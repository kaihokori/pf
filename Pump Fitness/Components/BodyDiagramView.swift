import SwiftUI

struct BodyDiagramView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Read-only visualization mode
    var injuries: [Injury]
    var highlightedParts: Set<BodyPart>? = nil
    var selectedDate: Date = Date()
    
    // Default color for uninjured parts
    let uninjuredColor = Color.secondary.opacity(0.15)
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            
            // Layout constants based on viewbox 300x600 (modified for shorter/muscular look)
            let viewBoxW: CGFloat = 300
            let viewBoxH: CGFloat = 510
            
            let scale = min(w / viewBoxW, h / viewBoxH)
            let offsetX = (w - (viewBoxW * scale)) / 2
            let offsetY = (h - (viewBoxH * scale)) / 2
            
            BodyView(scale: scale)
                .offset(x: offsetX, y: offsetY)
        }
    }
    
    // MARK: - Subviews
    
    // Simplified: Check if ANY injury corresponds to range of parts
    // E.g. Thigh should light up if Quad OR Hamstring is injured
    func color(for visualPart: VisualBodyPart) -> Color {
        if let highlightedParts = highlightedParts {
            if !visualPart.mappedParts.isDisjoint(with: highlightedParts) {
                return themeManager.selectedTheme.accent(for: colorScheme).opacity(0.6)
            }
            return uninjuredColor
        }

        // Find existing injuries that map to this visual part
        let matchingInjuries = injuries.filter { injury in
            // Filter out injuries that haven't occurred yet or have fully healed by selectedDate
            let calendar = Calendar.current
            let startOfSelected = calendar.startOfDay(for: selectedDate)
            let startOfOccurrence = calendar.startOfDay(for: injury.dateOccurred)
            
            guard startOfOccurrence <= startOfSelected else { return false }
            
            let endDate = calendar.date(byAdding: .day, value: injury.durationDays, to: injury.dateOccurred) ?? injury.dateOccurred
            let endOfInjury = calendar.startOfDay(for: endDate)
            
            if startOfSelected >= endOfInjury { return false }
            
            guard let part = injury.bodyPart else { return false }
            return visualPart.mappedParts.contains(part)
        }
        
        if let injury = matchingInjuries.max(by: { $0.dateOccurred < $1.dateOccurred }) {
            // Calculate intensity based on user formula: days left divided by 60
            let calendar = Calendar.current
            let startOfSelected = calendar.startOfDay(for: selectedDate)
            let startOfOccurrence = calendar.startOfDay(for: injury.dateOccurred)
            
            let daysElapsed = calendar.dateComponents([.day], from: startOfOccurrence, to: startOfSelected).day ?? 0
            let remainingDays = max(0, Double(injury.durationDays) - Double(daysElapsed))
            
            // "Percentage of days left divided by 60"
            let intensity = max(0, min(1, remainingDays / 60.0))
            
            let isMultiColor = (themeManager.selectedTheme == .multiColour)
            if isMultiColor {
                // Gradually shift from red (intensity 1.0 -> hue 0.0) to green (intensity 0.0 -> hue 0.33)
                let hue = 0.33 * (1.0 - intensity)
                return Color(hue: hue, saturation: 0.8, brightness: 0.9).opacity(max(0.6, intensity))
            } else {
                // Opacity is simple percentage of days left / 60
                // We keep a small minimum opacity so it doesn't vanish entirely if it's technically day 0 of healing
                return themeManager.selectedTheme.accent(for: colorScheme).opacity(max(0.1, intensity))
            }
        }
        return uninjuredColor
    }
    
    @ViewBuilder
    func BodyView(scale: CGFloat) -> some View {
        ForEach(VisualBodyPart.allCases) { part in
            BodyPartShape(path: part.path)
                .fill(color(for: part))
                .scaleEffect(scale, anchor: UnitPoint.topLeading)
        }
    }
}

