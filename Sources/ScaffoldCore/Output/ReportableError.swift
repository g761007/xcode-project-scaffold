import ScaffoldSchema

/// An error that can state itself in the terms §23 requires.
///
/// The point of the protocol is that the mapping lives with the error rather
/// than at the place that reports it: a new `GenerationError` case is a
/// compiler error here, where someone knows what it means, instead of quietly
/// arriving at a caller as the catch-all code.
public protocol ReportableError: Error, CustomStringConvertible {
    /// The name a caller branches on.
    var errorCode: ScaffoldErrorCode { get }

    /// Overrides the code's own phase, for the codes that can arrive from more
    /// than one stage. Defaults to the code's.
    var reportedPhase: ScaffoldPhase? { get }

    /// The external command that failed, as it would be typed.
    var failedCommand: String? { get }

    /// The file or directory the failure is about.
    var relevantPath: String? { get }
}

extension ReportableError {
    public var reportedPhase: ScaffoldPhase? {
        errorCode.phase
    }

    public var failedCommand: String? {
        nil
    }

    public var relevantPath: String? {
        nil
    }

    /// The wire form. `description` is the message: one error has one wording,
    /// whether it is read in a terminal or parsed out of JSON.
    public var scaffoldError: ScaffoldError {
        ScaffoldError(
            code: errorCode,
            message: description,
            command: failedCommand,
            path: relevantPath
        )
    }
}
