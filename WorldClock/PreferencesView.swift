//
//  PreferencesView.swift
//  WorldClock
//
//  Created by Teesma M on 17/04/26.
//

import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var viewModel: ClockViewModel
    @State private var selectedTab = 0
 
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Menu Bar").tag(0)
                Text("Clock List").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
 
            Divider()
 
            if selectedTab == 0 {
                MenuBarZonesPane(viewModel: viewModel)
            } else {
                ClockListZonesPane(viewModel: viewModel)
            }
        }
        .frame(width: 700, height: 500)
        // Fix: capture the window reference so OK can close it reliably
        .background(WindowAccessor())
    }
}
 
// Captures the NSWindow so OK buttons can close it without relying on keyWindow
 
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            PrefsWindowStore.shared.window = v.window
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            PrefsWindowStore.shared.window = nsView.window
        }
    }
}
 
final class PrefsWindowStore {
    static let shared = PrefsWindowStore()
    weak var window: NSWindow?
    private init() {}
    func close() { window?.close() }
}
 
private func friendlyName(_ zone: String) -> String {
    let parts = zone.split(separator: "/")
    guard parts.count >= 2 else { return zone }
    let city   = parts.last!.replacingOccurrences(of: "_", with: " ")
    let region = parts.first!.replacingOccurrences(of: "_", with: " ")
    return "\(city), \(region)"
}
 
// Uses NSTextField subclass so focus ring + I-beam always work first click.
 
struct CursorSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
 
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.focusRingType = .exterior
        // Allow the field to receive the very first click without needing window focus
        field.refusesFirstResponder = false
        return field
    }
 
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }
 
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
 
    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func controlTextDidChange(_ obj: Notification) {
            if let f = obj.object as? NSSearchField { text = f.stringValue }
        }
    }
}

private struct CityRowContent: View {
    let zone: String
    let isSelected: Bool
    let isDisabled: Bool
    let showCheckmark: Bool
 
    var body: some View {
        HStack(spacing: 0) {
            Text(friendlyName(zone))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(rowForeground)
            Text(gmtOffset(zone))
                .frame(width: 80, alignment: .leading)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
        .opacity(isDisabled ? 0.38 : 1.0)
        .contentShape(Rectangle())
    }
 
    private var rowForeground: Color {
        isSelected ? .white : .primary
    }
 
    private func gmtOffset(_ id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "GMT" }
        let s = tz.secondsFromGMT()
        if s == 0 { return "GMT" }
        let h = s / 3600; let m = abs((s % 3600) / 60)
        return m == 0 ? String(format: "GMT%+d", h) : String(format: "GMT%+d:%02d", h, m)
    }
}
  
private struct SelectedZoneRow: View {
    let zone: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(friendlyName(zone))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(gmtOffset(zone))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
                .font(.caption)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
    
    private func gmtOffset(_ id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "GMT" }
        let s = tz.secondsFromGMT()
        if s == 0 { return "GMT" }
        let h = s / 3600; let m = abs((s % 3600) / 60)
        return m == 0 ? String(format: "GMT%+d", h) : String(format: "GMT%+d:%02d", h, m)
    }
}
  
struct MenuBarZonesPane: View {
    @ObservedObject var viewModel: ClockViewModel
    @State private var searchText = ""
    @State private var showMenuBarOptions = false
    
    // Cache the Set for O(1) lookups — avoids O(n) contains on every row render
    private var selectedSet: Set<String> { Set(viewModel.menuBarZones) }
    
