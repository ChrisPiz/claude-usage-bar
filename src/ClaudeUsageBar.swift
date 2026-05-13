import Cocoa

// MARK: — State
struct Limit: Codable {
    let usedPercentage: Double
    let resetsAt: Int?
    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt       = "resets_at"
    }
}
struct RateLimits: Codable {
    let fiveHour:       Limit?
    let sevenDay:       Limit?
    let sevenDaySonnet: Limit?
    enum CodingKeys: String, CodingKey {
        case fiveHour       = "five_hour"
        case sevenDay       = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}
struct UsageState: Codable {
    let updatedAt:  Int
    let rateLimits: RateLimits?
    enum CodingKeys: String, CodingKey {
        case updatedAt  = "updated_at"
        case rateLimits = "rate_limits"
    }
}

struct StatusLineInput: Codable {
    let rateLimits: RateLimits?
    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
    }
}

enum SetupStatus {
    case configured
    case customStatusLine
    case moveToApplications
    case failed
}

let appName = "ClaudeUsageBar"
let homeDirectoryPath = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
let stateFilePath = homeDirectoryPath + "/.claude/.claude-usage-state.json"

func shellQuoted(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
}

func ansiForPct(_ pct: Double) -> String {
    if pct < 70 { return "\u{001B}[38;5;82m" }
    if pct < 90 { return "\u{001B}[38;5;214m" }
    return "\u{001B}[38;5;196m"
}

func pctText(_ limit: Limit) -> String {
    "\(Int(limit.usedPercentage))"
}

func renderStatusLine() {
    let inputData = FileHandle.standardInput.readDataToEndOfFile()
    guard !inputData.isEmpty,
          let payload = try? JSONDecoder().decode(StatusLineInput.self, from: inputData),
          let limits = payload.rateLimits,
          limits.fiveHour != nil || limits.sevenDay != nil else {
        return
    }

    var parts: [String] = []
    let reset = "\u{001B}[0m"

    if let limit = limits.fiveHour {
        let pct = pctText(limit)
        parts.append("\(ansiForPct(limit.usedPercentage))5h:\(pct)%\(reset)")
    }
    if let limit = limits.sevenDay {
        let pct = pctText(limit)
        parts.append("\(ansiForPct(limit.usedPercentage))7d:\(pct)%\(reset)")
    }
    if let limit = limits.sevenDaySonnet {
        let pct = pctText(limit)
        parts.append("\(ansiForPct(limit.usedPercentage))7dS:\(pct)%\(reset)")
    }

    var prefix = ""
    let cavemanPath = homeDirectoryPath + "/.claude/.caveman-active"
    if let mode = try? String(contentsOfFile: cavemanPath, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines) {
        if mode.isEmpty || mode == "full" {
            prefix = "\u{001B}[38;5;172m[CAVEMAN]\(reset)"
        } else {
            prefix = "\u{001B}[38;5;172m[CAVEMAN:\(mode.uppercased())]\(reset)"
        }
    }

    let output = ([prefix] + parts).filter { !$0.isEmpty }.joined(separator: "  ")
    if !output.isEmpty {
        print(output)
    }

    let state = UsageState(updatedAt: Int(Date().timeIntervalSince1970), rateLimits: limits)
    do {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: homeDirectoryPath + "/.claude"),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: URL(fileURLWithPath: stateFilePath), options: .atomic)
    } catch {
        // Statusline rendering should not fail just because state persistence failed.
    }
}

