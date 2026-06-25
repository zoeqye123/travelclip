import Foundation

struct PageTemplateApplication {
    let selectedElementIDs: Set<UUID>
}

enum PageTemplateApplier {
    static func apply(_ template: PageTemplateDefinition, to document: inout CanvasDocument) -> PageTemplateApplication {
        let startZ = (document.elements.map(\.zIndex).max() ?? 0) + 1
        document.background = template.background

        let elements = polishedElements(for: template).enumerated().map { offset, element in
            var copy = element
            copy.id = UUID()
            copy.zIndex = startZ + offset
            return copy
        }

        document.elements.append(contentsOf: elements)
        if let starterElement = elements.first(where: \.isTemplateStarterElement) {
            return PageTemplateApplication(selectedElementIDs: [starterElement.id])
        }
        return PageTemplateApplication(selectedElementIDs: [])
    }

    static func polishedElements(for template: PageTemplateDefinition) -> [CanvasElement] {
        template.elements.map { polishedElement($0, background: template.background) }
    }

    private static func polishedElement(_ element: CanvasElement, background: CanvasBackground) -> CanvasElement {
        guard element.kind == .text || element.kind == .wordArt else {
            var copy = element
            if copy.kind == .image && !copy.locked && (copy.localPath?.isEmpty ?? true) && copy.editHint == nil {
                copy.editHint = "Tap to replace photo"
            }
            return copy
        }

        var copy = element
        let text = copy.text ?? ""
        let lines = max(CGFloat(text.components(separatedBy: .newlines).count), 1)
        let isLongLine = text.count > 34 || text.contains("/")
        copy.fontSize = readabilityAdjustedFontSize(for: copy, text: text, lineCount: lines)

        let lineHeight = copy.fontSize * (copy.kind == .wordArt ? 1.22 : 1.28)
        let minimumHeight = lineHeight * lines + max(18, copy.fontSize * 0.36)

        if copy.height < minimumHeight {
            copy.height = minimumHeight
        }

        if isLongLine, copy.fontSize > 30, copy.width < 620 {
            copy.fontSize *= 0.9
        }

        if copy.kind == .wordArt {
            copy.fontSize = min(copy.fontSize, 84)
            copy.height = max(copy.height, copy.fontSize * 1.55)
            copy.textShadowEnabled = true
            copy.shadowColorHex = wordArtShadowColor(for: background)
        }

        if copy.backgroundHex == nil, copy.kind == .text, lines > 1 {
            copy.backgroundHex = "#FFFDF5"
        }

        return copy
    }

    private static func readabilityAdjustedFontSize(for element: CanvasElement, text: String, lineCount: CGFloat) -> CGFloat {
        guard element.width > 0, element.height > 0 else { return element.fontSize }

        let longestLineLength = text
            .components(separatedBy: .newlines)
            .map(\.count)
            .max() ?? text.count
        let lineWidthBudget = max(element.width - 28, 80)
        let heightBudget = max(element.height - 18, 40)
        let widthLimitedSize = lineWidthBudget / max(CGFloat(longestLineLength) * 0.56, 1)
        let heightLimitedSize = heightBudget / max(lineCount * 1.26, 1)
        let readableCap = min(widthLimitedSize, heightLimitedSize) * 0.98

        return min(element.fontSize, max(readableCap, element.kind == .wordArt ? 34 : 22))
    }

    private static func wordArtShadowColor(for background: CanvasBackground) -> String {
        let luminance = (relativeLuminance(background.colorA) + relativeLuminance(background.colorB)) / 2
        return luminance < 0.34 ? "#111820" : "#FFF8EA"
    }

    private static func relativeLuminance(_ hex: String) -> CGFloat {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = Int(value, radix: 16) else { return 1 }
        let red = CGFloat((rgb >> 16) & 0xFF) / 255
        let green = CGFloat((rgb >> 8) & 0xFF) / 255
        let blue = CGFloat(rgb & 0xFF) / 255
        return red * 0.2126 + green * 0.7152 + blue * 0.0722
    }
}

private extension CanvasElement {
    var isTemplateStarterElement: Bool {
        kind == .image && !locked && (localPath?.isEmpty ?? true)
    }
}
