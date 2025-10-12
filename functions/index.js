const functions = require('firebase-functions');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onCall} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const twilio = require('twilio');

// Initialize Firebase Admin
admin.initializeApp();

// Define secrets for Twilio (will be accessed from Firebase Secret Manager)
const twilioAccountSid = defineSecret('TWILIO_ACCOUNT_SID');
const twilioAuthToken = defineSecret('TWILIO_AUTH_TOKEN');
const twilioPhoneNumber = defineSecret('TWILIO_PHONE_NUMBER');

/**
 * Cloud Function to send SMS via Twilio
 *
 * Request body:
 * {
 *   "to": "+17788143739",
 *   "message": "Hi! Time to take your vitamins",
 *   "profileId": "profile-uuid",
 *   "messageType": "taskReminder"
 * }
 *
 * Response:
 * {
 *   "success": true,
 *   "messageId": "SM1234...",
 *   "status": "queued",
 *   "sentAt": "2025-10-09T..."
 * }
 */
exports.sendSMS = onCall({
  secrets: [twilioAccountSid, twilioAuthToken, twilioPhoneNumber]
}, async (request) => {
  // Verify user is authenticated
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to send SMS'
    );
  }

  // Access secrets from request.rawRequest (v2 pattern)
  const accountSid = twilioAccountSid.value();
  const authToken = twilioAuthToken.value();
  const fromNumber = twilioPhoneNumber.value();

  // Initialize Twilio client with secrets
  const twilioClient = twilio(accountSid, authToken);

  const data = request.data;

  const { to, message, profileId, messageType } = data;

  // Validate required fields
  if (!to || !message) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: to, message'
    );
  }

  // Validate phone number format (E.164)
  const phoneRegex = /^\+[1-9]\d{1,14}$/;
  if (!phoneRegex.test(to)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid phone number format: ${to}. Must be E.164 format (e.g., +17788143739)`
    );
  }

  // Check user's SMS quota (prevent abuse)
  const userId = request.auth.uid;
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'User not found'
    );
  }

  const userData = userDoc.data();

  // Check if user has exceeded their SMS quota
  if (userData.smsQuotaUsed >= userData.smsQuotaLimit) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `SMS quota exceeded. Used ${userData.smsQuotaUsed}/${userData.smsQuotaLimit} for this period.`
    );
  }

  // Check if quota period needs reset
  const now = new Date();
  const quotaPeriodEnd = userData.smsQuotaPeriodEnd?.toDate();

  if (quotaPeriodEnd && now > quotaPeriodEnd) {
    // Reset quota for new period
    await admin.firestore().collection('users').doc(userId).update({
      smsQuotaUsed: 0,
      smsQuotaPeriodStart: admin.firestore.FieldValue.serverTimestamp(),
      smsQuotaPeriodEnd: new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
    });
  }

  try {
    // Send SMS via Twilio
    const twilioMessage = await twilioClient.messages.create({
      body: message,
      from: fromNumber,
      to: to
    });

    console.log(`✅ SMS sent successfully: ${twilioMessage.sid}`);

    // Increment user's SMS quota usage
    await admin.firestore().collection('users').doc(userId).update({
      smsQuotaUsed: admin.firestore.FieldValue.increment(1)
    });

    // Log SMS delivery for audit trail
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('smsLogs')
      .add({
        to: to,
        message: message,
        profileId: profileId || null,
        messageType: messageType || 'unknown',
        twilioSid: twilioMessage.sid,
        status: twilioMessage.status,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        direction: 'outbound'
      });

    return {
      success: true,
      messageId: twilioMessage.sid,
      status: twilioMessage.status,
      sentAt: new Date().toISOString()
    };

  } catch (error) {
    console.error('❌ Twilio SMS error:', error);

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send SMS: ${error.message}`
    );
  }
});

/**
 * Webhook endpoint for Twilio incoming SMS (Status callbacks & Replies)
 *
 * This receives incoming messages when elderly users reply to reminders
 */
