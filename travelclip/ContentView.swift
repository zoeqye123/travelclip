//
//  ContentView.swift
//  travelclip
//
//  Created by moc on 2026/5/18.
//

import Combine
import CoreText
import CoreGraphics
import AVKit
import CoreLocation
import ImageIO
import MapKit
import PhotosUI
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var repository = NotebookRepository()
    @State private var path: [TravelRoute] = []
    @State private var selectedRootTab: RootTab = .home

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(repository: repository, path: $path, selectedRootTab: $selectedRootTab)
                .navigationDestination(for: TravelRoute.self) { route in
                    switch route {
                    case .notebook(let notebookID):
                        NotebookDetailView(repository: repository, notebookID: notebookID, path: $path)
                    case .preview(let pageID):
                        PagePreviewView(repository: repository, pageID: pageID, path: $path)
                    case .presentation(let pageID):
                        CanvasPresentationView(repository: repository, pageID: pageID)
                    case .editor(let pageID):
                        CanvasEditorView(repository: repository, pageID: pageID)
                    case .editorLaunch(let pageID, let action):
                        CanvasEditorView(repository: repository, pageID: pageID, launchAction: action)
                    }
                }
        }
    }
}

private enum RootTab: String, CaseIterable, Identifiable {
    case home
    case store
    case universe
    case my

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .store: return "Store"
        case .universe: return "Universe"
        case .my: return "My"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .store: return "storefront"
        case .universe: return "globe.asia.australia"
        case .my: return "face.smiling"
        }
    }
}

private struct HomeView: View {
    @ObservedObject var repository: NotebookRepository
    @Binding var path: [TravelRoute]
    @Binding var selectedRootTab: RootTab
    @StateObject private var locationProvider = TravelLocationProvider()
    @State private var showingNewNotebook = false
    @State private var showingPlaceSearch = false
    @State private var showingNotifications = false

    var body: some View {
        ZStack(alignment: .bottom) {
            rootContent

            BottomTabBar(selectedTab: $selectedRootTab)
        }
        .background(PaperBackground().ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewNotebook) {
            NewNotebookSheet { title, themeIndex, coverImageData in
                showingNewNotebook = false
                let notebookID = repository.createNotebook(title: title, themeIndex: themeIndex, coverImageData: coverImageData)
                path.append(.notebook(notebookID))
            } onCancel: {
                showingNewNotebook = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingPlaceSearch) {
            PlaceSearchSheet(locationProvider: locationProvider) {
                showingPlaceSearch = false
            }
            .presentationDetents(EditorSheetSizing.addDetents)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotifications) {
            HomeNotificationSheet(
                notebooks: repository.notebooks,
                pages: repository.pages,
                onOpenPage: { pageID in
                    showingNotifications = false
                    path.append(.preview(pageID))
                },
                onDone: {
                    showingNotifications = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            repository.bootstrapIfNeeded()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch selectedRootTab {
        case .home:
            homeContent
        case .store:
            MaterialStoreHomeView(repository: repository, locationProvider: locationProvider) { action in
                createStorePage(action)
            }
        case .universe:
            UniverseRootTabView(repository: repository, locationProvider: locationProvider) { action in
                createStorePage(action)
            }
        case .my:
            MyLibraryRootTabView(
                repository: repository,
                path: $path,
                showingNewNotebook: $showingNewNotebook,
                onCreatePage: {
                    repository.createPageAndOpen(in: nil, title: "New Page", template: .blank) { pageID in
                        path.append(.editor(pageID))
                    }
                },
                onTemplatePage: {
                    repository.createPageAndOpen(in: nil, title: "Template Page", template: .postcard) { pageID in
                        path.append(.editor(pageID))
                    }
                }
            )
        }
    }

    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HeaderView(onNotifications: { showingNotifications = true })
                SearchCard(
                    title: locationProvider.placeDisplayName,
                    subtitle: locationProvider.statusText,
                    isSearching: locationProvider.isLocating,
                    placeLabel: locationProvider.mapDisplayName,
                    mapRegion: locationProvider.mapRegion,
                    onTap: { showingPlaceSearch = true },
                    onLocate: { locationProvider.requestLocation() }
                )
                CreateBanner(
                    onCreatePage: {
                        repository.createPageAndOpen(in: nil, title: "New Page", template: .blank) { pageID in
                            path.append(.editor(pageID))
                        }
                    },
                    onTemplatePage: {
                        repository.createPageAndOpen(in: nil, title: "Template Page", template: .postcard) { pageID in
                            path.append(.editor(pageID))
                        }
                    }
                )
                LocationStickerShelf(
                    repository: repository,
                    locationProvider: locationProvider,
                    onAddMaterial: { item in
                        let pageID = repository.createPage(in: nil, title: locationProvider.pageTitle, template: .blank, saveAfterCreate: false, draft: true)
                        switch repository.addMaterial(item, to: pageID, selectAfterInsert: false) {
                        case .success:
                            path.append(.editor(pageID))
                        case .failure:
                            path.append(.editor(pageID))
                        }
                    },
                    onAddSticker: { sticker in
                        let pageID = repository.createPage(in: nil, title: locationProvider.pageTitle, template: .blank, saveAfterCreate: false, draft: true)
                        repository.addSticker(sticker, to: pageID, selectAfterInsert: false)
                        path.append(.editor(pageID))
                    }
                )
                NotebookSection(repository: repository, path: $path, showingNewNotebook: $showingNewNotebook)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 116)
        }
    }

    private func createStorePage(_ action: StoreInsertAction) {
        let pageID = repository.createPage(in: nil, title: "Store Page", template: .blank, saveAfterCreate: false, draft: true)
        switch action {
        case .material(let item):
            _ = repository.addMaterial(item, to: pageID, selectAfterInsert: false)
        case .sticker(let sticker):
            repository.addSticker(sticker, to: pageID, selectAfterInsert: false)
        case .tape(let tape):
            _ = repository.addTape(tape, to: pageID, selectAfterInsert: false)
        case .textPreset(let preset):
            path.append(.editorLaunch(pageID, preset.kind == .wordArt ? .wordArtPreset(preset.id) : .textPreset(preset.id)))
            return
        case .brushPreset(let preset):
            path.append(.editorLaunch(pageID, .brushPreset(preset.id)))
            return
        case .background(let background):
            repository.updateBackground(background, for: pageID)
        case .template(let template):
            repository.applyTemplate(template, to: pageID)
        }
        path.append(.editor(pageID))
    }
}

private final class TravelLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var city: String?
    @Published private(set) var country: String?
    @Published private(set) var statusText = "Nearby stickers"
    @Published private(set) var isLocating = false
    @Published private(set) var searchedPlaceName: String?
    @Published private(set) var regionName: String?
    @Published private(set) var placeRevision = UUID()
    @Published private(set) var coordinate = CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579)
    @Published private(set) var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579),
        span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
    )

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var pageTitle: String {
        if let searchedPlaceName, !searchedPlaceName.isEmpty {
            return "\(searchedPlaceName) Page"
        }
        if let city, !city.isEmpty {
            return "\(city) Page"
        }
        return "Location Page"
    }

    var placeDisplayName: String {
        if let searchedPlaceName, !searchedPlaceName.isEmpty {
            return searchedPlaceName
        }
        let place = [city, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return place.isEmpty ? "Search places..." : place
    }

    var mapDisplayName: String {
        if let searchedPlaceName, !searchedPlaceName.isEmpty {
            return searchedPlaceName
        }
        if let city, !city.isEmpty {
            return city
        }
        return "Pick a place"
    }

    func applySearchResult(_ mapItem: MKMapItem) {
        searchedPlaceName = mapItem.name
        let rawName = mapItem.name ?? ""
        let subtitleParts = [
            mapItem.placemark.locality,
            mapItem.placemark.subAdministrativeArea,
            mapItem.placemark.administrativeArea,
            mapItem.placemark.country
        ]
        let searchableText = ([rawName] + subtitleParts.compactMap { $0 }).joined(separator: " ")
        city = normalizedKnownCity(from: searchableText)
            ?? mapItem.placemark.locality
            ?? mapItem.placemark.subAdministrativeArea
            ?? mapItem.placemark.administrativeArea
            ?? mapItem.name
        country = normalizedKnownCountry(from: searchableText) ?? mapItem.placemark.country
        applyCoordinate(mapItem.placemark.coordinate)
        regionName = [mapItem.placemark.subAdministrativeArea, mapItem.placemark.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let place = [city, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        statusText = place.isEmpty ? "Showing place stickers" : "Stickers for \(place)"
        isLocating = false
        placeRevision = UUID()
    }

    func applySearchText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedCity = normalizedKnownCity(from: trimmed)
        searchedPlaceName = normalizedCity ?? trimmed
        city = normalizedCity ?? trimmed
        country = normalizedKnownCountry(from: trimmed)
        applyCoordinate(knownCoordinate(from: trimmed) ?? coordinate)
        regionName = nil
        statusText = "Stickers for \(city ?? trimmed)"
        isLocating = false
        placeRevision = UUID()
    }

    func requestLocation() {
        searchedPlaceName = nil
        placeRevision = UUID()
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            statusText = "Allow location to show nearby stickers"
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLocating = true
            statusText = "Finding nearby stickers..."
            if let location = manager.location {
                applyCoordinate(location.coordinate)
                placeRevision = UUID()
            }
            manager.requestLocation()
        case .denied, .restricted:
            statusText = "Location off. Showing travel stickers."
            isLocating = false
            applyCoordinate(knownCoordinate(from: city ?? "") ?? coordinate)
        @unknown default:
            statusText = "Showing travel stickers"
            isLocating = false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isLocating = false
            return
        }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor [weak self] in
                guard let provider = self else { return }
                provider.isLocating = false
                guard error == nil, let placemark = placemarks?.first else {
                    provider.statusText = "Showing travel stickers"
                    return
                }
                provider.city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
                provider.country = placemark.country
                provider.searchedPlaceName = nil
                provider.applyCoordinate(location.coordinate)
                provider.regionName = [placemark.subAdministrativeArea, placemark.administrativeArea]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let place = [provider.city, provider.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                provider.statusText = place.isEmpty ? "Nearby stickers" : "Stickers near \(place)"
                provider.placeRevision = UUID()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        statusText = "Could not locate. Showing travel stickers."
        placeRevision = UUID()
    }

    private func normalizedKnownCity(from text: String) -> String? {
        let key = text.locationKey
        if key.contains("shenzhen") || key.contains("深圳") {
            return "Shenzhen"
        }
        if key.contains("guangzhou") || key.contains("canton") || key.contains("广州") {
            return "Guangzhou"
        }
        return nil
    }

    private func knownCoordinate(from text: String) -> CLLocationCoordinate2D? {
        let key = text.locationKey
        if key.contains("shenzhen") || key.contains("深圳") {
            return CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579)
        }
        if key.contains("guangzhou") || key.contains("canton") || key.contains("广州") {
            return CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644)
        }
        return nil
    }

    private func applyCoordinate(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        mapRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
    }

    private func normalizedKnownCountry(from text: String) -> String? {
        let key = text.locationKey
        if key.contains("china") || key.contains("中国") || key.contains("深圳") || key.contains("广州") {
            return "China"
        }
        return nil
    }
}

private enum TravelRoute: Hashable {
    case notebook(UUID)
    case preview(UUID)
    case presentation(UUID)
    case editor(UUID)
    case editorLaunch(UUID, EditorLaunchAction)
}

private enum EditorLaunchAction: Hashable {
    case textPreset(String)
    case wordArtPreset(String)
    case brushPreset(String)
    case tape(String)
}

private enum ActiveCanvasTool: Equatable {
    case brush
    case arrow
}

private enum EditorSheetSizing {
    static let addDetents: Set<PresentationDetent> = [.height(520), .large]
}

private struct PageCreateContext: Identifiable {
    let id = UUID()
    let notebookID: UUID?
}

private struct PageNotebookMoveContext: Identifiable {
    let id = UUID()
    let pageID: UUID
}

private struct NotebookDetailView: View {
    @ObservedObject var repository: NotebookRepository
    let notebookID: UUID
    @Binding var path: [TravelRoute]
    @State private var pageTitle = ""
    @State private var pageBeingEdited: JournalPage?
    @State private var pageCreateContext: PageCreateContext?
    @State private var showingNotebookEditor = false
    @State private var exportItem: ShareableExport?
    @State private var showingShare = false

    private var notebook: TravelNotebook? {
        repository.notebooks.first { $0.id == notebookID }
    }

    private var pages: [JournalPage] {
        repository.pages(for: notebookID)
    }

    private let pageColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            PaperBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(notebook?.title ?? "Notebook")
                                .font(.system(size: 31, weight: .bold, design: .serif))
                                .foregroundStyle(Color.ink)

                            Text("\(pages.count) pages")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkSoft)
                        }

                        Spacer()

                        TrackedEditorToolButton(componentID: "notebook.detail.edit", disabled: false, action: {
                            showingNotebookEditor = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 42, height: 42)
                                .background(Color.paper)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.3))
                        }

                        if pages.isEmpty {
                            TrackedEditorToolButton(componentID: "notebook.detail.export.empty", disabled: true, action: {}) {
                                notebookExportIcon(disabled: true)
                            }
                        } else {
                            Menu {
                                Button {
                                    InteractionTelemetry.recordAction(componentID: "notebook.detail.export.pdf", disabled: false)
                                    exportNotebookPDF()
                                } label: {
                                    Label("PDF", systemImage: "doc.richtext")
                                }

                                Button {
                                    InteractionTelemetry.recordAction(componentID: "notebook.detail.export.zip", disabled: false)
                                    exportNotebookZIP()
                                } label: {
                                    Label("ZIP Archive", systemImage: "doc.zipper")
                                }
                            } label: {
                                notebookExportIcon(disabled: false)
                            }
                            .buttonStyle(.plain)
                        }

                        TrackedEditorToolButton(componentID: "notebook.detail.new-page", disabled: false, action: {
                            pageCreateContext = PageCreateContext(notebookID: notebookID)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 42, height: 42)
                                .background(Color.paper)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.3))
                        }
                    }

                    LazyVGrid(columns: pageColumns, spacing: 14) {
                        ForEach(pages) { page in
                            NotebookPageCard(
                                repository: repository,
                                page: page,
                                isCover: notebook?.coverPageID == page.id,
                                onOpen: {
                                    path.append(.preview(page.id))
                                },
                                onRename: {
                                    pageTitle = page.title
                                    pageBeingEdited = page
                                },
                                onDelete: {
                                    repository.deletePage(page.id)
                                },
                                onSetCover: {
                                    repository.setCoverPage(page.id, in: notebookID)
                                }
                            )
                        }
                    }
                }
                .padding(18)
            }
        }
        .sheet(item: $pageBeingEdited) { page in
            RenamePageSheet(
                title: $pageTitle,
                onCancel: { pageBeingEdited = nil },
                onConfirm: {
                    repository.renamePage(page.id, to: pageTitle)
                    pageBeingEdited = nil
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $pageCreateContext) { context in
            NewPageSheet(
                onNewPage: {
                    pageCreateContext = nil
                    repository.createPageAndOpen(in: context.notebookID, title: "New Page", template: .blank) { pageID in
                        path.append(.editor(pageID))
                    }
                },
                onTemplate: {
                    pageCreateContext = nil
                    repository.createPageAndOpen(in: context.notebookID, title: "Template Page", template: .postcard) { pageID in
                        path.append(.editor(pageID))
                    }
                }
            )
            .presentationDetents([.height(190)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotebookEditor) {
            if let notebook {
                NotebookEditSheet(
                    notebook: notebook,
                    canDelete: repository.notebooks.count > 1,
                    onCancel: { showingNotebookEditor = false },
                    onRename: { title in
                        repository.renameNotebook(notebook.id, to: title)
                        showingNotebookEditor = false
                    },
                    onDelete: {
                        repository.deleteNotebook(notebook.id)
                        showingNotebookEditor = false
                        path.removeAll { route in
                            if case .notebook(notebook.id) = route {
                                return true
                            }
                            return false
                        }
                    }
                )
                .presentationDetents([.height(330), .medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingShare) {
            if let exportItem {
                ShareSheet(items: [exportItem.item])
                    .presentationDetents([.medium])
            }
        }
    }

    private func exportNotebookPDF() {
        guard let notebook,
              let pdfURL = makeNotebookPDF(notebook: notebook, pages: pages) else { return }
        exportItem = ShareableExport(item: pdfURL)
        showingShare = true
    }

    private func exportNotebookZIP() {
        guard let notebook,
              let zipURL = makeNotebookZIP(notebook: notebook, pages: pages) else { return }
        exportItem = ShareableExport(item: zipURL)
        showingShare = true
    }

    private func notebookExportIcon(disabled: Bool) -> some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(disabled ? Color.inkSoft.opacity(0.42) : Color.ink)
            .frame(width: 42, height: 42)
            .background(Color.paper)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.3))
    }

    private func makeNotebookPDF(notebook: TravelNotebook, pages: [JournalPage]) -> URL? {
        let renderers = pages.map { page in
            ImageRenderer(
                content: CanvasDocumentRenderer(
                    repository: repository,
                    document: page.canvasDocument,
                    scale: 1,
                    selectedElementIDs: []
                )
            )
        }
        renderers.forEach { $0.scale = 1 }
        let images = renderers.compactMap(\.uiImage)
        guard images.count == pages.count, let firstImage = images.first else { return nil }

        let safeTitle = notebook.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = "\((safeTitle.isEmpty ? "travelclip-notebook" : safeTitle))-\(notebook.id.uuidString.prefix(8)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let bounds = CGRect(origin: .zero, size: firstImage.size)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        do {
            try renderer.writePDF(to: url) { context in
                for image in images {
                    context.beginPage()
                    image.draw(in: bounds)
                }
            }
            return url
        } catch {
            assertionFailure("Failed to export notebook PDF: \(error)")
            return nil
        }
    }

    private func makeNotebookZIP(notebook: TravelNotebook, pages: [JournalPage]) -> URL? {
        let safeTitle = notebook.title.safeArchivePathComponent(fallback: "travelclip-notebook")
        let fileName = "\(safeTitle)-\(notebook.id.uuidString.prefix(8)).zip"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)

        var archive = StoredZipArchive()
        var pageManifests: [NotebookArchivePage] = []
        var archivedAssetNames: Set<String> = []

        for (index, page) in pages.enumerated() {
            let renderer = ImageRenderer(
                content: CanvasDocumentRenderer(
                    repository: repository,
                    document: page.canvasDocument,
                    scale: 1,
                    selectedElementIDs: []
                )
            )
            renderer.scale = 1
            if let imageData = renderer.uiImage?.pngData() {
                let pageName = "pages/\(String(format: "%03d", index + 1))-\(page.title.safeArchivePathComponent(fallback: "page")).png"
                archive.addFile(path: pageName, data: imageData)
            }

            var assetNames: [String] = []
            for element in page.canvasDocument.elements {
                guard let localPath = element.localPath,
                      let assetURL = repository.imageURL(for: localPath),
                      let assetData = try? Data(contentsOf: assetURL) else { continue }
                let assetName = assetURL.lastPathComponent.safeArchivePathComponent(fallback: "asset")
                let archivePath = "assets/\(assetName)"
                if !archivedAssetNames.contains(archivePath) {
                    archive.addFile(path: archivePath, data: assetData)
                    archivedAssetNames.insert(archivePath)
                }
                assetNames.append(archivePath)
            }

            pageManifests.append(
                NotebookArchivePage(
                    id: page.id.uuidString,
                    title: page.title,
                    updatedAt: page.updatedAt.formatted(.iso8601),
                    elementCount: page.canvasDocument.elements.count,
                    assets: assetNames
                )
            )
        }

        let manifest = NotebookArchiveManifest(
            notebookID: notebook.id.uuidString,
            title: notebook.title,
            exportedAt: Date().formatted(.iso8601),
            pages: pageManifests
        )

        if let manifestData = try? JSONEncoder.prettyArchive.encode(manifest) {
            archive.addFile(path: "manifest.json", data: manifestData)
        }

        do {
            try archive.write(to: url)
            return url
        } catch {
            assertionFailure("Failed to export notebook ZIP: \(error)")
            return nil
        }
    }
}

private struct NotebookPageCard: View {
    @ObservedObject var repository: NotebookRepository
    let page: JournalPage
    let isCover: Bool
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onSetCover: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "notebook.page.open.\(page.id.uuidString.lowercased())", disabled: false, action: onOpen) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    CanvasThumbnail(repository: repository, document: page.canvasDocument)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.92, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))

                    Rectangle()
                        .fill(Color.lineSoft.opacity(0.55))
                        .frame(height: 1)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(pageDateText)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)

                            HStack(spacing: 5) {
                                Text(page.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                if isCover {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.clay)
                                }
                            }
                        }

                        Spacer()

                        PageMoodBadge(symbol: pageMoodSymbol)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(minHeight: 62)
                }

                Menu {
                    Button("Rename", systemImage: "pencil") {
                        InteractionTelemetry.recordAction(componentID: "notebook.page.rename.\(page.id.uuidString.lowercased())", disabled: false)
                        onRename()
                    }
                    Button("Set as cover", systemImage: "star") {
                        InteractionTelemetry.recordAction(componentID: "notebook.page.cover.\(page.id.uuidString.lowercased())", disabled: false)
                        onSetCover()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        InteractionTelemetry.recordAction(componentID: "notebook.page.delete.\(page.id.uuidString.lowercased())", disabled: false)
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.clay)
                        .frame(width: 30, height: 30)
                        .background(Color.paper.opacity(0.92))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.1))
                        .shadow(color: Color.shadowSoft, radius: 6, x: 0, y: 3)
                }
                .menuStyle(.button)
                .padding(8)
            }
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
            .shadow(color: Color.shadowSoft, radius: 8, x: 0, y: 4)
        }
    }

    private var pageDateText: String {
        page.updatedAt.formatted(
            Date.FormatStyle()
                .year(.defaultDigits)
                .month(.twoDigits)
                .day(.twoDigits)
                .weekday(.abbreviated)
        )
    }

    private var pageMoodSymbol: String {
        if page.canvasDocument.elements.contains(where: { $0.kind == .image || $0.kind == .video }) {
            return "face.smiling"
        }
        if page.canvasDocument.elements.contains(where: { $0.kind == .link || $0.kind == .file }) {
            return "paperclip"
        }
        return "sparkles"
    }
}

private struct PageMoodBadge: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.ink)
            .frame(width: 38, height: 38)
            .background(Color.sand.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct PagePreviewView: View {
    @ObservedObject var repository: NotebookRepository
    let pageID: UUID
    @Binding var path: [TravelRoute]
    @State private var exportItem: ShareableExport?
    @State private var showingShare = false
    @Environment(\.dismiss) private var dismiss

    private var page: JournalPage? {
        repository.page(id: pageID)
    }

    var body: some View {
        ZStack {
            Color.editorPeach.ignoresSafeArea()

            if let page {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        TrackedEditorToolButton(componentID: "page.preview.back", disabled: false, action: {
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color.clay)
                                .frame(width: 42, height: 42)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(page.title)
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(Color.ink)
                                .lineLimit(1)

                            Text(page.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkSoft)
                        }

                        Spacer()

                        TrackedEditorToolButton(componentID: "page.preview.presentation", disabled: false, action: {
                            path.append(.presentation(page.id))
                        }) {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.clay)
                                .frame(width: 42, height: 42)
                                .background(Color.paper.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.1))
                        }

                        Menu {
                            Button {
                                InteractionTelemetry.recordAction(componentID: "page.preview.export.image", disabled: false)
                                exportImage(page.canvasDocument)
                            } label: {
                                Label("Image", systemImage: "photo")
                            }

                            Button {
                                InteractionTelemetry.recordAction(componentID: "page.preview.export.pdf", disabled: false)
                                exportPDF(page)
                            } label: {
                                Label("PDF", systemImage: "doc.richtext")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.clay)
                                .frame(width: 42, height: 42)
                                .background(Color.paper.opacity(0.7))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.1))
                        }
                        .buttonStyle(.plain)

                        TrackedEditorToolButton(componentID: "page.preview.edit", disabled: false, action: {
                            path.append(.editor(page.id))
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.paper)
                                .frame(width: 42, height: 42)
                                .background(Color.clay)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                    GeometryReader { proxy in
                        let scale = min(
                            (proxy.size.width - 28) / page.canvasDocument.canvasSize.width,
                            (proxy.size.height - 28) / page.canvasDocument.canvasSize.height
                        )

                        ScrollView([.vertical, .horizontal], showsIndicators: false) {
                            CanvasDocumentRenderer(
                                repository: repository,
                                document: page.canvasDocument,
                                scale: max(0.18, scale),
                                selectedElementIDs: []
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
                            .padding(14)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            } else {
                ContentUnavailableView("Page Missing", systemImage: "doc.questionmark")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingShare) {
            if let exportItem {
                ShareSheet(items: [exportItem.item])
                    .presentationDetents([.medium])
            }
        }
    }

    private func exportImage(_ document: CanvasDocument) {
        let renderer = ImageRenderer(
            content: CanvasDocumentRenderer(
                repository: repository,
                document: document,
                scale: 1,
                selectedElementIDs: []
            )
        )
        renderer.scale = 1
        guard let image = renderer.uiImage else { return }
        exportItem = ShareableExport(item: image)
        showingShare = true
    }

    private func exportPDF(_ page: JournalPage) {
        let renderer = ImageRenderer(
            content: CanvasDocumentRenderer(
                repository: repository,
                document: page.canvasDocument,
                scale: 1,
                selectedElementIDs: []
            )
        )
        renderer.scale = 1
        guard let image = renderer.uiImage,
              let pdfURL = makePDF(from: image, page: page) else { return }
        exportItem = ShareableExport(item: pdfURL)
        showingShare = true
    }

    private func makePDF(from image: UIImage, page: JournalPage) -> URL? {
        let safeTitle = page.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = "\((safeTitle.isEmpty ? "travelclip-page" : safeTitle))-\(page.id.uuidString.prefix(8)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let bounds = CGRect(origin: .zero, size: image.size)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                image.draw(in: bounds)
            }
            return url
        } catch {
            assertionFailure("Failed to export PDF: \(error)")
            return nil
        }
    }
}

private struct ShareableExport: Identifiable {
    let id = UUID()
    let item: Any
}

private struct FilePreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct CanvasInsertStatus: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

private struct CanvasInsertStatusBanner: View {
    let status: CanvasInsertStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(status.isError ? Color.red : Color.clay)

            Text(status.message)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.paper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(status.isError ? Color.red.opacity(0.35) : Color.clay.opacity(0.35), lineWidth: 1.2)
        )
        .shadow(color: Color.shadow, radius: 12, x: 0, y: 6)
    }
}

private enum InteractionTelemetry {
    static func logTap(componentID: String, disabled: Bool, location: CGPoint?) {
        let locationText: String
        if let location {
            locationText = "x=\(Int(location.x.rounded())) y=\(Int(location.y.rounded()))"
        } else {
            locationText = "x=unknown y=unknown"
        }
        print("[InteractionTelemetry] component=\(componentID) disabled=\(disabled) \(locationText)")
    }

    static func feedback(disabled: Bool) {
        if disabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func recordAction(componentID: String, disabled: Bool, location: CGPoint? = nil) {
        logTap(componentID: componentID, disabled: disabled, location: location)
        feedback(disabled: disabled)
    }
}

private struct TrackedEditorToolButton<Label: View>: View {
    let componentID: String
    let disabled: Bool
    let action: () -> Void
    @ViewBuilder var label: Label
    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        label
            .contentShape(Rectangle())
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            buttonFrame = proxy.frame(in: .global)
                        }
                        .onChange(of: proxy.size) { _, _ in
                            buttonFrame = proxy.frame(in: .global)
                        }
                }
            )
            .onTapGesture {
                let center = CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)
                InteractionTelemetry.logTap(componentID: componentID, disabled: disabled, location: center)
                InteractionTelemetry.feedback(disabled: disabled)
                guard !disabled else { return }
                action()
            }
            .accessibilityAddTraits(disabled ? .isStaticText : .isButton)
            .accessibilityHint(disabled ? Text("Unavailable for the current selection") : Text(""))
    }
}

private func telemetryIDSegment(_ value: String) -> String {
    let normalized = value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return normalized.isEmpty ? "unknown" : normalized
}

private struct TapePlacementBar: View {
    let title: String
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.clay)
                .frame(width: 34, height: 34)
                .background(Color.clay.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text("滑动放置一条直 tape")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
            }

            Spacer()

            TrackedEditorToolButton(componentID: "canvas.tape.placement.cancel", disabled: false, action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.inkSoft)
                    .frame(width: 34, height: 34)
                    .background(Color.paper)
                    .clipShape(Circle())
            }

            TrackedEditorToolButton(componentID: "canvas.tape.placement.done", disabled: false, action: onDone) {
                Text("Done")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.paper)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color.clay)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(Color.paper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        .shadow(color: Color.shadow, radius: 12, x: 0, y: 6)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

private struct NotebookArchiveManifest: Codable {
    let notebookID: String
    let title: String
    let exportedAt: String
    let pages: [NotebookArchivePage]
}

private struct NotebookArchivePage: Codable {
    let id: String
    let title: String
    let updatedAt: String
    let elementCount: Int
    let assets: [String]
}

private struct StoredZipArchive {
    private struct Entry {
        let path: String
        let data: Data
        let crc: UInt32
    }

    private var entries: [Entry] = []

    mutating func addFile(path: String, data: Data) {
        entries.append(Entry(path: path, data: data, crc: CRC32.checksum(data)))
    }

    func write(to url: URL) throws {
        var output = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            offsets.append(UInt32(output.count))
            let nameData = Data(entry.path.utf8)
            output.appendUInt32LE(0x04034b50)
            output.appendUInt16LE(20)
            output.appendUInt16LE(0)
            output.appendUInt16LE(0)
            output.appendUInt16LE(0)
            output.appendUInt16LE(0)
            output.appendUInt32LE(entry.crc)
            output.appendUInt32LE(UInt32(entry.data.count))
            output.appendUInt32LE(UInt32(entry.data.count))
            output.appendUInt16LE(UInt16(nameData.count))
            output.appendUInt16LE(0)
            output.append(nameData)
            output.append(entry.data)
        }

        let centralDirectoryOffset = UInt32(output.count)

        for (index, entry) in entries.enumerated() {
            let nameData = Data(entry.path.utf8)
            centralDirectory.appendUInt32LE(0x02014b50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(entry.crc)
            centralDirectory.appendUInt32LE(UInt32(entry.data.count))
            centralDirectory.appendUInt32LE(UInt32(entry.data.count))
            centralDirectory.appendUInt16LE(UInt16(nameData.count))
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(offsets[index])
            centralDirectory.append(nameData)
        }

        output.append(centralDirectory)
        output.appendUInt32LE(0x06054b50)
        output.appendUInt16LE(0)
        output.appendUInt16LE(0)
        output.appendUInt16LE(UInt16(entries.count))
        output.appendUInt16LE(UInt16(entries.count))
        output.appendUInt32LE(UInt32(centralDirectory.count))
        output.appendUInt32LE(centralDirectoryOffset)
        output.appendUInt16LE(0)
        try output.write(to: url, options: .atomic)
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0...255).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            crc = (crc & 1) == 1 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1)
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}

private extension JSONEncoder {
    static var prettyArchive: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension String {
    func safeArchivePathComponent(fallback: String) -> String {
        let value = components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return value.isEmpty ? fallback : value
    }
}

private struct CanvasPresentationView: View {
    @ObservedObject var repository: NotebookRepository
    let pageID: UUID
    @State private var stepIndex = 0
    @Environment(\.dismiss) private var dismiss

    private var page: JournalPage? {
        repository.page(id: pageID)
    }

