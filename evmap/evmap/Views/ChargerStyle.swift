//
//  ChargerStyle.swift
//  evmap
//
//  Gemeinsame Darstellungs-Helfer für Charger (Farbcodierung nach Leistung).
//  Farben übernommen aus EVMap (Android) – res/values/colors.xml (charger_*).
//

import SwiftUI
import UIKit

enum ChargerStyle {
    /// Markerfarbe nach maximaler Ladeleistung – identisch zum Android-Original.
    static func color(forPower power: Double?) -> Color {
        switch power ?? 0 {
        case 100...: return Color(hex: 0xFDD835)   // ≥ 100 kW – gelb
        case 43..<100: return Color(hex: 0xFF9800) // ≥ 43 kW – orange
        case 20..<43: return Color(hex: 0x03A9F4)  // ≥ 20 kW – blau
        case 11..<20: return Color(hex: 0x9E9E9E)  // ≥ 11 kW – grau
        default: return Color(hex: 0x607D8B)       // < 11 kW – blaugrau
        }
    }

    static func uiColor(forPower power: Double?) -> UIColor {
        switch power ?? 0 {
        case 100...: return UIColor(hex: 0xFDD835)
        case 43..<100: return UIColor(hex: 0xFF9800)
        case 20..<43: return UIColor(hex: 0x03A9F4)
        case 11..<20: return UIColor(hex: 0x9E9E9E)
        default: return UIColor(hex: 0x607D8B)
        }
    }

    /// Kurzes Leistungslabel für Marker, z.B. "150".
    static func powerLabel(_ power: Double?) -> String {
        guard let power, power > 0 else { return "" }
        return String(Int(power.rounded()))
    }
}

extension Color {
    /// Erzeugt eine Farbe aus einem 0xRRGGBB-Hexwert.
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// EVMap-Markenfarben (aus Android colors.xml).
enum EVMapColor {
    static let primary = Color(hex: 0x4CAF50)   // Material-Grün
    static let available = Color(hex: 0x4CAF50)
    static let someAvailable = Color(hex: 0xFFC107)
    static let unavailable = Color(hex: 0xF44336)
}
