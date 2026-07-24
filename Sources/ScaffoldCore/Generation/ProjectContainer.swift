import Foundation
import ScaffoldSchema

/// Which container a generated project is driven through: the `.xcodeproj`
/// itself, or — once CocoaPods is in play — the `.xcworkspace` that
/// `pod install` produces around it.
///
/// Build, Test and Open all take their target from here and nowhere else
/// (§10): a caller deciding `-project` versus `-workspace` for itself is how
/// the two drift apart, and CocoaPods' one special rule ("use the workspace")
/// should be written down exactly once.
public enum ProjectContainer: Equatable, Sendable {
    case project(fileName: String)
    case workspace(fileName: String)

    /// The container this configuration's project is driven through.
    /// CocoaPods and mixed wrap the project in a workspace; everything else is
    /// the project file itself.
    public init(for configuration: ProjectConfiguration) {
        switch configuration.dependencyManagement.mode {
        case .cocoapods, .mixed:
            self = .workspace(fileName: "\(configuration.project.name).xcworkspace")
        case .disabled, .spm:
            self = .project(fileName: configuration.projectFileName)
        }
    }

    /// What sits at the destination — the thing to open.
    public var fileName: String {
        switch self {
        case let .project(fileName), let .workspace(fileName):
            fileName
        }
    }

    /// How xcodebuild is told about this container.
    public var xcodebuildFlag: String {
        switch self {
        case .project: "-project"
        case .workspace: "-workspace"
        }
    }

    /// Confirms the workspace the plan promised is on disk, once the plan has
    /// actually run pod install (§9.3): a run that skipped the generator — and
    /// with it the pods — promised nothing, and a project container is the
    /// generator's own output, verified by it failing loudly instead.
    public func verifyProduced(by plan: GenerationPlan, at destination: URL) throws {
        guard case let .workspace(fileName) = self,
              plan.commands.contains(where: { $0.executable == "pod" })
        else { return }

        guard FileManager.default.fileExists(atPath: destination.appendingPathComponent(fileName).path) else {
            throw GenerationError.workspaceNotProduced(fileName)
        }
    }
}
