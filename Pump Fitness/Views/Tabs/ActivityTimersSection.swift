import SwiftUI

// Two-column activity timers section styled like the FastingTimerCard
struct ActivityTimersSection: View {
    var accentColorOverride: Color?

    var body: some View {
        HStack(spacing: 12) {
            ActivityTimerCard(
                accentColorOverride: accentColorOverride ?? .orange,
                title: "Workout",
                hoursElapsed: 0.75,
                nextText: "Ends 7:30 AM"
            )
            .frame(maxWidth: .infinity)

            ActivityTimerCard(
                accentColorOverride: accentColorOverride ?? .green,
                title: "Intimate Time",
                hoursElapsed: 0.25,
                nextText: "Starts 11:15 PM"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

private struct ActivityTimerCard: View {
    var accentColorOverride: Color?
    var title: String
    var hoursElapsed: Double
    var nextText: String

    private var progress: Double {
        let duration = 1.0
        return min(max(hoursElapsed / duration, 0), 1)
    }

    private func formattedTimeString(for hoursValue: Double) -> String {
        let safeHours = max(hoursValue, 0)
        let hoursComponent = Int(safeHours)
        let minutesComponent = Int((safeHours - Double(hoursComponent)) * 60)
        return String(format: "%02dh %02dm", hoursComponent, minutesComponent)
    }

    var body: some View {
        let tint = accentColorOverride ?? .green

        VStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            ZStack {
                // smaller rings — explicit frame to control size
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                VStack(spacing: 4) {
                    Text("Time Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(formattedTimeString(for: max(0, 1.0 - hoursElapsed)))
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)

            VStack(alignment: .center, spacing: 6) {
                Text("Next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(nextText)
                    .font(.headline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button {
                // action
            } label: {
                Text("Stop")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}

#if DEBUG
struct ActivityTimersSection_Previews: PreviewProvider {
    static var previews: some View {
        ActivityTimersSection(accentColorOverride: .orange)
            .previewLayout(.sizeThatFits)
    }
}
#endif
