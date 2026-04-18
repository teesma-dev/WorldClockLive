//
//  AppDelegate.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
 
    // One status item per visible menu-bar zone
    private var statusItems: [String: NSStatusItem] = [:]
    private var clockTimer: Timer?
 
    let viewModel = ClockViewModel()
    var popover = NSPopover()
    var eventMonitor: Any?
 
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire view-model callback → rebuild status items
        viewModel.onMenuBarChanged = { [weak self] in
            self?.rebuildStatusItems()
        }
 
        // Initial build
        rebuildStatusItems()
 
        // Popover
        popover.contentSize  = NSSize(width: 300, height: 400)
        popover.behavior     = .transient
        popover.contentViewController =
            NSHostingController(rootView: ClockListView(viewModel: viewModel))
 
        // Dismiss popover on outside click
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }
 
        // Tick every second to update time strings in menu bar
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatusItemTitles()
        }
    }
  
    private func rebuildStatusItems() {
        // Remove all existing items
        for item in statusItems.values {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()
 
        let clocks = viewModel.menuBarClocks   // already filtered by showInMenuBar
 
        if clocks.isEmpty {
            // Always show at least the globe icon so the user can open preferences
            let fallback = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            fallback.button?.image = NSImage(
                systemSymbolName: "globe",
                accessibilityDescription: "World Clock"
            )
            fallback.button?.action   = #selector(togglePopover)
            fallback.button?.target   = self
            statusItems["__fallback__"] = fallback
        } else {
            for clock in clocks {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                item.button?.title  = titleString(for: clock)
                item.button?.action = #selector(togglePopover)
                item.button?.target = self
                statusItems[clock.id.uuidString] = item
            }
        }
    }
 
    private func updateStatusItemTitles() {
        let clocks = viewModel.menuBarClocks
        let pairs  = zip(clocks, statusItems.values.sorted { _ , _ in true })
        for (clock, item) in pairs {
            item.button?.title = titleString(for: clock)
        }
    }
 
    private func titleString(for clock: ClockEntry) -> String {
        let f = DateFormatter()
        f.timeZone = clock.timeZone
        f.timeStyle = .short
        f.dateStyle = .none
        return "\(clock.city): \(f.string(from: Date()))"
    }
  
    @objc func togglePopover() {
        // Use the first status item button as the anchor
        guard let button = statusItems.values.first?.button else { return }
 
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
