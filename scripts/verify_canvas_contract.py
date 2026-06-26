#!/usr/bin/env python3
import re
import sys
import os
import math
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[1]
CONTENT_VIEW = Path(os.environ.get("TRAVELCLIP_CONTENT_VIEW", ROOT / "travelclip" / "ContentView.swift")).resolve()
TRAVEL_MODELS = Path(os.environ.get("TRAVELCLIP_TRAVEL_MODELS", ROOT / "travelclip" / "TravelModels.swift")).resolve()
NOTEBOOK_REPOSITORY = Path(os.environ.get("TRAVELCLIP_NOTEBOOK_REPOSITORY", ROOT / "travelclip" / "NotebookRepository.swift")).resolve()
PAGE_TEMPLATES = Path(os.environ.get("TRAVELCLIP_PAGE_TEMPLATES", ROOT / "travelclip" / "PageTemplates.swift")).resolve()
PAGE_TEMPLATE_APPLIER = Path(os.environ.get("TRAVELCLIP_PAGE_TEMPLATE_APPLIER", ROOT / "travelclip" / "PageTemplateApplier.swift")).resolve()
MATERIAL_GROUPS = Path(os.environ.get("TRAVELCLIP_MATERIAL_GROUPS", ROOT / "travelclip" / "Resources" / "MaterialGroups")).resolve()
MATERIAL_MANIFEST = Path(os.environ.get("TRAVELCLIP_MATERIAL_MANIFEST", MATERIAL_GROUPS / "material-manifest.txt")).resolve()
MATERIAL_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}


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


def require_no_noop_tracked_actions(source: str) -> None:
    lines = source.splitlines()
    for index, line in enumerate(lines):
        if "TrackedEditorToolButton" not in line or "action: {}" not in line:
            continue

        if 'disabled: true' in line:
            continue
        fail(f"TrackedEditorToolButton at {CONTENT_VIEW}:{index + 1} must not have an empty action unless it is explicitly disabled.")


def require_native_photo_pickers_are_tracked(source: str) -> None:
    picker_count = len(re.findall(r"\bPhotosPicker\s*\(", source))
    telemetry_count = len(re.findall(r"recordAction\(componentID:\s*\"(?:editor\.tool\.picture\.picker|sheet\.new-notebook\.cover\.picker|sheet\.quick-clip\.photo)\"", source))
    if picker_count != telemetry_count:
        fail("Every native PhotosPicker path must record telemetry with a stable component ID when a selection is made.")


def split_template_blocks(page_templates: str) -> list[tuple[str, str]]:
    marker = "PageTemplateDefinition("
    blocks: list[tuple[str, str]] = []
    search_start = 0
    while True:
        start = page_templates.find(marker, search_start)
        if start == -1:
            break

        depth = 0
        end = start
        for index in range(start, len(page_templates)):
            char = page_templates[index]
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
        block = page_templates[start:end]
        id_match = re.search(r'id:\s*"([^"]+)"', block)
        blocks.append((id_match.group(1) if id_match else f"template@{start}", block))
        search_start = end
    return blocks


def canvas_element_blocks(template_block: str) -> list[str]:
    marker = "CanvasElement("
    blocks: list[str] = []
    search_start = 0
    while True:
        start = template_block.find(marker, search_start)
        if start == -1:
            break
        depth = 0
        end = start
        for index in range(start, len(template_block)):
            char = template_block[index]
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
        blocks.append(template_block[start:end])
        search_start = end
    return blocks


def argument_string(block: str, name: str) -> Optional[str]:
    match = re.search(rf'{name}:\s*"([^"]*)"', block, re.DOTALL)
    return match.group(1) if match else None


def argument_number(block: str, name: str) -> Optional[float]:
    match = re.search(rf'{name}:\s*(-?\d+(?:\.\d+)?)', block)
    return float(match.group(1)) if match else None


def is_text_element(block: str) -> bool:
    return "kind: .text" in block or "kind: .wordArt" in block


def line_count(text: str) -> int:
    return max(text.count(r"\n") + 1, 1)


def element_bounds(block: str) -> tuple[float, float, float, float]:
    x = argument_number(block, "x") or 0
    y = argument_number(block, "y") or 0
    width = argument_number(block, "width") or 0
    height = argument_number(block, "height") or 0
    rotation = abs(argument_number(block, "rotation") or 0) * math.pi / 180
    bounds_width = abs(width * math.cos(rotation)) + abs(height * math.sin(rotation))
    bounds_height = abs(width * math.sin(rotation)) + abs(height * math.cos(rotation))
    padding = 8
    return (
        x - bounds_width / 2 - padding,
        y - bounds_height / 2 - padding,
        x + bounds_width / 2 + padding,
        y + bounds_height / 2 + padding
    )


