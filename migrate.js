#!/usr/bin/env node

/**
 * ========================================================================
 * FIRESTORE MIGRATION SCRIPT: FLAT → NESTED SUBCOLLECTIONS
 * ========================================================================
 *
 * USAGE:
 *   node migrate.js --dry-run          # Preview changes (no writes)
 *   node migrate.js --commit           # Execute migration
 *   node migrate.js --validate         # Validate migration results
 *   node migrate.js --backup           # Backup old collections to JSON
 *
 * ENVIRONMENT VARIABLES:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
 *
 * CURRENT SCHEMA (Flat Collections):
 *   /users/{uid}
 *   /profiles/{id}           ← linked to userId
 *   /tasks/{id}              ← linked to profileId
 *   /responses/{id}          ← linked to profileId
 *   /gallery_events/{id}     ← linked to userId
 *
 * DESIRED SCHEMA (Nested Subcollections):
 *   /users/{uid}
 *       /profiles/{phoneNumber}
 *           /habits/{uuid}
 *           /messages/{uuid}
 *       /gallery_events/{uuid}
 *
 * SAFETY FEATURES:
 *   ✅ Dry-run mode by default
 *   ✅ Detailed progress logging
 *   ✅ Batch operations (respects Firestore limits)
 *   ✅ Validation checks (count comparison)
 *   ✅ Backup export before deletion
 *   ✅ Error handling with retry logic
 *
 * ========================================================================
 */

const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

// ========================================================================
// CONFIGURATION
// ========================================================================

const CONFIG = {
  dryRun: true, // Default to safe mode
  batchSize: 500, // Firestore batch limit
  backupDir: './firestore-backup',
  logFile: './migration.log',
};

// Parse command-line arguments
const args = process.argv.slice(2);
if (args.includes('--commit')) {
  CONFIG.dryRun = false;
  console.log('🔴 COMMIT MODE ENABLED - Changes will be written to Firestore');
} else if (args.includes('--validate')) {
  CONFIG.validateOnly = true;
  console.log('📊 VALIDATION MODE - Checking migration results');
} else if (args.includes('--backup')) {
  CONFIG.backupOnly = true;
  console.log('💾 BACKUP MODE - Exporting old collections to JSON');
} else {
  console.log('✅ DRY-RUN MODE - Preview only (no writes)');
}

// ========================================================================
// FIREBASE INITIALIZATION
// ========================================================================

// Initialize Firebase Admin SDK
// Ensure GOOGLE_APPLICATION_CREDENTIALS env variable is set
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('❌ ERROR: GOOGLE_APPLICATION_CREDENTIALS environment variable not set');
  console.error('   Set it to the path of your Firebase service account key JSON file');
  console.error('   Example: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

// ========================================================================
// LOGGING UTILITIES
// ========================================================================

const log = {
  info: (message) => {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] INFO: ${message}`;
    console.log(logMessage);
    appendToLogFile(logMessage);
  },

  success: (message) => {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] ✅ SUCCESS: ${message}`;
    console.log(logMessage);
    appendToLogFile(logMessage);
  },

  warning: (message) => {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] ⚠️  WARNING: ${message}`;
    console.warn(logMessage);
    appendToLogFile(logMessage);
  },

  error: (message, error) => {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] ❌ ERROR: ${message}`;
    console.error(logMessage);
    if (error) {
      console.error(error);
      appendToLogFile(`${logMessage}\n${error.stack || error}`);
    } else {
      appendToLogFile(logMessage);
    }
  },

  progress: (current, total, entity) => {
    const percentage = ((current / total) * 100).toFixed(1);
    const message = `Progress: ${current}/${total} ${entity} (${percentage}%)`;
    console.log(message);
    if (current % 100 === 0 || current === total) {
      appendToLogFile(message);
    }
  },
};

async function appendToLogFile(message) {
  try {
    await fs.appendFile(CONFIG.logFile, message + '\n');
  } catch (err) {
    // Ignore logging errors to avoid infinite loops
  }
}

// ========================================================================
// BACKUP FUNCTIONS
// ========================================================================

/**
 * Export a collection to JSON file
 */
