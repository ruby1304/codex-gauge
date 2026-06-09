import SwiftUI
import AppKit

struct PopoverView: View {
    var model: UsageModel
    @AppStorage(Prefs.activeQueryKey) private var activeQueryEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(spacing: 16) {
                RingGauge(title: "5 小时窗", window: model.fiveHour)
                RingGauge(title: "本周窗", window: model.weekly)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            Divider().overlay(Theme.border).padding(.horizontal, 18).padding(.top, 16)
            footer
        }
        .frame(width: 296)
        .background(Theme.panel)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Codex")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.fg)
            if !model.plan.isEmpty {
                Text(model.plan)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.fg2)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Theme.track, in: Capsule())
            }
            Spacer()
            Text(ageText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.fg3)
            SettingsLink {
                Image(systemName: "gearshape").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.fg3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 15)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Button { model.refresh() } label: {
                    Label("刷新", systemImage: "arrow.clockwise").font(.system(size: 11.5))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.fg2)

                if activeQueryEnabled {
                    Button { model.forceRefresh() } label: {
                        if model.busy {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("强制查最新", systemImage: "bolt").font(.system(size: 11.5))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.warn)
                    .disabled(model.busy)
                    .help("让 Codex 真发一次请求取此刻精确值,会消耗一点点 5 小时额度")
                }

                Spacer()

                Link(destination: URL(string: "https://github.com/ruby1304/codex-gauge")!) {
                    Label("GitHub", systemImage: "arrow.up.right").font(.system(size: 11))
                }
                .foregroundStyle(Theme.fg3)

                Button { NSApp.terminate(nil) } label: {
                    Text("退出").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.fg3)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Text("零消耗 · 只读本地 session,不碰 token / 不发请求")
                .font(.system(size: 10))
                .foregroundStyle(Theme.fg3)
                .padding(.horizontal, 18)
                .padding(.bottom, 13)
        }
    }

    private var ageText: String {
        guard let a = model.snapshotAge else { return "—" }
        if a < 3600 { return "快照 \(Int(a / 60)) 分钟前" }
        if a < 86400 { return "快照 \(Int(a / 3600)) 小时前" }
        return "快照 \(Int(a / 86400)) 天前"
    }
}

struct RingGauge: View {
    let title: String
    let window: UsageWindow?

    var body: some View {
        let rem = window?.remaining
        let frac = (rem ?? 0) / 100
        let color = rem.map { Theme.status($0) } ?? Theme.fg3

        VStack(spacing: 9) {
            ZStack {
                Circle().stroke(Theme.track, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: frac)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.55), value: frac)
                VStack(spacing: 0) {
                    Text(rem != nil ? "\(Int(rem!.rounded()))" : "—")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.fg)
                    Text("剩 %")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.fg3)
                }
            }
            .frame(width: 90, height: 90)

            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.fg2)
            Text(resetText)
                .font(.system(size: 10))
                .foregroundStyle(Theme.fg3)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var resetText: String {
        guard let r = window?.resetsAt else { return " " }
        let dt = r.timeIntervalSinceNow
        if dt <= 0 { return "即将重置" }
        if dt < 3600 { return "\(Int(dt / 60)) 分后重置" }
        if dt < 86400 {
            let h = Int(dt / 3600)
            let m = Int(dt.truncatingRemainder(dividingBy: 3600) / 60)
            return "\(h)时\(m)分后重置"
        }
        return "\(Int(dt / 86400)) 天后重置"
    }
}
