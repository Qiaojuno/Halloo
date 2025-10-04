const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function checkData() {
  try {
    console.log('Checking Firestore for existing data...\n');
    
    // Check all collections
    const collections = ['users', 'profiles', 'tasks', 'responses', 'gallery_events'];
    
    for (const collectionName of collections) {
      const snapshot = await db.collection(collectionName).limit(5).get();
      console.log(`📁 ${collectionName}: ${snapshot.size} documents (showing first 5)`);
      
      if (snapshot.size > 0) {
        snapshot.forEach((doc) => {
          const data = doc.data();
          console.log(`   - ${doc.id}`);
          // Show a few key fields
          if (data.email) console.log(`     email: ${data.email}`);
          if (data.name) console.log(`     name: ${data.name}`);
          if (data.userId) console.log(`     userId: ${data.userId}`);
          if (data.profileId) console.log(`     profileId: ${data.profileId}`);
        });
      }
      console.log('');
    }
    
    // Get total count for users
    const usersCount = await db.collection('users').count().get();
    console.log(`\n📊 Total users in database: ${usersCount.data().count}`);
    
  } catch (error) {
    console.error('❌ ERROR:', error.message);
  }
  process.exit(0);
}

checkData();
