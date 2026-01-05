
struct MethodStepRow: View {
    let index: Int
    let step: MethodStep
    let accentColor: Color
    
    @State private var timeRemaining: TimeInterval
    @State private var isRunning = false
    
    init(index: Int, step: MethodStep, accentColor: Color) {
        self.index = index
        self.step = step
        self.accentColor = accentColor
        _timeRemaining = State(initialValue: TimeInterval(step.durationMinutes * 60))
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1).")
                .font(.callout.weight(.semibold))
                .padding(6)
                .background(accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(step.text)
                    .font(.subheadline)
                    .lineSpacing(3)
                
                if step.durationMinutes > 0 {
                    HStack(spacing: 12) {
                        // Timer Badge
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(formatTime(timeRemaining))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                        
                        // Controls
                        Button {
                            isRunning.toggle()
                        } label: {
                            Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                        
                        if timeRemaining != TimeInterval(step.durationMinutes * 60) {
                            Button {
                                isRunning = false
                                timeRemaining = TimeInterval(step.durationMinutes * 60)
                            } label: {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                isRunning = false
            }
        }
    }
    
    private func formatTime(_ totalSeconds: TimeInterval) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
