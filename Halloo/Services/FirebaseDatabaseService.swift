import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

// MARK: - Firebase Database Service
class FirebaseDatabaseService: DatabaseServiceProtocol {
    
    // MARK: - Properties
    private lazy var db: Firestore = Firestore.firestore()
    private lazy var storage: Storage = Storage.storage()
    private var listeners: [ListenerRegistration] = []
    
    // MARK: - Collection Paths (Nested Subcollections)
    /// Dynamic collection path builder for nested Firestore structure
    /// Schema: /users/{uid}/profiles/{pid}/habits/{hid} and /users/{uid}/profiles/{pid}/messages/{mid}
    private enum CollectionPath {
        case users
        case userProfiles(userId: String)
        case userGalleryEvents(userId: String)
        case profileHabits(userId: String, profileId: String)
        case profileMessages(userId: String, profileId: String)

        var path: String {
            switch self {
            case .users:
                return "users"
            case .userProfiles(let userId):
                return "users/\(userId)/profiles"
            case .userGalleryEvents(let userId):
                return "users/\(userId)/gallery_events"
            case .profileHabits(let userId, let profileId):
                return "users/\(userId)/profiles/\(profileId)/habits"
            case .profileMessages(let userId, let profileId):
                return "users/\(userId)/profiles/\(profileId)/messages"
            }
        }

        /// Returns a document reference for the given path and document ID
        func document(_ documentId: String, in db: Firestore) -> DocumentReference {
            return db.collection(path).document(documentId)
        }

        /// Returns a collection reference for the given path
        func collection(in db: Firestore) -> CollectionReference {
            return db.collection(path)
        }
    }
    
    // MARK: - User Operations
    
    func createUser(_ user: User) async throws {
        let userData = try encodeToFirestore(user)
        try await CollectionPath.users.document(user.id, in: db).setData(userData)
    }

    func getUser(_ userId: String) async throws -> User? {
        let document = try await CollectionPath.users.document(userId, in: db).getDocument()

        guard let data = document.data() else {
            return nil
        }

        return try decodeFromFirestore(data, as: User.self)
    }

    func updateUser(_ user: User) async throws {
        let userData = try encodeToFirestore(user)
        try await CollectionPath.users.document(user.id, in: db).updateData(userData)
    }
    
    func deleteUser(_ userId: String) async throws {
        // ✅ Use recursive helper for safe cascade delete
        try await deleteUserRecursively(userId)
    }
    
    // MARK: - Profile Operations
    
    func createElderlyProfile(_ profile: ElderlyProfile) async throws {
        DiagnosticLogger.info(.profileId, "Creating profile", context: [
            "profileId": profile.id,
            "userId": profile.userId,
            "phoneNumber": profile.phoneNumber
        ])

        // Check for existing profile with same phone number (DUPLICATE PREVENTION)
        let existingProfiles = try await CollectionPath.userProfiles(userId: profile.userId)
            .collection(in: db)
            .whereField("phoneNumber", isEqualTo: profile.phoneNumber)
            .getDocuments()

        if !existingProfiles.isEmpty {
            // Log details of duplicate
            DiagnosticLogger.error(.profileId, "❌ DUPLICATE PHONE NUMBER - BLOCKING CREATION", context: [
                "newProfileId": profile.id,
                "phoneNumber": profile.phoneNumber,
                "existingCount": existingProfiles.documents.count
            ])

            // Get existing profile details for error message
            let firstDoc = existingProfiles.documents.first!
            let existingData = firstDoc.data()
            let existingName = existingData["name"] as? String ?? "Unknown"
            let existingId = firstDoc.documentID

            DiagnosticLogger.info(.profileId, "Existing profile details", context: [
                "id": existingId,
                "name": existingName,
                "phoneNumber": profile.phoneNumber
            ])

            // Throw error to prevent duplicate creation
            throw DatabaseError.duplicatePhoneNumber(
                phoneNumber: profile.phoneNumber,
                existingProfileName: existingName,
                existingProfileId: existingId
            )
        } else {
            DiagnosticLogger.success(.profileId, "✅ No duplicate phone numbers found - safe to create", context: [
                "phoneNumber": profile.phoneNumber
            ])
        }

        let profileData = try encodeToFirestore(profile)
        try await CollectionPath.userProfiles(userId: profile.userId)
            .document(profile.id, in: db)
            .setData(profileData)

        DiagnosticLogger.success(.database, "Profile created in Firestore", context: [
            "profileId": profile.id,
            "userId": profile.userId
        ])

        // Update user's profile count
        try await updateUserProfileCount(profile.userId)
    }

