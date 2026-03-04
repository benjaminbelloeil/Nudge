import SwiftUI

struct ManualMissionsView: View {
    @ObservedObject var viewModel: NudgeViewModel
    @FocusState private var focusedField: Int?

    @EnvironmentObject var languageManager: LanguageManager
    private var lang: (String) -> String { { key in languageManager[key] } }

    @State private var appeared = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header card
                headerCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)

                // Step chain scroll area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { index in
                            StepChainRow(
                                index: index,
                                placeholder: lang("manual.placeholder_\(index)"),
                                text: $viewModel.manualMissions[index],
                                isFocused: focusedField == index,
                                isLast: index == 4,
                                onTap: { focusedField = index }
                            )
                            .focused($focusedField, equals: index)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.82)
                                    .delay(0.06 + Double(index) * 0.055),
                                value: appeared
                            )
                        }
                        Spacer().frame(height: 20)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

                // Bottom submit panel
                submitPanel
                    .opacity(appeared ? 1 : 0)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.isManualMode = false
                    viewModel.isAIFallbackToManual = false
                    viewModel.manualMissions = Array(repeating: "", count: 5)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.04)) {
                appeared = true
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: viewModel.isAIFallbackToManual ? "sparkles.slash" : "pencil.and.list.clipboard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang("manual.title"))
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(viewModel.isAIFallbackToManual
                         ? lang("manual.ai_fallback_note")
                         : lang("manual.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                FrictionBadge(label: viewModel.taskText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppColors.cardBackground)

            // Progress stripe
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.45))
                        .frame(width: geo.size.width * filledFraction)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filledCount)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Submit Panel

    private var submitPanel: some View {
        VStack(spacing: 6) {
            // Mini dot indicators
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    let filled = !viewModel.manualMissions[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Capsule()
                        .fill(filled ? Color.accentColor : Color.secondary.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)
                        .animation(.spring(response: 0.3), value: filled)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Button {
                HapticManager.medium()
                focusedField = nil
                viewModel.submitManualMissions()
            } label: {
                HStack(spacing: 8) {
                    if !viewModel.canSubmitManualMissions {
                        Text("\(filledCount)/5")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Text(lang("manual.create"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.canSubmitManualMissions
                    ? Color.accentColor
                    : Color.accentColor.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!viewModel.canSubmitManualMissions)
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .background(AppColors.background)
    }

    // MARK: - Helpers

    private var filledCount: Int {
        viewModel.manualMissions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var filledFraction: CGFloat { CGFloat(filledCount) / 5.0 }
}

// MARK: - Step Chain Row

private struct StepChainRow: View {
    let index: Int
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool
    let isLast: Bool
    let onTap: () -> Void

    private var isFilled: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Number column + connector
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isFilled ? Color.accentColor : Color.secondary.opacity(0.10))
                        .frame(width: 36, height: 36)
                        .shadow(
                            color: isFilled ? Color.accentColor.opacity(0.3) : Color.clear,
                            radius: 6, x: 0, y: 2
                        )
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(isFilled ? .white : .secondary.opacity(0.45))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFilled)

                if !isLast {
                    Rectangle()
                        .fill(isFilled ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.10))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                        .animation(.easeInOut(duration: 0.3), value: isFilled)
                }
            }
            .frame(width: 52)
            .padding(.top, 14)

            // Text field
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isFocused ? AppColors.elevatedCard : AppColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            isFocused
                                ? Color.accentColor.opacity(0.55)
                                : (isFilled ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1)),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .onTapGesture { onTap() }
                .padding(.top, 8)
                .padding(.trailing, 20)
                .padding(.bottom, isLast ? 8 : 6)
        }
        .padding(.leading, 12)
    }
}
