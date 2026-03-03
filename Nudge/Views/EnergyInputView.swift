import SwiftUI

struct EnergyInputView: View {
    @Binding var selectedEnergy: EnergyLevel
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    // Title
                    VStack(spacing: 4) {
                        Text("Step 2")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                            .tracking(1)
                        Text("How's your\nenergy?")
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    Text("This helps tailor the nudge to what you can handle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)

                EnergySelector(selected: $selectedEnergy)
                    .padding(.horizontal, 12)

                Spacer().frame(height: 24)

                Text(energyDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 40)
                    .padding(.horizontal, 40)
                    .animation(.easeInOut(duration: 0.2), value: selectedEnergy)

                Spacer()

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

                    Button(action: onNext) {
                        Text("Next")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private var energyDescription: String {
        switch selectedEnergy {
        case .veryLow: "Barely keeping eyes open."
        case .low: "Running low. Gentle actions only."
        case .medium: "Functional. Can handle a moderate nudge."
        case .high: "Feeling capable. Ready for a solid push."
        case .veryHigh: "Full battery. Can take on a sprint."
        }
    }
}
