import SwiftUI

struct ManualMissionsView: View {
    @ObservedObject var viewModel: NudgeViewModel
    @FocusState private var focusedField: Int?

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.10))
                            .frame(width: 64, height: 64)
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }

                    Text("Create Your Missions")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Both AI models are unavailable right now.\nBreak your task into 5 small missions instead.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Task label
                HStack {
                    FrictionBadge(label: viewModel.taskText)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

                // Mission fields
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(0..<5, id: \.self) { index in
                            MissionField(
                                index: index,
                                text: $viewModel.manualMissions[index],
                                isFocused: focusedField == index,
                                onTap: { focusedField = index }
                            )
                            .focused($focusedField, equals: index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                // Bottom button
                VStack(spacing: 8) {
                    Button {
                        focusedField = nil
                        viewModel.submitManualMissions()
                    } label: {
                        Text("Create Plan")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(viewModel.canSubmitManualMissions ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!viewModel.canSubmitManualMissions)

                    Text("\(filledCount)/5 missions filled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(AppColors.background)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.isManualMode = false
                    viewModel.manualMissions = Array(repeating: "", count: 5)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var filledCount: Int {
        viewModel.manualMissions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

// MARK: - Mission Field

private struct MissionField: View {
    let index: Int
    @Binding var text: String
    let isFocused: Bool
    let onTap: () -> Void

    private let placeholders = [
        "e.g. Open the document and read through it",
        "e.g. Write the first paragraph or outline",
        "e.g. Add details to two main sections",
        "e.g. Review and fix any rough spots",
        "e.g. Save progress and note next steps"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(text.isEmpty ? Color.secondary.opacity(0.10) : Color.accentColor)
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(text.isEmpty ? .secondary : .white)
                }

                Text("Mission \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
            }

            TextField(placeholders[index], text: $text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...4)
                .padding(14)
                .background(AppColors.elevatedCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.12),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .onTapGesture { onTap() }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
