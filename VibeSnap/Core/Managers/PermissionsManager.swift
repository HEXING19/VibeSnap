import Foundation
import ScreenCaptureKit

/// Singleton manager for handling system permissions required by VibeSnap
final class PermissionsManager {
    static let shared = PermissionsManager()
    
    private init() {}
    
    /// Check if screen capture permission is granted
    var hasScreenCapturePermission: Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    /// Request screen capture permission from the system
    /// - Parameter completion: Callback with the result (true if granted)
    func requestScreenCapturePermission(completion: @escaping (Bool) -> Void) {
        // First check if already granted
        if hasScreenCapturePermission {
            completion(true)
            return
        }
        
        // Request permission - this will prompt the user
        let granted = CGRequestScreenCaptureAccess()
        completion(granted)
    }
    
    /// Verify permissions are available before capture operations
    /// - Returns: True if all required permissions are granted
    func verifyAllPermissions() -> Bool {
        return hasScreenCapturePermission
    }
}
