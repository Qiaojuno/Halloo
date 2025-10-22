//
//  ImageCacheService.swift
//  Halloo
//
//  Purpose: Memory-based image caching for profile photos
//  Prevents AsyncImage flicker when switching tabs by pre-loading images
//
//  Created by Claude Code on 2025-10-21
//

import SwiftUI
import Combine

/// Memory-based image cache for profile photos
///
/// This service pre-loads profile photos into memory when profiles are loaded,
/// eliminating the brief "empty state" flicker from AsyncImage when switching tabs.
///
/// ## Architecture:
/// - Uses NSCache for automatic memory management
/// - Pre-loads images when profiles are added to AppState
/// - Provides synchronous access to cached images
/// - Cleans up automatically when memory pressure occurs
///
/// ## Usage:
/// ```swift
/// // Pre-load profile photos
/// await imageCache.preloadProfileImages(profiles)
///
/// // Get cached image synchronously
/// if let image = imageCache.getCachedImage(for: profilePhotoURL) {
///     // Use image directly
/// }
/// ```
final class ImageCacheService: ObservableObject {

    // MARK: - Cache Storage

    /// Memory-based cache using NSCache for automatic memory management
    /// NSCache automatically evicts objects when memory pressure occurs
    private let cache = NSCache<NSString, UIImage>()

    /// Published dictionary for SwiftUI reactive updates
    /// Maps photo URL to loaded status (allows views to observe loading state)
    @Published private(set) var loadedImages: Set<String> = []

    // MARK: - Initialization

    init() {
        // Configure cache limits
        cache.countLimit = 20 // Max 20 images (4 profiles × up to 5 images each)
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit for profile photos
    }

    // MARK: - Public API

    /// Get cached image synchronously (no flicker)
    ///
    /// - Parameter url: The photo URL string
    /// - Returns: Cached UIImage if available, nil otherwise
    func getCachedImage(for url: String?) -> UIImage? {
        guard let url = url, !url.isEmpty else { return nil }
        return cache.object(forKey: url as NSString)
    }

    /// Pre-load profile images into cache
    ///
    /// Call this when profiles are loaded to pre-populate the cache.
    /// Images are loaded asynchronously in parallel.
    ///
    /// - Parameter profiles: Array of profiles with photoURL to cache
    func preloadProfileImages(_ profiles: [ElderlyProfile]) async {
        print("🖼️ [ImageCache] Pre-loading \(profiles.count) profile images...")

        // Load all profile images in parallel
        await withTaskGroup(of: Void.self) { group in
            for profile in profiles {
                guard let urlString = profile.photoURL,
                      !urlString.isEmpty,
                      let url = URL(string: urlString) else {
                    continue
                }

                // Skip if already cached
                if cache.object(forKey: urlString as NSString) != nil {
                    print("✅ [ImageCache] Already cached: \(profile.name)")
                    continue
                }

                group.addTask {
                    await self.loadAndCacheImage(url: url, key: urlString, profileName: profile.name)
                }
            }
        }

        print("✅ [ImageCache] Profile images pre-loaded - \(loadedImages.count) total cached")
    }

    /// Pre-load gallery photos into cache
    ///
    /// Call this when gallery events are loaded to pre-populate the cache.
    /// Only caches profile creation photos (photoURL), not task response photos (photoData).
    ///
    /// - Parameter events: Array of gallery events with photoURL to cache
    func preloadGalleryPhotos(_ events: [GalleryHistoryEvent]) async {
        print("🖼️ [ImageCache] Pre-loading gallery photos...")

        var photoCount = 0

        // Load all gallery photos in parallel
        await withTaskGroup(of: Void.self) { group in
            for event in events {
                // Only cache profile creation events with photoURL
                // Task response photos use photoData (already fast, no cache needed)
                guard case .profileCreated(let data) = event.eventData,
                      let urlString = data.photoURL,
                      !urlString.isEmpty,
                      let url = URL(string: urlString) else {
                    continue
                }

                // Skip if already cached (might be a profile photo too!)
                if cache.object(forKey: urlString as NSString) != nil {
                    print("✅ [ImageCache] Gallery photo already cached: \(event.id)")
                    continue
                }

                photoCount += 1
                group.addTask {
                    await self.loadAndCacheImage(url: url, key: urlString, profileName: "Gallery-\(event.id)")
                }
            }
        }

        print("✅ [ImageCache] Gallery photos pre-loaded - \(photoCount) new, \(loadedImages.count) total cached")
    }

    /// Load a single image and cache it
    ///
    /// - Parameters:
    ///   - url: The image URL
    ///   - key: The cache key (usually the URL string)
    ///   - profileName: Profile name for logging
    private func loadAndCacheImage(url: URL, key: String, profileName: String) async {
        do {
            // Download image data
            let (data, response) = try await URLSession.shared.data(from: url)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ [ImageCache] Invalid response for \(profileName)")
                return
            }

            // Create UIImage from data
            guard let image = UIImage(data: data) else {
                print("❌ [ImageCache] Failed to create image for \(profileName)")
                return
            }

            // Cache the image with cost (estimated memory size)
            let cost = data.count
            await MainActor.run {
                cache.setObject(image, forKey: key as NSString, cost: cost)
                loadedImages.insert(key)
            }

            print("✅ [ImageCache] Cached image for \(profileName) (\(cost / 1024)KB)")

        } catch {
            print("❌ [ImageCache] Failed to load image for \(profileName): \(error)")
        }
    }

    /// Remove specific image from cache
    ///
    /// - Parameter url: The photo URL to remove
    func removeImage(for url: String?) {
        guard let url = url, !url.isEmpty else { return }
        cache.removeObject(forKey: url as NSString)
        loadedImages.remove(url)
    }

    /// Clear all cached images
    func clearCache() {
        cache.removeAllObjects()
        loadedImages.removeAll()
        print("🗑️ [ImageCache] Cache cleared")
    }
}