    private var elements: [CanvasElement] {
        page?.canvasDocument.elements
            .filter { !$0.hidden }
            .sorted { $0.zIndex < $1.zIndex } ?? []
    }

    private var frames: [CanvasViewportFrame] {
        page?.canvasDocument.viewportFrames ?? []
    }

    private var usesSavedFrames: Bool {
        !frames.isEmpty
    }

    private var stepCount: Int {
        usesSavedFrames ? frames.count : max(1, elements.count + 1)
    }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()

            if let page {
                GeometryReader { proxy in
                    let document = page.canvasDocument
                    let fitScale = min(
                        proxy.size.width / document.canvasSize.width,
                        proxy.size.height / document.canvasSize.height
                    )
                    let focus = focusFrame(for: document)
                    let targetScale = targetScale(for: document, focus: focus, fitScale: fitScale, size: proxy.size)
                    let offset = CGSize(
                        width: proxy.size.width / 2 - focus.midX * targetScale,
                        height: proxy.size.height / 2 - focus.midY * targetScale
                    )

                    CanvasDocumentRenderer(
                        repository: repository,
                        document: document,
                        scale: targetScale,
                        selectedElementIDs: []
                    )
                    .offset(offset)
                    .animation(.spring(response: 0.58, dampingFraction: 0.86), value: stepIndex)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        TrackedEditorToolButton(componentID: "presentation.close", disabled: false, action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.paper)
                                .frame(width: 42, height: 42)
                                .background(Color.black.opacity(0.24))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Text("\(stepIndex + 1) / \(stepCount)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.paper)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(Color.black.opacity(0.22))
                            .clipShape(Capsule())

                        if usesSavedFrames, frames.indices.contains(stepIndex) {
                            Text(frames[stepIndex].title)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.paper)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(Color.black.opacity(0.22))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    Spacer()

                    HStack(spacing: 12) {
                        presentationButton("chevron.left", disabled: stepIndex == 0) {
                            stepIndex = max(0, stepIndex - 1)
                        }

                        presentationButton("chevron.right", disabled: stepIndex >= stepCount - 1) {
                            stepIndex = min(stepCount - 1, stepIndex + 1)
                        }
                    }
                    .padding(.bottom, 22)
                }
            } else {
                ContentUnavailableView("Page Missing", systemImage: "doc.questionmark")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func focusFrame(for document: CanvasDocument) -> CGRect {
        if usesSavedFrames, frames.indices.contains(stepIndex) {
            let frame = frames[stepIndex]
            let viewportWidth = document.canvasSize.width / max(frame.zoom, 0.75)
            let viewportHeight = document.canvasSize.height / max(frame.zoom, 0.75)
            let raw = CGRect(
                x: frame.center.x - viewportWidth / 2,
                y: frame.center.y - viewportHeight / 2,
                width: viewportWidth,
                height: viewportHeight
            )
            return raw.intersection(CGRect(origin: .zero, size: document.canvasSize.cgSize))
        }

        guard stepIndex > 0, elements.indices.contains(stepIndex - 1) else {
            return CGRect(origin: .zero, size: document.canvasSize.cgSize)
        }
        return elements[stepIndex - 1].bounds.insetBy(dx: -110, dy: -110)
    }

    private func targetScale(for document: CanvasDocument, focus: CGRect, fitScale: CGFloat, size: CGSize) -> CGFloat {
        if usesSavedFrames, frames.indices.contains(stepIndex) {
            let frameZoom = max(frames[stepIndex].zoom, 0.75)
            let frameScale = fitScale * frameZoom
            let focusScale = min(size.width / max(focus.width, 1), size.height / max(focus.height, 1)) * 0.86
            return min(max(frameScale, fitScale * 0.72), max(focusScale, fitScale))
        }

        return min(
            fitScale * (stepIndex == 0 ? 0.92 : 2.15),
            min(size.width / max(focus.width, 1), size.height / max(focus.height, 1)) * 0.72
        )
    }

    private func presentationButton(_ icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        TrackedEditorToolButton(componentID: "presentation.step.\(telemetryIDSegment(icon))", disabled: disabled, action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(disabled ? Color.paper.opacity(0.28) : Color.paper)
                .frame(width: 58, height: 50)
                .background(Color.black.opacity(disabled ? 0.12 : 0.28))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct CanvasEditorView: View {
    @ObservedObject var repository: NotebookRepository
    let pageID: UUID
    var launchAction: EditorLaunchAction?
    @StateObject private var locationProvider = TravelLocationProvider()
    @State private var draftText = ""
    @State private var textMode: TextInsertMode = .normal
    @State private var showingTextSheet = false
    @State private var showingLinkSheet = false
    @State private var showingNoteSheet = false
    @State private var objectShareItem: ShareableExport?
    @State private var showingObjectShare = false
    @State private var filePreviewItem: FilePreviewItem?
    @State private var pageMoveContext: PageNotebookMoveContext?
    @State private var editingElementID: UUID?
    @State private var draftNote = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingTicketSheet = false
    @State private var showingFileImporter = false
    @State private var activePanel: EditorPanel = .multi
    @State private var activeToolShelf: EditorToolShelf = .add
    @State private var activeCanvasTool: ActiveCanvasTool?
    @State private var activeBrushPreset: BrushPresetDefinition?
    @State private var activeBrushColorHex = "#B77255"
    @State private var activeBrushWidth: CGFloat = 46
    @State private var activeBrushOpacity = 0.72
    @State private var launchActionHandled = false
    @State private var pageFinished = false
    @State private var snapToGrid = true
    @State private var textStyle = TextStyleParameters(text: "")
    @State private var linkCard = LinkCardParameters()
    @State private var assetSheet: CanvasAssetSheet?
    @State private var insertStatus: CanvasInsertStatus?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private var page: JournalPage? {
        repository.page(id: pageID)
    }

    private var document: CanvasDocument {
        page?.canvasDocument ?? CanvasDocument(pageID: pageID)
    }

    private var selectedElementID: UUID? {
        guard let page, let selectedID = repository.selectedElementID else { return nil }
        return page.canvasDocument.elements.contains { $0.id == selectedID } ? selectedID : nil
    }

    private var selectedElementIDs: Set<UUID> {
        guard let page else { return [] }
        let availableIDs = Set(page.canvasDocument.elements.map(\.id))
        return repository.selectedElementIDs.intersection(availableIDs)
    }

    var body: some View {
        ZStack {
            Color.editorPeach.ignoresSafeArea()

            VStack(spacing: 0) {
                EditorTopBar(
                    canUndo: repository.canUndo(pageID: pageID),
                    canRedo: repository.canRedo(pageID: pageID),
                    activePanel: activePanel,
                    onBack: {
                        finishWithoutSavingIfDraft()
                        dismiss()
                    },
                    onUndo: { repository.undo(pageID: pageID) },
                    onRedo: { repository.redo(pageID: pageID) },
                    onLayer: {
                        clearActiveCanvasTool()
                        activePanel = .layer
                    },
                    onMulti: {
                        clearActiveCanvasTool()
                        activePanel = .multi
                    },
                    onMore: {
                        clearActiveCanvasTool()
                        activePanel = .more
                    },
                    onDone: {
                        pageFinished = true
                        repository.commitPage(pageID)
                        dismiss()
                    }
                )

                GeometryReader { proxy in
                    let panelHeight: CGFloat = activePanel == .multi ? 124 : 90

                    ZStack(alignment: .bottom) {
                        CanvasWorkspace(
                            document: document,
                            selectedElementID: selectedElementID,
                            selectedElementIDs: selectedElementIDs,
                            imageURL: { repository.imageURL(for: $0) },
                            onSelect: { elementID, _ in
                                repository.selectElement(elementID, extending: false, on: pageID)
                            },
                            onMoveStart: { repository.beginUndoGroup(for: pageID) },
                            onMove: { elementID, position in
                                repository.moveElement(elementID, on: pageID, to: position)
                            },
                            onMoveSelection: { positions, translation in
                                repository.moveSelection(on: pageID, from: positions, translation: translation)
                            },
                            onTransformSelection: { elements, rect, scale, rotation in
                                repository.transformSelection(on: pageID, from: elements, selectionRect: rect, scale: scale, rotation: rotation)
                            },
                            onCommit: {
                                repository.commitPage(pageID)
                            },
                            onDelete: { elementID in
                                repository.deleteElement(elementID, from: pageID)
                            },
                            onDeleteSelection: {
                                if selectedElementIDs.count > 1 {
                                    repository.deleteSelection(from: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.deleteElement(selectedID, from: pageID)
                                }
                            },
                            onBringForwardSelection: {
                                if selectedElementIDs.count > 1 {
                                    repository.bringSelectionForward(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.bringForward(selectedID, on: pageID)
                                }
                            },
                            onSendBackwardSelection: {
                                if selectedElementIDs.count > 1 {
                                    repository.sendSelectionBackward(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.sendBackward(selectedID, on: pageID)
                                }
                            },
                            onColorSelected: { colorHex in
                                repository.updateSelectedElementColor(colorHex, on: pageID)
                            },
                            onLineWidthSelected: { width in
                                if let selectedID = repository.selectedElementID {
                                    repository.updateLineWidth(selectedID, on: pageID, width: width)
                                }
                            },
                            onTapeLengthSelected: { width in
                                if let selectedID = repository.selectedElementID {
                                    repository.updateTapeLength(selectedID, on: pageID, width: width)
                                }
                            },
                            onOpacitySelected: { opacity in
                                if let selectedID = repository.selectedElementID {
                                    repository.updateOpacity(selectedID, on: pageID, value: opacity)
                                }
                            },
                            onCornerRadiusSelected: { radius in
                                if let selectedID = repository.selectedElementID {
                                    repository.updateCornerRadius(selectedID, on: pageID, value: radius)
                                }
                            },
                            onToggleStrokeSelected: {
                                if let selectedID = repository.selectedElementID {
                                    repository.toggleStroke(selectedID, on: pageID)
                                }
                            },
                            onToggleShadowSelected: {
                                if let selectedID = repository.selectedElementID {
                                    repository.toggleShadow(selectedID, on: pageID)
                                }
                            },
                            onDuplicateSelection: {
                                repository.duplicateSelection(on: pageID)
                            },
                            onToggleHiddenSelection: {
                                if selectedElementIDs.count > 1 {
                                    repository.toggleSelectionHidden(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.toggleHidden(selectedID, on: pageID)
                                }
                            },
                            onToggleLockedSelection: {
                                if selectedElementIDs.count > 1 {
                                    repository.toggleSelectionLocked(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.toggleLocked(selectedID, on: pageID)
                                }
                            },
                            onEditSelected: {
                                openSelectedElementEditor()
                            },
                            onTransformFromStart: { elementID, start, scale, rotation in
                                repository.transformElement(elementID, on: pageID, from: start, scale: scale, rotation: rotation)
                            },
                            onMoveConnectorEndpoint: { elementID, endpoint, point in
                                repository.moveConnectorEndpoint(elementID, on: pageID, endpoint: endpoint, to: point)
                            },
                            elementGestureTransformEnabled: activeCanvasTool == nil,
                            snapToGrid: snapToGrid,
                            activeCanvasTool: activeCanvasTool,
                            activeBrushColorHex: activeBrushColorHex,
                            activeBrushWidth: activeBrushWidth,
                            activeBrushOpacity: activeBrushOpacity,
                            onBrushFinished: { points in
                                repository.addBrushStroke(
                                    points,
                                    to: pageID,
                                    colorHex: activeBrushColorHex,
                                    brushWidth: activeBrushWidth,
                                    opacity: activeBrushOpacity
                                )
                            },
                            onArrowFinished: { start, end in
                                if let arrowID = repository.addConnector(to: pageID, start: start, end: end) {
                                    repository.selectElement(arrowID, extending: false, on: pageID)
                                    showInsertStatus("Arrow added")
                                } else {
                                    showInsertStatus("Could not add arrow", isError: true)
                                }
                            }
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)

                        EditorToolPanel(
                            activePanel: activePanel,
                            selectedShelf: $activeToolShelf,
                            document: document,
                            selectedElementID: selectedElementID,
                            selectedElementIDs: selectedElementIDs,
                            onSelect: { repository.selectElement($0, extending: false, on: pageID) },
                            onSelectAll: { repository.selectAll(on: pageID) },
                            onClearSelection: {
                                repository.commitPage(pageID)
                                repository.clearSelection()
                            },
                            onTemplate: {
                                clearActiveCanvasTool()
                                assetSheet = .templates
                            },
                            onText: {
                                beginTextEntry(
                                    with: TextStyleParameters(text: "", fontName: "Georgia", fontSize: 78, colorHex: "#2E2824", bold: true, width: 680),
                                    mode: .normal
                                )
                            },
                            onTextStyles: {
                                clearActiveCanvasTool()
                                assetSheet = .text
                            },
                            onLink: {
                                clearActiveCanvasTool()
                                editingElementID = nil
                                linkCard = LinkCardParameters()
                                showingLinkSheet = true
                            },
                            onFile: {
                                clearActiveCanvasTool()
                                showingFileImporter = true
                            },
                            onTicket: {
                                clearActiveCanvasTool()
                                showingTicketSheet = true
                            },
                            onPaste: {
                                clearActiveCanvasTool()
                                switch repository.pasteFromClipboard(to: pageID) {
                                case .success(let message):
                                    showInsertStatus(message)
                                case .failure(let error):
                                    showInsertStatus(error.localizedDescription, isError: true)
                                }
                            },
                            onConnector: {
                                if selectedElementIDs.count == 2 {
                                    clearActiveCanvasTool()
                                    if repository.connectSelection(on: pageID) != nil {
                                        showInsertStatus("Elements connected")
                                    } else {
                                        showInsertStatus("Select two unlocked items to connect", isError: true)
                                    }
                                } else {
                                    activateArrowTool()
                                }
                            },
                            onWordArt: {
                                beginTextEntry(
                                    with: TextStyleParameters(text: "", fontName: "Snell Roundhand", fontSize: 86, colorHex: "#B77255", bold: true, width: 720),
                                    mode: .wordArt
                                )
                            },
                            onWordArtStyles: {
                                clearActiveCanvasTool()
                                assetSheet = .wordArt
                            },
                            onEdit: {
                                openSelectedElementEditor()
                            },
                            onOpenObject: {
                                openSelectedObject()
                            },
                            onShareObject: {
                                shareSelectedObject()
                            },
                            onNote: {
                                openSelectedElementNote()
                            },
                            onEffect: {
                                clearActiveCanvasTool()
                                activePanel = .effect
                                repository.addEffect(to: pageID)
                            },
                            onSticker: {
                                clearActiveCanvasTool()
                                assetSheet = .stickers
                            },
                            onShape: {
                                clearActiveCanvasTool()
                                assetSheet = .shapes
                            },
                            onBackground: {
                                clearActiveCanvasTool()
                                assetSheet = .backgrounds
                            },
                            onTape: {
                                clearActiveCanvasTool()
                                assetSheet = .tapes
                            },
                            onBrush: {
                                activateBrushTool(preset: nil)
                            },
                            onDelete: {
                                if selectedElementIDs.count > 1 {
                                    repository.deleteSelection(from: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.deleteElement(selectedID, from: pageID)
                                }
                            },
                            onBringForward: {
                                if selectedElementIDs.count > 1 {
                                    repository.bringSelectionForward(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.bringForward(selectedID, on: pageID)
                                }
                            },
                            onSendBackward: {
                                if selectedElementIDs.count > 1 {
                                    repository.sendSelectionBackward(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.sendBackward(selectedID, on: pageID)
                                }
                            },
                            onBringToFront: {
                                if selectedElementIDs.count > 1 {
                                    repository.bringSelectionToFront(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.bringToFront(selectedID, on: pageID)
                                }
                            },
                            onSendToBack: {
                                if selectedElementIDs.count > 1 {
                                    repository.sendSelectionToBack(on: pageID)
                                } else if let selectedID = repository.selectedElementID {
                                    repository.sendToBack(selectedID, on: pageID)
                                }
                            },
                            onToggleHidden: {
                                if let selectedID = repository.selectedElementID {
                                    repository.toggleHidden(selectedID, on: pageID)
                                }
                            },
                            onToggleLocked: {
                                if let selectedID = repository.selectedElementID {
                                    repository.toggleLocked(selectedID, on: pageID)
                                }
                            },
                            onOpacityDown: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateOpacity(selectedID, on: pageID, delta: -0.12)
                                }
                            },
                            onOpacityUp: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateOpacity(selectedID, on: pageID, delta: 0.12)
                                }
                            },
                            onCornerDown: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateCornerRadius(selectedID, on: pageID, delta: -8)
                                }
                            },
                            onCornerUp: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateCornerRadius(selectedID, on: pageID, delta: 8)
                                }
                            },
                            onToggleShadow: {
                                if let selectedID = repository.selectedElementID {
                                    repository.toggleShadow(selectedID, on: pageID)
                                }
                            },
                            onToggleStroke: {
                                if let selectedID = repository.selectedElementID {
                                    repository.toggleStroke(selectedID, on: pageID)
                                }
                            },
                            onLineWidthDown: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateLineWidth(selectedID, on: pageID, delta: -6)
                                }
                            },
                            onLineWidthUp: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateLineWidth(selectedID, on: pageID, delta: 6)
                                }
                            },
                            onSetLineWidth: { width in
                                if let selectedID = repository.selectedElementID {
                                    repository.updateLineWidth(selectedID, on: pageID, width: width)
                                }
                            },
                            onTapeLengthDown: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateTapeLength(selectedID, on: pageID, delta: -40)
                                }
                            },
                            onTapeLengthUp: {
                                if let selectedID = repository.selectedElementID {
                                    repository.updateTapeLength(selectedID, on: pageID, delta: 40)
                                }
                            },
                            onSetTapeLength: { width in
                                if let selectedID = repository.selectedElementID {
                                    repository.updateTapeLength(selectedID, on: pageID, width: width)
                                }
                            },
                            onColor: { colorHex in
                                repository.updateSelectedElementColor(colorHex, on: pageID)
                            },
                            onAlign: { alignment in
                                repository.alignSelection(alignment, on: pageID)
                            },
                            onAlignCanvas: { alignment in
                                repository.alignSelectionToCanvas(alignment, on: pageID)
                            },
                            onDistribute: { axis in
                                repository.distributeSelection(axis, on: pageID)
                            },
                            onArrangeGrid: {
                                repository.arrangeSelectionGrid(on: pageID)
                            },
                            onMatchSize: {
                                repository.matchSelectionSize(on: pageID)
                            },
                            onApplyStyle: {
                                repository.applySelectedStyleToSelection(on: pageID)
                            },
                            onDuplicate: {
                                repository.duplicateSelection(on: pageID)
                            },
                            onGroup: {
                                repository.groupSelection(on: pageID)
                            },
                            onUngroup: {
                                repository.ungroupSelection(on: pageID)
                            },
                            snapToGrid: snapToGrid,
                            onToggleSnap: {
                                snapToGrid.toggle()
                            },
                            activeCanvasTool: activeCanvasTool,
                            activeBrushTitle: activeBrushPreset?.title,
                            activeBrushColorHex: activeBrushColorHex,
                            activeBrushWidth: activeBrushWidth,
                            activeBrushOpacity: activeBrushOpacity,
                            onBrushColor: { activeBrushColorHex = $0 },
                            onBrushWidth: { activeBrushWidth = min(max($0, 4), 140) },
                            onBrushOpacity: { activeBrushOpacity = min(max($0, 0.12), 1) },
                            onOpenBrushLibrary: {
                                assetSheet = .brush
                            },
                            onExitToolMode: {
                                clearActiveCanvasTool()
                                activePanel = .multi
                            },
                            photoPicker: {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    EditorToolItem(icon: "plus.circle", title: "Picture")
                                }
                                .buttonStyle(.plain)
                            }
                        )
                        .frame(width: proxy.size.width, height: panelHeight)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            repository.ensureEditableCanvas(for: pageID)
            locationProvider.requestLocation()
            Task { @MainActor in
                repository.ensureEditableCanvas(for: pageID)
                applyLaunchActionIfNeeded()
            }
            if selectedElementID == nil {
                repository.selectedElementID = nil
            }
        }
        .onDisappear {
            if !pageFinished, repository.isDraftPage(pageID) {
                repository.discardDraftPageIfNeeded(pageID)
            } else {
                repository.flushPendingSave()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                if !repository.isDraftPage(pageID) {
                    repository.flushPendingSave()
                }
            }
        }
        .sheet(isPresented: $showingTextSheet) {
            TextInputSheet(text: $draftText, style: $textStyle, mode: textMode) {
                var resolvedStyle = textStyle
                resolvedStyle.text = draftText
                if let editingElementID {
                    repository.updateTextElement(editingElementID, style: resolvedStyle, on: pageID)
                    self.editingElementID = nil
                    showingTextSheet = false
                    showInsertStatus("Text updated")
                    return nil
                } else {
                    let result: Result<UUID, CanvasInsertError>
                    switch textMode {
                    case .normal:
                        result = repository.addText(resolvedStyle, to: pageID)
                    case .wordArt:
                        result = repository.addWordArt(resolvedStyle, to: pageID)
                    }

                    switch result {
                    case .success:
                        showingTextSheet = false
                        showInsertStatus(textMode == .wordArt ? "WordArt added" : "Text added")
                        return nil
                    case .failure(let error):
                        return error.localizedDescription
                    }
                }
            }
            .presentationDetents(EditorSheetSizing.addDetents)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingLinkSheet) {
            LinkInputSheet(link: $linkCard) {
                if let editingElementID {
                    repository.updateLinkElement(editingElementID, link: linkCard, on: pageID)
                    self.editingElementID = nil
                    showingLinkSheet = false
                    showInsertStatus("Link updated")
                    return nil
                } else {
                    switch repository.addLink(linkCard, to: pageID) {
                    case .success:
                        showingLinkSheet = false
                        showInsertStatus("Link added")
                        return nil
                    case .failure(let error):
                        return error.localizedDescription
                    }
                }
            }
            .presentationDetents(EditorSheetSizing.addDetents)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNoteSheet) {
            ElementNoteSheet(note: $draftNote) {
                if let editingElementID {
                    repository.updateElementNote(draftNote, elementID: editingElementID, on: pageID)
                    self.editingElementID = nil
                }
                showingNoteSheet = false
            }
            .presentationDetents([.height(300), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTicketSheet) {
            TicketComposerSheet(repository: repository) { image in
                switch repository.addTicketImage(image, to: pageID) {
                case .success:
                    showingTicketSheet = false
                    showInsertStatus("Ticket added")
                    return nil
                case .failure(let error):
                    return error.localizedDescription
                }
            } onCancel: {
                showingTicketSheet = false
            }
            .presentationDetents([.height(620), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingObjectShare) {
            if let objectShareItem {
                ShareSheet(items: [objectShareItem.item])
                    .presentationDetents([.medium])
            }
        }
        .sheet(item: $filePreviewItem) { item in
            QuickLookPreview(url: item.url)
                .ignoresSafeArea()
        }
        .sheet(item: $pageMoveContext) { context in
            NotebookPickerSheet(
                repository: repository,
                currentNotebookID: page?.notebookID,
                onSelect: { notebookID in
                    repository.movePage(context.pageID, to: notebookID)
                    pageMoveContext = nil
                    dismiss()
                },
                onCancel: {
                    pageMoveContext = nil
                }
            )
            .presentationDetents(EditorSheetSizing.addDetents)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $assetSheet) { sheet in
            CanvasAssetPickerSheet(
                sheet: sheet,
                repository: repository,
                locationProvider: locationProvider,
                document: document,
                onTemplate: { template in
                    repository.applyTemplate(template, to: pageID)
                    assetSheet = nil
                },
                onTextPreset: { preset in
                    assetSheet = nil
                    beginTextEntry(with: preset.style, mode: preset.kind == .wordArt ? .wordArt : .normal)
                },
                onSticker: { sticker in
                    if repository.addSticker(sticker, to: pageID, selectAfterInsert: false) != nil {
                        showInsertStatus("Sticker added")
                    } else {
                        showInsertStatus("Could not add sticker", isError: true)
                    }
                    assetSheet = nil
                },
                onMaterial: { item in
                    switch repository.addMaterial(item, to: pageID, selectAfterInsert: false) {
                    case .success:
                        showInsertStatus("Material added")
                    case .failure(let error):
                        showInsertStatus(error.localizedDescription, isError: true)
                    }
                    assetSheet = nil
                },
                onShape: { shape in
                    if repository.addShape(shape, to: pageID) != nil {
                        showInsertStatus("Shape added")
                    } else {
                        showInsertStatus("Could not add shape", isError: true)
                    }
                    assetSheet = nil
                },
                onBackground: { background in
                    repository.updateBackground(background, for: pageID)
                    assetSheet = nil
                },
                onTape: { tape in
                    activateTapeTool(tape)
                    assetSheet = nil
                },
                onBrushPreset: { preset in
                    activateBrushTool(preset: preset)
                    assetSheet = nil
                },
                onCancel: {
                    assetSheet = nil
                }
            )
            .presentationDetents(EditorSheetSizing.addDetents)
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                let result = await repository.addPhoto(newItem, to: pageID)
                switch result {
                case .success:
                    activePanel = .multi
                    activeToolShelf = .add
                    showInsertStatus("Photo added")
                case .failure(let error):
                    showInsertStatus(error.localizedDescription, isError: true)
                }
                selectedPhoto = nil
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    showInsertStatus("No file selected", isError: true)
                    return
                }
                switch repository.addFile(from: url, to: pageID) {
                case .success:
                    showInsertStatus("File added")
                case .failure(let error):
                    showInsertStatus(error.localizedDescription, isError: true)
                }
            case .failure(let error):
                showInsertStatus(error.localizedDescription, isError: true)
            }
        }
        .overlay(alignment: .top) {
            if let insertStatus {
                CanvasInsertStatusBanner(status: insertStatus)
                    .padding(.top, 58)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func openSelectedObject() {
        guard let selectedElementID,
              let element = document.elements.first(where: { $0.id == selectedElementID }) else { return }

        switch element.kind {
        case .link:
            guard let linkURL = element.linkURL,
                  let url = URL(string: linkURL) else { return }
            UIApplication.shared.open(url)
        case .file, .video, .audio:
            guard let fileURL = repository.imageURL(for: element.localPath) else { return }
            filePreviewItem = FilePreviewItem(url: fileURL)
        default:
            return
        }
    }

    private func shareSelectedObject() {
        guard let selectedElementID,
              let element = document.elements.first(where: { $0.id == selectedElementID }),
              element.kind.isShareableAttachment,
              let fileURL = repository.imageURL(for: element.localPath) else { return }
        objectShareItem = ShareableExport(item: fileURL)
        showingObjectShare = true
    }

    private func openSelectedElementEditor() {
        guard let selectedElementID,
              let element = document.elements.first(where: { $0.id == selectedElementID }),
              !element.locked else { return }
        editingElementID = element.id
        switch element.kind {
        case .text, .wordArt:
            textMode = element.kind == .wordArt ? .wordArt : .normal
            draftText = element.text ?? ""
            textStyle = TextStyleParameters(
                text: element.text ?? "",
                fontName: element.fontName,
                fontSize: element.fontSize,
                colorHex: element.colorHex,
                bold: element.bold,
                italic: element.italic,
                alignment: element.textAlignment,
                width: element.width
            )
            showingTextSheet = true
        case .link:
            linkCard = LinkCardParameters(
                title: element.text ?? "",
                url: element.linkURL ?? "",
                colorHex: element.colorHex
            )
            showingLinkSheet = true
        default:
            editingElementID = nil
        }
    }

    private func applyLaunchActionIfNeeded() {
        guard !launchActionHandled, let launchAction else { return }
        launchActionHandled = true
        switch launchAction {
        case .textPreset(let presetID):
            let preset = repository.textPresetLibrary.first { $0.id == presetID }
            beginTextEntry(with: preset?.style, mode: .normal)
        case .wordArtPreset(let presetID):
            let preset = repository.wordArtLibrary.first { $0.id == presetID }
            beginTextEntry(with: preset?.style, mode: .wordArt)
        case .brushPreset(let presetID):
            activateBrushTool(preset: repository.brushPresetLibrary.first { $0.id == presetID })
        case .tape(let tapeID):
            let tape = repository.availableTapeGroups
                .flatMap(\.items)
                .first { $0.id == tapeID }
            guard let tape else {
                clearActiveCanvasTool()
                showInsertStatus("Tape unavailable", isError: true)
                return
            }
            activateTapeTool(tape)
        }
    }

    private func beginTextEntry(with style: TextStyleParameters?, mode: TextInsertMode) {
        clearActiveCanvasTool()
        textMode = mode
        editingElementID = nil
        let resolvedStyle = style ?? TextStyleParameters(
            text: "",
            fontName: mode == .wordArt ? "Snell Roundhand" : "Georgia",
            fontSize: mode == .wordArt ? 86 : 78,
            colorHex: mode == .wordArt ? "#B77255" : "#2E2824",
            bold: true,
            width: mode == .wordArt ? 720 : 680
        )
        draftText = resolvedStyle.text
        textStyle = resolvedStyle
        showingTextSheet = true
    }

    private func activateBrushTool(preset: BrushPresetDefinition?) {
        activeBrushPreset = preset
        if let preset {
            activeBrushColorHex = preset.colorHex
            activeBrushWidth = preset.width
            activeBrushOpacity = preset.opacity
        }
        activeCanvasTool = .brush
        activePanel = .tool
        showInsertStatus("Draw with brush")
    }

    private func activateTapeTool(_ tape: TapeDefinition) {
        if repository.addTape(tape, to: pageID) != nil {
            showInsertStatus("Tape added")
        } else {
            showInsertStatus("Could not add tape", isError: true)
        }
        clearActiveCanvasTool()
        activePanel = .multi
        activeToolShelf = .adjust
    }

    private func activateArrowTool() {
        activeBrushPreset = nil
        activeCanvasTool = .arrow
        activePanel = .tool
        repository.clearSelection()
        showInsertStatus("Drag to draw arrow")
    }

    private func clearActiveCanvasTool() {
        activeCanvasTool = nil
        activeBrushPreset = nil
    }

    private func finishWithoutSavingIfDraft() {
        if repository.isDraftPage(pageID) {
            repository.discardDraftPageIfNeeded(pageID)
        } else {
            repository.flushPendingSave()
        }
    }

    private func openSelectedElementNote() {
        guard let selectedElementID,
              let element = document.elements.first(where: { $0.id == selectedElementID }),
              !element.locked else { return }
        editingElementID = element.id
        draftNote = element.note ?? ""
        showingNoteSheet = true
    }

    private func showInsertStatus(_ message: String, isError: Bool = false) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            insertStatus = CanvasInsertStatus(message: message, isError: isError)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                insertStatus = nil
            }
        }
    }

}

private struct EditorTopBar: View {
    let canUndo: Bool
    let canRedo: Bool
    let activePanel: EditorPanel
    let onBack: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onLayer: () -> Void
    let onMulti: () -> Void
    let onMore: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            TrackedEditorToolButton(componentID: "editor.top.back", disabled: false, action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 34, height: 44)
                    .foregroundStyle(Color.clay)
            }

            Spacer(minLength: 2)

            EditorTopTool(icon: "arrow.uturn.backward", title: "Undo", selected: false, disabled: !canUndo, action: onUndo)
            EditorTopTool(icon: "arrow.uturn.forward", title: "Redo", selected: false, disabled: !canRedo, action: onRedo)
            EditorTopTool(icon: "square.stack.3d.up", title: "Layer", selected: activePanel == .layer, disabled: false, action: onLayer)
            EditorTopTool(icon: "square.dashed", title: "Multi", selected: activePanel == .multi, disabled: false, action: onMulti)
            EditorTopTool(icon: "ellipsis", title: "More", selected: activePanel == .more, disabled: false, action: onMore)

            TrackedEditorToolButton(componentID: "editor.top.done", disabled: false, action: onDone) {
                Text("OK")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.paper)
                    .frame(width: 42, height: 32)
                    .background(Color.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: Color.clay.opacity(0.18), radius: 0, x: 4, y: 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 5)
    }
}

private struct EditorTopTool: View {
    let icon: String
    let title: String
    let selected: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "editor.top.\(normalizedComponentID(title))", disabled: disabled, action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 32, height: 24)

                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(disabled ? Color.clay.opacity(0.24) : (selected ? Color.clay : Color.clay.opacity(0.82)))
            .frame(width: 42, height: 44)
            .background(selected ? Color.paper.opacity(0.55) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func normalizedComponentID(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }
}

private struct CanvasWorkspace: View {
    let document: CanvasDocument
    let selectedElementID: UUID?
    let selectedElementIDs: Set<UUID>
    let imageURL: (String?) -> URL?
    let onSelect: (UUID?, Bool) -> Void
    let onMoveStart: () -> Void
    let onMove: (UUID, CGPoint) -> Void
    let onMoveSelection: ([UUID: CGPoint], CGSize) -> Void
    let onTransformSelection: ([UUID: CanvasElement], CGRect, CGFloat, Double) -> Void
    let onCommit: () -> Void
    let onDelete: (UUID) -> Void
    let onDeleteSelection: () -> Void
    let onBringForwardSelection: () -> Void
    let onSendBackwardSelection: () -> Void
    let onColorSelected: (String) -> Void
    let onLineWidthSelected: (CGFloat) -> Void
    let onTapeLengthSelected: (CGFloat) -> Void
    let onOpacitySelected: (Double) -> Void
    let onCornerRadiusSelected: (CGFloat) -> Void
    let onToggleStrokeSelected: () -> Void
    let onToggleShadowSelected: () -> Void
    let onDuplicateSelection: () -> Void
    let onToggleHiddenSelection: () -> Void
    let onToggleLockedSelection: () -> Void
    let onEditSelected: () -> Void
    let onTransformFromStart: (UUID, CanvasElement, CGFloat, Double) -> Void
    let onMoveConnectorEndpoint: (UUID, ConnectorEndpoint, CGPoint) -> Void
    let elementGestureTransformEnabled: Bool
    let snapToGrid: Bool
    let activeCanvasTool: ActiveCanvasTool?
    let activeBrushColorHex: String
    let activeBrushWidth: CGFloat
    let activeBrushOpacity: Double
    let onBrushFinished: ([CGPoint]) -> Void
    let onArrowFinished: (CGPoint, CGPoint) -> Void
    @State private var dragStartFrames: [UUID: CGPoint] = [:]
    @State private var selectionDragStartFrames: [UUID: CGPoint] = [:]
    @State private var selectionDragStartRect: CGRect?
    @State private var selectionDragTranslation: CGSize?
    @State private var selectionTransformStartElements: [UUID: CanvasElement] = [:]
    @State private var selectionTransformStartRect: CGRect?
    @State private var selectionTransformPreview: [UUID: CanvasElement] = [:]
    @State private var undoCapturedForDrag: Set<UUID> = []
    @State private var transformingElementIDs: Set<UUID> = []
    @State private var elementTransformStartElements: [UUID: CanvasElement] = [:]
    @State private var elementTransformPreview: [UUID: CanvasElement] = [:]
    @State private var activeGuides: CanvasSnapGuides?
    @State private var activeCanvasInteractionCount = 0
    @State private var isViewportZooming = false
    @State private var viewportSize: CGSize = .zero

    private let gridSpacing: CGFloat = 36
    private let toolbarColorOptions = ["#2E2824", "#B77255", "#C4563F", "#7AA08C", "#A9C0D2", "#D99A8C"]

    private var displaySize: CGSize {
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return document.canvasSize.cgSize
        }
        return viewportSize
    }

    private var viewportTransform: CanvasViewportTransform {
        CanvasViewportTransform(documentSize: document.canvasSize.cgSize, viewportSize: displaySize)
    }

    private var effectiveScale: CGFloat {
        viewportTransform.uniformScale
    }

    private var isCanvasInteracting: Bool {
        activeCanvasInteractionCount > 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                canvasBody
                    .frame(width: displaySize.width, height: displaySize.height)
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()

                fixedSelectionToolbar
            }
            .onAppear {
                updateViewportSize(proxy.size)
            }
            .onChange(of: proxy.size) { size in
                updateViewportSize(size)
            }
        }
        .onChange(of: document.pageID) { _ in
            elementTransformPreview = [:]
            elementTransformStartElements = [:]
            selectionTransformPreview = [:]
            selectionTransformStartElements = [:]
            selectionTransformStartRect = nil
            selectionDragStartRect = nil
            selectionDragTranslation = nil
            transformingElementIDs = []
            activeCanvasInteractionCount = 0
            activeGuides = nil
        }
        .onChange(of: selectedElementIDs) { _ in
            elementTransformPreview = elementTransformPreview.filter { selectedElementIDs.contains($0.key) }
            elementTransformStartElements = elementTransformStartElements.filter { selectedElementIDs.contains($0.key) }
            selectionTransformPreview = selectionTransformPreview.filter { selectedElementIDs.contains($0.key) }
            selectionTransformStartElements = selectionTransformStartElements.filter { selectedElementIDs.contains($0.key) }
            if selectedElementIDs.count < 2 {
                selectionTransformStartRect = nil
                selectionDragStartRect = nil
                selectionDragTranslation = nil
            }
            transformingElementIDs = transformingElementIDs.intersection(selectedElementIDs)
            activeCanvasInteractionCount = 0
            activeGuides = nil
        }
    }

