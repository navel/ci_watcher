import Foundation
#if !APPSTORE
import Sparkle

/// Manages automatic updates via Sparkle (GitHub Releases appcast).
final class UpdaterController {
    private let controller: SPUStandardUpdaterController?
    
    var isAvailable: Bool { controller != nil }
    
    init() {
        if Self.isSparkleConfigured {
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            controller = nil
        }
    }
    
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
    
    private static var isSparkleConfigured: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return false
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = Data(base64Encoded: trimmed) else {
            return false
        }
        return data.count == 32
    }
}
#else
/// App Store builds use App Store for updates — Sparkle is disabled.
final class UpdaterController {
    func checkForUpdates() {}
}
#endif
