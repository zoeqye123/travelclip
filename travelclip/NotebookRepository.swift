//
//  NotebookRepository.swift
//  travelclip
//

import Combine
import PhotosUI
import Foundation
import SwiftUI

@MainActor
final class NotebookRepository: ObservableObject {
    @Published private(set) var notebooks: [TravelNotebook] = []
    @Published private(set) var pages: [JournalPage] = []
    @Published var selectedElementID: UUID?

    private let fileManager = FileManager.default
    private var undoStacks: [UUID: [CanvasDocument]] = [:]
    private var redoStacks: [UUID: [CanvasDocument]] = [:]

    private var databaseURL: URL {
        documentsURL.appendingPathComponent("travelclip-local-database.json")
    }

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var assetsURL: URL {
        documentsURL.appendingPathComponent("TravelClipAssets", isDirectory: true)
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
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        guard pages[index].canvasDocument.elements.isEmpty else { return }
        pages[index].canvasDocument.background = CanvasBackground(colorA: "#FFFFFF", colorB: "#FFFFFF")
        save()
    }

    func pages(for notebookID: UUID) -> [JournalPage] {
        pages
            .filter { $0.notebookID == notebookID }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    func page(id: UUID) -> JournalPage? {
        pages.first { $0.id == id }
    }

    func createNotebook(title: String, themeIndex: Int) -> UUID {
        let symbols = ["airplane.departure", "map.fill", "camera.fill", "sparkles", "photo.stack"]
        let tints = ["sand", "mist", "sage", "rose", "clay"]
        let index = max(0, min(themeIndex, tints.count - 1))
        let notebook = TravelNotebook(
            title: title,
            coverPageID: nil,
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

    func setCoverPage(_ pageID: UUID?, in notebookID: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        notebooks[index].coverPageID = pageID
        touchNotebook(notebookID)
        save()
    }

    @discardableResult
    func createPage(in notebookID: UUID?, title: String, template: PageTemplate, saveAfterCreate: Bool = true) -> UUID {
        let resolvedNotebookID = notebookID ?? defaultNotebookID()
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

        let sortIndex = pages(for: resolvedNotebookID).count
        let page = JournalPage(notebookID: resolvedNotebookID, title: title, sortIndex: sortIndex, canvasDocument: document)
        pages.insert(page, at: 0)
        touchNotebook(resolvedNotebookID)
        if saveAfterCreate {
            save()
        }
        return pageID
    }

    func addText(_ text: String, to pageID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            page.canvasDocument.elements.append(
                CanvasElement(
                    kind: .text,
                    text: trimmed,
                    x: 540,
                    y: 520,
                    width: 680,
                    height: 190,
                    zIndex: zIndex,
                    colorHex: "#2E2824",
                    fontSize: 78,
                    bold: true
                )
            )
        }
    }

    func addWordArt(_ text: String, to pageID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            page.canvasDocument.elements.append(
                CanvasElement(
                    kind: .wordArt,
                    text: trimmed,
                    x: 540,
                    y: 420,
                    width: 720,
                    height: 160,
                    rotation: -4,
                    zIndex: zIndex,
                    colorHex: "#B77255",
                    fontSize: 86,
                    bold: true
                )
            )
        }
    }

    func addSticker(to pageID: UUID) {
        let symbols = ["sparkles", "heart.fill", "leaf.fill", "mappin.and.ellipse", "camera.fill", "airplane.departure"]
        let colors = ["#C4563F", "#7AA08C", "#D1B890", "#A9C0D2"]
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            page.canvasDocument.elements.append(
                CanvasElement(
                    kind: .sticker,
                    symbol: symbols.randomElement() ?? "sparkles",
                    x: CGFloat(Int.random(in: 300...760)),
                    y: CGFloat(Int.random(in: 360...1000)),
                    width: 220,
                    height: 200,
                    rotation: Double.random(in: -10...10),
                    zIndex: zIndex,
                    colorHex: colors.randomElement() ?? "#C4563F"
                )
            )
        }
    }

