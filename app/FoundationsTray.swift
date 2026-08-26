import Cocoa
import Darwin
import ServiceManagement

struct Plate: Decodable {
    let id: String
    let track: String
    let title: String
}

struct Playlist: Decodable {
    let id: String
    let title: String
    let tracks: [String]?
    let mode: String?
    let ids: [String]?
}

struct Catalog: Decodable {
    let plates: [Plate]
    let playlists: [Playlist]?
}

struct TrayState: Codable {
    var plateId: String
    var advance: String
    var playlist: String

    enum CodingKeys: String, CodingKey {
        case plateId, advance, playlist
    }

    init(plateId: String = "", advance: String = "off", playlist: String = "all") {
        self.plateId = plateId
        self.advance = advance
        self.playlist = playlist
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plateId = try c.decodeIfPresent(String.self, forKey: .plateId) ?? ""
        advance = try c.decodeIfPresent(String.self, forKey: .advance) ?? "off"
        playlist = try c.decodeIfPresent(String.self, forKey: .playlist) ?? "all"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var plates: [Plate] = []
    private var playlists: [Playlist] = []
    private var state = TrayState()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var spaceApplyWork: DispatchWorkItem?
    private let mixTracks = ["system", "backend", "database", "dsa", "frontend", "network", "genai", "lang", "os", "arch", "tools"]
    private let launchAgentLabel = "local.foundations.plates"

    private var rootURL: URL { URL(fileURLWithPath: FoundationsRoot.path, isDirectory: true) }
    private var catalogURL: URL { rootURL.appendingPathComponent("catalog.json") }
    private var currentURL: URL { rootURL.appendingPathComponent(".current-plate") }
    private var stateURL: URL { rootURL.appendingPathComponent(".tray-state.json") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadCatalog()
        loadState()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.3.layers.3d", accessibilityDescription: "Foundations")
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        }
        rebuildMenu()
        applyCurrent(write: false)
        scheduleAdvance()
        watchSpacesAndScreens()
    }

