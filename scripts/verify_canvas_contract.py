#!/usr/bin/env python3
import re
import sys
import os
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[1]
CONTENT_VIEW = Path(os.environ.get("TRAVELCLIP_CONTENT_VIEW", ROOT / "travelclip" / "ContentView.swift")).resolve()
TRAVEL_MODELS = Path(os.environ.get("TRAVELCLIP_TRAVEL_MODELS", ROOT / "travelclip" / "TravelModels.swift")).resolve()
NOTEBOOK_REPOSITORY = Path(os.environ.get("TRAVELCLIP_NOTEBOOK_REPOSITORY", ROOT / "travelclip" / "NotebookRepository.swift")).resolve()


failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def require(pattern: str, source: str, message: str) -> None:
    if not re.search(pattern, source, re.MULTILINE | re.DOTALL):
        fail(message)


def forbid(pattern: str, source: str, message: str) -> None:
    if re.search(pattern, source, re.MULTILINE | re.DOTALL):
        fail(message)


def require_direct_buttons_are_menu_tracked(source: str) -> None:
    lines = source.splitlines()
    for index, line in enumerate(lines):
        if not re.match(r"^\s*Button(?:\s*\(|\s*\{)", line):
            continue

        window_start = max(0, index - 14)
        window_end = min(len(lines), index + 10)
        context = "\n".join(lines[window_start:window_end])
        if "Menu {" in context and "InteractionTelemetry.recordAction" in context:
            continue
        fail(f"Direct SwiftUI Button at {CONTENT_VIEW}:{index + 1} must use TrackedEditorToolButton or recordAction inside a Menu row.")


def require_native_disabled_usage_is_safe(source: str) -> None:
    lines = source.splitlines()
    for index, line in enumerate(lines):
        if ".disabled(" not in line:
            continue

        window_start = max(0, index - 8)
        window_end = min(len(lines), index + 3)
        context = "\n".join(lines[window_start:window_end])
        if "VideoPlayer(" in context:
            continue
        fail(f"Native .disabled at {CONTENT_VIEW}:{index + 1} must not be used for app commands because disabled taps need telemetry feedback.")


def require_block(pattern: str, source: str, message: str) -> Optional[str]:
    match = re.search(pattern, source, re.DOTALL)
    if not match:
        fail(message)
        return None
    return match.group("body")


def report_and_exit() -> None:
    if failures:
        print(f"Canvas and interaction contract verification failed with {len(failures)} issue(s):")
        for index, message in enumerate(failures, start=1):
            print(f"{index}. {message}")
        sys.exit(1)
    print("Canvas and interaction contract verification passed.")


