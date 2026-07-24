/// The version of `xscaffold` itself, as `--version` reports it.
///
/// The placeholder below is not a version to maintain. The release workflow
/// stamps the pushed tag's number over it (`Scripts/set-version.sh`) before
/// building, so the tag is the single source of the version (§20.3) — and a
/// development build honestly says it is one. The release smoke test fails
/// the release if the shipped binary disagrees with its tag.
///
/// It is not stamped into anything the tool produces. A generated
/// `scaffold.yml` describes the project and not the thing that wrote it, and
/// `--output json` carries what a caller branches on — neither has a use for a
/// version that would then have to be kept meaningful across releases.
public enum ScaffoldVersion {
    /// Overwritten from the release tag at build time; never edited by hand.
    public static let current = "0.0.0-dev"
}
