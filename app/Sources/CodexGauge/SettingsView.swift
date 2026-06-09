import SwiftUI
import AppKit

struct SettingsView: View {
    var model: UsageModel

    @AppStorage(Prefs.codexPathKey)   private var codexPath = "~/.codex/sessions"
    @AppStorage(Prefs.intervalKey)    private var refreshInterval = 60
    @AppStorage(Prefs.thresholdKey)   private var lowThreshold = 10
    @AppStorage(Prefs.alertKey)       private var lowAlertEnabled = true
    @AppStorage(Prefs.activeQueryKey) private var activeQueryEnabled = false
    @AppStorage(LanguageKey)          private var lang = "en"

    private var t: Strings { Strings(lang) }

    var body: some View {
        Form {
            Section(t("Data Source", "数据来源")) {
                HStack(spacing: 8) {
                    TextField(t("Codex sessions folder", "Codex 会话文件夹"), text: $codexPath)
                        .textFieldStyle(.roundedBorder)
                    Button(t("Choose…", "选取…")) { pick() }
                }
                Text(t("Default is ~/.codex/sessions. Changes take effect immediately.",
                       "默认为 ~/.codex/sessions,更改即时生效。"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(t("Auto-Refresh", "自动刷新")) {
                Picker(t("Refresh every", "刷新频率"), selection: $refreshInterval) {
                    Text(t("30 seconds", "30 秒")).tag(30)
                    Text(t("1 minute", "1 分钟")).tag(60)
                    Text(t("5 minutes", "5 分钟")).tag(300)
                    Text(t("15 minutes", "15 分钟")).tag(900)
                }
                .onChange(of: refreshInterval) { model.restartTimer() }
                Text(t("Re-reads local files only — free at any interval.",
                       "仅重新读取本地文件——任何频率均无消耗。"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(t("Alerts", "提醒")) {
                Toggle(t("Notify me when usage runs low", "用量不足时通知我"), isOn: $lowAlertEnabled)
                Picker(t("Alert threshold", "提醒阈值"), selection: $lowThreshold) {
                    ForEach([5, 10, 15, 20, 25, 30, 40, 50], id: \.self) { Text("\($0)%").tag($0) }
                }
                .disabled(!lowAlertEnabled)
                Text(t("Notifies you when either window drops to this level.",
                       "任一时段用量降到该比例时通知你。"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(t("Active Query (Advanced)", "主动查询(高级)")) {
                Toggle(t("Show “Force Refresh” button", "显示“强制刷新”按钮"), isOn: $activeQueryEnabled)
                Text(t("Sends one real request to Codex, spending a small amount of your 5-hour quota. Off by default — the local snapshot is free and sufficient.",
                       "会向 Codex 发送一次真实请求,消耗少量 5 小时配额。默认关闭——本地快照免费且足够。"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(t("Language", "语言")) {
                Picker(t("Language", "语言"), selection: $lang) {
                    Text(t("System", "跟随系统")).tag("system")
                    Text("English").tag("en")
                    Text("中文").tag("zh")
                }
            }

            Section {
                HStack {
                    Text("Codex Gauge \(version)").foregroundStyle(.secondary)
                    Spacer()
                    Link("GitHub", destination: URL(string: "https://github.com/ruby1304/codex-gauge")!)
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 540)
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: (codexPath as NSString).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            codexPath = url.path
            model.refresh()
        }
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