def main() -> None:
    source = CONTENT_VIEW.read_text(encoding="utf-8")
    models = TRAVEL_MODELS.read_text(encoding="utf-8")
    repository = NOTEBOOK_REPOSITORY.read_text(encoding="utf-8")

    forbid(r"CanvasScrollContainer", source, "CanvasWorkspace must not use the legacy UIScrollView zoom container.")
    forbid(r"FittingScrollView", source, "Legacy fitting scroll view must stay removed from the canvas path.")
    forbid(r"UIScrollViewDelegate", source, "Canvas zoom/pan must not be delegated to UIScrollView.")

    require(r"struct\s+CanvasViewportTransform", source, "CanvasViewportTransform is required for stable viewport/document coordinate mapping.")
    require(r"func\s+displayPoint\(_\s+point:\s+CGPoint\)", source, "CanvasViewportTransform must map document points to display points.")
    require(r"func\s+documentPoint\(_\s+point:\s+CGPoint\)", source, "CanvasViewportTransform must map display points back to document points.")
    require(r"viewportTransform\.displayElement\(renderedElement\)", source, "Canvas elements must render through the shared viewport transform.")
    require(r"viewportTransform\.documentPoint\(location\)", source, "Connector endpoint dragging must convert display coordinates through the shared viewport transform.")
    require(r"\.position\(viewportTransform\.displayPoint\(CGPoint\(x:\s*renderedElement\.x,\s*y:\s*renderedElement\.y\)\)\)", source, "Canvas element centers must be positioned through the shared viewport transform.")
    require(r"transform:\s*CanvasViewportTransform", source, "Canvas capture overlays must receive the shared viewport transform.")
    require(r"CanvasWorkspace\([\s\S]*?\)\s*\.frame\(width:\s*proxy\.size\.width,\s*height:\s*proxy\.size\.height\)", source, "CanvasWorkspace must fill the measured editor viewport instead of being reduced by tool panels.")
    require(r"ZStack\(alignment:\s*\.bottom\)[\s\S]*?CanvasWorkspace\([\s\S]*?EditorToolPanel\(", source, "Editor tool panel must overlay the fixed canvas viewport instead of resizing it.")
    forbid(r"let\s+canvasHeight\s*=|proxy\.size\.height\s*-\s*panelHeight", source, "Tool panels must not subtract from the CanvasWorkspace viewport height.")
    require(r"static\s+let\s+designCanvasSize\s*=\s*CodableSize\(width:\s*1080,\s*height:\s*1920\)", models, "CanvasDocument must define one canonical design coordinate size.")
    require(r"var\s+canvasSize\s*=\s*CanvasDocument\.designCanvasSize", models, "CanvasDocument canvasSize must default to the canonical design size.")
    require(r"canvasSize:\s*CodableSize\s*=\s*CanvasDocument\.designCanvasSize", models, "CanvasDocument initializer must default to the canonical design size.")
    require(r"decodeIfPresent\(CodableSize\.self,\s*forKey:\s*\.canvasSize\)\s*\?\?\s*CanvasDocument\.designCanvasSize", models, "CanvasDocument decoder must preserve compatibility while defaulting missing canvas size to the canonical design size.")
    require(r"current\.matches\(CanvasDocument\.designCanvasSize\)", repository, "Loaded pages must normalize stored canvas sizes to the canonical design size.")
    forbid(r"CodableSize\(width:\s*1080,\s*height:\s*1920\)", repository, "Repository code must use CanvasDocument.designCanvasSize instead of duplicating literal canvas dimensions.")

    workspace = require_block(r"private struct CanvasWorkspace: View \{(?P<body>.*?)\n\}\n\nprivate struct CanvasSurface", source, "CanvasWorkspace not found.")
    if workspace is not None:
        require(r"@State\s+private\s+var\s+viewportSize:\s*CGSize\s*=\s*\.zero", workspace, "CanvasWorkspace must own a measured viewportSize state.")
        require(r"private\s+var\s+displaySize:\s*CGSize\s*\{(?P<body>.*?)return\s+viewportSize", workspace, "CanvasWorkspace displaySize must resolve to the measured viewportSize.")
        require(r"CanvasViewportTransform\(documentSize:\s*document\.canvasSize\.cgSize,\s*viewportSize:\s*displaySize\)", workspace, "CanvasWorkspace must map document coordinates into the fixed displaySize viewport.")
        require(r"updateViewportSize\(proxy\.size\)", workspace, "CanvasWorkspace must measure the visible GeometryReader viewport.")
        require(r"canvasBody\s*\n\s*\.frame\(width:\s*displaySize\.width,\s*height:\s*displaySize\.height\)", workspace, "Canvas body must be pinned to displaySize.")
        require(r"CanvasSurface\(background:\s*document\.background\)\s*\n\s*\.frame\(width:\s*displaySize\.width,\s*height:\s*displaySize\.height\)", workspace, "Canvas surface must render at displaySize, not document size.")
        require(r"\.coordinateSpace\(name:\s*\"canvasSpace\"\)", workspace, "CanvasWorkspace must keep gestures in a stable canvas coordinate space.")
        forbid(r"CanvasScrollContainer|UIScrollView|ScrollView\s*\(", workspace, "CanvasWorkspace must not wrap the editor canvas in a scroll or zoom container.")
        forbid(r"\.scaleEffect\(", workspace, "CanvasWorkspace must not scale the whole canvas view.")

    brush = require_block(r"private struct BrushCaptureOverlay: View \{(?P<body>.*?)\n\}", source, "BrushCaptureOverlay not found.")
    if brush is not None:
        require(r"DragGesture\(minimumDistance:\s*3,\s*coordinateSpace:\s*\.named\(\"canvasSpace\"\)\)", brush, "BrushCaptureOverlay must capture gestures in the shared canvas coordinate space.")
        forbid(r"/\s*scale|\*\s*scale", brush, "BrushCaptureOverlay must not directly divide or multiply by a single scale.")

    arrow = require_block(r"private struct ArrowCaptureOverlay: View \{(?P<body>.*?)\n\}", source, "ArrowCaptureOverlay not found.")
    if arrow is not None:
        require(r"DragGesture\(minimumDistance:\s*6,\s*coordinateSpace:\s*\.named\(\"canvasSpace\"\)\)", arrow, "ArrowCaptureOverlay must capture gestures in the shared canvas coordinate space.")
        forbid(r"/\s*scale|\*\s*scale", arrow, "ArrowCaptureOverlay must not directly divide or multiply by a single scale.")

    transform = require_block(r"private struct CanvasViewportTransform \{(?P<body>.*?)\n\}", source, "CanvasViewportTransform not found.")
    if transform is not None:
        display_element = require_block(r"func\s+displayElement\(_\s+element:\s+CanvasElement\)\s*->\s*CanvasElement\s*\{(?P<body>.*?)\n    \}", transform, "CanvasViewportTransform.displayElement not found.")
        if display_element is not None:
            forbid(r"copy\.x\s*\*=|copy\.y\s*\*=", display_element, "CanvasViewportTransform.displayElement must not scale element centers because parent positioning uses displayPoint.")

    require(r"enum\s+InteractionTelemetry", source, "InteractionTelemetry is required for button tap diagnostics.")
    require(r"struct\s+TrackedEditorToolButton", source, "TrackedEditorToolButton is required for editor button feedback and diagnostics.")
    require(r"InteractionTelemetry\.logTap", source, "Tracked editor buttons must log tap component IDs and locations.")
    require(r"InteractionTelemetry\.feedback", source, "Tracked editor buttons must provide user feedback for taps.")
    require(r"InteractionTelemetry\.recordAction", source, "Non-wrapper actions such as menu rows must record telemetry and feedback.")
    require_direct_buttons_are_menu_tracked(source)
    require_native_disabled_usage_is_safe(source)
    require(r"componentID:\s*\"editor\.tool\.", source, "Editor tool buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"editor\.align\.", source, "Editor alignment buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"editor\.top\.", source, "Editor top bar buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"floating\.selection\.", source, "Floating selection toolbar buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.toolstrip\.", source, "Canvas active tool strip buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.line\.", source, "Canvas line style buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.tape\.length\.", source, "Canvas tape length buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.shape\.", source, "Canvas shape style buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.layer\.", source, "Canvas layer row buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.text\.", source, "Text editor sheet buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.link\.", source, "Link editor sheet buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.note\.", source, "Note editor sheet buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.ticket\.", source, "Ticket composer sheet buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.rename\.", source, "Rename sheet buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.new-page\.", source, "New page sheet buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"store\.home\.category\.", source, "Store home category buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"store\.home\.search\.clear\"", source, "Store home search clear button must have telemetry.")
    require(r"componentID:\s*\"asset\.sheet\.done\"", source, "Asset picker done button must have telemetry.")
    require(r"componentID:\s*\"asset\.template\.", source, "Template picker cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.text-preset\.", source, "Text preset cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.brush-preset\.", source, "Brush preset cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.material\.", source, "Material cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.material-shelf\.", source, "Material shelf cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.sticker\.", source, "Sticker cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.shape\.", source, "Shape cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.background\.", source, "Background cards must have stable telemetry component IDs.")
    require(r"componentID:\s*\"asset\.tape\.", source, "Tape cards and category controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"material\.panel\.open-store\"", source, "Material panel store button must have telemetry.")
    require(r"componentID:\s*\"material\.panel\.category\.", source, "Material panel category buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"material\.panel\.search\.clear\"", source, "Material panel search clear button must have telemetry.")
    require(r"componentID:\s*\"material\.store\.category\.", source, "Material store category buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"material\.store\.search\.clear\"", source, "Material store search clear button must have telemetry.")
    require(r"componentID:\s*\"notebook\.detail\.", source, "Notebook detail controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"notebook\.page\.", source, "Notebook page cards and menu actions must have stable telemetry component IDs.")
    require(r"componentID:\s*\"page\.preview\.", source, "Page preview controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"presentation\.", source, "Presentation controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.tape\.placement\.", source, "Tape placement controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.notebook-edit\.", source, "Notebook edit sheet controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.notebook-picker\.", source, "Notebook picker sheet controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.new-notebook\.", source, "New notebook sheet controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.header\.", source, "Home header controls must have telemetry, including placeholder actions.")
    require(r"componentID:\s*\"home\.search\.", source, "Home search/location controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.place-search\.", source, "Place search sheet controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.create\.", source, "Home create buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.notebook\.", source, "Home notebook controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.location\.", source, "Location sticker shelf controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"root\.tab\.", source, "Root tab controls must have stable telemetry component IDs.")
    require(r"recordAction\(componentID:\s*\"home\.header\..*\.placeholder\"", source, "Placeholder header actions must explicitly log disabled telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.detail\.export\.pdf\"", source, "Notebook PDF export menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.detail\.export\.zip\"", source, "Notebook ZIP export menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.page\.rename\.", source, "Page rename menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.page\.cover\.", source, "Page cover menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.page\.delete\.", source, "Page delete menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"page\.preview\.export\.image\"", source, "Page image export menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"page\.preview\.export\.pdf\"", source, "Page PDF export menu action must record telemetry.")

    top_tool = require_block(r"private struct EditorTopTool: View \{(?P<body>.*?)\n\}", source, "EditorTopTool not found.")
    if top_tool is not None:
        forbid(r"\.disabled\(", top_tool, "EditorTopTool must not use SwiftUI disabled because disabled taps need telemetry.")

    for misleading_icon in [
        r"toolButton\(\"line\.3\.horizontal\",\s*\"Background\"",
        r"toolButton\(\"textformat\.alt\",\s*\"WordArt\"",
        r"toolButton\(\"textformat\.alt\",\s*\"ArtStyle\"",
        r"toolButton\(\"rectangle\.fill\.on\.rectangle\.fill\",\s*\"Texture\"",
        r"preset\.kind\s*==\s*\.wordArt\s*\?\s*\"textformat\.alt\"",
        r"case\s+\.wordArt:\s+return\s+\"textformat\.alt\"",
    ]:
        forbid(misleading_icon, source, f"Misleading icon mapping remains: {misleading_icon}")

    expected_icon_mappings = [
        (r"toolButton\(\"paintpalette\",\s*\"Background\"", "Background tool must use a palette icon."),
        (r"toolButton\(\"textformat\.size\",\s*\"WordArt\"", "WordArt tool must use the text sizing icon."),
        (r"preset\.kind\s*==\s*\.wordArt\s*\?\s*\"textformat\.size\"", "WordArt preset cards must use the text sizing icon."),
        (r"toolButton\(\"wand\.and\.stars\",\s*\"ArtStyle\"", "ArtStyle tool must use the wand icon."),
        (r"toolButton\(\"rectangle\.on\.rectangle\.angled\",\s*\"Texture\"", "Texture tool must use a layered texture icon."),
        (r"case\s+\.adjust:\s+return\s+\"dial\.medium\"", "Adjust shelf must use a tuning dial icon."),
        (r"case\s+\.wordArt:\s+return\s+\"textformat\.size\"", "WordArt category and element icons must use the text sizing icon."),
    ]
    for pattern, message in expected_icon_mappings:
        require(pattern, source, message)

    report_and_exit()


if __name__ == "__main__":
    main()
