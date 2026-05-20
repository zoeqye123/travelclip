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

    func addSticker(to pageID: UUID) {
        let symbols = ["sparkles", "heart.fill", "leaf.fill", "mappin.and.ellipse", "camera.fill", "airplane.departure"]
        let colors = ["#C4563F", "#7AA08C", "#D1B890", "#A9C0D2"]
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

    func addPhoto(_ item: PhotosPickerItem?, to pageID: UUID) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            let url = assetsURL.appendingPathComponent("\(UUID().uuidString).jpg")
            try data.write(to: url, options: Data.WritingOptions.atomic)
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

    func deleteElement(_ elementID: UUID, from pageID: UUID) {
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
            ("#E8F2EE", "#FFF7E6")
        ]
        let pair = options.randomElement() ?? options[0]
        mutatePage(pageID) { page in
            page.canvasDocument.background.colorA = pair.0
            page.canvasDocument.background.colorB = pair.1
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
