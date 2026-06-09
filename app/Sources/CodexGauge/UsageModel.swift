import Foundation
import Observation
import SwiftUI
import UserNotifications

// ---- preferences (UserDefaults-backed) ----
enum Prefs {
    static let codexPathKey = "codexPath"
    static let intervalKey   = "refreshInterval"
    static let thresholdKey   = "lowThreshold"
    static let alertKey       = "lowAlertEnabled"
    static let activeQueryKey = "activeQueryEnabled"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            codexPathKey: "~/.codex/sessions",
            intervalKey: 60,
            thresholdKey: 10,
            alertKey: true,
            activeQueryKey: false,
            LanguageKey: "en",   // English by default; System / 中文 selectable in Settings
        ])
    }
    static var codexPath: String { UserDefaults.standard.string(forKey: codexPathKey) ?? "~/.codex/sessions" }
    static var interval: Int { max(15, UserDefaults.standard.integer(forKey: intervalKey)) }
    static var threshold: Int { max(1, UserDefaults.standard.integer(forKey: thresholdKey)) }
    static var alertEnabled: Bool { UserDefaults.standard.bool(forKey: alertKey) }
}

struct UsageWindow {
    var remaining: Double      // 0–100
    var resetsAt: Date?
}

// Reads the rate-limit snapshot the Codex CLI already wrote to local session logs.
// Zero-cost: only reads files, never calls any API, never touches any token.
@Observable
final class UsageModel {
    var fiveHour: UsageWindow?
    var weekly: UsageWindow?
    var plan: String = ""
    var snapshotAge: TimeInterval?
    var loaded = false
    var busy = false           // true while a force-refresh is running

    private var timer: Timer?
    private var alertedFive = false
    private var alertedWeek = false

    init() {
        Prefs.registerDefaults()
        if Bundle.main.bundleIdentifier != nil {   // skip when run as a bare binary (e.g. --shot)
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        refresh()
        restartTimer()
    }

    func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Prefs.interval), repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // ---- menu-bar title ----
    var menuBarTitle: String {
        guard let w = weekly ?? fiveHour else { return "◌ codex" }
        return "\(Self.glyph(w.remaining)) \(Int(w.remaining.rounded()))%"
    }
    var menuBarColor: Color? {
        let rems = [fiveHour?.remaining, weekly?.remaining].compactMap { $0 }
        guard let m = rems.min() else { return nil }
        return m < 30 ? Theme.status(m) : nil
    }
    static func glyph(_ r: Double) -> String {
        r >= 87 ? "●" : r >= 62 ? "◕" : r >= 37 ? "◑" : r >= 12 ? "◔" : "○"
    }

    // ---- passive refresh (free) ----
    func refresh() {
        guard let (rl, age) = Self.readLatest(path: Prefs.codexPath) else { return }
        snapshotAge = age
        plan = (rl["plan_type"] as? String) ?? ""
        fiveHour = Self.window(rl["primary"])
        weekly = Self.window(rl["secondary"])
        loaded = true
        checkAlerts()
    }

    // ---- active query (opt-in, spends a little quota) ----
    func forceRefresh() {
        guard !busy else { return }
        busy = true
        DispatchQueue.global().async { [weak self] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            p.arguments = ["-lc", "codex exec --skip-git-repo-check --sandbox read-only 'say ok' < /dev/null"]
            try? p.run()
            p.waitUntilExit()
            DispatchQueue.main.async {
                self?.busy = false
                self?.refresh()
            }
        }
    }

    private func checkAlerts() {
        guard Prefs.alertEnabled else { return }
        let s = Strings(UserDefaults.standard.string(forKey: LanguageKey) ?? "system")
        let th = Double(Prefs.threshold)
        if let r = fiveHour?.remaining {
            if r < th && !alertedFive {
                Self.notify(s("Codex 5-hour quota is low", "Codex 5 小时额度偏低"),
                            s("Only \(Int(r))% remaining", "只剩 \(Int(r))% 了"))
                alertedFive = true
            }
            if r >= th { alertedFive = false }
        }
        if let r = weekly?.remaining {
            if r < th && !alertedWeek {
                Self.notify(s("Codex weekly quota is low", "Codex 本周额度偏低"),
                            s("Only \(Int(r))% remaining", "只剩 \(Int(r))% 了"))
                alertedWeek = true
            }
            if r >= th { alertedWeek = false }
        }
    }

    static func notify(_ title: String, _ body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    // ---- parsing ----
    static func window(_ any: Any?) -> UsageWindow? {
        guard let d = any as? [String: Any] else { return nil }
        let used = (d["used_percent"] as? Double)
            ?? (d["used_percentage"] as? Double)
            ?? (d["utilization"] as? Double)
            ?? (d["used_percent"] as? Int).map(Double.init)
        guard let u = used else { return nil }
        var reset: Date?
        if let ra = d["resets_at"] as? Double { reset = Date(timeIntervalSince1970: ra) }
        else if let ra = d["resets_at"] as? Int { reset = Date(timeIntervalSince1970: Double(ra)) }
        return UsageWindow(remaining: max(0, min(100, 100 - u)), resetsAt: reset)
    }

    static func findRateLimits(_ obj: Any) -> [String: Any]? {
        if let d = obj as? [String: Any] {
            if let rl = d["rate_limits"] as? [String: Any],
               rl["primary"] != nil || rl["secondary"] != nil { return rl }
            for (_, v) in d { if let r = findRateLimits(v) { return r } }
        } else if let a = obj as? [Any] {
            for v in a { if let r = findRateLimits(v) { return r } }
        }
        return nil
    }

    static func readLatest(path: String) -> ([String: Any], TimeInterval)? {
        let base = (path as NSString).expandingTildeInPath
        let fm = FileManager.default
        guard let en = fm.enumerator(atPath: base) else { return nil }
        var files: [(String, Date)] = []
        for case let p as String in en where p.hasSuffix(".jsonl") && p.contains("rollout-") {
            let full = base + "/" + p
            if let attr = try? fm.attributesOfItem(atPath: full),
               let m = attr[.modificationDate] as? Date {
                files.append((full, m))
            }
        }
        files.sort { $0.1 > $1.1 }
        for (full, mdate) in files.prefix(8) {
            guard let content = try? String(contentsOf: URL(fileURLWithPath: full), encoding: .utf8) else { continue }
            var found: [String: Any]?
            for line in content.split(separator: "\n") where line.range(of: "rate_limits") != nil {
                if let data = line.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data),
                   let rl = findRateLimits(obj) { found = rl }
            }
            if let f = found { return (f, Date().timeIntervalSince(mdate)) }
        }
        return nil
    }
}
