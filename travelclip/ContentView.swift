//
//  ContentView.swift
//  travelclip
//
//  Created by moc on 2026/5/18.
//

import Combine
import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var repository = NotebookRepository()
    @State private var path: [TravelRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(repository: repository, path: $path)
                .navigationDestination(for: TravelRoute.self) { route in
                    switch route {
                    case .notebook(let notebookID):
                        NotebookDetailView(repository: repository, notebookID: notebookID, path: $path)
                    case .editor(let pageID):
                        CanvasEditorView(repository: repository, pageID: pageID)
                    }
                }
        }
    }
}

private struct HomeView: View {
    @ObservedObject var repository: NotebookRepository
    @Binding var path: [TravelRoute]
    @State private var showingNewNotebook = false
    @State private var pageCreateContext: PageCreateContext?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HeaderView()
                    SearchCard()
                    CreateBanner(
                        onCreatePage: {
                            pageCreateContext = .defaultNotebook
                        },
                        onTemplatePage: {
                            let pageID = repository.createPage(in: nil, title: "Template Page", template: .postcard)
                            path.append(.editor(pageID))
                        }
                    )
                    NotebookSection(repository: repository, path: $path, showingNewNotebook: $showingNewNotebook)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 116)
            }

            BottomTabBar()
        }
        .background(PaperBackground().ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewNotebook) {
            NewNotebookSheet { title, themeIndex in
                showingNewNotebook = false
                let notebookID = repository.createNotebook(title: title, themeIndex: themeIndex)
                path.append(.notebook(notebookID))
            } onCancel: {
                showingNewNotebook = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $pageCreateContext) { context in
            NewPageSheet(
                onBlank: {
                    pageCreateContext = nil
                    let pageID = repository.createPage(in: context.notebookID, title: "New Page", template: .blank)
                    path.append(.editor(pageID))
                },
                onTemplate: {
                    pageCreateContext = nil
                    let pageID = repository.createPage(in: context.notebookID, title: "Template Page", template: .postcard)
                    path.append(.editor(pageID))
                },
                onCancel: {
                    pageCreateContext = nil
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            repository.bootstrapIfNeeded()
        }
    }
}

private enum TravelRoute: Hashable {
    case notebook(UUID)
    case editor(UUID)
}

private struct PageCreateContext: Identifiable {
    let id = UUID()
    let notebookID: UUID?

    static let defaultNotebook = PageCreateContext(notebookID: nil)
}

private struct NotebookDetailView: View {
    @ObservedObject var repository: NotebookRepository
    let notebookID: UUID
    @Binding var path: [TravelRoute]
    @State private var pageTitle = ""
    @State private var pageBeingEdited: JournalPage?
    @State private var pageCreateContext: PageCreateContext?

    private var notebook: TravelNotebook? {
        repository.notebooks.first { $0.id == notebookID }
    }

    private var pages: [JournalPage] {
        repository.pages(for: notebookID)
    }

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

                            Text("\(pages.count) pages · local first")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkSoft)
                        }

                        Spacer()

                        Button {
                            pageCreateContext = PageCreateContext(notebookID: notebookID)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 42, height: 42)
                                .background(Color.paper)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.3))
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVStack(spacing: 14) {
                        ForEach(pages) { page in
                            PageRow(
                                page: page,
                                isCover: notebook?.coverPageID == page.id,
                                onOpen: {
                                    path.append(.editor(page.id))
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
                onBlank: {
                    pageCreateContext = nil
                    let pageID = repository.createPage(in: context.notebookID, title: "New Page", template: .blank)
                    path.append(.editor(pageID))
                },
                onTemplate: {
                    pageCreateContext = nil
                    let pageID = repository.createPage(in: context.notebookID, title: "Template Page", template: .postcard)
                    path.append(.editor(pageID))
                },
                onCancel: {
                    pageCreateContext = nil
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct PageRow: View {
    let page: JournalPage
    let isCover: Bool
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onSetCover: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                CanvasThumbnail(document: page.canvasDocument)
                    .frame(width: 84, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(page.title)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)

                        if isCover {
                            Text("Cover")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.paper)
                                .padding(.horizontal, 8)
                                .frame(height: 20)
                                .background(Color.clay)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(page.canvasDocument.elements.count) elements")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)

                    Text(page.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft.opacity(0.86))
                }

                Spacer()

                Menu {
                    Button("Rename", systemImage: "pencil", action: onRename)
                    Button("Set as cover", systemImage: "star", action: onSetCover)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.clay)
                        .frame(width: 32, height: 32)
                }
                .menuStyle(.button)
            }
            .padding(12)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

private struct CanvasEditorView: View {
    @ObservedObject var repository: NotebookRepository
    let pageID: UUID
    @State private var draftText = ""
    @State private var showingTextSheet = false
    @State private var selectedPhoto: PhotosPickerItem?

    private var page: JournalPage? {
        repository.page(id: pageID)
    }

    var body: some View {
        ZStack {
            Color.editorChrome.ignoresSafeArea()

            VStack(spacing: 0) {
                EditorTopBar(title: page?.title ?? "Canvas") {
                    repository.updateBackground(for: pageID)
                }

                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    if let document = page?.canvasDocument {
                        CanvasWorkspace(
                            document: document,
                            selectedElementID: repository.selectedElementID,
                            onSelect: { repository.selectedElementID = $0 },
                            onMove: { elementID, position in
                                repository.moveElement(elementID, on: pageID, to: position)
                            },
                            onCommit: {
                                repository.commitPage(pageID)
                            },
                            onDelete: { elementID in
                                repository.deleteElement(elementID, from: pageID)
                            },
                            onScale: { elementID, factor in
                                repository.scaleElement(elementID, on: pageID, by: factor)
                            },
                            onRotate: { elementID, degrees in
                                repository.rotateElement(elementID, on: pageID, by: degrees)
                            }
                        )
                        .padding(.horizontal, 34)
                        .padding(.vertical, 28)
                    }
                }
            }

            VStack {
                Spacer()
                EditorToolBar(
                    selectedElementID: repository.selectedElementID,
                    onText: {
                        draftText = ""
                        showingTextSheet = true
                    },
                    onSticker: {
                        repository.addSticker(to: pageID)
                    },
                    onDelete: {
                        if let selectedID = repository.selectedElementID {
                            repository.deleteElement(selectedID, from: pageID)
                        }
                    },
                    photoPicker: {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                                .toolIcon()
                        }
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTextSheet) {
            TextInputSheet(text: $draftText) {
                repository.addText(draftText, to: pageID)
                showingTextSheet = false
            }
            .presentationDetents([.medium])
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                await repository.addPhoto(newItem, to: pageID)
                selectedPhoto = nil
            }
        }
    }
}

private struct EditorTopBar: View {
    let title: String
    let onBackground: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)

                Text("Saved in notebook")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
            }

            Spacer()

            Button(action: onBackground) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 40, height: 40)
                    .background(Color.paper)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.paper.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lineSoft)
                .frame(height: 1)
        }
    }
}

