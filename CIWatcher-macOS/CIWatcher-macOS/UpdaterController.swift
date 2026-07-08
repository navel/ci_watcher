import Foundation
#if !APPSTORE
import Sparkle

/// Manages automatic updates via Sparkle (GitHub Releases appcast).
final class UpdaterController {
    private let controller: SPUStandardUpdaterController
    
    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#else
/// App Store builds use App Store for updates — Sparkle is disabled.
final class UpdaterController {
    func checkForUpdates() {}
}
#endif