    private func updateViewportSize(_ size: CGSize) {
        let normalized = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        guard viewportSize != normalized else { return }
        DispatchQueue.main.async {
            viewportSize = normalized
            isViewportZooming = false
        }
    }

    private var canvasBody: some View {
        ZStack {
            CanvasSurface(background: document.background)
                .frame(width: displaySize.width, height: displaySize.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    onCommit()
                    onSelect(nil, false)
                }

            if let activeGuides {
                CanvasSnapGuideOverlay(guides: activeGuides, transform: viewportTransform)
                    .allowsHitTesting(false)
            }

            ForEach(document.elements.filter { !$0.hidden }.sorted { $0.zIndex < $1.zIndex }) { element in
                let renderedElement = elementTransformPreview[element.id] ?? element
                CanvasElementView(
                    element: viewportTransform.displayElement(renderedElement),
                    selected: selectedElementIDs.contains(element.id),
                    performanceMode: isCanvasInteracting || isViewportZooming,
                    imageURL: imageURL
                )
                    .rotationEffect(.degrees(renderedElement.rotation))
                    .position(viewportTransform.displayPoint(CGPoint(x: renderedElement.x, y: renderedElement.y)))
                    .opacity(renderedElement.opacity)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .named("canvasSpace"))
                            .onChanged { value in
                                guard !element.locked,
                                      !isViewportZooming,
                                      !transformingElementIDs.contains(element.id) else { return }
                                let canvasTranslation = CGSize(
                                    width: value.location.x - value.startLocation.x,
                                    height: value.location.y - value.startLocation.y
                                )
                                if !selectedElementIDs.contains(element.id) || selectedElementIDs.count != 1 {
                                    onSelect(element.id, false)
                                }
                                captureTransformUndo(for: element.id)
                                if elementTransformPreview[element.id] == nil {
                                    beginCanvasInteraction()
                                }
                                let start = dragStartFrames[element.id] ?? CGPoint(x: element.x, y: element.y)
                                dragStartFrames[element.id] = start
                                let proposed = CGPoint(
                                    x: start.x + canvasTranslation.width / viewportTransform.xScale,
                                    y: start.y + canvasTranslation.height / viewportTransform.yScale
                                )
                                let snapped = snappedPoint(proposed)
                                activeGuides = snapped.guides
                                var preview = element
                                preview.x = snapped.point.x
                                preview.y = snapped.point.y
                                elementTransformPreview[element.id] = preview
                            }
                            .onEnded { _ in
                                guard !isViewportZooming else {
                                    dragStartFrames[element.id] = nil
                                    selectionDragStartFrames = [:]
                                    selectionDragStartRect = nil
                                    selectionDragTranslation = nil
                                    elementTransformPreview[element.id] = nil
                                    selectionTransformPreview = [:]
                                    activeGuides = nil
                                    endCanvasInteraction()
                                    return
                                }
                                if let preview = elementTransformPreview[element.id] {
                                    onMove(element.id, CGPoint(x: preview.x, y: preview.y))
                                } else if let translation = selectionDragTranslation {
                                    onMoveSelection(selectionDragStartFrames, translation)
                                }
                                dragStartFrames[element.id] = nil
                                selectionDragStartFrames = [:]
                                selectionDragStartRect = nil
                                selectionDragTranslation = nil
                                elementTransformPreview[element.id] = nil
                                selectionTransformPreview = [:]
                                undoCapturedForDrag.remove(element.id)
                                undoCapturedForDrag.remove(selectionUndoKey)
                                activeGuides = nil
                                endCanvasInteraction()
                                onCommit()
                            }
                    )
                .simultaneousGesture(elementTransformGesture(for: element))
                    .onTapGesture {
                        onSelect(element.id, true)
                    }
            }

            if let connector = selectedFreeConnectorElement {
                ConnectorEndpointHandles(
                    start: viewportTransform.displayPoint(connector.freeConnectorEndpoints.start),
                    end: viewportTransform.displayPoint(connector.freeConnectorEndpoints.end),
                    onDragStart: {
                        beginCanvasInteraction()
                        onSelect(connector.id, false)
                        captureTransformUndo(for: connector.id)
                        transformingElementIDs.insert(connector.id)
                        dragStartFrames[connector.id] = nil
                    },
                    onDragChanged: { endpoint, location in
                        elementTransformPreview[connector.id] = previewFreeConnector(
                            connector,
                            moving: endpoint,
                            to: viewportTransform.documentPoint(location)
                        )
                    },
                    onDragEnded: { endpoint in
                        if let preview = elementTransformPreview[connector.id] {
                            let endpoints = preview.freeConnectorEndpoints
                            onMoveConnectorEndpoint(connector.id, endpoint, endpoint == .start ? endpoints.start : endpoints.end)
                        }
                        elementTransformPreview[connector.id] = nil
                        transformingElementIDs.remove(connector.id)
                        undoCapturedForDrag.remove(connector.id)
                        endCanvasInteraction()
                        onCommit()
                    }
                )
                .frame(width: displaySize.width, height: displaySize.height)
            }

            if selectedElementIDs.count > 1, let selectionRect {
                MultiSelectionBox(
                    rect: viewportTransform.displayRect(selectionRect),
                    onMoveStart: {
                        beginCanvasInteraction()
                        captureSelectionUndo()
                        selectionDragStartFrames = selectedElements.reduce(into: [:]) { result, element in
                            result[element.id] = CGPoint(x: element.x, y: element.y)
                        }
                        selectionDragStartRect = selectionRect
                    },
                    onMoveChanged: { translation in
                        guard !selectionDragStartFrames.isEmpty else { return }
                        let documentTranslation = CGSize(width: translation.width / viewportTransform.xScale, height: translation.height / viewportTransform.yScale)
                        let snappedTranslation = snappedSelectionTranslation(documentTranslation)
                        activeGuides = snappedTranslation.guides
                        selectionDragTranslation = snappedTranslation.translation
                        selectionTransformPreview = previewMovedSelectionElements(from: selectionDragStartFrames, translation: snappedTranslation.translation)
                    },
                    onMoveEnded: {
                        if let translation = selectionDragTranslation {
                            onMoveSelection(selectionDragStartFrames, translation)
                        }
                        selectionDragStartFrames = [:]
                        selectionDragStartRect = nil
                        selectionDragTranslation = nil
                        selectionTransformPreview = [:]
                        undoCapturedForDrag.remove(selectionUndoKey)
                        activeGuides = nil
                        endCanvasInteraction()
                        onCommit()
                    },
                    onTransformStart: {
                        beginCanvasInteraction()
                        captureSelectionUndo()
                        selectionTransformStartElements = selectedElements.reduce(into: [:]) { result, element in
                            result[element.id] = element
                        }
                        selectionTransformStartRect = selectionRect
                    },
                    onResizeChanged: { factor in
                        guard let startRect = selectionTransformStartRect,
                              !selectionTransformStartElements.isEmpty else { return }
                        selectionTransformPreview = previewSelectionElements(
                            from: selectionTransformStartElements,
                            selectionRect: startRect,
                            scale: factor,
                            rotation: 0
                        )
                    },
                    onRotateChanged: { degrees in
                        guard let startRect = selectionTransformStartRect,
                              !selectionTransformStartElements.isEmpty else { return }
                        selectionTransformPreview = previewSelectionElements(
                            from: selectionTransformStartElements,
                            selectionRect: startRect,
                            scale: 1,
                            rotation: degrees
                        )
                    },
                    onTransformEnded: {
                        if let startRect = selectionTransformStartRect,
                           !selectionTransformStartElements.isEmpty,
                           !selectionTransformPreview.isEmpty {
                            let scale = selectionPreviewScale(from: selectionTransformStartElements, preview: selectionTransformPreview)
                            let rotation = selectionPreviewRotation(from: selectionTransformStartElements, preview: selectionTransformPreview)
                            onTransformSelection(selectionTransformStartElements, startRect, scale, rotation)
                        }
                        selectionTransformStartElements = [:]
                        selectionTransformStartRect = nil
                        selectionTransformPreview = [:]
                        undoCapturedForDrag.remove(selectionUndoKey)
                        endCanvasInteraction()
                        onCommit()
                    }
                )
            }

            activeCanvasToolOverlay
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .coordinateSpace(name: "canvasSpace")
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var activeCanvasToolOverlay: some View {
        switch activeCanvasTool {
        case .brush:
            BrushCaptureOverlay(
                transform: viewportTransform,
                colorHex: activeBrushColorHex,
                brushWidth: activeBrushWidth,
                opacity: activeBrushOpacity,
                onEnded: onBrushFinished
            )
            .frame(width: displaySize.width, height: displaySize.height)
        case .arrow:
            ArrowCaptureOverlay(
                transform: viewportTransform,
                colorHex: activeBrushColorHex,
                width: activeBrushWidth,
                onEnded: onArrowFinished
            )
            .frame(width: displaySize.width, height: displaySize.height)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var fixedSelectionToolbar: some View {
        if !selectedElementIDs.isEmpty,
           activeCanvasTool == nil {
            FloatingSelectionToolbar(
                selectedCount: selectedElementIDs.count,
                selectedElement: selectedElements.count == 1 ? selectedElements[0] : nil,
                colorOptions: toolbarColorOptions,
                onColor: onColorSelected,
                onWidthDown: {
                    guard let element = selectedElements.first, element.supportsLineWidth else { return }
                    onLineWidthSelected(element.brushWidth - 6)
                },
                onWidthUp: {
                    guard let element = selectedElements.first, element.supportsLineWidth else { return }
                    onLineWidthSelected(element.brushWidth + 6)
                },
                onSetWidth: onLineWidthSelected,
                onTapeLengthDown: {
                    guard let element = selectedElements.first, element.kind == .tape else { return }
                    onTapeLengthSelected(element.width - 40)
                },
                onTapeLengthUp: {
                    guard let element = selectedElements.first, element.kind == .tape else { return }
                    onTapeLengthSelected(element.width + 40)
                },
                onSetTapeLength: onTapeLengthSelected,
                onSetOpacity: onOpacitySelected,
                onSetCornerRadius: onCornerRadiusSelected,
                onToggleStroke: onToggleStrokeSelected,
                onToggleShadow: onToggleShadowSelected,
                onBringForward: onBringForwardSelection,
                onSendBackward: onSendBackwardSelection,
                onDuplicate: onDuplicateSelection,
                onToggleHidden: onToggleHiddenSelection,
                onToggleLocked: onToggleLockedSelection,
                onEdit: onEditSelected,
                onDelete: onDeleteSelection
            )
            .padding(.top, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .zIndex(50)
        }
    }

    private var selectedElements: [CanvasElement] {
        document.elements.compactMap { element in
            guard selectedElementIDs.contains(element.id), !element.hidden else { return nil }
            return selectionTransformPreview[element.id] ?? elementTransformPreview[element.id] ?? element
        }
    }

    private var elementPanExclusionRects: [CGRect] {
        document.elements.compactMap { element in
            guard !element.hidden, !element.locked else { return nil }
            let renderedElement = elementTransformPreview[element.id] ?? element
            return renderedElement.bounds
                .scaled(by: effectiveScale)
                .rotatedBoundingBox(degrees: renderedElement.rotation)
        }
    }

    private var selectedFreeConnectorElement: CanvasElement? {
        guard selectedElementIDs.count == 1,
              let selectedElementID else { return nil }
        if let preview = elementTransformPreview[selectedElementID],
           !preview.hidden,
           preview.isFreeConnector {
            return preview
        }
        return document.elements.first { $0.id == selectedElementID && !$0.hidden && $0.isFreeConnector }
    }

    private var selectionRect: CGRect? {
        guard let first = selectedElements.first else { return nil }
        return selectedElements.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
    }

    private var selectionUndoKey: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }

    private func captureTransformUndo(for elementID: UUID) {
        guard !undoCapturedForDrag.contains(elementID) else { return }
        onMoveStart()
        undoCapturedForDrag.insert(elementID)
    }

    private func captureSelectionUndo() {
        guard !undoCapturedForDrag.contains(selectionUndoKey) else { return }
        onMoveStart()
        undoCapturedForDrag.insert(selectionUndoKey)
    }

    private func beginCanvasInteraction() {
        activeCanvasInteractionCount += 1
    }

    private func endCanvasInteraction() {
        activeCanvasInteractionCount = max(0, activeCanvasInteractionCount - 1)
    }

    private func previewMovedSelectionElements(from startPositions: [UUID: CGPoint], translation: CGSize) -> [UUID: CanvasElement] {
        document.elements.reduce(into: [:]) { result, element in
            guard selectedElementIDs.contains(element.id),
                  let start = startPositions[element.id],
                  !element.locked else { return }
            var preview = element
            preview.x = clampedDocumentX(start.x + translation.width)
            preview.y = clampedDocumentY(start.y + translation.height)
            result[element.id] = preview
        }
    }

    private func elementTransformGesture(for element: CanvasElement) -> some Gesture {
        MagnificationGesture()
            .simultaneously(with: RotationGesture())
            .onChanged { value in
                guard !element.locked,
                      elementGestureTransformEnabled,
                      selectedElementIDs == [element.id] else { return }
                transformingElementIDs.insert(element.id)
                dragStartFrames[element.id] = nil
                captureTransformUndo(for: element.id)
                if elementTransformStartElements[element.id] == nil {
                    beginCanvasInteraction()
                    elementTransformStartElements[element.id] = elementTransformPreview[element.id] ?? element
                }

                let magnification = value.first ?? 1
                let rotation = value.second ?? .zero
                guard let startElement = elementTransformStartElements[element.id] else { return }
                elementTransformPreview[element.id] = previewElement(from: startElement, scale: magnification, rotation: rotation.degrees)
            }
            .onEnded { _ in
                if let startElement = elementTransformStartElements[element.id],
                   let preview = elementTransformPreview[element.id] {
                    let widthScale = startElement.width > 0 ? preview.width / startElement.width : 1
                    onTransformFromStart(element.id, startElement, widthScale, preview.rotation - startElement.rotation)
                }
                dragStartFrames[element.id] = nil
                elementTransformStartElements[element.id] = nil
                elementTransformPreview[element.id] = nil
                transformingElementIDs.remove(element.id)
                undoCapturedForDrag.remove(element.id)
                endCanvasInteraction()
                onCommit()
            }
    }

    private func previewElement(from start: CanvasElement, scale: CGFloat, rotation: Double) -> CanvasElement {
        let clampedScale = min(max(scale, 0.18), 4)
        var element = start
        element.width = min(max(start.width * clampedScale, 42), 12000)
        element.height = min(max(start.height * clampedScale, 42), 12000)
        element.fontSize = min(max(start.fontSize * clampedScale, 24), 220)
        element.brushWidth = min(max(start.brushWidth * clampedScale, 4), 180)
        element.brushPoints = start.brushPoints.map { point in
            CodablePoint(x: point.x * clampedScale, y: point.y * clampedScale)
        }
        element.rotation = start.rotation + rotation
        return element
    }

    private func previewFreeConnector(_ element: CanvasElement, moving endpoint: ConnectorEndpoint, to point: CGPoint) -> CanvasElement {
        let clampedPoint = CGPoint(
            x: min(max(point.x, 20), max(20, document.canvasSize.width - 20)),
            y: min(max(point.y, 20), max(20, document.canvasSize.height - 20))
        )
        let current = element.freeConnectorEndpoints
        let start = endpoint == .start ? clampedPoint : current.start
        let end = endpoint == .end ? clampedPoint : current.end
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(hypot(dx, dy), 80)
        var preview = element
        preview.connectorStartPoint = CodablePoint(x: start.x, y: start.y)
        preview.connectorEndPoint = CodablePoint(x: end.x, y: end.y)
        preview.x = (start.x + end.x) / 2
        preview.y = (start.y + end.y) / 2
        preview.width = min(max(distance, 120), 1400)
        preview.height = min(max(preview.brushWidth * 5.4, 90), 280)
        preview.rotation = Double(atan2(dy, dx) * 180 / .pi)
        return preview
    }

    private func previewSelectionElements(from startElements: [UUID: CanvasElement], selectionRect: CGRect, scale: CGFloat, rotation: Double) -> [UUID: CanvasElement] {
        guard !startElements.isEmpty else { return [:] }
        let center = CGPoint(x: selectionRect.midX, y: selectionRect.midY)
        let clampedScale = min(max(scale, 0.18), 4)
        let radians = rotation * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)

        return startElements.reduce(into: [:]) { result, pair in
            let (id, start) = pair
            guard !start.locked else { return }

            let dx = (start.x - center.x) * clampedScale
            let dy = (start.y - center.y) * clampedScale
            let rotatedX = dx * cosine - dy * sine
            let rotatedY = dx * sine + dy * cosine

            var element = previewElement(from: start, scale: clampedScale, rotation: rotation)
            element.x = center.x + rotatedX
            element.y = center.y + rotatedY
            result[id] = element
        }
    }

    private func selectionPreviewScale(from startElements: [UUID: CanvasElement], preview: [UUID: CanvasElement]) -> CGFloat {
        for (id, start) in startElements {
            guard let next = preview[id],
                  start.width > 0,
                  abs(next.width - start.width) > 0.01 else { continue }
            return min(max(next.width / start.width, 0.18), 4)
        }
        return 1
    }

    private func selectionPreviewRotation(from startElements: [UUID: CanvasElement], preview: [UUID: CanvasElement]) -> Double {
        for (id, start) in startElements {
            guard let next = preview[id],
                  abs(next.rotation - start.rotation) > 0.01 else { continue }
            return next.rotation - start.rotation
        }
        return 0
    }

    private func snappedPoint(_ point: CGPoint) -> (point: CGPoint, guides: CanvasSnapGuides?) {
        guard snapToGrid else { return (point, nil) }
        let snappedX = (point.x / gridSpacing).rounded() * gridSpacing
        let snappedY = (point.y / gridSpacing).rounded() * gridSpacing
        return (
            CGPoint(x: snappedX, y: snappedY),
            CanvasSnapGuides(x: snappedX, y: snappedY)
        )
    }

    private func snappedSelectionTranslation(_ translation: CGSize) -> (translation: CGSize, guides: CanvasSnapGuides?) {
        guard snapToGrid, let rect = selectionDragStartRect ?? selectionRect else { return (translation, nil) }
        let targetCenter = CGPoint(x: rect.midX + translation.width, y: rect.midY + translation.height)
        let snapped = snappedPoint(targetCenter)
        let snappedTranslation = CGSize(width: snapped.point.x - rect.midX, height: snapped.point.y - rect.midY)
        return (snappedTranslation, snapped.guides)
    }

    private func clampedDocumentX(_ value: CGFloat) -> CGFloat {
        min(max(value, 40), max(40, document.canvasSize.width - 40))
    }

    private func clampedDocumentY(_ value: CGFloat) -> CGFloat {
        min(max(value, 40), max(40, document.canvasSize.height - 40))
    }

}

private struct CanvasSurface: View {
    let background: CanvasBackground
    var performanceMode = false

    var body: some View {
        Canvas(opaque: true, colorMode: .linear, rendersAsynchronously: false) { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let surface = Path(roundedRect: rect, cornerRadius: 12)
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color(hex: background.colorA), Color(hex: background.colorB)]),
                startPoint: rect.origin,
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            context.fill(surface, with: gradient)
            context.clip(to: surface)

            if !performanceMode {
                var grid = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    x += 36
                }

                var y: CGFloat = 0
                while y <= size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += 36
                }

                context.stroke(
                    grid,
                    with: .color(Color.editorGrid.opacity(0.72)),
                    style: StrokeStyle(lineWidth: 1.15, dash: [6, 6])
                )
            }
            context.stroke(surface, with: .color(Color.clay.opacity(0.32)), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CanvasSnapGuides {
    var x: CGFloat?
    var y: CGFloat?
}

private struct CanvasSnapGuideOverlay: View {
    let guides: CanvasSnapGuides
    let transform: CanvasViewportTransform

    var body: some View {
        ZStack {
            if let x = guides.x {
                Rectangle()
                    .fill(Color.clay.opacity(0.45))
                    .frame(width: 1.5)
                    .position(x: transform.displayPoint(CGPoint(x: x, y: 0)).x, y: transform.viewportSize.height / 2)
            }

            if let y = guides.y {
                Rectangle()
                    .fill(Color.clay.opacity(0.45))
                    .frame(height: 1.5)
                    .position(x: transform.viewportSize.width / 2, y: transform.displayPoint(CGPoint(x: 0, y: y)).y)
            }
        }
        .frame(width: transform.viewportSize.width, height: transform.viewportSize.height)
    }
}

private struct CanvasDocumentRenderer: View {
    @ObservedObject var repository: NotebookRepository
    let document: CanvasDocument
    let scale: CGFloat
    var selectedElementIDs: Set<UUID> = []
    var elementLimit: Int?

    private var renderSize: CGSize {
        CGSize(width: document.canvasSize.width * scale, height: document.canvasSize.height * scale)
    }

    private var renderTransform: CanvasViewportTransform {
        CanvasViewportTransform(documentSize: document.canvasSize.cgSize, viewportSize: renderSize)
    }

    private var visibleElements: [CanvasElement] {
        let elements = document.elements.filter { !$0.hidden }.sorted { $0.zIndex < $1.zIndex }
        if let elementLimit {
            return Array(elements.prefix(elementLimit))
        }
        return elements
    }

    var body: some View {
        ZStack {
            CanvasSurface(background: document.background)
                .frame(width: renderSize.width, height: renderSize.height)

            ForEach(visibleElements) { element in
                CanvasElementView(
                    element: renderTransform.displayElement(element),
                    selected: selectedElementIDs.contains(element.id),
                    imageURL: { repository.imageURL(for: $0) }
                )
                .rotationEffect(.degrees(element.rotation))
                .position(renderTransform.displayPoint(CGPoint(x: element.x, y: element.y)))
                .opacity(element.opacity)
            }
        }
        .frame(width: renderSize.width, height: renderSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CanvasElementView: View {
    let element: CanvasElement
    let selected: Bool
    var performanceMode = false
    let imageURL: (String?) -> URL?

    var body: some View {
        ZStack {
            switch element.kind {
            case .video:
                MediaCardElement(element: element, mediaKind: .video, fileURL: imageURL(element.localPath))
                    .frame(width: element.width, height: element.height)
            case .audio:
                MediaCardElement(element: element, mediaKind: .audio, fileURL: imageURL(element.localPath))
                    .frame(width: element.width, height: element.height)
            case .text:
                Text(element.text ?? "")
                    .font(FontResolver.swiftUIFont(name: element.fontName, size: element.fontSize, bold: element.bold, italic: element.italic))
                    .foregroundStyle(Color(hex: element.colorHex))
                    .multilineTextAlignment(element.textAlignmentValue)
                    .frame(width: element.width, height: element.height)
                    .minimumScaleFactor(0.3)
            case .wordArt:
                Text(element.text ?? "")
                    .font(FontResolver.swiftUIFont(name: element.fontName, size: element.fontSize, bold: true, italic: element.italic))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: element.colorHex), Color.sand, Color.paper],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(element.textAlignmentValue)
                    .frame(width: element.width, height: element.height)
                    .minimumScaleFactor(0.3)
                    .shadow(color: Color.clay.opacity(0.28), radius: 0, x: 5, y: 5)
            case .sticker:
                Text(element.symbol ?? "sparkle")
                    .font(.system(size: min(element.width, element.height) * 0.72, weight: .semibold))
                    .foregroundStyle(Color(hex: element.colorHex))
                    .frame(width: element.width, height: element.height)
                    .background(Color(hex: element.colorHex).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            case .image:
                if let url = imageURL(element.localPath),
                   let image = CanvasImageCache.shared.image(at: url, maxPixelSize: imageMaxPixelSize) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: element.width, height: element.height)
                        .clipShape(RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                        .frame(width: element.width, height: element.height)
                        .background(Color.paper)
                        .clipShape(RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous))
                }
            case .tape:
                TapeElement(color: Color(hex: element.colorHex), imageURL: imageURL(element.localPath))
                    .frame(width: element.width, height: element.height)
            case .brush:
                BrushElement(element: element)
                    .frame(width: element.width, height: element.height)
            case .shape:
                CanvasShapeElement(element: element)
                    .frame(width: element.width, height: element.height)
            case .connector:
                ConnectorElement(element: element)
                    .frame(width: element.width, height: element.height)
            case .link:
                LinkCardElement(element: element)
                    .frame(width: element.width, height: element.height)
            case .file:
                FileCardElement(element: element)
                    .frame(width: element.width, height: element.height)
            }
        }
        .blur(radius: performanceMode ? 0 : element.blur)
        .shadow(color: !performanceMode && element.shadow ? Color.black.opacity(0.18) : .clear, radius: 18, x: 0, y: 10)
        .overlay {
            if element.stroke {
                RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                    .stroke(Color(hex: element.colorHex).opacity(0.72), lineWidth: 7)
                    .frame(width: element.width, height: element.height)
            }
        }
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.clay, style: StrokeStyle(lineWidth: 4, dash: [18, 10]))
                    .frame(width: element.width + 18, height: element.height + 18)
            }
        }
        .overlay(alignment: .topTrailing) {
            if element.note?.isEmpty == false {
                Image(systemName: "note.text")
                    .font(.system(size: max(14, min(element.width, element.height) * 0.11), weight: .bold))
                    .foregroundStyle(Color.paper)
                    .frame(width: max(28, min(element.width, element.height) * 0.2), height: max(28, min(element.width, element.height) * 0.2))
                    .background(Color.clay)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.paper, lineWidth: max(2, min(element.width, element.height) * 0.018)))
                    .offset(x: max(8, min(element.width, element.height) * 0.06), y: -max(8, min(element.width, element.height) * 0.06))
            }
        }
    }

    private var imageMaxPixelSize: CGFloat {
        let longestSide = max(element.width, element.height)
        let requested = max(longestSide * 3, 320)
        return performanceMode ? min(requested, 900) : min(requested, 1800)
    }
}

