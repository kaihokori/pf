import SwiftUI

struct AIAssistantStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 24)
            
            Text("Meet your very own AI Assistant")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Use voice commands to easily add meals, create routines, fill out trackers, or just ask general fitness questions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill").foregroundStyle(.blue)
                    Text("Hands-free Logging")
                }
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                    Text("Smart Suggestions")
                }
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill").foregroundStyle(.orange)
                    Text("Instant Routine Builder")
                }
            }
            .font(.subheadline)
            .padding(.top, 16)
        }
        .padding()
        .surfaceCard(16)
    }
}
