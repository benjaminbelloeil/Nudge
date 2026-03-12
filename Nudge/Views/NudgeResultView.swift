import SwiftUI

struct NudgeResultView: View {
    let result: NudgeResult
    let source: NudgeSource
    @ObservedObject var viewModel: NudgeViewModel
    var onDismiss: (() -> Void)? = nil

    @EnvironmentObject var languageManager: LanguageManager
    private var lang: (String) -> String { { key in languageManager[key] } }

    @State private var cardsAppeared = false
    @State private var showSteps = true
    @State private var showGoal = false
    @State private var shakeStepId: Int? = nil
    @Environment(\.appReduceMotion) private var reduceMotion

    private var progressFraction: Double {
        guard viewModel.totalStepCount > 0 else { return 0 }
        return Double(viewModel.completedStepCount) / Double(viewModel.totalStepCount)
    }

    @State private var errorAppeared = false

    var body: some View {
        Group {
            if hasError {
                errorPage
            } else {
                normalContent
            }
        }
        .background(AppColors.background)
    }

    // MARK: - Error Page (full, minimalist, no sheet)

    private var errorPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.secondary.opacity(0.5))
                    .scaleEffect(errorAppeared ? 1 : 0.6)
                    .opacity(errorAppeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text(lang("result.error_title"))
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(viewModel.contentWarning ?? viewModel.errorMessage ?? "An unknown error occurred.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }
                .opacity(errorAppeared ? 1 : 0)
                .offset(y: errorAppeared ? 0 : 8)

                Button {
                    HapticManager.warning()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.reset()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        onDismiss?()
                    }
                } label: {
                    Text(lang("result.start_over"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 40)
                .opacity(errorAppeared ? 1 : 0)
                .offset(y: errorAppeared ? 0 : 12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                errorAppeared = true
            }
        }
    }

    // MARK: - Normal Content

    private var normalContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    resultHeader
                    progressSection
                    stepsSection
                    goalSection
                    Spacer().frame(height: 24)
                }
            }

            // MARK: - Bottom Buttons (pinned lower)
            bottomButtons
        }
        .background(AppColors.background)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                cardsAppeared = true
            }
        }
    }

    // MARK: - Header

    private var resultHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                FrictionBadge(label: result.frictionLabel)
                Spacer()
                if viewModel.completedStepCount == viewModel.totalStepCount && viewModel.totalStepCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All done!")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                }
            }

            Text(lang("result.action_plan"))
                .font(.title2)
                .fontWeight(.bold)

            Text(viewModel.taskText.replacingOccurrences(of: "\n", with: " "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lang("result.action_plan")). \(result.frictionLabel). \(viewModel.taskText.replacingOccurrences(of: "\n", with: " ")). \(viewModel.completedStepCount) of \(viewModel.totalStepCount) steps done")
    }

    // MARK: - Progress

    private var progressSection: some View {
        HorizontalTimerBar(
            progress: progressFraction,
            label: "\(viewModel.completedStepCount) \(lang("common.of")) \(viewModel.totalStepCount) \(lang("common.steps"))"
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .opacity(cardsAppeared ? 1 : 0)
    }

    // MARK: - Steps (Expandable)

    private func isStepLocked(_ step: NudgeStep) -> Bool {
        let previous = result.steps.filter { $0.id < step.id }
        return !previous.allSatisfy { viewModel.completedStepIds.contains($0.id) }
    }

    private var stepsSection: some View {
        VStack(spacing: 0) {
            // Section header button
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85)) {
                    showSteps.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "list.number")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }

                    Text(lang("result.steps"))
                        .font(.body)
                        .fontWeight(.bold)

                    Spacer()

                    Text("\(viewModel.completedStepCount)/\(viewModel.totalStepCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showSteps ? -180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showSteps {
                VStack(spacing: 0) {
                    ForEach(Array(result.steps.enumerated()), id: \.element.id) { index, step in
                        let locked = isStepLocked(step)
                        ResultStepRow(
                            step: step,
                            isCompleted: viewModel.completedStepIds.contains(step.id),
                            isLocked: locked,
                            isLast: index == result.steps.count - 1,
                            shakeOffset: shakeStepId == step.id,
                            onToggle: {
                                if locked {
                                    HapticManager.error()
                                    withAnimation(.default) {
                                        shakeStepId = step.id
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        shakeStepId = nil
                                    }
                                } else {
                                    let wasCompleted = viewModel.completedStepIds.contains(step.id)
                                    viewModel.toggleStep(step.id)
                                    if !wasCompleted {
                                        HapticManager.success()
                                    } else {
                                        HapticManager.light()
                                    }
                                }
                            }
                        )
                        .opacity(cardsAppeared ? 1 : 0)
                        .offset(y: cardsAppeared ? 0 : 16)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(Double(index) * 0.08),
                            value: cardsAppeared
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSteps)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Goal (Expandable)

    private var goalSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85)) {
                    showGoal.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    Text(lang("result.goal"))
                        .font(.body)
                        .fontWeight(.bold)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showGoal ? -180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showGoal {
                Text(result.successDefinition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showGoal)
        .padding(.horizontal, 20)
        .opacity(cardsAppeared ? 1 : 0)
    }

    // MARK: - Error Check

    private var hasError: Bool {
        (viewModel.contentWarning != nil && !viewModel.contentWarning!.isEmpty) ||
        (viewModel.errorMessage != nil && !viewModel.errorMessage!.isEmpty)
    }

    // MARK: - Bottom Buttons (lower placement, hidden on error)

    @ViewBuilder
    private var bottomButtons: some View {
        if !hasError {
            VStack(spacing: 8) {
                Button {
                    HapticManager.success()
                    viewModel.markComplete()
                    onDismiss?()
                } label: {
                    Text(lang("result.save_close"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel(lang("result.save_close"))
                .accessibilityHint("Saves your progress and closes this nudge")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .background(AppColors.background)
        }
    }
}

// MARK: - Step Row (timeline style with lock support)

private struct ResultStepRow: View {
    let step: NudgeStep
    let isCompleted: Bool
    let isLocked: Bool
    let isLast: Bool
    let shakeOffset: Bool
    let onToggle: () -> Void

    @EnvironmentObject var languageManager: LanguageManager
    private var lang: (String) -> String { { key in languageManager[key] } }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 14) {
                // Timeline column
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.green : isLocked ? Color.secondary.opacity(0.10) : Color.accentColor.opacity(0.15))
                            .frame(width: 34, height: 34)

                        // Tap ring for unlocked incomplete steps
                        if !isCompleted && !isLocked {
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 34, height: 34)
                        }

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        } else if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(Color.secondary.opacity(0.5))
                        } else {
                            Text("\(step.id)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .modifier(ShakeEffect(shakes: shakeOffset ? 4 : 0))
                    .animation(.default, value: shakeOffset)
                    .accessibilityHidden(true)

                    if !isLast {
                        Rectangle()
                            .fill(isCompleted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.12))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                            .accessibilityHidden(true)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(isCompleted ? .secondary : isLocked ? Color.secondary.opacity(0.6) : .primary)

                    Text(step.action)
                        .font(.subheadline)
                        .foregroundColor(isLocked ? Color.secondary.opacity(0.4) : .secondary)
                        .lineSpacing(3)

                    // Tap hint for the first unlocked step
                    if !isCompleted && !isLocked {
                        Text(lang("result.tap_complete"))
                            .font(.caption2)
                            .foregroundColor(.accentColor.opacity(0.6))
                            .padding(.top, 2)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(step.id): \(step.title). \(step.action)")
        .accessibilityValue(isCompleted ? "Completed" : isLocked ? "Locked — complete previous steps first" : "Not yet done")
        .accessibilityHint(isLocked ? "" : (isCompleted ? "Double tap to mark incomplete" : "Double tap to mark complete"))
        .accessibilityAddTraits(isLocked ? [.isButton] : (isCompleted ? [.isButton, .isSelected] : .isButton))
    }
}

// MARK: - Shake Effect

private struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 2) * 6
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
