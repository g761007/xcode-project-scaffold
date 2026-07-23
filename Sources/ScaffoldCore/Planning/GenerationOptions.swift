/// The parts of a run that are not properties of the project.
///
/// Lives here rather than in `ScaffoldSchema` because it is not part of the
/// contract: `scaffold.yml` describes the project and never a particular run
/// (§4), so these arrive as CLI flags and are never serialised.
///
/// These decide *what is in the plan*. Options that decide how a plan is
/// carried out — `--force` — are arguments to `PlanExecutor` instead, so that
/// the same configuration always yields the same plan, and so that nothing here
/// can be set on the executor and quietly ignored.
public struct GenerationOptions: Equatable, Sendable {
    public var initializeGit: Bool
    public var runGenerator: Bool

    public init(initializeGit: Bool = true, runGenerator: Bool = true) {
        self.initializeGit = initializeGit
        self.runGenerator = runGenerator
    }
}
