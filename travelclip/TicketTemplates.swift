//
//  TicketTemplates.swift
//  travelclip
//

import Foundation
import SwiftUI
import UIKit

private struct TicketTemplateManifest: Decodable {
    let templates: [TicketTemplateDefinition]
}

enum TicketTemplateLibrary {
    static func load() -> [TicketTemplateDefinition] {
        guard let resourceURL = Bundle.main.resourceURL else { return fallbackTemplates }
        let structuredURL = resourceURL
            .appendingPathComponent("Resources/TicketTemplates", isDirectory: true)
            .appendingPathComponent("tickets.json")
        let flatURL = resourceURL.appendingPathComponent("tickets.json")

        for url in [structuredURL, flatURL] {
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(TicketTemplateManifest.self, from: data),
                  !manifest.templates.isEmpty else { continue }
            return manifest.templates
        }
        return fallbackTemplates
    }

    private static let fallbackTemplates: [TicketTemplateDefinition] = [
        TicketTemplateDefinition(
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
    ]
}

struct TicketRenderer {
    static func render(template: TicketTemplateDefinition, fields: TicketFields, scale: CGFloat = 1) -> UIImage {
        let size = CGSize(width: 1400 * scale, height: 900 * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.scaleBy(x: scale, y: scale)
            drawBackground(in: cg, template: template)
            drawTicket(in: cg, template: template, fields: fields)
        }
    }

    private static func drawBackground(in cg: CGContext, template: TicketTemplateDefinition) {
        cg.setFillColor(UIColor(ticketHex: "#EFE4D1").cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: 1400, height: 900))
        cg.setFillColor(UIColor(ticketHex: template.paperHex).withAlphaComponent(0.62).cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: 1400, height: 900))