exports.twilioWebhook = functions.https.onRequest(async (req, res) => {
  console.log('📱 Twilio webhook received:', req.body);

  const {
    From: fromPhone,
    To: toPhone,
    Body: messageBody,
    MessageSid: twilioSid,
    SmsStatus: status,
    NumMedia: numMedia
  } = req.body;

  try {
    // WORKAROUND: Try collectionGroup first, if it fails due to index building,
    // fall back to searching all users (less efficient but works)
    let profileDoc = null;
    let userId = null;

    try {
      // Try collectionGroup query (requires index)
      const profilesSnapshot = await admin.firestore()
        .collectionGroup('profiles')
        .where('phoneNumber', '==', fromPhone)
        .limit(1)
        .get();

      if (!profilesSnapshot.empty) {
        profileDoc = profilesSnapshot.docs[0];
        const profileData = profileDoc.data();
        userId = profileData.userId;
      }
    } catch (indexError) {
      console.warn(`⚠️ CollectionGroup query failed (index building?): ${indexError.message}`);
      console.log('📝 Falling back to manual user search...');

      // Fallback: Query all users and search their profiles
      const usersSnapshot = await admin.firestore().collection('users').get();

      for (const userDoc of usersSnapshot.docs) {
        const userProfiles = await userDoc.ref.collection('profiles')
          .where('phoneNumber', '==', fromPhone)
          .limit(1)
          .get();

        if (!userProfiles.empty) {
          profileDoc = userProfiles.docs[0];
          userId = userDoc.id;
          console.log(`✅ Found profile via fallback method for user: ${userId}`);
          break;
        }
      }
    }

    if (!profileDoc || !userId) {
      console.warn(`⚠️ No profile found for phone: ${fromPhone}`);
      res.status(200).send('OK'); // Still return 200 to Twilio
      return;
    }

    // Check for STOP keywords (opt-out)
    const upperMessage = messageBody.toUpperCase().trim();
    const stopKeywords = ['STOP', 'UNSUBSCRIBE', 'CANCEL', 'END', 'QUIT', 'STOPALL'];

    if (stopKeywords.includes(upperMessage)) {
      console.log(`🛑 Opt-out detected from ${fromPhone}`);

      // Update profile to opt-out
      await profileDoc.ref.update({
        smsOptedOut: true,
        optOutDate: admin.firestore.FieldValue.serverTimestamp(),
        optOutMethod: 'STOP_KEYWORD'
      });
    }

    // Store the incoming message
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('profiles')
      .doc(profileDoc.id)
      .collection('messages')
      .add({
        userId: userId, // Add userId for collectionGroup queries
        profileId: profileDoc.id,
        fromPhone: fromPhone,
        toPhone: toPhone,
        messageBody: messageBody,
        twilioSid: twilioSid,
        status: status,
        numMedia: parseInt(numMedia) || 0,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        isOptOut: stopKeywords.includes(upperMessage),
        direction: 'inbound'
      });

    console.log(`✅ Incoming message stored for user ${userId}`);
    res.status(200).send('OK');

  } catch (error) {
    console.error('❌ Webhook processing error:', error);
    res.status(500).send('Error processing webhook');
  }
});

/**
 * Helper function to validate Twilio webhook signature (security)
 * Prevents unauthorized requests to your webhook
 */
function validateTwilioRequest(req) {
  const twilioSignature = req.headers['x-twilio-signature'];
  const url = `https://${req.headers.host}${req.url}`;

  return twilio.validateRequest(
    twilioAuthToken,
    twilioSignature,
    url,
    req.body
  );
}

/**
 * Scheduled function to cleanup old gallery events (runs daily at midnight PST)
 *
 * Data Retention Policy:
 * - Events older than 90 days are processed
 * - Photos are archived to Cloud Storage (kept forever)
 * - Text data is permanently deleted (privacy + cost savings)
 *
 * Why:
 * - Privacy: Delete sensitive text messages after 3 months
 * - Cost: Reduce Firestore reads by 75%
 * - Memories: Keep photos in cheaper Cloud Storage
 *
 * Cost Impact:
 * - Before: ~$2/user/year (3,000+ Firestore docs)
 * - After: ~$0.50/user/year (270 docs + Cloud Storage)
 */