    func getElderlyProfile(_ profileId: String) async throws -> ElderlyProfile? {
        // Use collection group query to find profile across all users
        let snapshot = try await db.collectionGroup("profiles")
            .whereField("id", isEqualTo: profileId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first,
              let data = document.data() as? [String: Any] else {
            return nil
        }

        return try decodeFromFirestore(data, as: ElderlyProfile.self)
    }

    func getElderlyProfiles(for userId: String) async throws -> [ElderlyProfile] {
        let snapshot = try await CollectionPath.userProfiles(userId: userId)
            .collection(in: db)
            .order(by: "createdAt")
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: ElderlyProfile.self)
        }
    }

    func updateElderlyProfile(_ profile: ElderlyProfile) async throws {
        let profileData = try encodeToFirestore(profile)
        try await CollectionPath.userProfiles(userId: profile.userId)
            .document(profile.id, in: db)
            .updateData(profileData)
    }

    func deleteElderlyProfile(_ profileId: String, userId: String) async throws {
        DiagnosticLogger.info(.schema, "Profile delete requested", context: [
            "profileId": profileId,
            "userId": userId
        ])

        // ✅ Use direct path deletion (no collection group query needed)
        try await deleteProfileRecursively(profileId, userId: userId)

        DiagnosticLogger.success(.schema, "Profile deleted successfully", context: ["profileId": profileId])
    }

    func getConfirmedProfiles(for userId: String) async throws -> [ElderlyProfile] {
        let query = CollectionPath.userProfiles(userId: userId).collection(in: db)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "confirmed")
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: ElderlyProfile.self)
        }
    }
    
    // MARK: - Gallery History Event Operations
    
    func createGalleryHistoryEvent(_ event: GalleryHistoryEvent) async throws {
        let eventData = try encodeToFirestore(event)
        try await CollectionPath.userGalleryEvents(userId: event.userId)
            .document(event.id, in: db)
            .setData(eventData)
    }

    func getGalleryHistoryEvents(for userId: String) async throws -> [GalleryHistoryEvent] {
        let snapshot = try await CollectionPath.userGalleryEvents(userId: userId)
            .collection(in: db)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: GalleryHistoryEvent.self)
        }
    }
    
    // MARK: - Task/Habit Operations

    func createTask(_ task: Task) async throws {
        let taskData = try encodeToFirestore(task)
        try await CollectionPath.profileHabits(userId: task.userId, profileId: task.profileId)
            .document(task.id, in: db)
            .setData(taskData)

        // Update user's task count
        try await updateUserTaskCount(task.userId)
    }

    func getTask(_ taskId: String) async throws -> Task? {
        // Use collection group query to find task across all users/profiles
        let snapshot = try await db.collectionGroup("habits")
            .whereField("id", isEqualTo: taskId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first,
              let data = document.data() as? [String: Any] else {
            return nil
        }

        return try decodeFromFirestore(data, as: Task.self)
    }

    func getProfileTasks(_ profileId: String) async throws -> [Task] {
        // Use collection group query since we don't have userId
        let snapshot = try await db.collectionGroup("habits")
            .whereField("profileId", isEqualTo: profileId)
            .order(by: "createdAt")
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func getTasks(for userId: String) async throws -> [Task] {
        #if DEBUG
        print("🔍 [FirebaseDatabaseService] Querying habits collectionGroup for userId: \(userId)")
        print("🔍 [FirebaseDatabaseService] Auth UID: \(Auth.auth().currentUser?.uid ?? "nil")")
        #endif

        do {
            // Use collection group query to get all tasks for user across all profiles
            let snapshot = try await db.collectionGroup("habits")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt")
                .getDocuments()

            #if DEBUG
            print("✅ [FirebaseDatabaseService] Successfully fetched \(snapshot.documents.count) habits")
            if !snapshot.documents.isEmpty {
                print("📊 [FirebaseDatabaseService] Sample habit IDs: \(snapshot.documents.prefix(3).map { $0.documentID })")
            }
            #endif

            return try snapshot.documents.map { document in
                try decodeFromFirestore(document.data(), as: Task.self)
            }
        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Query failed: \(error.localizedDescription)")
            print("❌ [FirebaseDatabaseService] Error type: \(type(of: error))")
            #endif
            throw error
        }
    }

    func getTasks(for profileId: String, userId: String) async throws -> [Task] {
        let snapshot = try await CollectionPath.profileHabits(userId: userId, profileId: profileId)
            .collection(in: db)
            .order(by: "createdAt")
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getTasksScheduledFor(date: Date, userId: String) async throws -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        #if DEBUG
        print("🔍 [FirebaseDatabaseService] Querying scheduled habits for date: \(startOfDay), userId: \(userId)")
        #endif

        do {
            // Use collection group query across all user's profiles
            let snapshot = try await db.collectionGroup("habits")
                .whereField("userId", isEqualTo: userId)
                .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("nextScheduledDate", isLessThan: Timestamp(date: endOfDay))
                .order(by: "nextScheduledDate")
                .getDocuments()

            #if DEBUG
            print("✅ [FirebaseDatabaseService] Found \(snapshot.documents.count) scheduled habits for date")
            #endif

            return try snapshot.documents.map { document in
                try decodeFromFirestore(document.data(), as: Task.self)
            }
        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Scheduled habits query failed: \(error.localizedDescription)")
            #endif
            throw error
        }
    }

    func archiveTask(_ taskId: String) async throws {
        // Find task using collection group query
        let snapshot = try await db.collectionGroup("habits")
            .whereField("id", isEqualTo: taskId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            throw DatabaseError.documentNotFound
        }

        try await document.reference.updateData([
            "status": TaskStatus.archived.rawValue,
            "archivedAt": FieldValue.serverTimestamp()
        ])
    }

    func getTodaysTasks(_ userId: String) async throws -> [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Use collection group query across all user's profiles
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("nextScheduledDate", isLessThan: Timestamp(date: tomorrow))
            .order(by: "nextScheduledDate")
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            do {
                // Log document structure for debugging
                let data = document.data()
                print("🔍 [FirebaseDatabaseService] Task document keys: \(data.keys.joined(separator: ", "))")
                return try decodeFromFirestore(data, as: Task.self)
            } catch {
                print("⚠️ [FirebaseDatabaseService] Skipping task \(document.documentID): \(error.localizedDescription)")
                return nil
            }
        }
    }

    func getActiveTasks(for userId: String) async throws -> [Task] {
        // Use collection group query across all user's profiles
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: TaskStatus.active.rawValue)
            .order(by: "nextScheduledDate")
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func updateTask(_ task: Task) async throws {
        let taskData = try encodeToFirestore(task)
        try await CollectionPath.profileHabits(userId: task.userId, profileId: task.profileId)
            .document(task.id, in: db)
            .updateData(taskData)
    }
    
    func deleteTask(_ taskId: String, userId: String, profileId: String) async throws {
        #if DEBUG
        print("🔍 [FirebaseDatabaseService] deleteTask called")
        print("   taskId: \(taskId)")
        print("   userId: \(userId)")
        print("   profileId: \(profileId)")
        #endif

        do {
            // Delete the task itself using the proper nested path
            let taskPath = "users/\(userId)/profiles/\(profileId)/habits/\(taskId)"
            #if DEBUG
            print("🗑️ [FirebaseDatabaseService] Deleting habit at: \(taskPath)")
            #endif

            try await db.document(taskPath).delete()

            #if DEBUG
            print("✅ [FirebaseDatabaseService] Habit deleted successfully")
            #endif

            // Note: Messages are not deleted to preserve chat history
            // Note: User task count is not updated (would require collection group query)

        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Delete failed with error: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    // MARK: - Response/Message Operations

    func createSMSResponse(_ response: SMSResponse) async throws {
        guard let profileId = response.profileId else {
            throw DatabaseError.invalidData
        }

        let responseData = try encodeToFirestore(response)
        try await CollectionPath.profileMessages(userId: response.userId, profileId: profileId)
            .document(response.id, in: db)
            .setData(responseData)
    }

    func getSMSResponse(_ responseId: String) async throws -> SMSResponse? {
        // Use collection group query to find message across all users/profiles
        let snapshot = try await db.collectionGroup("messages")
            .whereField("id", isEqualTo: responseId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first,
              let data = document.data() as? [String: Any] else {
            return nil
        }

        return try decodeFromFirestore(data, as: SMSResponse.self)
    }

    func getSMSResponses(for taskId: String) async throws -> [SMSResponse] {
        // Use collection group query since we don't have userId/profileId
        let snapshot = try await db.collectionGroup("messages")
            .whereField("taskId", isEqualTo: taskId)
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }

    func getSMSResponses(for profileId: String, userId: String) async throws -> [SMSResponse] {
        let snapshot = try await CollectionPath.profileMessages(userId: userId, profileId: profileId)
            .collection(in: db)
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }

    func getSMSResponses(for userId: String, date: Date) async throws -> [SMSResponse] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Use collection group query across all user's profiles
        let snapshot = try await db.collectionGroup("messages")
            .whereField("userId", isEqualTo: userId)
            .whereField("receivedAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("receivedAt", isLessThan: Timestamp(date: endOfDay))
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }

    func getRecentSMSResponses(for userId: String, limit: Int) async throws -> [SMSResponse] {
        #if DEBUG
        print("🔍 [FirebaseDatabaseService] Querying recent messages (limit: \(limit)) for userId: \(userId)")
        #endif

        do {
            // Use collection group query across all user's profiles
            let snapshot = try await db.collectionGroup("messages")
                .whereField("userId", isEqualTo: userId)
                .order(by: "receivedAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            #if DEBUG
            print("✅ [FirebaseDatabaseService] Found \(snapshot.documents.count) recent messages")
            #endif

            return try snapshot.documents.compactMap { document in
                do {
                    // Log document structure for debugging
                    let data = document.data()
                    print("🔍 [FirebaseDatabaseService] Message document keys: \(data.keys.joined(separator: ", "))")
                    return try decodeFromFirestore(data, as: SMSResponse.self)
                } catch {
                    print("⚠️ [FirebaseDatabaseService] Skipping message \(document.documentID): \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Recent messages query failed: \(error.localizedDescription)")
            #endif
            throw error
        }
    }

    func getConfirmationResponses(for profileId: String) async throws -> [SMSResponse] {
        // Use collection group query since we don't have userId
        let snapshot = try await db.collectionGroup("messages")
            .whereField("profileId", isEqualTo: profileId)
            .whereField("responseType", isEqualTo: ResponseType.text.rawValue)
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }

    func getCompletedResponsesWithPhotos() async throws -> [SMSResponse] {
        // Use collection group query across all users/profiles
        let snapshot = try await db.collectionGroup("messages")
            .whereField("isCompleted", isEqualTo: true)
            .whereField("responseType", in: [ResponseType.photo.rawValue, ResponseType.both.rawValue])
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }

    func updateSMSResponse(_ response: SMSResponse) async throws {
        guard let profileId = response.profileId else {
            throw DatabaseError.invalidData
        }

        let responseData = try encodeToFirestore(response)
        try await CollectionPath.profileMessages(userId: response.userId, profileId: profileId)
            .document(response.id, in: db)
            .updateData(responseData)
    }

    func deleteSMSResponse(_ responseId: String) async throws {
        // Find message using collection group query
        let snapshot = try await db.collectionGroup("messages")
            .whereField("id", isEqualTo: responseId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            throw DatabaseError.documentNotFound
        }

        try await document.reference.delete()
    }
    
    // MARK: - Photo Storage Operations
    
    func uploadPhoto(_ photoData: Data, for responseId: String) async throws -> String {
        let storageRef = storage.reference()
        let photoRef = storageRef.child("responses/\(responseId)/photo.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await photoRef.putDataAsync(photoData, metadata: metadata)
        let downloadURL = try await photoRef.downloadURL()

        return downloadURL.absoluteString
    }

    func uploadProfilePhoto(_ photoData: Data, for profileId: String) async throws -> String {
        print("📤 [Storage] Starting profile photo upload")
        print("📤 [Storage] Profile ID: \(profileId)")
        print("📤 [Storage] Photo size: \(photoData.count) bytes")

        let storageRef = storage.reference()
        let photoRef = storageRef.child("profiles/\(profileId)/photo.jpg")

        print("📤 [Storage] Storage path: profiles/\(profileId)/photo.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        print("📤 [Storage] Calling putDataAsync()...")
        let uploadResult: StorageMetadata
        do {
            uploadResult = try await photoRef.putDataAsync(photoData, metadata: metadata)
            print("📤 [Storage] ✅ putDataAsync() completed!")
            print("📤 [Storage] Upload result path: \(uploadResult.path ?? "no path")")
            print("📤 [Storage] Upload result bucket: \(uploadResult.bucket ?? "no bucket")")
            print("📤 [Storage] Upload result name: \(uploadResult.name ?? "no name")")
        } catch {
            print("📤 [Storage] ❌ putDataAsync() FAILED with error: \(error)")
            print("📤 [Storage] Error type: \(type(of: error))")
            print("📤 [Storage] Error details: \(error.localizedDescription)")
            throw error
        }

        print("📤 [Storage] Getting download URL...")
        do {
            let downloadURL = try await photoRef.downloadURL()
            print("📤 [Storage] ✅ Download URL obtained: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("📤 [Storage] ❌ downloadURL() FAILED with error: \(error)")
            print("📤 [Storage] This means the upload succeeded but getting URL failed")
            print("📤 [Storage] Error details: \(error.localizedDescription)")
            throw error
        }
    }

    func deletePhoto(at url: String) async throws {
        let photoRef = storage.reference(forURL: url)
        try await photoRef.delete()
    }
    
    // MARK: - Real-time Listeners
    
    func observeUserTasks(_ userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        // Use collection group query to observe all tasks across user's profiles
        let listener = db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .order(by: "nextScheduledDate")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                do {
                    let tasks = try documents.map { document in
                        try self.decodeFromFirestore(document.data(), as: Task.self)
                    }
                    subject.send(tasks)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }

        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }

    func observeUserProfiles(_ userId: String) -> AnyPublisher<[ElderlyProfile], Error> {
        let subject = PassthroughSubject<[ElderlyProfile], Error>()

        // Observe nested profiles collection under user
        let listener = CollectionPath.userProfiles(userId: userId)
            .collection(in: db)
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                do {
                    let profiles = try documents.map { document in
                        try self.decodeFromFirestore(document.data(), as: ElderlyProfile.self)
                    }
                    subject.send(profiles)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }
        
        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }

    /// Observes incoming SMS messages for a user across all profiles
    ///
    /// Listens to the messages subcollection across all user profiles to detect
    /// incoming SMS replies (YES confirmations, STOP keywords, task responses).
    /// Broadcasts messages via DataSyncCoordinator for real-time UI updates.
    ///
    /// - Parameter userId: Family user ID to observe messages for
    /// - Returns: Publisher that emits incoming SMS messages
    func observeIncomingSMSMessages(_ userId: String) -> AnyPublisher<SMSResponse, Error> {
        let subject = PassthroughSubject<SMSResponse, Error>()

        print("📱 [FirebaseDatabaseService] Setting up incoming SMS listener for user: \(userId)")

        // Use collection group query to observe all messages across user's profiles
        // Only listen for NEW messages (direction: inbound, not yet processed)
        let listener = db.collectionGroup("messages")
            .whereField("userId", isEqualTo: userId)
            .whereField("direction", isEqualTo: "inbound")
            .order(by: "receivedAt", descending: true)
            .limit(to: 50) // Only recent messages to avoid loading history
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    let nsError = error as NSError
                    print("❌ [FirebaseDatabaseService] SMS listener error: \(error.localizedDescription)")
                    print("   - Error code: \(nsError.code)")
                    print("   - Error domain: \(nsError.domain)")
                    if nsError.code == 9 {
                        print("   - ⚠️ FAILED_PRECONDITION: This usually means a Firestore index is missing or still building")
                        print("   - Check Firebase Console > Firestore > Indexes")
                    }
                    subject.send(completion: .failure(error))
                    return
                }

                guard let snapshot = snapshot else {
                    print("⚠️ [FirebaseDatabaseService] SMS listener: no snapshot")
                    return
                }

                // Process only NEW messages (documentChanges with type .added)
                for change in snapshot.documentChanges {
                    guard change.type == .added else { continue }

                    let data = change.document.data()
                    print("📩 [FirebaseDatabaseService] New incoming SMS detected:")
                    print("   - Document ID: \(change.document.documentID)")
                    print("   - From: \(data["fromPhone"] as? String ?? "unknown")")
                    print("   - Message: \(data["messageBody"] as? String ?? "empty")")
                    print("   - Direction: \(data["direction"] as? String ?? "unknown")")

                    do {
                        // Convert Firestore message to SMSResponse
                        let smsResponse = try self.convertMessageToSMSResponse(data, documentId: change.document.documentID)
                        print("✅ [FirebaseDatabaseService] SMS converted to SMSResponse - broadcasting")
                        subject.send(smsResponse)
                    } catch {
                        print("❌ [FirebaseDatabaseService] Failed to convert message: \(error.localizedDescription)")
                    }
                }
            }

        listeners.append(listener)
        print("✅ [FirebaseDatabaseService] SMS listener registered")
        return subject.eraseToAnyPublisher()
    }

    /// Converts Firestore message document to SMSResponse model
    private func convertMessageToSMSResponse(_ data: [String: Any], documentId: String) throws -> SMSResponse {
        print("🔍 [FirebaseDatabaseService] Converting message document:")
        print("   - Raw data keys: \(data.keys.joined(separator: ", "))")
        print("   - fromPhone: \(data["fromPhone"] ?? "nil")")
        print("   - profileId: \(data["profileId"] ?? "nil")")
        print("   - userId: \(data["userId"] ?? "nil")")

        // Extract fields from Firestore message
        guard let fromPhone = data["fromPhone"] as? String,
              let messageBody = data["messageBody"] as? String,
              let receivedAtTimestamp = data["receivedAt"] as? Timestamp,
              let userId = data["userId"] as? String,
              let profileId = data["profileId"] as? String else {
            print("❌ [FirebaseDatabaseService] Missing required fields!")
            throw NSError(domain: "FirebaseDatabaseService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Missing required message fields"])
        }

        print("✅ [FirebaseDatabaseService] Successfully extracted profileId: \(profileId)")

        let receivedAt = receivedAtTimestamp.dateValue()
        let twilioSid = data["twilioSid"] as? String
        let numMedia = data["numMedia"] as? Int ?? 0
        let isOptOut = data["isOptOut"] as? Bool ?? false

        // Determine response type
        let responseType: ResponseType = numMedia > 0 ? .photo : .text

        // Analyze message sentiment
        let upperMessage = messageBody.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isPositive = upperMessage.contains("YES") ||
                        upperMessage.contains("DONE") ||
                        upperMessage.contains("OK") ||
                        upperMessage.contains("COMPLETED")

        let isConfirmation = upperMessage.contains("YES") || upperMessage.contains("CONFIRM")
        let isPositiveConfirmation = isConfirmation && isPositive

        // Use factory method for confirmation responses
        return SMSResponse.createConfirmationResponse(
            profileId: profileId,
            userId: userId,
            textResponse: messageBody,
            isPositive: isPositiveConfirmation
        )
    }

    // MARK: - Analytics and Reporting
    
    func getTaskCompletionStats(for userId: String, from startDate: Date, to endDate: Date) async throws -> TaskCompletionStats {
        // Use collection group queries for nested structure
        let tasksSnapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("nextScheduledDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()

        let completedSnapshot = try await db.collectionGroup("messages")
            .whereField("userId", isEqualTo: userId)
            .whereField("isCompleted", isEqualTo: true)
            .whereField("receivedAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("receivedAt", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        
        let totalTasks = tasksSnapshot.documents.count
        let completedTasks = completedSnapshot.documents.count
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        return TaskCompletionStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            completionRate: completionRate,
            averageResponseTime: 0, // Placeholder
            streakCount: 0, // Placeholder
            categoryBreakdown: [:], // Placeholder
            dailyCompletion: [:], // Placeholder
            responseTypeBreakdown: [:] // Placeholder
        )
    }
    
    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics {
        // Placeholder implementation
        return ProfileAnalytics(
            profileId: profileId,
            totalTasks: 0,
            completedTasks: 0,
            averageResponseTime: 0,
            lastActiveDate: nil,
            responseRate: 0,
            preferredResponseType: nil,
            bestPerformingCategory: nil,
            worstPerformingCategory: nil,
            weeklyTrend: []
        )
    }
    
    func getUserAnalytics(for userId: String) async throws -> UserAnalytics {
        // Placeholder implementation
        return UserAnalytics(
            userId: userId,
            totalProfiles: 0,
            activeProfiles: 0,
            totalTasks: 0,
            overallCompletionRate: 0,
            profileAnalytics: [],
            subscriptionUsage: SubscriptionUsage(
                planType: "trial",
                profilesUsed: 0,
                profilesLimit: 4,
                tasksCreated: 0,
                smssSent: 0,
                storageUsed: 0,
                billingPeriodStart: Date(),
                billingPeriodEnd: Date()
            ),
            generatedAt: Date()
        )
    }
    
    // MARK: - Batch Operations
    
    func batchUpdateTasks(_ tasks: [Task]) async throws {
        // Update each task individually using nested paths
        for task in tasks {
            try await updateTask(task)
        }
    }

    func batchDeleteTasks(_ taskIds: [String]) async throws {
        // Note: This method cannot be implemented without userId and profileId
        // Consider updating protocol to accept [(taskId, userId, profileId)] or Task objects
        throw DatabaseError.invalidData
    }

    func batchCreateSMSResponses(_ responses: [SMSResponse]) async throws {
        // Create each response individually using nested paths
        for response in responses {
            try await createSMSResponse(response)
        }
    }
    
    // MARK: - Search and Filtering
    
    func searchTasks(query: String, userId: String) async throws -> [Task] {
        // Use collection group query for nested structure
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            let task = try decodeFromFirestore(document.data(), as: Task.self)
            return task.title.lowercased().contains(query.lowercased()) ? task : nil
        }
    }
    
    func getTasksByCategory(_ category: TaskCategory, userId: String) async throws -> [Task] {
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("category", isEqualTo: category.rawValue)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func getTasksByStatus(_ status: TaskStatus, userId: String) async throws -> [Task] {
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: status.rawValue)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func getOverdueTasks(for userId: String) async throws -> [Task] {
        let now = Date()
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: TaskStatus.active.rawValue)
            .whereField("nextScheduledDate", isLessThan: Timestamp(date: now))
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    // MARK: - Data Synchronization
    
    func syncUserData(for userId: String) async throws {
        // Placeholder implementation
        print("Syncing user data for: \(userId)")
    }
    
    func getLastSyncTimestamp(for userId: String) async throws -> Date? {
        let document = try await CollectionPath.users.document(userId, in: db).getDocument()
        guard let data = document.data(),
              let timestamp = data["lastSyncTimestamp"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    func updateSyncTimestamp(for userId: String, timestamp: Date) async throws {
        try await CollectionPath.users.document(userId, in: db).updateData([
            "lastSyncTimestamp": Timestamp(date: timestamp)
        ])
    }
    
    // MARK: - Backup and Export
    
    func exportUserData(for userId: String) async throws -> UserDataExport {
        let user = try await getUser(userId)
        let profiles = try await getElderlyProfiles(for: userId)
        let tasks = try await getTasks(for: userId)
        let responses = try await getRecentSMSResponses(for: userId, limit: 1000)
        let analytics = try await getUserAnalytics(for: userId)
        
        return UserDataExport(
            userId: userId,
            user: user ?? User(id: userId, email: "", fullName: "", phoneNumber: "", createdAt: Date(), isOnboardingComplete: false, subscriptionStatus: .trial, trialEndDate: nil, quizAnswers: nil, profileCount: 0, taskCount: 0, updatedAt: Date(), lastSyncTimestamp: nil),
            profiles: profiles,
            tasks: tasks,
            responses: responses,
            analytics: analytics
        )
    }
    
    func importUserData(_ data: UserDataExport, for userId: String) async throws {
        // Placeholder implementation
        print("Importing user data for: \(userId)")
    }
    
    // MARK: - Helper Methods
    
    private func updateUserProfileCount(_ userId: String) async throws {
        // Count profiles in user's nested collection
        let profilesSnapshot = try await CollectionPath.userProfiles(userId: userId)
            .collection(in: db)
            .getDocuments()

        let profileCount = profilesSnapshot.documents.count

        // Use setData(merge: true) instead of updateData to create document if it doesn't exist
        try await CollectionPath.users.document(userId, in: db).setData([
            "profileCount": profileCount,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func updateUserTaskCount(_ userId: String) async throws {
        // Use collection group query to count all tasks across user's profiles
        let tasksSnapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let taskCount = tasksSnapshot.documents.count

        // Use setData(merge: true) instead of updateData to create document if it doesn't exist
        try await CollectionPath.users.document(userId, in: db).setData([
            "taskCount": taskCount,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    // MARK: - Encoding/Decoding Helpers
    
    private func encodeToFirestore<T: Codable>(_ object: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(object)
        let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dictionary ?? [:]
    }
    
    private func decodeFromFirestore<T: Codable>(_ data: [String: Any], as type: T.Type) throws -> T {
        // Convert Firestore Timestamps to Dates for JSON serialization
        let cleanedData = convertTimestampsToDates(data)
        let jsonData = try JSONSerialization.data(withJSONObject: cleanedData)

        // Configure decoder to handle timestamps as Unix epoch seconds
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        return try decoder.decode(type, from: jsonData)
    }

    /// Recursively converts Firestore Timestamp and Data objects for JSON serialization
    private func convertTimestampsToDates(_ data: Any) -> Any {
        if let timestamp = data as? Timestamp {
            // Convert Firestore Timestamp to Date, then to TimeInterval for JSON compatibility
            return timestamp.dateValue().timeIntervalSince1970
        } else if let binaryData = data as? Data {
            // Convert binary Data to base64 string for JSON compatibility
            return binaryData.base64EncodedString()
        } else if let dictionary = data as? [String: Any] {
            // Recursively process dictionary values
            return dictionary.mapValues { convertTimestampsToDates($0) }
        } else if let array = data as? [Any] {
            // Recursively process array elements
            return array.map { convertTimestampsToDates($0) }
        } else {
            // Return primitive types as-is
            return data
        }
    }
    
    deinit {
        // Remove all listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// Using DatabaseError from DatabaseServiceProtocol.swift

// MARK: - Recursive Delete Helper
extension FirebaseDatabaseService {
    /// Recursively deletes a document and all its subcollections
    /// - Parameters:
    ///   - docRef: The document reference to delete
    ///   - subcollections: Names of subcollections to delete (e.g., ["habits", "messages"])
    /// - Note: Handles batch size limits (500 operations per batch)
    private func deleteDocumentRecursively(
        _ docRef: DocumentReference,
        subcollections: [String]
    ) async throws {
        // Delete all subcollections first (depth-first traversal)
        for collectionName in subcollections {
            var hasMore = true

            // Handle batch size limit (500 documents per query)
            while hasMore {
                let snapshot = try await docRef.collection(collectionName)
                    .limit(to: 500)
                    .getDocuments()

                // If no documents, we're done with this subcollection
                if snapshot.documents.isEmpty {
                    hasMore = false
                    continue
                }

                // Delete each document (may have its own subcollections)
                for doc in snapshot.documents {
                    // Recursively delete nested subcollections
                    // Profiles have habits and messages, habits have no subcollections, messages have no subcollections
                    let nestedSubcollections = collectionName == "profiles" ? ["habits", "messages"] : []
                    try await deleteDocumentRecursively(
                        doc.reference,
                        subcollections: nestedSubcollections
                    )
                }

                // Check if there are more documents (500 is max per batch)
                hasMore = snapshot.documents.count == 500
            }
        }

        // After all subcollections deleted, delete the document itself
        try await docRef.delete()
    }

    /// Deletes a user and all associated data (profiles, habits, messages)
    /// - Parameter userId: The user's document ID
    /// - Note: Uses nested subcollections - Firestore automatically handles cascade
    func deleteUserRecursively(_ userId: String) async throws {
        let userRef = CollectionPath.users.document(userId, in: db)

        // Delete all nested subcollections under user
        // Order: profiles → (habits + messages nested under profiles) → gallery_events
        try await deleteDocumentRecursively(userRef, subcollections: ["profiles", "gallery_events"])
    }

    /// Deletes a profile and all associated habits/messages
    /// - Parameters:
    ///   - profileId: The profile's document ID
    ///   - userId: The user who owns this profile (for updating counts)
    /// - Note: Uses nested subcollections - deletes habits and messages automatically
    func deleteProfileRecursively(_ profileId: String, userId: String) async throws {
        let tracker = DiagnosticLogger.track(.schema, "Delete profile recursively", context: [
            "profileId": profileId,
            "userId": userId
        ])

        let profileRef = CollectionPath.userProfiles(userId: userId)
            .document(profileId, in: db)

        // Count items before deletion for verification
        let habitsSnapshot = try await profileRef.collection("habits").getDocuments()
        let messagesSnapshot = try await profileRef.collection("messages").getDocuments()

        // Also count gallery events linked to this profile
        let galleryEventsSnapshot = try await CollectionPath.userGalleryEvents(userId: userId)
            .collection(in: db)
            .whereField("profileId", isEqualTo: profileId)
            .getDocuments()

        DiagnosticLogger.info(.schema, "Found nested data", context: [
            "profileId": profileId,
            "habitsCount": habitsSnapshot.documents.count,
            "messagesCount": messagesSnapshot.documents.count,
            "galleryEventsCount": galleryEventsSnapshot.documents.count,
            "totalItems": habitsSnapshot.documents.count + messagesSnapshot.documents.count + galleryEventsSnapshot.documents.count
        ])

        let totalOps = habitsSnapshot.documents.count + messagesSnapshot.documents.count + 1
        if totalOps > 500 {
            DiagnosticLogger.warning(.schema, "⚠️ Operations exceed batch limit", context: [
                "totalOps": totalOps,
                "limit": 500,
                "willUseMultipleBatches": true
            ])
        }

        // Delete all nested subcollections under profile (habits and messages)
        try await deleteDocumentRecursively(profileRef, subcollections: ["habits", "messages"])

        // Process gallery events linked to this profile
        // Strategy: Keep photos (memories), delete text-only events (sensitive data)
        DiagnosticLogger.info(.schema, "Processing gallery events for profile", context: [
            "profileId": profileId,
            "galleryEventsCount": galleryEventsSnapshot.documents.count
        ])

        var dereferencedPhotos = 0
        var deletedTextOnlyEvents = 0

        for eventDoc in galleryEventsSnapshot.documents {
            let eventData = eventDoc.data()

            // Check if event contains photo data (nested in eventData field)
            let hasPhoto: Bool
            if let eventDataDict = eventData["eventData"] as? [String: Any],
               let photoData = eventDataDict["photoData"] {
                hasPhoto = !(photoData is NSNull)
            } else {
                hasPhoto = false
            }

            if hasPhoto {
                // Photo event - dereference profile but keep photo (preserve memory)
                try await eventDoc.reference.updateData([
                    "profileId": FieldValue.delete()
                ])
                dereferencedPhotos += 1
                DiagnosticLogger.debug(.schema, "Dereferenced photo event (kept photo)", context: [
                    "eventId": eventDoc.documentID,
                    "action": "removed profileId, kept photoData"
                ])
            } else {
                // Text-only event - safe to delete entirely (no memories lost)
                try await eventDoc.reference.delete()
                deletedTextOnlyEvents += 1
                DiagnosticLogger.debug(.schema, "Deleted text-only event", context: [
                    "eventId": eventDoc.documentID,
                    "action": "deleted entire event"
                ])
            }
        }

        DiagnosticLogger.success(.schema, "Gallery events processed", context: [
            "profileId": profileId,
            "dereferencedPhotos": dereferencedPhotos,
            "deletedTextOnlyEvents": deletedTextOnlyEvents
        ])

        // Verify deletion of habits and messages (gallery events intentionally kept if they have photos)
        let verifyHabits = try await profileRef.collection("habits").limit(to: 1).getDocuments()
        let verifyMessages = try await profileRef.collection("messages").limit(to: 1).getDocuments()

        if !verifyHabits.isEmpty || !verifyMessages.isEmpty {
            DiagnosticLogger.error(.schema, "❌ ORPHANED DATA DETECTED", context: [
                "profileId": profileId,
                "remainingHabits": verifyHabits.documents.count,
                "remainingMessages": verifyMessages.documents.count
            ])
        } else {
            DiagnosticLogger.success(.schema, "Profile data cleaned up successfully", context: [
                "profileId": profileId,
                "note": "Photo events dereferenced (kept), text-only events deleted"
            ])
        }

        // Update user's profile count
        try await updateUserProfileCount(userId)

        tracker.end(success: true, additionalContext: [
            "deletedHabits": habitsSnapshot.documents.count,
            "deletedMessages": messagesSnapshot.documents.count,
            "dereferencedPhotoEvents": dereferencedPhotos,
            "deletedTextOnlyEvents": deletedTextOnlyEvents
        ])
    }
}

// MARK: - Time Range Helper
enum FirebaseTimeRange {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case custom(Date, Date)
    
    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
            
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
            
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!
            return (startOfYear, endOfYear)
            
        case .custom(let start, let end):
            return (start, end)
        }
    }
}