# Firestore Migration Guide: Flat → Nested Subcollections

## Overview

This migration script transforms your Firestore database from a **flat collection structure** to a **nested subcollection architecture**.

### Current Schema (Flat)
```
/users/{uid}
/profiles/{id}           ← linked via userId field
/tasks/{id}              ← linked via profileId field
/responses/{id}          ← linked via profileId field
/gallery_events/{id}     ← linked via userId field
```

### Target Schema (Nested)
```
/users/{uid}
    /profiles/{phoneNumber}
        /habits/{uuid}
        /messages/{uuid}
    /gallery_events/{uuid}
```

---

## Prerequisites

### 1. Install Node.js
Ensure Node.js v16+ is installed:
```bash
node --version  # Should be v16 or higher
```

### 2. Get Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Save the JSON file as `serviceAccountKey.json` in the project root

⚠️ **IMPORTANT:** Add `serviceAccountKey.json` to `.gitignore` (never commit this file!)

### 3. Install Dependencies
```bash
cd /Users/nich/Desktop/Halloo
npm install
```

This will install `firebase-admin` SDK.

---

## Migration Steps

### Step 1: Set Environment Variable
```bash
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/serviceAccountKey.json"
```

Or add to your shell profile (`.bashrc`, `.zshrc`, etc.):
```bash
echo 'export GOOGLE_APPLICATION_CREDENTIALS="/Users/nich/Desktop/Halloo/serviceAccountKey.json"' >> ~/.zshrc
source ~/.zshrc
```

### Step 2: Dry-Run (Preview Changes)
```bash
npm run migrate:dry-run
```

This will:
- ✅ Read all users, profiles, tasks, responses, gallery events
- ✅ Show what WOULD be migrated (no writes)
- ✅ Log preview to console and `migration.log`
- ✅ Count documents that would be moved

**Example Output:**
```
✅ DRY-RUN MODE - Preview only (no writes)
[2025-10-03T...] INFO: Found 10 users to migrate
[2025-10-03T...] INFO: Processing user 1/10: abc123
  [DRY-RUN] Would migrate profile +15551234567 to /users/abc123/profiles/+15551234567
    [DRY-RUN] Would migrate habit task-123 to /users/abc123/profiles/+15551234567/habits/task-123
    [DRY-RUN] Would migrate message msg-456 to /users/abc123/profiles/+15551234567/messages/msg-456
...
✅ SUCCESS: MIGRATION COMPLETE
Duration: 2.34 seconds
Users processed: 10/10
Profiles migrated: 25 (skipped: 0)
Gallery events migrated: 15 (skipped: 0)

⚠️  WARNING: This was a DRY-RUN. No changes were written to Firestore.
To execute the migration, run: node migrate.js --commit
```

### Step 3: Backup Old Collections
```bash
npm run migrate:backup
```

This will:
- ✅ Export all old collections to `./firestore-backup/` as JSON files
- ✅ Create: `profiles-backup.json`, `tasks-backup.json`, `responses-backup.json`, `gallery_events-backup.json`
- ✅ Allows rollback if something goes wrong

**Example Output:**
```
💾 BACKUP MODE - Exporting old collections to JSON
[2025-10-03T...] INFO: Starting backup of collection: profiles
✅ SUCCESS: Backed up 25 documents from profiles to ./firestore-backup/profiles-backup.json
...
✅ SUCCESS: Backup complete!
```

### Step 4: Run Migration (Commit Mode)
```bash
npm run migrate:commit
```

⚠️ **WARNING:** This will write changes to Firestore!

This will:
- ✅ Migrate all users, profiles, tasks, responses, gallery events
- ✅ Write to nested subcollections under `/users/{uid}/...`
- ✅ Automatically run validation after completion
- ✅ Log all operations to `migration.log`

**Example Output:**
```
🔴 COMMIT MODE ENABLED - Changes will be written to Firestore
[2025-10-03T...] INFO: Found 10 users to migrate
[2025-10-03T...] INFO: Processing user 1/10: abc123
...
✅ SUCCESS: MIGRATION COMPLETE
Duration: 15.67 seconds
Users processed: 10/10
Profiles migrated: 25 (skipped: 0)
Gallery events migrated: 15 (skipped: 0)

Running automatic validation...
========================================
VALIDATING MIGRATION RESULTS
========================================
Counting documents in OLD collections...
  profiles: 25 documents
  tasks: 50 documents
  responses: 100 documents
  gallery_events: 15 documents

Counting documents in NEW nested collections...
  profiles: 25 documents
  habits: 50 documents
  messages: 100 documents
  gallery_events: 15 documents

Comparison:
  ✅ PASS Profiles: 25 (old) vs 25 (new)
  ✅ PASS Habits (tasks): 50 (old) vs 50 (new)
  ✅ PASS Messages (responses): 100 (old) vs 100 (new)
  ✅ PASS Gallery Events: 15 (old) vs 15 (new)

✅ ALL VALIDATION CHECKS PASSED
Migration appears successful. Safe to cleanup old collections.

Next steps:
1. Backup old collections: node migrate.js --backup
2. If satisfied, cleanup old collections (manual - see cleanupOldCollections())
```

