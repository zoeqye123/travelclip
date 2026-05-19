//
//  ContentView.swift
//  travelclip
//
//  Created by moc on 2026/5/18.
//

import SwiftUI

struct ContentView: View {
    private let collageItems = [
        CollageItem(title: "Kinkaku-ji", subtitle: "today", icon: "building.columns", tint: .sand),
        CollageItem(title: "Nishiki Market", subtitle: "yesterday", icon: "cup.and.saucer.fill", tint: .sage),
        CollageItem(title: "Photo Booth", subtitle: "memo strip", icon: "photo.on.rectangle", tint: .mist)
    ]

    private let notebooks = [
        Notebook(title: "Cloud Notebook", count: 1, tint: .sage, symbol: "cloud.sun.fill"),
        Notebook(title: "My Album", count: 0, tint: .sand, symbol: "photo.stack"),
        Notebook(title: "Route Memo", count: 3, tint: .mist, symbol: "map.fill"),
        Notebook(title: "Notes", count: 6, tint: .clay, symbol: "note.text")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HeaderView()
                    SearchCard()
                    CreateBanner()
                    NotebookSection(notebooks: notebooks)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 116)
            }

            BottomTabBar()
        }
        .background(
            PaperBackground()
                .ignoresSafeArea()
        )
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
                    Text("Kyoto, Japan")
                    Text("· now")
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

            Circle()
                .fill(Color.sage.opacity(0.18))
                .frame(width: 50, height: 50)
                .offset(x: -92, y: -38)

            Circle()
                .fill(Color.clay.opacity(0.16))
                .frame(width: 58, height: 58)
                .offset(x: 96, y: 56)

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
    var body: some View {
        HStack(spacing: 10) {
            Button {
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.clay)

                    Text("Start creating")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .background(Color.banner)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(DashedRoundedBorder(radius: 20, color: .lineSoft, lineWidth: 1.6))
            }
            .buttonStyle(.plain)

            Button {
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.clay)

                    Text("Template")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 110, height: 108)
                .background(Color.banner)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(DashedRoundedBorder(radius: 20, color: .lineSoft, lineWidth: 1.6))
            }
            .buttonStyle(.plain)
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.bannerSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.lineSoft, lineWidth: 1.5)
        )
    }
}

private struct CollageSection: View {
    let items: [CollageItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Journals")
                    .sectionTitle()

                Spacer()

                Text("See all")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.sage)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        CollageCard(item: item)
                    }
                }
                .padding(.horizontal, 3)
                .padding(.bottom, 4)
            }
        }
    }
}

private struct CollageCard: View {
    let item: CollageItem

    var body: some View {
        Button {
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.tint.opacity(0.18))

                    Image(systemName: item.icon)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(item.tint)
                }
                .frame(height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paper)
            }
            .frame(width: 156, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(item.tint.opacity(0.33), lineWidth: 1.4)
            )
            .shadow(color: Color.shadowSoft, radius: 7, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct NotebookSection: View {
    let notebooks: [Notebook]
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
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                        .frame(width: 38, height: 34)
                        .background(Color.paper)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1.2))
                }
                .buttonStyle(.plain)

                Button {
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
                ForEach(notebooks) { notebook in
                    NotebookCard(notebook: notebook)
                }
            }
        }
    }
}

private struct NotebookCard: View {
    let notebook: Notebook

    var body: some View {
        Button {
        } label: {
            ZStack(alignment: .bottom) {
                NotebookCover(notebook: notebook)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notebook.title)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("Note Number: \(notebook.count)")
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
    let notebook: Notebook

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

private struct TravelStamp: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.rose.opacity(0.12))
                .frame(width: 52, height: 52)

            Image(systemName: "airplane.departure")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.clay)
                .rotationEffect(.degrees(-8))
        }
    }
}

private struct ScrapbookCover: View {
    let notebook: Notebook

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    notebook.tint.opacity(0.22),
                    Color.panelDeep.opacity(0.6),
                    Color.paper
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<4) { index in
                Circle()
                    .fill(Color.paper.opacity(0.5))
                    .frame(width: CGFloat(20 + index * 9), height: CGFloat(20 + index * 9))
                    .position(x: CGFloat(34 + index * 34), y: CGFloat(26 + (index % 2) * 74))
            }

            VStack(spacing: 10) {
                Image(systemName: notebook.symbol)
                    .font(.system(size: 37, weight: .medium))
                    .foregroundStyle(notebook.tint)
                    .frame(width: 76, height: 76)
                    .background(
                        Circle()
                            .fill(Color.paper.opacity(0.72))
                    )

                Text("travel clip")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(notebook.tint.opacity(0.88))
            }
        }
    }
}

private struct CollageItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
}

private struct Notebook: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let tint: Color
    let symbol: String
}

private struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let selected: Bool
}

private extension Text {
    func sectionTitle() -> some View {
        self
            .font(.system(size: 24, weight: .bold, design: .serif))
            .foregroundStyle(Color.ink)
    }
}

private extension Color {
    static let background = Color(red: 0.968, green: 0.956, blue: 0.932)
    static let paper = Color(red: 0.992, green: 0.984, blue: 0.962)
    static let panel = Color(red: 0.981, green: 0.971, blue: 0.944)
    static let panelDeep = Color(red: 0.905, green: 0.867, blue: 0.785)
    static let banner = Color(red: 0.990, green: 0.962, blue: 0.860)
    static let bannerSoft = Color(red: 0.973, green: 0.946, blue: 0.895)
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let inkSoft = Color(red: 0.56, green: 0.54, blue: 0.50)
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
