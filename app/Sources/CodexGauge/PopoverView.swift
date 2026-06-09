import SwiftUI
import AppKit

struct PopoverView: View {
    var model: UsageModel
    @AppStorage(Prefs.activeQueryKey) private var activeQueryEnabled = false
    @AppStorage(LanguageKey) private var lang = "en"
    @Environment(\.openSettings) private var openSettings

    private var t: Strings { Strings(lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(spacing: 16) {
                RingGauge(title: t("5-Hour", "5 小时"), window: model.fiveHour, t: t)
                RingGauge(title: t("Weekly", "每周"), window: model.weekly, t: t)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            Divider().overlay(Theme.border).padding(.horizontal, 18).padding(.top, 16)
            footer
        }
        .frame(width: 300)
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
            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
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
                    Label(t("Refresh", "刷新"), systemImage: "arrow.clockwise").font(.system(size: 11.5))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.fg2)

                if activeQueryEnabled {
                    Button { model.forceRefresh() } label: {
                        if model.busy {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(t("Force Refresh", "强制刷新"), systemImage: "bolt").font(.system(size: 11.5))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.warn)
                    .disabled(model.busy)
                }

                Spacer()

                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/ruby1304/codex-gauge")!)
                } label: {
                    Label("GitHub", systemImage: "arrow.up.right").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.fg3)

                Button { NSApp.terminate(nil) } label: {
                    Text(t("Quit", "退出")).font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.fg3)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Text(t("Reads local files only. Never your token, never the network.",
                   "仅读取本地文件。不触及令牌,不连接网络。"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.fg3)
                .padding(.horizontal, 18)
                .padding(.bottom, 13)
        }
    }

    private var ageText: String {
        guard let a = model.snapshotAge else { return "" }
        let rel: String
        if a < 3600 { rel = "\(Int(a / 60))m" }
        else if a < 86400 { rel = "\(Int(a / 3600))h" }
        else { rel = "\(Int(a / 86400))d" }
        return t("Updated \(rel) ago", "\(rel)前更新")
    }
}

struct RingGauge: View {
    let title: String
    let window: UsageWindow?
    let t: Strings

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
                    Text(t("remaining", "剩余"))
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
        if dt <= 0 { return t("Resetting…", "重置中…") }
        let span: String
        if dt < 3600 { span = "\(Int(dt / 60))m" }
        else if dt < 86400 {
            let h = Int(dt / 3600), m = Int(dt.truncatingRemainder(dividingBy: 3600) / 60)
            span = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else { span = "\(Int(dt / 86400))d" }
        return t("Resets in \(span)", "\(span)后重置")
    }
}
