const admin = require('firebase-admin');
const serviceAccount = require('/Users/nich/Desktop/Halloo/remi-ios-9ad1c-firebase-adminsdk-qb61b-87cbf2e16c.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkHabits() {
  const now = admin.firestore.Timestamp.now();
  const twoMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 2 * 60 * 1000)
  );
  
  console.log('Current time:', now.toDate().toISOString());
  console.log('Two minutes ago:', twoMinutesAgo.toDate().toISOString());
  console.log('');
  
  // Get ALL habits to see what's in there
  const allHabits = await db.collectionGroup('habits').get();
  console.log(`Total habits in database: ${allHabits.size}`);
  console.log('');
  
  allHabits.forEach(doc => {
    const data = doc.data();
    console.log('Habit:', data.title);
    console.log('  - ID:', doc.id);
    console.log('  - Status:', data.status);
    console.log('  - scheduledTime:', data.scheduledTime?.toDate?.()?.toISOString() || data.scheduledTime);
    console.log('  - nextScheduledDate:', data.nextScheduledDate?.toDate?.()?.toISOString() || data.nextScheduledDate);
    console.log('  - Path:', doc.ref.path);
    console.log('');
  });
  
  process.exit(0);
}

checkHabits().catch(console.error);