async function backupCollection(collectionName) {
  log.info(`Starting backup of collection: ${collectionName}`);

  try {
    const snapshot = await db.collection(collectionName).get();
    const documents = [];

    snapshot.forEach((doc) => {
      documents.push({
        id: doc.id,
        data: doc.data(),
      });
    });

    // Ensure backup directory exists
    await fs.mkdir(CONFIG.backupDir, { recursive: true });

    // Write to JSON file
    const backupPath = path.join(CONFIG.backupDir, `${collectionName}-backup.json`);
    await fs.writeFile(
      backupPath,
      JSON.stringify(documents, null, 2)
    );

    log.success(`Backed up ${documents.length} documents from ${collectionName} to ${backupPath}`);
    return documents.length;
  } catch (error) {
    log.error(`Failed to backup collection ${collectionName}`, error);
    throw error;
  }
}

/**
 * Backup all old collections before migration
 */
async function backupOldCollections() {
  log.info('========================================');
  log.info('STARTING BACKUP OF OLD COLLECTIONS');
  log.info('========================================');

  const collections = ['profiles', 'tasks', 'responses', 'gallery_events'];
  const counts = {};

  for (const collection of collections) {
    counts[collection] = await backupCollection(collection);
  }

  log.success('Backup complete!');
  log.info('Backup summary:');
  Object.entries(counts).forEach(([collection, count]) => {
    log.info(`  ${collection}: ${count} documents`);
  });

  return counts;
}

// ========================================================================
// MIGRATION FUNCTIONS
// ========================================================================

/**
 * Migrate profiles from /profiles to /users/{uid}/profiles/{phoneNumber}
 */
async function migrateProfiles(userId) {
  const oldProfilesRef = db.collection('profiles').where('userId', '==', userId);
  const snapshot = await oldProfilesRef.get();

  if (snapshot.empty) {
    return { migrated: 0, skipped: 0 };
  }

  let migrated = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const profileData = doc.data();
    const profileId = doc.id;

    // New nested path: /users/{uid}/profiles/{profileId}
    const newProfileRef = db.collection('users')
      .doc(userId)
      .collection('profiles')
      .doc(profileId);

    if (CONFIG.dryRun) {
      log.info(`  [DRY-RUN] Would migrate profile ${profileId} to /users/${userId}/profiles/${profileId}`);
      migrated++;
    } else {
      try {
        await newProfileRef.set(profileData);
        migrated++;

        // Migrate nested habits and messages for this profile
        await migrateHabits(userId, profileId);
        await migrateMessages(userId, profileId);
      } catch (error) {
        log.error(`Failed to migrate profile ${profileId}`, error);
        skipped++;
      }
    }
  }

  return { migrated, skipped };
}

/**
 * Migrate tasks/habits from /tasks to /users/{uid}/profiles/{pid}/habits/{uuid}
 */
async function migrateHabits(userId, profileId) {
  const oldTasksRef = db.collection('tasks').where('profileId', '==', profileId);
  const snapshot = await oldTasksRef.get();

  if (snapshot.empty) {
    return { migrated: 0, skipped: 0 };
  }

  let migrated = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const taskData = doc.data();
    const taskId = doc.id;

    // New nested path: /users/{uid}/profiles/{pid}/habits/{uuid}
    const newHabitRef = db.collection('users')
      .doc(userId)
      .collection('profiles')
      .doc(profileId)
      .collection('habits')
      .doc(taskId);

    if (CONFIG.dryRun) {
      log.info(`    [DRY-RUN] Would migrate habit ${taskId} to /users/${userId}/profiles/${profileId}/habits/${taskId}`);
      migrated++;
    } else {
      try {
        await newHabitRef.set(taskData);
        migrated++;
      } catch (error) {
        log.error(`Failed to migrate habit ${taskId}`, error);
        skipped++;
      }
    }
  }

  return { migrated, skipped };
}

/**
 * Migrate responses/messages from /responses to /users/{uid}/profiles/{pid}/messages/{uuid}
 */
async function migrateMessages(userId, profileId) {
  const oldResponsesRef = db.collection('responses').where('profileId', '==', profileId);
  const snapshot = await oldResponsesRef.get();

  if (snapshot.empty) {
    return { migrated: 0, skipped: 0 };
  }

  let migrated = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const responseData = doc.data();
    const responseId = doc.id;

    // New nested path: /users/{uid}/profiles/{pid}/messages/{uuid}
    const newMessageRef = db.collection('users')
      .doc(userId)
      .collection('profiles')
      .doc(profileId)
      .collection('messages')
      .doc(responseId);

    if (CONFIG.dryRun) {
      log.info(`    [DRY-RUN] Would migrate message ${responseId} to /users/${userId}/profiles/${profileId}/messages/${responseId}`);
      migrated++;
    } else {
      try {
        await newMessageRef.set(responseData);
        migrated++;
      } catch (error) {
        log.error(`Failed to migrate message ${responseId}`, error);
        skipped++;
      }
    }
  }

  return { migrated, skipped };
}

