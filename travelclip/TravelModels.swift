//
//  TravelModels.swift
//  travelclip
//

import SwiftUI

struct TravelNotebook: Identifiable, Codable {
    var id = UUID()
    var title: String
    var coverPageID: UUID?
    var coverImagePath: String?
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
    var canvasSize = CodableSize(width: 1080, height: 1920)
    var background = CanvasBackground()
    var elements: [CanvasElement] = []
    var viewportFrames: [CanvasViewportFrame] = []
    var updatedAt = Date()

    init(
        pageID: UUID,
        canvasSize: CodableSize = CodableSize(width: 1080, height: 1920),
        background: CanvasBackground = CanvasBackground(),
        elements: [CanvasElement] = [],
        viewportFrames: [CanvasViewportFrame] = [],
        updatedAt: Date = Date()
    ) {
        self.pageID = pageID
        self.canvasSize = canvasSize
        self.background = background
        self.elements = elements
        self.viewportFrames = viewportFrames
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageID = try container.decode(UUID.self, forKey: .pageID)
        canvasSize = try container.decodeIfPresent(CodableSize.self, forKey: .canvasSize) ?? CodableSize(width: 1080, height: 1920)
        background = try container.decodeIfPresent(CanvasBackground.self, forKey: .background) ?? CanvasBackground()
        elements = try container.decodeIfPresent([CanvasElement].self, forKey: .elements) ?? []
        viewportFrames = try container.decodeIfPresent([CanvasViewportFrame].self, forKey: .viewportFrames) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

struct CanvasViewportFrame: Identifiable, Codable {
    var id = UUID()
    var title: String
    var center: CodablePoint
    var zoom: CGFloat
    var createdAt = Date()
}

extension CanvasDocument {
    var centerPoint: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }
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
    var linkURL: String?
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var rotation: Double = 0
    var zIndex: Int
    var opacity: Double = 1
    var colorHex = "#2E2824"
    var fontName = "Georgia"
    var fontSize: CGFloat = 72
    var bold = false
    var italic = false
    var textAlignment = "center"
    var hidden = false
    var locked = false
    var shadow = false
    var stroke = false
    var cornerRadius: CGFloat = 28
    var blur: CGFloat = 0
    var brushWidth: CGFloat = 46
    var brushPoints: [CodablePoint] = []
    var groupID: UUID?
    var note: String?
    var connectorStartID: UUID?
    var connectorEndID: UUID?
    var connectorStartPoint: CodablePoint?
    var connectorEndPoint: CodablePoint?

    init(
        id: UUID = UUID(),
        kind: CanvasElementKind,
        text: String? = nil,
        symbol: String? = nil,
        localPath: String? = nil,
        linkURL: String? = nil,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        rotation: Double = 0,
        zIndex: Int,
        opacity: Double = 1,
        colorHex: String = "#2E2824",
        fontName: String = "Georgia",
        fontSize: CGFloat = 72,
        bold: Bool = false,
        italic: Bool = false,
        textAlignment: String = "center",
        hidden: Bool = false,
        locked: Bool = false,
        shadow: Bool = false,
        stroke: Bool = false,
        cornerRadius: CGFloat = 28,
        blur: CGFloat = 0,
        brushWidth: CGFloat = 46,
        brushPoints: [CodablePoint] = [],
        groupID: UUID? = nil,
        note: String? = nil,
        connectorStartID: UUID? = nil,
        connectorEndID: UUID? = nil,
        connectorStartPoint: CodablePoint? = nil,
        connectorEndPoint: CodablePoint? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.symbol = symbol
        self.localPath = localPath
        self.linkURL = linkURL
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
        self.zIndex = zIndex
        self.opacity = opacity
        self.colorHex = colorHex
        self.fontName = fontName
        self.fontSize = fontSize
        self.bold = bold
        self.italic = italic
        self.textAlignment = textAlignment
        self.hidden = hidden
        self.locked = locked
        self.shadow = shadow
        self.stroke = stroke
        self.cornerRadius = cornerRadius
        self.blur = blur
        self.brushWidth = brushWidth
        self.brushPoints = brushPoints
        self.groupID = groupID
        self.note = note
        self.connectorStartID = connectorStartID
        self.connectorEndID = connectorEndID
        self.connectorStartPoint = connectorStartPoint
        self.connectorEndPoint = connectorEndPoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(CanvasElementKind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        localPath = try container.decodeIfPresent(String.self, forKey: .localPath)
        linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
        x = try container.decode(CGFloat.self, forKey: .x)
        y = try container.decode(CGFloat.self, forKey: .y)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#2E2824"
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? "Georgia"
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 72
        bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        textAlignment = try container.decodeIfPresent(String.self, forKey: .textAlignment) ?? "center"
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        shadow = try container.decodeIfPresent(Bool.self, forKey: .shadow) ?? false
        stroke = try container.decodeIfPresent(Bool.self, forKey: .stroke) ?? false
        cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? 28
        blur = try container.decodeIfPresent(CGFloat.self, forKey: .blur) ?? 0
        brushWidth = try container.decodeIfPresent(CGFloat.self, forKey: .brushWidth) ?? 46
        brushPoints = try container.decodeIfPresent([CodablePoint].self, forKey: .brushPoints) ?? []
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        connectorStartID = try container.decodeIfPresent(UUID.self, forKey: .connectorStartID)
        connectorEndID = try container.decodeIfPresent(UUID.self, forKey: .connectorEndID)
        connectorStartPoint = try container.decodeIfPresent(CodablePoint.self, forKey: .connectorStartPoint)
        connectorEndPoint = try container.decodeIfPresent(CodablePoint.self, forKey: .connectorEndPoint)
    }
}

enum CanvasElementKind: String, Codable {
    case image
    case video
    case audio
    case sticker
    case text
    case tape
    case brush
    case shape
    case wordArt
    case link
    case file
    case connector
}

struct LinkCardParameters {
    var title: String = ""
    var url: String = ""
    var colorHex: String = "#2E2824"
}

enum CanvasSelectionAlignment {
    case left
    case centerX
    case right
    case top
    case centerY
    case bottom
}

enum CanvasDistributionAxis {
    case horizontal
    case vertical
}

enum ConnectorEndpoint: Equatable {
    case start
    case end
}

struct StickerDefinition: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let colorHex: String
    let width: CGFloat
    let height: CGFloat
}

struct MaterialGroup: Identifiable {
    let id: String
    let title: String
    let country: String
    let city: String
    let tags: [String]
    let items: [MaterialItem]
}

struct MaterialItem: Identifiable {
    let id: String
    let groupID: String
    let title: String
    let fileName: String
    let fileURL: URL
    let country: String
    let city: String
    let category: String?
    let latitude: Double?
    let longitude: Double?
    let tags: [String]
}

struct TapeGroup: Identifiable {
    let id: String
    let title: String
    let tags: [String]
    let items: [TapeDefinition]
}

struct TapeDefinition: Identifiable {
    let id: String
    let title: String
    let groupID: String
    let fileName: String?
    let fileURL: URL?
    let colorHex: String
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let tags: [String]

