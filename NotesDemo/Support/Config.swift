// Config.swift
// NotesDemo
//
// Centralized, user-editable API URL configuration.
// Reads from UserDefaults("apiURL") and falls back to a default.
import Foundation

struct Config {
    /// The default endpoint used if the user hasn't overridden it.
    private static let fallback = "http://10.77.0.11:5000"

    /// The current API URL as a String, from AppStorage / UserDefaults.
    static var apiURLString: String {
        UserDefaults.standard.string(forKey: "apiURL") ?? fallback
    }

    /// The current API URL as a URL. Crashes early if malformed.
    static var baseURL: URL {
        guard let url = URL(string: apiURLString) else {
            fatalError("Invalid API URL in UserDefaults: \(apiURLString)")
        }
        return url
    }
}
