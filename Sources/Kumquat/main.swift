import AppKit

// `--render-screenshots <dir>` draws the README images and exits.
if let i = CommandLine.arguments.firstIndex(of: "--render-screenshots"), CommandLine.arguments.count > i + 1 {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    MainActor.assumeIsolated {
        ScreenshotRenderer.renderAll(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--render-ui"), CommandLine.arguments.count > i + 2 {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    MainActor.assumeIsolated {
        ScreenshotRenderer.renderUI(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]),
                                    sample: URL(fileURLWithPath: CommandLine.arguments[i + 2]))
    }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--render-rings"), CommandLine.arguments.count > i + 1 {
    NSApplication.shared.setActivationPolicy(.prohibited)
    MainActor.assumeIsolated { ScreenshotRenderer.renderRings(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) }
    exit(0)
}

// `kumquat convert …` and friends run as a command-line tool.
if CommandLine.arguments.count > 1, CLI.commands.contains(CommandLine.arguments[1]) {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    Task { @MainActor in
        let code = await CLI.run(CommandLine.arguments)
        if code != CLI.keepRunning { exit(code) }
    }
    RunLoop.main.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