    func addEffect(to pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            page.canvasDocument.elements.append(
                CanvasElement(
                    kind: .sticker,
                    symbol: "wand.and.sparkles",
                    x: CGFloat(Int.random(in: 300...780)),
                    y: CGFloat(Int.random(in: 360...980)),
                    width: 260,
                    height: 220,
                    rotation: Double.random(in: -12...12),
                    zIndex: zIndex,
                    opacity: 0.82,
                    colorHex: "#D99A8C"
                )
            )
        }
    }

    func addTape(to pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            page.canvasDocument.elements.append(
                CanvasElement(
                    kind: .tape,
                    x: 540,
                    y: CGFloat(Int.random(in: 360...1080)),
                    width: 760,
                    height: 92,
                    rotation: Double.random(in: -8...8),
                    zIndex: zIndex,
                    colorHex: ["#E0B56D", "#A8C8B6", "#D99A8C", "#9DB7D1"].randomElement() ?? "#E0B56D"
                )
            )
        }
    }

    func addBrushStroke(to pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            page.canvasDocument.elements.append(
                CanvasElement(
                    kind: .brush,
                    x: 540,
                    y: CGFloat(Int.random(in: 460...1040)),
                    width: 620,
                    height: 170,
                    rotation: Double.random(in: -7...7),
                    zIndex: zIndex,
                    opacity: 0.72,
                    colorHex: ["#B77255", "#6F9D86", "#D6A858", "#7E8EAB"].randomElement() ?? "#B77255"
                )
            )
        }
    }

    func addPhoto(_ item: PhotosPickerItem?, to pageID: UUID) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let url = assetsURL.appendingPathComponent("\(UUID().uuidString).jpg")
            try data.write(to: url, options: Data.WritingOptions.atomic)
            storeUndoSnapshot(for: pageID)
            mutatePage(pageID) { page in
                let zIndex = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
                page.canvasDocument.elements.append(
                    CanvasElement(
                        kind: .image,
                        localPath: url.path,
                        x: 540,
                        y: 660,
                        width: 620,
                        height: 460,
                        rotation: -3,
                        zIndex: zIndex,
                        colorHex: "#A9C0D2"
                    )
                )
            }
        } catch {
            assertionFailure("Failed to persist selected image: \(error)")
        }
    }

    func moveElement(_ elementID: UUID, on pageID: UUID, to position: CGPoint) {
        mutateElement(elementID, on: pageID, autosave: false) { element in
            element.x = min(max(position.x, 80), 1000)
            element.y = min(max(position.y, 80), 1360)
        }
    }

    func scaleElement(_ elementID: UUID, on pageID: UUID, by factor: CGFloat) {
        mutateElement(elementID, on: pageID) { element in
            element.width = min(max(element.width * factor, 86), 980)
            element.height = min(max(element.height * factor, 64), 1200)
            element.fontSize = min(max(element.fontSize * factor, 24), 180)
        }
    }

    func rotateElement(_ elementID: UUID, on pageID: UUID, by degrees: Double) {
        mutateElement(elementID, on: pageID) { element in
            element.rotation += degrees
        }
    }

    func transformElement(_ elementID: UUID, on pageID: UUID, scale: CGFloat, rotation: Double) {
        mutateElement(elementID, on: pageID, autosave: false) { element in
            element.width = min(max(element.width * scale, 86), 980)
            element.height = min(max(element.height * scale, 64), 1200)
            element.fontSize = min(max(element.fontSize * scale, 24), 180)
            element.rotation += rotation
        }
    }

    func deleteElement(_ elementID: UUID, from pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            page.canvasDocument.elements.removeAll { $0.id == elementID }
        }
        selectedElementID = nil
    }

    func commitPage(_ pageID: UUID) {
        guard pages.contains(where: { $0.id == pageID }) else { return }
        save()
    }

    func updateBackground(for pageID: UUID) {
        let options = [
            ("#FDF0D6", "#E4F1EC"),
            ("#F6E6E8", "#EAF1F7"),
            ("#FBF8F0", "#EDE4D1"),
            ("#E8F2EE", "#FFF7E6"),
            ("#FFFFFF", "#FFFFFF")
        ]
        let pair = options.randomElement() ?? options[0]
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            page.canvasDocument.background.colorA = pair.0
            page.canvasDocument.background.colorB = pair.1
        }
    }

    func applyTemplate(to pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutatePage(pageID) { page in
            let startZ = (page.canvasDocument.elements.map(\.zIndex).max() ?? 0) + 1
            page.canvasDocument.background = CanvasBackground(colorA: "#FFFFFF", colorB: "#FFFFFF")
            page.canvasDocument.elements.append(contentsOf: [
                CanvasElement(kind: .tape, x: 540, y: 250, width: 760, height: 90, rotation: -2, zIndex: startZ, colorHex: "#E4C385"),
                CanvasElement(kind: .image, x: 350, y: 570, width: 420, height: 320, rotation: -5, zIndex: startZ + 1, colorHex: "#A9C0D2"),
                CanvasElement(kind: .wordArt, text: "Travel clip", x: 620, y: 820, width: 560, height: 140, rotation: 3, zIndex: startZ + 2, colorHex: "#B77255", fontSize: 76, bold: true),
                CanvasElement(kind: .sticker, symbol: "sparkles", x: 790, y: 530, width: 150, height: 140, rotation: 8, zIndex: startZ + 3, colorHex: "#7AA08C")
            ])
        }
    }

    func bringForward(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.zIndex += 1
        }
        normalizeLayerOrder(on: pageID)
    }

    func sendBackward(_ elementID: UUID, on pageID: UUID) {
        storeUndoSnapshot(for: pageID)
        mutateElement(elementID, on: pageID) { element in
            element.zIndex -= 1
        }
        normalizeLayerOrder(on: pageID)
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

    func undo(pageID: UUID) {
        guard var stack = undoStacks[pageID], let previous = stack.popLast() else { return }
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        redoStacks[pageID, default: []].append(pages[index].canvasDocument)
        pages[index].canvasDocument = previous
        pages[index].updatedAt = Date()
        undoStacks[pageID] = stack
        selectedElementID = nil
        save()
    }

    func redo(pageID: UUID) {
        guard var stack = redoStacks[pageID], let next = stack.popLast() else { return }
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        undoStacks[pageID, default: []].append(pages[index].canvasDocument)
        pages[index].canvasDocument = next
        pages[index].updatedAt = Date()
        redoStacks[pageID] = stack
        selectedElementID = nil
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

    private func mutateElement(_ elementID: UUID, on pageID: UUID, autosave: Bool = true, mutation: (inout CanvasElement) -> Void) {
        mutatePage(pageID, autosave: autosave) { page in
            guard let index = page.canvasDocument.elements.firstIndex(where: { $0.id == elementID }) else { return }
            mutation(&page.canvasDocument.elements[index])
        }
    }

    private func mutatePage(_ pageID: UUID, autosave: Bool = true, mutation: (inout JournalPage) -> Void) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        mutation(&pages[index])
        pages[index].updatedAt = Date()
        pages[index].canvasDocument.updatedAt = Date()
        touchNotebook(pages[index].notebookID)
        if autosave {
            save()
        }
    }

    private func touchNotebook(_ notebookID: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        notebooks[index].updatedAt = Date()
    }

    private func rebuildSortIndexes(in notebookID: UUID) {
        let sortedIDs = pages(for: notebookID).map(\.id)
        for (index, pageID) in sortedIDs.enumerated() {
            guard let pageIndex = pages.firstIndex(where: { $0.id == pageID }) else { continue }
            pages[pageIndex].sortIndex = index
        }
        touchNotebook(notebookID)
        save()
    }

    private func defaultNotebookID() -> UUID {
        bootstrapIfNeeded()
        return notebooks[0].id
    }

    private func load() {
        guard let data = try? Data(contentsOf: databaseURL) else { return }
        guard let snapshot = try? JSONDecoder.travelClip.decode(LocalSnapshot.self, from: data) else { return }
        notebooks = snapshot.notebooks
        pages = snapshot.pages
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            let snapshot = LocalSnapshot(notebooks: notebooks, pages: pages)
            let data = try JSONEncoder.travelClip.encode(snapshot)
            try data.write(to: databaseURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save local notebook database: \(error)")
        }
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
