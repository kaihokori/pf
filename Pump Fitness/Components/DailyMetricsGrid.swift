import SwiftUI

struct DailyMetricsGrid: View {
    let metrics: [TrackedActivityMetric]
    let hkValues: [ActivityMetricType: Double]
    let manualAdjustmentProvider: (ActivityMetricType) -> Double

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(metrics) { metric in
                let (currentValue, progress) = metricValueAndProgress(for: metric)
                
                ActivityProgressCard(
                    title: metric.type.displayName,
                    iconName: metric.type.systemImage,
                    tint: metric.color,
                    currentValueText: currentValue,
                    goalValueText: "Goal \(Int(metric.goal)) \(metric.unit)",
                    progress: progress
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                // Span full width if it's the first item and we have an odd number of items
                .gridCellColumns((metrics.count % 2 != 0 && metric.id == metrics.first?.id) ? 2 : 1)
            }
        }
    }
    
    private func metricValueAndProgress(for metric: TrackedActivityMetric) -> (String, Double) {
        let hkVal = hkValues[metric.type] ?? 0
        let manualVal = manualAdjustmentProvider(metric.type)
        let total = hkVal + manualVal
        let progress = min(max(total / metric.goal, 0), 1.0)
        
        let valString: String = {
            switch metric.type {
            case .steps, .flightsClimbed, .swimStroke:
                return "\(Int(total))"
            default:
                return String(format: "%.1f", total)
            }
        }()
        
        return (valString, progress)
    }
}
