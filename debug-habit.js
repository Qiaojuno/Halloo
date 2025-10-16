const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkHabits() {
  try {
    console.log('🔍 Searching for all habits in database...\n');

    // Get all habits across all users/profiles
    const habitsSnapshot = await admin.firestore()
      .collectionGroup('habits')
      .get();

    console.log(`📊 Total habits found: ${habitsSnapshot.size}\n`);

    if (habitsSnapshot.empty) {
      console.log('❌ No habits found in database');
      process.exit(0);
    }

    // Analyze each habit
    for (const doc of habitsSnapshot.docs) {
      const habit = doc.data();
      const path = doc.ref.path;

      console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
      console.log(`📍 Path: ${path}`);
      console.log(`📝 Title: "${habit.title}"`);
      console.log(`🔄 Frequency: ${habit.frequency}`);
      console.log(`⏰ Status: ${habit.status}`);

      // Check nextScheduledDate
      if (habit.nextScheduledDate) {
        const nextScheduled = habit.nextScheduledDate.toDate();
        const now = new Date();
        const isPast = nextScheduled < now;
        const hoursDiff = Math.abs(now - nextScheduled) / (1000 * 60 * 60);

        console.log(`📅 nextScheduledDate: ${nextScheduled.toISOString()}`);
        console.log(`   - Time: ${nextScheduled.toLocaleString('en-US', { timeZone: 'America/Los_Angeles' })} PST`);
        console.log(`   - Status: ${isPast ? '⚠️  IN PAST' : '✅ FUTURE'}`);
        console.log(`   - Hours diff from now: ${hoursDiff.toFixed(2)} hours ${isPast ? 'ago' : 'ahead'}`);
      } else {
        console.log(`❌ nextScheduledDate: MISSING`);
      }

      // Check scheduledTime
      if (habit.scheduledTime) {
        const scheduledTime = habit.scheduledTime.toDate();
        console.log(`🕐 scheduledTime: ${scheduledTime.toISOString()}`);
        console.log(`   - Time: ${scheduledTime.toLocaleString('en-US', { timeZone: 'America/Los_Angeles' })} PST`);
      } else {
        console.log(`❌ scheduledTime: MISSING`);
      }

      // Check what the Cloud Function query would see
      const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
      const now = new Date();

      console.log(`\n🔎 Would Cloud Function find this?`);
      console.log(`   Query window: ${twoMinutesAgo.toLocaleTimeString()} - ${now.toLocaleTimeString()}`);

      if (habit.status === 'active') {
        console.log(`   ✅ status == 'active'`);
      } else {
        console.log(`   ❌ status != 'active' (actual: ${habit.status})`);
      }

      if (habit.nextScheduledDate) {
        const nextDate = habit.nextScheduledDate.toDate();
        const matchesQuery = nextDate >= twoMinutesAgo && nextDate <= now;
        console.log(`   ${matchesQuery ? '✅' : '❌'} nextScheduledDate in query window: ${matchesQuery}`);
      }
    }

    console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkHabits();
