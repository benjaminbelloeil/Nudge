import SwiftUI

struct TaskInputView: View {
    @Binding var taskText: String
    let canAdvance: Bool
    let onNext: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Solid background that extends behind keyboard
            AppColors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer().frame(height: 24)

                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Step 1")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                                .tracking(1)
                            Text("What are you\nputting off?")
                                .font(.system(size: 26, weight: .bold))
                                .lineSpacing(2)
                        }

                        Text("Describe the task you keep avoiding.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $taskText)
                                .frame(minHeight: 100, maxHeight: 160)
                                .padding(4)
                                .scrollContentBackground(.hidden)
                                .background(.clear)
                                .focused($isFocused)

                            if taskText.isEmpty {
                                Text("e.g., Start writing my essay, clean up the kitchen...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 12)
                                    .padding(.leading, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(12)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isFocused ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .animation(.easeOut(duration: 0.15), value: isFocused)

                        if taskText.count > 200 {
                            Text("Try to keep it concise")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isFocused = false
                }

                // Bottom button
                Button {
                    // Dismiss keyboard first, then advance after a short delay
                    isFocused = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onNext()
                    }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canAdvance ? Color.accentColor : Color.secondary.opacity(0.2))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canAdvance)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .padding(.top, 8)
            }
        }
    }
}