exports.cleanupOldGalleryEvents = onSchedule({
  schedule: 'every 24 hours',
  timeZone: 'America/Los_Angeles'
}, async (event) => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    // Calculate 90 days ago
    const threeMonthsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)
    );

    console.log('🧹 Starting cleanup of gallery events older than', threeMonthsAgo.toDate().toISOString());

    try {
      // Query old events across all users using collectionGroup
      const oldEventsSnapshot = await db.collectionGroup('galleryEvents')
        .where('createdAt', '<', threeMonthsAgo)
        .limit(500) // Process in batches to avoid timeouts
        .get();

      console.log(`📊 Found ${oldEventsSnapshot.size} old events to process`);

      if (oldEventsSnapshot.empty) {
        console.log('✨ No old events to cleanup');
        return { photosArchived: 0, eventsDeleted: 0 };
      }

      let photosArchived = 0;
      let eventsDeleted = 0;
      let errors = 0;

      // Process each old event
      for (const doc of oldEventsSnapshot.docs) {
        try {
          const event = doc.data();
          const userId = event.userId;
          const profileId = event.profileId;
          const eventDate = event.createdAt.toDate();

          // Check if this is a task response with a photo
          if (event.eventType === 'taskResponse' &&
              event.eventData?.taskResponse?.photoData) {

            const photoDataBase64 = event.eventData.taskResponse.photoData;

            // Create organized file path: userId/profileId/YYYY/MM/eventId.jpg
            const year = eventDate.getFullYear();
            const month = String(eventDate.getMonth() + 1).padStart(2, '0');
            const fileName = `gallery-archive/${userId}/${profileId}/${year}/${month}/${event.id}.jpg`;

            console.log(`📸 Archiving photo: ${fileName}`);

            // Convert base64 to buffer
            const photoBuffer = Buffer.from(photoDataBase64, 'base64');

            // Upload to Cloud Storage
            const file = bucket.file(fileName);
            await file.save(photoBuffer, {
              contentType: 'image/jpeg',
              metadata: {
                metadata: {
                  userId: userId,
                  profileId: profileId,
                  eventId: event.id,
                  originalCreatedAt: eventDate.toISOString(),
                  archivedAt: new Date().toISOString(),
                  taskTitle: event.eventData.taskResponse.taskTitle || 'Unknown Task'
                }
              }
            });

            photosArchived++;
            console.log(`✅ Photo archived successfully: ${fileName}`);
          }

          // Delete the Firestore event (text data permanently removed)
          await doc.ref.delete();
          eventsDeleted++;

          console.log(`🗑️ Event deleted: ${event.id} (created ${eventDate.toISOString()})`);

        } catch (error) {
          errors++;
          console.error(`❌ Failed to process event ${doc.id}:`, error.message);
          // Continue processing other events even if one fails
        }
      }

      const summary = {
        photosArchived,
        eventsDeleted,
        errors,
        timestamp: new Date().toISOString(),
        oldestEventProcessed: threeMonthsAgo.toDate().toISOString()
      };

      console.log('🎉 Cleanup complete:', JSON.stringify(summary, null, 2));

      return summary;

    } catch (error) {
      console.error('💥 Cleanup function failed:', error);
      throw error;
    }
  });

/**
 * Manual trigger endpoint for testing cleanup (HTTP)
 *
 * Usage:
 * curl -X POST https://us-central1-remi-91351.cloudfunctions.net/manualCleanup \
 *   -H "Content-Type: application/json" \
 *   -d '{"daysOld": 90}'
 */
exports.manualCleanup = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const daysOld = req.body.daysOld || 90;
  const cutoffDate = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000)
  );

  console.log(`🧪 Manual cleanup triggered for events older than ${daysOld} days`);

  try {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    const oldEventsSnapshot = await db.collectionGroup('galleryEvents')
      .where('createdAt', '<', cutoffDate)
      .limit(100) // Smaller limit for manual testing
      .get();

    let photosArchived = 0;
    let eventsDeleted = 0;

    for (const doc of oldEventsSnapshot.docs) {
      const event = doc.data();

      if (event.eventType === 'taskResponse' &&
          event.eventData?.taskResponse?.photoData) {

        const photoDataBase64 = event.eventData.taskResponse.photoData;
        const eventDate = event.createdAt.toDate();
        const year = eventDate.getFullYear();
        const month = String(eventDate.getMonth() + 1).padStart(2, '0');
        const fileName = `gallery-archive/${event.userId}/${event.profileId}/${year}/${month}/${event.id}.jpg`;

        const photoBuffer = Buffer.from(photoDataBase64, 'base64');
        const file = bucket.file(fileName);

        await file.save(photoBuffer, {
          contentType: 'image/jpeg',
          metadata: {
            metadata: {
              userId: event.userId,
              profileId: event.profileId,
              eventId: event.id,
              archivedAt: new Date().toISOString()
            }
          }
        });

        photosArchived++;
      }

      await doc.ref.delete();
      eventsDeleted++;
    }

    const result = {
      success: true,
      photosArchived,
      eventsDeleted,
      daysOld,
      timestamp: new Date().toISOString()
    };

    console.log('✅ Manual cleanup complete:', result);
    res.json(result);

  } catch (error) {
    console.error('❌ Manual cleanup failed:', error);
    res.status(500).json({ error: error.message });
  }
});
