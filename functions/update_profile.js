const admin = require('firebase-admin');
const serviceAccount = require('../remi-ios-9ad1c-firebase-adminsdk-6d2u1-1e63bd7cf5.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateProfile() {
  const userId = 'IJue7FhdmbbIzR3WG6Tzhhf2ykD2';
  
  // Find the profile that needs updating
  const profilesSnapshot = await db.collection('users').doc(userId).collection('profiles').get();
  
  console.log(`Found ${profilesSnapshot.size} profiles for user ${userId}`);
  
  for (const doc of profilesSnapshot.docs) {
    const profile = doc.data();
    console.log(`\nProfile ${doc.id}:`);
    console.log(`  Name: ${profile.name}`);
    console.log(`  Phone: ${profile.phoneNumber}`);
    console.log(`  Status: ${profile.status}`);
    
    if (profile.status === 'pendingConfirmation') {
      console.log(`\n✅ Updating profile ${doc.id} to "confirmed"...`);
      await doc.ref.update({
        status: 'confirmed',
        confirmedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ Profile ${doc.id} updated to "confirmed"`);
    }
  }
}

updateProfile()
  .then(() => {
    console.log('\n✅ Done');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
