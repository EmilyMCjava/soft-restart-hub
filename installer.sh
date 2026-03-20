#!/bin/bash

# --- CONFIGURATION ---
SWIFT_FILE="$HOME/Documents/soft_restart_pro.swift"

cat > "$SWIFT_FILE" << 'SWIFT_EOF'
import Cocoa
import Foundation

let LOCAL_VER = "1.6.1" 

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

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    func setupUI() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.center()
        w.title = "Soft Restart Pro"
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.delegate = self
        
        let visualEffect = NSVisualEffectView(frame: w.contentView!.bounds)
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .sidebar
        visualEffect.autoresizingMask = [.width, .height]
        w.contentView?.addSubview(visualEffect)

        let mainStack = NSStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.edgeInsets = NSEdgeInsets(top: 60, left: 25, bottom: 25, right: 25)
        
        // CRITICAL FIX: Add the stack to the view BEFORE defining constraints
        visualEffect.addSubview(mainStack)

        let titleLbl = NSTextField(labelWithString: "Soft Restart V2")
        titleLbl.font = .systemFont(ofSize: 18, weight: .bold)
        titleLbl.alignment = .center
        mainStack.addArrangedSubview(titleLbl)

        modeSegment.selectedSegment = 0
        reopenCheck.state = .on
        let modeStack = NSStackView(views: [modeSegment, reopenCheck])
        modeStack.orientation = .vertical
        modeStack.spacing = 10
        mainStack.addArrangedSubview(modeStack)

        tabView.heightAnchor.constraint(equalToConstant: 240).isActive = true
        let advTab = NSTabViewItem(identifier: "adv")
        advTab.label = "Process Picker"
        let advView = NSView()
        
        let advStack = NSStackView()
        advStack.translatesAutoresizingMaskIntoConstraints = false
        advStack.orientation = .vertical
        advStack.spacing = 8
        advView.addSubview(advStack)

        searchField.placeholderString = "Search apps..."
        searchField.delegate = self
        advStack.addArrangedSubview(searchField)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("proc"))
        col.width = 360
        tableView.addTableColumn(col)
        tableView.dataSource = self; tableView.delegate = self
        scroll.documentView = tableView
        advStack.addArrangedSubview(scroll)
        
        advTab.view = advView
        tabView.addTabViewItem(advTab)
        mainStack.addArrangedSubview(tabView)

        let consoleScroll = NSScrollView()
        consoleScroll.heightAnchor.constraint(equalToConstant: 100).isActive = true
        console.isEditable = false
        console.backgroundColor = NSColor.black.withAlphaComponent(0.4)
        console.textColor = .systemGreen
        console.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        consoleScroll.documentView = console
        mainStack.addArrangedSubview(consoleScroll)

        let footer = NSStackView()
        footer.orientation = .horizontal
        let vLbl = NSTextField(labelWithString: "v\(LOCAL_VER)")
        vLbl.font = .systemFont(ofSize: 10)
        vLbl.textColor = .secondaryLabelColor
        
        let execBtn = NSButton(title: "RUN SYSTEM RESTART", target: self, action: #selector(execute))
        execBtn.bezelStyle = .rounded
        execBtn.contentTintColor = .systemBlue
        
        footer.addView(vLbl, in: .leading)
        footer.addView(execBtn, in: .trailing)
        mainStack.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            advStack.leadingAnchor.constraint(equalTo: advView.leadingAnchor),
            advStack.trailingAnchor.constraint(equalTo: advView.trailingAnchor),
            advStack.topAnchor.constraint(equalTo: advView.topAnchor),
            advStack.bottomAnchor.constraint(equalTo: advView.bottomAnchor)
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
            if mode == 0 || mode == 2 { shell("killall Dock Finder SystemUIServer") }
            if mode == 1 || mode == 2 { shell("killall -u $(whoami) -m '.'") }
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
}

func shell(_ args: String) {
    let t = Process(); t.launchPath = "/bin/zsh"; t.arguments = ["-c", args]
    try? t.run(); t.waitUntilExit()
}

ProController().run()
SWIFT_EOF

swift "$SWIFT_FILE"