func configureClaudeStatusLine() -> SetupStatus {
    guard let executablePath = Bundle.main.executablePath else {
        return .failed
    }
    if executablePath.hasPrefix("/Volumes/") {
        return .moveToApplications
    }

    let claudeDir = URL(fileURLWithPath: homeDirectoryPath).appendingPathComponent(".claude")
    let settingsURL = claudeDir.appendingPathComponent("settings.json")
    let command = "\(shellQuoted(executablePath)) --statusline"

    do {
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            let data = try Data(contentsOf: settingsURL)
            if !data.isEmpty {
                settings = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }
        }

        let currentCommand: String
        if let statusLine = settings["statusLine"] as? [String: Any] {
            currentCommand = statusLine["command"] as? String ?? ""
        } else {
            currentCommand = settings["statusLine"] as? String ?? ""
        }

        if !currentCommand.isEmpty
            && !currentCommand.contains(appName)
            && !currentCommand.contains("usage-statusline.sh")
            && !currentCommand.contains("claude-usage-bar") {
            return .customStatusLine
        }

        settings["statusLine"] = [
            "type": "command",
            "command": command
        ]

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: settingsURL, options: .atomic)
        return .configured
    } catch {
        return .failed
    }
}

// MARK: — i18n
struct L {
    let heading, session, weekly, weeklySonnet, resets, updated, refresh, close, noData, noDataSub, stale: String
    static func detect() -> L {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "es": return L(heading:"Claude Code — Límites de uso",session:"Sesión (5h)",weekly:"Semana (todo)",weeklySonnet:"Semana (Sonnet)",resets:"↻",updated:"Actualizado",refresh:"Actualizar",close:"Cerrar",noData:"Sin datos de uso",noDataSub:"Envía un mensaje en Claude Code",stale:" (desactualizado)")
        case "pt": return L(heading:"Claude Code — Limites de uso",session:"Sessão (5h)",weekly:"Semana (tudo)",weeklySonnet:"Semana (Sonnet)",resets:"↻",updated:"Atualizado",refresh:"Atualizar",close:"Fechar",noData:"Sem dados de uso",noDataSub:"Envie uma mensagem no Claude Code",stale:" (desatualizado)")
        case "fr": return L(heading:"Claude Code — Limites d'utilisation",session:"Session (5h)",weekly:"Semaine (tout)",weeklySonnet:"Semaine (Sonnet)",resets:"↻",updated:"Mis à jour",refresh:"Actualiser",close:"Fermer",noData:"Aucune donnée",noDataSub:"Envoyez un message dans Claude Code",stale:" (périmé)")
        case "de": return L(heading:"Claude Code — Nutzungslimits",session:"Sitzung (5h)",weekly:"Woche (alle)",weeklySonnet:"Woche (Sonnet)",resets:"↻",updated:"Aktualisiert",refresh:"Aktualisieren",close:"Schließen",noData:"Keine Daten",noDataSub:"Sende eine Nachricht in Claude Code",stale:" (veraltet)")
        default:   return L(heading:"Claude Code — Usage Limits",session:"Session (5h)",weekly:"Weekly (all)",weeklySonnet:"Weekly (Sonnet)",resets:"↻",updated:"Updated",refresh:"Refresh",close:"Close",noData:"No usage data yet",noDataSub:"Send a message in Claude Code",stale:" (stale)")
        }
    }
}