    var filteredZones: [String] {
        guard !searchText.isEmpty else { return viewModel.allTimeZones }
        let q = searchText.lowercased()
        return viewModel.allTimeZones.filter { $0.lowercased().contains(q) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                
                // LEFT — all cities (List for reliable single-click)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose cities")
                        .font(.headline)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    
                    CursorSearchField(text: $searchText,
                                      placeholder: "Search for city or country")
                    .frame(height: 28)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    
                    HStack {
                        Text("City").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 80, alignment: .leading)
                        Spacer().frame(width: 18)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // List gives us NSTableView hit-testing — single click always works
                    List(filteredZones, id: \.self) { zone in
                        let isSelected = selectedSet.contains(zone)
                        let isAtLimit  = !isSelected && viewModel.menuBarZones.count >= viewModel.maxMenuBarZones
                        
                        CityRowContent(
                            zone: zone,
                            isSelected: isSelected,
                            isDisabled: isAtLimit,
                            showCheckmark: true
                        )
                        .onDrag {
                            NSItemProvider(object: zone as NSString)
                        }
                        .onTapGesture {
                            guard !isAtLimit else { return }
                            viewModel.toggleMenuBarZone(zone: zone)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    // Drop: dragging from right panel back to left removes the zone
                    .onDrop(of: [.plainText], isTargeted: nil) { providers in
                        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                            if let zone = item as? String {
                                DispatchQueue.main.async {
                                    viewModel.menuBarZones.removeAll { $0 == zone }
                                }
                            }
                        }
                        return true
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // RIGHT — selected zones with explicit ✕ remove button
                VStack(alignment: .leading, spacing: 0) {
                    Text("You can select only one city to show in the menu bar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("Menu Item").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 80, alignment: .leading)
                        Spacer().frame(width: 32)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    if viewModel.menuBarZones.isEmpty {
                        VStack {
                            Spacer()
                            Text("Your world clock is empty.\nDrag & drop cities from the left to get started.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        // Drop onto empty state
                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.menuBarZones.contains(zone),
                                              viewModel.menuBarZones.count < viewModel.maxMenuBarZones else { return }
                                        viewModel.menuBarZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    } else {
                        List {
                            ForEach(viewModel.menuBarZones, id: \.self) { zone in
                                SelectedZoneRow(zone: zone) {
                                    viewModel.menuBarZones.removeAll { $0 == zone }
                                }
                                .onDrag { NSItemProvider(object: zone as NSString) }
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowSeparator(.hidden)
                            }
                            .onMove { viewModel.moveMenuBarZones(from: $0, to: $1) }
                            .onDelete { viewModel.menuBarZones.remove(atOffsets: $0) }
                        }
                        .listStyle(.plain)
                        
                        // Drop onto populated list to add more (up to max)
                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.menuBarZones.contains(zone),
                                              viewModel.menuBarZones.count < viewModel.maxMenuBarZones else { return }
                                        viewModel.menuBarZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
        }
    }
}
        
struct ClockListZonesPane: View {
    @ObservedObject var viewModel: ClockViewModel
    @State private var searchText = ""
    
    private var selectedSet: Set<String> { Set(viewModel.selectedTimeZones) }
    
    var filteredZones: [String] {
        guard !searchText.isEmpty else { return viewModel.allTimeZones }
        let q = searchText.lowercased()
        return viewModel.allTimeZones.filter { $0.lowercased().contains(q) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                
                // LEFT — all cities
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose cities")
                        .font(.headline)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    
                    CursorSearchField(text: $searchText,
                                      placeholder: "Search for city or country")
                    .frame(height: 28)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    
                    HStack {
                        Text("City").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 80, alignment: .leading)
                        Spacer().frame(width: 18)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    List(filteredZones, id: \.self) { zone in
                        let isSelected = selectedSet.contains(zone)
                        let isAtLimit  = !isSelected && viewModel.selectedTimeZones.count >= viewModel.maxListZones
                        
                        CityRowContent(
                            zone: zone,
                            isSelected: isSelected,
                            isDisabled: isAtLimit,
                            showCheckmark: true
                        )
                        .onDrag {
                            NSItemProvider(object: zone as NSString)
                        }
                        .onTapGesture {
                            guard !isAtLimit else { return }
                            viewModel.toggleListZone(zone: zone)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .onDrop(of: [.plainText], isTargeted: nil) { providers in
                        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                            if let zone = item as? String {
                                DispatchQueue.main.async {
                                    viewModel.selectedTimeZones.removeAll { $0 == zone }
                                }
                            }
                        }
                        return true
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // RIGHT — selected clock list zones
                VStack(alignment: .leading, spacing: 0) {
                    Text("You can add up to \(viewModel.maxListZones) cities to track time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("City").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 80, alignment: .leading)
                        Spacer().frame(width: 32)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    if viewModel.selectedTimeZones.isEmpty {
                        VStack {
                            Spacer()
                            Text("Your world clock is empty.\nDrag & drop cities from the left to get started.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.selectedTimeZones.contains(zone),
                                              viewModel.selectedTimeZones.count < viewModel.maxListZones else { return }
                                        viewModel.selectedTimeZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    } else {
                        List {
                            ForEach(viewModel.selectedTimeZones, id: \.self) { zone in
                                SelectedZoneRow(zone: zone) {
                                    viewModel.selectedTimeZones.removeAll { $0 == zone }
                                }
                                .onDrag { NSItemProvider(object: zone as NSString) }
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowSeparator(.hidden)
                            }
                            .onMove { viewModel.selectedTimeZones.move(fromOffsets: $0, toOffset: $1) }
                            .onDelete { viewModel.selectedTimeZones.remove(atOffsets: $0) }
                        }
                        .listStyle(.plain)
                        
                        // Drop onto populated list to add more (up to max)
                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.selectedTimeZones.contains(zone),
                                              viewModel.selectedTimeZones.count < viewModel.maxListZones else { return }
                                        viewModel.selectedTimeZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
        }
    }
}
