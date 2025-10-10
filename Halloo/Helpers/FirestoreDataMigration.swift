import Foundation
import FirebaseFirestore

/// One-time data migration helper to fix task profileIds from phone numbers to UUIDs
///
/// **CONTEXT**: Old schema used phone numbers as profile IDs, new schema uses UUIDs
/// This migrates existing Firestore tasks to match current profiles
class FirestoreDataMigration {

    private let db = Firestore.firestore()

    /// Migrate all tasks for a user from phone-number profileIds to UUID profileIds
    ///
    /// **How it works:**
    /// 1. Fetch all user profiles (phone → UUID mapping)
    /// 2. Fetch all user habits from collectionGroup
    /// 3. For each habit with phone-number profileId, find matching profile by phone
    /// 4. Update habit's profileId to profile's actual UUID
    ///
    /// - Parameter userId: Firebase Auth UID
    /// - Returns: Number of tasks migrated
    func migrateTaskProfileIds(userId: String) async throws -> Int {
        print("🔧 [Migration] Starting task profileId migration for user: \(userId)")

        // Step 1: Load all profiles to build phone → UUID mapping
        let profilesSnapshot = try await db.collection("users")
            .document(userId)
            .collection("profiles")
            .getDocuments()

        var phoneToProfileId: [String: String] = [:]
        for doc in profilesSnapshot.documents {
            if let phoneNumber = doc.data()["phoneNumber"] as? String {
                phoneToProfileId[phoneNumber] = doc.documentID
                print("   Mapped: \(phoneNumber) → \(doc.documentID)")
            }
        }

        print("📱 [Migration] Found \(phoneToProfileId.count) profiles")

        // Step 2: Find all habits with phone-number profileIds
        let habitsSnapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        print("🔍 [Migration] Found \(habitsSnapshot.documents.count) total habits")

        var migratedCount = 0

        for doc in habitsSnapshot.documents {
            let data = doc.data()
            guard let currentProfileId = data["profileId"] as? String else {
                print("   ⚠️ Habit \(doc.documentID) has no profileId")
                continue
            }

            // Check if profileId looks like a phone number (+1...)
            if currentProfileId.hasPrefix("+") && currentProfileId.count >= 11 {
                // This is a phone number - needs migration
                if let newProfileId = phoneToProfileId[currentProfileId] {
                    print("   🔄 Migrating habit '\(data["title"] ?? "unknown")'")
                    print("      Old profileId: \(currentProfileId)")
                    print("      New profileId: \(newProfileId)")

                    try await doc.reference.updateData([
                        "profileId": newProfileId,
                        "lastModifiedAt": FieldValue.serverTimestamp()
                    ])

                    migratedCount += 1
                } else {
                    print("   ❌ No profile found for phone: \(currentProfileId)")
                }
            } else {
                print("   ✅ Habit already uses UUID profileId: \(currentProfileId)")
            }
        }

        print("✅ [Migration] Complete! Migrated \(migratedCount) habits")
        return migratedCount
    }

    /// Delete all habits with orphaned phone-number profileIds
    /// (Use if you just want to clean up and recreate habits)
    func deleteOrphanedHabits(userId: String) async throws -> Int {
        print("🗑️ [Migration] Deleting orphaned habits for user: \(userId)")

        let habitsSnapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        var deletedCount = 0

        for doc in habitsSnapshot.documents {
            let data = doc.data()
            guard let profileId = data["profileId"] as? String else { continue }

            // If profileId is a phone number, delete it
            if profileId.hasPrefix("+") && profileId.count >= 11 {
                print("   🗑️ Deleting habit: '\(data["title"] ?? "unknown")' (orphaned profileId: \(profileId))")
                try await doc.reference.delete()
                deletedCount += 1
            }
        }

        print("✅ [Migration] Deleted \(deletedCount) orphaned habits")
        return deletedCount
    }
}