private extension CanvasElement {
    var textAlignmentValue: TextAlignment {
        switch textAlignment {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    var isFreeConnector: Bool {
        kind == .connector && connectorStartID == nil && connectorEndID == nil
    }

    var freeConnectorEndpoints: (start: CGPoint, end: CGPoint) {
        if let startPoint = connectorStartPoint, let endPoint = connectorEndPoint {
            return (
                CGPoint(x: startPoint.x, y: startPoint.y),
                CGPoint(x: endPoint.x, y: endPoint.y)
            )
        }
        let radians = rotation * .pi / 180
        let halfLength = max(width, 120) / 2
        let dx = cos(radians) * halfLength
        let dy = sin(radians) * halfLength
        return (
            CGPoint(x: x - dx, y: y - dy),
            CGPoint(x: x + dx, y: y + dy)
        )
    }

    func displayScaled(by scale: CGFloat) -> CanvasElement {
        var copy = self
        copy.x *= scale
        copy.y *= scale
        copy.width *= scale
        copy.height *= scale
        copy.fontSize *= scale
        copy.cornerRadius *= scale
        copy.blur *= scale
        copy.brushWidth *= scale
        copy.brushPoints = brushPoints.map { point in
            CodablePoint(x: point.x * scale, y: point.y * scale)
        }
        return copy
    }
}

private struct CanvasViewportTransform {
    let documentSize: CGSize
    let viewportSize: CGSize

    var xScale: CGFloat {
        viewportSize.width / max(documentSize.width, 1)
    }

    var yScale: CGFloat {
        viewportSize.height / max(documentSize.height, 1)
    }

    var uniformScale: CGFloat {
        min(xScale, yScale)
    }

    func displayPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * xScale, y: point.y * yScale)
    }

    func documentPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / max(xScale, 0.0001), y: point.y / max(yScale, 0.0001))
    }

    func displayRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * xScale, y: rect.minY * yScale, width: rect.width * xScale, height: rect.height * yScale)
    }

    func displayElement(_ element: CanvasElement) -> CanvasElement {
        var copy = element
        copy.width *= xScale
        copy.height *= yScale
        copy.fontSize *= uniformScale
        copy.cornerRadius *= uniformScale
        copy.blur *= uniformScale
        copy.brushWidth *= uniformScale
        copy.brushPoints = element.brushPoints.map { point in
            CodablePoint(x: point.x * xScale, y: point.y * yScale)
        }
        return copy
    }
}

private final class CanvasImageCache {
    static let shared = CanvasImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func image(at url: URL) -> UIImage? {
        image(at: url, maxPixelSize: nil)
    }

    func image(at url: URL, maxPixelSize: CGFloat?) -> UIImage? {
        let normalizedMaxPixelSize = maxPixelSize.map { Int(max(1, $0).rounded(.up)) }
        let keyValue = normalizedMaxPixelSize.map { "\(url.path)#\($0)" } ?? url.path
        let key = keyValue as NSString
        lock.lock()
        if let image = cache.object(forKey: key) {
            lock.unlock()
            return image
        }
        lock.unlock()

        let image: UIImage?
        if let normalizedMaxPixelSize {
            image = downsampledImage(at: url, maxPixelSize: normalizedMaxPixelSize)
        } else {
            image = UIImage(contentsOfFile: url.path)
        }
        guard let image else { return nil }
        let cost = max(1, Int(image.size.width * image.size.height * max(image.scale * image.scale, 1)))
        lock.lock()
        cache.setObject(image, forKey: key, cost: cost)
        lock.unlock()
        return image
    }

    func preheat(urls: [URL], maxPixelSize: CGFloat) {
        let normalizedMaxPixelSize = Int(max(1, maxPixelSize).rounded(.up))
        for url in urls {
            let key = "\(url.path)#\(normalizedMaxPixelSize)" as NSString
            lock.lock()
            let cached = cache.object(forKey: key) != nil
            lock.unlock()
            guard !cached,
                  let image = downsampledImage(at: url, maxPixelSize: normalizedMaxPixelSize) else { continue }
            let cost = max(1, Int(image.size.width * image.size.height * max(image.scale * image.scale, 1)))
            lock.lock()
            cache.setObject(image, forKey: key, cost: cost)
            lock.unlock()
        }
    }

    private func downsampledImage(at url: URL, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private enum TextRenderService {
    static func sampleImage(text: String, style: TextStyleParameters, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let previewText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sample text" : text
        let width = min(max(style.width, 360), 920)
        let height = max(style.fontSize * 2.6, 150)
        return render(text: previewText, style: style, size: CGSize(width: width, height: height), scale: scale)
    }

    static func render(text: String, style: TextStyleParameters, size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = nsAlignment(for: style.alignment)
            paragraph.lineBreakMode = .byWordWrapping

            let font = uiFont(name: style.fontName, size: style.fontSize, bold: style.bold, italic: style.italic)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(hex: style.colorHex),
                .paragraphStyle: paragraph
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let inset = max(18, style.fontSize * 0.18)
            let rect = CGRect(x: inset, y: inset, width: max(1, size.width - inset * 2), height: max(1, size.height - inset * 2))
            attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }

    private static func uiFont(name: String, size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        let resolved = FontResolver.resolvedName(for: name)
        let candidates = [resolved, resolved.replacingOccurrences(of: " ", with: ""), name, name.replacingOccurrences(of: " ", with: "")]
        let base = candidates.compactMap { UIFont(name: $0, size: size) }.first ?? UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        guard italic || bold else { return base }

        var traits = base.fontDescriptor.symbolicTraits
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func nsAlignment(for alignment: String) -> NSTextAlignment {
        switch alignment {
        case "leading": return .left
        case "trailing": return .right
        default: return .center
        }
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension CGPoint {
    func scaledForCanvas(by scale: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }
}

private extension CanvasElementKind {
    var isPreviewableObject: Bool {
        switch self {
        case .link, .file, .video, .audio:
            return true
        default:
            return false
        }
    }

    var isShareableAttachment: Bool {
        switch self {
        case .file, .video, .audio:
            return true
        default:
            return false
        }
    }
}

private enum FontResolver {
    private static var registeredGoogleFonts: [String: String] = [:]

    static func registerGoogleFont(family: String, resolvedName: String) {
        registeredGoogleFonts[family] = resolvedName
    }

    static func resolvedName(for name: String) -> String {
        registeredGoogleFonts[name] ?? name
    }

    static func swiftUIFont(name: String, size: CGFloat, bold: Bool, italic: Bool) -> Font {
        let name = resolvedName(for: name)
        let resolved: Font
        if UIFont(name: name, size: size) != nil {
            resolved = .custom(name, size: size).weight(bold ? .bold : .regular)
        } else {
            let compactName = name.replacingOccurrences(of: " ", with: "")
            if UIFont(name: compactName, size: size) != nil {
                resolved = .custom(compactName, size: size).weight(bold ? .bold : .regular)
            } else {
                resolved = .system(size: size, weight: bold ? .bold : .regular)
            }
        }

        return italic ? resolved.italic() : resolved
    }
}

@MainActor
private final class FontLibrary: ObservableObject {
    @Published private var resolvedFonts: [String: String] = [:]
    private let googleFamilies = ["Roboto", "Open Sans", "Montserrat", "Merriweather", "Playfair Display", "Dancing Script", "Pacifico"]
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GoogleFonts", isDirectory: true)
    }

    func bootstrap() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        for family in googleFamilies {
            let fileURL = cachedFontURL(for: family)
            guard fileManager.fileExists(atPath: fileURL.path),
                  let name = registerFont(at: fileURL, family: family) else { continue }
            resolvedFonts[family] = name
            FontResolver.registerGoogleFont(family: family, resolvedName: name)
        }
    }

    func isAvailable(_ family: String) -> Bool {
        resolvedFonts[family] != nil
    }

    func resolvedName(for family: String) -> String {
        resolvedFonts[family] ?? family
    }

    func loadGoogleFont(named family: String) async throws -> String {
        if let resolved = resolvedFonts[family] {
            return resolved
        }

        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let fileURL = cachedFontURL(for: family)
        if !fileManager.fileExists(atPath: fileURL.path) {
            let fontURL = try await fetchFontFileURL(for: family)
            let (data, _) = try await URLSession.shared.data(from: fontURL)
            try data.write(to: fileURL, options: .atomic)
        }

        guard let resolved = registerFont(at: fileURL, family: family) else {
            throw URLError(.cannotDecodeContentData)
        }

        resolvedFonts[family] = resolved
        FontResolver.registerGoogleFont(family: family, resolvedName: resolved)
        return resolved
    }

    private func fetchFontFileURL(for family: String) async throws -> URL {
        var components = URLComponents(string: "https://fonts.googleapis.com/css2")!
        components.queryItems = [
            URLQueryItem(name: "family", value: family.replacingOccurrences(of: " ", with: "+")),
            URLQueryItem(name: "display", value: "swap")
        ]
        let cssURL = components.url!
        var request = URLRequest(url: cssURL)
        request.setValue("Mozilla/5.0 AppleWebKit/605.1.15 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let css = String(data: data, encoding: .utf8),
              let match = css.range(of: #"https://[^)]+"#, options: .regularExpression) else {
            throw URLError(.badServerResponse)
        }
        return URL(string: String(css[match]))!
    }

    private func cachedFontURL(for family: String) -> URL {
        let safeName = family.replacingOccurrences(of: " ", with: "-")
        return cacheDirectory.appendingPathComponent("\(safeName).ttf")
    }

    private func registerFont(at url: URL, family: String) -> String? {
        guard let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider) else { return nil }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterGraphicsFont(font, &error)
        let resolvedName = font.postScriptName as String? ?? family
        FontResolver.registerGoogleFont(family: family, resolvedName: resolvedName)
        return resolvedName
    }
}

private struct BrushCaptureOverlay: View {
    let transform: CanvasViewportTransform
    let colorHex: String
    let brushWidth: CGFloat
    let opacity: Double
    let onEnded: ([CGPoint]) -> Void
    @State private var currentPoints: [CGPoint] = []

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .named("canvasSpace"))
                        .onChanged { value in
                            let point = transform.documentPoint(value.location)
                            let minimumStep = 4 / max(transform.uniformScale, 0.2)
                            guard let last = currentPoints.last else {
                                currentPoints.append(point)
                                return
                            }
                            guard hypot(point.x - last.x, point.y - last.y) >= minimumStep else { return }
                            currentPoints.append(point)
                        }
                        .onEnded { _ in
                            if currentPoints.count > 1 {
                                onEnded(currentPoints)
                            }
                            currentPoints = []
                        }
                )

            BrushStrokePreviewLine(
                points: currentPoints.map { transform.displayPoint($0) },
                color: Color(hex: colorHex).opacity(opacity),
                width: max(3, brushWidth * transform.uniformScale)
            )
        }
    }
}

private struct ArrowCaptureOverlay: View {
    let transform: CanvasViewportTransform
    let colorHex: String
    let width: CGFloat
    let onEnded: (CGPoint, CGPoint) -> Void
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .named("canvasSpace"))
                        .onChanged { value in
                            if startPoint == nil {
                                startPoint = value.startLocation
                            }
                            currentPoint = value.location
                        }
                        .onEnded { value in
                            let start = startPoint ?? value.startLocation
                            let end = value.location
                            startPoint = nil
                            currentPoint = nil
                            guard hypot(end.x - start.x, end.y - start.y) >= 18 else { return }
                            onEnded(
                                transform.documentPoint(start),
                                transform.documentPoint(end)
                            )
                        }
                )

            if let startPoint, let currentPoint {
                Canvas { context, _ in
                    let lineWidth = max(4, width * transform.uniformScale)
                    let end = currentPoint
                    let dx = end.x - startPoint.x
                    let dy = end.y - startPoint.y
                    let angle = atan2(dy, dx)
                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(Color(hex: colorHex)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                    let headLength = max(lineWidth * 2.8, 24)
                    let headWidth = max(lineWidth * 2.2, 18)
                    let base = CGPoint(x: end.x - cos(angle) * headLength, y: end.y - sin(angle) * headLength)
                    let normal = angle + .pi / 2
                    var head = Path()
                    head.move(to: end)
                    head.addLine(to: CGPoint(x: base.x + cos(normal) * headWidth / 2, y: base.y + sin(normal) * headWidth / 2))
                    head.addLine(to: CGPoint(x: base.x - cos(normal) * headWidth / 2, y: base.y - sin(normal) * headWidth / 2))
                    head.closeSubpath()
                    context.fill(head, with: .color(Color(hex: colorHex)))
                }
                .allowsHitTesting(false)
            }
        }
    }
}

private struct TapeElement: View {
    let color: Color
    let imageURL: URL?

    var body: some View {
        ZStack {
            if let imageURL, let image = CanvasImageCache.shared.image(at: imageURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.72))

                GridPattern(spacing: 44)
                    .stroke(Color.paper.opacity(0.56), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [20, 18]))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BrushStrokePreviewLine: View {
    let points: [CGPoint]
    let color: Color
    let width: CGFloat

    var body: some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        .allowsHitTesting(false)
    }
}

private struct BrushElement: View {
    let element: CanvasElement

    var body: some View {
        if element.brushPoints.count > 1 {
            Path { path in
                guard let first = element.brushPoints.first?.point else { return }
                path.move(to: first)
                for point in element.brushPoints.dropFirst().map(\.point) {
                    path.addLine(to: point)
                }
            }
            .stroke(Color(hex: element.colorHex), style: StrokeStyle(lineWidth: element.brushWidth, lineCap: .round, lineJoin: .round))
        } else {
            Path { path in
                path.move(to: CGPoint(x: 18, y: 100))
                path.addCurve(to: CGPoint(x: 180, y: 48), control1: CGPoint(x: 70, y: 10), control2: CGPoint(x: 124, y: 28))
                path.addCurve(to: CGPoint(x: 360, y: 118), control1: CGPoint(x: 240, y: 78), control2: CGPoint(x: 284, y: 166))
                path.addCurve(to: CGPoint(x: 600, y: 82), control1: CGPoint(x: 430, y: 58), control2: CGPoint(x: 526, y: 36))
            }
            .stroke(Color(hex: element.colorHex), style: StrokeStyle(lineWidth: element.brushWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct LinkCardElement: View {
    let element: CanvasElement

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: min(element.height * 0.36, 70), weight: .semibold))
                .foregroundStyle(Color(hex: element.colorHex))
                .frame(width: element.height * 0.46, height: element.height * 0.46)

            VStack(alignment: .leading, spacing: 10) {
                Text(element.text?.isEmpty == false ? element.text! : "Link")
                    .font(.system(size: min(element.height * 0.18, 38), weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)

                Text(element.linkURL ?? "")
                    .font(.system(size: min(element.height * 0.105, 22), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, max(18, element.width * 0.055))
        .padding(.vertical, max(12, element.height * 0.12))
        .frame(width: element.width, height: element.height)
        .background(
            RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                .fill(Color.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                .stroke(Color(hex: element.colorHex).opacity(0.42), lineWidth: max(2, element.height * 0.018))
        )
    }
}

private struct FileCardElement: View {
    let element: CanvasElement

    private var fileName: String {
        element.text?.isEmpty == false ? element.text! : "Attachment"
    }

    private var extensionText: String {
        let ext = URL(fileURLWithPath: fileName).pathExtension
        return ext.isEmpty ? "FILE" : ext.uppercased()
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: element.cornerRadius * 0.42, style: .continuous)
                    .fill(Color(hex: element.colorHex).opacity(0.16))

                Image(systemName: "doc.fill")
                    .font(.system(size: min(element.height * 0.35, 58), weight: .semibold))
                    .foregroundStyle(Color(hex: element.colorHex))

                Text(extensionText)
                    .font(.system(size: min(element.height * 0.07, 13), weight: .bold, design: .rounded))
                    .foregroundStyle(Color.paper)
                    .padding(.horizontal, 6)
                    .frame(height: max(18, element.height * 0.14))
                    .background(Color(hex: element.colorHex))
                    .clipShape(Capsule())
                    .offset(y: element.height * 0.2)
            }
            .frame(width: element.height * 0.54, height: element.height * 0.54)

            VStack(alignment: .leading, spacing: 9) {
                Text(fileName)
                    .font(.system(size: min(element.height * 0.17, 32), weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)

                Text("Canvas attachment")
                    .font(.system(size: min(element.height * 0.1, 18), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, max(18, element.width * 0.055))
        .padding(.vertical, max(12, element.height * 0.12))
        .frame(width: element.width, height: element.height)
        .background(
            RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                .fill(Color.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                .stroke(Color(hex: element.colorHex).opacity(0.38), lineWidth: max(2, element.height * 0.018))
        )
    }
}

private enum CanvasMediaKind {
    case video
    case audio
}

private struct MediaCardElement: View {
    let element: CanvasElement
    let mediaKind: CanvasMediaKind
    let fileURL: URL?

    private var title: String {
        element.text?.isEmpty == false ? element.text! : (mediaKind == .video ? "Video" : "Audio")
    }

    private var subtitle: String {
        mediaKind == .video ? "Canvas video" : "Canvas audio"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if mediaKind == .video, let fileURL {
                VideoPlayer(player: AVPlayer(url: fileURL))
                    .disabled(true)
                    .frame(width: element.width, height: element.height)
                    .clipShape(RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: element.colorHex).opacity(0.2),
                                Color.paper
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            if mediaKind == .video {
                mediaBadge(icon: "play.fill", size: min(element.height * 0.2, 66))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                HStack(spacing: max(5, element.width * 0.012)) {
                    ForEach(0..<18, id: \.self) { index in
                        Capsule()
                            .fill(Color(hex: element.colorHex).opacity(index.isMultiple(of: 3) ? 0.95 : 0.58))
                            .frame(width: max(5, element.width * 0.012), height: waveformHeight(at: index))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                mediaBadge(icon: "waveform", size: min(element.height * 0.16, 48))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(max(14, element.height * 0.08))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: min(element.height * 0.095, 30), weight: .bold, design: .rounded))
                    .foregroundStyle(Color.paper)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(subtitle)
                    .font(.system(size: min(element.height * 0.065, 18), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.paper.opacity(0.86))
                    .lineLimit(1)
            }
            .padding(.horizontal, max(18, element.width * 0.045))
            .padding(.vertical, max(14, element.height * 0.07))
            .frame(width: element.width, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.62), Color.black.opacity(0.12), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        .frame(width: element.width, height: element.height)
        .clipShape(RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                .stroke(Color(hex: element.colorHex).opacity(0.42), lineWidth: max(2, element.height * 0.012))
        )
    }

    private func mediaBadge(icon: String, size: CGFloat) -> some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(Color(hex: element.colorHex))
            .frame(width: size, height: size)
            .background(Color.paper.opacity(0.9))
            .clipShape(Circle())
    }

    private func waveformHeight(at index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0.28, 0.48, 0.7, 0.42, 0.86, 0.56, 0.34, 0.76, 0.62]
        return max(18, element.height * pattern[index % pattern.count] * 0.52)
    }
}

private struct CanvasShapeElement: View {
    let element: CanvasElement

    var body: some View {
        ZStack {
            switch element.symbol {
            case "circle":
                shapeFill(Circle())
            case "triangle":
                TriangleShape()
                    .fill(Color(hex: element.colorHex).opacity(element.stroke ? 0.08 : 0.78))
                    .overlay(TriangleShape().stroke(Color(hex: element.colorHex), lineWidth: element.stroke ? 10 : 0))
            case "arrow":
                adjustableArrow
            case "line":
                Capsule()
                    .fill(Color(hex: element.colorHex))
                    .frame(height: min(max(element.brushWidth, 4), max(8, element.height * 0.72)))
            case "rounded-rect-outline":
                RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                    .fill(Color(hex: element.colorHex).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                            .stroke(Color(hex: element.colorHex), lineWidth: 10)
                    )
            default:
                shapeFill(RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous))
            }
        }
    }

    private func shapeFill<S: InsettableShape>(_ shape: S) -> some View {
        shape
            .fill(Color(hex: element.colorHex).opacity(element.stroke ? 0.08 : 0.78))
            .overlay(shape.stroke(Color(hex: element.colorHex), lineWidth: element.stroke ? 10 : 0))
    }

    private var adjustableArrow: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let lineWidth = min(max(element.brushWidth, 6), max(10, size.height * 0.72))
            let headLength = max(lineWidth * 2.4, min(size.width * 0.28, size.height * 1.2))
            let headWidth = max(lineWidth * 2.3, size.height * 0.38)
            let start = CGPoint(x: lineWidth / 2, y: size.height / 2)
            let end = CGPoint(x: max(size.width - headLength * 0.62, lineWidth), y: size.height / 2)
            let color = Color(hex: element.colorHex)

            ZStack {
                ArrowShaftShape(start: start, end: end)
                    .stroke(color.opacity(element.stroke ? 0.92 : 1), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                ConnectorArrowHeadShape(
                    tip: CGPoint(x: size.width - lineWidth / 2, y: size.height / 2),
                    length: headLength,
                    width: headWidth
                )
                .fill(color.opacity(element.stroke ? 0.92 : 1))
            }
        }
    }
}

private struct ArrowShaftShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

private struct ConnectorElement: View {
    let element: CanvasElement

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let lineWidth = max(4, min(element.brushWidth, max(size.width, size.height) * 0.22))
            let arrowLength = max(lineWidth * 2.4, min(size.width * 0.18, size.height * 0.72))
            let start = CGPoint(x: lineWidth / 2, y: size.height * 0.5)
            let end = CGPoint(x: size.width - arrowLength * 0.72, y: size.height * 0.5)
            let color = Color(hex: element.colorHex)

            ZStack {
                if element.shadow {
                    ConnectorLineShape(start: start, end: end)
                        .stroke(color.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round, lineJoin: .round))
                        .offset(x: lineWidth * 0.25, y: lineWidth * 0.25)
                }

                ConnectorLineShape(start: start, end: end)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                ConnectorArrowHeadShape(
                    tip: CGPoint(x: size.width - lineWidth / 2, y: size.height * 0.5),
                    length: arrowLength,
                    width: max(lineWidth * 2.2, 22)
                )
                .fill(color)
            }
        }
    }
}

private struct ConnectorLineShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

private struct ConnectorArrowHeadShape: Shape {
    let tip: CGPoint
    let length: CGFloat
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - length, y: tip.y - width / 2))
        path.addLine(to: CGPoint(x: tip.x - length * 0.62, y: tip.y + width * 0.08))
        path.addLine(to: CGPoint(x: tip.x - length * 0.92, y: tip.y + width / 2))
        path.closeSubpath()
        return path
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let shaftHeight = rect.height * 0.36
        let headWidth = min(rect.width * 0.34, rect.height * 0.9)
        let midY = rect.midY
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: midY - shaftHeight / 2))
        path.addLine(to: CGPoint(x: rect.maxX - headWidth, y: midY - shaftHeight / 2))
        path.addLine(to: CGPoint(x: rect.maxX - headWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - headWidth, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - headWidth, y: midY + shaftHeight / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: midY + shaftHeight / 2))
        path.closeSubpath()
        return path
    }
}

private struct ConnectorEndpointHandles: View {
    let start: CGPoint
    let end: CGPoint
    let onDragStart: () -> Void
    let onDragChanged: (ConnectorEndpoint, CGPoint) -> Void
    let onDragEnded: (ConnectorEndpoint) -> Void
    @State private var activeEndpoint: ConnectorEndpoint?

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(Color.clay.opacity(0.54), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [9, 7]))
            .allowsHitTesting(false)

            endpointHandle(.start, at: start, icon: "circle.fill")
            endpointHandle(.end, at: end, icon: "arrowtriangle.right.fill")
        }
    }

    private func endpointHandle(_ endpoint: ConnectorEndpoint, at point: CGPoint, icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: endpoint == .start ? 11 : 15, weight: .bold))
            .foregroundStyle(activeEndpoint == endpoint ? Color.clay : Color.paper)
            .frame(width: 38, height: 38)
            .background(activeEndpoint == endpoint ? Color.paper : Color.clay)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.paper, lineWidth: 4))
            .shadow(color: Color.black.opacity(0.14), radius: 5, x: 0, y: 3)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvasSpace"))
                    .onChanged { value in
                        if activeEndpoint == nil {
                            activeEndpoint = endpoint
                            onDragStart()
                        }
                        onDragChanged(endpoint, value.location)
                    }
                    .onEnded { _ in
                        activeEndpoint = nil
                        onDragEnded(endpoint)
                    }
            )
            .accessibilityLabel(Text(endpoint == .start ? "Move connector start" : "Move connector end"))
    }
}

private struct MultiSelectionBox: View {
    let rect: CGRect
    let onMoveStart: () -> Void
    let onMoveChanged: (CGSize) -> Void
    let onMoveEnded: () -> Void
    let onTransformStart: () -> Void
    let onResizeChanged: (CGFloat) -> Void
    let onRotateChanged: (Double) -> Void
    let onTransformEnded: () -> Void
    @State private var dragging = false
    @State private var resizing = false
    @State private var rotating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.clay, style: StrokeStyle(lineWidth: 3, dash: [16, 10]))
                .background(Color.clay.opacity(dragging ? 0.08 : 0.03))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !dragging {
                                dragging = true
                                onMoveStart()
                            }
                            onMoveChanged(value.translation)
                        }
                        .onEnded { _ in
                            dragging = false
                            onMoveEnded()
                        }
                )

            multiHandle("arrow.up.left.and.arrow.down.right")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !resizing {
                                resizing = true
                                onTransformStart()
                            }
                            let base = max(rect.width, rect.height, 1)
                            let delta = (value.translation.width + value.translation.height) / max(base, 1)
                            onResizeChanged(min(max(1 + delta, 0.18), 4))
                        }
                        .onEnded { _ in
                            resizing = false
                            onTransformEnded()
                        }
                )

            multiHandle("rotate.right")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !rotating {
                                rotating = true
                                onTransformStart()
                            }
                            onRotateChanged(Double(value.translation.width / 2))
                        }
                        .onEnded { _ in
                            rotating = false
                            onTransformEnded()
                        }
                )
        }
        .frame(width: rect.width + 24, height: rect.height + 24)
        .position(x: rect.midX, y: rect.midY)
    }

    private func multiHandle(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.paper)
            .frame(width: 46, height: 46)
            .background(Color.clay)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.paper, lineWidth: 3))
    }
}

private struct FloatingSelectionToolbar: View {
    let selectedCount: Int
    let selectedElement: CanvasElement?
    let colorOptions: [String]
    let onColor: (String) -> Void
    let onWidthDown: () -> Void
    let onWidthUp: () -> Void
    let onSetWidth: (CGFloat) -> Void
    let onTapeLengthDown: () -> Void
    let onTapeLengthUp: () -> Void
    let onSetTapeLength: (CGFloat) -> Void
    let onSetOpacity: (Double) -> Void
    let onSetCornerRadius: (CGFloat) -> Void
    let onToggleStroke: () -> Void
    let onToggleShadow: () -> Void
    let onBringForward: () -> Void
    let onSendBackward: () -> Void
    let onDuplicate: () -> Void
    let onToggleHidden: () -> Void
    let onToggleLocked: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var expandedPanel: FloatingToolbarPanel?

    private var canTuneLineWidth: Bool {
        selectedCount == 1 && selectedElement?.supportsLineWidth == true
    }

    private var canTuneTapeLength: Bool {
        selectedCount == 1 && selectedElement?.kind == .tape && selectedElement?.locked == false
    }

    private var canTuneColor: Bool {
        guard selectedCount == 1, let selectedElement, !selectedElement.locked else { return false }
        switch selectedElement.kind {
        case .image, .file, .video, .audio:
            return false
        default:
            return true
        }
    }

    private var canTuneStyle: Bool {
        guard selectedCount == 1, let selectedElement, !selectedElement.locked else { return false }
        return selectedElement.kind != .file && selectedElement.kind != .audio && selectedElement.kind != .video
    }

    private var canEdit: Bool {
        selectedCount == 1 &&
            selectedElement?.locked == false &&
            (selectedElement?.kind == .text || selectedElement?.kind == .wordArt || selectedElement?.kind == .link)
    }

    var body: some View {
        VStack(spacing: 7) {
            if expandedPanel == .color, canTuneColor {
                expandedColorPanel
            } else if expandedPanel == .lineWidth, canTuneLineWidth {
                expandedLineWidthPanel
            } else if expandedPanel == .tapeLength, canTuneTapeLength {
                expandedTapeLengthPanel
            } else if expandedPanel == .style, canTuneStyle {
                expandedStylePanel
            }

            HStack(spacing: 7) {
                Text(selectedCount > 1 ? "\(selectedCount)" : objectLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .frame(minWidth: 34)
                    .frame(height: 30)
                    .padding(.horizontal, 6)
                    .background(Color.paper.opacity(0.9))
                    .clipShape(Capsule())

                if selectedElement?.kind == .image {
                    gestureHint("hand.draw")
                    gestureHint("arrow.up.left.and.arrow.down.right")
                    gestureHint("rotate.right")
                }

                if canTuneColor {
                    TrackedEditorToolButton(componentID: "floating.selection.color-panel", disabled: false, action: {
                        expandedPanel = expandedPanel == .color ? nil : .color
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: selectedElement?.colorHex ?? colorOptions[0]))
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.paper, lineWidth: 2))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.clay)
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 30)
                        .background(Color.paper.opacity(0.9))
                        .clipShape(Capsule())
                    }
                }

                if canTuneLineWidth {
                    toolbarButton("lineweight", active: expandedPanel == .lineWidth) {
                        expandedPanel = expandedPanel == .lineWidth ? nil : .lineWidth
                    }
                }

                if canTuneTapeLength {
                    toolbarButton("arrow.left.and.right", active: expandedPanel == .tapeLength) {
                        expandedPanel = expandedPanel == .tapeLength ? nil : .tapeLength
                    }
                }

                if canTuneStyle {
                    toolbarButton("slider.horizontal.3", active: expandedPanel == .style) {
                        expandedPanel = expandedPanel == .style ? nil : .style
                    }
                }

                if canEdit {
                    toolbarButton("pencil", action: onEdit)
                }
                toolbarButton("plus.square.on.square", action: onDuplicate)
                toolbarButton(selectedElement?.hidden == true ? "eye" : "eye.slash", action: onToggleHidden)
                toolbarButton(selectedElement?.locked == true ? "lock.open" : "lock", action: onToggleLocked)
                toolbarButton("arrow.up.square", action: onBringForward)
                toolbarButton("arrow.down.square", action: onSendBackward)
                toolbarButton("trash", destructive: true, action: onDelete)
            }
            .padding(.horizontal, 8)
            .frame(height: 42)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.paper.opacity(0.82), lineWidth: 1.2))
            .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
        }
        .onAppear {
            if selectedElement?.kind == .image {
                expandedPanel = .style
            }
        }
        .onChange(of: selectedElement?.id) { _, _ in
            if selectedElement?.kind == .image {
                expandedPanel = .style
            }
        }
    }

    private var objectLabel: String {
        guard let selectedElement else { return "Object" }
        switch selectedElement.kind {
        case .connector:
            return "Arrow"
        case .shape:
            return selectedElement.symbol == "arrow" ? "Arrow" : "Shape"
        case .image:
            return "Image"
        case .text, .wordArt:
            return "Text"
        default:
            return selectedElement.kind.rawValue.capitalized
        }
    }

    private var expandedColorPanel: some View {
        HStack(spacing: 8) {
            ForEach(colorOptions, id: \.self) { colorHex in
                TrackedEditorToolButton(componentID: "floating.selection.color.\(colorHex.replacingOccurrences(of: "#", with: ""))", disabled: false, action: { onColor(colorHex) }) {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(selectedElement?.colorHex == colorHex ? Color.clay : Color.paper, lineWidth: selectedElement?.colorHex == colorHex ? 3 : 2))
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.paper.opacity(0.82), lineWidth: 1.2))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    }

    private var expandedLineWidthPanel: some View {
        HStack(spacing: 10) {
            toolbarButton("minus", action: onWidthDown)
            Slider(
                value: Binding(
                    get: { min(max(selectedElement?.brushWidth ?? 18, 4), 140) },
                    set: { onSetWidth($0) }
                ),
                in: 4...140,
                step: 1
            )
            .frame(width: 148)
            Text("\(Int((selectedElement?.brushWidth ?? 18).rounded()))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .frame(width: 34, height: 30)
                .background(Color.paper.opacity(0.9))
                .clipShape(Capsule())
            toolbarButton("plus", action: onWidthUp)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.paper.opacity(0.82), lineWidth: 1.2))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    }

    private var expandedTapeLengthPanel: some View {
        HStack(spacing: 10) {
            toolbarButton("minus", action: onTapeLengthDown)
            Slider(
                value: Binding(
                    get: { min(max(selectedElement?.width ?? 320, 90), 1460) },
                    set: { onSetTapeLength($0) }
                ),
                in: 90...1460,
                step: 5
            )
            .frame(width: 156)
            Text("\(Int((selectedElement?.width ?? 320).rounded()))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .frame(width: 42, height: 30)
                .background(Color.paper.opacity(0.9))
                .clipShape(Capsule())
            toolbarButton("plus", action: onTapeLengthUp)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.paper.opacity(0.82), lineWidth: 1.2))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    }

    private var expandedStylePanel: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.clay)
                .frame(width: 28, height: 30)
                .background(Color.paper.opacity(0.9))
                .clipShape(Circle())

            Slider(
                value: Binding(
                    get: { min(max(selectedElement?.opacity ?? 1, 0.2), 1) },
                    set: { onSetOpacity($0) }
                ),
                in: 0.2...1,
                step: 0.02
            )
            .frame(width: 104)

            Text("\(Int(((selectedElement?.opacity ?? 1) * 100).rounded()))")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .frame(width: 34, height: 30)
                .background(Color.paper.opacity(0.9))
                .clipShape(Capsule())

            if selectedElement?.kind == .image || selectedElement?.kind == .shape || selectedElement?.kind == .link {
                Image(systemName: "rectangle.roundedtop")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.clay)
                Slider(
                    value: Binding(
                        get: { min(max(selectedElement?.cornerRadius ?? 0, 0), 80) },
                        set: { onSetCornerRadius($0) }
                    ),
                    in: 0...80,
                    step: 1
                )
                .frame(width: 96)
            }

            toolbarButton("shadow", active: selectedElement?.shadow == true, action: onToggleShadow)
            toolbarButton("pencil.and.outline", active: selectedElement?.stroke == true, action: onToggleStroke)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.paper.opacity(0.82), lineWidth: 1.2))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    }

    private func toolbarButton(_ icon: String, destructive: Bool = false, active: Bool = false, action: @escaping () -> Void) -> some View {
        TrackedEditorToolButton(componentID: "floating.selection.\(normalizedComponentID(icon))", disabled: false, action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(destructive ? Color.red : (active ? Color.paper : Color.clay))
                .frame(width: 30, height: 30)
                .background(active ? Color.clay : Color.paper.opacity(0.9))
                .clipShape(Circle())
        }
    }

    private func normalizedComponentID(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    private func gestureHint(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.clay.opacity(0.82))
            .frame(width: 30, height: 30)
            .background(Color.paper.opacity(0.68))
            .clipShape(Circle())
    }
}

