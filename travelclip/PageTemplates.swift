import SwiftUI

enum PageTemplateLibrary {
    static let builtIn: [PageTemplateDefinition] = [
        PageTemplateDefinition(
            id: "postcard-day",
            title: "Packing Field Notes",
            subtitle: "A detailed pre-trip packing board with tickets, checklist strips, and taped photo pockets.",
            tags: ["packing", "travel", "photo", "handbook", "scrapbook", "checklist", "global", "before-travel", "plan", "checklist-flow", "packing-check"],
            background: CanvasBackground(colorA: "#F8EAD0", colorB: "#DDE9DF"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 930, width: 840, height: 1320, rotation: -1.2, zIndex: 1, opacity: 0.78, colorHex: "#FFF8EA", stroke: true, cornerRadius: 42),
                CanvasElement(kind: .tape, x: 256, y: 180, width: 310, height: 64, rotation: -7, zIndex: 2, opacity: 0.82, colorHex: "#CFA16A"),
                CanvasElement(kind: .tape, x: 770, y: 180, width: 330, height: 64, rotation: 5, zIndex: 3, opacity: 0.78, colorHex: "#A9B990"),
                CanvasElement(kind: .text, text: "PACKING PLAN", x: 478, y: 248, width: 675, height: 118, rotation: -2, zIndex: 4, colorHex: "#87583D", fontName: "Georgia", fontSize: 74, bold: true),
                CanvasElement(kind: .wordArt, text: "field notes", x: 650, y: 340, width: 500, height: 112, rotation: 2, zIndex: 5, colorHex: "#A94F3F", fontSize: 58, bold: true, italic: true),
                CanvasElement(kind: .text, text: "01  DEPARTURE ____ / ____     02  WEATHER ______", x: 540, y: 430, width: 760, height: 68, zIndex: 6, colorHex: "#5D513F", backgroundHex: "#F7E2BC", fontSize: 25, bold: true),
                CanvasElement(kind: .image, x: 335, y: 705, width: 390, height: 370, rotation: -5, zIndex: 7, colorHex: "#EAD9C0", shadow: true, stroke: true, cornerRadius: 22),
                CanvasElement(kind: .image, x: 735, y: 690, width: 390, height: 315, rotation: 4, zIndex: 8, colorHex: "#DDE8DA", shadow: true, stroke: true, cornerRadius: 22),
                CanvasElement(kind: .tape, x: 330, y: 500, width: 235, height: 58, rotation: -12, zIndex: 9, opacity: 0.88, colorHex: "#D8AD73"),
                CanvasElement(kind: .tape, x: 734, y: 492, width: 240, height: 58, rotation: 11, zIndex: 10, opacity: 0.88, colorHex: "#B8C79E"),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-watercolor__lat-0__lng-0__name-suitcase__tags-suitcase-行李箱-watercolor-水彩-sticker.png", x: 800, y: 344, width: 180, height: 180, rotation: 9, zIndex: 11, colorHex: "#A7664E", shadow: true),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-vintage__lat-0__lng-0__name-ticket__tags-ticket-机票-vintage-复古-sticker.png", x: 225, y: 1115, width: 235, height: 178, rotation: -8, zIndex: 12, colorHex: "#A7664E", shadow: true),
                CanvasElement(kind: .text, text: "03 carry-on", x: 760, y: 910, width: 285, height: 66, rotation: 3, zIndex: 13, colorHex: "#76583F", backgroundHex: "#F7D9B4", fontSize: 31, bold: true),
                CanvasElement(kind: .text, text: "□ passport\n□ charger\n□ small camera\n□ rain jacket\n□ train snacks", x: 755, y: 1090, width: 350, height: 268, rotation: 2, zIndex: 14, colorHex: "#4E4438", backgroundHex: "#FFFDF4", fontSize: 34, textAlignment: "left"),
                CanvasElement(kind: .text, text: "04 tiny things", x: 355, y: 930, width: 315, height: 66, rotation: -3, zIndex: 15, colorHex: "#5A5245", backgroundHex: "#E8EEDC", fontSize: 29, bold: true),
                CanvasElement(kind: .text, text: "lip balm / coins / postcards\nmetro card / receipt tape\none good pen", x: 405, y: 1048, width: 405, height: 150, rotation: -2, zIndex: 16, colorHex: "#4D4338", backgroundHex: "#FFFFFF", fontSize: 28, textAlignment: "left"),
                CanvasElement(kind: .text, text: "05 OUTFIT\n01  airport layers\n02  city walk shoes\n03  dinner scarf", x: 357, y: 1288, width: 450, height: 250, rotation: -2, zIndex: 17, colorHex: "#4A5545", backgroundHex: "#EFF4E7", fontSize: 31, bold: true, textAlignment: "left"),
                CanvasElement(kind: .image, x: 737, y: 1390, width: 330, height: 310, rotation: 5, zIndex: 18, colorHex: "#EBD6C5", shadow: true, stroke: true, cornerRadius: 20),
                CanvasElement(kind: .tape, x: 735, y: 1218, width: 230, height: 54, rotation: 13, zIndex: 19, opacity: 0.86, colorHex: "#C98E65"),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-lineart__lat-0__lng-0__name-compass__tags-compass-指南针-lineart-线条-sticker.png", x: 815, y: 1195, width: 145, height: 145, rotation: 8, zIndex: 20, colorHex: "#6F7F63", shadow: true),
                CanvasElement(kind: .text, text: "leave room for paper maps, bakery bags, and one found leaf", x: 540, y: 1638, width: 700, height: 92, rotation: -1, zIndex: 21, colorHex: "#6E4B3A", backgroundHex: "#F5DDB9", fontSize: 34, italic: true),
                CanvasElement(kind: .sticker, symbol: "sparkles", x: 192, y: 482, width: 86, height: 80, rotation: -12, zIndex: 22, colorHex: "#B7634C"),
                CanvasElement(kind: .sticker, symbol: "paperplane.fill", x: 850, y: 1580, width: 105, height: 92, rotation: 14, zIndex: 23, colorHex: "#7E967C"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 528, y: 520, width: 690, height: 46, rotation: -1, zIndex: 24, opacity: 0.42, colorHex: "#E6D4A9", cornerRadius: 12),
                CanvasElement(kind: .text, text: "bag weight ___ kg     gate ___     hotel drawer check", x: 520, y: 540, width: 640, height: 58, rotation: -1, zIndex: 25, colorHex: "#7A6046", backgroundHex: "#F6E7C7", fontName: "Courier", fontSize: 24, textAlignment: "left"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 735, y: 1082, width: 380, height: 18, rotation: 2, zIndex: 26, opacity: 0.35, colorHex: "#C98E65", cornerRadius: 8),
                CanvasElement(kind: .text, text: "last-minute pocket", x: 330, y: 1510, width: 315, height: 58, rotation: -5, zIndex: 27, colorHex: "#87583D", backgroundHex: "#F9E8C7", fontSize: 29, bold: true)
            ]
        ),
        PageTemplateDefinition(
            id: "itinerary-board",
            title: "Pre-trip Itinerary",
            subtitle: "A polished planning board for flight, hotel, route order, budget, and must-book items.",
            tags: ["itinerary", "planning", "route", "checklist", "ticket", "global", "before-travel", "plan", "route-flow", "booking", "day-one-route"],
            background: CanvasBackground(colorA: "#F7EAD9", colorB: "#DCE8E7"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 928, width: 838, height: 1326, rotation: 0.7, zIndex: 1, opacity: 0.78, colorHex: "#FFFDF6", stroke: true, cornerRadius: 42),
                CanvasElement(kind: .text, text: "TRIP BLUEPRINT", x: 500, y: 190, width: 650, height: 92, rotation: -1, zIndex: 2, colorHex: "#31545A", backgroundHex: "#FFFDF6", fontName: "Georgia", fontSize: 56, bold: true),
                CanvasElement(kind: .wordArt, text: "route first", x: 590, y: 306, width: 600, height: 118, rotation: 2, zIndex: 3, colorHex: "#A75F49", fontSize: 62, bold: true, italic: true),
                CanvasElement(kind: .text, text: "01 FLY  /  02 CHECK IN  /  03 FIRST STOP  /  04 SAVE RECEIPTS", x: 540, y: 412, width: 765, height: 68, zIndex: 4, colorHex: "#465248", backgroundHex: "#E9EFD9", fontSize: 24, bold: true),
                CanvasElement(kind: .image, x: 330, y: 650, width: 405, height: 340, rotation: -5, zIndex: 5, colorHex: "#E8D3B6", shadow: true, stroke: true, cornerRadius: 22),
                CanvasElement(kind: .image, x: 735, y: 670, width: 375, height: 375, rotation: 4, zIndex: 6, colorHex: "#D8E5E3", shadow: true, stroke: true, cornerRadius: 22),
                CanvasElement(kind: .tape, x: 320, y: 448, width: 250, height: 56, rotation: -11, zIndex: 7, opacity: 0.88, colorHex: "#D6B26D"),
                CanvasElement(kind: .tape, x: 732, y: 472, width: 260, height: 56, rotation: 10, zIndex: 8, opacity: 0.86, colorHex: "#8FB0A7"),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-lineart__lat-0__lng-0__name-airplane__tags-airplane-飞机-lineart-线条-sticker.png", x: 790, y: 250, width: 178, height: 178, rotation: 8, zIndex: 9, colorHex: "#31545A", shadow: true),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-vintage__lat-0__lng-0__name-passport__tags-passport-护照-vintage-复古-sticker.png", x: 235, y: 1065, width: 230, height: 188, rotation: -8, zIndex: 10, colorHex: "#A75F49", shadow: true),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-watercolor__lat-0__lng-0__name-map-pin__tags-map-地图-watercolor-水彩-sticker.png", x: 806, y: 1095, width: 185, height: 185, rotation: 9, zIndex: 11, colorHex: "#6F8E68", shadow: true),
                CanvasElement(kind: .text, text: "BOOKING CHECK\n01 flight: ______\n02 hotel: ______\n03 local pass: ____", x: 295, y: 1000, width: 380, height: 218, rotation: -2, zIndex: 12, colorHex: "#3F463E", backgroundHex: "#FFF9ED", fontName: "Courier", fontSize: 26, bold: true, textAlignment: "left"),
                CanvasElement(kind: .text, text: "DAY 01 ROUTE\n01 airport express\n02 hotel drop-off\n03 first meal\n04 sunset walk", x: 720, y: 1012, width: 365, height: 256, rotation: 3, zIndex: 13, colorHex: "#31545A", backgroundHex: "#EAF3EF", fontSize: 27, bold: true, textAlignment: "left"),
                CanvasElement(kind: .image, x: 540, y: 1270, width: 640, height: 260, rotation: -1, zIndex: 14, colorHex: "#F0DAB8", shadow: true, stroke: true, cornerRadius: 20),
                CanvasElement(kind: .text, text: "BUDGET\ntransport ____\nfood ________\ntickets _____", x: 270, y: 1425, width: 300, height: 174, rotation: -3, zIndex: 15, colorHex: "#604B39", backgroundHex: "#FFF8EA", fontName: "Courier", fontSize: 25, bold: true, textAlignment: "left"),
                CanvasElement(kind: .text, text: "MUST SAVE\nconfirmation codes\noffline map\npassport copy", x: 680, y: 1430, width: 365, height: 176, rotation: 2, zIndex: 16, colorHex: "#604B39", backgroundHex: "#F6E0BA", fontSize: 26, bold: true, textAlignment: "left"),
                CanvasElement(kind: .text, text: "replace photos with ticket, hotel, and first-stop screenshots", x: 540, y: 1620, width: 720, height: 84, rotation: -1, zIndex: 17, colorHex: "#6B523E", backgroundHex: "#E9EFD9", fontSize: 30, italic: true),
                CanvasElement(kind: .sticker, symbol: "calendar.badge.clock", x: 215, y: 340, width: 98, height: 88, rotation: -10, zIndex: 18, colorHex: "#A75F49"),
                CanvasElement(kind: .sticker, symbol: "checkmark.seal.fill", x: 850, y: 1520, width: 96, height: 86, rotation: 12, zIndex: 19, colorHex: "#6F8E68"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 535, y: 515, width: 670, height: 34, rotation: -1, zIndex: 20, opacity: 0.36, colorHex: "#D6B26D", cornerRadius: 10),
                CanvasElement(kind: .text, text: "visa / charger / cash / offline address / rainy plan", x: 540, y: 523, width: 630, height: 50, rotation: -1, zIndex: 21, colorHex: "#6B523E", backgroundHex: "#F6E7C7", fontName: "Courier", fontSize: 24, textAlignment: "left")
            ]
        ),
        PageTemplateDefinition(
            id: "map-memory",
            title: "Route Memory",
            subtitle: "A layered route page with map space, station tabs, ticket scraps, and numbered stops.",
            tags: ["map", "route", "notes", "ticket", "scrapbook", "global", "during-travel", "route-flow", "step-by-step"],
            background: CanvasBackground(colorA: "#FBF2DE", colorB: "#DDECE2"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 548, y: 926, width: 845, height: 1335, rotation: 1, zIndex: 1, opacity: 0.82, colorHex: "#FFF9EC", stroke: true, cornerRadius: 44),
                CanvasElement(kind: .text, text: "ROUTE MAP", x: 354, y: 176, width: 420, height: 74, rotation: -2, zIndex: 2, colorHex: "#4B5A47", backgroundHex: "#FFF9ED", fontSize: 44, bold: true),
                CanvasElement(kind: .wordArt, text: "places we found", x: 575, y: 292, width: 650, height: 126, rotation: -2, zIndex: 3, colorHex: "#A94F3F", fontSize: 66, bold: true),
                CanvasElement(kind: .text, text: "DAY 02  /  01 WALK  02 TRAIN  03 SAVE RECEIPTS", x: 545, y: 405, width: 760, height: 66, zIndex: 4, colorHex: "#4D523F", backgroundHex: "#E7EDD9", fontSize: 25, bold: true),
                CanvasElement(kind: .image, x: 486, y: 692, width: 704, height: 540, rotation: 1.5, zIndex: 5, colorHex: "#E5D2AF", shadow: true, stroke: true, cornerRadius: 24),
                CanvasElement(kind: .tape, x: 304, y: 440, width: 250, height: 58, rotation: -10, zIndex: 6, opacity: 0.9, colorHex: "#D6B66D"),
                CanvasElement(kind: .tape, x: 726, y: 940, width: 300, height: 58, rotation: 8, zIndex: 7, opacity: 0.88, colorHex: "#9DB89E"),
                CanvasElement(kind: .text, text: "north gate", x: 268, y: 532, width: 190, height: 52, rotation: -6, zIndex: 8, colorHex: "#7A573F", backgroundHex: "#F2D9AE", fontSize: 27, bold: true),
                CanvasElement(kind: .text, text: "river path", x: 720, y: 794, width: 190, height: 52, rotation: 5, zIndex: 9, colorHex: "#3F5C54", backgroundHex: "#DDEBE4", fontSize: 27, bold: true),
                CanvasElement(kind: .image, x: 756, y: 1130, width: 330, height: 260, rotation: 6, zIndex: 10, colorHex: "#DCE7E1", shadow: true, stroke: true, cornerRadius: 20),
                CanvasElement(kind: .text, text: "ROUTE FLOW\n01  station exit B\n02  bakery corner\n03  old bridge\n04  sunset stop", x: 318, y: 1146, width: 470, height: 282, rotation: -2, zIndex: 11, colorHex: "#433B31", backgroundHex: "#FFFDF5", fontSize: 31, bold: true, textAlignment: "left"),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-lineart__lat-0__lng-0__name-map-pin__tags-map-地图-lineart-线条-sticker.png", x: 800, y: 325, width: 170, height: 170, rotation: 10, zIndex: 12, colorHex: "#B76549", shadow: true),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-vintage__lat-0__lng-0__name-passport__tags-passport-护照-vintage-复古-sticker.png", x: 252, y: 1438, width: 235, height: 194, rotation: -8, zIndex: 13, colorHex: "#7E8C74", shadow: true),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-lineart__lat-0__lng-0__name-ticket__tags-ticket-机票-lineart-线条-sticker.png", x: 742, y: 1435, width: 250, height: 185, rotation: 7, zIndex: 14, colorHex: "#AF664C", shadow: true),
                CanvasElement(kind: .text, text: "ticket notes", x: 620, y: 1294, width: 250, height: 58, rotation: 1, zIndex: 15, colorHex: "#6F5A3D", backgroundHex: "#F2DBB2", fontSize: 30, bold: true),
                CanvasElement(kind: .text, text: "platform 3  /  16:42\nwindow seat, warm light\nkeep the transfer receipt", x: 580, y: 1422, width: 455, height: 165, rotation: 2, zIndex: 16, colorHex: "#4D4338", backgroundHex: "#FFF8EA", fontSize: 30, textAlignment: "left"),
                CanvasElement(kind: .text, text: "miles, stamps, snack receipts", x: 590, y: 1634, width: 560, height: 78, rotation: -1, zIndex: 17, colorHex: "#6F5A3D", backgroundHex: "#F2DBB2", fontSize: 34, italic: true),
                CanvasElement(kind: .sticker, symbol: "location.fill", x: 360, y: 690, width: 90, height: 80, rotation: -8, zIndex: 18, colorHex: "#B05F42"),
                CanvasElement(kind: .sticker, symbol: "tram.fill", x: 675, y: 560, width: 100, height: 90, rotation: 7, zIndex: 19, colorHex: "#5E755D"),
                CanvasElement(kind: .sticker, symbol: "sparkles", x: 232, y: 910, width: 84, height: 78, rotation: -12, zIndex: 20, colorHex: "#C28B5D"),
                CanvasElement(kind: .connector, x: 540, y: 718, width: 440, height: 250, rotation: 0, zIndex: 21, opacity: 0.72, colorHex: "#B05F42", strokeWidth: 8, connectorStartPoint: CodablePoint(x: 330, y: 650), connectorEndPoint: CodablePoint(x: 750, y: 820)),
                CanvasElement(kind: .text, text: "MAP SCRAPS", x: 258, y: 785, width: 210, height: 54, rotation: -7, zIndex: 22, colorHex: "#4B5A47", backgroundHex: "#F7E2BC", fontSize: 27, bold: true),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 520, y: 1020, width: 625, height: 30, rotation: -1, zIndex: 23, opacity: 0.35, colorHex: "#D6B66D", cornerRadius: 10),
                CanvasElement(kind: .sticker, symbol: "flag.fill", x: 820, y: 915, width: 82, height: 76, rotation: 9, zIndex: 24, colorHex: "#B05F42")
            ]
        ),
        PageTemplateDefinition(
            id: "photo-stack",
            title: "Trip Photo Receipt",
            subtitle: "Layered photo collage with receipt notes, tape corners, and tiny keepsake labels.",
            tags: ["photo", "stack", "moments", "grid", "collage", "receipt", "global", "after-travel", "memory", "keepsake", "trip-recap"],
            background: CanvasBackground(colorA: "#FFF7EA", colorB: "#E8DCD2"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 918, width: 850, height: 1325, rotation: -0.5, zIndex: 1, opacity: 0.8, colorHex: "#FFFDF5", stroke: true, cornerRadius: 44),
                CanvasElement(kind: .wordArt, text: "tiny moments", x: 470, y: 205, width: 670, height: 132, rotation: -3, zIndex: 2, colorHex: "#533D32", fontSize: 70, bold: true),
                CanvasElement(kind: .text, text: "01 SHOOT  /  02 KEEP RECEIPT  /  03 WRITE NOTE", x: 595, y: 306, width: 690, height: 66, zIndex: 3, colorHex: "#76563E", backgroundHex: "#F7E4BF", fontSize: 25, bold: true),
                CanvasElement(kind: .text, text: "35mm roll  /  receipt no. 0427  /  cloudy afternoon", x: 540, y: 390, width: 740, height: 62, rotation: -1, zIndex: 4, colorHex: "#6A563D", backgroundHex: "#FDF2DD", fontSize: 25, bold: true),
                CanvasElement(kind: .image, x: 320, y: 600, width: 420, height: 320, rotation: -6, zIndex: 5, colorHex: "#E7D3B5", shadow: true, stroke: true, cornerRadius: 18),
                CanvasElement(kind: .image, x: 720, y: 628, width: 370, height: 430, rotation: 5, zIndex: 6, colorHex: "#D8E2D4", shadow: true, stroke: true, cornerRadius: 18),
                CanvasElement(kind: .image, x: 350, y: 1038, width: 370, height: 430, rotation: 4, zIndex: 7, colorHex: "#E4C6B4", shadow: true, stroke: true, cornerRadius: 18),
                CanvasElement(kind: .image, x: 700, y: 1130, width: 435, height: 330, rotation: -4, zIndex: 8, colorHex: "#DCE6EB", shadow: true, stroke: true, cornerRadius: 18),
                CanvasElement(kind: .tape, x: 300, y: 420, width: 230, height: 54, rotation: -12, zIndex: 9, opacity: 0.9, colorHex: "#C6B07A"),
                CanvasElement(kind: .tape, x: 728, y: 412, width: 250, height: 54, rotation: 11, zIndex: 10, opacity: 0.9, colorHex: "#B7C9A7"),
                CanvasElement(kind: .tape, x: 338, y: 1288, width: 250, height: 54, rotation: 11, zIndex: 11, opacity: 0.84, colorHex: "#C68D72"),
                CanvasElement(kind: .tape, x: 715, y: 922, width: 245, height: 54, rotation: -9, zIndex: 12, opacity: 0.82, colorHex: "#D8B66E"),
                CanvasElement(kind: .text, text: "CAFE 14:20", x: 252, y: 812, width: 230, height: 54, rotation: -5, zIndex: 13, colorHex: "#694936", backgroundHex: "#F7DDBE", fontSize: 27, bold: true),
                CanvasElement(kind: .text, text: "STATION LIGHT", x: 705, y: 890, width: 285, height: 54, rotation: 4, zIndex: 14, colorHex: "#4A5545", backgroundHex: "#E8EEDC", fontSize: 27, bold: true),
                CanvasElement(kind: .text, text: "RECEIPT\nmilk tea  18\npostcard   6\nmetro      4\nsunset     free", x: 210, y: 1435, width: 275, height: 235, rotation: -3, zIndex: 15, colorHex: "#4D4338", backgroundHex: "#FFF7E8", fontName: "Courier", fontSize: 24, bold: true, textAlignment: "left"),
                CanvasElement(kind: .text, text: "today smelled like rain, coffee, train seats, and paper maps", x: 596, y: 1488, width: 570, height: 118, rotation: 1, zIndex: 16, colorHex: "#4D4338", backgroundHex: "#FFF9EE", fontSize: 34, italic: true),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-watercolor__lat-0__lng-0__name-camera__tags-camera-相机-watercolor-水彩-sticker.png", x: 805, y: 1460, width: 185, height: 165, rotation: 10, zIndex: 17, colorHex: "#A7664E", shadow: true),
                CanvasElement(kind: .image, localPath: "country-global__city-travel-icons__cat-vintage__lat-0__lng-0__name-ticket__tags-ticket-机票-vintage-复古-sticker.png", x: 300, y: 270, width: 190, height: 145, rotation: -12, zIndex: 18, colorHex: "#A7664E", shadow: true),
                CanvasElement(kind: .text, text: "KEEP", x: 842, y: 284, width: 126, height: 48, rotation: 8, zIndex: 19, colorHex: "#74432F", backgroundHex: "#F4D2C2", fontSize: 26, bold: true),
                CanvasElement(kind: .sticker, symbol: "heart.fill", x: 845, y: 725, width: 80, height: 70, rotation: 12, zIndex: 20, colorHex: "#C06E5A"),
                CanvasElement(kind: .sticker, symbol: "sparkles", x: 226, y: 1190, width: 86, height: 80, rotation: -12, zIndex: 21, colorHex: "#B7634C"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 520, y: 1320, width: 675, height: 32, rotation: -2, zIndex: 22, opacity: 0.32, colorHex: "#C6B07A", cornerRadius: 10),
                CanvasElement(kind: .text, text: "film 05 / window seat / bakery bag", x: 575, y: 1328, width: 560, height: 54, rotation: -2, zIndex: 23, colorHex: "#7B6244", backgroundHex: "#F6E6C7", fontName: "Courier", fontSize: 23, textAlignment: "left"),
                CanvasElement(kind: .sticker, symbol: "scissors", x: 820, y: 1180, width: 76, height: 70, rotation: 14, zIndex: 24, colorHex: "#8A6546"),
                CanvasElement(kind: .text, text: "PAID", x: 418, y: 1608, width: 128, height: 48, rotation: -8, zIndex: 25, colorHex: "#873B31", backgroundHex: "#F4D2C2", fontSize: 26, bold: true)
            ]
        ),
        PageTemplateDefinition(
            id: "guangzhou-morning-tea",
            title: "广州早茶日记",
            subtitle: "Liwan dim sum spread with menu notes, tape, and local stickers.",
            city: "Guangzhou",
            country: "China",
            tags: ["广州", "Guangzhou", "早茶", "点心", "荔湾", "dim sum", "Liwan", "China", "Guangdong", "during-travel", "city-log", "food-memory", "restaurant-log"],
            background: CanvasBackground(colorA: "#FFF2D7", colorB: "#EAD2A7"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 930, width: 835, height: 1325, rotation: -1, zIndex: 0, opacity: 0.66, colorHex: "#FFF8EA", stroke: true, cornerRadius: 42),
                CanvasElement(kind: .text, text: "LIWAN TABLE", x: 330, y: 188, width: 410, height: 72, rotation: -2, zIndex: 1, colorHex: "#7C553C", backgroundHex: "#FFF9EA", fontSize: 40, bold: true),
                CanvasElement(kind: .wordArt, text: "广州早茶", x: 560, y: 295, width: 680, height: 150, rotation: -1, zIndex: 2, colorHex: "#8D432F", fontName: "Georgia", fontSize: 80, bold: true),
                CanvasElement(kind: .image, x: 398, y: 690, width: 565, height: 450, rotation: -4, zIndex: 3, colorHex: "#F5E3C4", shadow: true, cornerRadius: 26),
                CanvasElement(kind: .image, x: 735, y: 960, width: 335, height: 390, rotation: 5, zIndex: 4, colorHex: "#F9EAD0", shadow: true, cornerRadius: 22),
                CanvasElement(kind: .tape, x: 360, y: 430, width: 280, height: 62, rotation: -11, zIndex: 5, opacity: 0.9, colorHex: "#DDB56F"),
                CanvasElement(kind: .tape, x: 760, y: 755, width: 245, height: 58, rotation: 12, zIndex: 6, opacity: 0.86, colorHex: "#C98E65"),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-liwan__lat-23.115__lng-113.24__name-dim-sum-watercolor__tags-早茶-food-watercolor-点心-sticker.png", x: 800, y: 365, width: 230, height: 205, rotation: 9, zIndex: 7, colorHex: "#F3B76B", shadow: true),
                CanvasElement(kind: .text, text: "01 点单\n虾饺 / 烧卖 / 奶黄包\n02 排队号：____\n03 茶位：____", x: 300, y: 1175, width: 445, height: 275, rotation: -2, zIndex: 8, colorHex: "#6A4A35", backgroundHex: "#FFF8E8", fontSize: 32, bold: true, textAlignment: "left"),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-common__lat-23.129__lng-113.264__name-kapok-flower__tags-木棉花-flower-city-flower-nature-sticker.png", x: 735, y: 1268, width: 210, height: 210, rotation: -8, zIndex: 9, colorHex: "#C4563F", shadow: true),
                CanvasElement(kind: .text, text: "04 地点 / 日期 / 同行人", x: 540, y: 1460, width: 720, height: 86, rotation: 1, zIndex: 10, colorHex: "#8D593D", backgroundHex: "#F6DFAE", fontSize: 32, bold: true),
                CanvasElement(kind: .text, text: "茶单", x: 735, y: 780, width: 150, height: 54, rotation: 6, zIndex: 11, colorHex: "#8D4B34", backgroundHex: "#F7D9B4", fontSize: 30, bold: true),
                CanvasElement(kind: .text, text: "morning queue\nsteam, cups, voices", x: 705, y: 1135, width: 340, height: 124, rotation: 4, zIndex: 12, colorHex: "#684832", backgroundHex: "#FFF9EC", fontSize: 29, italic: true, textAlignment: "left"),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-liwan__lat-23.115__lng-113.24__name-dim-sum__tags-早茶-food-local-点心.png", x: 230, y: 910, width: 205, height: 170, rotation: -8, zIndex: 13, colorHex: "#C77A4B", shadow: true),
                CanvasElement(kind: .sticker, symbol: "cup.and.saucer.fill", x: 238, y: 340, width: 110, height: 95, rotation: -11, zIndex: 14, colorHex: "#9B4F34"),
                CanvasElement(kind: .sticker, symbol: "leaf.fill", x: 865, y: 1455, width: 96, height: 86, rotation: 12, zIndex: 15, colorHex: "#7E8C58"),
                CanvasElement(kind: .text, text: "table no. 18\ntea: pu-erh\nshared with ____", x: 735, y: 575, width: 320, height: 138, rotation: 4, zIndex: 16, colorHex: "#6A4A35", backgroundHex: "#FFF8E8", fontName: "Courier", fontSize: 26, textAlignment: "left"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 325, y: 1375, width: 420, height: 34, rotation: -2, zIndex: 17, opacity: 0.34, colorHex: "#DDB56F", cornerRadius: 10),
                CanvasElement(kind: .text, text: "MENU STAMP", x: 835, y: 915, width: 170, height: 50, rotation: 9, zIndex: 18, colorHex: "#8D4B34", backgroundHex: "#F6DFAE", fontSize: 25, bold: true),
                CanvasElement(kind: .sticker, symbol: "seal.fill", x: 205, y: 1530, width: 82, height: 76, rotation: -10, zIndex: 19, colorHex: "#C4563F")
            ]
        ),
        PageTemplateDefinition(
            id: "guangzhou-pearl-river-night",
            title: "珠江夜游",
            subtitle: "Night cruise collage with deep paper, tickets, tower, and river light.",
            city: "Guangzhou",
            country: "China",
            tags: ["广州", "Guangzhou", "珠江", "夜游", "广州塔", "Pearl River", "Canton Tower", "night", "China", "during-travel", "route-flow", "ticket-log"],
            background: CanvasBackground(colorA: "#17202A", colorB: "#4B5C68"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 932, width: 825, height: 1315, rotation: 1, zIndex: 0, opacity: 0.36, colorHex: "#213140", stroke: true, cornerRadius: 44),
                CanvasElement(kind: .tape, x: 540, y: 164, width: 650, height: 74, rotation: -2, zIndex: 1, opacity: 0.72, colorHex: "#A66B48"),
                CanvasElement(kind: .wordArt, text: "珠江夜游", x: 520, y: 258, width: 740, height: 156, rotation: -1, zIndex: 2, colorHex: "#F5CF78", fontName: "Georgia", fontSize: 82, bold: true, shadow: true),
                CanvasElement(kind: .text, text: "Pearl River Cruise  /  city lights", x: 540, y: 378, width: 660, height: 64, zIndex: 3, colorHex: "#DCE8F0", backgroundHex: "#263948", fontSize: 34, bold: true),
                CanvasElement(kind: .image, x: 515, y: 750, width: 710, height: 500, rotation: 2, zIndex: 4, colorHex: "#263948", shadow: true, cornerRadius: 28),
                CanvasElement(kind: .image, x: 292, y: 1115, width: 315, height: 250, rotation: -7, zIndex: 5, colorHex: "#32475A", shadow: true, cornerRadius: 22),
                CanvasElement(kind: .tape, x: 735, y: 506, width: 270, height: 58, rotation: 12, zIndex: 6, opacity: 0.86, colorHex: "#D8B96B"),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-tianhe__lat-23.106__lng-113.324__name-canton-tower-clouds__tags-广州塔-landmark-clouds-tower-sticker.png", x: 800, y: 1088, width: 260, height: 320, rotation: 4, zIndex: 7, colorHex: "#F2C078", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-tianhe__lat-23.117__lng-113.317__name-pearl-river-cruise__tags-珠江-cruise-night-river-sticker.png", x: 350, y: 1290, width: 290, height: 225, rotation: -5, zIndex: 8, colorHex: "#A9C0D2", shadow: true),
                CanvasElement(kind: .text, text: "01 boarding  20:30\n02 deck wind / neon water\n03 keep ticket edge", x: 560, y: 1428, width: 675, height: 172, rotation: 1, zIndex: 9, colorHex: "#F7E6B8", backgroundHex: "#22313F", fontSize: 31, bold: true, textAlignment: "left"),
                CanvasElement(kind: .sticker, symbol: "sparkles", x: 200, y: 450, width: 125, height: 120, rotation: -12, zIndex: 10, colorHex: "#F7D487"),
                CanvasElement(kind: .sticker, symbol: "moon.stars.fill", x: 820, y: 246, width: 125, height: 120, rotation: 8, zIndex: 11, colorHex: "#F7D487"),
                CanvasElement(kind: .text, text: "ticket  A12\npier 3", x: 240, y: 940, width: 240, height: 116, rotation: -6, zIndex: 12, colorHex: "#F4DFA8", backgroundHex: "#2B3F4D", fontName: "Courier", fontSize: 30, bold: true, textAlignment: "left"),
                CanvasElement(kind: .text, text: "ROUTE  01 Haixinsha  /  02 Canton Tower  /  03 Shamian", x: 540, y: 1232, width: 750, height: 76, rotation: -1, zIndex: 13, colorHex: "#DCE8F0", backgroundHex: "#34495A", fontSize: 25, bold: true),
                CanvasElement(kind: .tape, x: 300, y: 1200, width: 220, height: 52, rotation: -13, zIndex: 14, opacity: 0.8, colorHex: "#8FAFC3"),
                CanvasElement(kind: .sticker, symbol: "ferry.fill", x: 755, y: 1328, width: 116, height: 96, rotation: 7, zIndex: 15, colorHex: "#F2C078"),
                CanvasElement(kind: .sticker, symbol: "star.fill", x: 292, y: 610, width: 72, height: 68, rotation: -8, zIndex: 16, colorHex: "#F7D487"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 520, y: 535, width: 610, height: 34, rotation: 1, zIndex: 17, opacity: 0.34, colorHex: "#D8B96B", cornerRadius: 10),
                CanvasElement(kind: .text, text: "deck wind / neon water / keep ticket edge", x: 535, y: 545, width: 570, height: 52, rotation: 1, zIndex: 18, colorHex: "#F7E6B8", backgroundHex: "#243646", fontName: "Courier", fontSize: 24, textAlignment: "left"),
                CanvasElement(kind: .text, text: "NIGHT LOG", x: 735, y: 905, width: 210, height: 54, rotation: 5, zIndex: 19, colorHex: "#F2C078", backgroundHex: "#263948", fontSize: 29, bold: true),
                CanvasElement(kind: .sticker, symbol: "circle.grid.cross.fill", x: 202, y: 1572, width: 84, height: 78, rotation: -12, zIndex: 20, colorHex: "#8FAFC3")
            ]
        ),
        PageTemplateDefinition(
            id: "guangzhou-old-town-walk",
            title: "老城漫步",
            subtitle: "Shamian, arcades, and Lingnan architecture as a walking scrapbook.",
            city: "Guangzhou",
            country: "China",
            tags: ["广州", "Guangzhou", "老城", "沙面", "骑楼", "陈家祠", "岭南", "Shamian", "arcade", "China", "during-travel", "route-flow", "city-walk"],
            background: CanvasBackground(colorA: "#F8F0E1", colorB: "#DDE8D8"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 925, width: 840, height: 1320, rotation: -0.8, zIndex: 0, opacity: 0.72, colorHex: "#FFFDF5", stroke: true, cornerRadius: 42),
                CanvasElement(kind: .text, text: "OLD TOWN WALK", x: 538, y: 192, width: 700, height: 88, rotation: -1, zIndex: 1, colorHex: "#3D4D3E", backgroundHex: "#FFFDF5", fontName: "Georgia", fontSize: 58, bold: true),
                CanvasElement(kind: .wordArt, text: "老城漫步", x: 530, y: 305, width: 650, height: 138, rotation: 2, zIndex: 2, colorHex: "#A86047", fontSize: 74, bold: true),
                CanvasElement(kind: .image, x: 345, y: 645, width: 475, height: 390, rotation: -6, zIndex: 3, colorHex: "#EEE1CB", shadow: true, cornerRadius: 22),
                CanvasElement(kind: .image, x: 705, y: 865, width: 460, height: 380, rotation: 5, zIndex: 4, colorHex: "#E8D7BF", shadow: true, cornerRadius: 22),
                CanvasElement(kind: .image, x: 350, y: 1188, width: 360, height: 285, rotation: -3, zIndex: 5, colorHex: "#E6D9BF", shadow: true, cornerRadius: 20),
                CanvasElement(kind: .tape, x: 330, y: 432, width: 260, height: 58, rotation: -12, zIndex: 6, opacity: 0.88, colorHex: "#D2B47B"),
                CanvasElement(kind: .tape, x: 705, y: 655, width: 260, height: 58, rotation: 12, zIndex: 7, opacity: 0.88, colorHex: "#9BB394"),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-liwan__lat-23.11__lng-113.24__name-shamian-island__tags-沙面-european-colonial-vintage-sticker.png", x: 780, y: 498, width: 230, height: 190, rotation: 8, zIndex: 8, colorHex: "#7AA08C", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-liwan__lat-23.115__lng-113.24__name-shangxiajiu-arcade__tags-上下九-arcade-lingnan-heritage-sticker.png", x: 275, y: 990, width: 260, height: 215, rotation: -9, zIndex: 9, colorHex: "#B77255", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-liwan__lat-23.129__lng-113.239__name-chen-clan-ancestral-hall__tags-陈家祠-ancestral-lingnan-architecture-stick.png", x: 700, y: 1248, width: 285, height: 230, rotation: 4, zIndex: 10, colorHex: "#9E6F54", shadow: true),
                CanvasElement(kind: .text, text: "01 沙面  /  02 上下九  /  03 陈家祠\n骑楼阴影里慢慢走", x: 540, y: 1480, width: 740, height: 142, zIndex: 11, colorHex: "#3D4D3E", backgroundHex: "#FFFDF5", fontSize: 32, bold: true, textAlignment: "left"),
                CanvasElement(kind: .text, text: "stop 01", x: 220, y: 470, width: 160, height: 54, rotation: -8, zIndex: 12, colorHex: "#7C553C", backgroundHex: "#F4DDB8", fontSize: 28, bold: true),
                CanvasElement(kind: .text, text: "facade notes\narches / tile / shade", x: 730, y: 1080, width: 300, height: 124, rotation: 5, zIndex: 13, colorHex: "#4A5545", backgroundHex: "#EEF4E8", fontSize: 28, italic: true, textAlignment: "left"),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-liwan__lat-23.115__lng-113.24__name-wok-ear-wall__tags-镬耳墙-lingnan-architecture-element-sticker.png", x: 820, y: 1392, width: 190, height: 165, rotation: 8, zIndex: 14, colorHex: "#9E6F54", shadow: true),
                CanvasElement(kind: .tape, x: 360, y: 1360, width: 245, height: 54, rotation: 9, zIndex: 15, opacity: 0.84, colorHex: "#B8C79E"),
                CanvasElement(kind: .sticker, symbol: "figure.walk", x: 212, y: 1345, width: 100, height: 92, rotation: -8, zIndex: 16, colorHex: "#3D4D3E"),
                CanvasElement(kind: .text, text: "shade map\narcade corner\nold stone step", x: 290, y: 830, width: 320, height: 138, rotation: -5, zIndex: 17, colorHex: "#594A38", backgroundHex: "#FFF8EA", fontName: "Courier", fontSize: 26, textAlignment: "left"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 560, y: 448, width: 620, height: 30, rotation: -1, zIndex: 18, opacity: 0.35, colorHex: "#D2B47B", cornerRadius: 10),
                CanvasElement(kind: .text, text: "stop 02   old facade   snack window   photo wall", x: 585, y: 455, width: 560, height: 50, rotation: -1, zIndex: 19, colorHex: "#7C553C", backgroundHex: "#F4E2C4", fontSize: 23, textAlignment: "left"),
                CanvasElement(kind: .sticker, symbol: "camera.viewfinder", x: 845, y: 805, width: 88, height: 82, rotation: 11, zIndex: 20, colorHex: "#B77255")
            ]
        ),
        PageTemplateDefinition(
            id: "guangzhou-city-postcard",
            title: "广州城市明信片",
            subtitle: "City postcard with kapok, tower stamp, and handbook labels.",
            city: "Guangzhou",
            country: "China",
            tags: ["广州", "Guangzhou", "明信片", "广州塔", "木棉花", "postcard", "kapok", "landmark", "China", "after-travel", "city-card", "share-card"],
            background: CanvasBackground(colorA: "#FDF0D6", colorB: "#E4EEE8"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 930, width: 845, height: 1325, rotation: 0.8, zIndex: 0, opacity: 0.7, colorHex: "#FFFDF5", stroke: true, cornerRadius: 42),
                CanvasElement(kind: .text, text: "POSTCARD FROM", x: 362, y: 180, width: 470, height: 72, rotation: -2, zIndex: 1, colorHex: "#7D6042", backgroundHex: "#FFFDF5", fontSize: 40, bold: true),
                CanvasElement(kind: .wordArt, text: "Guangzhou", x: 500, y: 300, width: 700, height: 150, rotation: -3, zIndex: 2, colorHex: "#B84E3B", fontName: "Georgia", fontSize: 78, bold: true),
                CanvasElement(kind: .image, x: 515, y: 705, width: 735, height: 535, rotation: -1, zIndex: 3, colorHex: "#E8D7BF", shadow: true, cornerRadius: 28),
                CanvasElement(kind: .tape, x: 330, y: 440, width: 280, height: 60, rotation: -11, zIndex: 4, opacity: 0.88, colorHex: "#D7B66E"),
                CanvasElement(kind: .tape, x: 715, y: 960, width: 300, height: 60, rotation: 8, zIndex: 5, opacity: 0.88, colorHex: "#A8B997"),
                CanvasElement(kind: .image, x: 690, y: 1178, width: 340, height: 260, rotation: 4, zIndex: 6, colorHex: "#DCE7E1", shadow: true, cornerRadius: 20),
                CanvasElement(kind: .text, text: "01 广州 / China\n02 DATE ______\n03 PLACE _____", x: 360, y: 1190, width: 450, height: 165, rotation: -2, zIndex: 7, colorHex: "#3D4D3E", backgroundHex: "#FFFFFF", fontSize: 30, bold: true, textAlignment: "left"),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-common__lat-23.129__lng-113.264__name-kapok-flower__tags-木棉花-flower-city-flower-nature-sticker.png", x: 245, y: 1370, width: 210, height: 210, rotation: -8, zIndex: 8, colorHex: "#D65F4A", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-guangzhou__cat-tianhe__lat-23.106__lng-113.324__name-canton-tower-clouds__tags-广州塔-landmark-clouds-tower-sticker.png", x: 795, y: 325, width: 255, height: 310, rotation: 7, zIndex: 9, colorHex: "#7AA08C", shadow: true),
                CanvasElement(kind: .text, text: "city flower / river wind / morning tea", x: 575, y: 1462, width: 600, height: 76, rotation: 2, zIndex: 10, colorHex: "#7D6042", backgroundHex: "#F6E0BA", fontSize: 34, italic: true),
                CanvasElement(kind: .text, text: "STAMP\n23.129 N\n113.264 E", x: 790, y: 1190, width: 230, height: 144, rotation: 5, zIndex: 11, colorHex: "#405D53", backgroundHex: "#EFF5EA", fontName: "Courier", fontSize: 26, bold: true),
                CanvasElement(kind: .text, text: "Dear ____\nToday I kept this light.", x: 350, y: 1350, width: 390, height: 118, rotation: -2, zIndex: 12, colorHex: "#594A38", backgroundHex: "#FFF8EA", fontSize: 30, textAlignment: "left"),
                CanvasElement(kind: .sticker, symbol: "paperplane.fill", x: 840, y: 925, width: 102, height: 90, rotation: 14, zIndex: 13, colorHex: "#C4563F"),
                CanvasElement(kind: .sticker, symbol: "circle.hexagongrid.fill", x: 230, y: 425, width: 88, height: 82, rotation: -10, zIndex: 14, colorHex: "#D7B66E"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 520, y: 1008, width: 655, height: 34, rotation: 1, zIndex: 15, opacity: 0.34, colorHex: "#A8B997", cornerRadius: 10),
                CanvasElement(kind: .text, text: "postmark / tram bell / warm pavement", x: 510, y: 1016, width: 575, height: 50, rotation: 1, zIndex: 16, colorHex: "#405D53", backgroundHex: "#E9F1E8", fontName: "Courier", fontSize: 24, textAlignment: "left"),
                CanvasElement(kind: .text, text: "AIR MAIL", x: 250, y: 1560, width: 170, height: 54, rotation: -8, zIndex: 17, colorHex: "#963A2F", backgroundHex: "#F6E0BA", fontSize: 29, bold: true),
                CanvasElement(kind: .sticker, symbol: "envelope.fill", x: 785, y: 1540, width: 92, height: 80, rotation: 9, zIndex: 18, colorHex: "#7AA08C")
            ]
        ),
        PageTemplateDefinition(
            id: "shenzhen-coastal-fieldbook",
            title: "深圳海岸手册",
            subtitle: "Coastal Shenzhen fieldbook with bridge, bay, and taped snapshots.",
            city: "Shenzhen",
            country: "China",
            tags: ["深圳", "Shenzhen", "深圳湾", "南山", "海岸", "bridge", "bay", "Nanshan", "China", "Guangdong", "during-travel", "route-flow", "fieldbook"],
            background: CanvasBackground(colorA: "#F4E7D1", colorB: "#DDEBE8"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 930, width: 835, height: 1320, rotation: -0.6, zIndex: 0, opacity: 0.7, colorHex: "#FFF9ED", stroke: true, cornerRadius: 42),
                CanvasElement(kind: .text, text: "SHENZHEN BAY", x: 410, y: 185, width: 520, height: 74, rotation: -2, zIndex: 1, colorHex: "#44605B", backgroundHex: "#FFF9ED", fontSize: 42, bold: true),
                CanvasElement(kind: .wordArt, text: "海岸手册", x: 558, y: 305, width: 650, height: 138, rotation: 1, zIndex: 2, colorHex: "#2F6B72", fontSize: 74, bold: true),
                CanvasElement(kind: .image, x: 375, y: 650, width: 500, height: 405, rotation: -5, zIndex: 3, colorHex: "#D9E5E1", shadow: true, cornerRadius: 24),
                CanvasElement(kind: .image, x: 704, y: 925, width: 455, height: 380, rotation: 5, zIndex: 4, colorHex: "#F0DAB8", shadow: true, cornerRadius: 24),
                CanvasElement(kind: .tape, x: 340, y: 430, width: 260, height: 58, rotation: -12, zIndex: 5, opacity: 0.88, colorHex: "#C7A96B"),
                CanvasElement(kind: .tape, x: 735, y: 700, width: 260, height: 58, rotation: 12, zIndex: 6, opacity: 0.88, colorHex: "#88AAA1"),
                CanvasElement(kind: .image, localPath: "country-china__city-shenzhen__cat-nanshan__lat-22.498__lng-113.948__name-shenzhen-bay-bridge__tags-深圳湾大桥-bridge-sea-coastal-sticker.png", x: 770, y: 470, width: 260, height: 200, rotation: 8, zIndex: 7, colorHex: "#6FA4A5", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-shenzhen__cat-common__lat-22.508__lng-113.95__name-shenzhen-bay-bird__tags-深圳湾-mangrove-bird-nature-sticker.png", x: 292, y: 1095, width: 235, height: 205, rotation: -8, zIndex: 8, colorHex: "#6E8E74", shadow: true),
                CanvasElement(kind: .text, text: "01 Nanshan  /  02 Bay Park  /  03 sea wind\nweather: ________  steps: ________", x: 540, y: 1375, width: 740, height: 154, rotation: -1, zIndex: 9, colorHex: "#394C47", backgroundHex: "#FFFDF5", fontSize: 31, bold: true, textAlignment: "left"),
                CanvasElement(kind: .sticker, symbol: "sailboat.fill", x: 795, y: 1295, width: 130, height: 118, rotation: 10, zIndex: 10, colorHex: "#2F6B72"),
                CanvasElement(kind: .image, x: 336, y: 1120, width: 300, height: 250, rotation: -3, zIndex: 11, colorHex: "#E7D5B6", shadow: true, cornerRadius: 20),
                CanvasElement(kind: .text, text: "tide notes\nmangrove shade\nbridge line", x: 720, y: 1104, width: 340, height: 130, rotation: 4, zIndex: 12, colorHex: "#34524F", backgroundHex: "#EAF3EF", fontSize: 29, italic: true, textAlignment: "left"),
                CanvasElement(kind: .tape, x: 330, y: 912, width: 220, height: 52, rotation: 10, zIndex: 13, opacity: 0.84, colorHex: "#D2B071"),
                CanvasElement(kind: .sticker, symbol: "water.waves", x: 235, y: 345, width: 110, height: 90, rotation: -10, zIndex: 14, colorHex: "#2F6B72"),
                CanvasElement(kind: .text, text: "FIELD LOG", x: 745, y: 784, width: 230, height: 56, rotation: 5, zIndex: 15, colorHex: "#6D5840", backgroundHex: "#F4DDB8", fontSize: 28, bold: true),
                CanvasElement(kind: .text, text: "tide  ___  wind  ___\nfound shell / bridge shadow", x: 345, y: 835, width: 405, height: 118, rotation: -4, zIndex: 16, colorHex: "#34524F", backgroundHex: "#FFF9ED", fontName: "Courier", fontSize: 25, textAlignment: "left"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 535, y: 1265, width: 660, height: 32, rotation: -1, zIndex: 17, opacity: 0.36, colorHex: "#88AAA1", cornerRadius: 10),
                CanvasElement(kind: .text, text: "bay park / mangrove / bridge line / late sun", x: 540, y: 1228, width: 620, height: 50, rotation: -1, zIndex: 18, colorHex: "#44605B", backgroundHex: "#E5F0EC", fontSize: 24, textAlignment: "left"),
                CanvasElement(kind: .sticker, symbol: "binoculars.fill", x: 850, y: 610, width: 92, height: 82, rotation: 10, zIndex: 19, colorHex: "#6E8E74")
            ]
        ),
        PageTemplateDefinition(
            id: "shenzhen-city-walk",
            title: "深圳城市漫游",
            subtitle: "Urban Shenzhen collage for parks, landmarks, electronics, and notes.",
            city: "Shenzhen",
            country: "China",
            tags: ["深圳", "Shenzhen", "南山", "福田", "华强北", "人才公园", "city", "electronics", "China", "Guangdong", "during-travel", "route-flow", "city-walk"],
            background: CanvasBackground(colorA: "#F8F3E8", colorB: "#E2E7D8"),
            elements: [
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 930, width: 835, height: 1320, rotation: 0.7, zIndex: 0, opacity: 0.7, colorHex: "#FFFDF5", stroke: true, cornerRadius: 42),
                CanvasElement(kind: .wordArt, text: "Shenzhen", x: 485, y: 220, width: 680, height: 142, rotation: -3, zIndex: 1, colorHex: "#375D62", fontName: "Georgia", fontSize: 76, bold: true),
                CanvasElement(kind: .text, text: "城市漫游 / parks, towers, markets", x: 590, y: 330, width: 650, height: 64, zIndex: 2, colorHex: "#6D5840", backgroundHex: "#FFF8EA", fontSize: 34, bold: true),
                CanvasElement(kind: .image, x: 320, y: 610, width: 390, height: 360, rotation: -6, zIndex: 3, colorHex: "#E4D4B8", shadow: true, cornerRadius: 20),
                CanvasElement(kind: .image, x: 715, y: 680, width: 390, height: 460, rotation: 4, zIndex: 4, colorHex: "#DCE7E1", shadow: true, cornerRadius: 20),
                CanvasElement(kind: .image, x: 385, y: 1080, width: 430, height: 330, rotation: 5, zIndex: 5, colorHex: "#EACBBC", shadow: true, cornerRadius: 20),
                CanvasElement(kind: .tape, x: 310, y: 405, width: 245, height: 54, rotation: -12, zIndex: 6, opacity: 0.88, colorHex: "#C9B46F"),
                CanvasElement(kind: .tape, x: 730, y: 425, width: 260, height: 54, rotation: 11, zIndex: 7, opacity: 0.88, colorHex: "#9AB3A2"),
                CanvasElement(kind: .image, localPath: "country-china__city-shenzhen__cat-futian__lat-22.544__lng-114.087__name-huaqiangbei__tags-华强北-electronics-technology-sticker.png", x: 770, y: 1088, width: 245, height: 205, rotation: 9, zIndex: 8, colorHex: "#A7664E", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-shenzhen__cat-nanshan__lat-22.514__lng-113.933__name-talent-park__tags-人才公园-park-city-nanshan-sticker.png", x: 260, y: 1325, width: 235, height: 205, rotation: -8, zIndex: 9, colorHex: "#6F8E68", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-shenzhen__cat-common__lat-22.508__lng-113.95__name-shenzhen-bay-bird__tags-深圳湾-mangrove-bird-nature-sticker.png", x: 790, y: 250, width: 185, height: 185, rotation: 9, zIndex: 10, colorHex: "#6E8E74", shadow: true),
                CanvasElement(kind: .text, text: "01 metro line: ____\n02 coffee stop: ____\n03 found object: ____", x: 560, y: 1435, width: 680, height: 178, rotation: -1, zIndex: 11, colorHex: "#3F453B", backgroundHex: "#FFFDF5", fontSize: 31, bold: true, textAlignment: "left"),
                CanvasElement(kind: .text, text: "ROUTE CARD\n01 Nanshan\n02 Futian\n03 Shekou", x: 635, y: 1245, width: 440, height: 160, rotation: 3, zIndex: 12, colorHex: "#375D62", backgroundHex: "#EAF1EC", fontSize: 27, bold: true, textAlignment: "left"),
                CanvasElement(kind: .image, localPath: "country-china__city-shenzhen__cat-nanshan__lat-22.517__lng-113.935__name-spring-bamboo-tower__tags-春笋大厦-landmark-modern-nanshan-sticker.png", x: 235, y: 900, width: 220, height: 250, rotation: -8, zIndex: 13, colorHex: "#6F8E68", shadow: true),
                CanvasElement(kind: .image, localPath: "country-china__city-shenzhen__cat-shekou__lat-22.488__lng-113.907__name-minghua-cruise__tags-海上世界-minghua-cruise-shekou-sticker.png", x: 800, y: 1390, width: 230, height: 190, rotation: 8, zIndex: 14, colorHex: "#477A84", shadow: true),
                CanvasElement(kind: .text, text: "market glow", x: 720, y: 910, width: 250, height: 56, rotation: 4, zIndex: 15, colorHex: "#704F3C", backgroundHex: "#F3D7BC", fontSize: 28, bold: true),
                CanvasElement(kind: .sticker, symbol: "tram.fill", x: 240, y: 390, width: 106, height: 92, rotation: -10, zIndex: 16, colorHex: "#375D62"),
                CanvasElement(kind: .text, text: "city walk kit\nmetro card / battery / iced tea", x: 320, y: 805, width: 360, height: 122, rotation: -5, zIndex: 17, colorHex: "#3F453B", backgroundHex: "#FFF8EA", fontName: "Courier", fontSize: 25, textAlignment: "left"),
                CanvasElement(kind: .shape, symbol: "rounded-rectangle", x: 540, y: 420, width: 660, height: 30, rotation: -1, zIndex: 18, opacity: 0.34, colorHex: "#C9B46F", cornerRadius: 10),
                CanvasElement(kind: .text, text: "parks / towers / electronics market / ferry lights", x: 550, y: 428, width: 630, height: 50, rotation: -1, zIndex: 19, colorHex: "#6D5840", backgroundHex: "#F1E4C5", fontSize: 24, textAlignment: "left"),
                CanvasElement(kind: .sticker, symbol: "cpu.fill", x: 850, y: 1000, width: 86, height: 80, rotation: 10, zIndex: 20, colorHex: "#A7664E")
            ]
        )
    ]

    static func templates(matching location: TemplateLocation?, query: String = "", scope: TemplateLocationScope = .recommended) -> [PageTemplateDefinition] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let locationFiltered = builtIn.filter { template in
            switch scope {
            case .recommended:
                guard let location, !location.tokens.isEmpty else { return true }
                guard template.city != nil || template.country != nil else { return true }
                return template.matches(location: location)
            case .currentCity:
                guard let location, !location.tokens.isEmpty else { return false }
                return template.matches(location: location)
            case .all:
                return true
            }
        }
        guard !normalizedQuery.isEmpty else { return locationFiltered }
        return locationFiltered.filter { template in
            template.templateSearchTokens.contains { $0.lowercased().contains(normalizedQuery) }
        }
    }
}

