import Foundation
import ScaffoldSchema

/// Carries out a `GenerationPlan`: files onto disk, then commands against them.
///
/// Two rules shape it, both from §10.
///
/// **Nothing is written in the destination until everything is ready.** Files
/// are rendered into a staging area first, and only then published, so a
/// failure while writing cannot leave a directory that looks like a project but
/// is missing half of it.
///
/// **xscaffold removes only what it created.** If it created the destination, a
/// failure removes it again and the user is left where they started — bar any
/// intermediate parent directories it had to create on the way, which are left
/// empty rather than swept up. If the destination already existed — empty, or
/// non-empty with `--force` — a failure leaves it alone and says so: telling a
/// generated file from one that was already there would mean guessing, and
/// guessing wrong deletes someone's work.
public struct PlanExecutor: Sendable {
    private let processRunner: any ProcessRunner

    public init(processRunner: any ProcessRunner = SystemProcessRunner()) {
        self.processRunner = processRunner
    }

    public func execute(_ plan: GenerationPlan, at destination: URL, force: Bool = false) throws {
        // Everything that can be known before writing is checked before
        // writing, so the common failures cost nothing to recover from.
        try checkPaths(of: plan.files)
        let destinationExisted = try destinationExists(destination, force: force)
        try checkExecutables(of: plan.commands)

        let staging = try makeStagingDirectory(beside: destination)
        defer { try? FileManager.default.removeItem(at: staging) }

        try write(plan.files, into: staging)
        try publish(plan.files, from: staging, to: destination, destinationExisted: destinationExisted)

        do {
            try run(plan.commands, in: destination)
        } catch let error as GenerationError {
            guard destinationExisted else {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
            // Not ours to remove, so the reader has to be told what is in it.
            throw GenerationError.failedLeavingFiles(error, in: destination)
        }
    }
}

// MARK: - Before anything is written

extension PlanExecutor {
    /// Planned paths come from templates and a validated project name, so a path
    /// that escapes the destination should be unreachable. It is checked anyway,
    /// because the alternative to checking is writing outside the directory the
    /// user named.
    private func checkPaths(of files: [PlannedFile]) throws {
        for file in files {
            let components = file.path.split(separator: "/", omittingEmptySubsequences: true)
            guard !file.path.hasPrefix("/"), !components.isEmpty, !components.contains("..") else {
                throw GenerationError.unsafePlannedPath(file.path)
            }
        }
    }

    /// Whether the destination is already there — which decides whether a later
    /// failure may remove it — throwing if it is there in a way that cannot be
    /// written into.
    ///
    /// §13.3's two tiers, in order. A directory that already holds a project is
    /// refused before `force` is so much as consulted, so the flag can never
    /// downgrade the hard tier. A merely non-empty one is refused unless
    /// forced. A `scaffold.yml` on its own occupies nothing: it is how "save
    /// now, generate later" leaves a directory, and the plan writes its own.
    private func destinationExists(_ destination: URL, force: Bool) throws -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) else {
            return false
        }
        guard isDirectory.boolValue else {
            throw GenerationError.destinationIsNotADirectory(destination)
        }

        let existing = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        if let marker = projectMarker(among: existing) {
            throw GenerationError.destinationHasProject(destination, marker: marker)
        }
        guard existing.allSatisfy({ $0 == "scaffold.yml" }) || force else {
            throw GenerationError.destinationNotEmpty(destination)
        }
        return true
    }

    /// The mark of an existing project among a directory's own entries: a
    /// project file, a generator manifest, or source code — `.swift` also
    /// catches `Package.swift`, so a Swift package is refused by the same rule.
    /// Top-level entries only: the canonical layouts all mark themselves there,
    /// and anything deeper is still behind the non-empty tier.
    private func projectMarker(among entries: [String]) -> String? {
        entries.sorted().first { entry in
            entry.hasSuffix(".xcodeproj") || entry.hasSuffix(".xcworkspace")
                || entry == "project.yml" || entry.hasSuffix(".swift")
        }
    }

    private func checkExecutables(of commands: [PlannedCommand]) throws {
        var checked: Set<String> = []
        for command in commands where checked.insert(command.executable).inserted {
            guard processRunner.locate(command.executable) != nil else {
                throw GenerationError.executableNotFound(command.executable)
            }
        }
    }
}

// MARK: - Writing

extension PlanExecutor {
    /// A sibling of the destination rather than a directory under `/tmp`: the
    /// move that publishes it is then a rename within one volume, which is
    /// atomic, instead of a copy that can fail half way.
    private func makeStagingDirectory(beside destination: URL) throws -> URL {
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let staging = parent.appendingPathComponent(
            ".\(destination.lastPathComponent).xscaffold-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        return staging
    }

    private func write(_ files: [PlannedFile], into staging: URL) throws {
        for file in files {
            let url = staging.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// A destination xscaffold creates arrives in one move. One that was already
    /// there is filled in file by file, replacing what the plan names and
    /// leaving everything else — a directory cannot be moved onto another
    /// without destroying what is in it.
    private func publish(
        _ files: [PlannedFile],
        from staging: URL,
        to destination: URL,
        destinationExisted: Bool
    ) throws {
        guard destinationExisted else {
            try FileManager.default.moveItem(at: staging, to: destination)
            return
        }

        for file in files {
            let target = destination.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) {
                // `removeItem` takes a directory's whole contents with it, and
                // `--force` is permission to replace files, not to empty
                // someone's folder.
                guard !isDirectory.boolValue else {
                    throw GenerationError.cannotReplaceDirectory(target)
                }
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: staging.appendingPathComponent(file.path), to: target)
        }
    }
}

// MARK: - Running

extension PlanExecutor {
    private func run(_ commands: [PlannedCommand], in destination: URL) throws {
        for command in commands {
            let result = try processRunner.run(ProcessInvocation(
                executable: command.executable,
                arguments: command.arguments,
                workingDirectory: destination
            ))

            guard result.succeeded else {
                throw GenerationError.commandFailed(
                    command,
                    exitStatus: result.exitStatus,
                    output: result.combinedOutput
                )
            }
        }
    }
}
