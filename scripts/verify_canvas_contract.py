#!/usr/bin/env python3
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT_VIEW = ROOT / "travelclip" / "ContentView.swift"


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def require(pattern: str, source: str, message: str) -> None:
    if not re.search(pattern, source, re.MULTILINE | re.DOTALL):
        fail(message)


def forbid(pattern: str, source: str, message: str) -> None:
    if re.search(pattern, source, re.MULTILINE | re.DOTALL):
        fail(message)


def main() -> None:
    source = CONTENT_VIEW.read_text(encoding="utf-8")

    forbid(r"CanvasScrollContainer", source, "CanvasWorkspace must not use the legacy UIScrollView zoom container.")
    forbid(r"FittingScrollView", source, "Legacy fitting scroll view must stay removed from the canvas path.")
    forbid(r"UIScrollViewDelegate", source, "Canvas zoom/pan must not be delegated to UIScrollView.")

    require(r"struct\s+CanvasViewportTransform", source, "CanvasViewportTransform is required for stable viewport/document coordinate mapping.")
    require(r"func\s+displayPoint\(_\s+point:\s+CGPoint\)", source, "CanvasViewportTransform must map document points to display points.")
    require(r"func\s+documentPoint\(_\s+point:\s+CGPoint\)", source, "CanvasViewportTransform must map display points back to document points.")
    require(r"viewportTransform\.displayElement\(renderedElement\)", source, "Canvas elements must render through the shared viewport transform.")
    require(r"viewportTransform\.documentPoint\(location\)", source, "Connector endpoint dragging must convert display coordinates through the shared viewport transform.")
    require(r"transform:\s*CanvasViewportTransform", source, "Canvas capture overlays must receive the shared viewport transform.")

    workspace_block = re.search(r"private struct CanvasWorkspace: View \{(?P<body>.*?)\n\}\n\nprivate struct CanvasSurface", source, re.DOTALL)
    if not workspace_block:
        fail("CanvasWorkspace not found.")
    workspace = workspace_block.group("body")
    require(r"@State\s+private\s+var\s+viewportSize:\s*CGSize\s*=\s*\.zero", workspace, "CanvasWorkspace must own a measured viewportSize state.")
    require(r"private\s+var\s+displaySize:\s*CGSize\s*\{(?P<body>.*?)return\s+viewportSize", workspace, "CanvasWorkspace displaySize must resolve to the measured viewportSize.")
    require(r"CanvasViewportTransform\(documentSize:\s*document\.canvasSize\.cgSize,\s*viewportSize:\s*displaySize\)", workspace, "CanvasWorkspace must map document coordinates into the fixed displaySize viewport.")
    require(r"updateViewportSize\(proxy\.size\)", workspace, "CanvasWorkspace must measure the visible GeometryReader viewport.")
    require(r"canvasBody\s*\n\s*\.frame\(width:\s*displaySize\.width,\s*height:\s*displaySize\.height\)", workspace, "Canvas body must be pinned to displaySize.")
    require(r"CanvasSurface\(background:\s*document\.background\)\s*\n\s*\.frame\(width:\s*displaySize\.width,\s*height:\s*displaySize\.height\)", workspace, "Canvas surface must render at displaySize, not document size.")
    require(r"\.coordinateSpace\(name:\s*\"canvasSpace\"\)", workspace, "CanvasWorkspace must keep gestures in a stable canvas coordinate space.")
    forbid(r"CanvasScrollContainer|UIScrollView|ScrollView\s*\(", workspace, "CanvasWorkspace must not wrap the editor canvas in a scroll or zoom container.")
    forbid(r"\.scaleEffect\(", workspace, "CanvasWorkspace must not scale the whole canvas view.")

    brush_block = re.search(r"private struct BrushCaptureOverlay: View \{(?P<body>.*?)\n\}", source, re.DOTALL)
    if not brush_block:
        fail("BrushCaptureOverlay not found.")
    forbid(r"/\s*scale|\*\s*scale", brush_block.group("body"), "BrushCaptureOverlay must not directly divide or multiply by a single scale.")

    arrow_block = re.search(r"private struct ArrowCaptureOverlay: View \{(?P<body>.*?)\n\}", source, re.DOTALL)
    if not arrow_block:
        fail("ArrowCaptureOverlay not found.")
    forbid(r"/\s*scale|\*\s*scale", arrow_block.group("body"), "ArrowCaptureOverlay must not directly divide or multiply by a single scale.")

    require(r"enum\s+InteractionTelemetry", source, "InteractionTelemetry is required for button tap diagnostics.")
    require(r"struct\s+TrackedEditorToolButton", source, "TrackedEditorToolButton is required for editor button feedback and diagnostics.")
    require(r"InteractionTelemetry\.logTap", source, "Tracked editor buttons must log tap component IDs and locations.")
    require(r"InteractionTelemetry\.feedback", source, "Tracked editor buttons must provide user feedback for taps.")
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

    top_tool_block = re.search(r"private struct EditorTopTool: View \{(?P<body>.*?)\n\}", source, re.DOTALL)
    if not top_tool_block:
        fail("EditorTopTool not found.")
    forbid(r"\.disabled\(", top_tool_block.group("body"), "EditorTopTool must not use SwiftUI disabled because disabled taps need telemetry.")

    for misleading_icon in [
        r"toolButton\(\"line\.3\.horizontal\",\s*\"Background\"",
        r"toolButton\(\"textformat\.alt\",\s*\"ArtStyle\"",
        r"toolButton\(\"rectangle\.fill\.on\.rectangle\.fill\",\s*\"Texture\"",
    ]:
        forbid(misleading_icon, source, f"Misleading icon mapping remains: {misleading_icon}")

    print("Canvas and interaction contract verification passed.")


if __name__ == "__main__":
    main()
