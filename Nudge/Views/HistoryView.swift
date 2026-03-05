import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var languageManager: LanguageManager

    private var lang: LanguageManager { languageManager }

    var body: some View {
        Group {
            if viewModel.entries.isEmpty {
                historyEmptyState
            } else {
                List {
                    ForEach(viewModel.filteredEntries) { entry in
                        Button {
                            navigationPath.append(NavigationDestination.nudgeDetail(entry.id))
                        } label: {
                            HistoryCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteEntry(id: entry.id)
                            } label: {
                                Label(lang["common.delete"], systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(AppColors.background)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(lang["history.title"])
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: lang["history.search"])
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(lang["history.filter_all"]) { viewModel.filterMood = nil }
                    Divider()
                    ForEach(Mood.allCases) { mood in
                        Button {
                            viewModel.filterMood = mood
                        } label: {
                            Label(
                                "\(mood.emoji) \(languageManager["mood.\(mood.rawValue)"])",
                                systemImage: viewModel.filterMood == mood ? "checkmark" : ""
                            )
                        }
                    }
                } label: {
                    Image(systemName: viewModel.filterMood != nil
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                    )
                }
            }
        }
    }

    // MARK: - Empty State (centered, visually rich)

    private var historyEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.4))

            VStack(spacing: 8) {
                Text(lang["history.empty_title"])
                    .font(.title3)
                    .fontWeight(.bold)

                Text(lang["history.empty_subtitle"])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let entry: NudgeEntry
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: task name + completion
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.taskDescription.replacingOccurrences(of: "\n", with: " "))
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        FrictionBadge(label: entry.result.frictionLabel)
                        Text(entry.mood.emoji)
                            .font(.caption)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(entry.isCompleted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: entry.isCompleted ? "checkmark" : "chevron.right")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(entry.isCompleted ? .green : .secondary.opacity(0.4))
                }
            }

            // Bottom row: steps + date
            HStack {
                ProgressCapsule(completed: entry.stepsCompleted, total: entry.totalSteps)
                Spacer()
                Text("\(entry.stepsCompleted)/\(entry.totalSteps) \(languageManager["common.steps"])")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(entry.createdAt.formatted(
                    Date.RelativeFormatStyle(presentation: .named, unitsStyle: .wide)
                        .locale(languageManager.locale)
                ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.taskDescription.replacingOccurrences(of: "\n", with: " ")). \(entry.isCompleted ? "Completed" : "In progress"). \(entry.stepsCompleted) of \(entry.totalSteps) steps done")
        .accessibilityHint("Double tap to open")
    }
}

// MARK: - Nudge Detail View

struct NudgeDetailView: View {
    @ObservedObject var viewModel: HistoryViewModel
    let entryId: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appReduceMotion) private var reduceMotion

    private var lang: LanguageManager { languageManager }

    @State private var showSteps = true
    @State private var showGoal = false
    @State private var appeared = false
    @State private var justCompletedStepId: Int? = nil
    @State private var shakeStepId: Int? = nil
    @State private var showDeleteAlert = false

    private var entry: NudgeEntry? {
        viewModel.entries.first { $0.id == entryId }
    }

    var body: some View {
        Group {
            if let entry = entry {
                detailContent(entry: entry)
            } else {
            Text(lang["details.not_found"])
                    .foregroundStyle(.secondary)
            }
        }
        .alert(lang["details.delete_title"], isPresented: $showDeleteAlert) {
            Button(lang["common.cancel"], role: .cancel) { }
            Button(lang["common.delete"], role: .destructive) {
                viewModel.deleteEntry(id: entryId)
                dismiss()
            }
        } message: {
            Text(lang["details.delete_message"])
        }
    }

    @ViewBuilder
    private func detailContent(entry: NudgeEntry) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header (no card wrapper)
                    DetailHeader(entry: entry)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    // Progress bar
                    HorizontalTimerBar(
                        progress: entry.progressFraction,
                        label: "\(entry.stepsCompleted) / \(entry.totalSteps) \(lang["common.steps"])"
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)

                    // Steps (expandable card)
                    DetailStepsCard(
                        entry: entry,
                        viewModel: viewModel,
                        showSteps: $showSteps,
                        justCompletedStepId: $justCompletedStepId,
                        shakeStepId: $shakeStepId
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                    // Goal (expandable card)
                    DetailGoalCard(
                        entry: entry,
                        showGoal: $showGoal
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)

                    // Info section
                    DetailInfoSection(entry: entry)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    // Complete button
                    DetailCompleteButton(entry: entry, viewModel: viewModel)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .opacity(appeared ? 1 : 0)

                    // Delete button
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text(lang["details.delete_button"])
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                }
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(lang["details.title"])
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Detail Header (clean, no card wrapper)

private struct DetailHeader: View {
    let entry: NudgeEntry
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badges row
            HStack(spacing: 8) {
                FrictionBadge(label: entry.result.frictionLabel)

                Spacer()

                if entry.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(languageManager["details.completed"])
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
            }

            // Task title
            Text(entry.taskDescription.replacingOccurrences(of: "\n", with: " "))
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(2)
                .truncationMode(.tail)

            // Mood, energy, date
            HStack(spacing: 10) {
                Text(entry.mood.emoji)
                    .font(.title3)
                Text(languageManager["mood.\(entry.mood.rawValue)"])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(languageManager["energy.name.\(entry.energy.rawValue)"])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.createdAt.formatted(
                    Date.RelativeFormatStyle(presentation: .named, unitsStyle: .wide)
                        .locale(languageManager.locale)
                ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.taskDescription.replacingOccurrences(of: "\n", with: " ")). \(entry.result.frictionLabel). \(entry.isCompleted ? languageManager["details.completed"] : "In progress"). \(languageManager["mood.\(entry.mood.rawValue)"]). \(languageManager["energy.name.\(entry.energy.rawValue)"])")
    }
}

