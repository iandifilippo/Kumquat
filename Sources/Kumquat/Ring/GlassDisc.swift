import AppKit
import SwiftUI

/// The round glass plate behind the slices.
struct GlassDisc: View {
    var theme: Theme
    var dark: Bool

    var body: some View {
        ZStack {
            // Soft shadow as a radial gradient that fades to fully clear well inside its own
            // frame. (A blurred circle gets clipped to its frame and leaves a straight edge;
            // .shadow on the AppKit blur view casts a square.)
            GeometryReader { geo in
                let r = min(geo.size.width, geo.size.height) / 2
                RadialGradient(
                    // The disc covers up to 0.77 of this radius: clear inside, darkest at the rim.
                    stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: .black.opacity(dark ? 0.42 : 0.22), location: 0.76),
                        .init(color: .black.opacity(dark ? 0.16 : 0.08), location: 0.85),
                        .init(color: .clear, location: 0.98),
                    ],
                    center: .center, startRadius: 0, endRadius: r * 1.3)
                    .frame(width: r * 2.6, height: r * 2.6)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + r * 0.06)
            }
            .allowsHitTesting(false)

            base
                .overlay(Circle().fill(theme.accent.opacity(dark ? 0.10 : 0.07)))
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(dark ? 0.35 : 0.85), .white.opacity(dark ? 0.05 : 0.25)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.2)
                )
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var base: some View {
        switch theme.glass {
        case .frosted where !theme.drawsBackdrop:
            SwiftUI.Color.clear
        case .liquid:
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                Circle().fill(.clear).glassEffect(.regular, in: Circle())
            } else if theme.drawsBackdrop {
                BlurView(material: dark ? .hudWindow : .popover, dark: dark)
            } else {
                SwiftUI.Color.clear
            }
            #else
            if theme.drawsBackdrop { BlurView(material: dark ? .hudWindow : .popover, dark: dark) } else { SwiftUI.Color.clear }
            #endif
        case .frosted:
            BlurView(material: dark ? .hudWindow : .popover, dark: dark)
        case .solid:
            Circle().fill(dark ? SwiftUI.Color(white: 0.13) : SwiftUI.Color(white: 0.96))
        case .snapshot:
            // A drawn imitation of frosted glass for offscreen renders.
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(dark ? 0.18 : 0.62), .white.opacity(dark ? 0.06 : 0.34)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.45), .clear], center: .init(x: 0.3, y: 0.15), startRadius: 0, endRadius: 160))
                )
                .background(Circle().fill(dark ? SwiftUI.Color.black.opacity(0.35) : SwiftUI.Color.white.opacity(0.12)))
        }
    }
}

/// NSVisualEffectView cut to a circle. The mask is an image redrawn on every layout,
/// because a layer mask or SwiftUI clipping would turn the live blur into a square.
final class RoundBlurView: NSVisualEffectView {
    override func layout() {
        super.layout()
        updateMask()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateMask()
    }

    private func updateMask() {
        let size = bounds.size
        guard size.width > 0, maskImage?.size != size else { return }
        maskImage = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }
}

struct BlurView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var dark: Bool

    func makeNSView(context: Context) -> RoundBlurView {
        let v = RoundBlurView()
        v.blendingMode = .behindWindow
        v.state = .active
        v.material = material
        return v
    }

    func updateNSView(_ v: RoundBlurView, context: Context) {
        v.material = material
        v.appearance = NSAppearance(named: dark ? .vibrantDark : .vibrantLight)
        v.needsLayout = true
    }
}
