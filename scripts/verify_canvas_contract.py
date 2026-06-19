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
