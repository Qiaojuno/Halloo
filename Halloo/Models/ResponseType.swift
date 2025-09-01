import Foundation
import SwiftUI

// MARK: - Response Type
enum ResponseType: String, CaseIterable, Codable {
    case text = "text"
    case photo = "photo"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .photo:
            return "Photo"
        case .both:
            return "Text & Photo"
        }
    }
    
    var description: String {
        switch self {
        case .text:
            return "Text response only"
        case .photo:
            return "Photo response only"
        case .both:
            return "Both text and photo required"
        }
    }
    
    var icon: String {
        switch self {
        case .text:
            return "text.bubble"
        case .photo:
            return "camera"
        case .both:
            return "text.bubble.fill"
        }
    }
    
    var requiresText: Bool {
        return self == .text || self == .both
    }
    
    var requiresPhoto: Bool {
        return self == .photo || self == .both
    }
}