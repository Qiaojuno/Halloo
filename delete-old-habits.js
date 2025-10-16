const admin = require('firebase-admin');

// Initialize Firebase Admin with project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'remi-ios-9ad1c'
  });
}

const db = admin.firestore();

async function deleteOldHabits() {
  console.log('🔍 Finding habits with numeric timestamps...');

  const habitsSnapshot = await db.collectionGroup('habits').get();

  console.log(`📋 Total habits found: ${habitsSnapshot.size}`);

  let deletedCount = 0;
  let keptCount = 0;

  for (const doc of habitsSnapshot.docs) {
    const habit = doc.data();
    const isOldFormat = typeof habit.nextScheduledDate === 'number';

    console.log(`\n  Habit: "${habit.title}"`);
    console.log(`    ID: ${doc.id}`);
    console.log(`    nextScheduledDate type: ${typeof habit.nextScheduledDate}`);
    console.log(`    Format: ${isOldFormat ? 'OLD (number)' : 'NEW (Timestamp)'}`);

    if (isOldFormat) {
      console.log(`    ❌ Deleting old format habit...`);
      await doc.ref.delete();
      deletedCount++;
    } else {
      console.log(`    ✅ Keeping new format habit`);
      keptCount++;
    }
  }

  console.log(`\n✅ Cleanup complete:`);
  console.log(`   Deleted: ${deletedCount} habits`);
  console.log(`   Kept: ${keptCount} habits`);
}

deleteOldHabits()
  .then(() => {
    console.log('✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
