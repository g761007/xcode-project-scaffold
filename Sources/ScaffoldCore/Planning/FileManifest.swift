import ScaffoldSchema

/// One path claimed twice (§13.4).
///
/// A template author's mistake rather than a user's, in the usual case, so the
/// message names the path and everyone who claimed it: "something collided"
/// leaves the reader searching a template tree for a path they have not been
/// told.
public struct TemplateConflictError: Error, Equatable, Sendable {
    /// Relative to the destination, after rendering — the path as it would have
    /// been written, not the template's spelling of it.
    public let path: String
    /// Everyone who claimed the path, sorted so that the same conflict reads
    /// the same way twice. A name appearing twice is not a fault in the report:
    /// it says one origin produced the path twice.
    public let origins: [String]
}

extension TemplateConflictError: ReportableError {
    public var errorCode: ScaffoldErrorCode {
        .templateConflict
    }

    /// The path claimed twice — the one thing the reader has to go and look at.
    public var relevantPath: String? {
        path
    }

    /// A template set that cannot be resolved into a file list, like a missing
    /// variant — the run never reaches the destination, so nothing about the
    /// machine or the directory is at fault (§11.4).
    public var exitCode: ScaffoldExitCode {
        errorCode.exitCode
    }
}

extension TemplateConflictError: CustomStringConvertible {
    public var description: String {
        "The same file is claimed twice.\n"
            + "File:\n  \(path)\n"
            + "Claimed by:\n"
            + origins.map { "  \($0)" }.joined(separator: "\n")
    }
}

/// Every file a run would write, each with the origin that claimed its path.
///
/// The whole list is assembled before anything reaches disk (§13.4), so a path
/// claimed twice fails with both names in it rather than being won by whichever
/// origin happened to be added last. Order of addition therefore carries no
/// meaning — which is the point, since a template set is a dictionary and has
/// no order to rely on.
///
/// The architecture overlay is not a conflict: it replaces the variant's screen
/// by declaration, and `TemplateLibrary` resolves that against the base layer's
/// paths before anything reaches here (ADR-0004), so the overlay and the file it
/// stands in for never both arrive. What arrives twice is two peers — two
/// features, or a feature and a variant — each believing the path is theirs.
struct FileManifest {
    private struct Entry {
        let file: PlannedFile
        /// Where the file came from: a template layer's directory under
        /// `Templates/`, or the renderer that produced it. Not `provider` —
        /// that word already means a technology choice in this project.
        let origin: String
    }

    private var entries: [Entry] = []

    mutating func add(_ file: PlannedFile, from origin: String) {
        entries.append(Entry(file: file, origin: origin))
    }

    mutating func add(_ files: [PlannedFile], from origin: String) {
        for file in files {
            add(file, from: origin)
        }
    }

    /// The planned files in path order, once no path has more than one origin.
    ///
    /// One conflict is reported rather than all of them, and it is the lowest
    /// path, so that the same template set always names the same one: a
    /// conflict is a fault in the templates, fixed one at a time, not a list of
    /// user mistakes to work through in a single pass.
    func resolved() throws -> [PlannedFile] {
        let claims = Dictionary(grouping: entries, by: \.file.path)
        if let conflict = claims.filter({ $0.value.count > 1 }).min(by: { $0.key < $1.key }) {
            throw TemplateConflictError(
                path: conflict.key,
                origins: conflict.value.map(\.origin).sorted()
            )
        }
        return entries.map(\.file).sorted { $0.path < $1.path }
    }
}
