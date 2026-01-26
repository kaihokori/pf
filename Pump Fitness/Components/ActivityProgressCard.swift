import SwiftUI

struct ActivityProgressCard: View {
    var title: String
    var iconName: String
    var tint: Color
    var currentValueText: String
    var goalValueText: String
    var progress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var progressPercentage: Int {
        Int(clampedProgress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currentValueText)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(goalValueText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                GeometryReader { proxy in
                    let width = proxy.size.width * clampedProgress
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tint.opacity(0.85))
                            .frame(width: max(width, 8))
                    }
                    .frame(height: 10)
                    .animation(.easeOut(duration: 0.35), value: clampedProgress)
                }
                .frame(height: 10)

                HStack(alignment: .center, spacing: 8) {
                    Text("\(progressPercentage)% of goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150)
        .adaptiveGlassEffect(in: .rect(cornerRadius: 16.0))
    }
}