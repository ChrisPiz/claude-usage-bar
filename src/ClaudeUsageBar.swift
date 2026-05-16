import Cocoa
import UserNotifications

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

// MARK: — Claude Status
struct StatusComponent: Codable {
    let id: String
    let name: String
    let status: String
}

struct StatusIncident: Codable {
    let id: String
    let name: String
    let status: String
}

struct StatusAPIResponse: Codable {
    let components: [StatusComponent]
    let incidents: [StatusIncident]
}

struct ClaudeStatus {
    let components: [StatusComponent]
    let incidents: [StatusIncident]
    let fetchedAt: Date
    var hasIssue: Bool {
        !incidents.isEmpty || components.contains { $0.status != "operational" }
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
let claudeCodeIconColor = NSColor(calibratedRed: 217.0 / 255.0, green: 119.0 / 255.0, blue: 87.0 / 255.0, alpha: 1.0)

func shellQuoted(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
}

func ansiForPct(_ pct: Double) -> String {
    if pct < 70 { return "\u{001B}[38;5;82m" }
    if pct < 90 { return "\u{001B}[38;5;214m" }
    return "\u{001B}[38;5;196m"
}

func pctText(_ limit: Limit) -> String {
    "\(effectiveUsedPercentage(limit))"
}

func effectiveUsedPercentage(_ limit: Limit, now: Int = Int(Date().timeIntervalSince1970)) -> Int {
    if let resetsAt = limit.resetsAt, resetsAt <= now {
        return 0
    }
    return Int(limit.usedPercentage)
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
    if ProcessInfo.processInfo.environment["CLAUDE_USAGE_BAR_PRINT_STATUSLINE"] == "1", !output.isEmpty {
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

func makeClaudeCodeIconPath() -> NSBezierPath {
    let path = NSBezierPath()
    path.windingRule = .evenOdd

    path.move(to: NSPoint(x: 20.998, y: 10.949))
    path.line(to: NSPoint(x: 24.0, y: 10.949))
    path.line(to: NSPoint(x: 24.0, y: 14.051))
    path.line(to: NSPoint(x: 21.0, y: 14.051))
    path.line(to: NSPoint(x: 21.0, y: 17.079))
    path.line(to: NSPoint(x: 19.513, y: 17.079))
    path.line(to: NSPoint(x: 19.513, y: 20.0))
    path.line(to: NSPoint(x: 18.0, y: 20.0))
    path.line(to: NSPoint(x: 18.0, y: 17.079))
    path.line(to: NSPoint(x: 16.513, y: 17.079))
    path.line(to: NSPoint(x: 16.513, y: 20.0))
    path.line(to: NSPoint(x: 15.0, y: 20.0))
    path.line(to: NSPoint(x: 15.0, y: 17.079))
    path.line(to: NSPoint(x: 9.0, y: 17.079))
    path.line(to: NSPoint(x: 9.0, y: 20.0))
    path.line(to: NSPoint(x: 7.488, y: 20.0))
    path.line(to: NSPoint(x: 7.488, y: 17.079))
    path.line(to: NSPoint(x: 6.0, y: 17.079))
    path.line(to: NSPoint(x: 6.0, y: 20.0))
    path.line(to: NSPoint(x: 4.487, y: 20.0))
    path.line(to: NSPoint(x: 4.487, y: 17.079))
    path.line(to: NSPoint(x: 3.0, y: 17.079))
    path.line(to: NSPoint(x: 3.0, y: 14.05))
    path.line(to: NSPoint(x: 0.0, y: 14.05))
    path.line(to: NSPoint(x: 0.0, y: 10.95))
    path.line(to: NSPoint(x: 3.0, y: 10.95))
    path.line(to: NSPoint(x: 3.0, y: 5.0))
    path.line(to: NSPoint(x: 20.998, y: 5.0))
    path.close()

    path.move(to: NSPoint(x: 6.0, y: 10.949))
    path.line(to: NSPoint(x: 7.488, y: 10.949))
    path.line(to: NSPoint(x: 7.488, y: 8.102))
    path.line(to: NSPoint(x: 6.0, y: 8.102))
    path.close()

    path.move(to: NSPoint(x: 16.51, y: 10.949))
    path.line(to: NSPoint(x: 18.0, y: 10.949))
    path.line(to: NSPoint(x: 18.0, y: 8.102))
    path.line(to: NSPoint(x: 16.51, y: 8.102))
    path.close()

    return path
}

func makeClaudeCodeIcon(size: CGFloat, template: Bool = false) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext.current?.cgContext else {
            NSGraphicsContext.restoreGraphicsState()
            return false
        }

        context.translateBy(x: rect.minX, y: rect.minY + rect.height)
        context.scaleBy(x: rect.width / 24.0, y: -rect.height / 24.0)
        claudeCodeIconColor.setFill()
        makeClaudeCodeIconPath().fill()
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
    image.isTemplate = template
    return image
}

func makeStatusBadgedIcon(size: CGFloat) -> NSImage {
    let base = makeClaudeCodeIcon(size: size)
    let result = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        base.draw(in: rect)
        let dotSize: CGFloat = 6
        let dotRect = NSRect(x: rect.maxX - dotSize, y: rect.maxY - dotSize,
                             width: dotSize, height: dotSize)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        return true
    }
    return result
}

// MARK: — i18n
struct L {
    let heading, session, weekly, weeklySonnet, resets, updated, refresh, close, noData, noDataSub, stale: String
    let statusHeading, operational, degraded, outage, alertsToggle, statusLoading: String
    static func detect() -> L {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "es": return L(heading:"Claude Code — Límites de uso",session:"Sesión (5h)",weekly:"Semana (todo)",weeklySonnet:"Semana (Sonnet)",resets:"↻",updated:"Actualizado",refresh:"Actualizar",close:"Cerrar",noData:"Sin datos de uso",noDataSub:"Envía un mensaje en Claude Code",stale:" (desactualizado)",statusHeading:"Sistema Claude",operational:"Operacional",degraded:"Degradado",outage:"Interrumpido",alertsToggle:"Alertas de incidentes",statusLoading:"Obteniendo estado...")
        case "pt": return L(heading:"Claude Code — Limites de uso",session:"Sessão (5h)",weekly:"Semana (tudo)",weeklySonnet:"Semana (Sonnet)",resets:"↻",updated:"Atualizado",refresh:"Atualizar",close:"Fechar",noData:"Sem dados de uso",noDataSub:"Envie uma mensagem no Claude Code",stale:" (desatualizado)",statusHeading:"Status Claude",operational:"Operacional",degraded:"Degradado",outage:"Interrompido",alertsToggle:"Alertas de incidentes",statusLoading:"Obtendo status...")
        case "fr": return L(heading:"Claude Code — Limites d'utilisation",session:"Session (5h)",weekly:"Semaine (tout)",weeklySonnet:"Semaine (Sonnet)",resets:"↻",updated:"Mis à jour",refresh:"Actualiser",close:"Fermer",noData:"Aucune donnée",noDataSub:"Envoyez un message dans Claude Code",stale:" (périmé)",statusHeading:"Statut Claude",operational:"Opérationnel",degraded:"Dégradé",outage:"Panne",alertsToggle:"Alertes d'incidents",statusLoading:"Chargement...")
        case "de": return L(heading:"Claude Code — Nutzungslimits",session:"Sitzung (5h)",weekly:"Woche (alle)",weeklySonnet:"Woche (Sonnet)",resets:"↻",updated:"Aktualisiert",refresh:"Aktualisieren",close:"Schließen",noData:"Keine Daten",noDataSub:"Sende eine Nachricht in Claude Code",stale:" (veraltet)",statusHeading:"Claude-Status",operational:"Betriebsbereit",degraded:"Beeinträchtigt",outage:"Ausfall",alertsToggle:"Störungsmeldungen",statusLoading:"Wird geladen...")
        default:   return L(heading:"Claude Code — Usage Limits",session:"Session (5h)",weekly:"Weekly (all)",weeklySonnet:"Weekly (Sonnet)",resets:"↻",updated:"Updated",refresh:"Refresh",close:"Close",noData:"No usage data yet",noDataSub:"Send a message in Claude Code",stale:" (stale)",statusHeading:"Claude System Status",operational:"Operational",degraded:"Degraded",outage:"Outage",alertsToggle:"Incident Alerts",statusLoading:"Fetching status...")
        }
    }
}

// MARK: — App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var setupStatus: SetupStatus = .failed
    var aboutWindow: NSWindow?
    let stateFile = stateFilePath
    var statusTimer: Timer?
    var claudeStatus: ClaudeStatus?
    let statusFetchURL = URL(string: "https://status.claude.com/api/v2/summary.json")!
    var isFetchingStatus = false

