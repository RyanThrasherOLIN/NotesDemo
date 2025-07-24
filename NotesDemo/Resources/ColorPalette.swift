// ColorPalette.swift
// Provides accessible color palettes for normal, color-blind, and high-contrast modes

import SwiftUI

struct ColorPalette {
    let primary: Color
    let secondary: Color
    let background: Color
    let accent: Color

    // MARK: - Static Presets

    /// Normal vision palette
    static let standard = ColorPalette(
        primary: .primary,
        secondary: .gray,
        background: Color(UIColor.systemBackground),
        accent: Color(red: 0.0, green: 0.48, blue: 1.0) // system blue
    )

    /// Protanopia-friendly palette
    static let protanopia = ColorPalette(
        primary: Color(red: 0.0, green: 0.6, blue: 0.6),     // teal
        secondary: Color(red: 1.0, green: 0.84, blue: 0.0),   // gold
        background: Color(UIColor.systemBackground),
        accent: Color(red: 0.2, green: 0.2, blue: 0.7)        // navy blue
    )

    /// Deuteranopia-friendly palette
    static let deuteranopia = ColorPalette(
        primary: Color(red: 0.0, green: 0.65, blue: 0.9),     // cyan
        secondary: Color(red: 1.0, green: 0.6, blue: 0.0),    // orange
        background: Color(UIColor.systemBackground),
        accent: Color(red: 0.3, green: 0.2, blue: 0.6)        // indigo
    )

    /// Tritanopia-friendly palette
    static let tritanopia = ColorPalette(
        primary: Color(red: 1.0, green: 0.45, blue: 0.2),     // reddish-orange
        secondary: Color(red: 0.0, green: 0.7, blue: 0.6),    // turquoise
        background: Color(UIColor.systemBackground),
        accent: Color(red: 0.4, green: 0.2, blue: 0.6)        // violet
    )

    /// Achromatopsia (grayscale) palette
    static let achromatopsia = ColorPalette(
        primary: Color(white: 0.2),       // dark gray
        secondary: Color(white: 0.6),     // light gray
        background: Color(UIColor.systemBackground),
        accent: .black
    )

    /// High-contrast palette for users with low vision
    static let highContrast = ColorPalette(
        primary: .black,
        secondary: .white,
        background: .yellow,              // high luminance contrast
        accent: Color(red: 1.0, green: 0.0, blue: 0.0) // bright red
    )

    // MARK: - Dynamic Access

    static var current: ColorPalette {
        let raw = UserDefaults.standard.string(forKey: "colorBlindMode")
        let mode = ColorBlindMode(rawValue: raw ?? ColorBlindMode.normal.rawValue) ?? .normal
        return mode.palette()
    }
}