private struct CanvasWorkspace: View {
    let document: CanvasDocument
    let selectedElementID: UUID?
    let onSelect: (UUID?) -> Void
    let onMove: (UUID, CGPoint) -> Void
    let onCommit: () -> Void
    let onDelete: (UUID) -> Void
    let onScale: (UUID, CGFloat) -> Void
    let onRotate: (UUID, Double) -> Void
    @State private var dragStartFrames: [UUID: CGPoint] = [:]

    var body: some View {
        ZStack {
            CanvasSurface(background: document.background)

            ForEach(document.elements.sorted { $0.zIndex < $1.zIndex }) { element in
                CanvasElementView(element: element, selected: selectedElementID == element.id)
                    .position(x: element.x, y: element.y)
                    .rotationEffect(.degrees(element.rotation))
                    .opacity(element.opacity)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                onSelect(element.id)
                                let start = dragStartFrames[element.id] ?? CGPoint(x: element.x, y: element.y)
                                dragStartFrames[element.id] = start
                                onMove(element.id, CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height))
                            }
                            .onEnded { _ in
                                dragStartFrames[element.id] = nil
                                onCommit()
                            }
                    )
                    .onTapGesture {
                        onSelect(element.id)
                    }
                    .overlay {
                        if selectedElementID == element.id {
                            TransformHandles(
                                onDelete: { onDelete(element.id) },
                                onScaleUp: { onScale(element.id, 1.08) },
                                onScaleDown: { onScale(element.id, 0.92) },
                                onRotate: { onRotate(element.id, 12) }
                            )
                            .frame(width: element.width + 34, height: element.height + 34)
                            .position(x: element.x, y: element.y)
                            .rotationEffect(.degrees(element.rotation))
                        }
                    }
            }
        }
        .frame(width: document.canvasSize.width, height: document.canvasSize.height)
        .scaleEffect(0.27, anchor: .topLeading)
        .frame(width: document.canvasSize.width * 0.27, height: document.canvasSize.height * 0.27)
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 14)
        .onTapGesture {
            onSelect(nil)
        }
    }
}

private struct CanvasSurface: View {
    let background: CanvasBackground

    var body: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(background.gradient)
            .overlay {
                GridPattern(spacing: 54)
                    .stroke(Color.white.opacity(0.22), lineWidth: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            }
    }
}

private struct CanvasElementView: View {
    let element: CanvasElement
    let selected: Bool

