import SwiftUI
import AppKit

// "--shot <path>" renders the popover to a PNG (for the README hero) and exits.
// Otherwise launches the normal menu-bar app.
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--shot"), i + 1 < args.count {
    let path = args[i + 1]
    UserDefaults.standard.set("en", forKey: LanguageKey)   // render the hero screenshot in English
    _ = NSApplication.shared
    MainActor.assumeIsolated {
        let model = UsageModel()
        // representative demo data for the hero screenshot
        model.plan = "Plus"
        model.snapshotAge = 60
        model.fiveHour = UsageWindow(remaining: 86, resetsAt: Date().addingTimeInterval(2 * 3600 + 40 * 60))
        model.weekly = UsageWindow(remaining: 71, resetsAt: Date().addingTimeInterval(4 * 86400))
        let view = PopoverView(model: model).background(Theme.panel)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let img = renderer.nsImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
            print("wrote \(path)  size=\(img.size)")
        } else {
            print("render failed")
        }
    }
    exit(0)
}

CodexGaugeApp.main()