    init(
        id: String,
        title: String,
        groupID: String = "basic",
        fileName: String? = nil,
        fileURL: URL? = nil,
        colorHex: String,
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.groupID = groupID
        self.fileName = fileName
        self.fileURL = fileURL
        self.colorHex = colorHex
        self.width = width
        self.height = height
        self.rotation = rotation
        self.tags = tags
    }
}

enum TicketKind: String, Codable, CaseIterable {
    case flight
    case train
    case ferry
    case movie
    case event

    var label: String {
        switch self {
        case .flight: return "Flight"
        case .train: return "Train"
        case .ferry: return "Ferry"
        case .movie: return "Movie"
        case .event: return "Event"
        }
    }
}

struct TicketFields: Codable, Equatable {
    var origin: String
    var destination: String
    var date: String
    var time: String
    var seat: String
    var gate: String
    var className: String
    var reference: String
}

struct TicketTemplateDefinition: Identifiable, Codable {
    let id: String
    let kind: TicketKind
    let title: String
    let headline: String
    let accentHex: String
    let paperHex: String
    let fields: TicketFields
}

struct ShapeDefinition: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let colorHex: String
    let width: CGFloat
    let height: CGFloat
    let stroke: Bool
    let cornerRadius: CGFloat
}

struct BackgroundDefinition: Identifiable {
    let id: String
    let title: String
    let colorA: String
    let colorB: String
}

struct TextPresetDefinition: Identifiable {
    let id: String
    let title: String
    let previewText: String
    let style: TextStyleParameters
    let kind: CanvasElementKind
}

struct BrushPresetDefinition: Identifiable {
    let id: String
    let title: String
    let colorHex: String
    let width: CGFloat
    let opacity: Double
    let points: [CodablePoint]
}

enum CanvasInsertError: Error, LocalizedError {
    case pageMissing
    case emptySelection
    case emptyText
    case emptyURL
    case photoDataUnavailable
    case unsupportedImageData
    case imageEncodingFailed
    case clipboardEmpty
    case assetUnavailable
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .pageMissing:
            return "The canvas is being restored. Try adding the item again."
        case .emptySelection:
            return "No item was selected."
        case .emptyText:
            return "Enter text before adding it to the canvas."
        case .emptyURL:
            return "Enter a URL before adding a link."
        case .photoDataUnavailable:
            return "The selected photo could not be loaded. If it is in iCloud, wait for it to download and try again."
        case .unsupportedImageData:
            return "The selected image format is not supported."
        case .imageEncodingFailed:
            return "The selected photo could not be prepared for the canvas."
        case .clipboardEmpty:
            return "Copy an image, link, or text before pasting to the canvas."
        case .assetUnavailable:
            return "The selected asset could not be prepared for the canvas."
        case .writeFailed(let detail):
            return detail.isEmpty ? "The selected item could not be saved." : detail
        }
    }
}

struct PageTemplateDefinition: Identifiable {
    let id: String
    let title: String
    let background: CanvasBackground
    let elements: [CanvasElement]
}

struct TextStyleParameters {
    var text: String
    var fontName: String = "Georgia"
    var fontSize: CGFloat = 78
    var colorHex: String = "#2E2824"
    var bold: Bool = true
    var italic: Bool = false
    var alignment: String = "center"
    var width: CGFloat = 680
}

struct CodableSize: Codable {
    var width: CGFloat
    var height: CGFloat

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }

    func matches(_ other: CodableSize, tolerance: CGFloat = 1) -> Bool {
        abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
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

extension CanvasElement {
    var bounds: CGRect {
        CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
    }

    var supportsLineWidth: Bool {
        kind == .connector ||
            kind == .brush ||
            (kind == .shape && (symbol == "line" || symbol == "arrow"))
    }
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