// Visual Mapping: Front-Facing Single Diagram
enum VisualBodyPart: String, CaseIterable, Identifiable {
    case head, neck, chest, abdomen, hips
    case leftShoulder, rightShoulder
    case leftUpperArm, rightUpperArm
    case leftForearm, rightForearm
    case leftHand, rightHand
    case leftThigh, rightThigh
    case leftShin, rightShin
    case leftFoot, rightFoot

    var id: String { rawValue }

    var path: Path {
        switch self {
        case .head: return BodyPaths.head
        case .neck: return BodyPaths.neck
        case .chest: return BodyPaths.chest
        case .abdomen: return BodyPaths.abdomen
        case .hips: return BodyPaths.hips
        case .leftShoulder: return BodyPaths.leftShoulder
        case .rightShoulder: return BodyPaths.rightShoulder
        case .leftUpperArm: return BodyPaths.leftUpperArm
        case .rightUpperArm: return BodyPaths.rightUpperArm
        case .leftForearm: return BodyPaths.leftForearm
        case .rightForearm: return BodyPaths.rightForearm
        case .leftHand: return BodyPaths.leftHand
        case .rightHand: return BodyPaths.rightHand
        case .leftThigh: return BodyPaths.leftThigh
        case .rightThigh: return BodyPaths.rightThigh
        case .leftShin: return BodyPaths.leftShin
        case .rightShin: return BodyPaths.rightShin
        case .leftFoot: return BodyPaths.leftFoot
        case .rightFoot: return BodyPaths.rightFoot
        }
    }
    
    // Map underlying BodyPart data (including back parts) to this visual region
    var mappedParts: Set<BodyPart> {
        switch self {
        case .head: return [.head]
        case .neck: return [.neck]
        // Chest shape covers upper torso front/back
        case .chest: return [.chest, .upperBack, .trapezius, .lats]
        // Abdomen shape covers lower torso
        case .abdomen: return [.abdomen, .lowerBack]
        // Hips shape covers glutes/hips
        case .hips: return [.hips, .leftGlute, .rightGlute]
        case .leftShoulder: return [.leftShoulder]
        case .rightShoulder: return [.rightShoulder]
        case .leftUpperArm: return [.leftUpperArm]
        case .rightUpperArm: return [.rightUpperArm]
        case .leftForearm: return [.leftForearm]
        case .rightForearm: return [.rightForearm]
        case .leftHand: return [.leftHand]
        case .rightHand: return [.rightHand]
        case .leftThigh: return [.leftThigh, .leftHamstring]
        case .rightThigh: return [.rightThigh, .rightHamstring]
        case .leftShin: return [.leftShin, .leftCalf]
        case .rightShin: return [.rightShin, .rightCalf]
        case .leftFoot: return [.leftFoot]
        case .rightFoot: return [.rightFoot]
        }
    }
}

// MARK: - Path Definitions
// "Muscular" proportions. Viewbox approx 300 x 600. Center X = 150.
struct BodyPaths {
    
    // MARK: - Head & Neck
    static let head: Path = {
        var p = Path()
        // Center 150. y=20.
        p.addEllipse(in: CGRect(x: 125, y: 10, width: 50, height: 60))
        return p
    }()
    
    static let neck: Path = {
        // Thick neck
        var p = Path()
        // slightly wider than before
        p.addRect(CGRect(x: 135, y: 65, width: 30, height: 20))
        return p
    }()
    
    // MARK: - Torso
    static let chest: Path = {
        // Broad chest (Pecs)
        var p = Path()
        p.move(to: CGPoint(x: 135, y: 85)) // Neck Left Base
        p.addLine(to: CGPoint(x: 165, y: 85)) // Neck Right Base
        p.addLine(to: CGPoint(x: 210, y: 95)) // Shoulder Right Connect
        p.addLine(to: CGPoint(x: 195, y: 160)) // Under Arm Right
        p.addLine(to: CGPoint(x: 150, y: 170)) // Sternum / Solar Plexus
        p.addLine(to: CGPoint(x: 105, y: 160)) // Under Arm Left
        p.addLine(to: CGPoint(x: 90, y: 95))  // Shoulder Left Connect
        p.closeSubpath()
        return p
    }()
    
