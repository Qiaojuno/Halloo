import Foundation

protocol VersionedModel: Codable {
    var version: Int { get set }
    var lastModified: Date { get set }
    var modifiedBy: String? { get set }
}

struct VersionConflict: Error {
    let localVersion: Int
    let remoteVersion: Int
    let fieldName: String
    let localValue: Any
    let remoteValue: Any
    
    var localizedDescription: String {
        return "Version conflict on \(fieldName): local version \(localVersion) vs remote version \(remoteVersion)"
    }
}

class OptimisticLockingManager {
    
    enum ConflictResolution {
        case useLocal
        case useRemote
        case merge(resolver: (Any, Any) -> Any)
        case askUser
    }
    
    static func checkVersion<T: VersionedModel>(local: T, remote: T) throws {
        if local.version != remote.version {
            throw VersionConflict(
                localVersion: local.version,
                remoteVersion: remote.version,
                fieldName: "document",
                localValue: local,
                remoteValue: remote
            )
        }
    }
    
    static func resolveConflict<T: VersionedModel>(
        local: inout T,
        remote: T,
        resolution: ConflictResolution
    ) -> T {
        switch resolution {
        case .useLocal:
            local.version = remote.version + 1
            local.lastModified = Date()
            return local
            
        case .useRemote:
            var updated = remote
            updated.version = remote.version + 1
            updated.lastModified = Date()
            return updated
            
        case .merge(let resolver):
            var merged = resolver(local, remote) as! T
            merged.version = max(local.version, remote.version) + 1
            merged.lastModified = Date()
            return merged
            
        case .askUser:
            return remote
        }
    }
}

extension ElderlyProfile: VersionedModel {
    var version: Int {
        get { return 1 }
        set { }
    }
    
    var lastModified: Date {
        get { return lastActiveAt }
        set { lastActiveAt = newValue }
    }
    
    var modifiedBy: String? {
        get { return userId }
        set { }
    }
}

extension Task: VersionedModel {
    var version: Int {
        get { return 1 }
        set { }
    }

    var lastModified: Date {
        get { return lastModifiedAt }
        set { lastModifiedAt = newValue }
    }

    var modifiedBy: String? {
        get { return userId }
        set { }
    }
}