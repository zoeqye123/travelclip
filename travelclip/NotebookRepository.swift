//
//  NotebookRepository.swift
//  travelclip
//

import Combine
import PhotosUI
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum MaterialGroupScanner {
    static func scan() -> [MaterialGroup] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let structuredRoot = resourceURL.appendingPathComponent("Resources/MaterialGroups", isDirectory: true)
        let structuredGroups = scanDirectory(rootURL: structuredRoot)
        if !structuredGroups.isEmpty {
            return structuredGroups
        }
        return scanFlattenedBundle(resourceURL: resourceURL)
    }

    private static func scanDirectory(rootURL: URL) -> [MaterialGroup] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var groups: [MaterialGroup] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let imageURLs = imageFiles(in: url)
            guard !imageURLs.isEmpty else { continue }
            let relativeGroupID = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            let groupID = relativeGroupID.replacingOccurrences(of: "/", with: "-")
            let pathParts = relativeGroupID.split(separator: "/").map(String.init)
            let country = pathParts.first ?? url.deletingLastPathComponent().lastPathComponent
            let city = pathParts.dropFirst().first ?? url.lastPathComponent
            let title = titleized(pathParts.last ?? url.lastPathComponent)
            let groupTags = Array(Set((pathParts + tokens(from: relativeGroupID)).map { $0.lowercased() })).sorted()
            let items = imageURLs.enumerated().map { offset, imageURL -> MaterialItem in
                let parsed = parseMaterialFileName(imageURL.deletingPathExtension().lastPathComponent)
                let itemTags = parsed.tags + groupTags + tokens(from: imageURL.lastPathComponent)
                return MaterialItem(
                    id: "\(groupID)-\(imageURL.lastPathComponent)-\(offset)",
                    groupID: groupID,
                    title: parsed.title,
                    fileName: imageURL.lastPathComponent,
                    fileURL: imageURL,
                    country: parsed.country ?? country,
                    city: parsed.city ?? city,
                    category: parsed.category,
                    latitude: parsed.latitude,
                    longitude: parsed.longitude,
                    tags: Array(Set(itemTags.map { $0.lowercased() })).sorted(),
                    accessLevel: parsed.category?.lowercased().contains("premium") == true ? .premium : .free
                )
            }

            groups.append(MaterialGroup(id: groupID, title: title, country: country, city: city, tags: groupTags, items: items))
        }
        return groups.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func scanFlattenedBundle(resourceURL: URL) -> [MaterialGroup] {
        let images = imageFiles(in: resourceURL)
        let grouped = Dictionary(grouping: images) { imageURL in
            let parsed = parseMaterialFileName(imageURL.deletingPathExtension().lastPathComponent)
            return [parsed.country, parsed.city, parsed.category].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "-")
        }

        return grouped.compactMap { rawGroupID, imageURLs -> MaterialGroup? in
            let groupID = rawGroupID.isEmpty ? "materials" : rawGroupID
            let firstParsed = parseMaterialFileName(imageURLs[0].deletingPathExtension().lastPathComponent)
            let country = firstParsed.country ?? "global"
            let city = firstParsed.city ?? ""
            let groupTags = Array(Set(tokens(from: groupID))).sorted()
            let items = imageURLs.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                .enumerated()
                .map { offset, imageURL -> MaterialItem in
                    let parsed = parseMaterialFileName(imageURL.deletingPathExtension().lastPathComponent)
                    let itemTags = parsed.tags + groupTags + tokens(from: imageURL.lastPathComponent)
                return MaterialItem(
                    id: "\(groupID)-\(imageURL.lastPathComponent)-\(offset)",
                    groupID: groupID,
                    title: parsed.title,
                    fileName: imageURL.lastPathComponent,
                    fileURL: imageURL,
                    country: parsed.country ?? country,
                    city: parsed.city ?? city,
                    category: parsed.category,
                    latitude: parsed.latitude,
                    longitude: parsed.longitude,
                    tags: Array(Set(itemTags.map { $0.lowercased() })).sorted(),
                    accessLevel: parsed.category?.lowercased().contains("premium") == true ? .premium : .free
                )
            }

            guard !items.isEmpty else { return nil }
            return MaterialGroup(id: groupID, title: titleized(groupID), country: country, city: city, tags: groupTags, items: items)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func imageFiles(in directory: URL) -> [URL] {
        let allowed = Set(["png", "jpg", "jpeg", "webp"])
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func tokens(from value: String) -> [String] {
        value
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(separator: " ")
            .map { String($0).lowercased() }
    }

    private static func titleized(_ value: String) -> String {
        tokens(from: value).map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    private static func parseMaterialFileName(_ stem: String) -> (country: String?, city: String?, category: String?, latitude: Double?, longitude: Double?, title: String, tags: [String]) {
        let parts = stem.split(separator: "__", omittingEmptySubsequences: false).map(String.init)
        var country: String?
        var city: String?
        var category: String?
        var latitude: Double?
        var longitude: Double?
        var titlePart = stem
        var tags: [String] = []

        for part in parts {
            if let separator = part.firstIndex(of: "-") {
                let key = String(part[..<separator]).lowercased()
                let value = String(part[part.index(after: separator)...])
                switch key {
                case "country":
                    country = value.lowercased()
                    tags.append(value)
                case "city":
                    city = value.lowercased()
                    tags.append(value)
                case "cat", "category":
                    category = value.lowercased()
                    tags.append(value)
                case "lat":
                    latitude = Double(value)
                    tags.append("lat-\(value)")
                case "lng", "lon":
                    longitude = Double(value)
                    tags.append("lng-\(value)")
                case "name", "title":
                    titlePart = value
                case "tags":
                    tags += value.split(separator: "-").map(String.init)
                default:
                    break
                }
            }
        }

        if parts.count > 1, titlePart == stem {
            titlePart = parts.last ?? stem
        }

        tags += tokens(from: stem)
        if latitude != nil || longitude != nil {
            tags.append("geo")
            tags.append("location")
        }
        return (
            country: country,
            city: city,
            category: category,
            latitude: latitude,
            longitude: longitude,
            title: titleized(titlePart),
            tags: Array(Set(tags.map { $0.lowercased() })).sorted()
        )
    }
}

private enum TapeGroupScanner {
    static func scan() -> [TapeGroup] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let structuredRoot = resourceURL.appendingPathComponent("Resources/TapeGroups", isDirectory: true)
        let structuredGroups = scanDirectory(rootURL: structuredRoot)
        if !structuredGroups.isEmpty {
            return structuredGroups
        }
        return scanFlattenedBundle(resourceURL: resourceURL)
    }

    private static func scanDirectory(rootURL: URL) -> [TapeGroup] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var groups: [TapeGroup] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let imageURLs = imageFiles(in: url)
            guard !imageURLs.isEmpty else { continue }
            let relativeGroupID = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            let groupID = relativeGroupID.replacingOccurrences(of: "/", with: "-")
            let groupTags = tokens(from: relativeGroupID)
            let title = titleized(url.lastPathComponent)
            let items = imageURLs.enumerated().map { offset, imageURL in
                tapeDefinition(
                    imageURL: imageURL,
                    groupID: groupID,
                    groupTags: groupTags,
                    offset: offset
                )
            }
            groups.append(TapeGroup(id: groupID, title: title, tags: groupTags, items: items))
        }
        return groups.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func scanFlattenedBundle(resourceURL: URL) -> [TapeGroup] {
        let images = imageFiles(in: resourceURL)
        let grouped = Dictionary(grouping: images) { imageURL in
            let stem = imageURL.deletingPathExtension().lastPathComponent
            return stem.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? "tapes"
        }

        return grouped.compactMap { groupID, imageURLs in
            let sortedImages = imageURLs.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            let groupTags = tokens(from: groupID)
            let title = titleized(groupID)
            let items = sortedImages.enumerated().map { offset, imageURL in
                tapeDefinition(
                    imageURL: imageURL,
                    groupID: groupID,
                    groupTags: groupTags,
                    offset: offset
                )
            }
            return TapeGroup(id: groupID, title: title, tags: groupTags, items: items)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func tapeDefinition(
        imageURL: URL,
        groupID: String,
        groupTags: [String],
        offset: Int
    ) -> TapeDefinition {
        let fileName = imageURL.lastPathComponent
        let image = UIImage(contentsOfFile: imageURL.path)
        let imageSize = image?.size ?? CGSize(width: 800, height: 72)
        let aspect = max(imageSize.width / max(imageSize.height, 1), 1)
        let height = min(max(imageSize.height, 64), 110)
        let width = min(max(height * aspect * 1.7, 920), 1500)
        return TapeDefinition(
            id: "\(groupID)-\(fileName)-\(offset)",
            title: titleized(imageURL.deletingPathExtension().lastPathComponent),
            groupID: groupID,
            fileName: fileName,
            fileURL: imageURL,
            colorHex: "#F6E6B8",
            width: width,
            height: height,
            rotation: 0,
            tags: Array(Set((groupTags + tokens(from: fileName)).map { $0.lowercased() })).sorted()
        )
    }

    private static func imageFiles(in directory: URL) -> [URL] {
        let allowed = Set(["png", "jpg", "jpeg", "webp"])
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func tokens(from value: String) -> [String] {
        value
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(separator: " ")
            .map { String($0).lowercased() }
    }

    private static func titleized(_ value: String) -> String {
        tokens(from: value).map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

@MainActor
final class NotebookRepository: ObservableObject {
    static let defaultNotebookTitle = "My Travel Clips"

    @Published private(set) var notebooks: [TravelNotebook] = []
    @Published private(set) var pages: [JournalPage] = []
    @Published private(set) var canvasRevision = 0
    @Published private(set) var selectedElementIDs: Set<UUID> = []
    private lazy var cachedMaterialGroups: [MaterialGroup] = MaterialGroupScanner.scan()
    private lazy var cachedTapeGroups: [TapeGroup] = TapeGroupScanner.scan()
    private lazy var cachedTicketTemplates: [TicketTemplateDefinition] = TicketTemplateLibrary.load()

    let stickerLibrary: [StickerDefinition] = [
        StickerDefinition(id: "sparkles-rust", title: "Sparkles", symbol: "sparkles", colorHex: "#C4563F", width: 190, height: 170),
        StickerDefinition(id: "map-pin", title: "Pin", symbol: "mappin.and.ellipse", colorHex: "#7AA08C", width: 210, height: 190),
        StickerDefinition(id: "camera", title: "Camera", symbol: "camera.fill", colorHex: "#A9C0D2", width: 205, height: 180),
        StickerDefinition(id: "plane", title: "Plane", symbol: "airplane.departure", colorHex: "#B77255", width: 230, height: 170),
        StickerDefinition(id: "heart", title: "Heart", symbol: "heart.fill", colorHex: "#D99A8C", width: 180, height: 165),
        StickerDefinition(id: "leaf", title: "Leaf", symbol: "leaf.fill", colorHex: "#6F9D86", width: 180, height: 165)
    ]

    let tapeLibrary: [TapeDefinition] = [
        TapeDefinition(id: "kraft", title: "Kraft", colorHex: "#E0B56D", width: 760, height: 92, rotation: -3),
        TapeDefinition(id: "sage", title: "Sage", colorHex: "#A8C8B6", width: 720, height: 88, rotation: 4, accessLevel: .premium),
        TapeDefinition(id: "rose", title: "Rose", colorHex: "#D99A8C", width: 700, height: 86, rotation: -6, accessLevel: .premium),
        TapeDefinition(id: "mist", title: "Mist", colorHex: "#9DB7D1", width: 740, height: 90, rotation: 5)
    ]

    let shapeLibrary: [ShapeDefinition] = [
        ShapeDefinition(id: "note-rect", title: "Rect", symbol: "rectangle", colorHex: "#F2C078", width: 430, height: 290, stroke: false, cornerRadius: 32),
        ShapeDefinition(id: "circle", title: "Circle", symbol: "circle", colorHex: "#9DB7D1", width: 310, height: 310, stroke: false, cornerRadius: 155),
        ShapeDefinition(id: "outline", title: "Outline", symbol: "rounded-rect-outline", colorHex: "#6F9D86", width: 480, height: 300, stroke: true, cornerRadius: 28),
        ShapeDefinition(id: "triangle", title: "Triangle", symbol: "triangle", colorHex: "#B77255", width: 320, height: 280, stroke: false, cornerRadius: 0),
        ShapeDefinition(id: "line", title: "Line", symbol: "line", colorHex: "#2E2824", width: 520, height: 54, stroke: false, cornerRadius: 0)
    ]

    let backgroundLibrary: [BackgroundDefinition] = [
        BackgroundDefinition(id: "plain", title: "Plain", colorA: "#FFFFFF", colorB: "#FFFFFF"),
        BackgroundDefinition(id: "postcard", title: "Postcard", colorA: "#FDF0D6", colorB: "#E4F1EC"),
        BackgroundDefinition(id: "rose-mist", title: "Rose", colorA: "#F6E6E8", colorB: "#EAF1F7"),
        BackgroundDefinition(id: "warm-paper", title: "Paper", colorA: "#FBF8F0", colorB: "#EDE4D1"),
        BackgroundDefinition(id: "garden", title: "Garden", colorA: "#E8F2EE", colorB: "#FFF7E6")
    ]

    let textPresetLibrary: [TextPresetDefinition] = [
        TextPresetDefinition(
            id: "caption-serif",
            title: "Caption",
            previewText: "tiny moments",
            style: TextStyleParameters(text: "tiny moments", fontName: "Georgia", fontSize: 68, colorHex: "#2E2824", bold: true, alignment: "center", width: 680),
            kind: .text
        ),
        TextPresetDefinition(
            id: "label-rounded",
            title: "Label",
            previewText: "day one",
            style: TextStyleParameters(text: "day one", fontName: "Avenir Next", fontSize: 54, colorHex: "#6F9D86", bold: true, alignment: "center", width: 520),
            kind: .text
        ),
        TextPresetDefinition(
            id: "note-body",
            title: "Note",
            previewText: "write it down",
            style: TextStyleParameters(text: "write it down", fontName: "Georgia", fontSize: 48, colorHex: "#4A403A", bold: false, alignment: "leading", width: 650),
            kind: .text
        )
    ]

    let wordArtLibrary: [TextPresetDefinition] = [
        TextPresetDefinition(
            id: "wordart-travel",
            title: "Travel",
            previewText: "Travel",
            style: TextStyleParameters(text: "Travel", fontName: "Snell Roundhand", fontSize: 96, colorHex: "#B77255", bold: true, alignment: "center", width: 740),
            kind: .wordArt
        ),
        TextPresetDefinition(
            id: "wordart-memory",
            title: "Memory",
            previewText: "Memory",
            style: TextStyleParameters(text: "Memory", fontName: "Georgia", fontSize: 88, colorHex: "#C4563F", bold: true, italic: true, alignment: "center", width: 720),
            kind: .wordArt
        ),
        TextPresetDefinition(
            id: "wordart-route",
            title: "Route",
            previewText: "Route Notes",
            style: TextStyleParameters(text: "Route Notes", fontName: "Avenir Next", fontSize: 78, colorHex: "#7AA08C", bold: true, alignment: "center", width: 760),
            kind: .wordArt
        )
    ]

    let brushPresetLibrary: [BrushPresetDefinition] = [
        BrushPresetDefinition(
            id: "brush-swoosh",
            title: "Swoosh",
            colorHex: "#B77255",
            width: 44,
            opacity: 0.7,
            points: [
                CodablePoint(x: 40, y: 112),
                CodablePoint(x: 150, y: 54),
                CodablePoint(x: 286, y: 86),
                CodablePoint(x: 430, y: 126),
                CodablePoint(x: 590, y: 72)
            ]
        ),
        BrushPresetDefinition(
            id: "brush-highlight",
            title: "Highlight",
            colorHex: "#D6A858",
            width: 58,
            opacity: 0.52,
            points: [
                CodablePoint(x: 36, y: 86),
                CodablePoint(x: 188, y: 74),
                CodablePoint(x: 350, y: 94),
                CodablePoint(x: 520, y: 82),
                CodablePoint(x: 650, y: 90)
            ]
        ),
        BrushPresetDefinition(
            id: "brush-loop",
            title: "Loop",
            colorHex: "#7E8EAB",
            width: 34,
            opacity: 0.72,
            points: [
                CodablePoint(x: 46, y: 96),
                CodablePoint(x: 126, y: 42),
                CodablePoint(x: 214, y: 118),
                CodablePoint(x: 310, y: 48),
                CodablePoint(x: 420, y: 120),
                CodablePoint(x: 558, y: 70)
            ]
        )
    ]

    var materialGroups: [MaterialGroup] {
        cachedMaterialGroups
    }

    var tapeGroups: [TapeGroup] {
        cachedTapeGroups
    }

    var availableTapeGroups: [TapeGroup] {
        let scanned = tapeGroups
        guard !scanned.isEmpty else {
            return [TapeGroup(id: "basic", title: "Basic", tags: ["basic", "color"], items: tapeLibrary)]
        }
        return scanned + [TapeGroup(id: "basic", title: "Basic", tags: ["basic", "color"], items: tapeLibrary)]
    }

    var ticketTemplates: [TicketTemplateDefinition] {
        cachedTicketTemplates
    }

    var templateLibrary: [PageTemplateDefinition] {
        PageTemplateLibrary.builtIn
    }

    var selectedElementID: UUID? {
        get {
            pages
                .flatMap(\.canvasDocument.elements)
                .filter { selectedElementIDs.contains($0.id) }
                .max { $0.zIndex < $1.zIndex }?
                .id
        }
        set { setSelectedElementIDs(newValue.map { [$0] } ?? []) }
    }

    private let fileManager = FileManager.default
    private var undoStacks: [UUID: [CanvasDocument]] = [:]
    private var redoStacks: [UUID: [CanvasDocument]] = [:]
    private var draftPageIDs: Set<UUID> = []
    private var pendingSaveTask: Task<Void, Never>?

    private var databaseURL: URL {
        documentsURL.appendingPathComponent("travelclip-local-database.json")
    }

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var assetsURL: URL {
        documentsURL.appendingPathComponent("TravelClipAssets", isDirectory: true)
    }

    func imageURL(for localPath: String?) -> URL? {
        guard let localPath, !localPath.isEmpty else { return nil }
        let directURL = URL(fileURLWithPath: localPath)
        if fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }

        let assetName = directURL.lastPathComponent
        guard !assetName.isEmpty else { return nil }
        let migratedURL = assetsURL.appendingPathComponent(assetName)
        if fileManager.fileExists(atPath: migratedURL.path) {
            return migratedURL
        }

        if let recoveredURL = recoverBundledAsset(named: assetName) {
            return recoveredURL
        }

        if let suffixURL = recoverAssetBySuffix(assetName) {
            return suffixURL
        }

        return nil
    }

    @discardableResult
    private func ensureWritablePage(_ pageID: UUID, title: String = "Recovered Page") -> Bool {
        ensurePageExists(pageID, title: title)
    }

    private func verifiedAssetURL(for fileName: String) -> URL? {
        let url = assetsURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return url
    }

    init() {
        load()
    }

    func bootstrapIfNeeded() {
        guard notebooks.isEmpty else { return }
        let notebook = TravelNotebook(
            title: "Cloud Notebook",
            coverPageID: nil,
            tintName: "sage",
            symbol: "cloud.sun.fill"
        )
        notebooks = [notebook]
        let pageID = createPage(in: notebook.id, title: "First Page", template: .postcard, saveAfterCreate: false)
        notebooks[0].coverPageID = pageID
        save()
    }

    func ensureEditableCanvas(for pageID: UUID) {
        guard ensurePageExists(pageID, title: "New Page"),
              let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        guard pages[index].canvasDocument.elements.isEmpty else { return }
        objectWillChange.send()
        var page = pages[index]
        page.canvasDocument.background = CanvasBackground(colorA: "#FFFFFF", colorB: "#FFFFFF")
        page.canvasDocument.updatedAt = Date()
        page.updatedAt = Date()
        pages[index] = page
        canvasRevision += 1
        if !draftPageIDs.contains(pageID) {
            save()
        }
    }

    func pages(for notebookID: UUID) -> [JournalPage] {
        pages
            .filter { $0.notebookID == notebookID }
            .sorted {
                if $0.sortIndex == $1.sortIndex {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.sortIndex > $1.sortIndex
            }
    }

    func coverPage(for notebookID: UUID) -> JournalPage? {
        guard let notebook = notebooks.first(where: { $0.id == notebookID }) else { return nil }
        if let coverPageID = notebook.coverPageID,
           let page = pages.first(where: { $0.id == coverPageID && $0.notebookID == notebookID }) {
            return page
        }
        return pages(for: notebookID).first
    }

    func page(id: UUID) -> JournalPage? {
        pages.first { $0.id == id }
    }

    func notebook(id: UUID) -> TravelNotebook? {
        notebooks.first { $0.id == id }
    }

    func notebook(for pageID: UUID) -> TravelNotebook? {
        guard let page = page(id: pageID) else { return nil }
        return notebook(id: page.notebookID)
    }

    func targetNotebookForNewPage(preferred notebookID: UUID? = nil) -> TravelNotebook {
        let resolvedID = resolvedNotebookID(preferred: notebookID)
        ensureNotebookExists(resolvedID)
        return notebooks.first(where: { $0.id == resolvedID }) ?? notebooks[0]
    }

    func createNotebook(title: String, themeIndex: Int, coverImageData: Data? = nil) -> UUID {
        let symbols = ["airplane.departure", "map.fill", "camera.fill", "sparkles", "photo.stack"]
        let tints = ["sand", "mist", "sage", "rose", "clay"]
        let index = max(0, min(themeIndex, tints.count - 1))
        let coverImagePath = saveNotebookCoverImage(coverImageData)
        let notebook = TravelNotebook(
            title: title,
            coverPageID: nil,
            coverImagePath: coverImagePath,
            tintName: tints[index],
            symbol: symbols[index]
        )
        notebooks.insert(notebook, at: 0)
        let pageID = createPage(in: notebook.id, title: "First Page", template: .blank, saveAfterCreate: false)
        if let notebookIndex = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[notebookIndex].coverPageID = pageID
        }
        save()
        return notebook.id
    }

    private func saveNotebookCoverImage(_ data: Data?) -> String? {
        guard let data, let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString)-notebook-cover.jpg"
            let url = assetsURL.appendingPathComponent(fileName)
            try jpegData.write(to: url, options: .atomic)
            return verifiedAssetURL(for: fileName) == nil ? nil : fileName
        } catch {
            return nil
        }
    }

    func renameNotebook(_ notebookID: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        notebooks[index].title = trimmed
        notebooks[index].updatedAt = Date()
        save()
    }

    func deleteNotebook(_ notebookID: UUID) {
        guard notebooks.count > 1,
              notebooks.contains(where: { $0.id == notebookID }) else { return }
        notebooks.removeAll { $0.id == notebookID }
        pages.removeAll { $0.notebookID == notebookID }
        save()
    }

    @discardableResult
    func createPageAndOpen(in notebookID: UUID?, title: String, template: PageTemplate, open: (UUID) -> Void) -> UUID {
        let pageID = createPage(in: notebookID, title: title, template: template, saveAfterCreate: false, draft: true)
        ensurePageExists(pageID, title: title)
        open(pageID)
        return pageID
    }

    @discardableResult
    func createQuickClip(
        in notebookID: UUID?,
        place: String,
        note: String,
        photoData: Data?
    ) -> Result<UUID, CanvasInsertError> {
        let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedPlace.isEmpty ? "Quick Clip" : trimmedPlace
        let pageID = createPage(in: notebookID, title: title, template: .blank, saveAfterCreate: false)
        var photoFileName: String?
        var photoSize = CGSize(width: 900, height: 1200)

        if let photoData {
            guard let image = UIImage(data: photoData) else {
                deletePage(pageID)
                return .failure(.unsupportedImageData)
            }
            guard let jpegData = image.jpegData(compressionQuality: 0.92) else {
                deletePage(pageID)
                return .failure(.imageEncodingFailed)
            }

            do {
                try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
                let fileName = "\(UUID().uuidString)-quick-clip.jpg"
                let url = assetsURL.appendingPathComponent(fileName)
                try jpegData.write(to: url, options: .atomic)
                guard verifiedAssetURL(for: fileName) != nil else {
                    deletePage(pageID)
                    return .failure(.assetUnavailable)
                }
                photoFileName = fileName
                photoSize = image.size
            } catch {
                deletePage(pageID)
                return .failure(.writeFailed(error.localizedDescription))
            }
        }

        mutatePage(pageID, autosave: false) { page in
            page.canvasDocument.background = CanvasBackground(colorA: "#FBF8F0", colorB: "#EAF1F7")
            page.canvasDocument.elements = quickClipElements(
                place: title,
                note: trimmedNote.isEmpty ? "A small moment from today." : trimmedNote,
                photoFileName: photoFileName,
                photoSize: photoSize
            )
        }
        commitPage(pageID)
        return .success(pageID)
    }

    func renamePage(_ pageID: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutatePage(pageID) { page in
            page.title = trimmed
        }
    }

    func deletePage(_ pageID: UUID) {
        guard let page = pages.first(where: { $0.id == pageID }) else { return }
        pages.removeAll { $0.id == pageID }
        rebuildSortIndexes(in: page.notebookID)
        if notebooks.first(where: { $0.coverPageID == pageID }) != nil {
            let remaining = pages(for: page.notebookID)
            let newCover = remaining.first?.id
            setCoverPage(newCover, in: page.notebookID)
        } else {
            touchNotebook(page.notebookID)
            save()
        }
    }

    func movePage(_ pageID: UUID, to notebookID: UUID) {
        guard notebooks.contains(where: { $0.id == notebookID }),
              let pageIndex = pages.firstIndex(where: { $0.id == pageID }) else { return }
        let oldNotebookID = pages[pageIndex].notebookID
        pages[pageIndex].notebookID = notebookID
        pages[pageIndex].sortIndex = nextSortIndex(in: notebookID)
        pages[pageIndex].updatedAt = Date()
        if notebooks.first(where: { $0.id == notebookID })?.coverPageID == nil,
           let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookID }) {
            notebooks[notebookIndex].coverPageID = pageID
        }
        rebuildSortIndexes(in: oldNotebookID, saveAfterRebuild: false)
        rebuildSortIndexes(in: notebookID, saveAfterRebuild: false)
        touchNotebook(oldNotebookID)
        touchNotebook(notebookID)
        save()
    }

    func setCoverPage(_ pageID: UUID?, in notebookID: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        notebooks[index].coverPageID = pageID
        touchNotebook(notebookID)
        save()
    }

    @discardableResult
    func createPage(in notebookID: UUID?, title: String, template: PageTemplate, saveAfterCreate: Bool = true, draft: Bool = false) -> UUID {
        let resolvedNotebookID = resolvedNotebookID(preferred: notebookID)
        ensureNotebookExists(resolvedNotebookID)
        let pageID = UUID()
        var document = CanvasDocument(pageID: pageID)
        if template == .postcard {
            document.background = CanvasBackground(colorA: "#FDF0D6", colorB: "#E4F1EC")
            document.elements = [
                CanvasElement(kind: .text, text: "Travel day", x: 540, y: 260, width: 620, height: 130, zIndex: 1, colorHex: "#2E2824", fontSize: 92, bold: true),
                CanvasElement(kind: .sticker, symbol: "mappin.and.ellipse", x: 760, y: 520, width: 210, height: 190, rotation: -8, zIndex: 2, colorHex: "#C4563F"),
                CanvasElement(kind: .sticker, symbol: "sparkles", x: 310, y: 880, width: 170, height: 150, rotation: 10, zIndex: 3, colorHex: "#7AA08C")
            ]
        }

        let sortIndex = nextSortIndex(in: resolvedNotebookID)
        let page = JournalPage(id: pageID, notebookID: resolvedNotebookID, title: title, sortIndex: sortIndex, canvasDocument: document)
        pages.insert(page, at: 0)
        touchNotebook(resolvedNotebookID)
        if draft {
            draftPageIDs.insert(pageID)
        }
        if saveAfterCreate {
            save()
        }
        return pageID
    }

    @discardableResult
    func addText(_ style: TextStyleParameters, to pageID: UUID) -> Result<UUID, CanvasInsertError> {
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        let trimmed = style.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyText) }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let center = page.canvasDocument.centerPoint
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .text,
                    text: trimmed,
                    x: center.x,
                    y: center.y,
                    width: style.width,
                    height: 190,
                    zIndex: zIndex,
                    opacity: style.opacity,
                    colorHex: style.colorHex,
                    backgroundHex: style.backgroundHex,
                    strokeHex: style.strokeHex,
                    strokeWidth: style.strokeWidth,
                    textShadowEnabled: style.shadowEnabled,
                    shadowColorHex: style.shadowColorHex,
                    fontName: style.fontName,
                    fontSize: style.fontSize,
                    bold: style.bold,
                    italic: style.italic,
                    textAlignment: style.alignment,
                    shadow: style.shadowEnabled,
                    stroke: style.strokeWidth > 0
                )
            )
            selectedElementID = elementID
        }
        return insertedID.map { .success($0) } ?? .failure(.pageMissing)
    }

    @discardableResult
    func addWordArt(_ style: TextStyleParameters, to pageID: UUID) -> Result<UUID, CanvasInsertError> {
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        let trimmed = style.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyText) }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let center = page.canvasDocument.centerPoint
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .wordArt,
                    text: trimmed,
                    x: center.x,
                    y: center.y - page.canvasDocument.canvasSize.height * 0.08,
                    width: style.width,
                    height: 160,
                    rotation: -4,
                    zIndex: zIndex,
                    opacity: style.opacity,
                    colorHex: style.colorHex,
                    backgroundHex: style.backgroundHex,
                    strokeHex: style.strokeHex,
                    strokeWidth: style.strokeWidth,
                    textShadowEnabled: style.shadowEnabled,
                    shadowColorHex: style.shadowColorHex,
                    fontName: style.fontName,
                    fontSize: style.fontSize,
                    bold: true,
                    italic: style.italic,
                    textAlignment: style.alignment,
                    shadow: style.shadowEnabled,
                    stroke: style.strokeWidth > 0
                )
            )
            selectedElementID = elementID
        }
        return insertedID.map { .success($0) } ?? .failure(.pageMissing)
    }

    @discardableResult
    func addTextPreset(_ preset: TextPresetDefinition, to pageID: UUID) -> Result<UUID, CanvasInsertError> {
        switch preset.kind {
        case .wordArt:
            return addWordArt(preset.style, to: pageID)
        default:
            return addText(preset.style, to: pageID)
        }
    }

    @discardableResult
    func addLink(_ link: LinkCardParameters, to pageID: UUID) -> Result<UUID, CanvasInsertError> {
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        let trimmedURL = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return .failure(.emptyURL) }
        let title = link.title.trimmingCharacters(in: .whitespacesAndNewlines)
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let center = page.canvasDocument.centerPoint
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .link,
                    text: title.isEmpty ? trimmedURL : title,
                    linkURL: normalizedLinkURL(trimmedURL),
                    x: center.x,
                    y: center.y,
                    width: 660,
                    height: 210,
                    rotation: -2,
                    zIndex: zIndex,
                    colorHex: link.colorHex,
                    shadow: true,
                    cornerRadius: 34
                )
            )
            selectedElementID = elementID
        }
        return insertedID.map { .success($0) } ?? .failure(.pageMissing)
    }

    func addSticker(to pageID: UUID) {
        guard let sticker = stickerLibrary.first else { return }
        addSticker(sticker, to: pageID)
    }

    @discardableResult
    func addSticker(_ sticker: StickerDefinition, to pageID: UUID, selectAfterInsert: Bool = true) -> UUID? {
        guard ensurePageExists(pageID) else { return nil }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let canvas = page.canvasDocument.canvasSize
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .sticker,
                    symbol: sticker.symbol,
                    x: CGFloat.random(in: canvas.width * 0.28...canvas.width * 0.72),
                    y: CGFloat.random(in: canvas.height * 0.28...canvas.height * 0.72),
                    width: sticker.width,
                    height: sticker.height,
                    rotation: 0,
                    zIndex: zIndex,
                    colorHex: sticker.colorHex
                )
            )
            if selectAfterInsert {
                selectedElementID = elementID
            } else {
                selectedElementID = nil
            }
        }
        return insertedID
    }

    @discardableResult
    func addShape(_ shape: ShapeDefinition, to pageID: UUID) -> UUID? {
        guard ensurePageExists(pageID) else { return nil }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let center = page.canvasDocument.centerPoint
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .shape,
                    symbol: shape.symbol,
                    x: center.x,
                    y: center.y,
                    width: shape.width,
                    height: shape.height,
                    rotation: 0,
                    zIndex: zIndex,
                    opacity: 0.86,
                    colorHex: shape.colorHex,
                    stroke: shape.stroke,
                    cornerRadius: shape.cornerRadius
                )
            )
            selectedElementID = elementID
        }
        return insertedID
    }

    @discardableResult
    func addConnector(to pageID: UUID) -> UUID? {
        guard ensurePageExists(pageID) else { return nil }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let center = page.canvasDocument.centerPoint
            let elementID = UUID()
            let startPoint = CodablePoint(x: center.x - 310, y: center.y)
            let endPoint = CodablePoint(x: center.x + 310, y: center.y - 65)
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .connector,
                    symbol: "arrow",
                    x: center.x,
                    y: center.y,
                    width: 620,
                    height: 170,
                    rotation: -6,
                    zIndex: zIndex,
                    opacity: 0.92,
                    colorHex: "#2E2824",
                    shadow: true,
                    stroke: false,
                    cornerRadius: 0,
                    brushWidth: 18,
                    connectorStartPoint: startPoint,
                    connectorEndPoint: endPoint
                )
            )
            selectedElementID = elementID
        }
        return insertedID
    }

    @discardableResult
    func addConnector(to pageID: UUID, start: CGPoint, end: CGPoint) -> UUID? {
        guard ensurePageExists(pageID) else { return nil }
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard hypot(dx, dy) >= 24 else { return nil }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let elementID = UUID()
            var element = CanvasElement(
                id: elementID,
                kind: .connector,
                symbol: "arrow",
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2,
                width: max(hypot(dx, dy), 120),
                height: 100,
                zIndex: zIndex,
                opacity: 0.92,
                colorHex: "#2E2824",
                shadow: true,
                stroke: false,
                cornerRadius: 0,
                brushWidth: 18,
                connectorStartPoint: CodablePoint(x: start.x, y: start.y),
                connectorEndPoint: CodablePoint(x: end.x, y: end.y)
            )
            applyFreeConnectorGeometry(start: start, end: end, to: &element)
            insertedID = elementID
            page.canvasDocument.elements.append(element)
            selectedElementID = elementID
        }
        return insertedID
    }

    @discardableResult
    func connectSelection(on pageID: UUID) -> UUID? {
        guard selectedElementIDs.count == 2,
              let document = page(id: pageID)?.canvasDocument else { return nil }
        let selected = document.elements
            .filter { selectedElementIDs.contains($0.id) && !$0.hidden && !$0.locked && $0.kind != .connector }
            .sorted { $0.zIndex < $1.zIndex }
        guard selected.count == 2 else { return nil }

        let start = selected[0]
        let end = selected[1]
        let geometry = connectorGeometry(from: start, to: end)

        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .connector,
                    symbol: "linked-arrow",
                    x: geometry.center.x,
                    y: geometry.center.y,
                    width: geometry.width,
                    height: geometry.height,
                    rotation: geometry.rotation,
                    zIndex: zIndex,
                    opacity: 0.92,
                    colorHex: "#2E2824",
                    shadow: true,
                    stroke: false,
                    cornerRadius: 0,
                    brushWidth: 18,
                    connectorStartID: start.id,
                    connectorEndID: end.id
                )
            )
            selectedElementID = elementID
        }
        return insertedID
    }

    func addEffect(to pageID: UUID) {
        guard let selectedElementID else { return }
        storeUndoSnapshot(for: pageID)
        mutateElement(selectedElementID, on: pageID) { element in
            element.shadow.toggle()
            element.stroke.toggle()
        }
    }

    func selectElement(_ elementID: UUID?, extending: Bool = false, on pageID: UUID) {
        guard let elementID else {
            setSelectedElementIDs([])
            return
        }
        guard let document = page(id: pageID)?.canvasDocument,
              let element = document.elements.first(where: { $0.id == elementID }) else { return }
        let elementIDs = element.groupID.map { groupID in
            Set(document.elements.filter { $0.groupID == groupID && !$0.hidden }.map(\.id))
        } ?? [elementID]
        if extending {
            var nextSelection = selectedElementIDs
            if elementIDs.isSubset(of: selectedElementIDs), selectedElementIDs.count > elementIDs.count {
                nextSelection.subtract(elementIDs)
            } else {
                nextSelection.formUnion(elementIDs)
            }
            setSelectedElementIDs(nextSelection)
        } else {
            setSelectedElementIDs(elementIDs)
        }
    }

    func selectAll(on pageID: UUID) {
        setSelectedElementIDs(Set(page(id: pageID)?.canvasDocument.elements.filter { !$0.hidden }.map(\.id) ?? []))
    }

    func selectElements(in rect: CGRect, on pageID: UUID) {
        guard rect.width > 8, rect.height > 8,
              let document = page(id: pageID)?.canvasDocument else { return }
        let intersectedElements = document.elements.filter { !$0.hidden && $0.bounds.intersects(rect) }
        let groupIDs = Set(intersectedElements.compactMap(\.groupID))
        setSelectedElementIDs(Set(
            document.elements
                .filter { element in
                    guard !element.hidden else { return false }
                    return intersectedElements.contains { $0.id == element.id } || element.groupID.map { groupIDs.contains($0) } == true
                }
                .map(\.id)
        ))
    }

    func clearSelection() {
        setSelectedElementIDs([])
    }

    func addTape(to pageID: UUID) {
        guard let tape = tapeLibrary.first else { return }
        addTape(tape, to: pageID)
    }

    @discardableResult
    func addTape(_ tape: TapeDefinition, to pageID: UUID, selectAfterInsert: Bool = true) -> UUID? {
        guard ensureWritablePage(pageID, title: "New Page") else { return nil }
        let copiedFileName = copiedTapeFileName(for: tape)
        if let copiedFileName, imageURL(for: copiedFileName) == nil {
            return nil
        }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let center = page.canvasDocument.centerPoint
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .tape,
                    localPath: copiedFileName,
                    x: center.x,
                    y: center.y,
                    width: tape.width,
                    height: tape.height,
                    rotation: tape.rotation,
                    zIndex: zIndex,
                    colorHex: tape.colorHex
                )
            )
            selectedElementID = selectAfterInsert ? elementID : nil
        }
        return insertedID
    }

    private func copiedTapeFileName(for tape: TapeDefinition) -> String? {
        guard let fileURL = tape.fileURL, let fileName = tape.fileName else { return nil }
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let destinationName = "\(UUID().uuidString)-\(fileName)"
            let destinationURL = assetsURL.appendingPathComponent(destinationName)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: fileURL, to: destinationURL)
            guard verifiedAssetURL(for: destinationName) != nil else { return nil }
            return destinationName
        } catch {
            return fileName
        }
    }

    func addBrushStroke(
        _ points: [CGPoint],
        to pageID: UUID,
        colorHex: String? = nil,
        brushWidth: CGFloat? = nil,
        opacity: Double? = nil
    ) {
        guard points.count > 1 else { return }
        guard ensurePageExists(pageID) else { return }
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let elementID = UUID()
            let minX = points.map(\.x).min() ?? 0
            let maxX = points.map(\.x).max() ?? 0
            let minY = points.map(\.y).min() ?? 0
            let maxY = points.map(\.y).max() ?? 0
            let padding: CGFloat = 70
            let originX = minX - padding
            let originY = minY - padding
            let width = max(maxX - minX + padding * 2, 120)
            let height = max(maxY - minY + padding * 2, 120)
            let normalized = points.map { CodablePoint(x: $0.x - originX, y: $0.y - originY) }
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .brush,
                    x: originX + width / 2,
                    y: originY + height / 2,
                    width: width,
                    height: height,
                    rotation: 0,
                    zIndex: zIndex,
                    opacity: opacity ?? 0.72,
                    colorHex: colorHex ?? ["#B77255", "#6F9D86", "#D6A858", "#7E8EAB"].randomElement() ?? "#B77255",
                    brushWidth: brushWidth ?? 46,
                    brushPoints: normalized
                )
            )
            selectedElementID = elementID
        }
    }

    @discardableResult
    func addPhoto(_ item: PhotosPickerItem?, to pageID: UUID) async -> Result<UUID, CanvasInsertError> {
        guard let item else { return .failure(.emptySelection) }
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return .failure(.photoDataUnavailable) }
        guard let image = UIImage(data: data) else { return .failure(.unsupportedImageData) }
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else { return .failure(.imageEncodingFailed) }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).jpg"
            let url = assetsURL.appendingPathComponent(fileName)
            try jpegData.write(to: url, options: Data.WritingOptions.atomic)
            guard verifiedAssetURL(for: fileName) != nil else { return .failure(.assetUnavailable) }
            return insertImageAsset(fileName: fileName, imageSize: image.size, to: pageID)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    @discardableResult
    func replaceImageElement(_ elementID: UUID, with item: PhotosPickerItem?, on pageID: UUID) async -> Result<UUID, CanvasInsertError> {
        guard let item else { return .failure(.emptySelection) }
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        guard let element = page(id: pageID)?.canvasDocument.elements.first(where: { $0.id == elementID }),
              element.kind == .image,
              !element.locked else { return .failure(.assetUnavailable) }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return .failure(.photoDataUnavailable) }
        guard let image = UIImage(data: data) else { return .failure(.unsupportedImageData) }
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else { return .failure(.imageEncodingFailed) }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).jpg"
            let url = assetsURL.appendingPathComponent(fileName)
            try jpegData.write(to: url, options: Data.WritingOptions.atomic)
            guard verifiedAssetURL(for: fileName) != nil else { return .failure(.assetUnavailable) }
            storeUndoSnapshot(for: pageID)
            mutateElement(elementID, on: pageID) { element in
                guard element.kind == .image, !element.locked else { return }
                element.localPath = fileName
                element.colorHex = "#A9C0D2"
            }
            selectedElementID = elementID
            return .success(elementID)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    @discardableResult
    func pasteFromClipboard(to pageID: UUID) -> Result<String, CanvasInsertError> {
        let pasteboard = UIPasteboard.general
        if let image = pasteboard.image {
            switch addImage(image, to: pageID) {
            case .success:
                return .success("Image pasted")
            case .failure(let error):
                return .failure(error)
            }
        }

        if let url = pasteboard.url {
            switch addLink(LinkCardParameters(title: url.host ?? "Link", url: url.absoluteString), to: pageID) {
            case .success:
                return .success("Link pasted")
            case .failure(let error):
                return .failure(error)
            }
        }

        if let string = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !string.isEmpty {
            if looksLikeURL(string) {
                switch addLink(LinkCardParameters(url: string), to: pageID) {
                case .success:
                    return .success("Link pasted")
                case .failure(let error):
                    return .failure(error)
                }
            }

            let style = TextStyleParameters(
                text: string,
                fontName: "Georgia",
                fontSize: min(max(CGFloat(92 - string.count / 3), 42), 78),
                colorHex: "#2E2824",
                bold: true,
                alignment: "center",
                width: 700
            )
            switch addText(style, to: pageID) {
            case .success:
                return .success("Text pasted")
            case .failure(let error):
                return .failure(error)
            }
        }

        return .failure(.clipboardEmpty)
    }

    @discardableResult
    private func addImage(_ image: UIImage, to pageID: UUID) -> Result<UUID, CanvasInsertError> {
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else { return .failure(.imageEncodingFailed) }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).jpg"
            let url = assetsURL.appendingPathComponent(fileName)
            try jpegData.write(to: url, options: Data.WritingOptions.atomic)
            guard verifiedAssetURL(for: fileName) != nil else { return .failure(.assetUnavailable) }
            return insertImageAsset(fileName: fileName, imageSize: image.size, to: pageID)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    @discardableResult
    func addTicketImage(_ image: UIImage, to pageID: UUID) -> Result<UUID, CanvasInsertError> {
        addImage(image, to: pageID)
    }

    @discardableResult
    func addMaterial(_ item: MaterialItem, to pageID: UUID, selectAfterInsert: Bool = true) -> Result<UUID, CanvasInsertError> {
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        guard fileManager.fileExists(atPath: item.fileURL.path) else { return .failure(.assetUnavailable) }
        guard let image = UIImage(contentsOfFile: item.fileURL.path) else { return .failure(.unsupportedImageData) }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let destinationName = "\(UUID().uuidString)-\(item.fileName)"
            let destinationURL = assetsURL.appendingPathComponent(destinationName)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: item.fileURL, to: destinationURL)
            guard verifiedAssetURL(for: destinationName) != nil else { return .failure(.assetUnavailable) }
            return insertImageAsset(fileName: destinationName, imageSize: image.size, to: pageID, selectAfterInsert: selectAfterInsert)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    private func insertImageAsset(fileName: String, imageSize: CGSize, to pageID: UUID, selectAfterInsert: Bool = true) -> Result<UUID, CanvasInsertError> {
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        guard imageURL(for: fileName) != nil else { return .failure(.assetUnavailable) }
        storeUndoSnapshot(for: pageID)
        var insertedID: UUID?
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let center = page.canvasDocument.centerPoint
            let aspect = max(imageSize.width / max(imageSize.height, 1), 0.2)
            let baseWidth: CGFloat = aspect >= 1 ? 680 : 460
            let width = min(max(baseWidth, 340), 760)
            let height = min(max(width / aspect, 320), 820)
            let elementID = UUID()
            insertedID = elementID
            page.canvasDocument.elements.append(
                CanvasElement(
                    id: elementID,
                    kind: .image,
                    localPath: fileName,
                    x: center.x,
                    y: center.y,
                    width: width,
                    height: height,
                    rotation: -3,
                    zIndex: zIndex,
                    colorHex: "#A9C0D2"
                )
            )
            if selectAfterInsert {
                selectedElementID = elementID
            } else {
                selectedElementID = nil
            }
        }
        return insertedID.map { .success($0) } ?? .failure(.pageMissing)
    }

    private func quickClipElements(place: String, note: String, photoFileName: String?, photoSize: CGSize) -> [CanvasElement] {
        var elements: [CanvasElement] = [
            CanvasElement(
                kind: .shape,
                symbol: "rounded-rect-outline",
                x: 540,
                y: 960,
                width: 860,
                height: 1420,
                zIndex: 1,
                opacity: 0.92,
                colorHex: "#FFFFFF",
                strokeHex: "#D8C9B8",
                strokeWidth: 7,
                cornerRadius: 42
            ),
            CanvasElement(
                kind: .text,
                text: place,
                x: 540,
                y: 238,
                width: 760,
                height: 116,
                zIndex: 3,
                colorHex: "#2E2824",
                fontName: "Georgia",
                fontSize: min(max(CGFloat(88 - place.count), 48), 82),
                bold: true
            ),
            CanvasElement(
                kind: .text,
                text: note,
                x: 540,
                y: 1540,
                width: 760,
                height: 220,
                zIndex: 4,
                colorHex: "#4A403A",
                fontName: "Georgia",
                fontSize: min(max(CGFloat(72 - note.count / 3), 40), 58),
                textAlignment: "center"
            ),
            CanvasElement(
                kind: .sticker,
                symbol: "mappin.and.ellipse",
                x: 222,
                y: 248,
                width: 130,
                height: 118,
                rotation: -8,
                zIndex: 5,
                colorHex: "#B77255"
            ),
            CanvasElement(
                kind: .tape,
                x: 540,
                y: 438,
                width: 720,
                height: 86,
                rotation: -3,
                zIndex: 6,
                opacity: 0.82,
                colorHex: "#E0B56D",
                cornerRadius: 12
            )
        ]

        if let photoFileName {
            let aspect = max(photoSize.width / max(photoSize.height, 1), 0.2)
            let photoWidth: CGFloat = 760
            let photoHeight = min(max(photoWidth / aspect, 620), 930)
            elements.append(
                CanvasElement(
                    kind: .image,
                    localPath: photoFileName,
                    x: 540,
                    y: 900,
                    width: photoWidth,
                    height: photoHeight,
                    rotation: -1.5,
                    zIndex: 2,
                    colorHex: "#A9C0D2",
                    cornerRadius: 30
                )
            )
        } else {
            elements.append(
                CanvasElement(
                    kind: .shape,
                    symbol: "photo",
                    x: 540,
                    y: 900,
                    width: 760,
                    height: 820,
                    rotation: -1.5,
                    zIndex: 2,
                    opacity: 0.72,
                    colorHex: "#D9E5E2",
                    strokeHex: "#D8C9B8",
                    strokeWidth: 5,
                    cornerRadius: 30
                )
            )
        }

        return elements
    }

    private func looksLikeURL(_ string: String) -> Bool {
        if let url = URL(string: string), url.scheme != nil, url.host != nil {
            return true
        }
        let lowered = string.lowercased()
        return lowered.hasPrefix("www.") || lowered.contains(".com") || lowered.contains(".cn") || lowered.contains(".net") || lowered.contains(".org")
    }

    @discardableResult
    func addFile(from sourceURL: URL, to pageID: UUID) -> Result<UUID, CanvasInsertError> {
        guard ensureWritablePage(pageID, title: "New Page") else { return .failure(.pageMissing) }
        let accessGranted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let originalName = sourceURL.lastPathComponent.isEmpty ? "Attachment" : sourceURL.lastPathComponent
            let destinationName = "\(UUID().uuidString)-\(originalName)"
            let destinationURL = assetsURL.appendingPathComponent(destinationName)
            let mediaKind = canvasKind(for: sourceURL)
            let layout = attachmentLayout(for: mediaKind)

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            guard verifiedAssetURL(for: destinationName) != nil else { return .failure(.assetUnavailable) }

            storeUndoSnapshot(for: pageID)
            var insertedID: UUID?
            mutatePage(pageID) { page in
                let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
                let center = page.canvasDocument.centerPoint
                let elementID = UUID()
                insertedID = elementID
                page.canvasDocument.elements.append(
                    CanvasElement(
                        id: elementID,
                        kind: mediaKind,
                        text: originalName,
                        localPath: destinationName,
                        x: center.x,
                        y: center.y,
                        width: layout.size.width,
                        height: layout.size.height,
                        rotation: layout.rotation,
                        zIndex: zIndex,
                        colorHex: layout.colorHex,
                        shadow: true,
                        cornerRadius: layout.cornerRadius
                    )
                )
                selectedElementID = elementID
            }
            if let insertedID {
                return .success(insertedID)
            }
            return .failure(.pageMissing)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    private func canvasKind(for fileURL: URL) -> CanvasElementKind {
        guard let type = UTType(filenameExtension: fileURL.pathExtension) else { return .file }
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        }
        if type.conforms(to: .audio) {
            return .audio
        }
        if type.conforms(to: .image) {
            return .image
        }
        return .file
    }

    private func attachmentLayout(for kind: CanvasElementKind) -> (size: CGSize, rotation: Double, colorHex: String, cornerRadius: CGFloat) {
        switch kind {
        case .image:
            return (CGSize(width: 620, height: 460), -3, "#A9C0D2", 34)
        case .video:
            return (CGSize(width: 700, height: 430), -2, "#7E8EAB", 36)
        case .audio:
            return (CGSize(width: 660, height: 220), -1, "#B77255", 32)
        default:
            return (CGSize(width: 660, height: 190), -1, "#6F9D86", 30)
        }
    }

    func moveElement(_ elementID: UUID, on pageID: UUID, to position: CGPoint) {
        mutatePage(pageID, autosave: false) { page in
            guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == elementID }) else { return }
            var element = page.canvasDocument.elements[index]
            guard !element.locked else { return }
            element.x = clamped(position.x, lower: 40, upper: max(40, page.canvasDocument.canvasSize.width - 40))
            element.y = clamped(position.y, lower: 40, upper: max(40, page.canvasDocument.canvasSize.height - 40))
            page.canvasDocument.elements[index] = element
        }
    }

    func moveSelection(on pageID: UUID, from startPositions: [UUID: CGPoint], translation: CGSize) {
        mutatePage(pageID, autosave: false) { page in
            for id in selectedElementIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }),
                      let start = startPositions[id],
                      !page.canvasDocument.elements[index].locked else { continue }
                page.canvasDocument.elements[index].x = clamped(start.x + translation.width, lower: 40, upper: max(40, page.canvasDocument.canvasSize.width - 40))
                page.canvasDocument.elements[index].y = clamped(start.y + translation.height, lower: 40, upper: max(40, page.canvasDocument.canvasSize.height - 40))
            }
        }
    }

    func transformSelection(on pageID: UUID, from startElements: [UUID: CanvasElement], selectionRect: CGRect, scale: CGFloat, rotation: Double) {
        guard !startElements.isEmpty else { return }
        let bounds = elementSizeBounds(on: pageID)
        let center = CGPoint(x: selectionRect.midX, y: selectionRect.midY)
        let radians = rotation * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        let clampedScale = min(max(scale, 0.18), 4)

        mutatePage(pageID, autosave: false) { page in
            for (id, start) in startElements {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }),
                      !page.canvasDocument.elements[index].locked else { continue }

                let dx = (start.x - center.x) * clampedScale
                let dy = (start.y - center.y) * clampedScale
                let rotatedX = dx * cosine - dy * sine
                let rotatedY = dx * sine + dy * cosine
                let nextWidth = min(max(start.width * clampedScale, bounds.minWidth), bounds.maxWidth)
                let nextHeight = min(max(start.height * clampedScale, bounds.minHeight), bounds.maxHeight)
                let nextCenter = CGPoint(x: center.x + rotatedX, y: center.y + rotatedY)

                page.canvasDocument.elements[index].x = clamped(nextCenter.x, lower: 40, upper: max(40, page.canvasDocument.canvasSize.width - 40))
                page.canvasDocument.elements[index].y = clamped(nextCenter.y, lower: 40, upper: max(40, page.canvasDocument.canvasSize.height - 40))
                page.canvasDocument.elements[index].width = nextWidth
                page.canvasDocument.elements[index].height = nextHeight
                page.canvasDocument.elements[index].rotation = start.rotation + rotation
                page.canvasDocument.elements[index].fontSize = min(max(start.fontSize * clampedScale, 24), 220)
                page.canvasDocument.elements[index].brushWidth = min(max(start.brushWidth * clampedScale, 4), 180)
                page.canvasDocument.elements[index].brushPoints = start.brushPoints.map { point in
                    CodablePoint(x: point.x * clampedScale, y: point.y * clampedScale)
                }
            }
        }
    }

    func transformElement(_ elementID: UUID, on pageID: UUID, from start: CanvasElement, scale: CGFloat, rotation: Double) {
        let bounds = elementSizeBounds(on: pageID)
        let clampedScale = min(max(scale, 0.18), 4)
        mutateElement(elementID, on: pageID, autosave: false) { element in
            guard !element.locked else { return }
            element.x = start.x
            element.y = start.y
            element.width = min(max(start.width * clampedScale, bounds.minWidth), bounds.maxWidth)
            element.height = min(max(start.height * clampedScale, bounds.minHeight), bounds.maxHeight)
            element.fontSize = min(max(start.fontSize * clampedScale, 24), 220)
            element.brushWidth = min(max(start.brushWidth * clampedScale, 4), 180)
            element.brushPoints = start.brushPoints.map { point in
                CodablePoint(x: point.x * clampedScale, y: point.y * clampedScale)
            }
            element.rotation = start.rotation + rotation
        }
    }

    func moveConnectorEndpoint(_ elementID: UUID, on pageID: UUID, endpoint: ConnectorEndpoint, to point: CGPoint) {
        mutatePage(pageID, autosave: false) { page in
            guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == elementID }) else { return }
            var element = page.canvasDocument.elements[index]
            guard !element.locked,
                  element.kind == .connector,
                  element.connectorStartID == nil,
                  element.connectorEndID == nil else { return }
            let clampedPoint = CGPoint(
                x: clamped(point.x, lower: 20, upper: max(20, page.canvasDocument.canvasSize.width - 20)),
                y: clamped(point.y, lower: 20, upper: max(20, page.canvasDocument.canvasSize.height - 20))
            )
            let current = freeConnectorEndpoints(for: element)
            let start = endpoint == .start ? clampedPoint : current.start
            let end = endpoint == .end ? clampedPoint : current.end
            applyFreeConnectorGeometry(start: start, end: end, to: &element)
            page.canvasDocument.elements[index] = element
        }
    }

    func deleteElement(_ elementID: UUID, from pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            page.canvasDocument.elements.removeAll {
                $0.id == elementID || $0.connectorStartID == elementID || $0.connectorEndID == elementID
            }
        }
        selectedElementID = nil
    }

    func deleteSelection(from pageID: UUID) {
        guard !selectedElementIDs.isEmpty else { return }
        storeUndoSnapshot(for: pageID)
        let ids = selectedElementIDs
        mutatePage(pageID) { page in
            page.canvasDocument.elements.removeAll {
                ids.contains($0.id)
                    || ($0.connectorStartID.map { ids.contains($0) } ?? false)
                    || ($0.connectorEndID.map { ids.contains($0) } ?? false)
            }
        }
        setSelectedElementIDs([])
    }

    func commitPage(_ pageID: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        objectWillChange.send()
        pages[index].updatedAt = Date()
        pages[index].canvasDocument.updatedAt = Date()
        draftPageIDs.remove(pageID)
        touchNotebook(pages[index].notebookID)
        canvasRevision += 1
        saveNow()
    }

    func flushPendingSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        saveNow()
    }

    func discardDraftPageIfNeeded(_ pageID: UUID) {
        guard draftPageIDs.remove(pageID) != nil,
              let page = pages.first(where: { $0.id == pageID }) else { return }
        let notebookID = page.notebookID
        pages.removeAll { $0.id == pageID }
        undoStacks[pageID] = nil
        redoStacks[pageID] = nil
        setSelectedElementIDs(selectedElementIDs.filter { id in
            !page.canvasDocument.elements.contains { $0.id == id }
        })
        if notebooks.first(where: { $0.coverPageID == pageID }) != nil {
            let remaining = pages(for: notebookID)
            setCoverPage(remaining.first?.id, in: notebookID)
        } else {
            touchNotebook(notebookID)
            saveNow()
        }
    }

    func isDraftPage(_ pageID: UUID) -> Bool {
        draftPageIDs.contains(pageID)
    }

    func updateBackground(for pageID: UUID) {
        guard let background = backgroundLibrary.first else { return }
        updateBackground(background, for: pageID)
    }

    func updateBackground(_ background: BackgroundDefinition, for pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            page.canvasDocument.background.colorA = background.colorA
            page.canvasDocument.background.colorB = background.colorB
        }
    }

    func addViewportFrame(title: String, center: CGPoint, zoom: CGFloat, to pageID: UUID) {
        guard ensureWritablePage(pageID, title: "New Page") else { return }
        mutatePage(pageID) { page in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let frame = CanvasViewportFrame(
                title: trimmed.isEmpty ? "View \(page.canvasDocument.viewportFrames.count + 1)" : trimmed,
                center: CodablePoint(x: center.x, y: center.y),
                zoom: min(max(zoom, 0.75), 3.2)
            )
            page.canvasDocument.viewportFrames.append(frame)
        }
    }

    func deleteViewportFrame(_ frameID: UUID, from pageID: UUID) {
        mutatePage(pageID) { page in
            page.canvasDocument.viewportFrames.removeAll { $0.id == frameID }
        }
    }

    func applyTemplate(to pageID: UUID) {
        guard let template = templateLibrary.first else { return }
        applyTemplate(template, to: pageID)
    }

    func applyTemplate(_ template: PageTemplateDefinition, to pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let application = PageTemplateApplier.apply(template, to: &page.canvasDocument)
            setSelectedElementIDs(application.selectedElementIDs)
        }
    }

    func bringForward(_ elementID: UUID, on pageID: UUID) {
        adjustElementLayer(elementID, on: pageID, mode: .forward)
    }

    func sendBackward(_ elementID: UUID, on pageID: UUID) {
        adjustElementLayer(elementID, on: pageID, mode: .backward)
    }

    func bringToFront(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        let top = (page(id: pageID)?.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
        mutateElement(elementID, on: pageID) { element in
            element.zIndex = top
        }
        normalizeLayerOrder(on: pageID)
    }

    func sendToBack(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        let bottom = (page(id: pageID)?.canvasDocument.elements.map(\.zIndex).min() ?? 0) - 1
        mutateElement(elementID, on: pageID) { element in
            element.zIndex = bottom
        }
        normalizeLayerOrder(on: pageID)
    }

    func bringSelectionForward(on pageID: UUID) {
        adjustSelectionLayer(on: pageID, mode: .forward)
    }

    func sendSelectionBackward(on pageID: UUID) {
        adjustSelectionLayer(on: pageID, mode: .backward)
    }

    func bringSelectionToFront(on pageID: UUID) {
        adjustSelectionLayer(on: pageID, mode: .front)
    }

    func sendSelectionToBack(on pageID: UUID) {
        adjustSelectionLayer(on: pageID, mode: .back)
    }

    func duplicateSelection(on pageID: UUID) {
        guard !selectedElementIDs.isEmpty else { return }
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let selected = page.canvasDocument.elements
                .filter { selectedElementIDs.contains($0.id) }
                .sorted { $0.zIndex < $1.zIndex }
            guard !selected.isEmpty else { return }
            let topZ = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            let canvas = page.canvasDocument.canvasSize
            let groupMap = Dictionary(
                uniqueKeysWithValues: Set(selected.compactMap(\.groupID)).map { ($0, UUID()) }
            )
            let copies = selected.enumerated().map { offset, element in
                var copy = element
                copy.id = UUID()
                copy.x = min(max(copy.x + 44, 80), max(80, canvas.width - 80))
                copy.y = min(max(copy.y + 44, 80), max(80, canvas.height - 80))
                copy.zIndex = topZ + offset
                copy.locked = false
                if let groupID = copy.groupID {
                    copy.groupID = groupMap[groupID]
                }
                return copy
            }
            page.canvasDocument.elements.append(contentsOf: copies)
            setSelectedElementIDs(Set(copies.map(\.id)))
        }
        normalizeLayerOrder(on: pageID)
    }

    func groupSelection(on pageID: UUID) {
        guard selectedElementIDs.count > 1 else { return }
        let groupID = UUID()
        let targetIDs = selectedElementIDs
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for id in targetIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }),
                      !page.canvasDocument.elements[index].locked else { continue }
                page.canvasDocument.elements[index].groupID = groupID
            }
            setSelectedElementIDs(Set(page.canvasDocument.elements.filter { $0.groupID == groupID }.map(\.id)))
        }
    }

    func ungroupSelection(on pageID: UUID) {
        guard !selectedElementIDs.isEmpty else { return }
        guard let document = page(id: pageID)?.canvasDocument else { return }
        let groupIDs = Set(document.elements.filter { selectedElementIDs.contains($0.id) }.compactMap(\.groupID))
        guard !groupIDs.isEmpty else { return }
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for index in page.canvasDocument.elements.indices {
                guard let groupID = page.canvasDocument.elements[index].groupID,
                      groupIDs.contains(groupID),
                      !page.canvasDocument.elements[index].locked else { continue }
                page.canvasDocument.elements[index].groupID = nil
            }
        }
    }

    func toggleSelectionHidden(on pageID: UUID) {
        guard !selectedElementIDs.isEmpty,
              let document = page(id: pageID)?.canvasDocument else { return }
        let selected = document.elements.filter { selectedElementIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let shouldHide = selected.contains { !$0.hidden }
        let targetIDs = selectedElementIDs
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for id in targetIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }) else { continue }
                page.canvasDocument.elements[index].hidden = shouldHide
            }
        }
        if shouldHide {
            setSelectedElementIDs([])
        }
    }

    func toggleSelectionLocked(on pageID: UUID) {
        guard !selectedElementIDs.isEmpty,
              let document = page(id: pageID)?.canvasDocument else { return }
        let selected = document.elements.filter { selectedElementIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let shouldLock = selected.contains { !$0.locked }
        let targetIDs = selectedElementIDs
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for id in targetIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }) else { continue }
                page.canvasDocument.elements[index].locked = shouldLock
            }
        }
    }

    func alignSelection(_ alignment: CanvasSelectionAlignment, on pageID: UUID) {
        guard selectedElementIDs.count > 1,
              let rect = selectionRect(on: pageID) else { return }
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for id in selectedElementIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }),
                      !page.canvasDocument.elements[index].locked else { continue }
                switch alignment {
                case .left:
                    page.canvasDocument.elements[index].x = rect.minX + page.canvasDocument.elements[index].width / 2
                case .centerX:
                    page.canvasDocument.elements[index].x = rect.midX
                case .right:
                    page.canvasDocument.elements[index].x = rect.maxX - page.canvasDocument.elements[index].width / 2
                case .top:
                    page.canvasDocument.elements[index].y = rect.minY + page.canvasDocument.elements[index].height / 2
                case .centerY:
                    page.canvasDocument.elements[index].y = rect.midY
                case .bottom:
                    page.canvasDocument.elements[index].y = rect.maxY - page.canvasDocument.elements[index].height / 2
                }
            }
        }
    }

    func alignSelectionToCanvas(_ alignment: CanvasSelectionAlignment, on pageID: UUID) {
        guard !selectedElementIDs.isEmpty,
              let document = page(id: pageID)?.canvasDocument,
              let rect = selectionRect(on: pageID) else { return }
        storeUndoSnapshot(for: pageID)
        let canvas = document.canvasSize
        let dx: CGFloat
        let dy: CGFloat
        switch alignment {
        case .left:
            dx = -rect.minX
            dy = 0
        case .centerX:
            dx = canvas.width / 2 - rect.midX
            dy = 0
        case .right:
            dx = canvas.width - rect.maxX
            dy = 0
        case .top:
            dx = 0
            dy = -rect.minY
        case .centerY:
            dx = 0
            dy = canvas.height / 2 - rect.midY
        case .bottom:
            dx = 0
            dy = canvas.height - rect.maxY
        }

        mutatePage(pageID) { page in
            for id in selectedElementIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }),
                      !page.canvasDocument.elements[index].locked else { continue }
                page.canvasDocument.elements[index].x += dx
                page.canvasDocument.elements[index].y += dy
            }
        }
    }

    func distributeSelection(_ axis: CanvasDistributionAxis, on pageID: UUID) {
        guard selectedElementIDs.count > 2 else { return }
        guard let document = page(id: pageID)?.canvasDocument else { return }
        let selected = document.elements
            .filter { selectedElementIDs.contains($0.id) && !$0.hidden && !$0.locked }
            .sorted { axis == .horizontal ? $0.x < $1.x : $0.y < $1.y }
        guard selected.count > 2 else { return }
        let first = axis == .horizontal ? selected.first!.x : selected.first!.y
        let last = axis == .horizontal ? selected.last!.x : selected.last!.y
        let step = (last - first) / CGFloat(selected.count - 1)
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for (offset, element) in selected.enumerated() {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == element.id }) else { continue }
                let value = first + CGFloat(offset) * step
                switch axis {
                case .horizontal:
                    page.canvasDocument.elements[index].x = value
                case .vertical:
                    page.canvasDocument.elements[index].y = value
                }
            }
        }
    }

    func arrangeSelectionGrid(on pageID: UUID) {
        guard selectedElementIDs.count > 1,
              let document = page(id: pageID)?.canvasDocument else { return }
        let selected = document.elements
            .filter { selectedElementIDs.contains($0.id) && !$0.hidden && !$0.locked && $0.kind != .connector }
            .sorted {
                if abs($0.y - $1.y) > 24 {
                    return $0.y < $1.y
                }
                return $0.x < $1.x
            }
        guard selected.count > 1 else { return }

        let columns = max(2, Int(ceil(sqrt(Double(selected.count)))))
        let spacing: CGFloat = 34
        let maxWidth = selected.map(\.width).max() ?? 220
        let maxHeight = selected.map(\.height).max() ?? 180
        let rect = selected.dropFirst().reduce(selected[0].bounds) { $0.union($1.bounds) }
        let totalWidth = CGFloat(columns) * maxWidth + CGFloat(columns - 1) * spacing
        let startX = max(totalWidth / 2 + 40, rect.midX - totalWidth / 2 + maxWidth / 2)
        let startY = max(maxHeight / 2 + 40, rect.minY + maxHeight / 2)
        let canvas = document.canvasSize

        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for (offset, element) in selected.enumerated() {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == element.id }) else { continue }
                let column = offset % columns
                let row = offset / columns
                let x = startX + CGFloat(column) * (maxWidth + spacing)
                let y = startY + CGFloat(row) * (maxHeight + spacing)
                page.canvasDocument.elements[index].x = min(max(x, 80), max(80, canvas.width - 80))
                page.canvasDocument.elements[index].y = min(max(y, 80), max(80, canvas.height - 80))
            }
        }
    }

    func matchSelectionSize(on pageID: UUID) {
        guard selectedElementIDs.count > 1,
              let document = page(id: pageID)?.canvasDocument else { return }
        let selected = document.elements.filter { selectedElementIDs.contains($0.id) && !$0.hidden && !$0.locked && $0.kind != .connector }
        guard selected.count > 1 else { return }
        let reference = selected.first { $0.id == selectedElementID } ?? selected.sorted { $0.zIndex < $1.zIndex }[0]
        let targetWidth = reference.width
        let targetHeight = reference.height

        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for element in selected where element.id != reference.id {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == element.id }) else { continue }
                let widthScale = targetWidth / max(page.canvasDocument.elements[index].width, 1)
                let heightScale = targetHeight / max(page.canvasDocument.elements[index].height, 1)
                let textScale = min(widthScale, heightScale)
                page.canvasDocument.elements[index].width = targetWidth
                page.canvasDocument.elements[index].height = targetHeight
                if page.canvasDocument.elements[index].kind == .text || page.canvasDocument.elements[index].kind == .wordArt {
                    page.canvasDocument.elements[index].fontSize = min(max(page.canvasDocument.elements[index].fontSize * textScale, 24), 180)
                }
            }
        }
    }

    func applySelectedStyleToSelection(on pageID: UUID) {
        guard selectedElementIDs.count > 1,
              let document = page(id: pageID)?.canvasDocument,
              let referenceID = selectedElementID,
              let reference = document.elements.first(where: { $0.id == referenceID && !$0.hidden && !$0.locked }) else { return }
        let targetIDs = selectedElementIDs.subtracting([referenceID])
        guard !targetIDs.isEmpty else { return }

        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for id in targetIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }),
                      !page.canvasDocument.elements[index].locked else { continue }
                page.canvasDocument.elements[index].colorHex = reference.colorHex
                page.canvasDocument.elements[index].opacity = reference.opacity
                page.canvasDocument.elements[index].shadow = reference.shadow
                page.canvasDocument.elements[index].stroke = reference.stroke
                page.canvasDocument.elements[index].cornerRadius = reference.cornerRadius
                page.canvasDocument.elements[index].blur = reference.blur

                if page.canvasDocument.elements[index].kind == .text || page.canvasDocument.elements[index].kind == .wordArt {
                    page.canvasDocument.elements[index].fontName = reference.fontName
                    page.canvasDocument.elements[index].bold = reference.bold
                    page.canvasDocument.elements[index].italic = reference.italic
                    page.canvasDocument.elements[index].textAlignment = reference.textAlignment
                    page.canvasDocument.elements[index].fontSize = reference.fontSize
                }
            }
        }
    }

    func selectionRect(on pageID: UUID) -> CGRect? {
        guard let document = page(id: pageID)?.canvasDocument else { return nil }
        let selected = document.elements.filter { selectedElementIDs.contains($0.id) && !$0.hidden }
        guard let first = selected.first else { return nil }
        return selected.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
    }

    func toggleHidden(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.hidden.toggle()
        }
    }

    func toggleLocked(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.locked.toggle()
        }
    }

    func updateOpacity(_ elementID: UUID, on pageID: UUID, delta: Double) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.opacity = min(max(element.opacity + delta, 0.2), 1)
        }
    }

    func updateOpacity(_ elementID: UUID, on pageID: UUID, value: Double) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked else { return }
            element.opacity = min(max(value, 0.2), 1)
        }
    }

    func updateCornerRadius(_ elementID: UUID, on pageID: UUID, delta: CGFloat) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.cornerRadius = min(max(element.cornerRadius + delta, 0), 80)
        }
    }

    func updateCornerRadius(_ elementID: UUID, on pageID: UUID, value: CGFloat) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked else { return }
            element.cornerRadius = min(max(value, 0), 80)
        }
    }

    func updateSelectedElementColor(_ colorHex: String, on pageID: UUID) {
        let targetIDs = selectedElementIDs
        guard !targetIDs.isEmpty else { return }
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for id in targetIDs {
                guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == id }),
                      !page.canvasDocument.elements[index].locked else { continue }
                page.canvasDocument.elements[index].colorHex = colorHex
            }
        }
    }

    func updateTextElement(_ elementID: UUID, style: TextStyleParameters, on pageID: UUID) {
        let trimmed = style.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked,
                  element.kind == .text || element.kind == .wordArt else { return }
            element.text = trimmed
            element.fontName = style.fontName
            element.fontSize = style.fontSize
            element.opacity = style.opacity
            element.colorHex = style.colorHex
            element.backgroundHex = style.backgroundHex
            element.strokeHex = style.strokeHex
            element.strokeWidth = style.strokeWidth
            element.textShadowEnabled = style.shadowEnabled
            element.shadowColorHex = style.shadowColorHex
            element.bold = style.bold
            element.italic = style.italic
            element.textAlignment = style.alignment
            element.width = style.width
            element.shadow = style.shadowEnabled
            element.stroke = style.strokeWidth > 0
        }
    }

    func updateLinkElement(_ elementID: UUID, link: LinkCardParameters, on pageID: UUID) {
        let trimmedURL = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        let title = link.title.trimmingCharacters(in: .whitespacesAndNewlines)
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked,
                  element.kind == .link else { return }
            element.text = title.isEmpty ? trimmedURL : title
            element.linkURL = normalizedLinkURL(trimmedURL)
            element.colorHex = link.colorHex
        }
    }

    func updateElementNote(_ note: String, elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked else { return }
            element.note = trimmed.isEmpty ? nil : trimmed
        }
    }

    func toggleShadow(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.shadow.toggle()
        }
    }

    func toggleStroke(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.stroke.toggle()
        }
    }

    func updateLineWidth(_ elementID: UUID, on pageID: UUID, delta: CGFloat) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked, element.supportsLineWidth else { return }
            element.brushWidth = min(max(element.brushWidth + delta, 4), 140)
            if element.kind == .connector,
               element.connectorStartID == nil,
               element.connectorEndID == nil {
                let endpoints = freeConnectorEndpoints(for: element)
                applyFreeConnectorGeometry(start: endpoints.start, end: endpoints.end, to: &element)
            }
        }
    }

    func updateLineWidth(_ elementID: UUID, on pageID: UUID, width: CGFloat) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked, element.supportsLineWidth else { return }
            element.brushWidth = min(max(width, 4), 140)
            if element.kind == .connector,
               element.connectorStartID == nil,
               element.connectorEndID == nil {
                let endpoints = freeConnectorEndpoints(for: element)
                applyFreeConnectorGeometry(start: endpoints.start, end: endpoints.end, to: &element)
            }
        }
    }

    func updateTapeLength(_ elementID: UUID, on pageID: UUID, delta: CGFloat) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked, element.kind == .tape else { return }
            let bounds = elementSizeBounds(on: pageID)
            element.width = min(max(element.width + delta, 90), bounds.maxWidth)
        }
    }

    func updateTapeLength(_ elementID: UUID, on pageID: UUID, width: CGFloat) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            guard !element.locked, element.kind == .tape else { return }
            let bounds = elementSizeBounds(on: pageID)
            element.width = min(max(width, 90), bounds.maxWidth)
        }
    }

    func undo(pageID: UUID) {
        guard var stack = undoStacks[pageID], let previous = stack.popLast() else { return }
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        objectWillChange.send()
        var page = pages[index]
        redoStacks[pageID, default: []].append(page.canvasDocument)
        page.canvasDocument = previous
        page.canvasDocument.updatedAt = Date()
        page.updatedAt = Date()
        pages[index] = page
        undoStacks[pageID] = stack
        setSelectedElementIDs([])
        canvasRevision += 1
        save()
    }

    func redo(pageID: UUID) {
        guard var stack = redoStacks[pageID], let next = stack.popLast() else { return }
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        objectWillChange.send()
        var page = pages[index]
        undoStacks[pageID, default: []].append(page.canvasDocument)
        page.canvasDocument = next
        page.canvasDocument.updatedAt = Date()
        page.updatedAt = Date()
        pages[index] = page
        redoStacks[pageID] = stack
        setSelectedElementIDs([])
        canvasRevision += 1
        save()
    }

    func canUndo(pageID: UUID) -> Bool {
        !(undoStacks[pageID]?.isEmpty ?? true)
    }

    func canRedo(pageID: UUID) -> Bool {
        !(redoStacks[pageID]?.isEmpty ?? true)
    }

    func beginUndoGroup(for pageID: UUID) {
        storeUndoSnapshot(for: pageID)
    }

    private func storeUndoSnapshot(for pageID: UUID) {
        guard let document = page(id: pageID)?.canvasDocument else { return }
        undoStacks[pageID, default: []].append(document)
        if (undoStacks[pageID]?.count ?? 0) > 40 {
            undoStacks[pageID]?.removeFirst()
        }
        redoStacks[pageID] = []
    }

    private func normalizeLayerOrder(on pageID: UUID) {
        mutatePage(pageID) { page in
            let sortedIDs = page.canvasDocument.elements
                .sorted { $0.zIndex < $1.zIndex }
                .map(\.id)
            for (index, id) in sortedIDs.enumerated() {
                guard let elementIndex = page.canvasDocument.elements.firstIndex(where: { $0.id == id }) else { continue }
                page.canvasDocument.elements[elementIndex].zIndex = index + 1
            }
        }
    }

    private enum SelectionLayerMode {
        case forward
        case backward
        case front
        case back
    }

    private func adjustElementLayer(_ elementID: UUID, on pageID: UUID, mode: SelectionLayerMode) {
        guard let document = page(id: pageID)?.canvasDocument,
              let element = document.elements.first(where: { $0.id == elementID }),
              !element.locked else { return }
        adjustLayerOrder(on: pageID, selectedIDs: [elementID], mode: mode)
    }

    private func adjustSelectionLayer(on pageID: UUID, mode: SelectionLayerMode) {
        guard !selectedElementIDs.isEmpty else { return }
        guard let document = page(id: pageID)?.canvasDocument else { return }
        let sorted = document.elements.sorted { $0.zIndex < $1.zIndex }
        let selected = sorted.filter { selectedElementIDs.contains($0.id) && !$0.locked }
        guard !selected.isEmpty else { return }
        adjustLayerOrder(on: pageID, selectedIDs: Set(selected.map(\.id)), mode: mode)
    }

    private func adjustLayerOrder(on pageID: UUID, selectedIDs: Set<UUID>, mode: SelectionLayerMode) {
        guard !selectedIDs.isEmpty else { return }
        guard let document = page(id: pageID)?.canvasDocument else { return }
        let sorted = document.elements.sorted { $0.zIndex < $1.zIndex }
        let selected = sorted.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        var orderedIDs = sorted.map(\.id)

        switch mode {
        case .forward:
            for id in selected.map(\.id).reversed() {
                guard let index = orderedIDs.firstIndex(of: id), index < orderedIDs.count - 1 else { continue }
                let nextID = orderedIDs[index + 1]
                guard !selectedIDs.contains(nextID) else { continue }
                orderedIDs.swapAt(index, index + 1)
            }
        case .backward:
            for id in selected.map(\.id) {
                guard let index = orderedIDs.firstIndex(of: id), index > 0 else { continue }
                let previousID = orderedIDs[index - 1]
                guard !selectedIDs.contains(previousID) else { continue }
                orderedIDs.swapAt(index, index - 1)
            }
        case .front:
            orderedIDs.removeAll { selectedIDs.contains($0) }
            orderedIDs.append(contentsOf: selected.map(\.id))
        case .back:
            orderedIDs.removeAll { selectedIDs.contains($0) }
            orderedIDs.insert(contentsOf: selected.map(\.id), at: 0)
        }

        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            for (index, id) in orderedIDs.enumerated() {
                guard let elementIndex = page.canvasDocument.elements.firstIndex(where: { $0.id == id }) else { continue }
                page.canvasDocument.elements[elementIndex].zIndex = index + 1
            }
        }
    }

    private func mutateElement(_ elementID: UUID, on pageID: UUID, autosave: Bool = true, mutation: (inout CanvasElement) -> Void) {
        mutatePage(pageID, autosave: autosave) { page in
            guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == elementID }) else { return }
            mutation(&page.canvasDocument.elements[index])
        }
    }

    private func setSelectedElementIDs(_ ids: Set<UUID>) {
        guard selectedElementIDs != ids else { return }
        selectedElementIDs = ids
    }

    private func mutatePage(_ pageID: UUID, autosave: Bool = true, mutation: (inout JournalPage) -> Void) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        objectWillChange.send()
        var page = pages[index]
        mutation(&page)
        refreshLinkedConnectors(in: &page)
        let shouldPersist = autosave && !draftPageIDs.contains(pageID)
        if autosave {
            page.updatedAt = Date()
            page.canvasDocument.updatedAt = Date()
        }
        pages[index] = page
        if shouldPersist {
            touchNotebook(page.notebookID)
            canvasRevision += 1
            saveNow()
        } else if autosave {
            touchNotebook(page.notebookID)
            canvasRevision += 1
        }
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func touchNotebook(_ notebookID: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        objectWillChange.send()
        notebooks[index].updatedAt = Date()
    }

    private func refreshLinkedConnectors(in page: inout JournalPage) {
        let elementsByID = Dictionary(uniqueKeysWithValues: page.canvasDocument.elements.map { ($0.id, $0) })
        for index in page.canvasDocument.elements.indices {
            guard page.canvasDocument.elements[index].kind == .connector,
                  let startID = page.canvasDocument.elements[index].connectorStartID,
                  let endID = page.canvasDocument.elements[index].connectorEndID,
                  let start = elementsByID[startID],
                  let end = elementsByID[endID] else { continue }
            let geometry = connectorGeometry(from: start, to: end)
            page.canvasDocument.elements[index].x = geometry.center.x
            page.canvasDocument.elements[index].y = geometry.center.y
            page.canvasDocument.elements[index].width = geometry.width
            page.canvasDocument.elements[index].height = geometry.height
            page.canvasDocument.elements[index].rotation = geometry.rotation
        }
    }

    private func connectorGeometry(from start: CanvasElement, to end: CanvasElement) -> (center: CGPoint, width: CGFloat, height: CGFloat, rotation: Double) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(hypot(dx, dy), 260)
        let connectorWidth = min(max(distance * 0.88, 260), 980)
        let connectorHeight = min(max(abs(dy) * 0.42 + 150, 130), 360)
        let connectorRotation = Double(atan2(dy, dx) * 180 / .pi)
        let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        return (midpoint, connectorWidth, connectorHeight, connectorRotation)
    }

    private func freeConnectorEndpoints(for element: CanvasElement) -> (start: CGPoint, end: CGPoint) {
        if let startPoint = element.connectorStartPoint, let endPoint = element.connectorEndPoint {
            return (CGPoint(x: startPoint.x, y: startPoint.y), CGPoint(x: endPoint.x, y: endPoint.y))
        }
        let radians = element.rotation * .pi / 180
        let halfLength = max(element.width, 120) / 2
        let dx = cos(radians) * halfLength
        let dy = sin(radians) * halfLength
        return (
            CGPoint(x: element.x - dx, y: element.y - dy),
            CGPoint(x: element.x + dx, y: element.y + dy)
        )
    }

    private func applyFreeConnectorGeometry(start: CGPoint, end: CGPoint, to element: inout CanvasElement) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(hypot(dx, dy), 80)
        element.connectorStartPoint = CodablePoint(x: start.x, y: start.y)
        element.connectorEndPoint = CodablePoint(x: end.x, y: end.y)
        element.x = (start.x + end.x) / 2
        element.y = (start.y + end.y) / 2
        element.width = min(max(distance, 120), 1400)
        element.height = min(max(element.brushWidth * 5.4, 90), 280)
        element.rotation = Double(atan2(dy, dx) * 180 / .pi)
    }

    private func elementSizeBounds(on pageID: UUID) -> (minWidth: CGFloat, minHeight: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat) {
        let canvasSize = page(id: pageID)?.canvasDocument.canvasSize ?? CanvasDocument.designCanvasSize
        return (
            minWidth: 42,
            minHeight: 42,
            maxWidth: max(120, canvasSize.width * 1.35),
            maxHeight: max(120, canvasSize.height * 1.35)
        )
    }

    private func rebuildSortIndexes(in notebookID: UUID, saveAfterRebuild: Bool = true) {
        let sortedIDs = pages(for: notebookID).map(\.id)
        for (index, pageID) in sortedIDs.enumerated() {
            guard let pageIndex = pages.firstIndex(where: { $0.id == pageID }) else { continue }
            pages[pageIndex].sortIndex = sortedIDs.count - index
        }
        touchNotebook(notebookID)
        if saveAfterRebuild {
            save()
        }
    }

    private func nextSortIndex(in notebookID: UUID) -> Int {
        (pages.filter { $0.notebookID == notebookID }.map(\.sortIndex).max() ?? 0) + 1
    }

    private func resolvedNotebookID(preferred notebookID: UUID?) -> UUID {
        if let notebookID, notebooks.contains(where: { $0.id == notebookID }) {
            return notebookID
        }
        return defaultNotebookID()
    }

    private func defaultNotebookID() -> UUID {
        if notebooks.isEmpty {
            bootstrapIfNeeded()
        }
        if let activeNotebook = notebooks.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            return activeNotebook.id
        }
        if let firstNotebook = notebooks.first {
            return firstNotebook.id
        }
        let notebook = TravelNotebook(
            title: Self.defaultNotebookTitle,
            coverPageID: nil,
            tintName: "sage",
            symbol: "cloud.sun.fill"
        )
        notebooks = [notebook]
        save()
        return notebook.id
    }

    private func ensureNotebookExists(_ notebookID: UUID) {
        if notebooks.contains(where: { $0.id == notebookID }) {
            return
        }
        let notebook = TravelNotebook(
            id: notebookID,
            title: Self.defaultNotebookTitle,
            coverPageID: nil,
            tintName: "sage",
            symbol: "cloud.sun.fill"
        )
        notebooks.insert(notebook, at: 0)
    }

    @discardableResult
    private func ensurePageExists(_ pageID: UUID, title: String = "Recovered Page") -> Bool {
        if pages.contains(where: { $0.id == pageID }) {
            return true
        }
        recoverMissingPageIfNeeded(pageID, title: title)
        return pages.contains(where: { $0.id == pageID })
    }

    private func recoverMissingPageIfNeeded(_ pageID: UUID, title: String = "Recovered Page") {
        guard !pages.contains(where: { $0.id == pageID }) else { return }
        let notebookID = defaultNotebookID()
        ensureNotebookExists(notebookID)
        let page = JournalPage(
            id: pageID,
            notebookID: notebookID,
            title: title,
            sortIndex: nextSortIndex(in: notebookID),
            canvasDocument: CanvasDocument(pageID: pageID)
        )
        pages.insert(page, at: 0)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: databaseURL) else { return }
        guard let snapshot = try? JSONDecoder.travelClip.decode(LocalSnapshot.self, from: data) else { return }
        notebooks = snapshot.notebooks
        pages = snapshot.pages
        normalizeLoadedPages()
    }

    private func save() {
        saveNow()
    }

    private func scheduleSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            self?.pendingSaveTask = nil
            self?.saveNow()
        }
    }

    private func saveNow() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        do {
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            let snapshot = LocalSnapshot(notebooks: notebooks, pages: pages)
            let data = try JSONEncoder.travelClip.encode(snapshot)
            try data.write(to: databaseURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save local notebook database: \(error)")
        }
    }

    private func recoverBundledAsset(named assetName: String) -> URL? {
        let materialURL = materialGroups
            .flatMap(\.items)
            .first { item in
                item.fileName == assetName || item.fileURL.lastPathComponent == assetName
            }?
            .fileURL
        if let materialURL {
            return materialURL
        }

        return tapeGroups
            .flatMap(\.items)
            .first { item in
                item.fileName == assetName || item.fileURL?.lastPathComponent == assetName
            }?
            .fileURL
    }

    private func recoverAssetBySuffix(_ assetName: String) -> URL? {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: assetsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        return urls.first { url in
            let name = url.lastPathComponent
            return name == assetName || name.hasSuffix("-\(assetName)")
        }
    }

    private func normalizeLoadedPages() {
        var changed = false
        let fallbackNotebookID = defaultNotebookID()
        let validNotebookIDs = Set(notebooks.map(\.id))

        for index in pages.indices {
            if !validNotebookIDs.contains(pages[index].notebookID) {
                pages[index].notebookID = fallbackNotebookID
                changed = true
            }
            let current = pages[index].canvasDocument.canvasSize
            if !current.matches(CanvasDocument.designCanvasSize) {
                pages[index].canvasDocument.canvasSize = CanvasDocument.designCanvasSize
                changed = true
            }
            if pages[index].canvasDocument.pageID != pages[index].id {
                pages[index].canvasDocument.pageID = pages[index].id
                changed = true
            }
            for elementIndex in pages[index].canvasDocument.elements.indices {
                guard let localPath = pages[index].canvasDocument.elements[elementIndex].localPath,
                      !localPath.isEmpty else { continue }
                let assetName = URL(fileURLWithPath: localPath).lastPathComponent
                guard !assetName.isEmpty, assetName != localPath else { continue }
                if fileManager.fileExists(atPath: assetsURL.appendingPathComponent(assetName).path)
                    || recoverBundledAsset(named: assetName) != nil
                    || recoverAssetBySuffix(assetName) != nil {
                    pages[index].canvasDocument.elements[elementIndex].localPath = assetName
                    changed = true
                }
            }
        }

        if changed {
            for notebookID in Set(pages.map(\.notebookID)) {
                rebuildSortIndexes(in: notebookID, saveAfterRebuild: false)
            }
            save()
        }
    }

    private func normalizedLinkURL(_ rawURL: String) -> String {
        guard URL(string: rawURL)?.scheme == nil else { return rawURL }
        return "https://\(rawURL)"
    }
}

private extension JSONEncoder {
    static var travelClip: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var travelClip: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
