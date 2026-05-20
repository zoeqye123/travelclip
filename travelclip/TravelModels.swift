//
//  TravelModels.swift
//  travelclip
//

import SwiftUI

struct TravelNotebook: Identifiable, Codable {
    var id = UUID()
    var title: String
    var coverPageID: UUID?
    var createdAt = Date()
    var updatedAt = Date()
    var tintName: String
    var symbol: String

    var tint: Color {
        switch tintName {
        case "sage": return .sage
        case "mist": return .mist
        case "clay": return .clay
        case "rose": return .rose
        default: return .sand
        }
    }
}

struct JournalPage: Identifiable, Codable {
    var id = UUID()
    var notebookID: UUID
    var title: String
    var sortIndex: Int
    var canvasDocument: CanvasDocument
    var updatedAt = Date()
}

struct CanvasDocument: Codable {
    var pageID: UUID
    var canvasSize = CodableSize(width: 1080, height: 1440)
    var background = CanvasBackground()
    var elements: [CanvasElement] = []
    var updatedAt = Date()
}

struct CanvasBackground: Codable {
    var id = UUID()
    var colorA = "#FDF7EA"
    var colorB = "#E8F1ED"
    var mode = "fill"

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: colorA), Color(hex: colorB)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CanvasElement: Identifiable, Codable {
    var id = UUID()
    var kind: CanvasElementKind
    var text: String?
    var symbol: String?
    var localPath: String?
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var rotation: Double = 0
    var zIndex: Int
    var opacity: Double = 1
    var colorHex = "#2E2824"
    var fontSize: CGFloat = 72
    var bold = false
}

enum CanvasElementKind: String, Codable {
    case image
    case sticker
    case text
}

struct CodableSize: Codable {
    var width: CGFloat
    var height: CGFloat
}

enum PageTemplate {
    case blank
    case postcard
}

struct LocalSnapshot: Codable {
    var notebooks: [TravelNotebook]
    var pages: [JournalPage]
}

struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let selected: Bool
}

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
