//
//  SettingsWindowController.swift
//  CIWatcher-macOS
//

import AppKit
import SwiftUI
import SharedCore

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show(ciService: CIService, updaterController: UpdaterController?) {
        if let window {
            presentWindow(window)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(ciService: ciService, updaterController: updaterController)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CIWatcher Settings"
        window.contentViewController = hostingController
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)

        self.window = window
        presentWindow(window)
    }

    private func presentWindow(_ window: NSWindow) {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
