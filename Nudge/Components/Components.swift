import SwiftUI
import UIKit

// MARK: - Custom Accessibility Environment Keys

struct AppReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
struct AppDifferentiateWithoutColorKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
struct AppIncreaseContrastKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var appReduceMotion: Bool {
        get { self[AppReduceMotionKey.self] }
        set { self[AppReduceMotionKey.self] = newValue }
    }
    var appDifferentiateWithoutColor: Bool {
        get { self[AppDifferentiateWithoutColorKey.self] }
        set { self[AppDifferentiateWithoutColorKey.self] = newValue }
    }
    var appIncreaseContrast: Bool {
        get { self[AppIncreaseContrastKey.self] }
        set { self[AppIncreaseContrastKey.self] = newValue }
    }
}

// MARK: - Haptic Manager

enum HapticManager {
    /// Respects the user's "Haptic Feedback" preference (defaults to enabled).
    static var isEnabled: Bool {
        // UserDefaults.bool returns false for missing keys; treat missing as enabled.
        UserDefaults.standard.object(forKey: "hapticsEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    static func light()     { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()    { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()     { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success()   { guard isEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()     { guard isEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func warning()   { guard isEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { guard isEnabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - App Colors

enum AppColors {
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor.systemGroupedBackground
    })
    static let cardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1)
            : UIColor.secondarySystemGroupedBackground
    })
    static let elevatedCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1)
            : UIColor.tertiarySystemGroupedBackground
    })
}

// MARK: - Card Modifier

struct CardModifier: ViewModifier {
    @Environment(\.appIncreaseContrast) private var increaseContrast

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(increaseContrast ? 0.25 : 0), lineWidth: 1.5)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: InputStep
    @Environment(\.appReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(InputStep.allCases, id: \.rawValue) { step in
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: step.rawValue <= currentStep.rawValue ? geo.size.width : 0)
                        }
                        .clipShape(Capsule())
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(InputStep.allCases.count)")
        .accessibilityValue(currentStep.rawValue == InputStep.allCases.count - 1 ? "Final step" : "")
    }
}

// MARK: - Mood Chip

struct MoodChip: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appReduceMotion) private var reduceMotion
    @Environment(\.appDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.appIncreaseContrast) private var increaseContrast

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(mood.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(languageManager["mood.\(mood.rawValue)"])
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(increaseContrast ? 0.28 : 0.15) : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(increaseContrast ? 0.45 : 0.2),
                        lineWidth: increaseContrast ? 2.0 : 1.5
                    )
            )
            .overlay(
                Group {
                    if differentiateWithoutColor && isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 3.0)
                            .padding(1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? (reduceMotion ? 1.0 : 1.02) : 1.0)
        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel("\(languageManager["mood.\(mood.rawValue)"]) mood")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Energy Dot

struct EnergyDot: View {
    let level: EnergyLevel
    let isActive: Bool
    let action: () -> Void

    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appReduceMotion) private var reduceMotion
    @Environment(\.appDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.appIncreaseContrast) private var increaseContrast

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            VStack(spacing: 10) {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(increaseContrast ? 0.28 : 0.15))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isActive
                                    ? (differentiateWithoutColor ? Color.accentColor : Color.clear)
                                    : Color.secondary.opacity(increaseContrast ? 0.50 : 0),
                                lineWidth: 2.5
                            )
                    )
                    .overlay(
                        Group {
                            if isActive {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .accessibilityHidden(true)
                            } else {
                                Text(level.shortName)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(increaseContrast ? Color.primary : Color.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                    )

                Text(languageManager["energy.name.\(level.rawValue)"])
                    .font(.caption2)
                    .fontWeight(isActive ? .medium : .regular)
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isActive ? (reduceMotion ? 1.0 : 1.05) : 1.0)
        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .accessibilityLabel("Energy level: \(languageManager["energy.name.\(level.rawValue)"])")
        .accessibilityHint(isActive ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Energy Selector

struct EnergySelector: View {
    @Binding var selected: EnergyLevel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(EnergyLevel.allCases) { level in
                EnergyDot(
                    level: level,
                    isActive: level.rawValue <= selected.rawValue,
                    action: { selected = level }
                )
            }
        }
    }
}

// MARK: - Friction Badge

struct FrictionBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.15))
            .foregroundColor(.accentColor)
            .clipShape(Capsule())
    }
}

// MARK: - Empty State View (kept for backward compat, now unused by main views)

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(.accentColor.opacity(0.3))

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Horizontal Progress Timer

struct HorizontalTimerBar: View {
    let progress: Double // 0...1
    let label: String

    @State private var animatedProgress: Double = 0
    @Environment(\.appReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))

                    // Fill with smooth gradient
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.9), Color.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * animatedProgress))
                }
            }
            .frame(height: 5)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(animatedProgress * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(progress * 100)) percent complete")
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.6)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.35)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Skeleton Shimmer (Improved)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.appReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.15), location: 0.3),
                                .init(color: .white.opacity(0.3), location: 0.5),
                                .init(color: .white.opacity(0.15), location: 0.7),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: phase * geo.size.width * 2)
                        .mask(content)
                    }
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

struct SkeletonBlock: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(width: width, height: height)
            .modifier(ShimmerModifier())
    }
}

// MARK: - Progress Capsule (for cards)

struct ProgressCapsule: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < completed ? Color.accentColor : Color.secondary.opacity(0.15))
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(completed) of \(total) steps completed")
    }
}

// MARK: - Swipe To Delete Card

struct SwipeToDeleteCard<Content: View>: View {
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isRemoving = false

    private let revealWidth: CGFloat = 80

    @State private var cardHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red delete background — smoothly grows with swipe
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red)
                .frame(width: max(0, -offset), height: cardHeight > 0 ? cardHeight : nil)
                .overlay {
                    if !isRemoving && offset <= -revealWidth / 2 {
                        Image(systemName: "trash.fill")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                }
                .animation(.interactiveSpring(), value: offset)
                .opacity(offset < 0 ? 1 : 0)
                .onTapGesture { performDelete() }

            // Card content (slides left, no interactive children)
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { cardHeight = geo.size.height }
                    }
                )
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if offset == 0 {
                        onTap()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            offset = 0
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            guard !isRemoving else { return }
                            let h = value.translation.width

                            if h < 0 {
                                if abs(h) > revealWidth {
                                    offset = -revealWidth - pow(abs(h) - revealWidth, 0.7)
                                } else {
                                    offset = h
                                }
                            } else if offset < 0 {
                                offset = min(-revealWidth + h, 0)
                            }
                        }
                        .onEnded { value in
                            guard !isRemoving else { return }
                            let h = value.translation.width
                            let predicted = value.predictedEndTranslation.width

                            if h < -180 || predicted < -500 {
                                performDelete()
                            } else if h < -revealWidth / 2 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    offset = -revealWidth
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }

    private func performDelete() {
        guard !isRemoving else { return }
        isRemoving = true
        withAnimation(.easeOut(duration: 0.3)) {
            offset = -UIScreen.main.bounds.width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.25)) {
                onDelete()
            }
        }
    }
}
