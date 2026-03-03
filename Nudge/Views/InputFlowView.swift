import SwiftUI

struct InputFlowView: View {
    @ObservedObject var viewModel: NudgeViewModel

    var body: some View {
        ZStack {
            // Continuous background that never splits
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                StepIndicator(currentStep: viewModel.currentStep)
                    .padding(.top, 12)



                ZStack {
                    switch viewModel.currentStep {
                    case .task:
                        TaskInputView(
                            taskText: $viewModel.taskText,
                            canAdvance: viewModel.canAdvance,
                            onNext: { viewModel.advance() }
                        )
                        .transition(transitionForDirection)

                    case .energy:
                        EnergyInputView(
                            selectedEnergy: $viewModel.selectedEnergy,
                            onNext: { viewModel.advance() },
                            onBack: { viewModel.goBack() }
                        )
                        .transition(transitionForDirection)

                    case .mood:
                        MoodInputView(
                            selectedMood: $viewModel.selectedMood,
                            isGenerating: viewModel.isGenerating,
                            onGenerate: {
                                Task { await viewModel.generateNudge() }
                            },
                            onBack: { viewModel.goBack() }
                        )
                        .transition(transitionForDirection)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
            }
        }
    }

    private var transitionForDirection: AnyTransition {
        if viewModel.isGoingForward {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
}