    var body: some View {
        ZStack {
            switch element.kind {
            case .text:
                Text(element.text ?? "")
                    .font(.system(size: element.fontSize, weight: element.bold ? .bold : .medium, design: .serif))
                    .foregroundStyle(Color(hex: element.colorHex))
                    .multilineTextAlignment(.center)
                    .frame(width: element.width, height: element.height)
                    .minimumScaleFactor(0.3)
            case .sticker:
                Text(element.symbol ?? "sparkle")
                    .font(.system(size: min(element.width, element.height) * 0.72, weight: .semibold))
                    .frame(width: element.width, height: element.height)
                    .background(Color(hex: element.colorHex).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            case .image:
                if let image = element.localPath.flatMap({ UIImage(contentsOfFile: $0) }) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: element.width, height: element.height)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                        .frame(width: element.width, height: element.height)
                        .background(Color.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
            }
        }
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.clay, style: StrokeStyle(lineWidth: 4, dash: [18, 10]))
                    .frame(width: element.width + 18, height: element.height + 18)
            }
        }
    }
}

private struct TransformHandles: View {
    let onDelete: () -> Void
    let onScaleUp: () -> Void
    let onScaleDown: () -> Void
    let onRotate: () -> Void

    var body: some View {
        ZStack {
            handle("trash", alignment: .topLeading, action: onDelete)
            handle("plus.magnifyingglass", alignment: .bottomTrailing, action: onScaleUp)
            handle("minus.magnifyingglass", alignment: .bottomLeading, action: onScaleDown)
            handle("rotate.right", alignment: .topTrailing, action: onRotate)
        }
    }

    private func handle(_ icon: String, alignment: Alignment, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.paper)
                .frame(width: 54, height: 54)
                .background(Color.clay)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.paper, lineWidth: 4))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

private struct EditorToolBar<PhotoPicker: View>: View {
    let selectedElementID: UUID?
    let onText: () -> Void
    let onSticker: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let photoPicker: () -> PhotoPicker

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onText) {
                Image(systemName: "textformat")
                    .toolIcon()
            }
            .buttonStyle(.plain)

            Button(action: onSticker) {
                Image(systemName: "sparkles")
                    .toolIcon()
            }
            .buttonStyle(.plain)

            photoPicker()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .toolIcon(selectedElementID == nil ? Color.inkSoft.opacity(0.45) : Color.clay)
            }
            .disabled(selectedElementID == nil)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Color.paper)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1.3))
        .shadow(color: Color.shadow, radius: 16, x: 0, y: 8)
        .padding(.bottom, 18)
    }
}

private struct TextInputSheet: View {
    @Binding var text: String
    let onConfirm: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Text")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)

            TextEditor(text: $text)
                .focused($focused)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 150)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))

            HStack {
                Button("Clear") {
                    text = ""
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSoft)

                Spacer()

                Button("Add to Page", action: onConfirm)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.paper)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.inkSoft : Color.clay)
                    .clipShape(Capsule())
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .background(Color.background)
        .onAppear {
            focused = true
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
                Button("Cancel", action: onCancel)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)

                Spacer()

                Button("Save", action: onConfirm)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.paper)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.inkSoft : Color.clay)
                    .clipShape(Capsule())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .background(Color.background)
    }
}

private struct NewPageSheet: View {
    let onBlank: () -> Void
    let onTemplate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("New Page")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 36, height: 36)
                        .background(Color.paper)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                PageCreateOption(
                    title: "Blank",
                    subtitle: "Start with an empty canvas",
                    icon: "square",
                    tint: .sand,
                    action: onBlank
                )

                PageCreateOption(
                    title: "Template",
                    subtitle: "Use a starter layout",
                    icon: "doc.text",
                    tint: .sage,
                    action: onTemplate
                )
            }
        }
        .padding(22)
        .background(Color.background)
    }
}

private struct PageCreateOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

private struct NewNotebookSheet: View {
    @State private var title: String = "Note Group"
    @State private var themeIndex: Int = 0
    let onCreate: (String, Int) -> Void
    let onCancel: () -> Void

    private let themeNames = ["Default", "Berry", "Cloud", "Sakura"]
    private let coverNames = ["Default", "Petals", "Checks", "Sweet"]

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 42, height: 42)
                                .background(Color.paper)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("New Group")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ink)

                        Spacer()

                        Button {
                            onCreate(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Note Group" : title, themeIndex)
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 42, height: 42)
                                .background(Color.paper)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    NotebookPreviewCard(title: title, themeIndex: themeIndex)
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
                                    ThemeChip(title: name, selected: themeIndex == index)
                                        .onTapGesture {
                                            themeIndex = index
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
    }
}

