import Foundation
import ScreenCaptureKit
import AppKit

/// Manager for handling screenshot capture operations
final class CaptureManager {
    static let shared = CaptureManager()
    
    private init() {}
    
    /// Find the display that contains the given rectangle
    /// - Parameters:
    ///   - rect: The rectangle in screen coordinates
    ///   - displays: Array of available displays
    /// - Returns: The display containing the rect, or the first display as fallback
    private func findDisplay(containing rect: CGRect, from displays: [SCDisplay]) -> SCDisplay? {
        // Find display that contains the center point of the rect
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        
        // Check each display's frame
        for display in displays {
            let displayFrame = CGRect(
                x: CGFloat(display.frame.origin.x),
                y: CGFloat(display.frame.origin.y),
                width: CGFloat(display.width),
                height: CGFloat(display.height)
            )
            
            if displayFrame.contains(centerPoint) {
                return display
            }
        }
        
        // Fallback: find display with largest intersection
        var bestDisplay: SCDisplay?
        var largestIntersection: CGFloat = 0
        
        for display in displays {
            let displayFrame = CGRect(
                x: CGFloat(display.frame.origin.x),
                y: CGFloat(display.frame.origin.y),
                width: CGFloat(display.width),
                height: CGFloat(display.height)
            )
            
            let intersection = displayFrame.intersection(rect)
            let intersectionArea = intersection.width * intersection.height
            
            if intersectionArea > largestIntersection {
                largestIntersection = intersectionArea
                bestDisplay = display
            }
        }
        
        return bestDisplay ?? displays.first
    }
    
    /// Capture a specific area of the screen
    /// - Parameter rect: The rectangle area to capture (in NSScreen coordinates)
    /// - Parameter completion: Callback with the captured image or error
    func captureArea(rect: CGRect, completion: @escaping (Result<NSImage, Error>) -> Void) {
        Task {
            do {
                // Get shareable content - include all windows
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                // Find which NSScreen contains this rect
                var targetNSScreen: NSScreen?
                let rectCenter = CGPoint(x: rect.midX, y: rect.midY)
                for screen in NSScreen.screens {
                    if screen.frame.contains(rectCenter) {
                        targetNSScreen = screen
                        break
                    }
                }
                
                guard let nsScreen = targetNSScreen else {
                    completion(.failure(CaptureError.noDisplayFound))
                    return
                }
                
                // Find matching SCDisplay by comparing sizes and X origin
                // NSScreen and SCDisplay have same size but different Y origins
                var matchedDisplay: SCDisplay?
                for display in content.displays {
                    if Int(display.width) == Int(nsScreen.frame.width) && 
                       Int(display.height) == Int(nsScreen.frame.height) &&
                       Int(display.frame.origin.x) == Int(nsScreen.frame.origin.x) {
                        matchedDisplay = display
                        break
                    }
                }
                
                guard let display = matchedDisplay else {
                    completion(.failure(CaptureError.noDisplayFound))
                    return
                }
                
                // Convert NSScreen rect to display-relative coordinates
                let nsScreenRelativeX = rect.origin.x - nsScreen.frame.origin.x
                let nsScreenRelativeY = rect.origin.y - nsScreen.frame.origin.y
                
                // Get windows belonging to this app to exclude them from capture
                let currentBundleId = Bundle.main.bundleIdentifier
                let windowsToCapture = content.windows.filter { window in
                    window.owningApplication?.bundleIdentifier != currentBundleId && window.isOnScreen
                }
                
                // Create a filter that captures only the windows we want (all except our app's windows)
                let filter = SCContentFilter(display: display, including: windowsToCapture)
                
                // Configure the stream
                let config = SCStreamConfiguration()
                
                // Set explicit width and height based on display size with scale factor
                let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
                config.width = Int(CGFloat(display.width) * scaleFactor)
                config.height = Int(CGFloat(display.height) * scaleFactor)
                config.captureResolution = .best
                config.scalesToFit = false
                config.showsCursor = false
                
                // Capture the entire display
                let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                
                // Calculate the crop rectangle in pixel coordinates
                // The captured image is display-relative, so use display-relative coordinates
                // NSScreen Y=0 is at bottom, but image Y=0 is at top, so flip
                let pixelRect = CGRect(
                    x: nsScreenRelativeX * scaleFactor,
                    y: (CGFloat(display.height) - nsScreenRelativeY - rect.height) * scaleFactor,
                    width: rect.width * scaleFactor,
                    height: rect.height * scaleFactor
                )
                
                // Crop the image to the selected area
                if let croppedImage = fullImage.cropping(to: pixelRect) {
                    let nsImage = NSImage(cgImage: croppedImage, size: NSSize(width: rect.width, height: rect.height))
                    completion(.success(nsImage))
                } else {
                    completion(.failure(CaptureError.unknown))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Capture a specific window
    /// - Parameter window: The window to capture
    /// - Parameter completion: Callback with the captured image or error
    func captureWindow(window: SCWindow, completion: @escaping (Result<NSImage, Error>) -> Void) {
        Task {
            do {
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.captureResolution = .best
                config.scalesToFit = false
                config.showsCursor = false
                
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let nsImage = NSImage(cgImage: image, size: NSSize(width: window.frame.width, height: window.frame.height))
                completion(.success(nsImage))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Capture the entire screen
    /// - Parameter completion: Callback with the captured image or error
    func captureFullscreen(completion: @escaping (Result<NSImage, Error>) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    completion(.failure(CaptureError.noDisplayFound))
                    return
                }
                
                // Get windows belonging to this app to exclude them from capture
                let currentBundleId = Bundle.main.bundleIdentifier
                let windowsToCapture = content.windows.filter { window in
                    window.owningApplication?.bundleIdentifier != currentBundleId && window.isOnScreen
                }
                
                // Create a filter that captures only the windows we want (all except our app's windows)
                let filter = SCContentFilter(display: display, including: windowsToCapture)
                let config = SCStreamConfiguration()
                
                // Fix: Set explicit width and height based on display size with scale factor
                let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
                config.width = Int(CGFloat(display.width) * scaleFactor)
                config.height = Int(CGFloat(display.height) * scaleFactor)
                config.captureResolution = .best
                config.scalesToFit = false
                config.showsCursor = false
                
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let nsImage = NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))
                completion(.success(nsImage))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Get all available windows for selection
    func getAvailableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        return content.windows.filter { $0.isOnScreen }
    }
}

enum CaptureError: LocalizedError {
    case noDisplayFound
    case capturePermissionDenied
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for capture"
        case .capturePermissionDenied:
            return "Screen capture permission denied"
        case .unknown:
            return "Unknown capture error"
        }
    }
}