    static let abdomen: Path = {
        // Tapered waist (V-taper)
        var p = Path()
        p.move(to: CGPoint(x: 105, y: 160)) // Chest Bottom Left
        p.addLine(to: CGPoint(x: 150, y: 170)) // Center top
        p.addLine(to: CGPoint(x: 195, y: 160)) // Chest Bottom Right
        p.addLine(to: CGPoint(x: 185, y: 230)) // Waist Right (narrower)
        p.addLine(to: CGPoint(x: 115, y: 230)) // Waist Left
        p.closeSubpath()
        return p
    }()
    
    static let hips: Path = {
        // Pelvis area
        var p = Path()
        p.move(to: CGPoint(x: 115, y: 230)) // Waist Left
        p.addLine(to: CGPoint(x: 185, y: 230)) // Waist Right
        p.addLine(to: CGPoint(x: 200, y: 270)) // Hip Right Outer
        p.addLine(to: CGPoint(x: 150, y: 290)) // Crotch
        p.addLine(to: CGPoint(x: 100, y: 270)) // Hip Left Outer
        p.closeSubpath()
        return p
    }()
    
    // MARK: - Arms (Bulky)
    
    // Screen Left = Person Right
    static let screenLeftShoulder: Path = {
        // Deltoid
        var p = Path()
        // Rounded muscular shape
        p.move(to: CGPoint(x: 90, y: 95)) // chest connect
        p.addQuadCurve(to: CGPoint(x: 60, y: 130), control: CGPoint(x: 60, y: 90)) // Outer bulge
        p.addQuadCurve(to: CGPoint(x: 95, y: 140), control: CGPoint(x: 80, y: 140)) // Inner insertion
        p.closeSubpath()
        return p
    }()
    