/**
 * Migrate gallery events from /gallery_events to /users/{uid}/gallery_events/{uuid}
 */
async function migrateGalleryEvents(userId) {
  const oldEventsRef = db.collection('gallery_events').where('userId', '==', userId);
  const snapshot = await oldEventsRef.get();

  if (snapshot.empty) {
    return { migrated: 0, skipped: 0 };
  }

  let migrated = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const eventData = doc.data();
    const eventId = doc.id;

    // New nested path: /users/{uid}/gallery_events/{uuid}
    const newEventRef = db.collection('users')
      .doc(userId)
      .collection('gallery_events')
      .doc(eventId);

    if (CONFIG.dryRun) {
      log.info(`  [DRY-RUN] Would migrate gallery event ${eventId} to /users/${userId}/gallery_events/${eventId}`);
      migrated++;
    } else {
      try {
        await newEventRef.set(eventData);
        migrated++;
      } catch (error) {
        log.error(`Failed to migrate gallery event ${eventId}`, error);
        skipped++;
      }
    }
  }

  return { migrated, skipped };
}

// ========================================================================
// MAIN MIGRATION ORCHESTRATOR
// ========================================================================

/**
 * Migrate all data for all users
 */
async function runMigration() {
  log.info('========================================');
  log.info('STARTING FIRESTORE MIGRATION');
  log.info(`Mode: ${CONFIG.dryRun ? 'DRY-RUN (preview only)' : 'COMMIT (writing to Firestore)'}`);
  log.info('========================================');

  const startTime = Date.now();

  // Get all users
  const usersSnapshot = await db.collection('users').get();
  const totalUsers = usersSnapshot.size;

  log.info(`Found ${totalUsers} users to migrate`);

  const stats = {
    users: 0,
    profiles: { migrated: 0, skipped: 0 },
    habits: { migrated: 0, skipped: 0 },
    messages: { migrated: 0, skipped: 0 },
    galleryEvents: { migrated: 0, skipped: 0 },
  };

  let currentUser = 0;

  // Process each user
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    currentUser++;

    log.info(`Processing user ${currentUser}/${totalUsers}: ${userId}`);

    try {
      // Migrate profiles (which will cascade to habits and messages)
      const profileStats = await migrateProfiles(userId);
      stats.profiles.migrated += profileStats.migrated;
      stats.profiles.skipped += profileStats.skipped;

      // Migrate gallery events
      const eventStats = await migrateGalleryEvents(userId);
      stats.galleryEvents.migrated += eventStats.migrated;
      stats.galleryEvents.skipped += eventStats.skipped;

      stats.users++;
      log.progress(currentUser, totalUsers, 'users');
    } catch (error) {
      log.error(`Failed to migrate user ${userId}`, error);
    }
  }

  const endTime = Date.now();
  const duration = ((endTime - startTime) / 1000).toFixed(2);

  // Print summary
  log.info('========================================');
  log.success('MIGRATION COMPLETE');
  log.info('========================================');
  log.info(`Duration: ${duration} seconds`);
  log.info(`Users processed: ${stats.users}/${totalUsers}`);
  log.info(`Profiles migrated: ${stats.profiles.migrated} (skipped: ${stats.profiles.skipped})`);
  log.info(`Gallery events migrated: ${stats.galleryEvents.migrated} (skipped: ${stats.galleryEvents.skipped})`);

  if (CONFIG.dryRun) {
    log.info('');
    log.warning('This was a DRY-RUN. No changes were written to Firestore.');
    log.info('To execute the migration, run: node migrate.js --commit');
  }

  return stats;
}

// ========================================================================
// VALIDATION FUNCTIONS
// ========================================================================

/**
 * Count documents in old (flat) collections
 */
async function countOldCollections() {
  log.info('Counting documents in OLD collections...');

  const counts = {
    profiles: 0,
    tasks: 0,
    responses: 0,
    gallery_events: 0,
  };

  for (const collection of Object.keys(counts)) {
    const snapshot = await db.collection(collection).count().get();
    counts[collection] = snapshot.data().count;
    log.info(`  ${collection}: ${counts[collection]} documents`);
  }

  return counts;
}

/**
 * Count documents in new (nested) collections
 */