private enum FloatingToolbarPanel {
    case color
    case lineWidth
    case tapeLength
    case style
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(x: minX * scale, y: minY * scale, width: width * scale, height: height * scale)
    }

    func rotatedBoundingBox(degrees: Double) -> CGRect {
        let radians = CGFloat(degrees * .pi / 180)
        let transform = CGAffineTransform(translationX: midX, y: midY)
            .rotated(by: radians)
            .translatedBy(x: -midX, y: -midY)
        return applying(transform)
    }
}

private enum EditorPanel {
    case multi
    case layer
    case effect
    case tool
    case more
}

private enum EditorToolShelf: String, CaseIterable, Identifiable {
    case add
    case adjust
    case arrange
    case object

    var id: String { rawValue }

    var title: String {
        switch self {
        case .add: return "Add"
        case .adjust: return "Adjust"
        case .arrange: return "Arrange"
        case .object: return "Object"
        }
    }

    var icon: String {
        switch self {
        case .add: return "plus.circle"
        case .adjust: return "dial.medium"
        case .arrange: return "square.grid.2x2"
        case .object: return "square.stack.3d.up"
        }
    }
}

private enum TextInsertMode {
    case normal
    case wordArt
}

private enum CanvasAssetSheet: String, Identifiable {
    case templates
    case text
    case stickers
    case shapes
    case backgrounds
    case tapes
    case brush
    case wordArt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .templates: return "Templates"
        case .text: return "Text"
        case .stickers: return "Stickers"
        case .shapes: return "Shapes"
        case .backgrounds: return "Backgrounds"
        case .tapes: return "Tape"
        case .brush: return "Brush"
        case .wordArt: return "WordArt"
        }
    }
}

private enum StoreInsertAction {
    case material(MaterialItem)
    case sticker(StickerDefinition)
    case tape(TapeDefinition)
    case textPreset(TextPresetDefinition)
    case brushPreset(BrushPresetDefinition)
    case background(BackgroundDefinition)
    case template(PageTemplateDefinition)
}

private struct MaterialStoreHomeView: View {
    @ObservedObject var repository: NotebookRepository
    @ObservedObject var locationProvider: TravelLocationProvider
    let onInsert: (StoreInsertAction) -> Void
    @State private var query = ""
    @State private var selectedCategory: StoreCategory = .materials

    private var materialItems: [MaterialItem] {
        repository.materialGroups.flatMap(\.items)
    }

    private var filteredMaterialItems: [MaterialItem] {
        filteredMaterialItems(in: materialItems)
    }

    private var stickerMaterialItems: [MaterialItem] {
        filteredMaterialItems(in: materialItems.filter { materialKind(for: $0) == .sticker })
    }

    private var filteredFallbackStickers: [StickerDefinition] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return repository.stickerLibrary }
        return repository.stickerLibrary.filter { sticker in
            [sticker.title, sticker.id, sticker.symbol].contains { $0.lowercased().contains(trimmed) }
        }
    }

    private var filteredTapeGroups: [TapeGroup] {
        let groups = repository.availableTapeGroups
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return groups }
        return groups.compactMap { group in
            let groupMatches = ([group.title, group.id] + group.tags).contains { $0.lowercased().contains(trimmed) }
            let items = group.items.filter { tape in
                ([tape.title, tape.id, tape.groupID, tape.fileName ?? ""] + tape.tags).contains { $0.lowercased().contains(trimmed) }
            }
            if groupMatches {
                return group
            }
            guard !items.isEmpty else { return nil }
            return TapeGroup(id: group.id, title: group.title, tags: group.tags, items: items)
        }
    }

    private var filteredTextPresets: [TextPresetDefinition] {
        filteredTextPresets(in: repository.textPresetLibrary)
    }

    private var filteredWordArtPresets: [TextPresetDefinition] {
        filteredTextPresets(in: repository.wordArtLibrary)
    }

    private var filteredBrushPresets: [BrushPresetDefinition] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return repository.brushPresetLibrary }
        return repository.brushPresetLibrary.filter { preset in
            [preset.title, preset.id, preset.colorHex].contains { $0.lowercased().contains(trimmed) }
        }
    }

    private var filteredBackgrounds: [BackgroundDefinition] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return repository.backgroundLibrary }
        return repository.backgroundLibrary.filter { background in
            [background.title, background.id, background.colorA, background.colorB].contains { $0.lowercased().contains(trimmed) }
        }
    }

    private var filteredTemplates: [PageTemplateDefinition] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return repository.templateLibrary }
        return repository.templateLibrary.filter { template in
            [template.title, template.id].contains { $0.lowercased().contains(trimmed) }
        }
    }

    private var storeItemCount: Int {
        switch selectedCategory {
        case .materials:
            return filteredMaterialItems.count
        case .tape:
            return filteredTapeGroups.reduce(0) { $0 + $1.items.count }
        case .text:
            return filteredTextPresets.count
        case .stickers:
            return stickerMaterialItems.count + filteredFallbackStickers.count
        case .brush:
            return filteredBrushPresets.count
        case .wordArt:
            return filteredWordArtPresets.count
        case .backgrounds:
            return filteredBackgrounds.count
        case .templates:
            return filteredTemplates.count
        }
    }

    private var categories: [StoreCategory] {
        StoreCategory.allCases
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "storefront")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.clay)
                        .frame(width: 52, height: 52)
                        .background(Color.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Store")
                            .font(.system(size: 31, weight: .bold, design: .serif))
                            .foregroundStyle(Color.ink)

                        Text(storeSubtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                searchField

                categorySelector

                storeContent
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 116)
        }
    }

    private var storeSubtitle: String {
        let location = locationProvider.mapDisplayName
        return location == "Pick a place" ? "Materials, tape, text, brush, and WordArt" : "Materials near \(location)"
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.clay)

            TextField("Search \(selectedCategory.title)", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)

            if !query.isEmpty {
                TrackedEditorToolButton(componentID: "store.home.search.clear", disabled: false, action: {
                    query = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkSoft)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.bannerSoft, lineWidth: 1.5))
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    TrackedEditorToolButton(componentID: "store.home.category.\(category.rawValue)", disabled: false, action: {
                        selectedCategory = category
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: category.icon)
                                .font(.system(size: 21, weight: .bold))
                                .frame(width: 48, height: 34)
                                .foregroundStyle(selectedCategory == category ? Color.paper : Color.clay)
                                .background(selectedCategory == category ? Color.clay : Color.paper)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.lineSoft, lineWidth: selectedCategory == category ? 0 : 1))

                            Text(category.title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.clay)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(width: 66)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var storeContent: some View {
        switch selectedCategory {
        case .materials:
            if filteredMaterialItems.isEmpty {
                emptyStoreView
            } else {
                LazyVGrid(columns: StoreGrid.columns, spacing: 12) {
                    ForEach(filteredMaterialItems) { item in
                        MaterialItemCard(item: item) {
                            onInsert(.material(item))
                        }
                    }
                }
            }
        case .tape:
            if filteredTapeGroups.isEmpty {
                emptyStoreView
            } else {
                TapePanel(groups: filteredTapeGroups) { tape in
                    onInsert(.tape(tape))
                }
            }
        case .text:
            if filteredTextPresets.isEmpty {
                emptyStoreView
            } else {
                PresetTextPanel(presets: filteredTextPresets) { preset in
                    onInsert(.textPreset(preset))
                }
            }
        case .stickers:
            if stickerMaterialItems.isEmpty && filteredFallbackStickers.isEmpty {
                emptyStoreView
            } else {
                LazyVGrid(columns: StoreGrid.columns, spacing: 12) {
                    ForEach(stickerMaterialItems) { item in
                        MaterialItemCard(item: item) {
                            onInsert(.material(item))
                        }
                    }

                    ForEach(filteredFallbackStickers) { sticker in
                        StickerChoiceCard(sticker: sticker) {
                            onInsert(.sticker(sticker))
                        }
                    }
                }
            }
        case .brush:
            if filteredBrushPresets.isEmpty {
                emptyStoreView
            } else {
                BrushPresetPanel(presets: filteredBrushPresets) { preset in
                    onInsert(.brushPreset(preset))
                }
            }
        case .wordArt:
            if filteredWordArtPresets.isEmpty {
                emptyStoreView
            } else {
                PresetTextPanel(presets: filteredWordArtPresets) { preset in
                    onInsert(.textPreset(preset))
                }
            }
        case .backgrounds:
            if filteredBackgrounds.isEmpty {
                emptyStoreView
            } else {
                LazyVGrid(columns: StoreGrid.columns, spacing: 12) {
                    ForEach(filteredBackgrounds) { background in
                        BackgroundChoiceCard(background: background, selected: false) {
                            onInsert(.background(background))
                        }
                    }
                }
            }
        case .templates:
            if filteredTemplates.isEmpty {
                emptyStoreView
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(filteredTemplates) { template in
                        TemplateChoiceCard(template: template, imageURL: { repository.imageURL(for: $0) }) {
                            onInsert(.template(template))
                        }
                    }
                }
            }
        }
    }

    private var emptyStoreView: some View {
        ContentUnavailableView("No \(selectedCategory.title) found", systemImage: "magnifyingglass", description: Text("Try another category, city, tag, or file name."))
            .foregroundStyle(Color.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
    }

    private func filteredMaterialItems(in items: [MaterialItem]) -> [MaterialItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            ([item.title, item.fileName, item.country, item.city, item.category ?? ""] + item.tags).contains { $0.lowercased().contains(trimmed) }
        }
    }

    private func filteredTextPresets(in presets: [TextPresetDefinition]) -> [TextPresetDefinition] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return presets }
        return presets.filter { preset in
            [preset.title, preset.id, preset.previewText, preset.style.text, preset.style.fontName, preset.style.colorHex].contains { $0.lowercased().contains(trimmed) }
        }
    }

    private func materialKind(for item: MaterialItem) -> MaterialKind {
        let tokens = ([item.title, item.fileName, item.category ?? ""] + item.tags).map { $0.lowercased() }
        return tokens.contains { $0.contains("tape") || $0.contains("washi") || $0.contains("胶带") } ? .tape : .sticker
    }
}

private struct UniverseRootTabView: View {
    @ObservedObject var repository: NotebookRepository
    @ObservedObject var locationProvider: TravelLocationProvider
    let onInsert: (StoreInsertAction) -> Void

    private var featuredGroups: [MaterialGroup] {
        let locationTokens = ([locationProvider.searchedPlaceName, locationProvider.city, locationProvider.regionName, locationProvider.country])
            .compactMap { $0 }
            .flatMap(\.locationTokens)

        let locationMatches = repository.materialGroups.filter { group in
            let groupTokens = ([group.city, group.country, group.title] + group.tags).flatMap(\.locationTokens)
            return locationTokens.contains { token in
                groupTokens.contains { value in value == token || value.contains(token) || token.contains(value) }
            }
        }

        let source = locationMatches.isEmpty ? repository.materialGroups : locationMatches
        return Array(source.prefix(4))
    }

    private var spotlightItems: [MaterialItem] {
        Array(featuredGroups.flatMap(\.items).prefix(12))
    }

    private var universeSubtitle: String {
        let place = locationProvider.mapDisplayName
        return place == "Pick a place" ? "Travel packs, templates, and local material ideas." : "Travel packs inspired by \(place)."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "globe.asia.australia")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(Color.clay)
                        .frame(width: 54, height: 54)
                        .background(Color.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Universe")
                            .font(.system(size: 31, weight: .bold, design: .serif))
                            .foregroundStyle(Color.ink)

                        Text(universeSubtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                if spotlightItems.isEmpty {
                    emptyUniverse
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Travel Picks")
                            .sectionTitle()

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(spotlightItems) { item in
                                    UniverseMaterialCard(item: item) {
                                        onInsert(.material(item))
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("City Packs")
                        .sectionTitle()

                    ForEach(featuredGroups) { group in
                        UniversePackRow(group: group) { item in
                            onInsert(.material(item))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Start With A Layout")
                        .sectionTitle()

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(repository.templateLibrary.prefix(2)) { template in
                            TemplateChoiceCard(template: template, imageURL: { repository.imageURL(for: $0) }) {
                                onInsert(.template(template))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Paper Styles")
                        .sectionTitle()

                    LazyVGrid(columns: StoreGrid.columns, spacing: 12) {
                        ForEach(repository.backgroundLibrary.prefix(3)) { background in
                            BackgroundChoiceCard(background: background, selected: false) {
                                onInsert(.background(background))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 116)
        }
    }

    private var emptyUniverse: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color.clay)
            Text("No travel packs found yet.")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
            Text("Templates and paper styles are still available below.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paper.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))
    }
}

private struct UniverseMaterialCard: View {
    let item: MaterialItem
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "universe.material.\(telemetryIDSegment(item.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 8) {
                if let image = CanvasImageCache.shared.image(at: item.fileURL, maxPixelSize: 420) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 132, height: 104)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                        .frame(width: 132, height: 104)
                        .background(Color.paper)
                }

                Text(item.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)

                Text([item.city, item.country].filter { !$0.isEmpty }.joined(separator: " / "))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(width: 148, height: 166, alignment: .topLeading)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct UniversePackRow: View {
    let group: MaterialGroup
    let onMaterial: (MaterialItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.clay)
                    .frame(width: 24, height: 24)
                    .background(Color.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1))

                Text(group.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)

                Text("\(group.items.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Color.paper.opacity(0.82))
                    .clipShape(Capsule())

                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(group.items.prefix(10)) { item in
                        MaterialStoreShelfItem(item: item) {
                            onMaterial(item)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private enum StoreCategory: String, CaseIterable, Identifiable {
    case materials
    case tape
    case text
    case stickers
    case brush
    case wordArt
    case backgrounds
    case templates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .materials: return "Store"
        case .tape: return "Tape"
        case .text: return "Text"
        case .stickers: return "Stickers"
        case .brush: return "Brush"
        case .wordArt: return "WordArt"
        case .backgrounds: return "Paper"
        case .templates: return "Template"
        }
    }

    var icon: String {
        switch self {
        case .materials: return "storefront"
        case .tape: return "rectangle.on.rectangle.angled"
        case .text: return "textformat"
        case .stickers: return "sparkles"
        case .brush: return "paintbrush.pointed"
        case .wordArt: return "textformat.size"
        case .backgrounds: return "paintpalette"
        case .templates: return "square.grid.2x2"
        }
    }
}

private enum StoreGrid {
    static let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
}

private struct PlaceholderRootTabView: View {
    let title: String
    let icon: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color.clay)
                .frame(width: 86, height: 86)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

            Text(title)
                .font(.system(size: 31, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 96)
    }
}

private struct CanvasAssetPickerSheet: View {
    let sheet: CanvasAssetSheet
    @ObservedObject var repository: NotebookRepository
    @ObservedObject var locationProvider: TravelLocationProvider
    let document: CanvasDocument
    let onTemplate: (PageTemplateDefinition) -> Void
    let onTextPreset: (TextPresetDefinition) -> Void
    let onSticker: (StickerDefinition) -> Void
    let onMaterial: (MaterialItem) -> Void
    let onShape: (ShapeDefinition) -> Void
    let onBackground: (BackgroundDefinition) -> Void
    let onTape: (TapeDefinition) -> Void
    let onBrushPreset: (BrushPresetDefinition) -> Void
    let onCancel: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    @State private var materialSearch = ""

    private var allMaterialGroups: [MaterialGroup] {
        repository.materialGroups
    }

    private var materialGroups: [MaterialGroup] {
        let groups = allMaterialGroups
        let query = materialSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let groupMatched = ([group.title, group.country, group.city] + group.tags).contains { $0.lowercased().contains(query) }
            let items = group.items.filter { item in
                ([item.title, item.fileName, item.country, item.city] + item.tags).contains { $0.lowercased().contains(query) }
            }
            if groupMatched {
                return group
            }
            guard !items.isEmpty else { return nil }
            return MaterialGroup(id: group.id, title: group.title, country: group.country, city: group.city, tags: group.tags, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                switch sheet {
                case .templates:
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(repository.templateLibrary) { template in
                            TemplateChoiceCard(template: template, imageURL: { repository.imageURL(for: $0) }) {
                                onTemplate(template)
                            }
                        }
                    }
                    .padding(16)
                case .text:
                    PresetTextPanel(presets: repository.textPresetLibrary, onPreset: onTextPreset)
                        .padding(16)
                case .stickers:
                    MaterialPanel(
                        groups: materialGroups,
                        allGroups: allMaterialGroups,
                        locationProvider: locationProvider,
                        query: $materialSearch,
                        fallbackStickers: repository.stickerLibrary,
                        onMaterial: onMaterial,
                        onSticker: onSticker
                    )
                    .padding(16)
                case .shapes:
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(repository.shapeLibrary) { shape in
                            ShapeChoiceCard(shape: shape) {
                                onShape(shape)
                            }
                        }
                    }
                    .padding(16)
                case .backgrounds:
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(repository.backgroundLibrary) { background in
                            BackgroundChoiceCard(background: background, selected: background.colorA == document.background.colorA && background.colorB == document.background.colorB) {
                                onBackground(background)
                            }
                        }
                    }
                    .padding(16)
                case .tapes:
                    TapePanel(groups: repository.availableTapeGroups, onTape: onTape)
                    .padding(16)
                case .brush:
                    BrushPresetPanel(presets: repository.brushPresetLibrary, onPreset: onBrushPreset)
                        .padding(16)
                case .wordArt:
                    PresetTextPanel(presets: repository.wordArtLibrary, onPreset: onTextPreset)
                        .padding(16)
                }
            }
            .background(Color.background)
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    TrackedEditorToolButton(componentID: "asset.sheet.done", disabled: false, action: onCancel) {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.clay)
                    }
                }
            }
        }
    }
}

