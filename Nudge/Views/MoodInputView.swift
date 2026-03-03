import SwiftUI

struct MoodInputView: View {
    @Binding var selectedMood: Mood?
    let isGenerating: Bool
    let onGenerate: () -> Void
    let onBack: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    // Title
                    VStack(spacing: 4) {
                        Text("Step 3")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                            .tracking(1)
                        Text("What's your\nmood?")
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    Text("Pick what feels closest right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Mood.allCases) { mood in
                            MoodChip(
                                mood: mood,
                                isSelected: selectedMood == mood,
                                action: { selectedMood = mood }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.elevatedCard)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button(action: onGenerate) {
                        Text("Nudge Me")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedMood != nil ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isGenerating || selectedMood == nil)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}
