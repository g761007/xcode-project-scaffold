/// A dotted version such as `18`, `18.0` or `26.1.2`.
///
/// Deliberately not `Double`: `18.10` read as a number sorts below `18.9`,
/// which is exactly the mistake this type exists to prevent.
struct VersionNumber: Comparable {
    let components: [Int]

    /// Returns `nil` for anything that is not one to three dot-separated
    /// non-negative integers.
    init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1 ... 3).contains(parts.count) else { return nil }

        var parsed: [Int] = []
        for part in parts {
            guard !part.isEmpty,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = Int(part) // nil on overflow, which is a rejection
            else { return nil }
            parsed.append(value)
        }
        components = parsed
    }

    init(_ components: [Int]) {
        self.components = components
    }

    /// Both operators zero-pad. Synthesised `==` would compare the raw arrays,
    /// making `18` and `18.0` neither equal nor ordered — which breaks
    /// `Comparable`'s contract and, with it, `sorted`, `min` and `Set`.
    static func == (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        zipPadded(lhs, rhs).allSatisfy { $0 == $1 }
    }

    static func < (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        for (left, right) in zipPadded(lhs, rhs) where left != right {
            return left < right
        }
        return false
    }

    private static func zipPadded(_ lhs: VersionNumber, _ rhs: VersionNumber) -> [(Int, Int)] {
        let width = max(lhs.components.count, rhs.components.count)
        return (0 ..< width).map { index in
            (lhs.components.indices.contains(index) ? lhs.components[index] : 0,
             rhs.components.indices.contains(index) ? rhs.components[index] : 0)
        }
    }
}