private struct TemplateChoiceCard: View {
    let template: PageTemplateDefinition
    let imageURL: (String?) -> URL?
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.template.\(telemetryIDSegment(template.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 8) {
                CanvasTemplatePreview(template: template, imageURL: imageURL)
                    .aspectRatio(0.72, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

                Text(template.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .padding(10)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct PresetTextPanel: View {
    let presets: [TextPresetDefinition]
    let onPreset: (TextPresetDefinition) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(presets) { preset in
                TextPresetChoiceCard(preset: preset) {
                    onPreset(preset)
                }
            }
        }
    }
}

private struct TextPresetChoiceCard: View {
    let preset: TextPresetDefinition
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.text-preset.\(telemetryIDSegment(preset.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Text(preset.previewText)
                    .font(FontResolver.swiftUIFont(name: preset.style.fontName, size: min(preset.style.fontSize, 34), bold: preset.style.bold, italic: preset.style.italic))
                    .foregroundStyle(textForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(Color(hex: preset.style.colorHex).opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack {
                    Text(preset.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: preset.kind == .wordArt ? "textformat.size" : "textformat")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.clay)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .frame(height: 126)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }

    private var textForeground: some ShapeStyle {
        if preset.kind == .wordArt {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: preset.style.colorHex), Color.sand, Color.paper],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color(hex: preset.style.colorHex))
    }
}

private struct BrushPresetPanel: View {
    let presets: [BrushPresetDefinition]
    let onPreset: (BrushPresetDefinition) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(presets) { preset in
                BrushPresetChoiceCard(preset: preset) {
                    onPreset(preset)
                }
            }
        }
    }
}

private struct BrushPresetChoiceCard: View {
    let preset: BrushPresetDefinition
    let action: () -> Void

    private var previewElement: CanvasElement {
        let minX = preset.points.map(\.x).min() ?? 0
        let maxX = preset.points.map(\.x).max() ?? 0
        let minY = preset.points.map(\.y).min() ?? 0
        let maxY = preset.points.map(\.y).max() ?? 0
        let padding = max(preset.width, 48)
        let width = max(maxX - minX + padding * 2, 180)
        let height = max(maxY - minY + padding * 2, 140)
        let points = preset.points.map { point in
            CodablePoint(x: point.x - minX + padding, y: point.y - minY + padding)
        }
        return CanvasElement(
            kind: .brush,
            x: width / 2,
            y: height / 2,
            width: width,
            height: height,
            zIndex: 0,
            opacity: preset.opacity,
            colorHex: preset.colorHex,
            brushWidth: preset.width,
            brushPoints: points
        )
    }

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.brush-preset.\(telemetryIDSegment(preset.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 9) {
                BrushElement(element: previewElement.displayScaled(by: 0.18))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(Color(hex: preset.colorHex).opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack {
                    Text(preset.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "paintbrush.pointed")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.clay)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .frame(height: 126)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct MaterialPanel: View {
    let groups: [MaterialGroup]
    let allGroups: [MaterialGroup]
    @ObservedObject var locationProvider: TravelLocationProvider
    @Binding var query: String
    let fallbackStickers: [StickerDefinition]
    let onMaterial: (MaterialItem) -> Void
    let onSticker: (StickerDefinition) -> Void
    @State private var selectedShelf: MaterialShelf = .recommended
    @State private var selectedCategoryID = "all"
    @State private var showingStorePage = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var materialItems: [MaterialItem] {
        groups.flatMap(\.items)
    }

    private var selectedCoordinate: CLLocationCoordinate2D {
        _ = locationProvider.placeRevision
        return locationProvider.coordinate
    }

    private var shelfItems: [MaterialItem] {
        switch selectedShelf {
        case .recommended:
            let nearbyItems = rankedNearbyItems(from: materialItems)
            if !nearbyItems.isEmpty { return nearbyItems }
            let localItems = materialItems.filter { !$0.city.isEmpty && $0.country.lowercased() != "global" }
            return localItems.isEmpty ? materialItems : localItems
        case .places:
            let nearbyItems = rankedNearbyItems(from: materialItems)
            if !nearbyItems.isEmpty { return nearbyItems }
            return materialItems.filter { !$0.city.isEmpty && $0.country.lowercased() != "global" }
        case .tapes:
            return materialItems.filter { materialKind(for: $0) == .tape }
        case .icons:
            return materialItems.filter { materialKind(for: $0) != .tape }
        case .all:
            return materialItems
        }
    }

    private var visibleItems: [MaterialItem] {
        let filtered: [MaterialItem]
        switch selectedCategoryID {
        case "all":
            filtered = shelfItems
        case "location":
            filtered = locationItems
        case "common":
            filtered = commonItems
        default:
            filtered = shelfItems.filter { categoryID(for: $0) == selectedCategoryID }
        }
        return filtered.sorted(by: materialSort)
    }

    private var visibleFallbackStickers: [StickerDefinition] {
        guard selectedShelf == .recommended || selectedShelf == .icons || selectedShelf == .all else { return [] }
        guard selectedCategoryID == "all", visibleItems.isEmpty else { return [] }
        return fallbackStickers
    }

    private var usesShelfRows: Bool { false }

    private var shelfRows: [MaterialStoreRow] {
        let grouped = Dictionary(grouping: visibleItems, by: categoryID)
        return grouped.map { id, items -> MaterialStoreRow in
            let sortedItems = items.sorted(by: materialSort)
            let first = sortedItems[0]
            return MaterialStoreRow(
                id: id,
                title: categoryTitle(for: first),
                icon: categoryIcon(for: first),
                count: sortedItems.count,
                items: sortedItems
            )
        }
        .sorted { lhs, rhs in
            let lhsPriority = categoryPriority(lhs.id)
            let rhsPriority = categoryPriority(rhs.id)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var categoryOptions: [MaterialCategoryOption] {
        let grouped = Dictionary(grouping: shelfItems.filter(itemMatchesPrimaryTag), by: categoryID)
        let options = grouped.map { id, items -> MaterialCategoryOption in
            let first = items[0]
            return MaterialCategoryOption(
                id: id,
                title: categoryTitle(for: first),
                icon: categoryIcon(for: first),
                count: items.count,
                previewURL: previewURL(for: id, items: items),
                showsLocationBadge: id.hasPrefix("place-")
            )
        }
        .sorted { lhs, rhs in
            let lhsPriority = categoryPriority(lhs.id)
            let rhsPriority = categoryPriority(rhs.id)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        let primary = [
            MaterialCategoryOption(id: "all", title: "All", icon: selectedShelf.icon, count: shelfItems.count, previewURL: previewURL(for: "all", items: shelfItems), showsLocationBadge: false),
            MaterialCategoryOption(id: "location", title: locationTagTitle, icon: "mappin.and.ellipse", count: locationItems.count, previewURL: previewURL(for: "location", items: locationItems), showsLocationBadge: true),
            MaterialCategoryOption(id: "common", title: "Common", icon: "sparkles", count: commonItems.count, previewURL: previewURL(for: "common", items: commonItems), showsLocationBadge: false)
        ].filter { $0.id == "all" || $0.count > 0 }
        return primary + options.prefix(8)
    }

    private var locationTagTitle: String {
        let title = locationProvider.mapDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty || title == "Pick a place" ? "Here" : title
    }

    private var locationTokens: Set<String> {
        Set(([locationProvider.searchedPlaceName, locationProvider.city, locationProvider.regionName, locationProvider.country])
            .compactMap { $0 }
            .flatMap(\.locationTokens))
    }

    private var locationItems: [MaterialItem] {
        guard !locationTokens.isEmpty else { return rankedNearbyItems(from: materialItems) }
        let exact = materialItems.filter(isLocationItem)
        return exact.isEmpty ? rankedNearbyItems(from: materialItems) : exact
    }

    private var commonItems: [MaterialItem] {
        materialItems.filter(isCommonItem)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            storeSearchRow

            categorySelector

            if groups.isEmpty && visibleFallbackStickers.isEmpty {
                ContentUnavailableView("No materials found", systemImage: "magnifyingglass", description: Text("Try another city, tag, or file name."))
                    .foregroundStyle(Color.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                if visibleItems.isEmpty && visibleFallbackStickers.isEmpty {
                    ContentUnavailableView("No materials in this category", systemImage: "square.grid.2x2", description: Text("Try another category or search."))
                        .foregroundStyle(Color.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                } else {
                    materialContent
                }
            }
        }
        .navigationDestination(isPresented: $showingStorePage) {
            MaterialStorePage(
                title: "Store",
                rows: storeRows,
                fallbackStickers: fallbackStickers,
                onMaterial: onMaterial,
                onSticker: onSticker
            )
            .background(Color.background)
        }
        .onChange(of: selectedShelf) { _, _ in
            selectedCategoryID = "all"
        }
        .task(id: preheatToken) {
            preheatVisibleMaterialImages()
        }
    }

    private var preheatToken: String {
        let ids = visibleItems.prefix(40).map(\.id).joined(separator: "|")
        return "\(selectedShelf.rawValue)-\(selectedCategoryID)-\(trimmedQuery)-\(ids)"
    }

    private var storeRows: [MaterialStoreRow] {
        storeRows(from: allGroups.flatMap(\.items))
    }

    @ViewBuilder
    private var materialContent: some View {
        if usesShelfRows {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(shelfRows) { row in
                    MaterialStoreShelfRow(row: row) { item in
                        onMaterial(item)
                    }
                }
            }
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(visibleItems) { item in
                    MaterialItemCard(item: item) {
                        onMaterial(item)
                    }
                }

                ForEach(visibleFallbackStickers) { sticker in
                    StickerChoiceCard(sticker: sticker) {
                        onSticker(sticker)
                    }
                }
            }
        }
    }

    private var storeSearchRow: some View {
        HStack(spacing: 10) {
            TrackedEditorToolButton(componentID: "material.panel.open-store", disabled: false, action: {
                showingStorePage = true
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "storefront")
                        .font(.system(size: 15, weight: .bold))
                    Text("Store")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.paper)
                .padding(.horizontal, 13)
                .frame(height: 48)
                .background(Color.clay)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            searchField
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.clay)

            TextField("Search", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)

            if !query.isEmpty {
                TrackedEditorToolButton(componentID: "material.panel.search.clear", disabled: false, action: {
                    query = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkSoft)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.bannerSoft, lineWidth: 1.5))
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryOptions) { category in
                    TrackedEditorToolButton(componentID: "material.panel.category.\(telemetryIDSegment(category.id))", disabled: false, action: {
                        selectedCategoryID = category.id
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            MaterialCategoryThumbnail(category: category, selected: selectedCategoryID == category.id)
                            if category.count > 0 && selectedCategoryID == category.id {
                                Text("\(category.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.clay)
                                    .padding(.horizontal, 6)
                                    .frame(height: 18)
                                    .background(Color.paper)
                                    .clipShape(Capsule())
                                    .offset(x: 5, y: 5)
                            }
                        }
                        .accessibilityLabel(category.title)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func previewURL(for id: String, items: [MaterialItem]) -> URL? {
        let sortedItems = items.sorted { lhs, rhs in
            lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }
        guard !sortedItems.isEmpty else { return nil }
        let seed = id.unicodeScalars.reduce(0) { partial, scalar in
            partial &+ Int(scalar.value)
        }
        return sortedItems[abs(seed) % sortedItems.count].fileURL
    }

    private func storeRows(from items: [MaterialItem]) -> [MaterialStoreRow] {
        let grouped = Dictionary(grouping: items, by: categoryID)
        return grouped.map { id, items -> MaterialStoreRow in
            let sortedItems = items.sorted(by: materialSort)
            let first = sortedItems[0]
            return MaterialStoreRow(
                id: id,
                title: categoryTitle(for: first),
                icon: categoryIcon(for: first),
                count: sortedItems.count,
                items: sortedItems
            )
        }
        .sorted { lhs, rhs in
            let lhsPriority = categoryPriority(lhs.id)
            let rhsPriority = categoryPriority(rhs.id)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func itemMatchesPrimaryTag(_ item: MaterialItem) -> Bool {
        switch selectedCategoryID {
        case "all":
            return true
        case "location":
            return isLocationItem(item)
        case "common":
            return isCommonItem(item)
        default:
            return categoryID(for: item) == selectedCategoryID
        }
    }

    private func isLocationItem(_ item: MaterialItem) -> Bool {
        let itemTokens = ([item.city, item.country, item.title, item.fileName] + item.tags).flatMap(\.locationTokens)
        return itemTokens.contains { locationTokens.contains($0) }
    }

    private func isCommonItem(_ item: MaterialItem) -> Bool {
        item.country.locationKey == "global" || item.tags.map(\.locationKey).contains("global") || categoryID(for: item).hasPrefix("cat-common")
    }

    private func preheatVisibleMaterialImages() {
        let urls = visibleItems.prefix(40).map(\.fileURL)
        Task.detached(priority: .utility) {
            await CanvasImageCache.shared.preheat(urls: urls, maxPixelSize: 360)
        }
    }

    private func materialKind(for item: MaterialItem) -> MaterialKind {
        let tokens = ([item.title, item.fileName] + item.tags).map { $0.lowercased() }
        return tokens.contains { $0.contains("tape") || $0.contains("washi") || $0.contains("胶带") } ? .tape : .sticker
    }

    private func categoryID(for item: MaterialItem) -> String {
        if materialKind(for: item) == .tape { return "tape" }
        if let category = item.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
            return "cat-\(category.lowercased())"
        }
        if !item.city.isEmpty && item.country.lowercased() != "global" { return "place-\(item.city.lowercased())" }
        return "basic"
    }

    private func categoryTitle(for item: MaterialItem) -> String {
        if materialKind(for: item) == .tape { return "Tape" }
        if let category = item.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
            return displayTitle(forCategory: category)
        }
        if !item.city.isEmpty && item.country.lowercased() != "global" { return displayTitle(forCategory: item.city) }
        return "Basic"
    }

    private func categoryIcon(for item: MaterialItem) -> String {
        if materialKind(for: item) == .tape { return "rectangle.on.rectangle.angled" }
        if let category = item.category?.lowercased(), !category.isEmpty {
            if category.contains("food") || category.contains("dim") { return "fork.knife" }
            if category.contains("park") || category.contains("nature") || category.contains("common") { return "leaf" }
            if category.contains("vintage") { return "camera.filters" }
            if category.contains("watercolor") { return "paintpalette" }
            if category.contains("line") { return "scribble" }
            return "square.grid.2x2"
        }
        if !item.city.isEmpty && item.country.lowercased() != "global" { return "mappin.and.ellipse" }
        return "sparkles"
    }

    private func categoryPriority(_ id: String) -> Int {
        if id == "tape" { return selectedShelf == .tapes ? 0 : 4 }
        if id == "basic" { return 3 }
        if id.hasPrefix("cat-common") { return 0 }
        if id.hasPrefix("cat-") { return 1 }
        if id.hasPrefix("place-") { return 2 }
        return 5
    }

    private func materialSort(_ lhs: MaterialItem, _ rhs: MaterialItem) -> Bool {
        if selectedShelf == .recommended || selectedShelf == .places {
            let lhsDistance = distanceInMeters(from: selectedCoordinate, to: lhs)
            let rhsDistance = distanceInMeters(from: selectedCoordinate, to: rhs)
            switch (lhsDistance, rhsDistance) {
            case let (.some(lhsDistance), .some(rhsDistance)):
                if abs(lhsDistance - rhsDistance) > 100 { return lhsDistance < rhsDistance }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
        }

        let lhsLocal = lhs.country.lowercased() != "global"
        let rhsLocal = rhs.country.lowercased() != "global"
        if lhsLocal != rhsLocal { return lhsLocal }
        let lhsGeo = lhs.latitude != nil && lhs.longitude != nil && lhs.latitude != 0 && lhs.longitude != 0
        let rhsGeo = rhs.latitude != nil && rhs.longitude != nil && rhs.latitude != 0 && rhs.longitude != 0
        if lhsGeo != rhsGeo { return lhsGeo }
        let lhsPriority = categoryPriority(categoryID(for: lhs))
        let rhsPriority = categoryPriority(categoryID(for: rhs))
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        let cityCompare = lhs.city.localizedCaseInsensitiveCompare(rhs.city)
        if cityCompare != .orderedSame { return cityCompare == .orderedAscending }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func rankedNearbyItems(from items: [MaterialItem]) -> [MaterialItem] {
        let coordinate = selectedCoordinate
        let withDistance = items.compactMap { item -> (MaterialItem, CLLocationDistance)? in
            guard let distance = distanceInMeters(from: coordinate, to: item) else { return nil }
            return (item, distance)
        }
        guard !withDistance.isEmpty else { return [] }
        return withDistance
            .sorted { lhs, rhs in
                if abs(lhs.1 - rhs.1) > 100 { return lhs.1 < rhs.1 }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }
            .map(\.0)
    }

    private func distanceInMeters(from coordinate: CLLocationCoordinate2D, to item: MaterialItem) -> CLLocationDistance? {
        guard let latitude = item.latitude,
              let longitude = item.longitude,
              latitude != 0 || longitude != 0 else { return nil }
        let start = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let end = CLLocation(latitude: latitude, longitude: longitude)
        return start.distance(from: end)
    }

    private func displayTitle(forCategory value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func itemMatchesSelectedShelf(_ item: MaterialItem) -> Bool {
        switch selectedShelf {
        case .recommended:
            return (!item.city.isEmpty && item.country.lowercased() != "global") || item.country.lowercased() == "global"
        case .places:
            return !item.city.isEmpty && item.country.lowercased() != "global"
        case .tapes:
            return materialKind(for: item) == .tape
        case .icons:
            return materialKind(for: item) != .tape
        case .all:
            return true
        }
    }
}

private enum MaterialKind {
    case sticker
    case tape
}

private enum MaterialShelf: String, CaseIterable, Identifiable {
    case recommended
    case places
    case tapes
    case icons
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: return "Store"
        case .places: return "Nearby"
        case .tapes: return "Tape"
        case .icons: return "DIY"
        case .all: return "All"
        }
    }

    var icon: String {
        switch self {
        case .recommended: return "storefront"
        case .places: return "target"
        case .tapes: return "rectangle.on.rectangle.angled"
        case .icons: return "scissors"
        case .all: return "square.grid.2x2"
        }
    }
}

private struct MaterialCategoryOption: Identifiable {
    let id: String
    let title: String
    let icon: String
    let count: Int
    let previewURL: URL?
    let showsLocationBadge: Bool
}

private struct MaterialCategoryThumbnail: View {
    let category: MaterialCategoryOption
    let selected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let previewURL = category.previewURL,
                   let image = CanvasImageCache.shared.image(at: previewURL, maxPixelSize: 160) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(selected ? Color.paper : Color.clay)
                }
            }
            .frame(width: 54, height: 42)
            .background(selected ? Color.clay.opacity(0.92) : Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Color.clay : Color.lineSoft, lineWidth: selected ? 2 : 1))

            if category.showsLocationBadge {
                Image(systemName: "location.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.paper)
                    .frame(width: 18, height: 18)
                    .background(Color.clay)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.paper, lineWidth: 1.4))
                    .offset(x: 5, y: -5)
            }
        }
    }
}

private struct MaterialStoreRow: Identifiable {
    let id: String
    let title: String
    let icon: String
    let count: Int
    let items: [MaterialItem]
}

private struct MaterialStorePage: View {
    let title: String
    let rows: [MaterialStoreRow]
    let fallbackStickers: [StickerDefinition]
    let onMaterial: (MaterialItem) -> Void
    let onSticker: (StickerDefinition) -> Void
    @State private var selectedCategoryID = "all"
    @State private var query = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var visibleRows: [MaterialStoreRow] {
        let categoryRows = selectedCategoryID == "all" ? rows : rows.filter { $0.id == selectedCategoryID }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else { return categoryRows }
        return categoryRows.compactMap { row in
            let matchingItems = row.items.filter { item in
                ([item.title, item.fileName, item.country, item.city] + item.tags)
                    .contains { $0.lowercased().contains(trimmedQuery) }
            }
            guard !matchingItems.isEmpty else { return nil }
            return MaterialStoreRow(
                id: row.id,
                title: row.title,
                icon: row.icon,
                count: matchingItems.count,
                items: matchingItems
            )
        }
    }

    private var categoryOptions: [MaterialCategoryOption] {
        let allItems = rows.flatMap(\.items)
        let all = MaterialCategoryOption(
            id: "all",
            title: "All",
            icon: "square.grid.2x2",
            count: allItems.count,
            previewURL: previewURL(for: "all", items: allItems),
            showsLocationBadge: false
        )
        let options = rows.map { row in
            MaterialCategoryOption(
                id: row.id,
                title: row.title,
                icon: row.icon,
                count: row.count,
                previewURL: previewURL(for: row.id, items: row.items),
                showsLocationBadge: row.id.hasPrefix("place-")
            )
        }
        return [all] + options
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                searchField

                if !rows.isEmpty {
                    categorySelector
                }

                ForEach(visibleRows) { row in
                    MaterialStoreShelfRow(row: row, onMaterial: onMaterial)
                }

                if visibleRows.isEmpty && !fallbackStickers.isEmpty {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(fallbackStickers) { sticker in
                            StickerChoiceCard(sticker: sticker) {
                                onSticker(sticker)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.clay)

            TextField("Search", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)

            if !query.isEmpty {
                TrackedEditorToolButton(componentID: "material.store.search.clear", disabled: false, action: {
                    query = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkSoft)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.bannerSoft, lineWidth: 1.5))
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryOptions) { category in
                    TrackedEditorToolButton(componentID: "material.store.category.\(telemetryIDSegment(category.id))", disabled: false, action: {
                        selectedCategoryID = category.id
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            MaterialCategoryThumbnail(category: category, selected: selectedCategoryID == category.id)
                            if category.count > 0 && selectedCategoryID == category.id {
                                Text("\(category.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.clay)
                                    .padding(.horizontal, 6)
                                    .frame(height: 18)
                                    .background(Color.paper)
                                    .clipShape(Capsule())
                                    .offset(x: 5, y: 5)
                            }
                        }
                        .accessibilityLabel(category.title)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func previewURL(for id: String, items: [MaterialItem]) -> URL? {
        let sortedItems = items.sorted { lhs, rhs in
            lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }
        guard !sortedItems.isEmpty else { return nil }
        let seed = id.unicodeScalars.reduce(0) { partial, scalar in
            partial &+ Int(scalar.value)
        }
        return sortedItems[abs(seed) % sortedItems.count].fileURL
    }
}

private struct MaterialItemCard: View {
    let item: MaterialItem
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.material.\(telemetryIDSegment(item.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = CanvasImageCache.shared.image(at: item.fileURL, maxPixelSize: 360) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 88)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.inkSoft)
                            .frame(height: 88)
                            .frame(maxWidth: .infinity)
                            .background(Color.paper)
                    }

                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.paper)
                        .frame(width: 26, height: 26)
                        .background(Color.clay)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.paper, lineWidth: 2))
                        .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(item.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text([item.city, item.country].filter { !$0.isEmpty }.joined(separator: " / "))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(7)
            .frame(maxWidth: .infinity)
            .frame(height: 142)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct MaterialStoreShelfRow: View {
    let row: MaterialStoreRow
    let onMaterial: (MaterialItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: row.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.clay)
                    .frame(width: 24, height: 24)
                    .background(Color.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1))

                Text(row.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)

                Text("\(row.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Color.paper.opacity(0.82))
                    .clipShape(Capsule())

                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(row.items.prefix(16)) { item in
                        MaterialStoreShelfItem(item: item) {
                            onMaterial(item)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct MaterialStoreShelfItem: View {
    let item: MaterialItem
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.material-shelf.\(telemetryIDSegment(item.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = CanvasImageCache.shared.image(at: item.fileURL, maxPixelSize: 320) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 92, height: 82)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.inkSoft)
                            .frame(width: 92, height: 82)
                    }

                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.paper)
                        .frame(width: 24, height: 24)
                        .background(Color.clay)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.paper, lineWidth: 2))
                        .offset(x: 5, y: 5)
                }
                .frame(width: 104, height: 94)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))

                Text(item.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .frame(width: 104, alignment: .leading)
            }
            .frame(width: 108, alignment: .leading)
        }
    }
}

private struct CanvasTemplatePreview: View {
    let template: PageTemplateDefinition
    let imageURL: (String?) -> URL?

    private let previewWidth: CGFloat = 132
    private var previewHeight: CGFloat {
        previewWidth * CanvasDocument.designCanvasSize.height / CanvasDocument.designCanvasSize.width
    }

    private var previewSize: CGSize {
        CGSize(width: previewWidth, height: previewHeight)
    }

    private var previewTransform: CanvasViewportTransform {
        CanvasViewportTransform(documentSize: CanvasDocument.designCanvasSize.cgSize, viewportSize: previewSize)
    }

    var body: some View {
        ZStack {
            CanvasSurface(background: template.background)
                .frame(width: previewWidth, height: previewHeight)

            ForEach(template.elements.sorted { $0.zIndex < $1.zIndex }) { element in
                CanvasElementView(element: previewTransform.displayElement(element), selected: false, imageURL: imageURL)
                    .rotationEffect(.degrees(element.rotation))
                    .position(previewTransform.displayPoint(CGPoint(x: element.x, y: element.y)))
                    .opacity(element.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewHeight)
    }
}

private struct StickerChoiceCard: View {
    let sticker: StickerDefinition
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.sticker.\(telemetryIDSegment(sticker.id))", disabled: false, action: action) {
            VStack(spacing: 9) {
                Image(systemName: sticker.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(hex: sticker.colorHex))
                    .frame(width: 78, height: 68)
                    .background(Color(hex: sticker.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(sticker.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct ShapeChoiceCard: View {
    let shape: ShapeDefinition
    let action: () -> Void

    private var previewElement: CanvasElement {
        CanvasElement(
            kind: .shape,
            symbol: shape.symbol,
            x: shape.width / 2,
            y: shape.height / 2,
            width: shape.width,
            height: shape.height,
            zIndex: 0,
            opacity: 0.9,
            colorHex: shape.colorHex,
            stroke: shape.stroke,
            cornerRadius: shape.cornerRadius
        )
    }

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.shape.\(telemetryIDSegment(shape.id))", disabled: false, action: action) {
            VStack(spacing: 9) {
                CanvasShapeElement(element: previewElement.displayScaled(by: 0.2))
                    .frame(width: 86, height: 68)

                Text(shape.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct BackgroundChoiceCard: View {
    let background: BackgroundDefinition
    let selected: Bool
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.background.\(telemetryIDSegment(background.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: background.colorA), Color(hex: background.colorB)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 96)
                    .overlay(GridPattern(spacing: 28).stroke(Color.editorGrid.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [5, 6])))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Color.clay : Color.lineSoft, lineWidth: selected ? 2.4 : 1.1))

                HStack {
                    Text(background.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.clay)
                    }
                }
            }
            .padding(10)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct TapeChoiceCard: View {
    let tape: TapeDefinition
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.tape.\(telemetryIDSegment(tape.id))", disabled: false, action: action) {
            VStack(spacing: 10) {
                TapeElement(color: Color(hex: tape.colorHex), imageURL: tape.fileURL)
                    .frame(height: 34)
                    .rotationEffect(.degrees(tape.rotation))
                    .padding(.horizontal, 6)

                Text(tape.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .padding(.horizontal, 10)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct TapePanel: View {
    let groups: [TapeGroup]
    let onTape: (TapeDefinition) -> Void
    @State private var selectedGroupID = "all"
    @State private var query = ""

    private var visibleGroups: [TapeGroup] {
        let categoryGroups = selectedGroupID == "all" ? groups : groups.filter { $0.id == selectedGroupID }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else { return categoryGroups }
        return categoryGroups.compactMap { group in
            let items = group.items.filter { tape in
                ([tape.title, tape.fileName ?? "", tape.groupID] + tape.tags)
                    .contains { $0.lowercased().contains(trimmedQuery) }
            }
            guard !items.isEmpty else { return nil }
            return TapeGroup(id: group.id, title: group.title, tags: group.tags, items: items)
        }
    }

    private var allCount: Int {
        groups.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            searchField

            if !groups.isEmpty {
                categorySelector
            }

            ForEach(visibleGroups) { group in
                TapeStoreShelfRow(group: group, onTape: onTape)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.clay)

            TextField("Search tape", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)

            if !query.isEmpty {
                TrackedEditorToolButton(componentID: "asset.tape.search.clear", disabled: false, action: {
                    query = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkSoft)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.bannerSoft, lineWidth: 1.5))
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TapeCategoryChip(
                    id: "all",
                    title: "All",
                    icon: "square.grid.2x2",
                    count: allCount,
                    previewTape: stablePreviewTape(for: "all", tapes: groups.flatMap(\.items)),
                    selected: selectedGroupID == "all"
                ) {
                    selectedGroupID = "all"
                }

                ForEach(groups) { group in
                    TapeCategoryChip(
                        id: group.id,
                        title: group.title,
                        icon: "rectangle.on.rectangle.angled",
                        count: group.items.count,
                        previewTape: stablePreviewTape(for: group.id, tapes: group.items),
                        selected: selectedGroupID == group.id
                    ) {
                        selectedGroupID = group.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func stablePreviewTape(for id: String, tapes: [TapeDefinition]) -> TapeDefinition? {
        let sortedTapes = tapes.sorted { lhs, rhs in
            lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }
        guard !sortedTapes.isEmpty else { return nil }
        let seed = id.unicodeScalars.reduce(0) { partial, scalar in
            partial &+ Int(scalar.value)
        }
        return sortedTapes[abs(seed) % sortedTapes.count]
    }
}

private struct TapeCategoryChip: View {
    let id: String
    let title: String
    let icon: String
    let count: Int
    let previewTape: TapeDefinition?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.tape.category.\(telemetryIDSegment(id))", disabled: false, action: action) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if let previewTape {
                        TapeElement(color: Color(hex: previewTape.colorHex), imageURL: previewTape.fileURL)
                            .frame(width: 44, height: 15)
                            .rotationEffect(.degrees(previewTape.rotation))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(selected ? Color.paper : Color.clay)
                    }
                }
                .frame(width: 54, height: 42)
                .background(selected ? Color.clay.opacity(0.92) : Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Color.clay : Color.lineSoft, lineWidth: selected ? 2 : 1))

                if selected {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.clay)
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(Color.paper)
                        .clipShape(Capsule())
                        .offset(x: 5, y: 5)
                }
            }
            .accessibilityLabel(title)
        }
    }
}

private struct TapeStoreShelfRow: View {
    let group: TapeGroup
    let onTape: (TapeDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.clay)
                    .frame(width: 24, height: 24)
                    .background(Color.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1))

                Text(group.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)

                Text("\(group.items.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Color.paper.opacity(0.82))
                    .clipShape(Capsule())

                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(group.items) { tape in
                        TapeStoreShelfItem(tape: tape) {
                            onTape(tape)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct TapeStoreShelfItem: View {
    let tape: TapeDefinition
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "asset.tape-shelf.\(telemetryIDSegment(tape.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    TapeElement(color: Color(hex: tape.colorHex), imageURL: tape.fileURL)
                        .frame(width: 136, height: 34)
                        .rotationEffect(.degrees(tape.rotation))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 18)

                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.paper)
                        .frame(width: 24, height: 24)
                        .background(Color.clay)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.paper, lineWidth: 2))
                        .offset(x: 5, y: 5)
                }
                .frame(width: 164, height: 76)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))

                Text(tape.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .frame(width: 164, alignment: .leading)
            }
            .frame(width: 168, alignment: .leading)
        }
    }
}

private struct EditorToolPanel<PhotoPicker: View>: View {
    let activePanel: EditorPanel
    @Binding var selectedShelf: EditorToolShelf
    let document: CanvasDocument?
    let selectedElementID: UUID?
    let selectedElementIDs: Set<UUID>
    let onSelect: (UUID?) -> Void
    let onSelectAll: () -> Void
    let onClearSelection: () -> Void
    let onTemplate: () -> Void
    let onText: () -> Void
    let onTextStyles: () -> Void
    let onLink: () -> Void
    let onFile: () -> Void
    let onTicket: () -> Void
    let onPaste: () -> Void
    let onConnector: () -> Void
    let onWordArt: () -> Void
    let onWordArtStyles: () -> Void
    let onEdit: () -> Void
    let onOpenObject: () -> Void
    let onShareObject: () -> Void
    let onNote: () -> Void
    let onEffect: () -> Void
    let onSticker: () -> Void
    let onShape: () -> Void
    let onBackground: () -> Void
    let onTape: () -> Void
    let onBrush: () -> Void
    let onDelete: () -> Void
    let onBringForward: () -> Void
    let onSendBackward: () -> Void
    let onBringToFront: () -> Void
    let onSendToBack: () -> Void
    let onToggleHidden: () -> Void
    let onToggleLocked: () -> Void
    let onOpacityDown: () -> Void
    let onOpacityUp: () -> Void
    let onCornerDown: () -> Void
    let onCornerUp: () -> Void
    let onToggleShadow: () -> Void
    let onToggleStroke: () -> Void
    let onLineWidthDown: () -> Void
    let onLineWidthUp: () -> Void
    let onSetLineWidth: (CGFloat) -> Void
    let onTapeLengthDown: () -> Void
    let onTapeLengthUp: () -> Void
    let onSetTapeLength: (CGFloat) -> Void
    let onColor: (String) -> Void
    let onAlign: (CanvasSelectionAlignment) -> Void
    let onAlignCanvas: (CanvasSelectionAlignment) -> Void
    let onDistribute: (CanvasDistributionAxis) -> Void
    let onArrangeGrid: () -> Void
    let onMatchSize: () -> Void
    let onApplyStyle: () -> Void
    let onDuplicate: () -> Void
    let onGroup: () -> Void
    let onUngroup: () -> Void
    let snapToGrid: Bool
    let onToggleSnap: () -> Void
    let activeCanvasTool: ActiveCanvasTool?
    let activeBrushTitle: String?
    let activeBrushColorHex: String
    let activeBrushWidth: CGFloat
    let activeBrushOpacity: Double
    let onBrushColor: (String) -> Void
    let onBrushWidth: (CGFloat) -> Void
    let onBrushOpacity: (Double) -> Void
    let onOpenBrushLibrary: () -> Void
    let onExitToolMode: () -> Void
    @ViewBuilder let photoPicker: () -> PhotoPicker

    private var selectedElement: CanvasElement? {
        document?.elements.first { $0.id == selectedElementID }
    }

    private var canAlign: Bool {
        selectedElementIDs.count > 1
    }

    private var hasSelection: Bool {
        !selectedElementIDs.isEmpty
    }

    private var canDistribute: Bool {
        selectedElementIDs.count > 2
    }

    private var canGroup: Bool {
        selectedElementIDs.count > 1
    }

    private var canUngroup: Bool {
        guard let document else { return false }
        return document.elements.contains { selectedElementIDs.contains($0.id) && $0.groupID != nil }
    }

    private var canEditSelectedElement: Bool {
        guard let selectedElement, selectedElementIDs.count == 1, !selectedElement.locked else { return false }
        return selectedElement.kind == .text || selectedElement.kind == .wordArt || selectedElement.kind == .link
    }

    private var canOpenSelectedObject: Bool {
        guard let selectedElement, selectedElementIDs.count == 1 else { return false }
        return selectedElement.kind.isPreviewableObject
    }

    private var canShareSelectedObject: Bool {
        guard let selectedElement, selectedElementIDs.count == 1 else { return false }
        return selectedElement.kind.isShareableAttachment
    }

    private var openObjectTitle: String {
        selectedElement?.kind == .link ? "Open" : "Preview"
    }

    private var openObjectIcon: String {
        selectedElement?.kind == .link ? "arrow.up.forward.app" : "doc.viewfinder"
    }

    private var canNoteSelectedElement: Bool {
        guard let selectedElement, selectedElementIDs.count == 1 else { return false }
        return !selectedElement.locked
    }

    private var canTuneLineWidth: Bool {
        guard let selectedElement, selectedElementIDs.count == 1, !selectedElement.locked else { return false }
        return selectedElement.kind == .connector ||
            selectedElement.kind == .brush ||
            (selectedElement.kind == .shape && (selectedElement.symbol == "line" || selectedElement.symbol == "arrow"))
    }

    private var canTuneShapeStyle: Bool {
        guard let selectedElement, selectedElementIDs.count == 1, !selectedElement.locked else { return false }
        return selectedElement.kind == .shape || selectedElement.kind == .connector || selectedElement.kind == .brush
    }

    private var canTuneTapeLength: Bool {
        guard let selectedElement, selectedElementIDs.count == 1, !selectedElement.locked else { return false }
        return selectedElement.kind == .tape
    }

    private var canTuneColor: Bool {
        guard let selectedElement, selectedElementIDs.count == 1, !selectedElement.locked else { return false }
        switch selectedElement.kind {
        case .image, .file, .video, .audio:
            return false
        default:
            return true
        }
    }

    private var colorOptions: [String] {
        ["#2E2824", "#B77255", "#C4563F", "#7AA08C", "#A9C0D2", "#D99A8C", "#6F9D86", "#D6A858", "#F2C078", "#9DB7D1"]
    }

    var body: some View {
        VStack(spacing: 0) {
            if activePanel == .multi {
                shelfTabs
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    toolShelfContent
                }
                .padding(.horizontal, 14)
                .padding(.top, activePanel == .multi ? 6 : 8)
                .padding(.bottom, 12)
            }
        }
        .frame(height: activePanel == .multi ? 124 : 90)
        .background(Color.editorPeach)
        .onChange(of: activePanel) { _, panel in
            if panel != .multi {
                selectedShelf = .add
            }
        }
        .onChange(of: selectedElementIDs) { _, ids in
            guard activePanel == .multi else { return }
            if ids.isEmpty {
                selectedShelf = .add
            } else if ids.count > 1 {
                selectedShelf = .arrange
            }
        }
    }

    @ViewBuilder
    private var toolShelfContent: some View {
        switch activePanel {
        case .multi:
            switch selectedShelf {
            case .add:
                addTools
            case .adjust:
                adjustTools
            case .arrange:
                arrangeTools
            case .object:
                objectTools
            }
        case .layer:
            layerTools
        case .effect:
            adjustTools
        case .tool:
            toolModeTools
        case .more:
            moreTools
        }
    }

    private var shelfTabs: some View {
        HStack(spacing: 8) {
            ForEach(EditorToolShelf.allCases) { shelf in
                TrackedEditorToolButton(
                    componentID: "editor.shelf.\(shelf.rawValue)",
                    disabled: false,
                    action: {
                    selectedShelf = shelf
                    }
                ) {
                    HStack(spacing: 5) {
                        Image(systemName: shelf.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(shelf.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selectedShelf == shelf ? Color.paper : Color.clay)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(selectedShelf == shelf ? Color.clay : Color.paper.opacity(0.72))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.lineSoft, lineWidth: selectedShelf == shelf ? 0 : 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var addTools: some View {
        photoPicker()
        toolButton("sparkles", "Materials", action: onSticker)
        toolButton("ticket", "Ticket", action: onTicket)
        toolButton("textformat", "Text", action: onText)
        toolButton("textformat.size", "Styles", action: onTextStyles)
        toolButton("rectangle.on.rectangle.angled", "Tape", action: onTape)
        toolButton("square.on.circle", "Shapes", action: onShape)
        toolButton("paintbrush.pointed", "Brush", action: onBrush)
        toolButton(selectedElementIDs.count == 2 ? "arrow.triangle.branch" : "arrow.right", selectedElementIDs.count == 2 ? "Connect" : "Arrow", action: onConnector)
    }

    @ViewBuilder
    private var toolModeTools: some View {
        CanvasToolStrip(
            activeTool: activeCanvasTool,
            brushTitle: activeBrushTitle,
            colorHex: activeBrushColorHex,
            width: activeBrushWidth,
            opacity: activeBrushOpacity,
            colorOptions: colorOptions,
            onColor: onBrushColor,
            onWidth: onBrushWidth,
            onOpacity: onBrushOpacity,
            onBrushLibrary: onOpenBrushLibrary,
            onDone: onExitToolMode
        )
    }

    @ViewBuilder
    private var adjustTools: some View {
        if canTuneLineWidth, let selectedElement {
            LineStyleToolStrip(
                element: selectedElement,
                colorOptions: colorOptions,
                onColor: onColor,
                onWidthDown: onLineWidthDown,
                onWidthUp: onLineWidthUp,
                onSetWidth: onSetLineWidth
            )
        }
        if canTuneTapeLength, let selectedElement {
            TapeLengthToolStrip(
                element: selectedElement,
                onLengthDown: onTapeLengthDown,
                onLengthUp: onTapeLengthUp,
                onSetLength: onSetTapeLength
            )
        }
        if canTuneColor {
            ForEach(colorOptions, id: \.self) { colorHex in
                colorButton(colorHex)
            }
        }
        toolButton("pencil", "Edit", disabled: !canEditSelectedElement, action: onEdit)
        effectButton("shadow", "Shadow", active: selectedElement?.shadow == true, action: onToggleShadow)
        effectButton("pencil.and.outline", "Stroke", active: selectedElement?.stroke == true, action: onToggleStroke)
        if canTuneShapeStyle, let selectedElement, !canTuneLineWidth {
            ShapeStyleToolStrip(
                element: selectedElement,
                onToggleStroke: onToggleStroke,
                onCornerDown: onCornerDown,
                onCornerUp: onCornerUp
            )
        }
        effectButton("minus.circle", "Opacity-", action: onOpacityDown)
        effectButton("plus.circle", "Opacity+", action: onOpacityUp)
        effectButton("rectangle.compress.vertical", "Corner-", action: onCornerDown)
        effectButton("rectangle.expand.vertical", "Corner+", action: onCornerUp)
    }

    @ViewBuilder
    private var arrangeTools: some View {
        toolButton("checklist.checked", "All", action: onSelectAll)
        toolButton("xmark.square", "Clear", disabled: selectedElementIDs.isEmpty, action: onClearSelection)
        alignButton("align.horizontal.left", "Left", .left)
        alignButton("align.horizontal.center", "Center", .centerX)
        alignButton("align.horizontal.right", "Right", .right)
        alignButton("align.vertical.top", "Top", .top)
        alignButton("align.vertical.center", "Middle", .centerY)
        alignButton("align.vertical.bottom", "Bottom", .bottom)
        canvasAlignButton("rectangle.leadinghalf.filled", "Page L", .left)
        canvasAlignButton("rectangle.center.inset.filled", "Page C", .centerX)
        canvasAlignButton("rectangle.trailinghalf.filled", "Page R", .right)
        canvasAlignButton("rectangle.tophalf.filled", "Page T", .top)
        canvasAlignButton("rectangle.center.inset.filled", "Page M", .centerY)
        canvasAlignButton("rectangle.bottomhalf.filled", "Page B", .bottom)
        distributeButton("distribute.horizontal.center", "Dist H", .horizontal)
        distributeButton("distribute.vertical.center", "Dist V", .vertical)
        toolButton("rectangle.grid.2x2", "Grid", disabled: !canAlign, action: onArrangeGrid)
        toolButton("rectangle.resize", "Match", disabled: !canAlign, action: onMatchSize)
        toolButton("eyedropper", "Style", disabled: !canAlign, action: onApplyStyle)
        toolButton(snapToGrid ? "grid.circle.fill" : "grid.circle", "Snap", active: snapToGrid, action: onToggleSnap)
    }

    @ViewBuilder
    private var objectTools: some View {
        toolButton(openObjectIcon, openObjectTitle, disabled: !canOpenSelectedObject, action: onOpenObject)
        toolButton("square.and.arrow.up", "Share", disabled: !canShareSelectedObject, action: onShareObject)
        toolButton(selectedElement?.note?.isEmpty == false ? "note.text" : "note.text.badge.plus", "Note", disabled: !canNoteSelectedElement, action: onNote)
        toolButton("plus.square.on.square", "Duplicate", disabled: !hasSelection, action: onDuplicate)
        toolButton("square.stack.3d.up", "Group", disabled: !canGroup, action: onGroup)
        toolButton("square.stack.3d.down.right", "Ungroup", disabled: !canUngroup, action: onUngroup)
        layerButton("arrow.up.square", "Forward", action: onBringForward)
        layerButton("arrow.down.square", "Backward", action: onSendBackward)
        layerButton("eye", selectedElement?.hidden == true ? "Show" : "Hide", action: onToggleHidden)
        layerButton(selectedElement?.locked == true ? "lock.open" : "lock", selectedElement?.locked == true ? "Unlock" : "Lock", action: onToggleLocked)
        toolButton("trash", "Delete", disabled: !hasSelection, action: onDelete)
    }

    @ViewBuilder
    private var layerTools: some View {
        if let document, !document.elements.isEmpty {
            ForEach(document.elements.sorted { $0.zIndex > $1.zIndex }) { element in
                LayerRow(element: element, selected: selectedElementID == element.id, onSelect: { onSelect(element.id) })
            }
        } else {
            EmptyLayerHint()
        }
        objectTools
    }

    @ViewBuilder
    private var moreTools: some View {
        toolButton(snapToGrid ? "grid.circle.fill" : "grid.circle", "Snap", active: snapToGrid, action: onToggleSnap)
        toolButton("square.grid.2x2", "Template", action: onTemplate)
        toolButton("paintpalette", "Background", action: onBackground)
        toolButton("textformat.size", "WordArt", action: onWordArt)
        toolButton("wand.and.stars", "ArtStyle", action: onWordArtStyles)
        toolButton("link", "Link", action: onLink)
        toolButton("doc.badge.plus", "File", action: onFile)
        toolButton("scribble.variable", "Stroke", action: onBrush)
        toolButton("paintpalette", "Palette", action: onBackground)
        toolButton("square.on.circle", "Shapes", action: onShape)
        toolButton("arrow.right", "Arrow", action: onConnector)
        toolButton("doc.on.clipboard", "Paste", action: onPaste)
        toolButton("rectangle.on.rectangle.angled", "Texture", action: onTape)
        toolButton("trash", "Delete", disabled: !hasSelection, action: onDelete)
    }

    private func layerButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        toolButton(icon, title, disabled: selectedElementID == nil, action: action)
    }

    private func toolButton(_ icon: String, _ title: String, disabled: Bool = false, active: Bool = false, action: @escaping () -> Void) -> some View {
        TrackedEditorToolButton(componentID: "editor.tool.\(normalizedComponentID(title))", disabled: disabled, action: action) {
            EditorToolItem(icon: icon, title: title, disabled: disabled, active: active)
        }
    }

    private func effectButton(_ icon: String, _ title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        let disabled = selectedElementID == nil
        return TrackedEditorToolButton(componentID: "editor.effect.\(normalizedComponentID(title))", disabled: disabled, action: action) {
            EditorToolItem(icon: icon, title: title, disabled: disabled, active: active)
        }
    }

    private func colorButton(_ colorHex: String) -> some View {
        TrackedEditorToolButton(componentID: "editor.color.\(colorHex.replacingOccurrences(of: "#", with: ""))", disabled: !hasSelection, action: { onColor(colorHex) }) {
            EditorColorToolItem(
                colorHex: colorHex,
                selected: selectedElement?.colorHex == colorHex,
                disabled: !hasSelection
            )
        }
    }

    private func alignButton(_ icon: String, _ title: String, _ alignment: CanvasSelectionAlignment) -> some View {
        TrackedEditorToolButton(componentID: "editor.align.selection.\(normalizedComponentID(title))", disabled: !canAlign, action: { onAlign(alignment) }) {
            EditorToolItem(icon: icon, title: title, disabled: !canAlign)
        }
    }

    private func canvasAlignButton(_ icon: String, _ title: String, _ alignment: CanvasSelectionAlignment) -> some View {
        TrackedEditorToolButton(componentID: "editor.align.canvas.\(normalizedComponentID(title))", disabled: !hasSelection, action: { onAlignCanvas(alignment) }) {
            EditorToolItem(icon: icon, title: title, disabled: !hasSelection)
        }
    }

    private func distributeButton(_ icon: String, _ title: String, _ axis: CanvasDistributionAxis) -> some View {
        TrackedEditorToolButton(componentID: "editor.distribute.\(normalizedComponentID(title))", disabled: !canDistribute, action: { onDistribute(axis) }) {
            EditorToolItem(icon: icon, title: title, disabled: !canDistribute)
        }
    }

    private func normalizedComponentID(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: "+", with: "plus")
            .replacingOccurrences(of: "-", with: "minus")
            .replacingOccurrences(of: " ", with: "-")
    }
}

private struct EditorToolItem: View {
    let icon: String
    let title: String
    var disabled = false
    var active = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(disabled ? Color.clay.opacity(0.28) : (active ? Color.paper : Color.clay))
                .frame(width: 48, height: 38)
                .background(active ? Color.clay : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(disabled ? Color.clay.opacity(0.28) : Color.clay)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 66)
        }
        .frame(width: 66, height: 68)
    }
}

private struct EditorColorToolItem: View {
    let colorHex: String
    let selected: Bool
    let disabled: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(selected ? Color.clay : Color.lineSoft, lineWidth: selected ? 3 : 1))
                .opacity(disabled ? 0.35 : 1)
                .frame(width: 48, height: 38)

            Text("Color")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(disabled ? Color.clay.opacity(0.28) : Color.clay)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 66)
        }
        .frame(width: 66, height: 68)
    }
}

