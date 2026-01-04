import Foundation
import UIKit

@MainActor
struct DeviceInfoHelper {
    static func getBatteryInfo() -> (percentage: Double?, isCharging: Bool?) {
        let device = UIDevice.current
        let wasMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        let state = device.batteryState
        let percent: Double? = level >= 0 ? Double(level * 100.0) : nil
        let charging = state == .charging || state == .full
        
        // We don't disable monitoring to avoid interfering with other observers if any, 
        // or we can restore it. The original code restored it.
        if !wasMonitoring { device.isBatteryMonitoringEnabled = false }
        
        return (percent, charging)
    }
}