    /// Each macOS Space keeps its own wallpaper. Re-apply when you switch to
    /// (or create) a desktop, connect a display, or wake the screens.
    private func watchSpacesAndScreens() {
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyWallpaperSoon()
        })
        observers.append(nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyWallpaperSoon()
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyWallpaperSoon()
        })
    }

    private func applyWallpaperSoon() {
        spaceApplyWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.applyWallpaper()
        }
        spaceApplyWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func applyWallpaper() {
        if let p = plate(), let url = imageURL(for: p) {
            setWallpaper(url)
        }
    }

    private func loadCatalog() {
        do {
            let data = try Data(contentsOf: catalogURL)
            let catalog = try JSONDecoder().decode(Catalog.self, from: data)
            plates = catalog.plates
            playlists = catalog.playlists ?? [Playlist(id: "all", title: "All plates", tracks: nil, mode: nil, ids: nil)]
        } catch {
            plates = []
            playlists = []
            NSLog("Foundations: catalog failed \(error)")
        }
    }

    private func loadState() {
        if let data = try? Data(contentsOf: stateURL),
           let s = try? JSONDecoder().decode(TrayState.self, from: data) {
            state = s
        } else if let id = try? String(contentsOf: currentURL, encoding: .utf8) {
            state.plateId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if playlists.contains(where: { $0.id == state.playlist }) == false {
            state.playlist = "all"
        }
        if state.plateId.isEmpty {
            state.plateId = activePlates().first?.id ?? plates.first?.id ?? ""
        }
    }

    private func saveState() {
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL)
        }
        try? state.plateId.write(to: currentURL, atomically: true, encoding: .utf8)
    }

    private func currentPlaylist() -> Playlist {
        playlists.first(where: { $0.id == state.playlist }) ?? playlists.first ?? Playlist(id: "all", title: "All plates", tracks: nil, mode: nil, ids: nil)
    }

    private func interleave(_ source: [Plate]) -> [Plate] {
        let groups = mixTracks.map { t in source.filter { $0.track == t } }.filter { !$0.isEmpty }
        var out: [Plate] = []
        var i = 0
        while true {
            var added = false
            for g in groups where i < g.count {
                out.append(g[i])
                added = true
            }
            if !added { break }
            i += 1
        }
        return out
    }

    private func plates(in pl: Playlist) -> [Plate] {
        if pl.id == "all" { return plates }
        if pl.mode == "interleave" { return interleave(plates) }
        if let ids = pl.ids, !ids.isEmpty {
            let map = Dictionary(uniqueKeysWithValues: plates.map { ($0.id, $0) })
            return ids.compactMap { map[$0] }
        }
        if let tracks = pl.tracks, !tracks.isEmpty {
            let set = Set(tracks)
            return plates.filter { set.contains($0.track) }
        }
        return plates
    }

    private func activePlates() -> [Plate] {
        plates(in: currentPlaylist())
    }

    private func catalogIndex(_ id: String) -> Int {
        plates.firstIndex(where: { $0.id == id }) ?? -1
    }

    private func plateNumber(_ p: Plate) -> Int {
        Int(p.id.split(separator: "-").first ?? "") ?? 0
    }

    private func plate() -> Plate? {
        if let p = plates.first(where: { $0.id == state.plateId }) { return p }
        return activePlates().first ?? plates.first
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let current = plate()
        let header = NSMenuItem(title: current?.title ?? "Foundations", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let next = NSMenuItem(title: "Next plate", action: #selector(nextPlate), keyEquivalent: "n")
        next.target = self
        menu.addItem(next)

        let prev = NSMenuItem(title: "Previous plate", action: #selector(prevPlate), keyEquivalent: "p")
        prev.target = self
        menu.addItem(prev)

        menu.addItem(.separator())

        let shown = activePlates()
        let platesMenu = NSMenu()
        let width = plates.count >= 100 ? 3 : 2
        for p in shown {
            let num = String(format: width == 3 ? "%03d" : "%02d", plateNumber(p))
            let item = NSMenuItem(title: "\(num)  \(p.title)", action: #selector(choosePlate(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = p.id
            item.state = p.id == state.plateId ? .on : .off
            platesMenu.addItem(item)
        }
        let platesItem = NSMenuItem(title: "Plates", action: nil, keyEquivalent: "")
        platesItem.submenu = platesMenu
        menu.addItem(platesItem)

        let listMenu = NSMenu()
        for pl in playlists {
            let n = playlistCount(pl)
            let item = NSMenuItem(title: "\(pl.title)  (\(n))", action: #selector(choosePlaylist(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pl.id
            item.state = pl.id == state.playlist ? .on : .off
            listMenu.addItem(item)
        }
        let listItem = NSMenuItem(title: playlistMenuTitle(), action: nil, keyEquivalent: "")
        listItem.submenu = listMenu
        menu.addItem(listItem)

        menu.addItem(.separator())

        let adv = NSMenu()
        let cadence: [(String, String)] = [
            ("Off", "off"),
            ("Every 5 minutes", "5m"),
            ("Every 15 minutes", "15m"),
            ("Every 30 minutes", "30m"),
            ("Every hour", "1h"),
            ("Every 2 hours", "2h"),
            ("Every 6 hours", "6h"),
            ("Daily at 9:00", "daily"),
        ]
        for (i, (title, value)) in cadence.enumerated() {
            if i == 1 || i == 5 { adv.addItem(.separator()) }
            let item = NSMenuItem(title: title, action: #selector(chooseAdvance(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = state.advance == value ? .on : .off
            adv.addItem(item)
        }
        let advItem = NSMenuItem(title: cadenceMenuTitle(), action: nil, keyEquivalent: "")
        advItem.submenu = adv
        menu.addItem(advItem)

        let login = NSMenuItem(title: "Open at login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = isLoginEnabled() ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Foundations", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        let n = plate().map(plateNumber) ?? 0
        statusItem.button?.title = String(format: width == 3 ? " %03d" : " %02d", n)
    }

    private func playlistCount(_ pl: Playlist) -> Int {
        plates(in: pl).count
    }

    private func playlistMenuTitle() -> String {
        let title = currentPlaylist().title
        return title == "All plates" ? "Playlist" : "Playlist · \(title)"
    }

    @objc private func nextPlate() {
        stepActive(dir: 1)
    }

    @objc private func prevPlate() {
        stepActive(dir: -1)
    }

    private func stepActive(dir: Int) {
        let list = activePlates()
        guard !list.isEmpty else { return }
        if let i = list.firstIndex(where: { $0.id == state.plateId }) {
            state.plateId = list[(i + dir + list.count) % list.count].id
        } else {
            let full = catalogIndex(state.plateId)
            if dir > 0 {
                state.plateId = list.first(where: { catalogIndex($0.id) > full })?.id ?? list[0].id
            } else {
                state.plateId = list.last(where: { catalogIndex($0.id) < full })?.id ?? list[list.count - 1].id
            }
        }
        applyCurrent(write: true)
    }

    @objc private func choosePlaylist(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        state.playlist = id
        let list = activePlates()
        if list.contains(where: { $0.id == state.plateId }) == false {
            state.plateId = list.first?.id ?? state.plateId
            applyCurrent(write: true)
            return
        }
        saveState()
        rebuildMenu()
    }

    @objc private func choosePlate(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        state.plateId = id
        applyCurrent(write: true)
    }

    @objc private func chooseAdvance(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        state.advance = value
        saveState()
        scheduleAdvance()
        rebuildMenu()
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    private var appExecutablePath: String {
        rootURL.appendingPathComponent("app/Foundations.app/Contents/MacOS/Foundations").path
    }

    private func isLoginEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path) || SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLoginItem() {
        if isLoginEnabled() {
            unloadLaunchAgent()
            try? SMAppService.mainApp.unregister()
        } else {
            do {
                try writeLaunchAgent()
            } catch {
                NSLog("Foundations: launch agent \(error)")
            }
            try? SMAppService.mainApp.register()
        }
        rebuildMenu()
    }

    private func writeLaunchAgent() throws {
        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [appExecutablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: launchAgentURL)
        launchctl(["bootout", "gui/\(getuid())", launchAgentLabel])
        launchctl(["bootstrap", "gui/\(getuid())", launchAgentURL.path])
    }

    private func unloadLaunchAgent() {
        launchctl(["bootout", "gui/\(getuid())", launchAgentLabel])
        try? FileManager.default.removeItem(at: launchAgentURL)
    }

    private func launchctl(_ args: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }

    private func cadenceMenuTitle() -> String {
        switch state.advance {
        case "5m": return "Auto-advance · 5 min"
        case "15m": return "Auto-advance · 15 min"
        case "30m": return "Auto-advance · 30 min"
        case "1h": return "Auto-advance · 1 h"
        case "2h": return "Auto-advance · 2 h"
        case "6h": return "Auto-advance · 6 h"
        case "daily": return "Auto-advance · 9:00"
        default: return "Auto-advance"
        }
    }

    private func seconds(for value: String) -> TimeInterval? {
        switch value {
        case "5m": return 5 * 60
        case "15m": return 15 * 60
        case "30m": return 30 * 60
        case "1h": return 60 * 60
        case "2h": return 2 * 60 * 60
        case "6h": return 6 * 60 * 60
        default: return nil
        }
    }

    private func applyCurrent(write: Bool) {
        if write { saveState() }
        applyWallpaper()
        rebuildMenu()
    }

    private func preferredSize() -> [String] {
        guard let screen = NSScreen.main else { return ["mbp14", "16x10", "5k"] }
        let w = Int((screen.frame.width * screen.backingScaleFactor).rounded())
        if w >= 5000 { return ["5k", "mbp14", "16x10"] }
        if abs(w - 3024) < 120 { return ["mbp14", "16x10", "5k"] }
        return ["16x10", "mbp14", "5k"]
    }

    private func imageURL(for plate: Plate) -> URL? {
        for size in preferredSize() {
            let url = rootURL
                .appendingPathComponent("output")
                .appendingPathComponent(size)
                .appendingPathComponent("\(plate.id).png")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func setWallpaper(_ url: URL) {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .allowClipping: true,
            .imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue),
        ]
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
        // System Events "desktops" are displays. Spaces get the picture when we
        // re-apply on NSWorkspace.activeSpaceDidChangeNotification.
        let posix = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "System Events"
          set posixFile to POSIX file "\(posix)"
          repeat with d in desktops
            try
              set picture of d to posixFile
            end try
          end repeat
        end tell
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try? proc.run()
    }

    private func scheduleAdvance() {
        timer?.invalidate()
        timer = nil
        if state.advance == "daily" {
            let cal = Calendar.current
            var next = cal.nextDate(after: Date(), matching: DateComponents(hour: 9, minute: 0, second: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(86400)
            if next <= Date() {
                next = cal.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86400)
            }
            let t = Timer(fire: next, interval: 86400, repeats: true) { [weak self] _ in
                self?.nextPlate()
            }
            t.tolerance = 60
            RunLoop.main.add(t, forMode: .common)
            timer = t
            return
        }
        guard let secs = seconds(for: state.advance) else { return }
        let t = Timer(timeInterval: secs, repeats: true) { [weak self] _ in
            self?.nextPlate()
        }
        t.tolerance = min(15, max(1, secs * 0.05))
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}

@main
enum FoundationsApp {
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
