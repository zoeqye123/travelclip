# Mininote Public Product Research

This document summarizes public, observable behavior from Mininote / Mini Note style apps and translates it into implementation guidance for travelclip. It intentionally avoids private app binaries, proprietary assets, paid templates, and non-public APIs.

## Sources

- App Store listing: `https://apps.apple.com/us/app/mininote-cute-note-and-diary/id1575496870`
- App Store regional listing: `https://apps.apple.com/gb/app/mininote-cute-note-and-diary/id1575496870`
- Public screenshot mirrors and app listing pages found through web search, including AppHunter and MWM listing pages.
- Public user-facing screenshots, store descriptions, and reviews.

## Product Shape

Mininote is closer to a scrapbook editor than a plain note app. The core object model appears to be:

```text
Notebook
  Page
    CanvasDocument
      Background
      Elements[]
        Text
        Photo
        Sticker
        Tape
        BrushStroke
        WordArt
        TemplateItem
```

The important product idea is that every page is a fixed-format canvas. The app presents multiple entry points, but those entry points should all route to the same editor and the same persisted page document.

## Visible Modules

### Home / Notebook

- Multiple notebooks or collections.
- Decorative notebook covers.
- Counts or page previews.
- Fast entry to existing pages and new pages.

travelclip implication:

- Keep `TravelNotebook` and `JournalPage`.
- Make every new page belong to a notebook, even when created from the home screen.
- Avoid a separate "outside page" concept. Home quick create should use the default notebook and then open the same editor.

### Page Viewer

Public screenshots show a view mode where a finished page/card can be previewed with simple actions such as edit, share, or more. This is separate from full editing mode.

travelclip implication:

- Add a lightweight `PagePreviewView` later.
- For now, notebook rows and home cards should render pages using the same canvas renderer at thumbnail scale.

### Editor

The editor structure is consistent with:

- Top toolbar: back, undo, redo, layer, multi-select, more, done.
- Main fixed canvas area.
- Bottom tool strip: insert/photo, text, stickers, tape, word art, background, brush.
- Element selection with transform controls.
- Layer tools for order, lock, hide, delete.

travelclip implication:

- Keep a single `CanvasEditorView`.
- Keep fixed model canvas size, currently `1080 x 1920`.
- Scale the fixed canvas to available screen space.
- Never mutate the stored canvas size based on the current device viewport.

### Assets

The app relies heavily on reusable assets:

- Stickers
- Tape / masking tape
- Background paper
- Frames
- Template layouts
- WordArt presets

travelclip implication:

- Introduce an asset catalog model before adding more one-off tools.
- Store user photos and local/generated assets under an app-owned assets directory.
- Persist relative asset names or IDs in canvas elements, not absolute sandbox paths.

Recommended model:

```swift
struct CanvasAsset: Identifiable, Codable {
    var id: UUID
    var kind: AssetKind
    var title: String
    var localFileName: String?
    var systemSymbol: String?
    var colorHex: String?
}
```

### Templates

Templates appear to be pre-arranged compositions, not special editor states.

travelclip implication:

- A template should be a list of `CanvasElement` presets plus a background.
- Applying a template should either replace a blank page or append to the current page after confirmation.
- Avoid random template behavior for production UI.

Recommended model:

```swift
struct PageTemplateDefinition: Identifiable, Codable {
    var id: String
    var title: String
    var previewAssetName: String?
    var background: CanvasBackground
    var elements: [CanvasElement]
}
```

## Important Implementation Rules

### One Canvas Model

The app should not have one canvas for home-created pages and a different canvas for notebook-created pages. The data path should be:

```text
Home New Page -> repository.createPage(in: defaultNotebook) -> CanvasEditorView(pageID)
Book New Page -> repository.createPage(in: notebookID) -> CanvasEditorView(pageID)
Existing Page -> CanvasEditorView(pageID)
```

The editor must always render `page.canvasDocument`.

### Fixed Canvas Size

Use a stable document coordinate system, for example:

```swift
CanvasDocument.canvasSize = CGSize(width: 1080, height: 1920)
```

Display scale is a view concern:

```swift
scale = min(availableWidth / canvasWidth, availableHeight / canvasHeight)
```

Do not resize `canvasSize` when the editor appears. Otherwise two different entry points can produce different stored geometry.

### Shared Rendering

Use the same renderer for:

- Editor canvas
- Notebook row thumbnail
- Home preview
- Export/share preview

The thumbnail should only change scale and frame, not reimplement element layout.

### Relative Asset Paths

Persist photo elements like:

```swift
localPath = "92AF...jpg"
```

Resolve at render time:

```swift
Documents/TravelClipAssets/92AF...jpg
```

Keep compatibility for old absolute paths by checking whether the old file exists first, then falling back to `lastPathComponent`.

## travelclip Gaps

Current strong foundations:

- `TravelNotebook`, `JournalPage`, `CanvasDocument`, `CanvasElement` are already close to the needed model.
- The editor already has canvas, elements, transform controls, undo/redo, layers, and asset insertion.
- User photo persistence exists.

Priority gaps:

1. Replace random tools with browseable panels.
2. Add a proper template picker.
3. Add a sticker picker with categories.
4. Add a background picker with paper styles.
5. Add a tape picker.
6. Add page preview/export using the shared renderer.
7. Add mood/day metadata only after canvas flows are stable.

## Recommended Build Plan

### Phase 1: Stabilize Core Canvas

- Fixed `1080 x 1920` canvas.
- One editor route.
- Shared renderer for editor and thumbnails.
- Relative photo paths.
- Existing canvas migration.

### Phase 2: Asset Panels

- Replace random sticker/tape/background actions with horizontal pickers.
- Add local built-in asset definitions.
- Use system symbols and generated/simple vector-like SwiftUI elements first.

### Phase 3: Templates

- Create `PageTemplateDefinition`.
- Add a template picker sheet.
- Add "replace blank page" and "append to current page" behaviors.

### Phase 4: View / Export Mode

- Add `PagePreviewView`.
- Add export to image.
- Add share sheet.

### Phase 5: Diary Layer

- Add date, mood, location, tags to `JournalPage`.
- Add calendar view.
- Add notebook/day filtering.

## Non-Goals

- Do not copy Mininote's proprietary art, stickers, templates, icons, or exact visual identity.
- Do not inspect private app binaries or bypass App Store protection.
- Do not call private APIs or scrape protected service endpoints.

