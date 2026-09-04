import Foundation

/// Checks GitHub for a newer release.
///
/// Deliberately not a full updater: no download, no install, no dependency on
/// Sparkle. It asks the releases API once per launch at most, and reports what
/// it finds so the UI can offer a link. Until the app is notarized, an
/// automatic installer would only lead users into a Gatekeeper prompt anyway.
@MainActor
final class UpdateChecker {
    struct Release {
        let version: String
        let page: URL
    }

    /// Set when a newer release exists.
    private(set) var newerRelease: Release?

    /// What a finished check found.
    enum Outcome {
        case upToDate
        case updateAvailable(Release)
        /// No network, rate limited, or no releases published yet.
        case failed
    }

    /// Called on the main actor when a newer release is found.
    var onUpdateFound: ((Release) -> Void)?

    /// Called on the main actor when any check finishes, including when it
    /// finds nothing. Without this a caller that shows "Checking…" has no way
    /// to know it's over.
    var onCheckCompleted: ((Outcome) -> Void)?

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/connorpodea/BetterHUD/releases/latest"
    )
    private static let lastCheckedKey = "lastUpdateCheck"
    /// One check a day is plenty for a hobby release cadence, and it keeps the
    /// app from touching the network on every launch.
    private static let checkInterval: TimeInterval = 60 * 60 * 24

    private let defaults: UserDefaults
    private let currentVersion: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentVersion = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Checks only if enough time has passed since the last attempt.
    func checkIfDue() {
        let last = defaults.object(forKey: Self.lastCheckedKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > Self.checkInterval else { return }
        check()
    }

    func check() {
        guard let url = Self.latestReleaseURL else { return }
        defaults.set(Date(), forKey: Self.lastCheckedKey)

        var request = URLRequest(url: url, timeoutInterval: 10)
        // GitHub rejects API requests without one.
        request.setValue("BetterHUD/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        Task { [weak self] in
            let release = await Self.fetch(request)
            await MainActor.run { self?.handle(release) }
        }
    }

    // MARK: - Internals

    private struct LatestRelease: Decodable {
        let tagName: String
        let htmlUrl: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    private static func fetch(_ request: URLRequest) async -> LatestRelease? {
        // A failed check is not worth reporting: no network, rate limiting, and
        // "no releases yet" should all just mean nothing happens.
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? JSONDecoder().decode(LatestRelease.self, from: data)
    }

    private func handle(_ release: LatestRelease?) {
        guard let release else {
            onCheckCompleted?(.failed)
            return
        }

        let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        guard Self.isNewer(latest, than: currentVersion),
              let page = URL(string: release.htmlUrl) else {
            onCheckCompleted?(.upToDate)
            return
        }

        let found = Release(version: latest, page: page)
        newerRelease = found
        onUpdateFound?(found)
        onCheckCompleted?(.updateAvailable(found))
    }

    /// Compares dotted version strings component by component, so 0.0.10 is
    /// correctly newer than 0.0.9 where a string comparison would disagree.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let left = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let right = current.split(separator: ".").map { Int($0) ?? 0 }

        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }
        return false
    }
}
