import Foundation
import ScaffoldSchema

extension GenerationPlan {
    /// The existing files a run at `destination` would replace: planned paths
    /// that are already on disk (§13.3). Asked of the destination rather than
    /// stored in the plan, because the plan describes the project and is the
    /// same whichever directory it lands in — which is also why this must be
    /// asked *before* writing: afterwards every planned path exists.
    public func overwrites(at destination: URL) -> [String] {
        files.map(\.path).filter {
            FileManager.default.fileExists(atPath: destination.appendingPathComponent($0).path)
        }
    }
}
