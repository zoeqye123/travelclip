//
//  ContentView.swift
//  travelclip
//
//  Created by moc on 2026/5/18.
//

import SwiftUI

struct ContentView: View {
    private let quickActions = [
        QuickAction(title: "Map", icon: "map", tint: .terracotta),
        QuickAction(title: "Journal", icon: "book.closed", tint: .leaf),
        QuickAction(title: "Calendar", icon: "calendar", tint: .sky),
        QuickAction(title: "Sticker", icon: "face.smiling", tint: .rose)
    ]

    private let collageItems = [
        CollageItem(title: "City Walk", subtitle: "photo notes", icon: "figure.walk", tint: .sky),
        CollageItem(title: "Packing", subtitle: "trip list", icon: "shippingbox", tint: .sand),
        CollageItem(title: "Photo Booth", subtitle: "memory strip", icon: "camera.viewfinder", tint: .rose)
    ]

    private let notebooks = [
        Notebook(title: "Tokyo Weekend", count: 18, tint: .leaf, symbol: "tram.fill"),
        Notebook(title: "Coast Album", count: 9, tint: .sky, symbol: "sailboat.fill"),
        Notebook(title: "Market Finds", count: 12, tint: .terracotta, symbol: "basket.fill"),
        Notebook(title: "Dream Routes", count: 6, tint: .rose, symbol: "sparkles")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            PaperBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HeaderView()

                    QuickActionGrid(actions: quickActions)

                    CreateBanner()

                    CollageSection(items: collageItems)

                    NotebookSection(notebooks: notebooks)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 112)
            }

            BottomTabBar()
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.paper)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle()
                            .stroke(Color.lineSoft, lineWidth: 1.5)
                    )

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.terracotta)

                Text("NEW")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.rose))
                    .offset(x: 20, y: -4)
            }
            .frame(width: 48, height: 44)

            Text("travelclip")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)

            Spacer()

            HeaderButton(icon: "bell")
            HeaderButton(icon: "gearshape")
        }
    }
}

private struct HeaderButton: View {
    let icon: String

    var body: some View {
        Button {
        } label: {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(icon))
    }
}

private struct QuickActionGrid: View {
    let actions: [QuickAction]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(actions) { action in
                Button {
                } label: {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(action.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        HStack {
                            Spacer()
                            Image(systemName: action.icon)
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(action.tint)
                        }
                    }
                    .padding(14)
                    .frame(height: 86)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.paper)
                            .shadow(color: Color.ink.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.lineSoft, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CreateBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Button {
            } label: {
                HStack(spacing: 14) {
                    TravelStamp()

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Color.terracotta)

                    Text("Start Creating")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .frame(height: 106)
                .frame(maxWidth: .infinity)
                .background(Color.noteYellow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(DashedRoundedBorder(radius: 17, color: .mustard, lineWidth: 2))
            }
            .buttonStyle(.plain)

            Button {
            } label: {
                VStack(spacing: 11) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.terracotta)

                    Text("Template")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 104, height: 106)
                .background(Color.noteYellow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(DashedRoundedBorder(radius: 17, color: .mustard, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(Color.noteYellow.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(Color.mustard, lineWidth: 2)
        )
    }
}

private struct CollageSection: View {
    let items: [CollageItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fun Collage")
                .sectionTitle()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        CollageCard(item: item)
                    }
                }
                .padding(.horizontal, 2)
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
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(item.tint.opacity(0.18))

                    Image(systemName: item.icon)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(item.tint)
                }
                .frame(height: 72)

                VStack(spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(item.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 42)
                .frame(maxWidth: .infinity)
                .background(Color.paper.opacity(0.92))
            }
            .frame(width: 148, height: 116)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(item.tint.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: Color.ink.opacity(0.04), radius: 10, x: 0, y: 5)
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.inkSoft)
                        .frame(width: 42, height: 36)
                        .background(Capsule().fill(Color.paper))
                        .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                Button {
                } label: {
                    Label("New Group", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .padding(.horizontal, 15)
                        .frame(height: 36)
                        .background(Capsule().fill(Color.paper))
                        .overlay(Capsule().stroke(Color.lineSoft, lineWidth: 1.5))
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
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ScrapbookCover(notebook: notebook)
                        .frame(height: 154)

                    TicketStub()
                        .offset(x: 12, y: 80)
                }

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(notebook.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.66)

                        Text("Note Number: \(notebook.count)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                }
                .padding(12)
                .frame(height: 70)
                .background(Color.paper)
                .overlay(DashedRoundedBorder(radius: 11, color: .lineStrong, lineWidth: 1.8))
            }
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.lineSoft, lineWidth: 1.5)
            )
            .shadow(color: Color.ink.opacity(0.08), radius: 10, x: 1, y: 7)
        }
        .buttonStyle(.plain)
    }
}