def overlap_ratio(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> float:
    width = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    height = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    intersection = width * height
    if intersection <= 0:
        return 0

    area_a = max(0, a[2] - a[0]) * max(0, a[3] - a[1])
    area_b = max(0, b[2] - b[0]) * max(0, b[3] - b[1])
    return intersection / max(min(area_a, area_b), 1)


def relative_luminance(hex_color: str) -> float:
    value = hex_color.strip("#")
    if len(value) != 6:
        return 1

    channels = [int(value[index:index + 2], 16) / 255 for index in (0, 2, 4)]

    def linearize(channel: float) -> float:
        return channel / 12.92 if channel <= 0.03928 else ((channel + 0.055) / 1.055) ** 2.4

    red, green, blue = [linearize(channel) for channel in channels]
    return red * 0.2126 + green * 0.7152 + blue * 0.0722


def contrast_ratio(foreground: str, background: str) -> float:
    lighter, darker = sorted([relative_luminance(foreground), relative_luminance(background)], reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def is_body_text_element(block: str) -> bool:
    if "kind: .wordArt" in block:
        return False
    text = argument_string(block, "text") or ""
    return "\\n" in text or "/" in text or "____" in text or "01" in text or len(text) > 18


def template_tag_text(block: str) -> str:
    match = re.search(r"tags:\s*\[([^\]]*)\]", block, re.DOTALL)
    if not match:
        return ""
    return " ".join(re.findall(r'"([^"]+)"', match.group(1))).lower()


def asset_tokens(path: str) -> set[str]:
    normalized = path.lower()
    normalized = re.sub(r"[^0-9a-z\u4e00-\u9fff]+", " ", normalized)
    return {token for token in normalized.split() if len(token) >= 2}


def semantic_asset_matches_template(local_path: str, template_tags: str, template_block: str) -> bool:
    if "country-global" in local_path:
        return True

    tokens = asset_tokens(local_path)
    template_text = template_tags + " " + template_block.lower()
    return any(token in template_text for token in tokens if token not in {"country", "city", "cat", "lat", "lng", "name", "tags", "sticker", "png"})


def count_templates_matching(template_blocks: list[tuple[str, str]], *tokens: str) -> int:
    normalized_tokens = [token.lower() for token in tokens]
    count = 0
    for _, block in template_blocks:
        tag_text = template_tag_text(block)
        if any(token in tag_text for token in normalized_tokens):
            count += 1
    return count


def material_image_files() -> list[Path]:
    if os.environ.get("SCRIPT_INPUT_FILE_COUNT") and MATERIAL_MANIFEST.exists():
        return [
            MATERIAL_GROUPS / line.strip()
            for line in MATERIAL_MANIFEST.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#") and Path(line.strip()).suffix.lower() in MATERIAL_IMAGE_EXTENSIONS
        ]

    if not MATERIAL_GROUPS.exists():
        return []
    images = sorted(path for path in MATERIAL_GROUPS.rglob("*") if path.is_file() and path.suffix.lower() in MATERIAL_IMAGE_EXTENSIONS)
    empty_images = [path.relative_to(MATERIAL_GROUPS).as_posix() for path in images if path.stat().st_size == 0]
    for image in empty_images:
        fail(f"Material image asset is empty: {image}")
    return images


def verify_global_common_materials(content: str) -> None:
    images = material_image_files()
    global_common_images: list[Path] = []
    for path in images:
        relative_path = path.relative_to(MATERIAL_GROUPS).as_posix().lower()
        filename = path.name.lower()
        is_global = relative_path.startswith("global/") or "country-global__" in filename
        is_common_or_basic = (
            "/common" in relative_path
            or "/figma-basic/" in relative_path
            or "/travel-basic/" in relative_path
            or "__city-travel-basic__" in filename
            or re.search(r"__cat-(?:common|basic|sticker|background)__", filename) is not None
        )
        if is_global and is_common_or_basic:
            global_common_images.append(path)

    group_ids = {
        path.parent.relative_to(MATERIAL_GROUPS).as_posix()
        for path in global_common_images
    }
    if not group_ids:
        fail("Material Store must have at least one bundled global common/basic material group.")
        return

    if not any(path.name.lower().startswith("country-global__") for path in global_common_images):
        fail("Global common/basic materials must use country-global filenames so they remain visible outside city context.")
    if not any("__cat-sticker__" in path.name.lower() or "/travel-icons/" in path.as_posix().lower() for path in global_common_images):
        fail("Global common/basic materials must keep at least one reusable travel icon or sticker.")
    if not any("__cat-background__" in path.name.lower() for path in global_common_images):
        fail("Global common/basic materials must keep at least one reusable background.")

    require(r'MaterialCategoryOption\(id:\s*"common"', content, "Material Store must expose a Common category for global materials.")
    require(r'item\.country\.locationKey\s*==\s*"global"', content, "Common material filtering must include country-global assets.")


def verify_page_template_quality(page_templates: str, applier: str, content: str) -> None:
    if not PAGE_TEMPLATES.exists():
        fail("PageTemplates.swift is required for built-in template quality verification.")
        return

    template_blocks = split_template_blocks(page_templates)
    if len(template_blocks) < 10:
        fail("Built-in page templates must include a meaningful commercial starter library, not only a placeholder set.")

    if MATERIAL_MANIFEST.exists():
        available_assets = {
            line.strip()
            for line in MATERIAL_MANIFEST.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#")
        }
    else:
        available_assets = {path.name for path in MATERIAL_GROUPS.rglob("*") if path.is_file()} if MATERIAL_GROUPS.exists() else set()
    if not available_assets:
        fail("Template material assets were not found under Resources/MaterialGroups.")

    if count_templates_matching(template_blocks, "before-travel", "plan") < 2:
        fail("Template library must include at least two before-travel planning templates.")
    if count_templates_matching(template_blocks, "during-travel", "route-flow", "city-walk") < 4:
        fail("Template library must include a strong set of during-travel route templates.")
    if count_templates_matching(template_blocks, "after-travel", "memory", "keepsake", "share-card") < 2:
        fail("Template library must include at least two after-travel memory or sharing templates.")
    if count_templates_matching(template_blocks, "city-log", "city-card", "city-walk") < 4:
        fail("Template library must include enough city-specific templates to feel commercial.")
    required_workflows = {
        "packing-check": "a pre-trip packing/checklist template",
        "day-one-route": "a Day 1 route template",
        "city-walk": "a city walk template",
        "restaurant-log": "a restaurant or food log template",
        "trip-recap": "an after-trip recap template",
    }
    for tag, description in required_workflows.items():
        if count_templates_matching(template_blocks, tag) < 1:
            fail(f"Template library must include {description}.")

    for template_id, block in template_blocks:
        element_blocks = canvas_element_blocks(block)
        text_blocks = [element for element in element_blocks if is_text_element(element)]
        body_text_blocks = [element for element in text_blocks if is_body_text_element(element)]
        if len(text_blocks) < 5:
            fail(f"Template '{template_id}' must contain enough editable text structure to feel like a usable travel layout.")

        workflow_text = " ".join(argument_string(element, "text") or "" for element in text_blocks).lower()
        template_tags = template_tag_text(block)
        if not re.search(r"(?:\b01\b|stop\s*01|route|flow|步骤|路线|行程)", workflow_text):
            fail(f"Template '{template_id}' needs a visible travel flow marker such as 01/02/03, stop 01, route, or 路线.")
        if not re.search(r"\b(before-travel|during-travel|after-travel)\b", template_tags):
            fail(f"Template '{template_id}' must declare when it is used: before-travel, during-travel, or after-travel.")
        if not re.search(r"\b(plan|route-flow|memory|city-log|city-card|city-walk|food-memory|fieldbook|ticket-log|share-card)\b", template_tags):
            fail(f"Template '{template_id}' must declare a commercial use-case tag such as plan, route-flow, memory, city-log, or city-card.")

        image_blocks = [element for element in element_blocks if "kind: .image" in element]
        placeholder_count = len([element for element in image_blocks if "localPath:" not in element])
        local_material_count = len([element for element in image_blocks if "localPath:" in element])
        semantic_material_count = len([
            element
            for element in image_blocks
            if (local_path := argument_string(element, "localPath")) and semantic_asset_matches_template(local_path, template_tags, block)
        ])
        if placeholder_count < 2:
            fail(f"Template '{template_id}' should provide at least two replaceable image areas for a shareable travel page.")
        if local_material_count < 1:
            fail(f"Template '{template_id}' should include at least one intentional bundled travel material instead of only generic symbols.")
        if semantic_material_count < 1:
            fail(f"Template '{template_id}' must use at least one bundled material that matches the city or travel task.")

        commercial_score = 0
        commercial_score += min(len(text_blocks), 8)
        commercial_score += min(placeholder_count, 3) * 2
        commercial_score += min(local_material_count, 3)
        commercial_score += 2 if re.search(r"\b(before-travel|during-travel|after-travel)\b", template_tags) else 0
        commercial_score += 2 if re.search(r"\b(packing-check|day-one-route|restaurant-log|trip-recap|route-flow|city-walk|share-card)\b", template_tags) else 0
        commercial_score += 2 if semantic_material_count >= 1 else 0
        if commercial_score < 17:
            fail(f"Template '{template_id}' commercial quality score is too low ({commercial_score}); add stronger structure, photo frames, or semantic materials.")

        for element in element_blocks:
            local_path = argument_string(element, "localPath")
            if local_path and local_path not in available_assets:
                fail(f"Template '{template_id}' references missing material asset: {local_path}")

            if not is_text_element(element):
                continue

            text = argument_string(element, "text") or ""
            width = argument_number(element, "width") or 0
            height = argument_number(element, "height") or 0
            font_size = argument_number(element, "fontSize") or 72
            lines = line_count(text)
            estimated_min_height = font_size * (1.18 if "kind: .wordArt" in element else 1.24) * lines + max(14, font_size * 0.25)

            if width < 120:
                fail(f"Template '{template_id}' has an overly narrow text box that is likely to clip: {text[:32]}")
            if height < estimated_min_height * 0.72:
                fail(f"Template '{template_id}' text box is too short for its font and line count: {text[:48]}")
            if "kind: .wordArt" in element and font_size > 84:
                fail(f"Template '{template_id}' wordArt font size must stay at or below 84 for mobile readability: {text[:32]}")
            if "kind: .wordArt" in element and height < font_size * 1.35:
                fail(f"Template '{template_id}' wordArt height must leave room for descenders and rotation: {text[:32]}")

            background_hex = argument_string(element, "backgroundHex")
            if is_body_text_element(element) and background_hex is None:
                fail(f"Template '{template_id}' body text must have a background for reliable readability: {text[:48]}")
            if background_hex is not None:
                ratio = contrast_ratio(argument_string(element, "colorHex") or "#000000", background_hex)
                threshold = 3.0 if font_size >= 30 or "kind: .wordArt" in element else 4.5
                if ratio < threshold:
                    fail(f"Template '{template_id}' text contrast is too low ({ratio:.2f}) for: {text[:48]}")

        for first_index, first in enumerate(body_text_blocks):
            first_bounds = element_bounds(first)
            for second in body_text_blocks[first_index + 1:]:
                ratio = overlap_ratio(first_bounds, element_bounds(second))
                if ratio > 0.16:
                    first_text = (argument_string(first, "text") or "")[:32]
                    second_text = (argument_string(second, "text") or "")[:32]
                    fail(f"Template '{template_id}' has overlapping body text blocks: {first_text} <> {second_text}")

    require(r"static\s+func\s+polishedElements\(for\s+template:\s+PageTemplateDefinition\)\s*->\s*\[CanvasElement\]", applier, "Templates must pass through a reusable quality polish step before preview and application.")
    require(r"copy\.height\s*=\s*minimumHeight", applier, "Template polish must expand text frames that are too short.")
    require(r"copy\.fontSize\s*=\s*min\(copy\.fontSize,\s*84\)", applier, "Template polish must cap oversized wordArt.")
    require(r"readabilityAdjustedFontSize\(for:\s*copy,\s*text:\s*text,\s*lineCount:\s*lines\)", applier, "Template polish must shrink long text before it can clip or overlap.")
    require(r"relativeLuminance\(background\.colorA\).*relativeLuminance\(background\.colorB\)", applier, "Template wordArt shadow color must account for background brightness.")
    require(r"luminance\s*<\s*0\.34\s*\?\s*\"#111820\"\s*:\s*\"#FFF8EA\"", applier, "Template wordArt must use a dark shadow on dark backgrounds and a light paper shadow on light backgrounds.")
    require(r"first\(where:\s*\\\.isTemplateStarterElement\)", applier, "Applying a template must select the first replaceable photo area so users know where to start.")
    require(r"copy\.editHint\s*=\s*\"Tap to replace photo\"", applier, "Template photo placeholders must carry an explicit replacement hint.")
    require(r"PageTemplateApplier\.polishedElements\(for:\s*template\)", content, "Template preview must use the same polished elements as applied templates.")
    require(r"showStarterHintIfNeeded", content, "Editor must show a starter hint after applying or opening a template with a selected photo placeholder.")
    require(r"Template applied\. Start by replacing the selected photo\.", content, "Applying a template inside the editor must tell users the next editing step.")
    require(r"CanvasPreviewContent[\s\S]*CanvasElementView\(element:\s*previewTransform\.displayElement\(element\)", content, "Template previews must render with the same CanvasElementView path as the editor.")
    require(r"let\s+onEditElement:\s*\(UUID\)\s*->\s*Void", content, "CanvasWorkspace must expose direct element editing for double-tapped template text.")
    require(r"\.onTapGesture\(count:\s*2,\s*coordinateSpace:\s*\.named\(\"canvasSpace\"\)\)", content, "Canvas text elements must support double-tap editing.")
    require(r"if\s+element\.isTextElement\s*&&\s*!element\.locked[\s\S]*onEditElement\(element\.id\)", content, "Double-tap editing must only open editable text or wordArt elements.")
    require(r"case\s+plan", content, "Template Center must expose a planning category for before-travel templates.")
    require(r"case\s+route", content, "Template Center must expose a route category for travel flow templates.")
    require(r"case\s+memory", content, "Template Center must expose a memory category for after-travel templates.")
    require(r"travelMomentLabel", content, "Template cards must show the travel moment so users understand when to use a template.")
    require(r"templateUseCaseLabel", content, "Template cards must show a concrete use-case label instead of only a decorative title.")
    require(r"templateOutcomeLabel", content, "Template cards must explain the user outcome instead of only showing decorative metadata.")
    require(r"Text\(template\.templateOutcomeLabel\)", content, "Template cards must render the outcome label so users can judge why to use a template.")
    require(r"workflowLabel", content, "Template cards must expose a workflow label such as Day 1 Route or Restaurant Log.")
    require(r"Text\(template\.workflowLabel\)", content, "Template cards must render the workflow label for task-oriented browsing.")
    require(r"Text\(template\.marketMetadata\)", content, "Template cards must keep photo frame and location metadata visible.")
    require(r"Tap to replace photo", content, "Image placeholders must show a clear in-canvas replacement instruction.")
    styled_text = require_block(r"private struct StyledCanvasTextElement: View \{(?P<body>.*?)\n\}\n\nprivate struct CanvasViewportTransform", content, "StyledCanvasTextElement not found.")
    if styled_text is not None:
        forbid(r"LinearGradient", styled_text, "Canvas wordArt must not use gradient text because low-contrast fades are unreadable in templates.")

    text_preset_card = require_block(r"private struct TextPresetChoiceCard: View \{(?P<body>.*?)\n\}\n\nprivate struct BrushPresetPanel", content, "TextPresetChoiceCard not found.")
    if text_preset_card is not None:
        forbid(r"LinearGradient", text_preset_card, "Text preset previews must not use low-contrast gradients for wordArt.")


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
    page_templates = PAGE_TEMPLATES.read_text(encoding="utf-8") if PAGE_TEMPLATES.exists() else ""
    page_template_applier = PAGE_TEMPLATE_APPLIER.read_text(encoding="utf-8") if PAGE_TEMPLATE_APPLIER.exists() else ""

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
            require(r"copy\.width\s*\*=\s*xScale", display_element, "CanvasViewportTransform.displayElement must scale element width by xScale.")
            require(r"copy\.height\s*\*=\s*yScale", display_element, "CanvasViewportTransform.displayElement must scale element height by yScale.")
            require(r"copy\.connectorStartPoint\s*=\s*element\.connectorStartPoint\.map[\s\S]*?x:\s*point\.x\s*\*\s*xScale[\s\S]*?y:\s*point\.y\s*\*\s*yScale", display_element, "CanvasViewportTransform.displayElement must scale free connector start endpoints.")
            require(r"copy\.connectorEndPoint\s*=\s*element\.connectorEndPoint\.map[\s\S]*?x:\s*point\.x\s*\*\s*xScale[\s\S]*?y:\s*point\.y\s*\*\s*yScale", display_element, "CanvasViewportTransform.displayElement must scale free connector end endpoints.")

    display_scaled = require_block(r"func\s+displayScaled\(by\s+scale:\s+CGFloat\)\s*->\s*CanvasElement\s*\{(?P<body>.*?)\n    \}", source, "CanvasElement.displayScaled not found.")
    if display_scaled is not None:
        require(r"copy\.connectorStartPoint\s*=\s*connectorStartPoint\.map[\s\S]*?x:\s*point\.x\s*\*\s*scale[\s\S]*?y:\s*point\.y\s*\*\s*scale", display_scaled, "CanvasElement.displayScaled must scale free connector start endpoints.")
        require(r"copy\.connectorEndPoint\s*=\s*connectorEndPoint\.map[\s\S]*?x:\s*point\.x\s*\*\s*scale[\s\S]*?y:\s*point\.y\s*\*\s*scale", display_scaled, "CanvasElement.displayScaled must scale free connector end endpoints.")

    document_renderer = require_block(r"private struct CanvasDocumentRenderer: View \{(?P<body>.*?)\n\}\n\nprivate struct CanvasElementView", source, "CanvasDocumentRenderer not found.")
    if document_renderer is not None:
        require(r"renderTransform:\s*CanvasViewportTransform", document_renderer, "CanvasDocumentRenderer must render through CanvasViewportTransform.")
        require(r"CanvasViewportTransform\(documentSize:\s*document\.canvasSize\.cgSize,\s*viewportSize:\s*renderSize\)", document_renderer, "CanvasDocumentRenderer must map document coordinates into its render size.")
        require(r"renderTransform\.displayElement\(element\)", document_renderer, "CanvasDocumentRenderer elements must use displayElement.")
        require(r"\.position\(renderTransform\.displayPoint\(CGPoint\(x:\s*element\.x,\s*y:\s*element\.y\)\)\)", document_renderer, "CanvasDocumentRenderer element centers must use displayPoint.")
        forbid(r"displayScaled\(by:\s*scale\)|element\.x\s*\*\s*scale|element\.y\s*\*\s*scale", document_renderer, "CanvasDocumentRenderer must not use legacy scalar element rendering.")

    preview_content = require_block(r"private struct CanvasPreviewContent: View \{(?P<body>.*?)\n\}\n\nprivate struct HeaderView", source, "CanvasPreviewContent not found.")
    if preview_content is not None:
        require(r"previewTransform:\s*CanvasViewportTransform", preview_content, "CanvasPreviewContent must render through CanvasViewportTransform.")
        require(r"CanvasViewportTransform\(documentSize:\s*documentSize,\s*viewportSize:\s*viewportSize\)", preview_content, "CanvasPreviewContent must map document coordinates into its preview size.")
        require(r"previewTransform\.displayElement\(element\)", preview_content, "CanvasPreviewContent elements must use displayElement.")
        require(r"\.position\(previewTransform\.displayPoint\(CGPoint\(x:\s*element\.x,\s*y:\s*element\.y\)\)\)", preview_content, "CanvasPreviewContent element centers must use displayPoint.")
        forbid(r"displayScaled\(by:\s*scale\)|element\.x\s*\*\s*scale|element\.y\s*\*\s*scale", preview_content, "CanvasPreviewContent must not use legacy scalar rendering.")

    template_preview = require_block(r"private struct CanvasTemplatePreview: View \{(?P<body>.*?)\n\}\n\nprivate struct StickerChoiceCard", source, "CanvasTemplatePreview not found.")
    if template_preview is not None:
        require(r"CanvasDocument\.designCanvasSize", template_preview, "Template previews must derive their aspect ratio from the canonical design canvas size.")
        require(r"CanvasPreviewContent\(", template_preview, "Template previews must render through the shared canvas preview content.")
        require(r"documentSize:\s*CanvasDocument\.designCanvasSize\.cgSize", template_preview, "Template previews must map design coordinates into the preview size.")
        require(r"viewportSize:\s*previewSize", template_preview, "Template previews must pass the measured preview size to shared preview content.")
        forbid(r"\b1080\b|\b1920\b|displayScaled\(by:\s*scale\)|element\.x\s*\*\s*scale|element\.y\s*\*\s*scale", template_preview, "Template previews must not duplicate design dimensions or use legacy scalar rendering.")

    require(r"enum\s+InteractionTelemetry", source, "InteractionTelemetry is required for button tap diagnostics.")
    require(r"struct\s+TrackedEditorToolButton", source, "TrackedEditorToolButton is required for editor button feedback and diagnostics.")
    require(r"InteractionTelemetry\.logTap", source, "Tracked editor buttons must log tap component IDs and locations.")
    require(r"InteractionTelemetry\.logCanvasTap", source, "Canvas tap gestures must log canvas component IDs and coordinates.")
    require(r"InteractionTelemetry\.logCanvasGesture", source, "Canvas transform gestures must log stable component IDs and phases.")
    require(r"InteractionTelemetry\.feedback", source, "Tracked editor buttons must provide user feedback for taps.")
    require(r"InteractionTelemetry\.recordAction", source, "Non-wrapper actions such as menu rows must record telemetry and feedback.")
    require_direct_buttons_are_menu_tracked(source)
    require_native_disabled_usage_is_safe(source)
    require_no_noop_tracked_actions(source)
    require_native_photo_pickers_are_tracked(source)
    forbid(r"toolButton\([^)]*disabled:\s*true", source, "Editor tool rows must not include hard-coded disabled tool buttons; hide unavailable permanent controls or use state-driven disabled conditions.")
    require(r"componentID:\s*\"editor\.tool\.", source, "Editor tool buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"editor\.align\.", source, "Editor alignment buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"editor\.top\.", source, "Editor top bar buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"floating\.selection\.", source, "Floating selection toolbar buttons must have stable telemetry component IDs.")
    require(r"\.onTapGesture\(coordinateSpace:\s*\.named\(\"canvasSpace\"\)\)\s*\{\s*location\s+in[\s\S]*?recordCanvasTap\(componentID:\s*\"canvas\.surface\.deselect\"", source, "Canvas surface deselect taps must record telemetry in canvasSpace.")
    require(r"\.onTapGesture\(coordinateSpace:\s*\.named\(\"canvasSpace\"\)\)\s*\{\s*location\s+in[\s\S]*?recordCanvasTap\(componentID:\s*\"canvas\.element\.select\.\\\(element\.id\.uuidString\.lowercased\(\)\)\"", source, "Canvas element selection taps must record telemetry in canvasSpace.")
    require(r"viewportTransform\.documentPoint\(location\)", source, "Canvas tap telemetry must convert display tap coordinates to document coordinates.")
    require(r"func\s+logCanvasTap\(componentID:\s*String,\s*displayLocation:\s*CGPoint,\s*documentLocation:\s*CGPoint\)", source, "Canvas tap telemetry must include display and document locations.")
    require(r"func\s+logCanvasGesture\(componentID:\s*String,\s*phase:\s*String,\s*elementCount:\s*Int\?\s*=\s*nil\)", source, "Canvas gesture telemetry must include component ID, phase, and optional element count.")
    require(r"recordCanvasGesture\(\"canvas\.element\.move\.\\\(element\.id\.uuidString\.lowercased\(\)\)\",\s*phase:\s*\"start\"", source, "Canvas element move gestures must log start telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.element\.move\.\\\(element\.id\.uuidString\.lowercased\(\)\)\",\s*phase:\s*\"end\"", source, "Canvas element move gestures must log end telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.element\.transform\.\\\(element\.id\.uuidString\.lowercased\(\)\)\",\s*phase:\s*\"start\"", source, "Canvas element transform gestures must log start telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.element\.transform\.\\\(element\.id\.uuidString\.lowercased\(\)\)\",\s*phase:\s*\"end\"", source, "Canvas element transform gestures must log end telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.connector\.endpoint\.\\\(connector\.id\.uuidString\.lowercased\(\)\)\",\s*phase:\s*\"start\"", source, "Connector endpoint drags must log start telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.connector\.endpoint\.\\\(connector\.id\.uuidString\.lowercased\(\)\)\",\s*phase:\s*\"end\"", source, "Connector endpoint drags must log end telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.selection\.move\",\s*phase:\s*\"start\",\s*elementCount:\s*selectedElementIDs\.count\)", source, "Multi-selection move gestures must log start telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.selection\.move\",\s*phase:\s*\"end\",\s*elementCount:\s*selectedElementIDs\.count\)", source, "Multi-selection move gestures must log end telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.selection\.transform\",\s*phase:\s*\"start\",\s*elementCount:\s*selectedElementIDs\.count\)", source, "Multi-selection transform gestures must log start telemetry.")
    require(r"recordCanvasGesture\(\"canvas\.selection\.transform\",\s*phase:\s*\"end\",\s*elementCount:\s*selectedElementIDs\.count\)", source, "Multi-selection transform gestures must log end telemetry.")
    require(r"logCanvasGesture\(componentID:\s*\"canvas\.brush\.draw\",\s*phase:\s*\"start\"\)", source, "Brush drawing must log start telemetry.")
    require(r"logCanvasGesture\(componentID:\s*\"canvas\.brush\.draw\",\s*phase:\s*\"end\"\)", source, "Brush drawing must log end telemetry.")
    require(r"logCanvasGesture\(componentID:\s*\"canvas\.arrow\.draw\",\s*phase:\s*\"start\"\)", source, "Arrow drawing must log start telemetry.")
    require(r"logCanvasGesture\(componentID:\s*\"canvas\.arrow\.draw\",\s*phase:\s*\"end\"\)", source, "Arrow drawing must log end telemetry.")
    require(r"componentID:\s*\"canvas\.toolstrip\.", source, "Canvas active tool strip buttons must have stable telemetry component IDs.")
    require(r"recordSliderChange\(\"canvas\.toolstrip\.width\"\)", source, "Canvas active tool width slider must record telemetry.")
    require(r"recordSliderChange\(\"canvas\.toolstrip\.opacity\"\)", source, "Canvas active brush opacity slider must record telemetry.")
    require(r"componentID:\s*\"canvas\.line\.", source, "Canvas line style buttons must have stable telemetry component IDs.")
    require(r"recordSliderChange\(\"canvas\.line\.width\.slider\"\)", source, "Canvas line width slider must record telemetry.")
    require(r"componentID:\s*\"canvas\.tape\.length\.", source, "Canvas tape length buttons must have stable telemetry component IDs.")
    require(r"recordSliderChange\(\"canvas\.tape\.length\.slider\"\)", source, "Canvas tape length slider must record telemetry.")
    require(r"componentID:\s*\"canvas\.shape\.", source, "Canvas shape style buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.layer\.", source, "Canvas layer row buttons must have stable telemetry component IDs.")
    require(r"recordSliderChange\(\"floating\.selection\.line-width\"\)", source, "Floating selection line width slider must record telemetry.")
    require(r"recordSliderChange\(\"floating\.selection\.tape-length\"\)", source, "Floating selection tape length slider must record telemetry.")
    require(r"recordSliderChange\(\"floating\.selection\.opacity\"\)", source, "Floating selection opacity slider must record telemetry.")
    require(r"recordSliderChange\(\"floating\.selection\.corner-radius\"\)", source, "Floating selection corner radius slider must record telemetry.")
    forbid(r"gestureHint\(", source, "Floating selection toolbar must not show non-action gesture hint buttons.")
    require(r"recordAction\(componentID:\s*componentID", source, "Native slider telemetry helpers must pass through stable component IDs.")
    require(r"componentID:\s*\"sheet\.text\.", source, "Text editor sheet buttons must have stable telemetry component IDs.")
    require(r"recordStyleChange\(\"font\"\)", source, "Text font picker changes must record telemetry.")
    require(r"recordStyleChange\(\"size\"\)", source, "Text size slider changes must record telemetry.")
    require(r"recordStyleChange\(\"width\"\)", source, "Text width slider changes must record telemetry.")
    require(r"recordStyleChange\(\"bold\"\)", source, "Text bold toggle changes must record telemetry.")
    require(r"recordStyleChange\(\"italic\"\)", source, "Text italic toggle changes must record telemetry.")
    require(r"recordStyleChange\(\"align\"\)", source, "Text alignment picker changes must record telemetry.")
    require(r"recordAction\(componentID:\s*\"sheet\.text\.\\\(component\)\"", source, "Text style telemetry must use stable sheet.text component IDs.")
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
    require(r"targetNotebookForNewPage", source, "Home-created pages must resolve an explicit target notebook instead of creating orphan-like pages.")
    require(r"repository\.notebook\(for:\s*pageID\)", source, "Page preview must show the notebook that owns the page.")
    require(r"page\.preview\.notebook\.move", source, "Page preview must expose a notebook move action.")
    require(r"NotebookPickerSheet\([\s\S]*currentNotebookID:\s*page\?\.notebookID", source, "Page preview must use the notebook picker to move pages between notebooks.")
    require(r"componentID:\s*\"presentation\.", source, "Presentation controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"canvas\.tape\.placement\.", source, "Tape placement controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.notebook-edit\.", source, "Notebook edit sheet controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.notebook-picker\.", source, "Notebook picker sheet controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.new-notebook\.", source, "New notebook sheet controls must have stable telemetry component IDs.")
    require(r"recordAction\(componentID:\s*\"editor\.tool\.picture\.picker\"", source, "Editor native photo picker selection must record telemetry.")
    require(r"recordAction\(componentID:\s*\"sheet\.new-notebook\.cover\.picker\"", source, "New notebook cover photo picker selection must record telemetry.")
    require(r"componentID:\s*\"home\.header\.", source, "Home header controls must have telemetry.")
    require(r"componentID:\s*\"home\.header\.notifications\"", source, "Home notification header button must have a stable telemetry component ID.")
    require(r"HomeNotificationSheet\(", source, "Home notification header button must open a real notification sheet.")
    require(r"componentID:\s*\"home\.notifications\.open\.", source, "Home notification rows must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.notifications\.done\"", source, "Home notification sheet done button must have telemetry.")
    require(r"componentID:\s*\"home\.search\.", source, "Home search/location controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"sheet\.place-search\.", source, "Place search sheet controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.create\.", source, "Home create buttons must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.notebook\.", source, "Home notebook controls must have stable telemetry component IDs.")
    require(r"componentID:\s*\"home\.location\.", source, "Location sticker shelf controls must have stable telemetry component IDs.")
    forbid(r"PlaceholderRootTabView", source, "Root tabs must use functional screens instead of shared placeholder views.")
    require(r"UniverseRootTabView\(", source, "Universe root tab must render the discovery screen.")
    require(r"componentID:\s*\"universe\.material\.", source, "Universe material cards must have stable telemetry component IDs.")
    require(r"case\s+materials", source, "Canvas asset sheets must have a dedicated materials sheet.")
    require(r"toolButton\(\"storefront\",\s*\"Materials\",\s*action:\s*onMaterial\)", source, "Editor Materials tool must use a store icon and open material assets.")
    require(r"toolButton\(\"sparkles\",\s*\"Stickers\",\s*action:\s*onSticker\)", source, "Editor Stickers tool must be separate from Materials.")
    forbid(r"toolButton\(\"sparkles\",\s*\"Materials\",\s*action:\s*onSticker\)", source, "Editor Materials tool must not open the sticker action.")
    verify_global_common_materials(source)
    require(r"MyLibraryRootTabView\(", source, "My root tab must render the local library screen.")
    require(r"componentID:\s*\"my\.page\.open\.", source, "My tab recent page rows must have stable telemetry component IDs.")
    require(r"componentID:\s*\"my\.notebook\.new\"", source, "My tab new notebook button must have telemetry.")
    require(r"componentID:\s*\"root\.tab\.", source, "Root tab controls must have stable telemetry component IDs.")
    forbid(r"\.placeholder\"", source, "Placeholder telemetry actions must be replaced with real actions or disabled controls.")
    require(r"recordAction\(componentID:\s*\"notebook\.detail\.export\.pdf\"", source, "Notebook PDF export menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.detail\.export\.zip\"", source, "Notebook ZIP export menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.page\.rename\.", source, "Page rename menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.page\.cover\.", source, "Page cover menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"notebook\.page\.delete\.", source, "Page delete menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"page\.preview\.export\.image\"", source, "Page image export menu action must record telemetry.")
    require(r"recordAction\(componentID:\s*\"page\.preview\.export\.pdf\"", source, "Page PDF export menu action must record telemetry.")
    forbid(r"createPage(?:AndOpen)?\(in:\s*nil", source, "UI page creation must pass an explicit notebook target.")
    forbid(r"createQuickClip\(in:\s*nil", source, "Quick Clip creation must pass an explicit notebook target.")
    require(r"func\s+targetNotebookForNewPage", repository, "Repository must expose the resolved notebook used for new home-created pages.")
    require(r"func\s+notebook\(for\s+pageID:\s*UUID\)", repository, "Repository must expose notebook ownership for page previews.")
    require(r"!validNotebookIDs\.contains\(pages\[index\]\.notebookID\)", repository, "Loaded pages must be normalized away from invalid notebook ownership.")
    verify_page_template_quality(page_templates, page_template_applier, source)

    top_tool = require_block(r"private struct EditorTopTool: View \{(?P<body>.*?)\n\}", source, "EditorTopTool not found.")
    if top_tool is not None:
        forbid(r"\.disabled\(", top_tool, "EditorTopTool must not use SwiftUI disabled because disabled taps need telemetry.")

    for misleading_icon in [
        r"toolButton\(\"line\.3\.horizontal\",\s*\"Background\"",
        r"toolButton\(\"textformat\.alt\",\s*\"WordArt\"",
        r"toolButton\(\"textformat\.alt\",\s*\"ArtStyle\"",
        r"toolButton\(\"rectangle\.fill\.on\.rectangle\.fill\",\s*\"Texture\"",
        r"toolButton\(\"square\.stack\.3d\.up\",\s*\"Group\"",
        r"toolButton\(\"square\.stack\.3d\.down\.right\",\s*\"Ungroup\"",
        r"case\s+\.object:\s+return\s+\"square\.stack\.3d\.up\"",
        r"toolButton\(\"scribble\.variable\",\s*\"Stroke\",\s*action:\s*onBrush\)",
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
        (r"case\s+\.object:\s+return\s+\"cursorarrow\"", "Object shelf must use a selection cursor icon, not the layer stack icon."),
        (r"toolButton\(\"paintbrush\.pointed\",\s*\"Brush\",\s*action:\s*onBrush\)", "Brush insertion must be labeled Brush and use the brush icon, not a Stroke style label."),
        (r"case\s+\.wordArt:\s+return\s+\"textformat\.size\"", "WordArt category and element icons must use the text sizing icon."),
    ]
    for pattern, message in expected_icon_mappings:
        require(pattern, source, message)

    report_and_exit()


if __name__ == "__main__":
    main()
