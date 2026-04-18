//
//  ClockListView.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import SwiftUI
import AppKit
 
struct ClockListView: View {
 
    @ObservedObject var viewModel: ClockViewModel
 
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
 
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
 
            Text("World Clock")
                .font(.headline)
 
            if viewModel.clocks.isEmpty {
                Text("No time zones selected.\nOpen Preferences to add some.")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.clocks) { entry in
                    HStack {
                        Text(entry.city)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(timeString(for: entry.timeZone))
                            .monospacedDigit()
                    }
                }
            }
 
            Divider()
 
            Button("Preferences…") {
                openPreferences()
            }
 
            Button("Quit World Clock") {
                NSApp.terminate(nil)
            }
            .foregroundColor(.red)
        }
        .padding(16)
        .frame(width: 280)
        .onReceive(timer) { now = $0 }
    }
 
    func timeString(for tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.timeStyle = .medium
        return f.string(from: now)
    }
 
    func openPreferences() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.popover.performClose(nil)
        }

        // If window already exists, shake it instead of opening a new one
        if let existing = PrefsWindowStore.shared.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            existing.shake()
            return
        }

        let vc = NSHostingController(rootView: PreferencesView(viewModel: viewModel))
        let window = NSWindow(contentViewController: vc)
        window.title = "World Clock Preferences"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension NSWindow {
    func shake() {
        let numberOfShakes = 4
        let duration = 0.4
        let amplitude: CGFloat = 8

        let frame = self.frame
        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.duration = duration
        animation.repeatCount = 1
        animation.autoreverses = false

        var values: [NSValue] = []
        for i in 0...numberOfShakes * 2 {
            let x = (i % 2 == 0) ? frame.midX - amplitude : frame.midX + amplitude
            values.append(NSValue(point: NSPoint(x: x, y: frame.midY)))
        }
        values.append(NSValue(point: NSPoint(x: frame.midX, y: frame.midY)))
        animation.values = values

        self.animations = ["position": animation]
        self.animator().setFrame(frame, display: true)
    }
}