private struct NotebookPreviewCard: View {
    let title: String
    let themeIndex: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(previewGradient)

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
                        Text(title.isEmpty ? "Note Group" : title)
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
        Button(action: action) {
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
        .buttonStyle(.plain)
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
    let document: CanvasDocument

    var body: some View {
        ZStack {
            CanvasSurface(background: document.background)

            ForEach(document.elements.prefix(4)) { element in
                switch element.kind {
                case .text:
                    Text(element.text ?? "")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: element.colorHex))
                        .lineLimit(2)
                        .frame(width: 46, height: 22)
                        .position(x: element.x * 0.077, y: element.y * 0.077)
                case .sticker:
                    Text(element.symbol ?? "sparkle")
                        .font(.system(size: 18))
                        .position(x: element.x * 0.077, y: element.y * 0.077)
                case .image:
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.mist.opacity(0.58))
                        .frame(width: 30, height: 24)
                        .position(x: element.x * 0.077, y: element.y * 0.077)
                }
            }
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TravelClip")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Local Notebook")
                    Text("· offline")
                        .foregroundStyle(Color.clay)
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSoft)
            }

            Spacer()

            HeaderButton(icon: "bell")
        }
    }
}

private struct SearchCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkSoft)

                Text("Search places...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            MapMock()
                .frame(height: 168)
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

private struct MapMock: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.panelDeep, Color.panel, Color.paper],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Path { path in
                path.move(to: CGPoint(x: 32, y: 30))
                path.addLine(to: CGPoint(x: 52, y: 120))
                path.addLine(to: CGPoint(x: 130, y: 126))
                path.addLine(to: CGPoint(x: 185, y: 82))
                path.move(to: CGPoint(x: 48, y: 34))
                path.addLine(to: CGPoint(x: 150, y: 44))
                path.addLine(to: CGPoint(x: 184, y: 136))
                path.move(to: CGPoint(x: 88, y: 24))
                path.addLine(to: CGPoint(x: 80, y: 102))
            }
            .stroke(Color.lineSoft.opacity(0.8), lineWidth: 1.1)

            VStack(spacing: 3) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.clay)

                Text("You are here")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.paper)
                    .clipShape(Capsule())
                    .shadow(color: Color.shadowSoft, radius: 4, x: 0, y: 2)
            }
        }
    }
}

private struct HeaderButton: View {
    let icon: String

    var body: some View {
        Button {
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Color.ink)
                .frame(width: 38, height: 38)
                .background(Color.paper)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.lineSoft, lineWidth: 1.3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(icon))
    }
}

private struct CreateBanner: View {
    let onCreatePage: () -> Void
    let onTemplatePage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onCreatePage) {
                HStack(spacing: 14) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.clay)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("New Page")
                            .font(.system(size: 22, weight: .medium, design: .serif))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)

                        Text("Add a page to your notebook")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .background(Color.banner)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(DashedRoundedBorder(radius: 20, color: .lineSoft, lineWidth: 1.6))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button(action: onCreatePage) {
                    Label("Page", systemImage: "square.and.pencil")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
                }
                .buttonStyle(.plain)

                Button(action: onTemplatePage) {
                    Label("Template", systemImage: "doc.text")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lineSoft, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }
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
                Text("Local Notebook")
                    .sectionTitle()

                Spacer()

                Button {
                    showingNewNotebook = true
                } label: {
                    Label("New Book", systemImage: "plus")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Color.paper)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(repository.notebooks) { notebook in
                    NotebookCard(notebook: notebook, count: repository.pages(for: notebook.id).count) {
                        path.append(.notebook(notebook.id))
                    }
                }
            }
        }
    }
}

private struct NotebookCard: View {
    let notebook: TravelNotebook
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                NotebookCover(notebook: notebook)

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
        .buttonStyle(.plain)
    }
}

private struct NotebookCover: View {
    let notebook: TravelNotebook

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, 16)
        }
    }
}

private struct BottomTabBar: View {
    private let tabs = [
        TabItem(title: "Home", icon: "house", selected: true),
        TabItem(title: "Store", icon: "storefront", selected: false),
        TabItem(title: "Universe", icon: "globe.asia.australia", selected: false),
        TabItem(title: "My", icon: "face.smiling", selected: false)
    ]

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
                ForEach(tabs) { tab in
                    Button {
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                if tab.selected {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.tabShadow)
                                        .frame(width: 28, height: 28)
                                        .offset(x: 4, y: 4)
                                }

                                Image(systemName: tab.icon)
                                    .font(.system(size: 26, weight: .semibold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(tab.selected ? Color.ink : Color.tabIcon)
                                    .frame(width: 34, height: 32)
                            }

                            Text(tab.title)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(tab.selected ? Color.ink : Color.tabIcon)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                    }
                    .buttonStyle(.plain)
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