    static let screenRightShoulder: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 210, y: 95))
        p.addQuadCurve(to: CGPoint(x: 240, y: 130), control: CGPoint(x: 240, y: 90))
        p.addQuadCurve(to: CGPoint(x: 205, y: 140), control: CGPoint(x: 220, y: 140))
        p.closeSubpath()
        return p
    }()
    
    static var rightShoulder: Path { screenLeftShoulder }
    static var leftShoulder: Path { screenRightShoulder }
    
    static let screenLeftUpperArm: Path = {
        // Bicep/Tricep
        var p = Path()
        p.move(to: CGPoint(x: 60, y: 130)) // Shoulder outer
        p.addQuadCurve(to: CGPoint(x: 55, y: 200), control: CGPoint(x: 45, y: 165)) // Tricep bulge
        p.addLine(to: CGPoint(x: 85, y: 200)) // Elbow
        p.addQuadCurve(to: CGPoint(x: 95, y: 140), control: CGPoint(x: 95, y: 170)) // Bicep inner
        p.closeSubpath()
        return p
    }()
    
    static let screenRightUpperArm: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 240, y: 130))
        p.addQuadCurve(to: CGPoint(x: 245, y: 200), control: CGPoint(x: 255, y: 165))
        p.addLine(to: CGPoint(x: 215, y: 200))
        p.addQuadCurve(to: CGPoint(x: 205, y: 140), control: CGPoint(x: 205, y: 170))
        p.closeSubpath()
        return p
    }()
    static var rightUpperArm: Path { screenLeftUpperArm }
    static var leftUpperArm: Path { screenRightUpperArm }
    
    static let screenLeftForearm: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 55, y: 200))
        p.addQuadCurve(to: CGPoint(x: 50, y: 260), control: CGPoint(x: 45, y: 220)) // Forearm muscle
        p.addLine(to: CGPoint(x: 75, y: 260)) // Wrist
        p.addQuadCurve(to: CGPoint(x: 85, y: 200), control: CGPoint(x: 85, y: 220)) // Inner forearm
        p.closeSubpath()
        return p
    }()

    static let screenRightForearm: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 245, y: 200))
        p.addQuadCurve(to: CGPoint(x: 250, y: 260), control: CGPoint(x: 255, y: 220))
        p.addLine(to: CGPoint(x: 225, y: 260))
        p.addQuadCurve(to: CGPoint(x: 215, y: 200), control: CGPoint(x: 215, y: 220))
        p.closeSubpath()
        return p
    }()
    static var rightForearm: Path { screenLeftForearm }
    static var leftForearm: Path { screenRightForearm }
    
    static let screenLeftHand: Path = {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 50, y: 260, width: 25, height: 30), cornerSize: CGSize(width: 5, height: 5))
        return p
    }()
    static let screenRightHand: Path = {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 225, y: 260, width: 25, height: 30), cornerSize: CGSize(width: 5, height: 5))
        return p
    }()
    static var rightHand: Path { screenLeftHand }
    static var leftHand: Path { screenRightHand }
    
    // MARK: - Legs (Thick Quads)
    
    static let screenLeftThigh: Path = {
        // Quad sweep
        var p = Path()
        p.move(to: CGPoint(x: 100, y: 270)) // Hip outer
        p.addQuadCurve(to: CGPoint(x: 95, y: 380), control: CGPoint(x: 80, y: 320)) // Outer sweep
        p.addLine(to: CGPoint(x: 140, y: 380)) // Knee inner
        p.addQuadCurve(to: CGPoint(x: 150, y: 290), control: CGPoint(x: 145, y: 320)) // Inner thigh
        p.closeSubpath()
        return p
    }()
    
    static let screenRightThigh: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 200, y: 270))
        p.addQuadCurve(to: CGPoint(x: 205, y: 380), control: CGPoint(x: 220, y: 320))
        p.addLine(to: CGPoint(x: 160, y: 380))
        p.addQuadCurve(to: CGPoint(x: 150, y: 290), control: CGPoint(x: 155, y: 320))
        p.closeSubpath()
        return p
    }()
    static var rightThigh: Path { screenLeftThigh }
    static var leftThigh: Path { screenRightThigh }
    
    static let screenLeftShin: Path = {
        // Calf diamond
        var p = Path()
        p.move(to: CGPoint(x: 95, y: 380)) // Knee outer
        p.addQuadCurve(to: CGPoint(x: 100, y: 480), control: CGPoint(x: 85, y: 410)) // Calf bulge
        p.addLine(to: CGPoint(x: 130, y: 480)) // Ankle inner
        p.addLine(to: CGPoint(x: 140, y: 380)) // Knee inner
        p.closeSubpath()
        return p
    }()
    
    static let screenRightShin: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 205, y: 380))
        p.addQuadCurve(to: CGPoint(x: 200, y: 480), control: CGPoint(x: 215, y: 410))
        p.addLine(to: CGPoint(x: 170, y: 480))
        p.addLine(to: CGPoint(x: 160, y: 380))
        p.closeSubpath()
        return p
    }()
    static var rightShin: Path { screenLeftShin }
    static var leftShin: Path { screenRightShin }
    
    static let screenLeftFoot: Path = {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 100, y: 480, width: 30, height: 15), cornerSize: CGSize(width: 5, height: 5))
        return p
    }()
    static let screenRightFoot: Path = {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 170, y: 480, width: 30, height: 15), cornerSize: CGSize(width: 5, height: 5))
        return p
    }()
    static var rightFoot: Path { screenLeftFoot }
    static var leftFoot: Path { screenRightFoot }
}

struct BodyPartShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path {
        return path
    }
}