    func applicationDidFinishLaunching(_ n: Notification) {
        setupStatus = configureClaudeStatusLine()
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = makeClaudeCodeIcon(size: 18)
            btn.imagePosition = .imageLeft
            btn.title = " --"
        }
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.update()
        }
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted {
                DispatchQueue.main.async {
                    UserDefaults.standard.set(false, forKey: "statusAlertsEnabled")
                }
            }
        }
        fetchClaudeStatus()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchClaudeStatus()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let s = claudeStatus, Date().timeIntervalSince(s.fetchedAt) > 300 {
            fetchClaudeStatus()
        }
        update()
    }

    func update() {
        let l = L.detect()
        if let btn = statusItem.button {
            btn.image = (claudeStatus?.hasIssue == true)
                ? makeStatusBadgedIcon(size: 18)
                : makeClaudeCodeIcon(size: 18)
        }
        let m = NSMenu()
        m.delegate = self

        m.addHeader(l.heading)
        m.addItem(.separator())
        addSetupStatus(to: m)

        // Status section
        m.addHeader(l.statusHeading)
        if let cs = claudeStatus {
            for comp in cs.components {
                m.addStatusRow(comp.name, status: comp.status,
                               operational: l.operational,
                               degraded: l.degraded,
                               outage: l.outage)
            }
            for incident in cs.incidents {
                m.addPlain("↳ \(incident.name)", size: 11, gray: true, indent: 30)
            }
        } else {
            m.addPlain(l.statusLoading, size: 11, gray: true)
        }
        let alertsOn = UserDefaults.standard.object(forKey: "statusAlertsEnabled") as? Bool ?? true
        let alertsItem = NSMenuItem(title: l.alertsToggle, action: #selector(toggleAlerts), keyEquivalent: "")
        alertsItem.target = self
        alertsItem.state = alertsOn ? .on : .off
        m.addItem(alertsItem)
        m.addItem(.separator())

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
            statusItem.button?.title = " \(effectiveUsedPercentage(f, now: now))%\(stale)"
        } else {
            statusItem.button?.title = " --\(stale)"
        }

        if let f = fh {
            m.addRow(l.session, value: "\(effectiveUsedPercentage(f, now: now))%", symbol: "clock")
            if let ts = f.resetsAt { m.addPlain("\(l.resets) \(fmt(ts))", size: 11, gray: true) }
        }
        if let s = sd {
            m.addRow(l.weekly, value: "\(effectiveUsedPercentage(s, now: now))%", symbol: "calendar")
            if let ts = s.resetsAt { m.addPlain("\(l.resets) \(fmt(ts))", size: 11, gray: true) }
        }
        if let ss = sds {
            m.addRow(l.weeklySonnet, value: "\(effectiveUsedPercentage(ss, now: now))%", symbol: "sparkles")
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

    func fetchClaudeStatus() {
        guard !isFetchingStatus else { return }
        isFetchingStatus = true
        let task = URLSession.shared.dataTask(with: statusFetchURL) { [weak self] data, _, error in
            guard let self, let data, error == nil,
                  let response = try? JSONDecoder().decode(StatusAPIResponse.self, from: data)
            else {
                DispatchQueue.main.async { self?.isFetchingStatus = false }
                return
            }

            let filtered = response.components.filter {
                $0.name.contains("Claude Code") || $0.name.contains("Claude API")
            }
            let active = response.incidents.filter { $0.status != "resolved" }
            let newStatus = ClaudeStatus(components: filtered, incidents: active, fetchedAt: Date())

            let defaults = UserDefaults.standard
            let seen = defaults.stringArray(forKey: "seenIncidentIDs") ?? []
            let alertsOn = defaults.object(forKey: "statusAlertsEnabled") as? Bool ?? true

            let unseen = active.filter { !seen.contains($0.id) }
            if alertsOn && !unseen.isEmpty {
                for incident in unseen {
                    let content = UNMutableNotificationContent()
                    content.title = L.detect().statusHeading
                    content.body = incident.name
                    content.sound = .default
                    let req = UNNotificationRequest(
                        identifier: "claude-incident-\(incident.id)",
                        content: content,
                        trigger: nil
                    )
                    UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
                }
            }
            let activeIDs = active.map(\.id)
            let allSeen = Array(Set(seen + unseen.map(\.id)).intersection(activeIDs))
            defaults.set(allSeen, forKey: "seenIncidentIDs")

            DispatchQueue.main.async {
                self.isFetchingStatus = false
                self.claudeStatus = newStatus
                self.update()
            }
        }
        task.resume()
    }

    @objc func toggleAlerts() {
        let defaults = UserDefaults.standard
        let current = defaults.object(forKey: "statusAlertsEnabled") as? Bool ?? true
        defaults.set(!current, forKey: "statusAlertsEnabled")
        update()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
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

        let iconView = NSImageView(frame: NSRect(x: 54, y: 78, width: 128, height: 128))
        iconView.image = makeClaudeCodeIcon(size: 128)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        content.addSubview(iconView)

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

    func addStatusRow(_ label: String, status: String, operational: String, degraded: String, outage: String) {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 22))

        let (symName, color): (String, NSColor)
        switch status {
        case "operational":
            symName = "checkmark.circle"; color = .systemGreen
        case "degraded_performance":
            symName = "exclamationmark.triangle"; color = .systemYellow
        default:
            symName = "xmark.circle"; color = .systemRed
        }

        let statusText: String
        switch status {
        case "operational":         statusText = operational
        case "degraded_performance": statusText = degraded
        default:                    statusText = outage
        }

        if let img = NSImage(systemSymbolName: symName, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let colored = img.withSymbolConfiguration(cfg)
            let iv = NSImageView(frame: NSRect(x: 8, y: 3, width: 16, height: 16))
            iv.image = colored
            iv.contentTintColor = color
            view.addSubview(iv)
        }

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        lbl.frame = NSRect(x: 30, y: 2, width: 140, height: 18)
        view.addSubview(lbl)

        let val = NSTextField(labelWithString: statusText)
        val.font = .systemFont(ofSize: 13)
        val.textColor = .secondaryLabelColor
        val.alignment = .right
        val.frame = NSRect(x: 170, y: 2, width: 66, height: 18)
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
