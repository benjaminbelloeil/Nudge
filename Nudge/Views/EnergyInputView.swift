import SwiftUI

struct EnergyInputView: View {
    @Binding var selectedEnergy: EnergyLevel
    let onNext: () -> Void
    let onBack: () -> Void

    @EnvironmentObject var languageManager: LanguageManager
    private var lang: (String) -> String { { key in languageManager[key] } }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    // Title
                    VStack(spacing: 4) {
                        Text(lang("flow.step2_label"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                            .tracking(1)
                        Text(lang("flow.energy_title"))
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    Text(lang("flow.energy_subtitle"))
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
                    Button {
                        HapticManager.light()
                        onBack()
                    } label: {
                        Text(lang("flow.back"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.elevatedCard)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        HapticManager.light()
                        onNext()
                    } label: {
                        Text(lang("flow.next"))
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
        case .veryLow: lang("energy.very_low")
        case .low:     lang("energy.low")
        case .medium:  lang("energy.medium")
        case .high:    lang("energy.high")
        case .veryHigh: lang("energy.very_high")
        }
    }
}

