/// The version of `xscaffold` itself, as `--version` reports it.
///
/// It is not stamped into anything the tool produces. A generated
/// `scaffold.yml` describes the project and not the thing that wrote it, and
/// `--output json` carries what a caller branches on — neither has a use for a
/// version that would then have to be kept meaningful across releases.
public enum ScaffoldVersion {
    public static let current = "0.2.0"
}