private struct CanvasToolStrip: View {
    let activeTool: ActiveCanvasTool?
    let brushTitle: String?
    let colorHex: String
    let width: CGFloat
    let opacity: Double
    let colorOptions: [String]
    let onColor: (String) -> Void
    let onWidth: (CGFloat) -> Void
    let onOpacity: (Double) -> Void
    let onBrushLibrary: () -> Void
    let onDone: () -> Void

    private var title: String {
        switch activeTool {
        case .brush:
            return brushTitle ?? "Brush"
        case .arrow:
            return "Arrow"
        case nil:
            return "Tool"
        }
    }

    private var icon: String {
        activeTool == .arrow ? "arrow.right" : "paintbrush.pointed.fill"
    }

    private var widthRange: ClosedRange<CGFloat> {
        activeTool == .arrow ? 6...48 : 4...140
    }

    var body: some View {
        HStack(spacing: 10) {
            TrackedEditorToolButton(componentID: "canvas.toolstrip.done", disabled: false, action: onDone) {
                EditorToolItem(icon: "checkmark.circle.fill", title: "Done", active: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.ink)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color(hex: colorHex))
                    .frame(width: 86, height: max(5, min(width * 0.36, 24)))
                    .frame(height: 28, alignment: .center)
            }
            .frame(width: 98, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(colorOptions.prefix(6), id: \.self) { option in
                    TrackedEditorToolButton(componentID: "canvas.toolstrip.color.\(option.replacingOccurrences(of: "#", with: ""))", disabled: false, action: { onColor(option) }) {
                        Circle()
                            .fill(Color(hex: option))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(colorHex == option ? Color.clay : Color.paper, lineWidth: colorHex == option ? 3 : 2))
                    }
                }
            }

            Slider(value: Binding(get: { min(max(width, widthRange.lowerBound), widthRange.upperBound) }, set: onWidth), in: widthRange, step: 1)
                .frame(width: 96)

            if activeTool == .brush {
                Slider(value: Binding(get: { opacity }, set: onOpacity), in: 0.12...1, step: 0.02)
                    .frame(width: 72)

                TrackedEditorToolButton(componentID: "canvas.toolstrip.brush-library", disabled: false, action: onBrushLibrary) {
                    EditorToolItem(icon: "paintbrush.pointed", title: "Brushes")
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Color.paper.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
    }
}

private struct LineStyleToolStrip: View {
    let element: CanvasElement
    let colorOptions: [String]
    let onColor: (String) -> Void
    let onWidthDown: () -> Void
    let onWidthUp: () -> Void
    let onSetWidth: (CGFloat) -> Void

    private var widthLabel: String {
        "\(Int(element.brushWidth.rounded()))"
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: element.kind == .connector ? "arrow.right" : "line.diagonal")
                        .font(.system(size: 12, weight: .bold))
                    Text(element.kind == .connector ? "Arrow" : "Line")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.ink)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color(hex: element.colorHex))
                    .frame(width: 76, height: max(4, min(element.brushWidth * 0.36, 22)))
                    .frame(height: 24, alignment: .center)
            }
            .frame(width: 88, alignment: .leading)

            HStack(spacing: 6) {
                styleButton("minus", action: onWidthDown)

                Text(widthLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .frame(width: 34, height: 34)
                    .background(Color.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1))

                styleButton("plus", action: onWidthUp)
            }

            Slider(
                value: Binding(
                    get: { min(max(element.brushWidth, 4), 140) },
                    set: { onSetWidth($0) }
                ),
                in: 4...140,
                step: 1
            )
            .frame(width: 112)

            HStack(spacing: 6) {
                ForEach(colorOptions.prefix(5), id: \.self) { colorHex in
                    TrackedEditorToolButton(componentID: "canvas.line.color.\(colorHex.replacingOccurrences(of: "#", with: ""))", disabled: false, action: { onColor(colorHex) }) {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 25, height: 25)
                            .overlay(Circle().stroke(element.colorHex == colorHex ? Color.clay : Color.paper, lineWidth: element.colorHex == colorHex ? 3 : 2))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Color.paper.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
    }

    private func styleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        TrackedEditorToolButton(componentID: "canvas.line.width.\(telemetryIDSegment(icon))", disabled: false, action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.paper)
                .frame(width: 34, height: 34)
                .background(Color.clay)
                .clipShape(Circle())
        }
    }
}

private struct TapeLengthToolStrip: View {
    let element: CanvasElement
    let onLengthDown: () -> Void
    let onLengthUp: () -> Void
    let onSetLength: (CGFloat) -> Void

    private var lengthLabel: String {
        "\(Int(element.width.rounded()))"
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("Length")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.ink)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(hex: element.colorHex).opacity(0.76))
                    .frame(width: min(max(element.width * 0.16, 42), 94), height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.paper.opacity(0.75), lineWidth: 1.2))
            }
            .frame(width: 88, alignment: .leading)

            HStack(spacing: 6) {
                styleButton("minus", action: onLengthDown)

                Text(lengthLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 34)
                    .background(Color.paper)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1))

                styleButton("plus", action: onLengthUp)
            }

            Slider(
                value: Binding(
                    get: { min(max(element.width, 90), 1460) },
                    set: { onSetLength($0) }
                ),
                in: 90...1460,
                step: 5
            )
            .frame(width: 142)
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Color.paper.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
    }

    private func styleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        TrackedEditorToolButton(componentID: "canvas.tape.length.\(telemetryIDSegment(icon))", disabled: false, action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.paper)
                .frame(width: 34, height: 34)
                .background(Color.clay)
                .clipShape(Circle())
        }
    }
}

private struct ShapeStyleToolStrip: View {
    let element: CanvasElement
    let onToggleStroke: () -> Void
    let onCornerDown: () -> Void
    let onCornerUp: () -> Void

    private var styleTitle: String {
        switch element.symbol {
        case "arrow": return "Arrow"
        case "line": return "Line"
        default: return "Shape"
        }
    }

    private var cornerDisabled: Bool {
        element.symbol == "arrow" || element.symbol == "line"
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: element.symbol == "arrow" ? "arrow.right" : "square.on.circle")
                        .font(.system(size: 12, weight: .bold))
                    Text(styleTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.ink)

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: min(max(element.cornerRadius * 0.16, 2), 10), style: .continuous)
                        .fill(element.stroke ? Color.clear : Color(hex: element.colorHex))
                        .overlay(RoundedRectangle(cornerRadius: min(max(element.cornerRadius * 0.16, 2), 10), style: .continuous).stroke(Color(hex: element.colorHex), lineWidth: element.stroke ? 2.4 : 0))
                        .frame(width: 32, height: 22)

                    Text(element.stroke ? "Outline" : "Fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                }
            }
            .frame(width: 88, alignment: .leading)

            TrackedEditorToolButton(componentID: "canvas.shape.stroke-toggle", disabled: false, action: onToggleStroke) {
                EditorToolItem(icon: element.stroke ? "square" : "square.fill", title: element.stroke ? "Fill" : "Stroke", active: element.stroke)
            }

            TrackedEditorToolButton(componentID: "canvas.shape.corner-down", disabled: cornerDisabled, action: onCornerDown) {
                EditorToolItem(icon: "minus", title: "Corner-", disabled: cornerDisabled)
            }

            TrackedEditorToolButton(componentID: "canvas.shape.corner-up", disabled: cornerDisabled, action: onCornerUp) {
                EditorToolItem(icon: "plus", title: "Corner+", disabled: cornerDisabled)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Color.paper.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
    }
}

private struct EmptyLayerHint: View {
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.clay.opacity(0.48))
                .frame(width: 48, height: 38)

            Text("No layer")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.clay.opacity(0.55))
                .lineLimit(1)
                .frame(width: 70)
        }
        .frame(width: 70, height: 68)
    }
}

private struct LayerRow: View {
    let element: CanvasElement
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "canvas.layer.\(element.id.uuidString.lowercased())", disabled: false, action: onSelect) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Color.clay.opacity(0.18) : Color.paper.opacity(0.62))
                        .frame(width: 58, height: 38)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(selected ? Color.clay : Color.lineSoft, lineWidth: 1.4))

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(element.hidden ? Color.clay.opacity(0.28) : Color.clay)

                    if element.locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.clay)
                            .offset(x: 19, y: -11)
                    }

                    if element.note?.isEmpty == false {
                        Image(systemName: "note.text")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.clay)
                            .offset(x: -19, y: -11)
                    }
                }

                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.clay)
                    .lineLimit(1)
                    .frame(width: 64)
            }
            .frame(width: 66, height: 68)
        }
    }

    private var icon: String {
        switch element.kind {
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .audio: return "waveform"
        case .sticker: return element.symbol ?? "sparkles"
        case .text: return "textformat"
        case .tape: return "rectangle.on.rectangle.angled"
        case .brush: return "paintbrush.pointed"
        case .shape: return "square.on.circle"
        case .wordArt: return "textformat.size"
        case .link: return "link"
        case .file: return "doc"
        case .connector: return "arrow.right"
        }
    }

    private var title: String {
        switch element.kind {
        case .text, .wordArt:
            return element.text?.isEmpty == false ? String(element.text!.prefix(8)) : element.kind.rawValue
        case .link:
            return element.text?.isEmpty == false ? String(element.text!.prefix(8)) : "link"
        case .file, .video, .audio:
            return element.text?.isEmpty == false ? String(element.text!.prefix(8)) : element.kind.rawValue
        default:
            return element.kind.rawValue
        }
    }
}

private struct LinkInputSheet: View {
    @Binding var link: LinkCardParameters
    let onConfirm: () -> String?
    @FocusState private var focused: Bool
    @State private var validationMessage = ""
    private let colorOptions = ["#2E2824", "#B77255", "#C4563F", "#7AA08C", "#A9C0D2", "#D99A8C"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Link")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)

                TextField("Travel guide", text: $link.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)

                TextField("https://example.com", text: $link.url)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
                    .onChange(of: link.url) { _, _ in
                        validationMessage = ""
                    }
            }

            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.red)
            }

            HStack(spacing: 10) {
                ForEach(colorOptions, id: \.self) { colorHex in
                    TrackedEditorToolButton(componentID: "sheet.link.color.\(colorHex.replacingOccurrences(of: "#", with: ""))", disabled: false, action: {
                        link.colorHex = colorHex
                    }) {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(link.colorHex == colorHex ? Color.clay : Color.lineSoft, lineWidth: link.colorHex == colorHex ? 3 : 1))
                    }
                }
            }

            HStack {
                TrackedEditorToolButton(componentID: "sheet.link.clear", disabled: false, action: {
                    link = LinkCardParameters()
                }) {
                    Text("Clear")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                }

                Spacer()

                TrackedEditorToolButton(componentID: "sheet.link.confirm", disabled: false, action: {
                    validationMessage = onConfirm() ?? ""
                }) {
                    Text("Add Link")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.paper)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(Color.clay)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(22)
        .background(Color.background)
        .onAppear {
            focused = true
        }
    }
}

private struct ElementNoteSheet: View {
    @Binding var note: String
    let onConfirm: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Note")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)

            TextEditor(text: $note)
                .focused($focused)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 132)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

            HStack {
                TrackedEditorToolButton(componentID: "sheet.note.clear", disabled: false, action: {
                    note = ""
                }) {
                    Text("Clear")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                }

                Spacer()

                TrackedEditorToolButton(componentID: "sheet.note.confirm", disabled: false, action: onConfirm) {
                    Text("Save Note")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.paper)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(Color.clay)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(22)
        .background(Color.background)
        .onAppear {
            focused = true
        }
    }
}

private struct TicketComposerSheet: View {
    @ObservedObject var repository: NotebookRepository
    let onAdd: (UIImage) -> String?
    let onCancel: () -> Void
    @State private var selectedKind: TicketKind
    @State private var selectedTemplateID: String
    @State private var fields: TicketFields
    @State private var errorMessage: String?

    private var templates: [TicketTemplateDefinition] {
        repository.ticketTemplates
    }

    private var availableKinds: [TicketKind] {
        TicketKind.allCases.filter { kind in
            templates.contains { $0.kind == kind }
        }
    }

    private var styleTemplates: [TicketTemplateDefinition] {
        let matching = templates.filter { $0.kind == selectedKind }
        return matching.isEmpty ? templates : matching
    }

    private var fallbackTemplate: TicketTemplateDefinition {
        TicketTemplateDefinition(
            id: "rail-vintage",
            kind: .train,
            title: "Vintage Rail",
            headline: "RAIL PASSAGE TICKET",
            accentHex: "#B44D35",
            paperHex: "#F9F1E4",
            fields: fields
        )
    }

    private var selectedTemplate: TicketTemplateDefinition {
        templates.first { $0.id == selectedTemplateID } ?? templates.first ?? fallbackTemplate
    }

    private var previewImage: UIImage {
        TicketRenderer.render(template: selectedTemplate, fields: fields, scale: 0.34)
    }

    init(repository: NotebookRepository, onAdd: @escaping (UIImage) -> String?, onCancel: @escaping () -> Void) {
        self.repository = repository
        self.onAdd = onAdd
        self.onCancel = onCancel
        let template = repository.ticketTemplates.first ?? TicketTemplateDefinition(
            id: "rail-vintage",
            kind: .train,
            title: "Vintage Rail",
            headline: "RAIL PASSAGE TICKET",
            accentHex: "#B44D35",
            paperHex: "#F9F1E4",
            fields: TicketFields(
                origin: "SHANGHAI",
                destination: "HANGZHOU",
                date: "22 MAY 2026",
                time: "08:45",
                seat: "CAR 03 / 12A",
                gate: "7B",
                className: "SECOND",
                reference: "NO. A12-045"
            )
        )
        _selectedTemplateID = State(initialValue: template.id)
        _selectedKind = State(initialValue: template.kind)
        _fields = State(initialValue: template.fields)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
                        .shadow(color: Color.shadowSoft, radius: 8, x: 0, y: 5)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableKinds, id: \.self) { kind in
                                TrackedEditorToolButton(componentID: "sheet.ticket.kind.\(telemetryIDSegment(kind.rawValue))", disabled: false, action: {
                                    selectedKind = kind
                                    if let template = templates.first(where: { $0.kind == kind }) {
                                        selectedTemplateID = template.id
                                        fields = template.fields
                                    }
                                    errorMessage = nil
                                }) {
                                    HStack(spacing: 7) {
                                        Image(systemName: icon(for: kind))
                                            .font(.system(size: 13, weight: .bold))
                                        Text(kind.label)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(selectedKind == kind ? Color.paper : Color.clay)
                                    .padding(.horizontal, 13)
                                    .frame(height: 36)
                                    .background(selectedKind == kind ? Color.clay : Color.paper)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.lineSoft, lineWidth: selectedKind == kind ? 0 : 1))
                                }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(styleTemplates) { template in
                                TrackedEditorToolButton(componentID: "sheet.ticket.template.\(telemetryIDSegment(template.id))", disabled: false, action: {
                                    selectedTemplateID = template.id
                                    selectedKind = template.kind
                                    fields = template.fields
                                    errorMessage = nil
                                }) {
                                    Text(template.title)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .lineLimit(1)
                                    .foregroundStyle(selectedTemplateID == template.id ? Color.paper : Color.clay)
                                    .padding(.horizontal, 13)
                                    .frame(height: 36)
                                    .background(selectedTemplateID == template.id ? Color.clay : Color.paper)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.lineSoft, lineWidth: selectedTemplateID == template.id ? 0 : 1))
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        ticketFields(for: selectedTemplate.kind)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.red)
                    }
                }
                .padding(18)
            }
            .background(Color.background)
            .navigationTitle("Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    TrackedEditorToolButton(componentID: "sheet.ticket.cancel", disabled: false, action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    TrackedEditorToolButton(componentID: "sheet.ticket.add", disabled: false, action: {
                        let image = TicketRenderer.render(template: selectedTemplate, fields: fields)
                        errorMessage = onAdd(image)
                    }) {
                        Text("Add")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.clay)
                    }
                }
            }
        }
    }

    private func ticketField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.inkSoft)
            TextField(title, text: text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.characters)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }

    @ViewBuilder
    private func ticketFields(for kind: TicketKind) -> some View {
        switch kind {
        case .movie:
            ticketField("Cinema", text: $fields.origin)
            ticketField("Movie", text: $fields.destination)
            HStack(spacing: 10) {
                ticketField("Date", text: $fields.date)
                ticketField("Time", text: $fields.time)
            }
            HStack(spacing: 10) {
                ticketField("Seat", text: $fields.seat)
                ticketField("Hall", text: $fields.gate)
            }
            HStack(spacing: 10) {
                ticketField("Type", text: $fields.className)
                ticketField("Ref", text: $fields.reference)
            }
        case .event:
            ticketField("Venue", text: $fields.origin)
            ticketField("Event", text: $fields.destination)
            HStack(spacing: 10) {
                ticketField("Date", text: $fields.date)
                ticketField("Time", text: $fields.time)
            }
            HStack(spacing: 10) {
                ticketField("Seat", text: $fields.seat)
                ticketField("Entry", text: $fields.gate)
            }
            HStack(spacing: 10) {
                ticketField("Pass", text: $fields.className)
                ticketField("Ref", text: $fields.reference)
            }
        default:
            ticketField("From", text: $fields.origin)
            ticketField("To", text: $fields.destination)
            HStack(spacing: 10) {
                ticketField("Date", text: $fields.date)
                ticketField("Time", text: $fields.time)
            }
            HStack(spacing: 10) {
                ticketField("Seat", text: $fields.seat)
                ticketField(gateTitle(for: kind), text: $fields.gate)
            }
            HStack(spacing: 10) {
                ticketField(classTitle(for: kind), text: $fields.className)
                ticketField("Ref", text: $fields.reference)
            }
        }
    }

    private func icon(for kind: TicketKind) -> String {
        switch kind {
        case .flight: return "airplane"
        case .train: return "tram.fill"
        case .ferry: return "ferry.fill"
        case .movie: return "popcorn.fill"
        case .event: return "ticket.fill"
        }
    }

    private func gateTitle(for kind: TicketKind) -> String {
        switch kind {
        case .flight: return "Gate"
        case .train: return "Platform"
        case .ferry: return "Pier"
        case .movie: return "Hall"
        case .event: return "Entry"
        }
    }

    private func classTitle(for kind: TicketKind) -> String {
        kind == .movie ? "Type" : "Class"
    }
}

private struct TextInputSheet: View {
    @Binding var text: String
    @Binding var style: TextStyleParameters
    let mode: TextInsertMode
    let onConfirm: () -> String?
    @FocusState private var focused: Bool
    @StateObject private var fontLibrary = FontLibrary()
    @State private var fontStatus = ""
    @State private var validationMessage = ""
    @State private var previewImage: UIImage?
    private let systemFontOptions = ["Georgia", "Avenir Next", "Courier New", "Menlo", "Didot", "Papyrus", "Snell Roundhand", "Gill Sans", "Palatino", "Charter"]
    private let googleFontOptions = ["Roboto", "Open Sans", "Montserrat", "Merriweather", "Playfair Display", "Dancing Script", "Pacifico"]
    private let colorOptions = ["#2E2824", "#C4563F", "#7AA08C", "#A9C0D2", "#B77255", "#111827"]
    private var allFontOptions: [String] {
        systemFontOptions + googleFontOptions
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode == .wordArt ? "WordArt" : "Text")
                            .font(.system(size: 25, weight: .bold, design: .serif))
                            .foregroundStyle(Color.ink)

                        Text(style.fontName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer()

                    TrackedEditorToolButton(componentID: "sheet.text.confirm", disabled: false, action: {
                        validationMessage = onConfirm() ?? ""
                    }) {
                        Text(mode == .wordArt ? "Add" : "Done")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.paper)
                            .padding(.horizontal, 18)
                            .frame(height: 38)
                            .background(Color.clay)
                            .clipShape(Capsule())
                    }
                }

                TextRenderPreview(image: previewImage)
                    .onAppear {
                        refreshPreview()
                    }
                    .onChange(of: text) { _, _ in
                        refreshPreview()
                    }
                    .onChange(of: style.fontName) { _, _ in
                        refreshPreview()
                    }
                    .onChange(of: style.fontSize) { _, _ in
                        refreshPreview()
                    }
                    .onChange(of: style.colorHex) { _, _ in
                        refreshPreview()
                    }
                    .onChange(of: style.bold) { _, _ in
                        refreshPreview()
                    }
                    .onChange(of: style.italic) { _, _ in
                        refreshPreview()
                    }
                    .onChange(of: style.alignment) { _, _ in
                        refreshPreview()
                    }
                    .onChange(of: style.width) { _, _ in
                        refreshPreview()
                    }

                TextEditor(text: $text)
                    .focused($focused)
                    .font(FontResolver.swiftUIFont(name: style.fontName, size: 20, bold: style.bold, italic: style.italic))
                    .foregroundStyle(Color(hex: style.colorHex))
                    .multilineTextAlignment(style.alignment == "leading" ? .leading : (style.alignment == "trailing" ? .trailing : .center))
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .frame(height: 148)
                    .background(Color.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
                    .onChange(of: text) { _, _ in
                        validationMessage = ""
                    }

                if !validationMessage.isEmpty {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.red)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Font", systemImage: "textformat")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)

                        Spacer()

                        Picker("Font", selection: $style.fontName) {
                            Section("System") {
                                ForEach(systemFontOptions, id: \.self) { font in
                                    Text(font)
                                        .font(FontResolver.swiftUIFont(name: font, size: 18, bold: false, italic: false))
                                        .tag(font)
                                }
                            }

                            Section("Google Fonts") {
                                ForEach(googleFontOptions, id: \.self) { font in
                                    Text(font)
                                        .font(FontResolver.swiftUIFont(name: fontLibrary.resolvedName(for: font), size: 18, bold: false, italic: false))
                                        .tag(font)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: style.fontName) { _, font in
                            loadGoogleFontIfNeeded(font)
                        }
                    }

                    if !fontStatus.isEmpty {
                        Text(fontStatus)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                .padding(14)
                .background(Color.paper.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))

                VStack(spacing: 12) {
                    sliderRow(title: "Size", value: $style.fontSize, range: 32...160, step: 2)
                    sliderRow(title: "Width", value: $style.width, range: 360...920, step: 20)
                }
                .padding(14)
                .background(Color.paper.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))

                HStack(spacing: 10) {
                    Toggle("B", isOn: $style.bold)
                        .toggleStyle(.button)
                    Toggle("I", isOn: $style.italic)
                        .toggleStyle(.button)

                    Picker("Align", selection: $style.alignment) {
                        Image(systemName: "text.alignleft").tag("leading")
                        Image(systemName: "text.aligncenter").tag("center")
                        Image(systemName: "text.alignright").tag("trailing")
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.self) { colorHex in
                        TrackedEditorToolButton(componentID: "sheet.text.color.\(colorHex.replacingOccurrences(of: "#", with: ""))", disabled: false, action: {
                            style.colorHex = colorHex
                        }) {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 31, height: 31)
                                .overlay(Circle().stroke(style.colorHex == colorHex ? Color.clay : Color.lineSoft, lineWidth: style.colorHex == colorHex ? 3 : 1))
                        }
                    }
                }

                HStack {
                    TrackedEditorToolButton(componentID: "sheet.text.clear", disabled: false, action: {
                        text = ""
                    }) {
                        Text("Clear")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                    }

                    Spacer()
                }
            }
            .padding(22)
        }
        .background(Color.background)
        .onAppear {
            focused = true
            style.text = text
            fontLibrary.bootstrap()
            loadGoogleFontIfNeeded(style.fontName)
            refreshPreview()
        }
    }

    private func refreshPreview() {
        var previewStyle = style
        previewStyle.text = text
        previewImage = TextRenderService.sampleImage(text: text, style: previewStyle, scale: 2)
    }

    private func sliderRow(title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)
                .frame(width: 44, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func loadGoogleFontIfNeeded(_ font: String) {
        guard googleFontOptions.contains(font) else {
            fontStatus = ""
            return
        }

        fontStatus = fontLibrary.isAvailable(font) ? "Google Font cached" : "Loading Google Font..."
        Task {
            do {
                _ = try await fontLibrary.loadGoogleFont(named: font)
                await MainActor.run {
                    fontStatus = "Google Font ready"
                    refreshPreview()
                }
            } catch {
                await MainActor.run {
                    fontStatus = "Font download failed, using fallback"
                }
            }
        }
    }
}

private struct TextRenderPreview: View {
    let image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                Text("Render sample")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Text("transparent PNG")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
            }
            .foregroundStyle(Color.ink)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.paper)
                CheckerboardPattern()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                } else {
                    Text("Sample text")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(Color.inkSoft)
                }
            }
            .frame(height: 118)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
        .padding(14)
        .background(Color.paper.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
    }
}

private struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 14
            let rows = Int(ceil(size.height / tile))
            let columns = Int(ceil(size.width / tile))
            for row in 0...rows {
                for column in 0...columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(Color.inkSoft.opacity(0.055)))
                }
            }
        }
    }
}

private struct RenamePageSheet: View {
    @Binding var title: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Page")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)

            TextField("Page title", text: $title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

            HStack {
                TrackedEditorToolButton(componentID: "sheet.rename.cancel", disabled: false, action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                }

                Spacer()

                TrackedEditorToolButton(componentID: "sheet.rename.save", disabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, action: onConfirm) {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.paper)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.inkSoft : Color.clay)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(22)
        .background(Color.background)
    }
}

