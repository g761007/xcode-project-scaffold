import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// What a `scaffold.yml` looks like to a shell completing a path. Both
/// spellings, because the file is YAML and nothing stops someone from naming
/// theirs `app.yaml` — `--config` has always taken any path.
///
/// Named once, so that every command offering a configuration offers the same
/// files. A command that quietly completed only `.yml` would look broken to
/// whoever had the other.
let manifestExtensions = ["yml", "yaml"]

/// What a run would do, as opposed to what the project is. These shape the
/// plan, so `plan` has to accept them too or it would preview commands that
/// `generate` is not going to run.
struct RunOptions: ParsableArguments {
    @Flag(name: .customLong("skip-git"), help: "Do not create a git repository.")
    var skipGit = false

    @Flag(name: .customLong("skip-generate"), help: "Do not run the generator.")
    var skipGenerate = false

    var generationOptions: GenerationOptions {
        GenerationOptions(initializeGit: !skipGit, runGenerator: !skipGenerate)
    }
}
