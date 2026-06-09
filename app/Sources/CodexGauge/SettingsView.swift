import SwiftUI
import AppKit

struct SettingsView: View {
    var model: UsageModel

    @AppStorage(Prefs.codexPathKey)   private var codexPath = "~/.codex/sessions"
    @AppStorage(Prefs.intervalKey)    private var refreshInterval = 60
    @AppStorage(Prefs.thresholdKey)   private var lowThreshold = 10
    @AppStorage(Prefs.alertKey)       private var lowAlertEnabled = true
    @AppStorage(Prefs.activeQueryKey) private var activeQueryEnabled = false

    var body: some View {
        Form {
            Section("数据来源") {
                HStack(spacing: 8) {
                    TextField("Codex sessions 路径", text: $codexPath)
                        .textFieldStyle(.roundedBorder)
                    Button("选择…") { pick() }
                }
                Text("默认 ~/.codex/sessions。改完会立刻重新读取。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("刷新") {
                Picker("自动刷新间隔", selection: $refreshInterval) {
                    Text("30 秒").tag(30)
                    Text("1 分钟").tag(60)
                    Text("5 分钟").tag(300)
                    Text("15 分钟").tag(900)
                }
                .onChange(of: refreshInterval) { model.restartTimer() }
                Text("只是重读本地文件,频率高也零消耗。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("额度提醒") {
                Toggle("额度偏低时发系统通知", isOn: $lowAlertEnabled)
                Stepper("阈值:任一窗口剩 \(lowThreshold)% 时提醒", value: $lowThreshold, in: 5...50, step: 5)
                    .disabled(!lowAlertEnabled)
            }

            Section("主动查询(高级)") {
                Toggle("显示「强制查最新」按钮", isOn: $activeQueryEnabled)
                Text("⚠️ 强制查最新会让 Codex 真发一次请求、消耗一点点 5 小时额度。默认关闭——平时读本地快照就够,完全零消耗。只给确实需要「此刻精确值」的人。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("codex-gauge \(version)").foregroundStyle(.secondary)
                    Spacer()
                    Link("GitHub", destination: URL(string: "https://github.com/ruby1304/codex-gauge")!)
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 500)
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
