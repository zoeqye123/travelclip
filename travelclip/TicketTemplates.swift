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
            drawTicketLayout(in: cg, template: template, fields: fields)
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

    private static func drawTicketLayout(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        switch template.layoutStyle {
        case .boardingPass:
            drawBoardingPass(in: cg, template: template, fields: fields)
        case .baggageTag:
            drawBaggageTag(in: cg, template: template, fields: fields)
        case .retroAir:
            drawRetroAir(in: cg, template: template, fields: fields)
        case .railPass:
            drawRailPass(in: cg, template: template, fields: fields)
        case .localStub:
            drawLocalStub(in: cg, template: template, fields: fields)
        case .sleeperSlip:
            drawSleeperSlip(in: cg, template: template, fields: fields)
        case .pierPass:
            drawPierPass(in: cg, template: template, fields: fields)
        case .cruiseStub:
            drawCruiseStub(in: cg, template: template, fields: fields)
        case .islandTransfer:
            drawIslandTransfer(in: cg, template: template, fields: fields)
        case .cinemaStub:
            drawCinemaStub(in: cg, template: template, fields: fields)
        case .admitOne:
            drawAdmitOne(in: cg, template: template, fields: fields)
        case .festivalPass:
            drawFestivalPass(in: cg, template: template, fields: fields)
        case .museumEntry:
            drawMuseumEntry(in: cg, template: template, fields: fields)
        case .concertTicket:
            drawConcertTicket(in: cg, template: template, fields: fields)
        case .wristbandPass:
            drawWristbandPass(in: cg, template: template, fields: fields)
        case .classic:
            drawClassicTicket(in: cg, template: template, fields: fields)
        }
    }

    private static func drawClassicTicket(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
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

    private static func drawBoardingPass(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 86, y: 164, width: 1228, height: 572)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#24303A")
        let soft = UIColor(ticketHex: "#6F7F86")
        drawShadowedCard(card, template: template, radius: 28)

        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: card.minX, y: card.minY, width: card.width, height: 92))
        drawText(template.headline, in: CGRect(x: 132, y: 188, width: 760, height: 52), font: .boldSystemFont(ofSize: 44), color: .white)
        drawText(fields.reference, in: CGRect(x: 986, y: 194, width: 260, height: 42), font: condensedFont(size: 34), color: UIColor(ticketHex: "#FDF4E8"), alignment: .right)

        dashedLine(from: CGPoint(x: 970, y: 284), to: CGPoint(x: 970, y: 690), color: soft, vertical: true, dash: 12, gap: 9)
        drawText(fields.origin.uppercased(), in: CGRect(x: 138, y: 304, width: 330, height: 98), font: .boldSystemFont(ofSize: 76), color: ink)
        drawText("TO", in: CGRect(x: 498, y: 328, width: 90, height: 45), font: condensedFont(size: 42), color: soft, alignment: .center)
        drawText(fields.destination.uppercased(), in: CGRect(x: 622, y: 304, width: 300, height: 98), font: .boldSystemFont(ofSize: 76), color: ink)
        drawFieldBox("DATE", fields.date, CGRect(x: 138, y: 464, width: 240, height: 100), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 410, y: 464, width: 190, height: 100), soft: soft, ink: ink)
        drawFieldBox("SEAT", fields.seat, CGRect(x: 632, y: 464, width: 230, height: 100), soft: soft, ink: ink)
        drawBarcode(in: CGRect(x: 156, y: 625, width: 690, height: 54), color: ink)
        drawFieldBox(gateLabel(for: template.kind), fields.gate, CGRect(x: 1012, y: 306, width: 220, height: 90), soft: soft, ink: ink)
        drawFieldBox(classLabel(for: template.kind), fields.className, CGRect(x: 1012, y: 430, width: 220, height: 90), soft: soft, ink: ink)
        drawText("STUB", in: CGRect(x: 1032, y: 612, width: 172, height: 42), font: condensedFont(size: 38), color: accent, alignment: .center)
    }

    private static func drawBaggageTag(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 430, y: 68, width: 540, height: 764)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#26312E")
        let soft = UIColor(ticketHex: "#718077")
        drawShadowedCard(card, template: template, radius: 42)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: card.minX + 46, y: card.minY, width: card.width - 92, height: 118))
        cg.setBlendMode(.clear)
        cg.fillEllipse(in: CGRect(x: 648, y: 100, width: 104, height: 104))
        cg.setBlendMode(.normal)
        strokeRoundedRect(card.insetBy(dx: 28, dy: 28), radius: 30, color: accent.withAlphaComponent(0.65), lineWidth: 3)
        drawText(template.headline, in: CGRect(x: 480, y: 196, width: 440, height: 54), font: condensedFont(size: 46), color: accent, alignment: .center)
        drawText(fields.destination.uppercased(), in: CGRect(x: 498, y: 272, width: 404, height: 98), font: .boldSystemFont(ofSize: 82), color: ink, alignment: .center)
        drawText(fields.origin.uppercased(), in: CGRect(x: 560, y: 390, width: 280, height: 50), font: condensedFont(size: 42), color: soft, alignment: .center)
        drawFieldBox("DATE", fields.date, CGRect(x: 508, y: 486, width: 180, height: 92), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 712, y: 486, width: 180, height: 92), soft: soft, ink: ink)
        drawFieldBox("SEAT", fields.seat, CGRect(x: 508, y: 606, width: 180, height: 92), soft: soft, ink: ink)
        drawFieldBox(gateLabel(for: template.kind), fields.gate, CGRect(x: 712, y: 606, width: 180, height: 92), soft: soft, ink: ink)
        drawBarcode(in: CGRect(x: 528, y: 744, width: 344, height: 54), color: accent)
    }

    private static func drawRetroAir(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 112, y: 128, width: 1176, height: 644)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#392B22")
        let soft = UIColor(ticketHex: "#8C6D55")
        drawShadowedCard(card, template: template, radius: 22)
        strokeRoundedRect(card.insetBy(dx: 24, dy: 24), radius: 16, color: soft.withAlphaComponent(0.45), lineWidth: 2)
        cg.saveGState()
        cg.translateBy(x: 104, y: 196)
        cg.rotate(by: -.pi / 28)
        cg.setFillColor(accent.withAlphaComponent(0.9).cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: 520, height: 72))
        drawText(template.headline, in: CGRect(x: 26, y: 11, width: 468, height: 46), font: condensedFont(size: 44), color: .white, alignment: .center)
        cg.restoreGState()
        drawText(fields.origin.uppercased(), in: CGRect(x: 170, y: 332, width: 300, height: 72), font: serifFont(size: 56), color: ink)
        drawText(fields.destination.uppercased(), in: CGRect(x: 170, y: 440, width: 460, height: 72), font: serifFont(size: 56), color: ink)
        drawText("PASSAGE", in: CGRect(x: 760, y: 232, width: 260, height: 58), font: condensedFont(size: 54), color: accent, alignment: .center)
        strokeRoundedRect(CGRect(x: 802, y: 314, width: 190, height: 190), radius: 95, color: accent, lineWidth: 5)
        drawText("VALID", in: CGRect(x: 835, y: 362, width: 126, height: 52), font: condensedFont(size: 48), color: accent, alignment: .center)
        drawText(fields.className.uppercased(), in: CGRect(x: 810, y: 426, width: 174, height: 40), font: condensedFont(size: 30), color: soft, alignment: .center)
        drawCouponRow(y: 590, fields: fields, soft: soft, ink: ink)
        dashedLine(from: CGPoint(x: 1036, y: 168), to: CGPoint(x: 1036, y: 732), color: soft, vertical: true, dash: 9, gap: 8)
        drawText(fields.reference, in: CGRect(x: 1070, y: 218, width: 150, height: 220), font: condensedFont(size: 36), color: ink, alignment: .center)
        drawBarcode(in: CGRect(x: 1078, y: 538, width: 132, height: 84), color: accent)
    }

    private static func drawRailPass(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        drawClassicTicket(in: cg, template: template, fields: fields)
    }

    private static func drawLocalStub(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 96, y: 176, width: 1208, height: 548)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#302A22")
        let soft = UIColor(ticketHex: "#7A6F5F")
        drawShadowedCard(card, template: template, radius: 16)
        cg.setFillColor(accent.withAlphaComponent(0.14).cgColor)
        for x in stride(from: card.minX + 18, through: card.maxX - 40, by: 62) {
            cg.fillEllipse(in: CGRect(x: x, y: card.minY - 14, width: 28, height: 28))
            cg.fillEllipse(in: CGRect(x: x, y: card.maxY - 14, width: 28, height: 28))
        }
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: 132, y: 214, width: 210, height: 470))
        drawText("LOCAL", in: CGRect(x: 158, y: 252, width: 158, height: 62), font: condensedFont(size: 56), color: .white, alignment: .center)
        drawText(fields.reference, in: CGRect(x: 154, y: 584, width: 164, height: 46), font: condensedFont(size: 34), color: UIColor(ticketHex: "#FDF2DD"), alignment: .center)
        drawText(template.headline, in: CGRect(x: 398, y: 220, width: 670, height: 54), font: condensedFont(size: 52), color: accent)
        drawText(fields.origin.uppercased(), in: CGRect(x: 400, y: 326, width: 328, height: 76), font: .boldSystemFont(ofSize: 58), color: ink)
        drawText(fields.destination.uppercased(), in: CGRect(x: 400, y: 450, width: 420, height: 76), font: .boldSystemFont(ofSize: 58), color: ink)
        drawFieldBox("DATE", fields.date, CGRect(x: 874, y: 328, width: 180, height: 84), soft: soft, ink: ink)
        drawFieldBox(gateLabel(for: template.kind), fields.gate, CGRect(x: 1080, y: 328, width: 160, height: 84), soft: soft, ink: ink)
        drawFieldBox("SEAT", fields.seat, CGRect(x: 874, y: 474, width: 180, height: 84), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 1080, y: 474, width: 160, height: 84), soft: soft, ink: ink)
    }

    private static func drawSleeperSlip(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 138, y: 118, width: 1124, height: 664)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#243047")
        let soft = UIColor(ticketHex: "#647086")
        drawShadowedCard(card, template: template, radius: 30)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: card.minX, y: card.minY, width: card.width, height: 180))
        drawText(template.headline, in: CGRect(x: 188, y: 164, width: 540, height: 58), font: condensedFont(size: 54), color: .white)
        drawText("NIGHT SLIP", in: CGRect(x: 910, y: 174, width: 250, height: 46), font: condensedFont(size: 38), color: UIColor(ticketHex: "#DCE6F5"), alignment: .right)
        drawText(fields.origin.uppercased(), in: CGRect(x: 202, y: 338, width: 360, height: 70), font: serifFont(size: 54), color: ink)
        drawText(fields.destination.uppercased(), in: CGRect(x: 202, y: 456, width: 420, height: 70), font: serifFont(size: 54), color: ink)
        for (index, label) in ["DATE", "TIME", "BUNK", gateLabel(for: template.kind)].enumerated() {
            let row = index / 2
            let col = index % 2
            let value = [fields.date, fields.time, fields.seat, fields.gate][index]
            drawFieldBox(label, value, CGRect(x: 718 + CGFloat(col) * 210, y: 344 + CGFloat(row) * 132, width: 170, height: 92), soft: soft, ink: ink)
        }
        dashedLine(from: CGPoint(x: 190, y: 640), to: CGPoint(x: 1210, y: 640), color: soft, vertical: false, dash: 16, gap: 10)
        drawText(fields.reference, in: CGRect(x: 222, y: 666, width: 380, height: 44), font: condensedFont(size: 34), color: accent)
        drawBarcode(in: CGRect(x: 844, y: 662, width: 260, height: 46), color: ink)
    }

    private static func drawPierPass(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 120, y: 150, width: 1160, height: 600)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#203A3C")
        let soft = UIColor(ticketHex: "#668284")
        drawShadowedCard(card, template: template, radius: 34)
        cg.setFillColor(accent.withAlphaComponent(0.18).cgColor)
        for x in stride(from: card.minX, through: card.maxX, by: 76) {
            cg.fillEllipse(in: CGRect(x: x - 40, y: 618, width: 124, height: 74))
        }
        drawText(template.headline, in: CGRect(x: 178, y: 198, width: 650, height: 58), font: condensedFont(size: 54), color: accent)
        drawText(fields.origin.uppercased(), in: CGRect(x: 186, y: 318, width: 380, height: 70), font: .boldSystemFont(ofSize: 56), color: ink)
        drawText(fields.destination.uppercased(), in: CGRect(x: 186, y: 442, width: 440, height: 70), font: .boldSystemFont(ofSize: 56), color: ink)
        dashedLine(from: CGPoint(x: 830, y: 198), to: CGPoint(x: 830, y: 702), color: soft, vertical: true, dash: 12, gap: 10)
        drawFieldBox("PIER", fields.gate, CGRect(x: 884, y: 256, width: 250, height: 96), soft: soft, ink: ink)
        drawFieldBox("DECK", fields.seat, CGRect(x: 884, y: 384, width: 250, height: 96), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 884, y: 512, width: 250, height: 96), soft: soft, ink: ink)
        drawText(fields.reference, in: CGRect(x: 890, y: 650, width: 260, height: 40), font: condensedFont(size: 34), color: accent)
    }

    private static func drawCruiseStub(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#283840")
        let soft = UIColor(ticketHex: "#6A7B80")
        let top = CGRect(x: 130, y: 118, width: 1140, height: 292)
        let bottom = CGRect(x: 130, y: 462, width: 1140, height: 292)
        drawShadowedCard(top, template: template, radius: 28)
        drawShadowedCard(bottom, template: template, radius: 28)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: top.minX, y: top.minY, width: 84, height: top.height))
        cg.fill(CGRect(x: bottom.minX, y: bottom.minY, width: 84, height: bottom.height))
        drawText(template.headline, in: CGRect(x: 252, y: 162, width: 710, height: 52), font: condensedFont(size: 48), color: accent)
        drawText(fields.origin.uppercased(), in: CGRect(x: 256, y: 254, width: 330, height: 58), font: .boldSystemFont(ofSize: 46), color: ink)
        drawText(fields.destination.uppercased(), in: CGRect(x: 624, y: 254, width: 360, height: 58), font: .boldSystemFont(ofSize: 46), color: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 1010, y: 208, width: 170, height: 88), soft: soft, ink: ink)
        drawText("RECEIPT", in: CGRect(x: 252, y: 508, width: 250, height: 50), font: condensedFont(size: 44), color: accent)
        drawCouponRow(y: 610, fields: fields, soft: soft, ink: ink)
        drawBarcode(in: CGRect(x: 928, y: 592, width: 240, height: 64), color: ink)
    }

    private static func drawIslandTransfer(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 120, y: 118, width: 1160, height: 664)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#233937")
        let soft = UIColor(ticketHex: "#6A817F")
        drawShadowedCard(card, template: template, radius: 36)
        drawText(template.headline, in: CGRect(x: 184, y: 174, width: 650, height: 56), font: condensedFont(size: 52), color: accent)
        drawText(fields.origin.uppercased(), in: CGRect(x: 206, y: 338, width: 280, height: 64), font: .boldSystemFont(ofSize: 46), color: ink, alignment: .center)
        drawText(fields.destination.uppercased(), in: CGRect(x: 858, y: 338, width: 280, height: 64), font: .boldSystemFont(ofSize: 46), color: ink, alignment: .center)
        strokeRoundedRect(CGRect(x: 236, y: 452, width: 204, height: 92), radius: 46, color: accent, lineWidth: 4)
        strokeRoundedRect(CGRect(x: 896, y: 452, width: 204, height: 92), radius: 46, color: accent, lineWidth: 4)
        dashedLine(from: CGPoint(x: 450, y: 496), to: CGPoint(x: 884, y: 496), color: accent, vertical: false, dash: 18, gap: 12)
        drawText("SEA ROUTE", in: CGRect(x: 528, y: 424, width: 280, height: 46), font: condensedFont(size: 42), color: soft, alignment: .center)
        drawFieldBox("DATE", fields.date, CGRect(x: 218, y: 620, width: 220, height: 80), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 500, y: 620, width: 180, height: 80), soft: soft, ink: ink)
        drawFieldBox("PIER", fields.gate, CGRect(x: 740, y: 620, width: 180, height: 80), soft: soft, ink: ink)
        drawFieldBox("SEAT", fields.seat, CGRect(x: 980, y: 620, width: 180, height: 80), soft: soft, ink: ink)
    }

    private static func drawCinemaStub(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 112, y: 160, width: 1176, height: 580)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#2D2632")
        let soft = UIColor(ticketHex: "#766876")
        drawShadowedCard(card, template: template, radius: 18)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: card.minX, y: card.minY, width: card.width, height: 110))
        for x in stride(from: card.minX + 36, through: card.maxX - 70, by: 56) {
            cg.setFillColor(UIColor(ticketHex: "#FFE7A8").cgColor)
            cg.fillEllipse(in: CGRect(x: x, y: 190, width: 22, height: 22))
        }
        drawText(template.headline, in: CGRect(x: 190, y: 188, width: 760, height: 54), font: condensedFont(size: 54), color: .white)
        drawText(fields.destination.uppercased(), in: CGRect(x: 190, y: 332, width: 700, height: 76), font: serifFont(size: 58), color: ink)
        drawText(fields.origin.uppercased(), in: CGRect(x: 190, y: 438, width: 520, height: 48), font: condensedFont(size: 40), color: soft)
        dashedLine(from: CGPoint(x: 900, y: 300), to: CGPoint(x: 900, y: 694), color: soft, vertical: true, dash: 10, gap: 10)
        drawFieldBox("SEAT", fields.seat, CGRect(x: 952, y: 330, width: 230, height: 86), soft: soft, ink: ink)
        drawFieldBox("HALL", fields.gate, CGRect(x: 952, y: 446, width: 230, height: 86), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 952, y: 562, width: 230, height: 86), soft: soft, ink: ink)
        drawText(fields.reference, in: CGRect(x: 190, y: 624, width: 320, height: 42), font: condensedFont(size: 34), color: accent)
    }

    private static func drawAdmitOne(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 150, y: 148, width: 1100, height: 604)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#2F2722")
        let soft = UIColor(ticketHex: "#806C61")
        drawShadowedCard(card, template: template, radius: 24)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: card.minX, y: card.minY, width: 180, height: card.height))
        drawText("ADMIT\nONE", in: CGRect(x: 180, y: 274, width: 120, height: 150), font: condensedFont(size: 54), color: .white, alignment: .center)
        dashedLine(from: CGPoint(x: 362, y: 190), to: CGPoint(x: 362, y: 710), color: soft, vertical: true, dash: 10, gap: 10)
        drawText(fields.destination.uppercased(), in: CGRect(x: 430, y: 230, width: 620, height: 82), font: .boldSystemFont(ofSize: 60), color: ink)
        drawText(template.headline, in: CGRect(x: 430, y: 332, width: 540, height: 48), font: condensedFont(size: 42), color: accent)
        drawCouponRow(y: 476, fields: fields, soft: soft, ink: ink)
        drawBarcode(in: CGRect(x: 456, y: 650, width: 540, height: 54), color: ink)
    }

    private static func drawFestivalPass(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 356, y: 96, width: 688, height: 724)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#282824")
        let soft = UIColor(ticketHex: "#79786B")
        drawShadowedCard(card, template: template, radius: 38)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: card.minX, y: card.minY, width: card.width, height: 150))
        drawText("PASS", in: CGRect(x: 462, y: 126, width: 476, height: 82), font: .boldSystemFont(ofSize: 72), color: .white, alignment: .center)
        drawText(template.headline, in: CGRect(x: 428, y: 286, width: 544, height: 58), font: condensedFont(size: 50), color: accent, alignment: .center)
        drawText(fields.destination.uppercased(), in: CGRect(x: 430, y: 386, width: 540, height: 70), font: serifFont(size: 52), color: ink, alignment: .center)
        drawFieldBox("DATE", fields.date, CGRect(x: 440, y: 522, width: 230, height: 88), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 730, y: 522, width: 230, height: 88), soft: soft, ink: ink)
        drawFieldBox("ENTRY", fields.gate, CGRect(x: 440, y: 638, width: 230, height: 88), soft: soft, ink: ink)
        drawFieldBox("SEAT", fields.seat, CGRect(x: 730, y: 638, width: 230, height: 88), soft: soft, ink: ink)
    }

    private static func drawMuseumEntry(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 142, y: 126, width: 1116, height: 648)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#2F2923")
        let soft = UIColor(ticketHex: "#82766A")
        drawShadowedCard(card, template: template, radius: 12)
        strokeRoundedRect(card.insetBy(dx: 52, dy: 52), radius: 0, color: accent.withAlphaComponent(0.55), lineWidth: 3)
        drawText(template.headline, in: CGRect(x: 224, y: 194, width: 620, height: 54), font: serifFont(size: 42), color: ink)
        drawText(fields.origin.uppercased(), in: CGRect(x: 224, y: 326, width: 520, height: 62), font: .boldSystemFont(ofSize: 46), color: accent)
        drawText(fields.destination.uppercased(), in: CGRect(x: 224, y: 420, width: 620, height: 60), font: serifFont(size: 44), color: ink)
        drawFieldBox("DATE", fields.date, CGRect(x: 224, y: 596, width: 220, height: 74), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 496, y: 596, width: 180, height: 74), soft: soft, ink: ink)
        drawFieldBox("ROOM", fields.seat, CGRect(x: 728, y: 596, width: 190, height: 74), soft: soft, ink: ink)
        drawText(fields.reference, in: CGRect(x: 958, y: 198, width: 150, height: 380), font: condensedFont(size: 36), color: soft, alignment: .center)
        drawBarcode(in: CGRect(x: 948, y: 620, width: 180, height: 46), color: accent)
    }

    private static func drawConcertTicket(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let card = CGRect(x: 100, y: 126, width: 1200, height: 648)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#272229")
        let soft = UIColor(ticketHex: "#79636E")
        drawShadowedCard(card, template: template, radius: 26)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: 100, y: 126, width: 1200, height: 248))
        drawText(fields.destination.uppercased(), in: CGRect(x: 172, y: 174, width: 820, height: 86), font: .boldSystemFont(ofSize: 70), color: .white)
        drawText(template.headline, in: CGRect(x: 178, y: 282, width: 620, height: 48), font: condensedFont(size: 42), color: UIColor(ticketHex: "#FFE6F0"))
        drawText(fields.origin.uppercased(), in: CGRect(x: 176, y: 434, width: 520, height: 58), font: serifFont(size: 46), color: ink)
        drawCouponRow(y: 564, fields: fields, soft: soft, ink: ink)
        dashedLine(from: CGPoint(x: 986, y: 394), to: CGPoint(x: 986, y: 732), color: soft, vertical: true, dash: 12, gap: 9)
        drawText(fields.reference, in: CGRect(x: 1024, y: 438, width: 190, height: 54), font: condensedFont(size: 42), color: accent, alignment: .center)
        drawBarcode(in: CGRect(x: 1040, y: 584, width: 160, height: 80), color: ink)
    }

    private static func drawWristbandPass(in cg: CGContext, template: TicketTemplateDefinition, fields: TicketFields) {
        let band = CGRect(x: 52, y: 330, width: 1296, height: 238)
        let accent = UIColor(ticketHex: template.accentHex)
        let ink = UIColor(ticketHex: "#2D2A22")
        let soft = UIColor(ticketHex: "#776F61")
        drawShadowedCard(band, template: template, radius: 34)
        cg.setFillColor(accent.cgColor)
        cg.fill(CGRect(x: 52, y: 330, width: 188, height: 238))
        cg.fill(CGRect(x: 1160, y: 330, width: 188, height: 238))
        for x in stride(from: 275, through: 1080, by: 62) {
            cg.setFillColor(accent.withAlphaComponent(0.24).cgColor)
            cg.fillEllipse(in: CGRect(x: x, y: 418, width: 28, height: 28))
        }
        drawText("ENTRY", in: CGRect(x: 76, y: 412, width: 140, height: 48), font: condensedFont(size: 44), color: .white, alignment: .center)
        drawText(template.headline, in: CGRect(x: 310, y: 360, width: 500, height: 52), font: condensedFont(size: 48), color: accent)
        drawText(fields.destination.uppercased(), in: CGRect(x: 310, y: 442, width: 470, height: 58), font: .boldSystemFont(ofSize: 46), color: ink)
        drawFieldBox("DATE", fields.date, CGRect(x: 828, y: 382, width: 190, height: 74), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 1030, y: 382, width: 110, height: 74), soft: soft, ink: ink)
        drawText(fields.reference, in: CGRect(x: 1190, y: 408, width: 120, height: 52), font: condensedFont(size: 34), color: .white, alignment: .center)
    }

    private static func drawField(label: String, value: String, x: CGFloat, y: CGFloat, valueSize: CGFloat, valueFont: UIFont, soft: UIColor, ink: UIColor) {
        drawText(label, at: CGPoint(x: x, y: y), font: condensedFont(size: 28), color: soft)
        drawText(value.uppercased(), at: CGPoint(x: x, y: y + 35), font: valueFont, color: ink)
    }

    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        text.draw(at: point, withAttributes: attributes)
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil)
    }

    private static func drawFieldBox(_ label: String, _ value: String, _ rect: CGRect, soft: UIColor, ink: UIColor) {
        drawText(label, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 26), font: condensedFont(size: 24), color: soft)
        drawText(value.uppercased(), in: CGRect(x: rect.minX, y: rect.minY + 30, width: rect.width, height: rect.height - 30), font: .boldSystemFont(ofSize: min(34, rect.height - 34)), color: ink)
    }

    private static func drawCouponRow(y: CGFloat, fields: TicketFields, soft: UIColor, ink: UIColor) {
        drawFieldBox("DATE", fields.date, CGRect(x: 170, y: y, width: 210, height: 88), soft: soft, ink: ink)
        drawFieldBox("TIME", fields.time, CGRect(x: 420, y: y, width: 160, height: 88), soft: soft, ink: ink)
        drawFieldBox("SEAT", fields.seat, CGRect(x: 620, y: y, width: 220, height: 88), soft: soft, ink: ink)
        drawFieldBox("REF", fields.reference, CGRect(x: 880, y: y, width: 260, height: 88), soft: soft, ink: ink)
    }

    private static func drawShadowedCard(_ rect: CGRect, template: TicketTemplateDefinition, radius: CGFloat) {
        let path = roundedRect(rect, radius: radius)
        UIGraphicsGetCurrentContext()?.setShadow(offset: CGSize(width: 8, height: 12), blur: 20, color: UIColor.black.withAlphaComponent(0.2).cgColor)
        UIColor(ticketHex: template.paperHex).setFill()
        path.fill()
        UIGraphicsGetCurrentContext()?.setShadow(offset: .zero, blur: 0, color: nil)
        strokeRoundedRect(rect, radius: radius, color: UIColor(ticketHex: template.accentHex).withAlphaComponent(0.72), lineWidth: 3)
    }

    private static func drawBarcode(in rect: CGRect, color: UIColor) {
        color.setFill()
        var x = rect.minX
        let widths: [CGFloat] = [4, 9, 3, 12, 5, 6, 11, 4, 8, 3, 13, 5, 7, 4, 10, 6, 3, 12]
        var index = 0
        while x < rect.maxX {
            let width = widths[index % widths.count]
            UIBezierPath(rect: CGRect(x: x, y: rect.minY, width: min(width, rect.maxX - x), height: rect.height)).fill()
            x += width + 7
            index += 1
        }
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

    private static func classLabel(for kind: TicketKind) -> String {
        kind == .movie ? "TYPE" : "CLASS"
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
