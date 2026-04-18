import Foundation
import AppKit

@MainActor
final class UpdateChecker: ObservableObject {

    // MARK: - State

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case downloading
        case readyToInstall
        case installing
        case failed(String)
    }

    @Published var state: State = .idle
    @Published var latestVersion: String?
    @Published var releaseNotes: String?

    private let repo = "jpwahle/ai-apple-mail"
    private var downloadedDMG: URL?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Version Comparison

    /// Returns true when `remote` is a strictly higher semver than `local`.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        let len = max(r.count, l.count)
        for i in 0..<len {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    // MARK: - Check

    /// Checks GitHub for a newer release. On auto-check (default), failures
    /// are silent. On manual check, errors surface to the UI.
    func checkForUpdates(manual: Bool = false) {
        switch state {
        case .idle, .upToDate, .failed: break
        default: return
        }
        state = .checking

        Task {
            do {
                let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    state = manual ? .failed("Could not reach GitHub.") : .idle
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    state = .idle
                    return
                }

                let remote = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                latestVersion = remote
                releaseNotes = json["body"] as? String

                guard Self.isNewer(remote, than: currentVersion) else {
                    state = manual ? .upToDate : .idle
                    return
                }

                // Find first .dmg asset
                guard let assets = json["assets"] as? [[String: Any]],
                      let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                      let urlStr = dmg["browser_download_url"] as? String,
                      let dmgURL = URL(string: urlStr) else {
                    state = manual ? .failed("No DMG found in release.") : .idle
                    return
                }

                await download(from: dmgURL)

            } catch {
                state = manual ? .failed(error.localizedDescription) : .idle
            }
        }
    }

    // MARK: - Download

    private func download(from url: URL) async {
        state = .downloading

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("AIMailComposer-update.dmg")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)

            downloadedDMG = dest
            state = .readyToInstall
            showUpdateAlert()

        } catch {
            state = .failed("Download failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Install & Relaunch

    func install() {
        guard let dmgPath = downloadedDMG else {
            state = .failed("No downloaded update found.")
            return
        }

        state = .installing

        let appBundlePath = Bundle.main.bundlePath

        Task.detached {
            let mountPoint = FileManager.default.temporaryDirectory
                .appendingPathComponent("aimail-update-mount").path

            do {
                // Clean up any leftover mount
                let unmountOld = Process()
                unmountOld.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                unmountOld.arguments = ["detach", mountPoint, "-quiet"]
                try? unmountOld.run()
                unmountOld.waitUntilExit()

                // Mount DMG
                let mount = Process()
                mount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                mount.arguments = ["attach", dmgPath.path, "-nobrowse", "-readonly", "-mountpoint", mountPoint]
                try mount.run()
                mount.waitUntilExit()

                guard mount.terminationStatus == 0 else {
                    self.detach(mountPoint)
                    await MainActor.run { self.state = .failed("Failed to mount update DMG.") }
                    return
                }

                // Find .app inside mount
                let contents = try FileManager.default.contentsOfDirectory(atPath: mountPoint)
                guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
                    await MainActor.run { self.state = .failed("No .app found in DMG.") }
                    self.detach(mountPoint)
                    return
                }

                let source = "\(mountPoint)/\(appName)"
                let dest = appBundlePath

                // Replace app via rsync
                let rsync = Process()
                rsync.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
                rsync.arguments = ["-a", "--delete", "\(source)/", "\(dest)/"]
                try rsync.run()
                rsync.waitUntilExit()

                guard rsync.terminationStatus == 0 else {
                    await MainActor.run { self.state = .failed("Failed to copy update.") }
                    self.detach(mountPoint)
                    return
                }

                // Cleanup
                self.detach(mountPoint)
                try? FileManager.default.removeItem(at: dmgPath)

                // Relaunch
                let relaunch = Process()
                relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                relaunch.arguments = ["-n", dest]
                try relaunch.run()

                exit(0)

            } catch {
                self.detach(mountPoint)
                await MainActor.run {
                    self.state = .failed("Install error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Detach a mounted DMG, ignoring errors.
    private nonisolated func detach(_ mountPoint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-quiet"]
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Alert

    private func showUpdateAlert() {
        guard let version = latestVersion else { return }

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Apple Mail AI Plugin v\(version) is ready. Relaunch to update?"
        alert.addButton(withTitle: "Relaunch Now")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            install()
        }
    }
}