private struct NewPageSheet: View {
    let onNewPage: () -> Void
    let onTemplate: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            PageCreateOption(
                title: "New Page",
                icon: "square",
                tint: .sand,
                action: onNewPage
            )

            PageCreateOption(
                title: "Template",
                icon: "doc.text",
                tint: .sage,
                action: onTemplate
            )
        }
        .padding(18)
        .background(Color.background)
    }
}

private struct PageCreateOption: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "sheet.new-page.\(telemetryIDSegment(title))", disabled: false, action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .padding(.horizontal, 8)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
        }
    }
}

private struct NotebookEditSheet: View {
    let notebook: TravelNotebook
    let canDelete: Bool
    let onCancel: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    @State private var title: String

    init(
        notebook: TravelNotebook,
        canDelete: Bool,
        onCancel: @escaping () -> Void,
        onRename: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.notebook = notebook
        self.canDelete = canDelete
        self.onCancel = onCancel
        self.onRename = onRename
        self.onDelete = onDelete
        _title = State(initialValue: notebook.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Edit Notebook")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)

                Spacer()

                TrackedEditorToolButton(componentID: "sheet.notebook-edit.cancel", disabled: false, action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 36, height: 36)
                        .background(Color.paper)
                        .clipShape(Circle())
                }
            }

            TextField("Notebook name", text: $title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

            TrackedEditorToolButton(componentID: "sheet.notebook-edit.save", disabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, action: {
                onRename(title)
            }) {
                Label("Save name", systemImage: "checkmark")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.paper)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.inkSoft : Color.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            TrackedEditorToolButton(componentID: "sheet.notebook-edit.delete", disabled: !canDelete, action: onDelete) {
                Label(canDelete ? "Delete notebook" : "Keep at least one notebook", systemImage: "trash")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(canDelete ? Color.red : Color.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.background.ignoresSafeArea())
    }
}

private struct NotebookPickerSheet: View {
    @ObservedObject var repository: NotebookRepository
    let currentNotebookID: UUID?
    let onSelect: (UUID) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Save to Notebook")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)

                Spacer()

                TrackedEditorToolButton(componentID: "sheet.notebook-picker.cancel", disabled: false, action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 36, height: 36)
                        .background(Color.paper)
                        .clipShape(Circle())
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(repository.notebooks) { notebook in
                        TrackedEditorToolButton(componentID: "sheet.notebook-picker.select.\(notebook.id.uuidString.lowercased())", disabled: false, action: {
                            onSelect(notebook.id)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: notebook.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(notebook.tint)
                                    .frame(width: 42, height: 42)
                                    .background(notebook.tint.opacity(0.16))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(notebook.title)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                    Text("\(repository.pages(for: notebook.id).count) notes")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.inkSoft)
                                }

                                Spacer()

                                if notebook.id == currentNotebookID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 21, weight: .bold))
                                        .foregroundStyle(Color.clay)
                                }
                            }
                            .padding(12)
                            .background(Color.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.background.ignoresSafeArea())
    }
}

private struct NewNotebookSheet: View {
    @State private var title: String = "New Book"
    @State private var themeIndex: Int = 0
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var coverImageData: Data?
    let onCreate: (String, Int, Data?) -> Void
    let onCancel: () -> Void

    private let themeNames = ["Default", "Berry", "Cloud", "Sakura"]
    private let coverNames = ["Default", "Petals", "Checks", "Sweet"]

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack {
                        TrackedEditorToolButton(componentID: "sheet.new-notebook.cancel", disabled: false, action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 42, height: 42)
                                .background(Color.paper)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.2))
                        }

                        Spacer()

                        Text("New Book")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ink)

                        Spacer()

                        TrackedEditorToolButton(componentID: "sheet.new-notebook.create", disabled: false, action: {
                            onCreate(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Book" : title, themeIndex, coverImageData)
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 42, height: 42)
                                .background(Color.paper)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.2))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    NotebookPreviewCard(title: title, themeIndex: themeIndex, coverImageData: coverImageData)
                        .padding(.horizontal, 18)

                    VStack(alignment: .leading, spacing: 14) {
                        TextField("", text: $title)
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .frame(height: 58)
                            .background(Color.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.4))

                        GroupBox(label: Text("Choose Theme").font(.system(size: 20, weight: .semibold, design: .rounded))) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(Array(themeNames.enumerated()), id: \.offset) { index, name in
                                    TrackedEditorToolButton(componentID: "sheet.new-notebook.theme.\(telemetryIDSegment(name))", disabled: false, action: {
                                        themeIndex = index
                                    }) {
                                        ThemeChip(title: name, selected: themeIndex == index)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(Color.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

                        Text("Choose cover")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ink)

                        PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                            HStack(spacing: 12) {
                                Image(systemName: coverImageData == nil ? "photo.badge.plus" : "photo.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.clay)
                                    .frame(width: 38, height: 38)
                                    .background(Color.banner)
                                    .clipShape(Circle())

                                Text(coverImageData == nil ? "Choose Photo Cover" : "Change Photo Cover")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ink)

                                Spacer()

                                if coverImageData != nil {
                                    TrackedEditorToolButton(componentID: "sheet.new-notebook.cover.clear", disabled: false, action: {
                                        selectedCoverPhoto = nil
                                        coverImageData = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(Color.inkSoft)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 62)
                            .background(Color.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.3))
                        }
                        .buttonStyle(.plain)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<coverNames.count, id: \.self) { index in
                                    CoverOptionCard(
                                        title: coverNames[index],
                                        selected: themeIndex == index,
                                        themeIndex: index
                                    ) {
                                        themeIndex = index
                                    }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
        }
        .task(id: selectedCoverPhoto) {
            guard let selectedCoverPhoto else { return }
            coverImageData = try? await selectedCoverPhoto.loadTransferable(type: Data.self)
        }
    }
}

private struct NotebookPreviewCard: View {
    let title: String
    let themeIndex: Int
    let coverImageData: Data?

    var body: some View {
        ZStack {
            if let coverImageData, let image = UIImage(data: coverImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(previewGradient)
            }

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .frame(width: 78, height: 300)
                .offset(x: -44)

            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.paper.opacity(0.92))
                    .frame(width: 220, height: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.lineSoft, lineWidth: 2)
                            .padding(4)
                    )
                    .overlay(
                        Text(title.isEmpty ? "Note Book" : title)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    )
                    .offset(y: 90)

                Spacer()
            }
            .padding(.top, 42)

            if themeIndex == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.paper)
                    .background(Circle().fill(Color.clay))
                    .offset(x: 92, y: 84)
            }
        }
        .frame(height: 560)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: Color.shadow, radius: 20, x: 0, y: 10)
    }

    private var previewGradient: LinearGradient {
        switch themeIndex {
        case 1:
            return LinearGradient(colors: [Color.rose.opacity(0.25), Color.paper, Color.bannerSoft], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:
            return LinearGradient(colors: [Color.mist.opacity(0.26), Color.paper, Color.banner], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3:
            return LinearGradient(colors: [Color.sand.opacity(0.28), Color.paper, Color.rose.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color.bannerSoft, Color.paper, Color.panelDeep.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct ThemeChip: View {
    let title: String
    let selected: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ink)

            Spacer()

            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.clay)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(selected ? Color.banner : Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selected ? Color.clay.opacity(0.4) : Color.lineSoft, lineWidth: 1.2))
    }
}

private struct CoverOptionCard: View {
    let title: String
    let selected: Bool
    let themeIndex: Int
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "sheet.new-notebook.cover.\(telemetryIDSegment(title))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(coverGradient)
                    .frame(width: 136, height: 188)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? Color.clay : Color.lineSoft, lineWidth: selected ? 2.2 : 1.4)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Color.paper)
                                .padding(10)
                        }
                    }

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ink)
            }
        }
    }

    private var coverGradient: LinearGradient {
        switch themeIndex {
        case 1:
            return LinearGradient(colors: [Color.rose.opacity(0.35), Color.paper, Color.bannerSoft], startPoint: .top, endPoint: .bottom)
        case 2:
            return LinearGradient(colors: [Color.paper, Color.banner, Color.panelDeep.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        case 3:
            return LinearGradient(colors: [Color.bannerSoft, Color.rose.opacity(0.25), Color.paper], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color.paper, Color.panelDeep.opacity(0.45), Color.bannerSoft], startPoint: .top, endPoint: .bottom)
        }
    }
}

private struct CanvasThumbnail: View {
    @ObservedObject var repository: NotebookRepository
    let document: CanvasDocument

    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width / document.canvasSize.width, proxy.size.height / document.canvasSize.height)

            ZStack {
                Color.editorPeach

                CanvasDocumentRenderer(
                    repository: repository,
                    document: document,
                    scale: scale,
                    selectedElementIDs: [],
                    elementLimit: 8
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct HeaderView: View {
    let onNotifications: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TravelClip")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Travel journal")
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSoft)
            }

            Spacer()

            HeaderButton(
                icon: "bell",
                componentID: "home.header.notifications",
                accessibilityLabel: "Notifications",
                action: onNotifications
            )
        }
    }
}

private struct HomeNotificationSheet: View {
    let notebooks: [TravelNotebook]
    let pages: [JournalPage]
    let onOpenPage: (UUID) -> Void
    let onDone: () -> Void

    private var recentPages: [JournalPage] {
        Array(pages.sorted { $0.updatedAt > $1.updatedAt }.prefix(5))
    }

    private var totalElementCount: Int {
        pages.reduce(0) { total, page in
            total + page.canvasDocument.elements.count
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        notificationMetric(title: "Notebooks", value: "\(notebooks.count)", icon: "book.closed")
                        notificationMetric(title: "Pages", value: "\(pages.count)", icon: "doc.text.image")
                        notificationMetric(title: "Items", value: "\(totalElementCount)", icon: "square.stack.3d.up")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent activity")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)

                        if recentPages.isEmpty {
                            emptyState
                        } else {
                            ForEach(recentPages) { page in
                                TrackedEditorToolButton(componentID: "home.notifications.open.\(page.id.uuidString.lowercased())", disabled: false, action: {
                                    onOpenPage(page.id)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: icon(for: page))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(Color.clay)
                                            .frame(width: 38, height: 38)
                                            .background(Color.sand.opacity(0.7))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(page.title)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.ink)
                                                .lineLimit(1)

                                            Text(page.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.inkSoft)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.inkSoft)
                                    }
                                    .padding(12)
                                    .background(Color.paper)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 12)
            }
            .background(PaperBackground().ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    TrackedEditorToolButton(componentID: "home.notifications.done", disabled: false, action: onDone) {
                        Text("Done")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.clay)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                    }
                }
            }
        }
    }

    private func notificationMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.clay)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.inkSoft)
                .frame(width: 38, height: 38)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("No recent page activity yet.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paper.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))
    }

    private func icon(for page: JournalPage) -> String {
        if page.canvasDocument.elements.contains(where: { $0.kind == .image || $0.kind == .video }) {
            return "photo.on.rectangle"
        }
        if page.canvasDocument.elements.contains(where: { $0.kind == .link || $0.kind == .file }) {
            return "paperclip"
        }
        if page.canvasDocument.elements.contains(where: { $0.kind == .brush || $0.kind == .connector }) {
            return "scribble.variable"
        }
        return "doc.text"
    }
}

private struct SearchCard: View {
    let title: String
    let subtitle: String
    let isSearching: Bool
    let placeLabel: String
    let mapRegion: MKCoordinateRegion
    let onTap: () -> Void
    let onLocate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TrackedEditorToolButton(componentID: "home.search.open", disabled: false, action: onTap) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.inkSoft)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            LocationMapPreview(region: mapRegion, placeLabel: placeLabel)
                .frame(height: 168)

            TrackedEditorToolButton(componentID: "home.search.locate", disabled: isSearching, action: onLocate) {
                HStack(spacing: 8) {
                    if isSearching {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("选择当前定位")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.clay)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
            }
        }
        .padding(12)
        .background(Color.panel)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.lineSoft, lineWidth: 1.5)
        )
    }
}

@MainActor
private final class PlaceSearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [MKMapItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var message = "Search a city, landmark, cafe, museum, or neighborhood."

    func search() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            message = "Search a city, landmark, cafe, museum, or neighborhood."
            return
        }

        isSearching = true
        message = "Searching..."
        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = term
            request.resultTypes = [.address, .pointOfInterest]
            do {
                let response = try await MKLocalSearch(request: request).start()
                results = response.mapItems
                message = results.isEmpty ? "No places found." : "\(results.count) places found"
            } catch {
                results = []
                message = "Search failed. Try another place."
            }
            isSearching = false
        }
    }
}

private struct PlaceSearchSheet: View {
    @ObservedObject var locationProvider: TravelLocationProvider
    let onDone: () -> Void
    @StateObject private var model = PlaceSearchModel()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Place")
                        .font(.system(size: 25, weight: .bold, design: .serif))
                        .foregroundStyle(Color.ink)
                    Text("Pick a place to show related stickers on Home.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                }

                Spacer()

                TrackedEditorToolButton(componentID: "sheet.place-search.done", disabled: false, action: onDone) {
                    Text("Done")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.paper)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Color.clay)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.inkSoft)

                TextField("Tokyo, Paris, Shanghai...", text: $model.query)
                    .focused($focused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit { model.search() }

                if model.isSearching {
                    ProgressView()
                        .controlSize(.mini)
                } else if !model.query.isEmpty {
                    TrackedEditorToolButton(componentID: "sheet.place-search.clear", disabled: false, action: {
                        model.query = ""
                        model.search()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.inkSoft)
                    }
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
            .onChange(of: model.query) { _, _ in
                model.search()
            }

            Text(model.message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSoft)

            TrackedEditorToolButton(componentID: "sheet.place-search.current-location", disabled: locationProvider.isLocating, action: {
                locationProvider.requestLocation()
                onDone()
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.clay.opacity(0.12))
                        if locationProvider.isLocating {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.clay)
                        }
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("选择当前定位")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)

                        Text(locationProvider.statusText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
            }

            if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                TrackedEditorToolButton(componentID: "sheet.place-search.use-query", disabled: false, action: {
                    locationProvider.applySearchText(model.query)
                    onDone()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.clay)
                            .frame(width: 38, height: 38)
                            .background(Color.clay.opacity(0.12))
                            .clipShape(Circle())

                        Text("Use \"\(model.query.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.banner)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.clay.opacity(0.28), lineWidth: 1.2))
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(model.results.prefix(12).enumerated()), id: \.offset) { _, item in
                        TrackedEditorToolButton(componentID: "sheet.place-search.result.\(telemetryIDSegment(item.name ?? "place"))", disabled: false, action: {
                            locationProvider.applySearchResult(item)
                            onDone()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.clay)
                                    .frame(width: 38, height: 38)
                                    .background(Color.clay.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name ?? "Place")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                        .lineLimit(1)

                                    Text(placeSubtitle(for: item))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.inkSoft)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(Color.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
                        }
                    }
                }
            }
        }
        .padding(22)
        .background(Color.background)
        .onAppear {
            focused = true
        }
    }

    private func placeSubtitle(for item: MKMapItem) -> String {
        [
            item.placemark.locality,
            item.placemark.administrativeArea,
            item.placemark.country
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}

private struct LocationMapPreview: View {
    let region: MKCoordinateRegion
    let placeLabel: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(initialPosition: .region(region))
            .id("\(region.center.latitude)-\(region.center.longitude)-\(region.span.latitudeDelta)-\(region.span.longitudeDelta)")
            .allowsHitTesting(false)

            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.clay)
                Text(placeLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.paper.opacity(0.94))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1))
            .shadow(color: Color.shadowSoft, radius: 4, x: 0, y: 2)
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
    }
}

private struct HeaderButton: View {
    let icon: String
    let componentID: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: componentID, disabled: false, action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Color.ink)
                .frame(width: 38, height: 38)
                .background(Color.paper)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.3))
        }
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

private struct CreateBanner: View {
    let onCreatePage: () -> Void
    let onTemplatePage: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HomeCreateOption(
                title: "New Page",
                icon: "square.and.pencil",
                tint: .sand,
                action: onCreatePage
            )

            HomeCreateOption(
                title: "Template",
                icon: "doc.text",
                tint: .sage,
                action: onTemplatePage
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.bannerSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.lineSoft, lineWidth: 1.5)
        )
    }
}

private struct HomeCreateOption: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "home.create.\(telemetryIDSegment(title))", disabled: false, action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.clay)
                    .frame(width: 50, height: 50)
                    .background(tint.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 112)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
        }
    }
}

private struct MyLibraryRootTabView: View {
    @ObservedObject var repository: NotebookRepository
    @Binding var path: [TravelRoute]
    @Binding var showingNewNotebook: Bool
    let onCreatePage: () -> Void
    let onTemplatePage: () -> Void

    private let notebookColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var recentPages: [JournalPage] {
        Array(repository.pages.sorted { $0.updatedAt > $1.updatedAt }.prefix(4))
    }

    private var elementCount: Int {
        repository.pages.reduce(0) { total, page in
            total + page.canvasDocument.elements.count
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("My TravelClip")
                        .font(.system(size: 31, weight: .bold, design: .serif))
                        .foregroundStyle(Color.ink)

                    Text("Local notebooks, recent pages, and quick creation.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    libraryMetric(title: "Books", value: "\(repository.notebooks.count)", icon: "book.closed")
                    libraryMetric(title: "Pages", value: "\(repository.pages.count)", icon: "doc.text.image")
                    libraryMetric(title: "Items", value: "\(elementCount)", icon: "square.stack.3d.up")
                }

                CreateBanner(onCreatePage: onCreatePage, onTemplatePage: onTemplatePage)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Pages")
                            .sectionTitle()
                        Spacer()
                    }

                    if recentPages.isEmpty {
                        Text("Create a page to see recent work here.")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.paper.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(recentPages) { page in
                                TrackedEditorToolButton(componentID: "my.page.open.\(page.id.uuidString.lowercased())", disabled: false, action: {
                                    path.append(.preview(page.id))
                                }) {
                                    HStack(spacing: 12) {
                                        CanvasThumbnail(repository: repository, document: page.canvasDocument)
                                            .frame(width: 54, height: 72)
                                            .background(Color.paper)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))

                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(page.title)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.ink)
                                                .lineLimit(1)

                                            Text(page.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.inkSoft)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.inkSoft)
                                    }
                                    .padding(12)
                                    .background(Color.paper)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Notebooks")
                            .sectionTitle()

                        Spacer()

                        TrackedEditorToolButton(componentID: "my.notebook.new", disabled: false, action: {
                            showingNewNotebook = true
                        }) {
                            Label("New Book", systemImage: "plus")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkSoft)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(Color.paper)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1.2))
                        }
                    }

                    LazyVGrid(columns: notebookColumns, spacing: 16) {
                        ForEach(repository.notebooks) { notebook in
                            NotebookCard(
                                repository: repository,
                                notebook: notebook,
                                coverPage: repository.coverPage(for: notebook.id),
                                count: repository.pages(for: notebook.id).count
                            ) {
                                path.append(.notebook(notebook.id))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 116)
        }
    }

    private func libraryMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.clay)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1))
    }
}

private struct NotebookSection: View {
    @ObservedObject var repository: NotebookRepository
    @Binding var path: [TravelRoute]
    @Binding var showingNewNotebook: Bool
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("Notebooks")
                    .sectionTitle()

                Spacer()

                TrackedEditorToolButton(componentID: "home.notebook.new", disabled: false, action: {
                    showingNewNotebook = true
                }) {
                    Label("New Book", systemImage: "plus")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Color.paper)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1.2))
                }
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(repository.notebooks) { notebook in
                    NotebookCard(
                        repository: repository,
                        notebook: notebook,
                        coverPage: repository.coverPage(for: notebook.id),
                        count: repository.pages(for: notebook.id).count
                    ) {
                        path.append(.notebook(notebook.id))
                    }
                }
            }
        }
    }
}

private struct LocationStickerShelf: View {
    @ObservedObject var repository: NotebookRepository
    @ObservedObject var locationProvider: TravelLocationProvider
    let onAddMaterial: (MaterialItem) -> Void
    let onAddSticker: (StickerDefinition) -> Void

    private var selectedCoordinate: CLLocationCoordinate2D {
        _ = locationProvider.placeRevision
        return locationProvider.coordinate
    }

    private var matchingGroups: [MaterialGroup] {
        _ = locationProvider.placeRevision
        let groups = repository.materialGroups
        let primaryTokens = ([locationProvider.searchedPlaceName, locationProvider.city, locationProvider.regionName])
            .compactMap { $0 }
            .flatMap(\.locationTokens)
        let countryTokens = locationProvider.country?.locationTokens ?? []

        if !primaryTokens.isEmpty {
            let matched = groups.filter { group in
                let groupValues = ([group.city, group.country, group.title] + group.tags).flatMap(\.locationTokens)
                let itemValues = group.items.flatMap { item in
                    ([item.city, item.country, item.title, item.fileName] + item.tags).flatMap(\.locationTokens)
                }
                let values = groupValues + itemValues
                return primaryTokens.contains { token in
                    values.contains { value in
                        value == token || value.contains(token) || token.contains(value)
                    }
                }
            }
            if !matched.isEmpty {
                return matched
            }
        }

        if !countryTokens.isEmpty {
            let matched = groups.filter { group in
                let groupValues = ([group.country] + group.tags).flatMap(\.locationTokens)
                let itemValues = group.items.flatMap { item in
                    ([item.country] + item.tags).flatMap(\.locationTokens)
                }
                let values = groupValues + itemValues
                return countryTokens.contains { token in
                    values.contains { value in value == token }
                }
            }
            if !matched.isEmpty {
                return matched
            }
        }

        let global = groups.filter { group in
            group.country.locationKey == "global" || group.tags.map(\.locationKey).contains("global")
        }
        return global.isEmpty ? Array(groups.prefix(1)) : global
    }

    private var materialItems: [MaterialItem] {
        let coordinate = selectedCoordinate
        let items = matchingGroups.flatMap(\.items)
        let ranked = items.sorted { lhs, rhs in
            let lhsDistance = distanceInMeters(from: coordinate, to: lhs)
            let rhsDistance = distanceInMeters(from: coordinate, to: rhs)
            switch (lhsDistance, rhsDistance) {
            case let (.some(lhsDistance), .some(rhsDistance)):
                return lhsDistance < rhsDistance
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
        return Array(ranked.prefix(10))
    }

    private var shelfTitle: String {
        if let city = locationProvider.city, !city.isEmpty {
            return "\(city) Stickers"
        }
        return "Travel Stickers"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shelfTitle)
                        .sectionTitle()

                    Text(locationProvider.statusText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(1)
                }

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(materialItems) { item in
                        LocationMaterialStickerCard(item: item) {
                            onAddMaterial(item)
                        }
                    }

                    if materialItems.isEmpty {
                        ForEach(repository.stickerLibrary.prefix(6)) { sticker in
                            LocationSymbolStickerCard(sticker: sticker) {
                                onAddSticker(sticker)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func distanceInMeters(from coordinate: CLLocationCoordinate2D, to item: MaterialItem) -> CLLocationDistance? {
        guard let latitude = item.latitude,
              let longitude = item.longitude,
              latitude != 0 || longitude != 0 else { return nil }
        let start = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let end = CLLocation(latitude: latitude, longitude: longitude)
        return start.distance(from: end)
    }
}

private struct LocationMaterialStickerCard: View {
    let item: MaterialItem
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "home.location.material.\(telemetryIDSegment(item.id))", disabled: false, action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = CanvasImageCache.shared.image(at: item.fileURL) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 104, height: 82)
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(Color.inkSoft)
                            .frame(width: 104, height: 82)
                            .background(Color.paper)
                    }

                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.paper)
                        .frame(width: 24, height: 24)
                        .background(Color.clay)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.paper, lineWidth: 2))
                        .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(item.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(item.city.isEmpty ? item.country : item.city)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(width: 120, height: 132)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private struct LocationSymbolStickerCard: View {
    let sticker: StickerDefinition
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "home.location.sticker.\(telemetryIDSegment(sticker.id))", disabled: false, action: action) {
            VStack(spacing: 9) {
                Image(systemName: sticker.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color(hex: sticker.colorHex))
                    .frame(width: 78, height: 72)
                    .background(Color(hex: sticker.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(sticker.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(width: 112, height: 126)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.1))
        }
    }
}

private extension String {
    var locationKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "省", with: "")
            .replacingOccurrences(of: "city", with: "")
            .replacingOccurrences(of: "province", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    var locationTokens: [String] {
        let base = locationKey
        guard !base.isEmpty else { return [] }
        var tokens: Set<String> = [base]
        for part in base.split(separator: "-") where !part.isEmpty {
            tokens.insert(String(part))
        }

        let aliases: [String: [String]] = [
            "深圳": ["shenzhen"],
            "深圳市": ["shenzhen"],
            "shenzhen": ["深圳"],
            "广州": ["guangzhou", "canton"],
            "广州市": ["guangzhou", "canton"],
            "guangzhou": ["广州", "canton"],
            "canton": ["guangzhou", "广州"],
            "中国": ["china"],
            "china": ["中国"],
            "广东": ["guangdong", "china"],
            "guangdong": ["广东", "china"]
        ]

        for token in Array(tokens) {
            for alias in aliases[token] ?? [] {
                tokens.insert(alias.locationKey)
            }
        }
        return Array(tokens)
    }
}

private struct NotebookCard: View {
    @ObservedObject var repository: NotebookRepository
    let notebook: TravelNotebook
    let coverPage: JournalPage?
    let count: Int
    let action: () -> Void

    var body: some View {
        TrackedEditorToolButton(componentID: "home.notebook.open.\(notebook.id.uuidString.lowercased())", disabled: false, action: action) {
            ZStack(alignment: .bottom) {
                NotebookCover(repository: repository, notebook: notebook, coverPage: coverPage)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notebook.title)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("Note Number: \(count)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(Color.paper.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(DashedRoundedBorder(radius: 10, color: .lineStrong, lineWidth: 1.4))
                .padding(10)
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.lineSoft, lineWidth: 1.4)
            )
            .shadow(color: Color.shadow, radius: 10, x: 0, y: 5)
        }
    }
}

private struct NotebookCover: View {
    @ObservedObject var repository: NotebookRepository
    let notebook: TravelNotebook
    let coverPage: JournalPage?

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [
                    notebook.tint.opacity(0.28),
                    Color.banner.opacity(0.78),
                    Color.paper
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(Color.ink.opacity(0.08))
                .frame(width: 16)
                .overlay(
                    Rectangle()
                        .fill(Color.paper.opacity(0.45))
                        .frame(width: 3)
                        .offset(x: 5)
                )

            ForEach(0..<4) { index in
                Circle()
                    .fill(Color.paper.opacity(0.62))
                    .frame(width: 8, height: 8)
                    .offset(x: 4, y: CGFloat(-48 + index * 30))
            }

            ZStack {
                if let coverPage {
                    CanvasThumbnail(repository: repository, document: coverPage.canvasDocument)
                        .frame(width: 118, height: 158)
                        .background(Color.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.paper.opacity(0.92), lineWidth: 6)
                        )
                        .shadow(color: Color.shadowSoft, radius: 9, x: 0, y: 5)
                        .rotationEffect(.degrees(-3))
                } else {
                    ForEach(0..<7) { index in
                        Image(systemName: ["sparkle", "heart.fill", "leaf.fill", "circle.fill"][index % 4])
                            .font(.system(size: CGFloat(10 + (index % 3) * 4), weight: .medium))
                            .foregroundStyle([Color.rose, Color.sage, Color.sand, Color.mist][index % 4].opacity(0.6))
                            .offset(
                                x: CGFloat([-54, 42, 70, -22, 18, -70, 56][index]),
                                y: CGFloat([-38, -46, 6, 22, -8, 42, 48][index])
                            )
                    }

                    Image(systemName: notebook.symbol)
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(notebook.tint)
                        .frame(width: 84, height: 84)
                        .background(Circle().fill(Color.paper.opacity(0.72)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, 16)
        }
    }
}

private struct BottomTabBar: View {
    @Binding var selectedTab: RootTab

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.tabBorder, lineWidth: 2)
                )
                .shadow(color: Color.shadowSoft, radius: 10, x: 0, y: -2)
                .frame(height: 96)
                .offset(y: 20)

            HStack(spacing: 8) {
                ForEach(RootTab.allCases) { tab in
                    TrackedEditorToolButton(componentID: "root.tab.\(telemetryIDSegment(tab.title))", disabled: false, action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.tabShadow)
                                        .frame(width: 28, height: 28)
                                        .offset(x: 4, y: 4)
                                }

                                Image(systemName: tab.icon)
                                    .font(.system(size: 26, weight: .semibold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(selectedTab == tab ? Color.ink : Color.tabIcon)
                                    .frame(width: 34, height: 32)
                            }

                            Text(tab.title)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(selectedTab == tab ? Color.ink : Color.tabIcon)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 23)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .offset(y: 30)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct PaperBackground: View {
    var body: some View {
        ZStack {
            Color.background

            GridPattern()
                .stroke(Color.gridLine, lineWidth: 1)
        }
    }
}

private struct GridPattern: Shape {
    var spacing: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()

        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }

        return path
    }
}

private struct DashedRoundedBorder: View {
    let radius: CGFloat
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [8, 6]))
            .padding(8)
    }
}

private extension Text {
    func sectionTitle() -> some View {
        self
            .font(.system(size: 24, weight: .bold, design: .serif))
            .foregroundStyle(Color.ink)
    }
}

private extension Image {
    func toolIcon(_ color: Color = .ink) -> some View {
        self
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 48, height: 48)
            .background(Color.banner)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.2))
    }
}

extension Color {
    static let background = Color(red: 0.968, green: 0.956, blue: 0.932)
    static let paper = Color(red: 0.992, green: 0.984, blue: 0.962)
    static let panel = Color(red: 0.981, green: 0.971, blue: 0.944)
    static let panelDeep = Color(red: 0.905, green: 0.867, blue: 0.785)
    static let banner = Color(red: 0.990, green: 0.962, blue: 0.860)
    static let bannerSoft = Color(red: 0.973, green: 0.946, blue: 0.895)
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let inkSoft = Color(red: 0.56, green: 0.54, blue: 0.50)
    static let editorChrome = Color(red: 0.92, green: 0.91, blue: 0.88)
    static let editorPeach = Color(red: 0.95, green: 0.84, blue: 0.72)
    static let editorGrid = Color(red: 0.78, green: 0.72, blue: 0.66).opacity(0.18)
    static let tabIcon = Color(red: 0.54, green: 0.52, blue: 0.50)
    static let tabShadow = Color(red: 0.94, green: 0.84, blue: 0.72)
    static let tabBorder = Color(red: 0.92, green: 0.82, blue: 0.70)
    static let gridLine = Color(red: 0.79, green: 0.75, blue: 0.69).opacity(0.18)
    static let lineSoft = Color(red: 0.86, green: 0.80, blue: 0.73).opacity(0.9)
    static let lineStrong = Color(red: 0.64, green: 0.61, blue: 0.56).opacity(0.65)
    static let clay = Color(red: 0.69, green: 0.46, blue: 0.38)
    static let sage = Color(red: 0.48, green: 0.63, blue: 0.55)
    static let mist = Color(red: 0.68, green: 0.76, blue: 0.83)
    static let sand = Color(red: 0.82, green: 0.72, blue: 0.58)
    static let rose = Color(red: 0.86, green: 0.65, blue: 0.67)
    static let shadow = Color(red: 0.56, green: 0.49, blue: 0.42).opacity(0.12)
    static let shadowSoft = Color(red: 0.56, green: 0.49, blue: 0.42).opacity(0.07)
}

#Preview {
    ContentView()
}
