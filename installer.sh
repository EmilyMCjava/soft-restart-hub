#!/bin/bash

# --- CONFIGURATION ---
# This is what the Shortcut sees when it checks for updates
SWIFT_FILE="$HOME/Documents/soft_restart_pro.swift"

cat > "$SWIFT_FILE" << 'SWIFT_EOF'
import Cocoa
import Foundation

// --- VERSION DATA ---
// Shortcut looks for this line specifically
let LOCAL_VER = "1.5" 

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

    // UI Elements
    let tabView = NSTabView()
    let tableView = NSTableView()
    let searchField = NSSearchField()
    let console = NSTextView()
    let modeSegment = NSSegmentedControl(labels: ["🪟 Windows", "⚙️ Services", "☢️ Nuke"], trackingMode: .selectOne, target: nil, action: nil)
    let reopenCheck = NSButton(checkboxWithTitle: "🔄 Reopen Essentials", target: nil, action: nil)

    func log(_ text: String) {
        DispatchQueue.main.async {
            self.console.string += "> \(text)\n"
            self.console.scrollToEndOfDocument(nil)
        }
    }

    func setupUI() {
        // --- Create Window ---
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.center()
        w.title = "Soft Restart Pro"
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.appearance = NSAppearance(named: .vibrantDark)
        
        // --- Full Translucency Backing ---
        let visualEffect = NSVisualEffectView(frame: w.contentView!.bounds)
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .sidebar // Gives that nice deep blur
        visualEffect.autoresizingMask = [.width, .height]
        w.contentView?.addSubview(visualEffect)

        // --- Container View for Centering ---
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(container)

        // --- Main Title Label ---
        let titleLabel = NSTextField(labelWithString: "Soft Restart V2")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        container.addSubview(titleLabel)

        // --- Modes & Toggles (StackView 1) ---
        let topStack = NSStackView(views: [modeSegment, reopenCheck])
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.orientation = .vertical
        topStack.spacing = 15
        topStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        topStack.alignment = .centerX
        topStack.wantsLayer = true
        topStack.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        topStack.layer?.cornerRadius = 8
        container.addSubview(topStack)

        modeSegment.selectedSegment = 0
        reopenCheck.state = .on

        // --- Process TabView ---
        tabView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tabView)

        // Advanced Tab Only (Tucking the picker here to clean the UI)
        let advTab = NSTabViewItem(identifier: "adv")
        advTab.label = "Process Picker"
        let advView = NSView()
        advView.translatesAutoresizingMaskIntoConstraints = false
        advView.heightAnchor.constraint(equalToConstant: 250).isActive = true
        
        // Tab Container Stack
        let advStack = NSStackView()
        advStack.translatesAutoresizingMaskIntoConstraints = false
        advStack.orientation = .vertical
        advStack.spacing = 10
        advStack.alignment = .centerX
        advStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        advView.addSubview(advStack)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filter processes..."
        searchField.delegate = self
        advStack.addArrangedSubview(searchField)
        searchField.widthAnchor.constraint(equalTo: advStack.widthAnchor).isActive = true

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.heightAnchor.constraint(equalToConstant: 180).isActive = true
        
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("proc"))
        col.width = 380
        tableView.addTableColumn(col)
        tableView.dataSource = self; tableView.delegate = self
        scroll.documentView = tableView
        advStack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: advStack.widthAnchor).isActive = true
        
        advTab.view = advView
        tabView.addTabViewItem(advTab)

        // --- Console View ---
        let consoleScroll = NSScrollView()
        consoleScroll.translatesAutoresizingMaskIntoConstraints = false
        consoleScroll.wantsLayer = true
        consoleScroll.layer?.cornerRadius = 6
        consoleScroll.hasVerticalScroller = true
        consoleScroll.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        console.isEditable = false
        console.backgroundColor = NSColor.black.withAlphaComponent(0.4)
        console.textColor = .systemGreen
        console.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        consoleScroll.documentView = console
        container.addSubview(consoleScroll)

        // --- Bottom Row (Version + Run Button) ---
        let bottomStack = NSStackView()
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.orientation = .horizontal
        bottomStack.spacing = 10
        bottomStack.distribution = .gravityAreas
        bottomStack.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        container.addSubview(bottomStack)

        // Version Label
        let vLbl = NSTextField(labelWithString: "v\(LOCAL_VER)")
        vLbl.translatesAutoresizingMaskIntoConstraints = false
        vLbl.font = .systemFont(ofSize: 10)
        vLbl.textColor = .tertiaryLabelColor
        bottomStack.addView(vLbl, in: .leading)

        // Execute Button
        let execBtn = NSButton(title: "RUN SYSTEM RESTART", target: self, action: #selector(execute))
        execBtn.translatesAutoresizingMaskIntoConstraints = false
        execBtn.bezelStyle = .rounded
        execBtn.contentTintColor = .systemBlue
        bottomStack.addView(execBtn, in: .trailing)
        execBtn.widthAnchor.constraint(equalToConstant: 180).isActive = true

        // --- FINAL LAYOUT CONSTRAINTS (Centering the Container) ---
        NSLayoutConstraint.activate([
            // Container constraints to parent (the blur view)
            container.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            container.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 45), // Respect titlebar
            container.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -20),
            container.widthAnchor.constraint(equalTo: visualEffect.widthAnchor, constant: -40),

            // Vertical Stack of Elements
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.widthAnchor.constraint(equalTo: container.widthAnchor),

            topStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            topStack.widthAnchor.constraint(equalTo: container.widthAnchor),
            topStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            tabView.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 15),
            tabView.widthAnchor.constraint(equalTo: container.widthAnchor),
            tabView.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            // Tab View Internal Layout
            advStack.topAnchor.constraint(equalTo: advView.topAnchor),
            advStack.bottomAnchor.constraint(equalTo: advView.bottomAnchor),
            advStack.leadingAnchor.constraint(equalTo: advView.leadingAnchor),
            advStack.trailingAnchor.constraint(equalTo: advView.trailingAnchor),

            consoleScroll.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 15),
            consoleScroll.widthAnchor.constraint(equalTo: container.widthAnchor),
            consoleScroll.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            bottomStack.topAnchor.constraint(equalTo: consoleScroll.bottomAnchor, constant: 15),
            bottomStack.widthAnchor.constraint(equalTo: container.widthAnchor),
            bottomStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bottomStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.win = w
        refreshProcs()
        log("System Ready. v\(LOCAL_VER)")
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
        log("Executing mode: \(mode)...")
        DispatchQueue.global(qos: .userInitiated).async {
            for p in self.allProcesses where p.isSelected { 
                self.log("Killing \(p.name)...")
                shell("kill -9 \(p.pid)") 
            }
            if mode == 0 || mode == 2 { 
                self.log("Restarting UI Shell...")
                shell("killall Dock Finder SystemUIServer") 
            }
            if mode == 1 || mode == 2 { 
                self.log("Killing all user processes...")
                shell("killall -u $(whoami) -m '.'") 
            }
            if reopen {
                for appPath in self.essentials {
                    if FileManager.default.fileExists(atPath: appPath) { shell("open \(appPath)") }
                }
            }
            self.log("Done!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.win?.close(); NSApp.terminate(nil) }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { return filteredProcesses.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredProcesses[row]
        let btn = NSButton(checkboxWithTitle: "\(item.name) (PID: \(item.pid))", target: self, action: #selector(rowChecked))
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

    func run() {
        app.setActivationPolicy(.regular); setupUI()
        win?.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true); app.run()
    }

    // This forces the script to stop when you hit the red close button
    func windowWillClose(_ notification: Notification) {
        log("Window closing... Terminating.")
        NSApp.terminate(nil)
    }
}

func shell(_ args: String) {
    let t = Process(); t.launchPath = "/bin/zsh"; t.arguments = ["-c", args]
    try? t.run(); t.waitUntilExit()
}

ProController().run()
SWIFT_EOF

# Finally, execute the generated file
swift "$SWIFT_FILE"
