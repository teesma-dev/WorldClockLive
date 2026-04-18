//
//  ClockEntry.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import Foundation

struct ClockEntry: Identifiable {
    let id = UUID()
    let city: String
    let timeZone: TimeZone
}
