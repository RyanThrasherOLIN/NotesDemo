// ColorPalette.swift
// Provides color palettes for normal and color-blind modes

import SwiftUI

/// Centralizes palette definitions and provides a dynamic access based on user settings.
struct ColorPalette {
    let primary: Color
    let secondary: Color
    let background: Color
    let accent: Color

    // MARK: - Static Presets
    static let standard = ColorPalette(
        primary: .primary,
        secondary: .secondary,
        background: Color(UIColor.systemBackground),
        accent: .blue
    )

    static let protanopia = ColorPalette(
        primary: .green,
        secondary: .yellow,
        background: Color(UIColor.systemBackground),
        accent: .orange
    )

    static let deuteranopia = ColorPalette(
        primary: .blue,
        secondary: .orange,
        background: Color(UIColor.systemBackground),
        accent: .purple
    )

    static let tritanopia = ColorPalette(
        primary: .red,
        secondary: .green,
        background: Color(UIColor.systemBackground),
        accent: .pink
    )

    static let achromatopsia = ColorPalette(
        primary: .gray,
        secondary: .gray.opacity(0.7),
        background: Color(UIColor.systemBackground),
        accent: .black
    )

    // MARK: - Dynamic Access
    /// Reads the user’s choice from UserDefaults and returns the active palette.
    static var current: ColorPalette {
        let raw = UserDefaults.standard.string(forKey: "colorBlindMode")
        let mode = ColorBlindMode(rawValue: raw ?? ColorBlindMode.normal.rawValue) ?? .normal
        return mode.palette()
    }
}
