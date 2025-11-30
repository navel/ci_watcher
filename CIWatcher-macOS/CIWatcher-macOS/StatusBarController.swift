//
//  StatusBarController.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import AppKit
import SwiftUI
import SharedCore

class StatusBarController: ObservableObject {
    private var statusBarItem: NSStatusItem?
    private var popover: NSPopover?
    private var menu: NSMenu?
    
    @Published var statusEmoji: String = "⚪"
    
    init() {
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.action = #selector(handleClick)
            button.target = self
            button.toolTip = "CIWatcher"
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        setupMenu()
        updateStatusEmoji("⚪")
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open", action: #selector(togglePopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CIWatcher", action: #selector(quitApp), keyEquivalent: "q"))
        
        menu.items.forEach { $0.target = self }
        self.menu = menu
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // Right click: show menu
            statusBarItem?.menu = menu
            statusBarItem?.button?.performClick(nil)
            statusBarItem?.menu = nil
        } else {
            // Left click: toggle popover
            togglePopover()
        }
    }
    
    @objc private func openSettings() {
        // Use the standard way to open Settings window
        // This is equivalent to what SettingsLink does
        if #available(macOS 13.0, *) {
            if NSApp.responds(to: Selector(("showSettingsWindow:"))) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        } else {
            if NSApp.responds(to: Selector(("showPreferencesWindow:"))) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateStatusEmoji(_ emoji: String) {
        statusEmoji = emoji
        if let button = statusBarItem?.button {
            button.title = emoji
        }
    }
    
    @objc private func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        } else {
            // Only create popover if contentView is available
            guard contentView != nil else { return }
            createPopover()
            showPopover()
        }
    }
    
    private var contentView: ContentView?
    
    private func createPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        
        // Use stored contentView (should always be set via updateContentView)
        if let contentView = contentView {
            popover.contentViewController = NSHostingController(rootView: contentView)
        }
        
        self.popover = popover
    }
    
    func updateContentView(_ view: ContentView) {
        contentView = view
        if let hostingController = popover?.contentViewController as? NSHostingController<ContentView> {
            hostingController.rootView = view
        } else if popover != nil {
            popover?.contentViewController = NSHostingController(rootView: view)
        }
    }
    
    private func showPopover() {
        guard let popover = popover,
              let button = statusBarItem?.button else { return }
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    
    private func closePopover() {
        popover?.performClose(nil)
    }
}