private struct BottomTabBar: View {
    private let tabs = [
        TabItem(title: "Home", icon: "house.fill", selected: true),
        TabItem(title: "Store", icon: "storefront", selected: false),
        TabItem(title: "Trips", icon: "globe.asia.australia", selected: false),
        TabItem(title: "Me", icon: "person.crop.circle", selected: false)
    ]

    var body: some View {
        HStack {
            ForEach(tabs) { tab in
                Button {
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(tab.selected ? Color.ink : Color.inkSoft)

                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(tab.selected ? Color.ink : Color.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                        .stroke(Color.lineSoft, lineWidth: 1.5)
                )
        )
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
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [7, 6]))
            .padding(8)
    }
}

private struct TravelStamp: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.rose.opacity(0.16))
                .frame(width: 58, height: 58)

            Image(systemName: "airplane.departure")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.terracotta)
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
                    notebook.tint.opacity(0.35),
                    Color.noteYellow.opacity(0.7),
                    Color.paper
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<5) { index in
                Circle()
                    .fill(Color.paper.opacity(0.55))
                    .frame(width: CGFloat(18 + index * 8), height: CGFloat(18 + index * 8))
                    .position(x: CGFloat(28 + index * 31), y: CGFloat(24 + (index % 2) * 78))
            }

            VStack(spacing: 10) {
                Image(systemName: notebook.symbol)
                    .font(.system(size: 37, weight: .semibold))
                    .foregroundStyle(notebook.tint)
                    .frame(width: 76, height: 76)
                    .background(
                        Circle()
                            .fill(Color.paper.opacity(0.72))
                    )

                Text("travel clip")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(notebook.tint.opacity(0.88))
            }
        }
    }
}

private struct TicketStub: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.paper.opacity(0.9))
            .frame(width: 78, height: 42)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .overlay(
                Image(systemName: "circle.dashed")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.lineStrong)
                    .offset(x: -18)
            )
            .shadow(color: Color.ink.opacity(0.06), radius: 5, x: 1, y: 3)
    }
}

private struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
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
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ink)
    }
}

private extension Color {
    static let background = Color(red: 0.985, green: 0.973, blue: 0.948)
    static let paper = Color(red: 1.0, green: 0.992, blue: 0.965)
    static let noteYellow = Color(red: 1.0, green: 0.929, blue: 0.667)
    static let ink = Color(red: 0.16, green: 0.135, blue: 0.115)
    static let inkSoft = Color(red: 0.55, green: 0.52, blue: 0.48)
    static let gridLine = Color(red: 0.79, green: 0.75, blue: 0.68).opacity(0.26)
    static let lineSoft = Color(red: 0.82, green: 0.72, blue: 0.59).opacity(0.5)
    static let lineStrong = Color(red: 0.64, green: 0.61, blue: 0.56).opacity(0.65)
    static let mustard = Color(red: 0.77, green: 0.50, blue: 0.21)
    static let terracotta = Color(red: 0.67, green: 0.36, blue: 0.25)
    static let leaf = Color(red: 0.42, green: 0.62, blue: 0.45)
    static let sky = Color(red: 0.32, green: 0.59, blue: 0.74)
    static let rose = Color(red: 0.86, green: 0.43, blue: 0.49)
    static let sand = Color(red: 0.78, green: 0.62, blue: 0.40)
}

#Preview {
    ContentView()
}
