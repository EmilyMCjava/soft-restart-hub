#!/bin/bash

# --- CONFIGURATION ---
# This is used by the UI to check if it's out of date
REMOTE_VER_URL="https://raw.githubusercontent.com/EmilyMCjava/soft-restart-hub/main/version.txt"
LOCAL_VER="1.1"
SWIFT_FILE="$HOME/Documents/soft_restart_pro.swift"

# Check for the remote version number to pass into Swift
REMOTE_VER=$(curl -s "$REMOTE_VER_URL")

cat > "$SWIFT_FILE" << SWIFT_EOF
import Cocoa
import Foundation

struct ProcessItem {
    let pid: String
    let name: String
    var isSelected: Bool = false
}

class ProController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var win: NSWindow?
    let app = NSApplication.shared
    
    var allProcesses: [ProcessItem] = []
    var filteredProcesses: [ProcessItem] = []
    let essentials = ["/Applications/Stats.app", "/Applications/boringNotch.app"]
    
    // Simulation Vars
    var simNoStats = false
    var simNoNotch = false

    // UI Elements
    let tabView = NSTabView()
    let tableView = NSTableView()
    let searchField = NSSearchField()
    let statusLabel = NSTextField(labelWithString: "Ready")
    let modeSegment = NSSegmentedControl(labels: ["Windows", "Services", "Full Nuke"], trackingMode: .selectOne, target: nil, action: #selector(modeChanged))
    let reopenCheck = NSButton(checkboxWithTitle: "Reopen Essentials", target: nil, action: nil)

    func setupUI() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                         styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.center()
        w.titlebarAppearsTransparent = true
        w.appearance = NSAppearance(named: .vibrantDark)
        
        let visualEffect = NSVisualEffectView(frame: w.contentView!.bounds)
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .underWindowBackground
        visualEffect.autoresizingMask = [.width, .height]
        w.contentView?.addSubview(visualEffect)

        tabView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(tabView)

        // --- QUICK TAB ---
        let mainTab = NSTabViewItem(identifier: "main")
        mainTab.label = "Quick"
        let mainView = NSView()
        
        modeSegment.frame = NSRect(x: 20, y: 320, width: 360, height: 24)
        mainView.addSubview(modeSegment)
        
        reopenCheck.frame = NSRect(x: 20, y: 280, width: 140, height: 20)
        mainView.addSubview(reopenCheck)
        
        let helpBtn = NSButton(title: "?", target: self, action: #selector(showHelp))
        helpBtn.bezelStyle = .circular
        helpBtn.frame = NSRect(x: 165, y: 280, width: 22, height: 22)
        mainView.addSubview(helpBtn)
        
        // Update Label (Only shows if GitHub version is higher)
        if "$REMOTE_VER" > "$LOCAL_VER" {
            let upLbl = NSTextField(labelWithString: "⚠️ Update Available in Menu")
            upLbl.frame = NSRect(x: 20, y: 250, width: 360, height: 20)
            upLbl.textColor = .systemYellow
            upLbl.font = .systemFont(ofSize: 11, weight: .bold)
            mainView.addSubview(upLbl)
        }
        
        mainTab.view = mainView

        // --- ADVANCED TAB ---
        let advTab = NSTabViewItem(identifier: "adv")
        advTab.label = "Advanced"
        let advView = NSView()
        
        let simBox = NSBox(frame: NSRect(x: 15, y: 290, width: 370, height: 70))
        simBox.title = "Developer Simulation"
        let s1 = NSButton(checkboxWithTitle: "Simulate Stats Missing", target: self, action: #selector(toggleSim))
        let s2 = NSButton(checkboxWithTitle: "Simulate Notch Missing", target: self, action: #selector(toggleSim))
        s1.frame = NSRect(x: 10, y: 30, width: 200, height: 20)
        s2.frame = NSRect(x: 10, y: 10, width: 200, height: 20)
        simBox.contentView?.addSubview(s1); simBox.contentView?.addSubview(s2)
        advView.addSubview(simBox)

        searchField.frame = NSRect(x: 15, y: 255, width: 370, height: 22)
        searchField.placeholderString = "Search processes..."
        searchField.delegate = self
        advView.addSubview(searchField)

        let scroll = NSScrollView(frame: NSRect(x: 15, y: 10, width: 370, height: 235))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("proc"))
        col.width = 360
        tableView.addTableColumn(col)
        tableView.dataSource = self; tableView.delegate = self
        scroll.documentView = tableView
        advView.addSubview(scroll)
        
        advTab.view = advView
        tabView.addTabViewItem(mainTab); tabView.addTabViewItem(advTab)

        // Footer
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11); statusLabel.textColor = .secondaryLabelColor
        visualEffect.addSubview(statusLabel)

        let execBtn = NSButton(title: "Execute", target: self, action: #selector(execute))
        execBtn.translatesAutoresizingMaskIntoConstraints = false
        execBtn.bezelStyle = .rounded; execBtn.keyEquivalent = "\r"
        visualEffect.addSubview(execBtn)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 40),
            tabView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 5),
            tabView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -5),
            tabView.bottomAnchor.constraint(equalTo: execBtn.topAnchor, constant: -10),
            execBtn.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -20),
            execBtn.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -20),
            execBtn.widthAnchor.constraint(equalToConstant: 120),
            statusLabel.centerYAnchor.constraint(equalTo: execBtn.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 20)
        ])

        self.win = w
        updateEssentialState()
        refreshProcs()
    }

    func updateEssentialState() {
        let fm = FileManager.default
        let statsExist = fm.fileExists(atPath: essentials[0]) && !simNoStats
        let notchExist = fm.fileExists(atPath: essentials[1]) && !simNoNotch
        let anyFound = statsExist || notchExist
        
        DispatchQueue.main.async {
            self.reopenCheck.isEnabled = anyFound
            self.reopenCheck.alphaValue = anyFound ? 1.0 : 0.5
            if !anyFound { self.reopenCheck.state = .off }
        }
    }

    @objc func toggleSim(_ sender: NSButton) {
        if sender.title.contains("Stats") { simNoStats = (sender.state == .on) }
        else { simNoNotch = (sender.state == .on) }
        updateEssentialState()
    }

    @objc func showHelp(_ sender: NSButton) {
        let p = NSPopover(); p.behavior = .transient
        let vc = NSViewController()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 110))
        let txt = NSTextView(frame: NSRect(x: 10, y: 10, width: 230, height: 90))
        txt.string = "REOPEN ESSENTIALS:\n\nWhen enabled, the script will relaunch Stats and boringNotch after the cleanup. This option greys out if the apps are missing from /Applications."
        txt.isEditable = false; txt.backgroundColor = .clear; txt.font = .systemFont(ofSize: 11)
        container.addSubview(txt); vc.view = container; p.contentViewController = vc
        p.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    func refreshProcs() {
        let task = Process(); let pipe = Pipe()
        task.launchPath = "/bin/zsh"; task.arguments = ["-c", "ps -u $(whoami) -o pid=,comm="]
        task.standardOutput = pipe; try? task.run(); task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        allProcesses = output.components(separatedBy: "\n").compactMap { line in
            let p = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").filter { !$0.isEmpty }
            guard p.count >= 2 else { return nil }
            let name = URL(fileURLWithPath: p[1]).lastPathComponent
            if name.count < 3 || name.contains("soft_restart") { return nil }
            return ProcessItem(pid: p[0], name: name)
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        filteredProcesses = allProcesses
        tableView.reloadData()
    }

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.lowercased()
        filteredProcesses = query.isEmpty ? allProcesses : allProcesses.filter { $0.name.lowercased().contains(query) }
        tableView.reloadData()
    }

    @objc func execute() {
        let mode = modeSegment.selectedSegment
        let reopen = reopenCheck.state == .on
        let sStats = simNoStats, sNotch = simNoNotch
        
        DispatchQueue.global(qos: .userInitiated).async {
            for p in self.allProcesses where p.isSelected { shell("kill -9 \(p.pid)") }
            if mode == 0 || mode == 2 { shell("killall Dock Finder SystemUIServer") }
            if mode == 1 || mode == 2 { shell("killall -u $(whoami) -m '.'") }
            if reopen {
                if !sStats { shell("open \(self.essentials[0])") }
                if !sNotch { shell("open \(self.essentials[1])") }
            }
            DispatchQueue.main.async { self.win?.close(); NSApp.terminate(nil) }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { return filteredProcesses.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredProcesses[row]
        let btn = NSButton(checkboxWithTitle: "\(item.name) (\(item.pid))", target: self, action: #selector(rowChecked))
        btn.tag = row; btn.state = item.isSelected ? .on : .off
        btn.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        return btn
    }

    @objc func rowChecked(_ sender: NSButton) {
        let pid = filteredProcesses[sender.tag].pid
        if let idx = allProcesses.firstIndex(where: { $0.pid == pid }) {
            allProcesses[idx].isSelected = (sender.state == .on)
            filteredProcesses[sender.tag].isSelected = (sender.state == .on)
        }
    }

    @objc func modeChanged() {}
    func run() {
        app.setActivationPolicy(.regular); setupUI()
        win?.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true); app.run()
    }
}

func shell(_ args: String) {
    let t = Process(); t.launchPath = "/bin/zsh"; t.arguments = ["-c", args]
    try? t.run(); t.waitUntilExit()
}

ProController().run()
SWIFT_EOF

# Execute the newly written file
swift "$SWIFT_FILE"
