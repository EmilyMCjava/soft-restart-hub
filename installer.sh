#!/bin/bash

# --- CONFIGURATION ---
SWIFT_FILE="$HOME/Documents/soft_restart_pro.swift"
LOCAL_VER="1.2"

cat > "$SWIFT_FILE" << 'SWIFT_EOF'
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
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 550),
                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.center()
        w.title = "Soft Restart Pro"
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        
        let visualEffect = NSVisualEffectView(frame: w.contentView!.bounds)
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .sidebar // Gives that nice modern dark blur
        visualEffect.autoresizingMask = [.width, .height]
        w.contentView?.addSubview(visualEffect)

        // --- Tabs ---
        tabView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(tabView)

        // Quick Tab
        let mainTab = NSTabViewItem(identifier: "main")
        mainTab.label = "Quick Actions"
        let mainView = NSView()
        
        modeSegment.frame = NSRect(x: 20, y: 340, width: 380, height: 30)
        modeSegment.selectedSegment = 0
        mainView.addSubview(modeSegment)
        
        reopenCheck.frame = NSRect(x: 25, y: 300, width: 200, height: 20)
        reopenCheck.state = .on
        mainView.addSubview(reopenCheck)
        
        mainTab.view = mainView

        // Advanced Tab
        let advTab = NSTabViewItem(identifier: "adv")
        advTab.label = "Process Picker"
        let advView = NSView()
        
        searchField.frame = NSRect(x: 20, y: 345, width: 370, height: 24)
        searchField.placeholderString = "Filter running apps..."
        searchField.delegate = self
        advView.addSubview(searchField)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 20, width: 370, height: 315))
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

        // --- Console View ---
        let consoleScroll = NSScrollView(frame: NSRect(x: 20, y: 80, width: 380, height: 100))
        console.isEditable = false
        console.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        console.textColor = .systemGreen
        console.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        consoleScroll.documentView = console
        visualEffect.addSubview(consoleScroll)

        // Execute Button
        let execBtn = NSButton(title: "RUN SYSTEM RESTART", target: self, action: #selector(execute))
        execBtn.translatesAutoresizingMaskIntoConstraints = false
        execBtn.bezelStyle = .rounded
        execBtn.contentTintColor = .systemBlue
        visualEffect.addSubview(execBtn)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 50),
            tabView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 10),
            tabView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -10),
            tabView.bottomAnchor.constraint(equalTo: consoleScroll.topAnchor, constant: -10),
            execBtn.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -20),
            execBtn.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            execBtn.widthAnchor.constraint(equalToConstant: 200)
        ])

        self.win = w
        refreshProcs()
        log("System Ready. Version 1.1")
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
            // Kill checked items
            for p in self.allProcesses where p.isSelected { 
                self.log("Killing \(p.name)...")
                shell("kill -9 \(p.pid)") 
            }
            
            if mode == 0 || mode == 2 { 
                self.log("Restarting UI Shell...")
                shell("killall Dock Finder SystemUIServer") 
            }
            if mode == 1 || mode == 2 { 
                self.log("Nuking all user services...")
                shell("killall -u $(whoami) -m '.'") 
            }
            
            if reopen {
                for appPath in self.essentials {
                    if FileManager.default.fileExists(atPath: appPath) {
                        self.log("Relaunching \(URL(fileURLWithPath: appPath).lastPathComponent)...")
                        shell("open \(appPath)")
                    }
                }
            }
            self.log("Done!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.win?.close(); NSApp.terminate(nil)
            }
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