### Step 5: Validate Migration
```bash
npm run migrate:validate
```

This will:
- ✅ Count documents in old (flat) collections
- ✅ Count documents in new (nested) collections
- ✅ Compare counts to ensure no data loss
- ✅ Report any mismatches

**Example Output:**
```
📊 VALIDATION MODE - Checking migration results
========================================
VALIDATING MIGRATION RESULTS
========================================
Comparison:
  ✅ PASS Profiles: 25 (old) vs 25 (new)
  ✅ PASS Habits (tasks): 50 (old) vs 50 (new)
  ✅ PASS Messages (responses): 100 (old) vs 100 (new)
  ✅ PASS Gallery Events: 15 (old) vs 15 (new)

✅ ALL VALIDATION CHECKS PASSED
```

### Step 6: Cleanup Old Collections (MANUAL)

⚠️ **ONLY DO THIS AFTER:**
1. Validation passes (all counts match)
2. You've tested the app with the new nested structure
3. You have backups

To delete old collections, uncomment and run the cleanup function in `migrate.js`:

```javascript
// In migrate.js, add to main():
await cleanupOldCollections();
```

Then run:
```bash
npm run migrate:commit
```

This will **permanently delete** old collections: `profiles`, `tasks`, `responses`, `gallery_events`.

---

## Troubleshooting

### Error: GOOGLE_APPLICATION_CREDENTIALS not set
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/Users/nich/Desktop/Halloo/serviceAccountKey.json"
```

### Error: Permission denied
Ensure your service account has **Firestore Admin** role:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. IAM & Admin → Service Accounts
3. Find your service account
4. Add role: **Cloud Datastore User** or **Owner**

### Error: Counts don't match after migration
1. Check `migration.log` for errors
2. Look for "skipped" counts in migration output
3. Run validation again: `npm run migrate:validate`
4. If issues persist, restore from backup:
   - Use Firestore Console to import JSON backups
   - Or write a reverse migration script

### Migration is too slow
- Reduce batch size in `migrate.js`: `CONFIG.batchSize = 100`
- Run migration during low-traffic hours
- Consider migrating users in batches (modify script to process user subsets)

---

## Rollback Plan

If migration fails:

### Option 1: Restore from Backup
1. Go to Firestore Console
2. Delete new nested collections (if any)
3. Import JSON backups from `./firestore-backup/`:
   - Use Firebase CLI: `firebase firestore:import ./firestore-backup`
   - Or use Firestore Console bulk import

### Option 2: Keep Both Schemas Temporarily
The migration script does NOT delete old collections by default. You can:
1. Run migration to create nested structure
2. Keep old flat collections active temporarily
3. Update iOS app to read from nested collections
4. Once confirmed working, delete old collections manually

---

## Safety Features

✅ **Dry-run mode by default** - Must explicitly use `--commit` to write
✅ **Detailed logging** - All operations logged to `migration.log`
✅ **Backup export** - JSON backups of all old collections
✅ **Validation checks** - Automatic count comparison
✅ **Error handling** - Failed migrations logged, script continues
✅ **No automatic deletion** - Old collections preserved until manual cleanup

---

## Post-Migration Checklist

After successful migration:

- [ ] Validate all counts match (`npm run migrate:validate`)
- [ ] Test iOS app with nested structure
- [ ] Verify cascade deletes work (delete a profile in app, check subcollections deleted)
- [ ] Deploy updated Firestore indexes: `firebase deploy --only firestore:indexes`
- [ ] Update Firestore security rules for nested paths
- [ ] Monitor app for errors in production
- [ ] After 1-2 weeks of successful operation, cleanup old collections

---

## Support

If you encounter issues:

1. Check `migration.log` for detailed error messages
2. Ensure service account has correct permissions
3. Verify `serviceAccountKey.json` is valid and not expired
4. Test with a small dataset first (limit users in script)

---

## Script Architecture

```
migrate.js
├── Configuration (dry-run mode, batch size, etc.)
├── Firebase Initialization (Admin SDK)
├── Logging Utilities (info, success, warning, error)
├── Backup Functions (backupCollection, backupOldCollections)
├── Migration Functions
│   ├── migrateProfiles() - /profiles → /users/{uid}/profiles/{pid}
│   ├── migrateHabits() - /tasks → /users/{uid}/profiles/{pid}/habits/{hid}
│   ├── migrateMessages() - /responses → /users/{uid}/profiles/{pid}/messages/{mid}
│   └── migrateGalleryEvents() - /gallery_events → /users/{uid}/gallery_events/{eid}
├── Validation Functions (countOldCollections, countNewCollections, validateMigration)
├── Cleanup Functions (cleanupOldCollections, deleteCollection)
└── Main Orchestrator (runMigration)
```

---

**Migration created:** 2025-10-03
**Script version:** 1.0.0
**Firebase Admin SDK:** v12.0.0
