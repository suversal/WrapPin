import SwiftUI

// MARK: - Liquid Glass Container

/// Groups adjacent floating glass controls so iOS 26+ Liquid Glass surfaces
/// optically blend and morph together, while falling back cleanly on iOS 18–25.
struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Liquid Glass Surface

private struct LiquidGlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    let tint: Color?
    let interactive: Bool
    let prominentShadow: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    tint?.opacity(0.14) ?? Color(uiColor: .secondarySystemBackground),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10),
                        lineWidth: 0.75
                    )
                }
                .shadow(
                    color: .black.opacity(prominentShadow ? 0.18 : 0.10),
                    radius: prominentShadow ? 16 : 10,
                    y: prominentShadow ? 8 : 4
                )
        } else if #available(iOS 26, *) {
            content.glassEffect(resolvedGlass, in: shape)
        } else {
            content
                .background {
                    shape
                        .fill(.regularMaterial)
                        .overlay {
                            if let tint {
                                shape.fill(tint.opacity(colorScheme == .dark ? 0.20 : 0.12))
                            }
                        }
                        .overlay {
                            // Specular top-edge rim gives iOS 18–25 frosted glass a crisp, tactile finish.
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? 0.26 : 0.65),
                                        .white.opacity(colorScheme == .dark ? 0.06 : 0.14),
                                        .black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.85
                            )
                        }
                }
                .shadow(
                    color: .black.opacity(
                        colorScheme == .dark
                            ? (prominentShadow ? 0.36 : 0.22)
                            : (prominentShadow ? 0.16 : 0.10)
                    ),
                    radius: prominentShadow ? 20 : 12,
                    y: prominentShadow ? 9 : 5
                )
        }
    }

    @available(iOS 26, *)
    private var resolvedGlass: Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
}

extension View {
    /// Applies native iOS 26+ Liquid Glass with an elevated frosted-glass fallback on iOS 18–25.
    func liquidGlassSurface<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        prominentShadow: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                shape: shape,
                tint: tint,
                interactive: interactive,
                prominentShadow: prominentShadow
            )
        )
    }

    /// Applies an interactive Liquid Glass capsule or circle for floating map controls.
    func liquidGlassControl<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil
    ) -> some View {
        liquidGlassSurface(in: shape, tint: tint, interactive: true, prominentShadow: false)
    }
}

// MARK: - Tactile & Glass Button Styles

/// Subtle spring scale feedback for custom floating buttons and interactive cards.
struct TactilePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var pressedScale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

/// Unified primary action button: uses `.glassProminent` on iOS 26+ and a tactile
/// capsule with subtle specular highlight on iOS 18–25.
private struct WrapPinPrimaryButtonModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(tint)
                .controlSize(.large)
        } else {
            content
                .buttonStyle(LegacyProminentCapsuleButtonStyle(tint: tint, isEnabled: isEnabled))
        }
    }
}

private struct LegacyProminentCapsuleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tint: Color
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .background {
                Capsule()
                    .fill(isEnabled ? tint : Color(uiColor: .secondarySystemFill))
                    .overlay {
                        if isEnabled {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.32), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                    }
            }
            .shadow(
                color: isEnabled ? tint.opacity(0.28) : .clear,
                radius: configuration.isPressed ? 4 : 10,
                y: configuration.isPressed ? 2 : 5
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.75),
                value: configuration.isPressed
            )
    }
}

/// Unified secondary action button: uses `.glass` on iOS 26+ and a crisp frosted
/// capsule on iOS 18–25.
private struct WrapPinSecondaryButtonModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    let tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                content
                    .buttonStyle(.glass)
                    .tint(tint)
                    .controlSize(.large)
            } else {
                content
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
        } else {
            content
                .buttonStyle(LegacySecondaryCapsuleButtonStyle(tint: tint, isEnabled: isEnabled))
        }
    }
}

private struct LegacySecondaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color?
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = {
            if !isEnabled { return .secondary }
            return tint ?? .primary
        }()

        return configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .foregroundStyle(foreground)
            .background {
                Capsule()
                    .fill(
                        tint.map { $0.opacity(colorScheme == .dark ? 0.18 : 0.11) }
                            ?? Color(uiColor: .secondarySystemFill)
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                (tint ?? Color.primary).opacity(colorScheme == .dark ? 0.22 : 0.12),
                                lineWidth: 0.75
                            )
                    }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.75),
                value: configuration.isPressed
            )
    }
}

extension View {
    func wrapPinPrimaryButton(tint: Color = .blue) -> some View {
        modifier(WrapPinPrimaryButtonModifier(tint: tint))
    }

    func wrapPinSecondaryButton(tint: Color? = nil) -> some View {
        modifier(WrapPinSecondaryButtonModifier(tint: tint))
    }
}

// MARK: - Live Pulse Indicator

/// Subtle breathing halo for active status dots and simulated location pins.
struct LivePulseRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let color: Color
    var diameter: CGFloat = 14
    var isActive: Bool = true

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.10))
            .overlay {
                Circle()
                    .strokeBorder(color.opacity(0.32), lineWidth: 1.25)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(isPulsing ? 1.55 : 0.92)
            .opacity(isActive && !reduceMotion ? (isPulsing ? 0 : 0.75) : 0)
            .onAppear {
                guard isActive, !reduceMotion else { return }
                startPulse()
            }
            .onChange(of: isActive) { _, active in
                if active, !reduceMotion {
                    startPulse()
                } else {
                    isPulsing = false
                }
            }
    }

    private func startPulse() {
        isPulsing = false
        withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}
