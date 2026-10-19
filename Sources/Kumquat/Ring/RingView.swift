import AppKit
import KumquatCore
import SwiftUI
import UniformTypeIdentifiers

/// A ring slice with parallel gaps and soft corners.
struct AnnularSector: Shape {
    var start: Double
    var end: Double
    var inner: CGFloat
    var outer: CGFloat
    var gap: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let gi = Double(gap / 2 / max(inner, 1)), go = Double(gap / 2 / max(outer, 1))
        let q = Double.pi / 2
        var p = Path()
        p.addArc(center: c, radius: outer, startAngle: .radians(start + go - q), endAngle: .radians(end - go - q), clockwise: false)
        p.addArc(center: c, radius: inner, startAngle: .radians(end - gi - q), endAngle: .radians(start + gi - q), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct RingView: View {
    @ObservedObject var model: RingModel
    var theme: Theme
    /// When false the ring is drawn without the key hint pill (used in previews).
    var showsHint = true

    @Environment(\.colorScheme) private var systemScheme

    private var geo: RingGeometry { RingGeometry(diameter: theme.size) }
    private var scale: CGFloat { theme.size / 300 }
    private var dark: Bool { (theme.colorScheme ?? systemScheme) == .dark }

    var body: some View {
        ZStack {
            GlassDisc(theme: theme, dark: dark)
                .frame(width: geo.diameter, height: geo.diameter)

            ZStack {
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    slice(index: index, item: item)
                }
            }
            .id(model.page)
            .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity),
                                    removal: .scale(scale: 1.1).combined(with: .opacity)))


