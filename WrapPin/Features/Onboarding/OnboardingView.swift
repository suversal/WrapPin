import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0

    let isReplay: Bool
    private var pages: [OnboardingPage] {
        OnboardingPage.pages(usesBuiltInTunnel: appModel.usesBuiltInTunnel)
    }

    init(isReplay: Bool = false) {
        self.isReplay = isReplay
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("ROAM CONTROL")
                        .font(.caption.weight(.bold))
                        .tracking(2.2)
                        .foregroundStyle(.secondary)

                    if isReplay {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close introduction")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 22) {
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedPage ? Color.blue : Color.secondary.opacity(0.25))
                                .frame(width: index == selectedPage ? 24 : 8, height: 8)
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.3),
                                    value: selectedPage
                                )
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(
                            format: NSLocalizedString("Page %lld of %lld", comment: ""),
                            selectedPage + 1,
                            pages.count
                        )
                    )

                    Button {
                        advance()
                    } label: {
                        HStack {
                            Text(finalButtonTitle)
                            Image(systemName: finalButtonSymbol)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var isLastPage: Bool {
        selectedPage == pages.count - 1
    }

    private func advance() {
        if isLastPage {
            if isReplay {
                dismiss()
            } else {
                appModel.completeOnboarding()
            }
        } else {
            if reduceMotion {
                selectedPage += 1
            } else {
                withAnimation {
                    selectedPage += 1
                }
            }
        }
    }

    private var finalButtonTitle: String {
        if !isLastPage { return String(localized: "Continue") }
        return isReplay
            ? String(localized: "Done")
            : String(localized: "Set Up This iPhone")
    }

    private var finalButtonSymbol: String {
        if !isLastPage { return "arrow.right" }
        return isReplay ? "checkmark" : "iphone.and.arrow.forward"
    }
}

private struct OnboardingPageView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let page: OnboardingPage

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer(minLength: 20)

                    Image(systemName: page.symbol)
                        .font(.system(
                            size: dynamicTypeSize.isAccessibilitySize ? 46 : 64,
                            weight: .semibold
                        ))
                        .foregroundStyle(.white)
                        .frame(
                            width: dynamicTypeSize.isAccessibilitySize ? 96 : 132,
                            height: dynamicTypeSize.isAccessibilitySize ? 96 : 132
                        )
                        .background(
                            page.color,
                            in: RoundedRectangle(
                                cornerRadius: dynamicTypeSize.isAccessibilitySize ? 26 : 34,
                                style: .continuous
                            )
                        )
                        .shadow(color: page.color.opacity(0.22), radius: 18, y: 10)
                        .accessibilityHidden(true)

                    VStack(spacing: 14) {
                        Text(page.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(page.message)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)

                    if !page.requirements.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(page.requirements.enumerated()), id: \.offset) { index, item in
                                requirementRow(item)

                                if index < page.requirements.count - 1 {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .padding(.horizontal, 24)
                    }

                    if page.showsUsageStatisticsControl {
                        usageStatisticsCard
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func requirementRow(_ item: OnboardingRequirement) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))

                Text(item.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var usageStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                "Share Anonymous Usage Statistics",
                isOn: Binding(
                    get: { appModel.sharesAnonymousUsageStatistics },
                    set: appModel.setSharesAnonymousUsageStatistics
                )
            )
            .font(.headline)

            Label {
                Text("Off by default. Never includes locations, searches, routes, pairing data or personal information.")
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.green)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String
    let color: Color
    let requirements: [OnboardingRequirement]
    let showsUsageStatisticsControl: Bool

    init(
        symbol: String,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        color: Color,
        requirements: [OnboardingRequirement] = [],
        showsUsageStatisticsControl: Bool = false
    ) {
        self.symbol = symbol
        self.title = String(localized: title)
        self.message = String(localized: message)
        self.color = color
        self.requirements = requirements
        self.showsUsageStatisticsControl = showsUsageStatisticsControl
    }

    static func pages(usesBuiltInTunnel: Bool) -> [OnboardingPage] { [
        OnboardingPage(
            symbol: "location.viewfinder",
            title: "Welcome to WrapPin",
            message: "Search for a place or tap the map, then start a fixed location or preview a walking or driving route.",
            color: .blue
        ),
        OnboardingPage(
            symbol: "checklist",
            title: "Finish setup first",
            message: "Complete these steps once before starting a simulated location.",
            color: .orange,
            requirements: [
                OnboardingRequirement(
                    symbol: "hammer.fill",
                    title: String(localized: "Enable Developer Mode"),
                    message: String(localized: "Open Settings, then go to Privacy & Security > Developer Mode.")
                ),
                OnboardingRequirement(
                    symbol: "lock.shield.fill",
                    title: usesBuiltInTunnel
                        ? String(localized: "Allow WrapPin's built-in VPN")
                        : String(localized: "Install and connect LocalDevVPN"),
                    message: usesBuiltInTunnel
                        ? String(localized: "The first location session asks to add a VPN configuration; WrapPin then starts its local device tunnel automatically.")
                        : String(localized: "Keep its local tunnel connected while starting a location.")
                ),
                OnboardingRequirement(
                    symbol: "iphone.and.arrow.forward",
                    title: String(localized: "Pair this iPhone"),
                    message: String(localized: "The next screen will guide you through the private on-device pairing.")
                )
            ]
        ),
        OnboardingPage(
            symbol: "hand.raised.fill",
            title: "Private by design",
            message: "Choose whether to help improve WrapPin with anonymous activity counts. Sharing starts only if you switch it on and can be changed later in Settings.",
            color: .indigo,
            showsUsageStatisticsControl: true
        )
    ] }
}

private struct OnboardingRequirement {
    let symbol: String
    let title: String
    let message: String
}

#Preview {
    OnboardingView()
        .environment(AppModel())
}
