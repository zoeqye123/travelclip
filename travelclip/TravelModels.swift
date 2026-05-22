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
    var colorA = "#FFFFFF"
    var colorB = "#FFFFFF"
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
    var hidden = false
    var locked = false
    var shadow = false
    var stroke = false
    var cornerRadius: CGFloat = 28
    var blur: CGFloat = 0
    var brushWidth: CGFloat = 46
    var brushPoints: [CodablePoint] = []

    init(
        id: UUID = UUID(),
        kind: CanvasElementKind,
        text: String? = nil,
        symbol: String? = nil,
        localPath: String? = nil,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        rotation: Double = 0,
        zIndex: Int,
        opacity: Double = 1,
        colorHex: String = "#2E2824",
        fontSize: CGFloat = 72,
        bold: Bool = false,
        hidden: Bool = false,
        locked: Bool = false,
        shadow: Bool = false,
        stroke: Bool = false,
        cornerRadius: CGFloat = 28,
        blur: CGFloat = 0,
        brushWidth: CGFloat = 46,
        brushPoints: [CodablePoint] = []
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.symbol = symbol
        self.localPath = localPath
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
        self.zIndex = zIndex
        self.opacity = opacity
        self.colorHex = colorHex
        self.fontSize = fontSize
        self.bold = bold
        self.hidden = hidden
        self.locked = locked
        self.shadow = shadow
        self.stroke = stroke
        self.cornerRadius = cornerRadius
        self.blur = blur
        self.brushWidth = brushWidth
        self.brushPoints = brushPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(CanvasElementKind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        localPath = try container.decodeIfPresent(String.self, forKey: .localPath)
        x = try container.decode(CGFloat.self, forKey: .x)
        y = try container.decode(CGFloat.self, forKey: .y)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#2E2824"
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 72
        bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        shadow = try container.decodeIfPresent(Bool.self, forKey: .shadow) ?? false
        stroke = try container.decodeIfPresent(Bool.self, forKey: .stroke) ?? false
        cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? 28
        blur = try container.decodeIfPresent(CGFloat.self, forKey: .blur) ?? 0
        brushWidth = try container.decodeIfPresent(CGFloat.self, forKey: .brushWidth) ?? 46
        brushPoints = try container.decodeIfPresent([CodablePoint].self, forKey: .brushPoints) ?? []
    }
}

enum CanvasElementKind: String, Codable {
    case image
    case sticker
    case text
    case tape
    case brush
    case wordArt
}

struct CodableSize: Codable {
    var width: CGFloat
    var height: CGFloat
}

struct CodablePoint: Codable {
    var x: CGFloat
    var y: CGFloat

    var point: CGPoint {
        CGPoint(x: x, y: y)
    }

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }
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