// MARK: - Detail Steps Card (expandable, bigger touch targets)

private struct DetailStepsCard: View {
    let entry: NudgeEntry
    let viewModel: HistoryViewModel
    @Binding var showSteps: Bool
    @Binding var justCompletedStepId: Int?
    @Binding var shakeStepId: Int?
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appReduceMotion) private var reduceMotion

    private func isStepLocked(_ step: NudgeStep) -> Bool {
        let previous = entry.result.steps.filter { $0.id < step.id }
        return !previous.allSatisfy { entry.completedStepIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
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

                    Text(languageManager["details.steps"])
                        .font(.body)
                        .fontWeight(.bold)

                    Spacer()

                    Text("\(entry.stepsCompleted)/\(entry.totalSteps)")
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
                    ForEach(Array(entry.result.steps.enumerated()), id: \.element.id) { index, step in
                        let locked = isStepLocked(step)
                        DetailTimelineRow(
                            step: step,
                            isCompleted: entry.completedStepIds.contains(step.id),
                            isLocked: locked,
                            isLast: index == entry.result.steps.count - 1,
                            justCompleted: justCompletedStepId == step.id,
                            shaking: shakeStepId == step.id,
                            onToggle: {
                                if locked {
                                    HapticManager.error()
                                    withAnimation(reduceMotion ? .none : .default) {
                                        shakeStepId = step.id
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        shakeStepId = nil
                                    }
                                    return
                                }
                                let wasCompleted = entry.completedStepIds.contains(step.id)
                                viewModel.toggleStepCompletion(entryId: entry.id, stepId: step.id)
                                if !wasCompleted {
                                    HapticManager.success()
                                    withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.6)) {
                                        justCompletedStepId = step.id
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) {
                                            justCompletedStepId = nil
                                        }
                                    }
                                } else {
                                    HapticManager.light()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSteps)
    }
}

// MARK: - Detail Goal Card (expandable, bigger touch targets)

private struct DetailGoalCard: View {
    let entry: NudgeEntry
    @Binding var showGoal: Bool
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.appReduceMotion) private var reduceMotion

    var body: some View {
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

                    Text(languageManager["details.goal"])
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
                Text(entry.result.successDefinition)
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
    }
}

// MARK: - Detail Info Section

private struct DetailInfoSection: View {
    let entry: NudgeEntry
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                Text(languageManager["details.info"])
                    .font(.body)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            VStack(spacing: 12) {
                InfoRow(
                    label: languageManager["details.created"],
                    value: entry.createdAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened)
                            .locale(languageManager.locale)
                    )
                )
                InfoRow(label: languageManager["details.mood"], value: "\(entry.mood.emoji) \(languageManager["mood.\(entry.mood.rawValue)"])")
                InfoRow(label: languageManager["details.energy"], value: languageManager["energy.name.\(entry.energy.rawValue)"])
                InfoRow(
                    label: languageManager["details.source"],
                    value: entry.source == .ai
                        ? languageManager["settings.account.pro_badge"]
                        : entry.source == .appleIntelligence
                            ? "Apple Intelligence"
                            : entry.source == .manual
                                ? languageManager["details.source_manual"]
                                : languageManager["details.source_template"]
                )
                if let completedAt = entry.completedAt {
                    InfoRow(
                        label: languageManager["details.completed"],
                        value: completedAt.formatted(
                            Date.FormatStyle(date: .abbreviated, time: .shortened)
                                .locale(languageManager.locale)
                        )
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

// MARK: - Detail Timeline Row (with completion animation + lock)

private struct DetailTimelineRow: View {
    let step: NudgeStep
    let isCompleted: Bool
    let isLocked: Bool
    let isLast: Bool
    let justCompleted: Bool
    let shaking: Bool
    let onToggle: () -> Void
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.green : isLocked ? Color.secondary.opacity(0.10) : Color.accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        // Tap ring for unlocked incomplete steps
                        if !isCompleted && !isLocked {
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 36, height: 36)
                        }

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(.white)
                        } else if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(Color.secondary.opacity(0.5))
                        } else {
                            Text("\(step.id)")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .modifier(DetailShakeEffect(shakes: shaking ? 4 : 0))
                    .animation(.default, value: shaking)

                    if !isLast {
                        Rectangle()
                            .fill(isCompleted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.12))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(isCompleted ? .secondary : isLocked ? Color.secondary.opacity(0.6) : .primary)
                    Text(step.action)
                        .font(.subheadline)
                        .foregroundColor(isLocked ? Color.secondary.opacity(0.4) : .secondary)
                        .lineSpacing(3)

                    // Tap hint for unlocked incomplete steps
                    if !isCompleted && !isLocked {
                        Text(languageManager["details.tap_complete"])
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
    }
}

// MARK: - Shake Effect for Detail View

private struct DetailShakeEffect: GeometryEffect {
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

// MARK: - Complete Button

private struct DetailCompleteButton: View {
    let entry: NudgeEntry
    let viewModel: HistoryViewModel
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        Button {
            if entry.isCompleted {
                HapticManager.warning()
            } else {
                HapticManager.success()
            }
            viewModel.toggleCompletion(id: entry.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: entry.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(entry.isCompleted ? languageManager["details.mark_incomplete"] : languageManager["details.mark_complete"])
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(entry.isCompleted ? AppColors.elevatedCard : Color.accentColor)
            .foregroundColor(entry.isCompleted ? .secondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