            hub
            if showsHint, model.progress == nil { hint.offset(y: geo.outerRadius + 16 * scale) }
        }
        // Bigger than the disc: scale/rotation/opacity render into a layer clipped to this frame,
        // and the soft shadow needs room or it gets cut into a square.
        .frame(width: geo.diameter * RingGeometry.canvasScale, height: geo.diameter * RingGeometry.canvasScale)
        .scaleEffect(model.shown ? 1 : 0.86)
        .rotationEffect(.degrees(model.shown ? 0 : -12))
        .opacity(model.shown ? 1 : 0)
        .animation(theme.animated ? .spring(response: 0.2, dampingFraction: 0.78) : nil, value: model.shown)
        .animation(theme.animated ? .spring(response: 0.25, dampingFraction: 0.7) : nil, value: model.hovered)
        .animation(theme.animated ? .spring(response: 0.3, dampingFraction: 0.8) : nil, value: model.page)
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    // MARK: Slices

    private var sliceFill: SwiftUI.Color {
        dark ? SwiftUI.Color(white: 0.16).opacity(theme.sliceOpacity) : SwiftUI.Color.white.opacity(theme.sliceOpacity)
    }

    @ViewBuilder
    private func slice(index: Int, item: RingItem) -> some View {
        let count = model.items.count
        let start = geo.startAngle(index, of: count)
        let end = start + 2 * .pi / Double(count)
        let corner = 7 * scale
        let shape = AnnularSector(start: start, end: end, inner: geo.sliceInner + corner, outer: geo.sliceOuter - corner, gap: 5 * scale + corner * 2)
        let isHot = model.hovered == index || model.chosen == index
        let mid = (start + end) / 2

        ZStack {
            Group {
                if isHot {
                    Rectangle().fill(theme.gradient)
                } else {
                    Rectangle().fill(sliceFill)
                }
            }
            .mask {
                ZStack {
                    shape.fill(.black)
                    shape.stroke(.black, style: StrokeStyle(lineWidth: corner * 2, lineJoin: .round))
                }
            }
            .shadow(color: isHot ? theme.accent2.opacity(0.45) : .clear, radius: 10 * scale, y: 3 * scale)

            label(item, hot: isHot)
                .offset(x: CGFloat(sin(mid)) * geo.labelRadius, y: CGFloat(-cos(mid)) * geo.labelRadius)
        }
        .frame(width: geo.diameter, height: geo.diameter)
        .scaleEffect(isHot ? 1.035 : 1)
        // While an action runs, everything but the chosen slice steps back.
        .opacity(model.progress != nil && !isHot ? 0.35 : 1)
    }

    @ViewBuilder
    private func label(_ item: RingItem, hot: Bool) -> some View {
        let color: SwiftUI.Color = hot ? .white : (dark ? .white.opacity(0.92) : .black.opacity(0.78))
        VStack(spacing: 2 * scale) {
            if theme.labels != .text {
                Image(systemName: item.symbol)
                    .font(.system(size: (theme.labels == .icon ? 19 : 13) * scale, weight: .semibold))
            }
            if theme.labels != .icon {
                Text(item.title.uppercased())
                    .font(.system(size: 10.5 * scale, weight: .heavy, design: .rounded))
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 62 * scale)
            }
        }
        .foregroundStyle(color)
    }

    // MARK: Hub

    private var hub: some View {
        ZStack {
            Circle()
                .fill(dark ? SwiftUI.Color(white: 0.1).opacity(0.75) : SwiftUI.Color.white.opacity(0.82))
                .overlay(Circle().strokeBorder(theme.gradient.opacity(0.9), lineWidth: 2 * scale))
                .shadow(color: .black.opacity(0.12), radius: 6 * scale, y: 2 * scale)

            if let progress = model.progress {
                RingProgress(progress: progress, finished: model.finished, theme: theme, scale: scale,
                             title: model.chosen.flatMap { model.items.indices.contains($0) ? model.items[$0].title : nil } ?? "")
                    .transition(.opacity)
            } else if let hovered = model.hovered, model.items.indices.contains(hovered) {
                let item = model.items[hovered]
                VStack(spacing: 3 * scale) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 18 * scale, weight: .semibold))
                        .foregroundStyle(theme.gradient)
                    Text(item.title)
                        .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: geo.hubRadius * 1.6)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 2 * scale) {
                    ZStack(alignment: .topTrailing) {
                        FileIcon(urls: model.files)
                            .frame(width: 34 * scale, height: 34 * scale)
                        if model.files.count > 1 {
                            Text("\(model.files.count)")
                                .font(.system(size: 9 * scale, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4 * scale).padding(.vertical, 1 * scale)
                                .background(Capsule().fill(theme.gradient))
                                .offset(x: 6 * scale, y: -3 * scale)
                        }
                    }
                    Text(model.page == 0 ? L("Convert") : L("Tools"))
                        .font(.system(size: 10 * scale, weight: .heavy, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(theme.gradient)
                }
                .transition(.opacity)
            }
        }
        .frame(width: geo.hubRadius * 2, height: geo.hubRadius * 2)
    }

    // MARK: Hint

    private var hint: some View {
        let key = SettingsStore.shared.triggerKey.symbol
        return HStack(spacing: 6 * scale) {
            Text(key)
                .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                .padding(.horizontal, 5 * scale).padding(.vertical, 1 * scale)
                .background(RoundedRectangle(cornerRadius: 4 * scale).strokeBorder(.secondary.opacity(0.6)))
            ForEach(0..<2) { i in
                Text(i == 0 ? L("Convert") : L("Tools"))
                    .font(.system(size: 10.5 * scale, weight: i == model.page ? .heavy : .medium, design: .rounded))
                    .foregroundStyle(i == model.page ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(.secondary))
            }
        }
        .padding(.horizontal, 10 * scale).padding(.vertical, 5 * scale)
        .background(Capsule().fill(dark ? SwiftUI.Color(white: 0.12).opacity(0.85) : .white.opacity(0.85)))
        .overlay(Capsule().strokeBorder(.white.opacity(dark ? 0.12 : 0.6)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .opacity(model.hasTools && !model.pages[0].isEmpty ? 1 : 0)
    }
}

/// Progress around the hub, then a check mark (or a cross) when done.
struct RingProgress: View {
    var progress: Double
    var finished: Bool?
    var theme: Theme
    var scale: CGFloat
    var title: String
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle().stroke(theme.accent.opacity(0.18), lineWidth: 5 * scale)
            Group {
                if let finished {
                    Circle().stroke(finished ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(SwiftUI.Color.red.opacity(0.7)), lineWidth: 5 * scale)
                } else if progress < 0 {
                    // Unknown length: a spinning arc.
                    Circle().trim(from: 0, to: 0.28)
                        .stroke(theme.gradient, style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                        .onAppear { spin = true }
                } else {
                    Circle().trim(from: 0, to: max(0.04, progress))
                        .stroke(theme.gradient, style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.25), value: progress)
                }
            }
            VStack(spacing: 2 * scale) {
                if let finished {
                    Image(systemName: finished ? "checkmark" : "xmark")
                        .font(.system(size: 26 * scale, weight: .bold))
                        .foregroundStyle(finished ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(SwiftUI.Color.red))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(progress < 0 ? title : "\(Int(progress * 100))%")
                        .font(.system(size: 13 * scale, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(theme.gradient)
                }
            }
            .padding(10 * scale)
        }
        .padding(7 * scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: finished)
    }
}

/// The Finder icon of the dragged file (or a stack for several).
struct FileIcon: View {
    let urls: [URL]

    var body: some View {
        if let first = urls.first {
            Image(nsImage: FileManager.default.fileExists(atPath: first.path)
                  ? NSWorkspace.shared.icon(forFile: first.path)
                  : NSWorkspace.shared.icon(for: UTType(filenameExtension: first.pathExtension) ?? .data))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc.fill").resizable().aspectRatio(contentMode: .fit).foregroundStyle(.secondary)
        }
    }
}

extension Theme {
    var animated: Bool { SettingsStore.shared.animations }
}
