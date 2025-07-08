// ChatMessage.swift
import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
  var id: String        // ← was UUID
  var text: String
}