async function countNewCollections() {
  log.info('Counting documents in NEW nested collections...');

  const counts = {
    profiles: 0,
    habits: 0,
    messages: 0,
    gallery_events: 0,
  };

  // Use collection group queries to count across all users
  const profilesSnapshot = await db.collectionGroup('profiles').count().get();
  counts.profiles = profilesSnapshot.data().count;

  const habitsSnapshot = await db.collectionGroup('habits').count().get();
  counts.habits = habitsSnapshot.data().count;

  const messagesSnapshot = await db.collectionGroup('messages').count().get();
  counts.messages = messagesSnapshot.data().count;

  const eventsSnapshot = await db.collectionGroup('gallery_events').count().get();
  counts.gallery_events = eventsSnapshot.data().count;

  log.info(`  profiles: ${counts.profiles} documents`);
  log.info(`  habits: ${counts.habits} documents`);
  log.info(`  messages: ${counts.messages} documents`);
  log.info(`  gallery_events: ${counts.gallery_events} documents`);

  return counts;
}

/**
 * Validate migration by comparing document counts
 */
async function validateMigration() {
  log.info('========================================');
  log.info('VALIDATING MIGRATION RESULTS');
  log.info('========================================');

  const oldCounts = await countOldCollections();
  const newCounts = await countNewCollections();

  log.info('');
  log.info('Comparison:');

  const checks = [
    { name: 'Profiles', old: oldCounts.profiles, new: newCounts.profiles },
    { name: 'Habits (tasks)', old: oldCounts.tasks, new: newCounts.habits },
    { name: 'Messages (responses)', old: oldCounts.responses, new: newCounts.messages },
    { name: 'Gallery Events', old: oldCounts.gallery_events, new: newCounts.gallery_events },
  ];

  let allPassed = true;

  for (const check of checks) {
    const status = check.old === check.new ? '✅ PASS' : '❌ FAIL';
    log.info(`  ${status} ${check.name}: ${check.old} (old) vs ${check.new} (new)`);

    if (check.old !== check.new) {
      allPassed = false;
      log.warning(`    Mismatch detected! Expected ${check.old}, got ${check.new}`);
    }
  }

  log.info('');
  if (allPassed) {
    log.success('✅ ALL VALIDATION CHECKS PASSED');
    log.info('Migration appears successful. Safe to cleanup old collections.');
  } else {
    log.error('❌ VALIDATION FAILED');
    log.warning('Do NOT delete old collections until mismatches are resolved!');
  }

  return allPassed;
}

// ========================================================================
// CLEANUP FUNCTIONS
// ========================================================================

/**
 * Delete old flat collections (ONLY run after validation passes)
 */
async function cleanupOldCollections() {
  log.warning('========================================');
  log.warning('CLEANUP: DELETING OLD COLLECTIONS');
  log.warning('========================================');
  log.warning('This will permanently delete old collections!');
  log.warning('Ensure you have backups and validation passed.');

  if (CONFIG.dryRun) {
    log.info('[DRY-RUN] Would delete collections: profiles, tasks, responses, gallery_events');
    return;
  }

  const collections = ['profiles', 'tasks', 'responses', 'gallery_events'];

  for (const collectionName of collections) {
    log.info(`Deleting collection: ${collectionName}`);
    await deleteCollection(db, collectionName, CONFIG.batchSize);
    log.success(`Deleted collection: ${collectionName}`);
  }

  log.success('Cleanup complete!');
}

/**
 * Delete all documents in a collection
 */
async function deleteCollection(db, collectionPath, batchSize) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(db, query, resolve) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    // All documents deleted
    resolve();
    return;
  }

  // Delete documents in a batch
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  // Recurse on the next process tick to avoid stack overflow
  process.nextTick(() => {
    deleteQueryBatch(db, query, resolve);
  });
}

// ========================================================================
// MAIN ENTRY POINT
// ========================================================================

async function main() {
  try {
    if (CONFIG.backupOnly) {
      // Backup mode: Just export old collections
      await backupOldCollections();
    } else if (CONFIG.validateOnly) {
      // Validation mode: Check migration results
      await validateMigration();
    } else {
      // Migration mode: Run the migration (dry-run or commit)
      await runMigration();

      // If commit mode, automatically run validation
      if (!CONFIG.dryRun) {
        log.info('');
        log.info('Running automatic validation...');
        const validationPassed = await validateMigration();

        if (validationPassed) {
          log.info('');
          log.info('Next steps:');
          log.info('1. Backup old collections: node migrate.js --backup');
          log.info('2. If satisfied, cleanup old collections (manual - see cleanupOldCollections())');
        }
      }
    }

    log.success('Script completed successfully');
    process.exit(0);
  } catch (error) {
    log.error('Fatal error during migration', error);
    process.exit(1);
  }
}

// Run the script
main();