// MARK: — App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var setupStatus: SetupStatus = .failed
    var aboutWindow: NSWindow?
    let stateFile = stateFilePath
    let iconB64 = "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"

    func applicationDidFinishLaunching(_ n: Notification) {
        setupStatus = configureClaudeStatusLine()
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            if let data = Data(base64Encoded: iconB64), let img = NSImage(data: data) {
                img.isTemplate = true
                img.size = NSSize(width: 18, height: 18)
                btn.image = img
                btn.imagePosition = .imageLeft
            }
            btn.title = " --"
        }
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) { update() }

    func update() {
        let l = L.detect()
        let m = NSMenu()
        m.delegate = self

        m.addHeader(l.heading)
        m.addItem(.separator())
        addSetupStatus(to: m)

        guard let raw   = FileManager.default.contents(atPath: stateFile),
              let state = try? JSONDecoder().decode(UsageState.self, from: raw) else {
            statusItem.button?.title = " --"
            m.addRow(l.noData, value: "—", symbol: "exclamationmark.circle")
            m.addPlain(l.noDataSub, size: 11, gray: true)
            m.addItem(.separator())
            m.addPlain("About ClaudeUsageBar...", sel: #selector(showAbout), target: self)
            m.addPlain(l.refresh, sel: #selector(doRefresh), target: self)
            statusItem.menu = m
            return
        }

        let now   = Int(Date().timeIntervalSince1970)
        let stale = (now - state.updatedAt) > 21600 ? l.stale : ""
        let fh    = state.rateLimits?.fiveHour
        let sd    = state.rateLimits?.sevenDay
        let sds   = state.rateLimits?.sevenDaySonnet

        if let f = fh {
            statusItem.button?.title = " \(Int(f.usedPercentage))%\(stale)"
        } else {
            statusItem.button?.title = " --\(stale)"
        }

        if let f = fh {
            m.addRow(l.session, value: "\(Int(f.usedPercentage))%", symbol: "clock")
            if let ts = f.resetsAt { m.addPlain("\(l.resets) \(fmt(ts))", size: 11, gray: true) }
        }
        if let s = sd {
            m.addRow(l.weekly, value: "\(Int(s.usedPercentage))%", symbol: "calendar")
            if let ts = s.resetsAt { m.addPlain("\(l.resets) \(fmt(ts))", size: 11, gray: true) }
        }
        if let ss = sds {
            m.addRow(l.weeklySonnet, value: "\(Int(ss.usedPercentage))%", symbol: "sparkles")
        }

        m.addItem(.separator())
        m.addPlain("\(l.updated) \(fmt(state.updatedAt))", size: 11, gray: true)
        m.addItem(.separator())
        m.addPlain("About ClaudeUsageBar...", sel: #selector(showAbout), target: self)
        m.addPlain(l.refresh, sel: #selector(doRefresh), target: self)
        m.addPlain(l.close,   sel: #selector(doClose),   target: self)

        statusItem.menu = m
    }

    func fmt(_ ts: Int) -> String {
        let d = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = DateFormatter()
        f.dateFormat = "MMM d HH:mm"
        return f.string(from: d)
    }

    @objc func doRefresh() { update() }
    @objc func doClose()   { NSApp.terminate(nil) }

    @objc func showAbout() {
        if let window = aboutWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About ClaudeUsageBar"
        window.isReleasedWhenClosed = false
        window.center()

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 280))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        if let data = Data(base64Encoded: iconB64), let image = NSImage(data: data) {
            image.size = NSSize(width: 128, height: 128)
            let iconView = NSImageView(frame: NSRect(x: 54, y: 78, width: 128, height: 128))
            iconView.image = image
            iconView.imageScaling = .scaleProportionallyUpOrDown
            content.addSubview(iconView)
        }

        let title = NSTextField(labelWithString: "ClaudeUsageBar")
        title.font = .systemFont(ofSize: 40, weight: .regular)
        title.textColor = .labelColor
        title.frame = NSRect(x: 232, y: 182, width: 390, height: 52)
        content.addSubview(title)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = .systemFont(ofSize: 19)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 235, y: 148, width: 390, height: 26)
        content.addSubview(versionLabel)

        let developer = NSTextField(labelWithString: "Developed by ChrisPiz")
        developer.font = .systemFont(ofSize: 15)
        developer.textColor = .labelColor
        developer.frame = NSRect(x: 235, y: 112, width: 390, height: 22)
        content.addSubview(developer)

        let github = NSButton(title: "github.com/ChrisPiz/Claude-Code-Usage-Bar", target: self, action: #selector(openGitHub))
        github.bezelStyle = .inline
        github.isBordered = false
        github.alignment = .left
        github.contentTintColor = .linkColor
        github.frame = NSRect(x: 231, y: 82, width: 390, height: 24)
        content.addSubview(github)

        let disclaimer = NSTextField(labelWithString: "Independent project. Not affiliated with, endorsed by, or sponsored by Anthropic, Claude, or Claude Code.")
        disclaimer.font = .systemFont(ofSize: 11)
        disclaimer.textColor = .secondaryLabelColor
        disclaimer.frame = NSRect(x: 235, y: 42, width: 390, height: 34)
        disclaimer.lineBreakMode = .byWordWrapping
        disclaimer.maximumNumberOfLines = 2
        content.addSubview(disclaimer)

        window.contentView = content
        aboutWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func openGitHub() {
        if let url = URL(string: "https://github.com/ChrisPiz/Claude-Code-Usage-Bar") {
            NSWorkspace.shared.open(url)
        }
    }

    func addSetupStatus(to menu: NSMenu) {
        switch setupStatus {
        case .configured:
            return
        case .customStatusLine:
            menu.addPlain("Custom Claude Code statusLine detected", size: 11, gray: true)
            menu.addPlain("Not changed automatically", size: 11, gray: true)
            menu.addItem(.separator())
        case .moveToApplications:
            menu.addPlain("Move ClaudeUsageBar to Applications", size: 11, gray: true)
            menu.addPlain("Then reopen it to finish setup", size: 11, gray: true)
            menu.addItem(.separator())
        case .failed:
            menu.addPlain("Could not configure Claude Code", size: 11, gray: true)
            menu.addItem(.separator())
        }
    }
}

// MARK: — NSMenu helpers
// item.view bypasses macOS disabled-item graying AND hover-highlight for static rows.
// Interactive items (Refresh / Close) keep standard NSMenuItem rendering.
extension NSMenu {
    func addHeader(_ title: String) {
        let item = NSMenuItem()
        item.view = staticView(title, size: 13, bold: true)
        addItem(item)
    }

    func addRow(_ label: String, value: String, symbol: String? = nil) {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 22))

        var leadX: CGFloat = 14
        if let sym = symbol,
           let img = NSImage(systemSymbolName: sym, accessibilityDescription: nil),
           let cfg = img.withSymbolConfiguration(
               NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)) {
            let iv = NSImageView(frame: NSRect(x: 8, y: 3, width: 16, height: 16))
            iv.image = cfg
            view.addSubview(iv)
            leadX = 30
        }

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        lbl.frame = NSRect(x: leadX, y: 2, width: 160, height: 18)
        view.addSubview(lbl)

        let val = NSTextField(labelWithString: value)
        val.font = .systemFont(ofSize: 13)
        val.textColor = .labelColor
        val.alignment = .right
        val.frame = NSRect(x: 190, y: 2, width: 46, height: 18)
        view.addSubview(val)

        item.view = view
        addItem(item)
    }

    func addPlain(_ title: String, sel: Selector? = nil, target: AnyObject? = nil,
                  size: CGFloat = 13, gray: Bool = false, indent: CGFloat = 20) {
        if let sel = sel {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            item.target = target
            addItem(item)
        } else {
            let item = NSMenuItem()
            item.view = staticView(title, size: size, gray: gray, indent: indent)
            addItem(item)
        }
    }

    private func staticView(_ text: String, size: CGFloat = 13, bold: Bool = false,
                             gray: Bool = false, indent: CGFloat = 14) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: size < 12 ? 18 : 22))
        let lbl = NSTextField(labelWithString: text)
        lbl.font = bold ? .systemFont(ofSize: size, weight: .semibold) : .systemFont(ofSize: size)
        lbl.textColor = gray ? .secondaryLabelColor : .labelColor
        lbl.frame = NSRect(x: indent, y: 1, width: 220, height: size < 12 ? 16 : 18)
        view.addSubview(lbl)
        return view
    }
}

if CommandLine.arguments.contains("--statusline") {
    renderStatusLine()
    exit(0)
}

let app = NSApplication.shared
let del = AppDelegate()
app.delegate = del
app.run()
