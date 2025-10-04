const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function testConnection() {
  try {
    console.log('Testing Firestore connection...');
    
    // Try to list collections
    const collections = await db.listCollections();
    console.log(`✅ SUCCESS: Found ${collections.length} collections`);
    
    collections.forEach((col) => {
      console.log(`  - ${col.id}`);
    });
    
    if (collections.length === 0) {
      console.log('\n⚠️  WARNING: Firestore database exists but has no collections yet.');
      console.log('   This might be a new/empty database.');
    }
  } catch (error) {
    console.error('❌ ERROR:', error.message);
    if (error.message.includes('NOT_FOUND')) {
      console.log('\n⚠️  This likely means:');
      console.log('   1. Firestore database has not been initialized yet');
      console.log('   2. Go to Firebase Console → Firestore Database');
      console.log('   3. Click "Create Database" if prompted');
      console.log('   4. Choose production mode and region (us-central1 recommended)');
    }
  }
  process.exit(0);
}

testConnection();