        cg.setStrokeColor(UIColor(ticketHex: "#D8C7AC").withAlphaComponent(0.36).cgColor)
        cg.setLineWidth(1)
        for y in stride(from: 28, through: 880, by: 34) {
            cg.move(to: CGPoint(x: 0, y: y))
            cg.addLine(to: CGPoint(x: 1400, y: y + 10))
            cg.strokePath()
        }
    }

    private static func drawTicket(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 110, y: 120, width: 1180, height: 660)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#35261A")
        let soft = UIColor(ticketHex: "#8C7660")

        cg.setShadow(offset: CGSize(width: 10, height: 14), blur: 22, color: UIColor.black.withAlphaComponent(0.22).cgColor)
        UIColor(ticketHex: template.paperHex).setFill()
        roundedRect(card, radius: 34).fill()
        cg.setShadow(offset: .zero, blur: 0, color: nil)

        strokeRoundedRect(card, radius: 34, color: accent.withAlphaComponent(0.82), lineWidth: 4)
        strokeRoundedRect(card.insetBy(dx: 30, dy: 30), radius: 24, color: UIColor(ticketHex: "#D6B796"), lineWidth: 2)

        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: 160, y: 170, width: 1070, height: 60))
        drawText(template.headline, at: CGPoint(x: 190, y: 182), font: .boldSystemFont(ofSize: 44), color: .white)
        drawText(fields.reference, at: CGPoint(x: 980, y: 184), font: condensedFont(size: 40), color: UIColor(ticketHex: "#FFF0DF"))

        dashedLine(from: CGPoint(x: 930, y: 250), to: CGPoint(x: 930, y: 720), color: soft, vertical: true)

        drawField(label: "FROM", value: fields.origin, x: 190, y: 285, valueSize: 64, valueFont: .boldSystemFont(ofSize: 64), soft: soft, ink: ink)
        drawField(label: "TO", value: fields.destination, x: 190, y: 430, valueSize: 64, valueFont: .boldSystemFont(ofSize: 64), soft: soft, ink: ink)
        drawField(label: "DATE", value: fields.date, x: 190, y: 585, valueSize: 42, valueFont: serifFont(size: 42), soft: soft, ink: ink)
        drawField(label: "SEAT", value: fields.seat, x: 500, y: 585, valueSize: 42, valueFont: serifFont(size: 42), soft: soft, ink: ink)

        drawField(label: template.kind == .movie ? "TYPE" : "CLASS", value: fields.className, x: 980, y: 285, valueSize: 42, valueFont: .boldSystemFont(ofSize: 42), soft: soft, ink: ink)
        drawField(label: "TIME", value: fields.time, x: 980, y: 410, valueSize: 52, valueFont: .boldSystemFont(ofSize: 52), soft: soft, ink: ink)
        drawField(label: gateLabel(for: template.kind), value: fields.gate, x: 980, y: 535, valueSize: 52, valueFont: .boldSystemFont(ofSize: 52), soft: soft, ink: ink)

        let stamp = CGRect(x: 980, y: 635, width: 200, height: 80)
        strokeRoundedRect(stamp, radius: 10, color: accent, lineWidth: 3)
        drawText("VALID", at: CGPoint(x: 1010, y: 650), font: condensedFont(size: 36), color: accent)
        drawText("TRAVEL JOURNAL", at: CGPoint(x: 1012, y: 686), font: condensedFont(size: 18), color: accent)

        dashedLine(from: CGPoint(x: 170, y: 710), to: CGPoint(x: 1220, y: 710), color: UIColor(ticketHex: "#BDA58A"), vertical: false, dash: 14, gap: 10)
        drawText(footer(for: template.kind), at: CGPoint(x: 190, y: 724), font: serifFont(size: 24), color: soft)
    }

    private static func drawField(label: String, value: String, x: CGFloat, y: CGFloat, valueSize: CGFloat, valueFont: UIFont, soft: UIColor, ink: UIColor) {
        drawText(label, at: CGPoint(x: x, y: y), font: condensedFont(size: 28), color: soft)
        drawText(value.uppercased(), at: CGPoint(x: x, y: y + 35), font: valueFont, color: ink)
    }

    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        text.draw(at: point, withAttributes: attributes)
    }

    private static func roundedRect(_ rect: CGRect, radius: CGFloat) -> UIBezierPath {
        UIBezierPath(roundedRect: rect, cornerRadius: radius)
    }

    private static func strokeRoundedRect(_ rect: CGRect, radius: CGFloat, color: UIColor, lineWidth: CGFloat) {
        let path = roundedRect(rect, radius: radius)
        color.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func dashedLine(from start: CGPoint, to end: CGPoint, color: UIColor, vertical: Bool, dash: CGFloat = 8, gap: CGFloat = 8) {
        let path = UIBezierPath()
        if vertical {
            var y = start.y
            while y < end.y {
                path.move(to: CGPoint(x: start.x, y: y))
                path.addLine(to: CGPoint(x: start.x, y: min(y + dash, end.y)))
                y += dash + gap
            }
        } else {
            var x = start.x
            while x < end.x {
                path.move(to: CGPoint(x: x, y: start.y))
                path.addLine(to: CGPoint(x: min(x + dash, end.x), y: start.y))
                x += dash + gap
            }
        }
        color.setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    private static func condensedFont(size: CGFloat) -> UIFont {
        UIFont(name: "DINCondensed-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    }

    private static func serifFont(size: CGFloat) -> UIFont {
        UIFont(name: "Georgia", size: size) ?? .serifPreferred(size: size)
    }

    private static func gateLabel(for kind: TicketKind) -> String {
        switch kind {
        case .flight: return "GATE"
        case .train: return "PLATFORM"
        case .ferry: return "PIER"
        case .movie: return "HALL"
        case .event: return "ENTRY"
        }
    }

    private static func footer(for kind: TicketKind) -> String {
        switch kind {
        case .flight: return "scrapbook keepsake / boarding memory / printable cutout"
        case .train: return "scrapbook keepsake / vintage rail ephemera / printable cutout"
        case .ferry: return "scrapbook keepsake / sea passage / printable cutout"
        case .movie: return "scrapbook keepsake / cinema night / printable cutout"
        case .event: return "scrapbook keepsake / event pass / printable cutout"
        }
    }
}

private extension UIFont {
    static func serifPreferred(size: CGFloat) -> UIFont {
        UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.serif) ?? UIFontDescriptor(), size: size)
    }
}

private extension UIColor {
    convenience init(ticketHex: String) {
        var hex = ticketHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        switch hex.count {
        case 3:
            red = CGFloat((value >> 8) & 0xF) / 15
            green = CGFloat((value >> 4) & 0xF) / 15
            blue = CGFloat(value & 0xF) / 15
        default:
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
        }

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
