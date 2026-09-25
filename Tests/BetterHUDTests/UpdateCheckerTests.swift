import Testing

@testable import BetterHUD

/// Only the comparison is covered. The check around it is a network request,
/// which isn't worth a stubbed URL session here — the part that can silently be
/// wrong is the ordering.
@MainActor
struct UpdateCheckerTests {
    @Test("A higher component wins, whatever a string comparison would say")
    func comparesComponentsNumerically() {
        // The case that motivates doing this at all: "0.0.10" sorts *below*
        // "0.0.9" as text, which would leave everyone stuck on 0.0.9.
        #expect(UpdateChecker.isNewer("0.0.10", than: "0.0.9"))
        #expect(!UpdateChecker.isNewer("0.0.9", than: "0.0.10"))
        #expect(UpdateChecker.isNewer("0.2.0", than: "0.1.9"))
        #expect(UpdateChecker.isNewer("1.0.0", than: "0.9.9"))
    }

    @Test("The same version is not an update")
    func rejectsTheSameVersion() {
        #expect(!UpdateChecker.isNewer("0.0.2", than: "0.0.2"))
        #expect(!UpdateChecker.isNewer("1.2.3", than: "1.2.3"))
    }

    @Test("An older version is not an update")
    func rejectsOlderVersions() {
        #expect(!UpdateChecker.isNewer("0.0.1", than: "0.0.2"))
        #expect(!UpdateChecker.isNewer("0.9.9", than: "1.0.0"))
    }

    @Test("Missing components count as zero, so 0.1 and 0.1.0 are the same")
    func treatsMissingComponentsAsZero() {
        #expect(!UpdateChecker.isNewer("0.1", than: "0.1.0"))
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.1"))
        #expect(UpdateChecker.isNewer("0.1.1", than: "0.1"))
        #expect(!UpdateChecker.isNewer("0.1", than: "0.1.1"))
        #expect(UpdateChecker.isNewer("2", than: "1.9.9"))
    }

    @Test("A component that isn't a number counts as zero rather than crashing")
    func survivesUnparseableVersions() {
        // A release tagged something unexpected shouldn't take the app down; it
        // should just fail to look newer.
        #expect(!UpdateChecker.isNewer("", than: "0.0.2"))
        #expect(!UpdateChecker.isNewer("beta", than: "0.0.2"))
        #expect(UpdateChecker.isNewer("1.beta", than: "0.9"))
    }
}
