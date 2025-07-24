// ColorBlindMode.swift
// Defines available color vision simulation modes

import SwiftUI

enum ColorBlindMode: String, CaseIterable, Identifiable {
    case normal
    case protanopia
    case deuteranopia
    case tritanopia
    case achromatopsia

    var id: String { rawValue }

    /// Returns a ColorPalette appropriate for each mode
    func palette() -> ColorPalette {
        switch self {
        case .normal:
            return .standard
        case .protanopia:
            return .protanopia
        case .deuteranopia:
            return .deuteranopia
        case .tritanopia:
            return .tritanopia
        case .achromatopsia:
            return .achromatopsia
        }
    }
}