struct TemplateLocation {
    var city: String?
    var country: String?
    var placeName: String?
    var regionName: String?

    var displayName: String {
        [placeName, city, country]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .first ?? "All destinations"
    }

    var tokens: [String] {
        ([placeName, city, regionName, country].compactMap { $0 } + [displayName])
            .flatMap(\.templateLocationTokens)
    }
}

enum TemplateLocationScope: String, CaseIterable, Identifiable {
    case recommended
    case currentCity
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: return "Recommended"
        case .currentCity: return "This Place"
        case .all: return "All"
        }
    }
}

extension PageTemplateDefinition {
    func matches(location: TemplateLocation) -> Bool {
        let templateTokens = ([city, country].compactMap { $0 } + tags).flatMap(\.templateLocationTokens)
        guard !templateTokens.isEmpty, !location.tokens.isEmpty else { return false }
        return location.tokens.contains { token in
            templateTokens.contains { value in value == token || value.contains(token) || token.contains(value) }
        }
    }

    var templateSearchTokens: [String] {
        [title, id, subtitle ?? "", city ?? "", country ?? ""] + tags
    }
}

private extension String {
    var templateLocationKey: String {
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

    var templateLocationTokens: [String] {
        let base = templateLocationKey
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
        for alias in aliases[base] ?? [] {
            tokens.insert(alias)
        }
        return Array(tokens)
    }
}
