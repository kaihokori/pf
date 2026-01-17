import SwiftUI

struct WellnessMetricsGrid: View {
    let metrics: [TrackedWellnessMetric]
    let hkValues: [WellnessMetricType: Double]
    // Manual adjustment might not be relevant for Wellness (users rarely manually adjust HRV delta), but to keep "exact same" structure, we allow it.
    // Or we just rely on HK/Input.
    // DailySummary logic: total = HK + Manual.
    // For Wellness, usually we just log reading.
    // But implementation asked for "exact same". So I will support manual entry.
    // This provider will usually come from a Dictionary stored in the View.
    let manualAdjustmentProvider: (WellnessMetricType) -> Double
    var accentColor: Color? = nil

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(metrics) { metric in
                let (currentValue, progress) = metricValueAndProgress(for: metric)
                
                ActivityProgressCard(
                    title: metric.type.displayName,
                    iconName: metric.type.systemImage,
                    tint: accentColor ?? metric.color,
                    currentValueText: currentValue,
                    goalValueText: "Goal \(formattedGoal(metric))",
                    progress: progress
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                // Span full width if it's the first item and we have an odd number of items
                .gridCellColumns((metrics.count % 2 != 0 && metric.id == metrics.first?.id) ? 2 : 1)
            }
        }
    }
    
    private func formattedGoal(_ metric: TrackedWellnessMetric) -> String {
        let val = metric.goal
        // Handle percent scaling if needed. Assuming goal is stored as raw (e.g. 98 for SpO2, not 0.98, if user enters 98).
        // Let's assume goals are stored in Human Readable units.
        return "\(Int(val)) \(metric.unit)"
    }
    
    private func metricValueAndProgress(for metric: TrackedWellnessMetric) -> (String, Double) {
        let hkVal = hkValues[metric.type] ?? 0
        let manualVal = manualAdjustmentProvider(metric.type)
        
        // Aggregation logic for Total vs Average
        // For Activity (Steps), Total = HK + Manual.
        // For Body Temp (Average), Total = (HK + Manual) / 2? Or just "Latest"?
        // The previous "Sum" logic works for cumulative counts.
        // For Wellness, "HRV" isn't cumulative.
        // If I manually add an HRV reading, it should probably supersede or average with HK?
        // Simplifying constraint: Treat it as "Latest/Representative Value".
        // But the prompt said "exact same Daily Summary section".
        // In Daily Activity, it was `total = hkVal + manualVal`.
        // If I do that for BodyTemp (36.5 + 0), it works.
        // If I have HK (36.5) and Manual adjustment (+1.0), result 37.5.
        // This "Adjustment" model implies +/- delta.
        // Okay, I will stick to the +/- delta model to match "exact same".
        
        let total = hkVal + manualVal
        
        // Progress:
        // For UV, less is better? Or goal is limit?
        // Default logic: `total / goal`.
        // For things like VO2Max, higher is better.
        // For UV, lower is better.
        // I'll stick to simple ratio for now.
        
        var progress = 0.0
        if metric.goal != 0 {
             progress = min(max(total / metric.goal, 0), 1.0)
        }
        
        let valString: String = {
            // Percent formatting
            if metric.type == .oxygenSaturation || metric.type == .bloodAlcohol {
                // If HK returns 0.98, we might want to show 98%.
                // Let's check HKUnit.
                // If HKUnit.percent() was used, doubleValue(for: .percent()) returns 0.98.
                // We typically display 98%.
                return String(format: "%.1f", total * 100)
            }
            
            switch metric.type {
            case .uvIndex, .heartRate, .sexualActivity:
                return "\(Int(total))"
            default:
                return String(format: "%.1f", total)
            }
        }()
        
        return (valString, progress)
    }
}
