//
//  ClockViewModel.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import Foundation
import SwiftUI

struct MenuBarZoneSettings: Codable, Equatable {
    var showInMenuBar: Bool = true
    var clockLabel: String = ""
}
 
class ClockViewModel: ObservableObject {
 
    // Zones shown in the Clock List popover (max 6)
    @Published var selectedTimeZones: [String] = [] {
        didSet {
            UserDefaults.standard.set(selectedTimeZones, forKey: "zones")
        }
    }
 
    // Zones shown in the Menu Bar (max 4)
    @Published var menuBarZones: [String] = [] {
        didSet {
            UserDefaults.standard.set(menuBarZones, forKey: "menuBarZones")
            notifyMenuBarChanged()
        }
    }
 
    // Per-zone settings (show/hide, label, style, overnight)
    @Published var menuBarZoneSettings: [String: MenuBarZoneSettings] = [:] {
        didSet {
            if let encoded = try? JSONEncoder().encode(menuBarZoneSettings) {
                UserDefaults.standard.set(encoded, forKey: "menuBarZoneSettings")
            }
            notifyMenuBarChanged()
        }
    }
 
    let maxListZones  = 4
    let maxMenuBarZones = 1
 
    // AppDelegate observes this to rebuild NSStatusItems
    var onMenuBarChanged: (() -> Void)?
 
    init() {
        if let saved = UserDefaults.standard.array(forKey: "zones") as? [String] {
            selectedTimeZones = saved
        } else {
            selectedTimeZones = ["Asia/Kolkata", "America/New_York", "Europe/London"]
        }
 
        if let saved = UserDefaults.standard.array(forKey: "menuBarZones") as? [String] {
            menuBarZones = saved
        } else {
            menuBarZones = ["Europe/London"]
        }
 
        if let data = UserDefaults.standard.data(forKey: "menuBarZoneSettings"),
           let decoded = try? JSONDecoder().decode([String: MenuBarZoneSettings].self, from: data) {
            menuBarZoneSettings = decoded
        }
    }
  
    var clocks: [ClockEntry] {
        selectedTimeZones.compactMap {
            guard let tz = TimeZone(identifier: $0) else { return nil }
            return ClockEntry(city: cityName(from: $0), timeZone: tz)
        }
    }
 
    // Only zones where showInMenuBar == true
    var menuBarClocks: [ClockEntry] {
        menuBarZones.compactMap { zone in
            let s = menuBarZoneSettings[zone, default: MenuBarZoneSettings()]
            guard s.showInMenuBar, let tz = TimeZone(identifier: zone) else { return nil }
            let label = s.clockLabel.isEmpty ? cityName(from: zone) : s.clockLabel
            return ClockEntry(city: label, timeZone: tz)
        }
    }
 
    var allTimeZones: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }
  
    func settingsBinding(for zone: String) -> Binding<MenuBarZoneSettings> {
        Binding(
            get: { self.menuBarZoneSettings[zone, default: MenuBarZoneSettings()] },
            set: { self.menuBarZoneSettings[zone] = $0 }
        )
    }
  
    func toggleListZone(zone: String) {
        if selectedTimeZones.contains(zone) {
            selectedTimeZones.removeAll { $0 == zone }
        } else {
            guard selectedTimeZones.count < maxListZones else { return }
            selectedTimeZones.append(zone)
        }
    }
 
    func toggleMenuBarZone(zone: String) {
        if menuBarZones.contains(zone) {
            menuBarZones.removeAll { $0 == zone }
        } else {
            guard menuBarZones.count < maxMenuBarZones else { return }
            menuBarZones.append(zone)
        }
    }
 
    func moveMenuBarZones(from source: IndexSet, to destination: Int) {
        menuBarZones.move(fromOffsets: source, toOffset: destination)
    }
 
    func applyMenuBarVisibility() {
        notifyMenuBarChanged()
    }
  
    func cityName(from zone: String) -> String {
        zone.split(separator: "/").last?
            .replacingOccurrences(of: "_", with: " ") ?? zone
    }
 
    func gmtOffset(for identifier: String) -> String {
        guard let tz = TimeZone(identifier: identifier) else { return "GMT" }
        let seconds = tz.secondsFromGMT()
        if seconds == 0 { return "GMT" }
        let hours   = seconds / 3600
        let minutes = abs((seconds % 3600) / 60)
        return minutes == 0
            ? String(format: "GMT%+d", hours)
            : String(format: "GMT%+d:%02d", hours, minutes)
    }
 
    private func notifyMenuBarChanged() {
        DispatchQueue.main.async { self.onMenuBarChanged?() }
    }
}
