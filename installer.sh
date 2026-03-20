#!/bin/bash

# --- CONFIGURATION ---
SWIFT_FILE="$HOME/Documents/soft_restart_pro.swift"

cat > "$SWIFT_FILE" << 'SWIFT_EOF'
import Cocoa
import Foundation

// Keep the version string exactly as requested
let LOCAL_VER = "1.6.3" 

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

    // Premium UI Elements
    let tabView = NSTabView()
    let tableView = NSTableView()
    let searchField = NSSearchField()
    let console = NSTextView()
    let modeSegment = NSSegmentedControl(labels: ["🪟 Windows", "⚙️ Services", "☢️ Nuke"], trackingMode: .selectOne, target: nil, action: nil)
    let reopenCheck = NSButton(checkboxWithTitle: "🔄 Reopen Essentials", target: nil, action: nil)

    func log(_ text: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: Date())
            self.console.string += "[\(time)] \(text)\n"
            self.console.scrollToEndOfDocument(nil)
        }
    }

    // Terminate Shortcut on Window Close
    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    func setupUI() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 680),
                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.center()
        w.title = ""
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.delegate = self
        
        let visualEffect = NSVisualEffectView(frame: w.contentView!.bounds)
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .sidebar // Premium frosted glass effect
        visualEffect.autoresizingMask = [.width, .height]
        w.contentView?.addSubview(visualEffect)

        let mainStack = NSStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .vertical
        mainStack.spacing = 24
        mainStack.edgeInsets = NSEdgeInsets(top: 50, left: 30, bottom: 30, right: 30)
        visualEffect.addSubview(mainStack)

        // Header Section
        let titleStack = NSStackView()
        let titleLbl = NSTextField(labelWithString: "Soft Restart Pro")
        titleLbl.font = .systemFont(ofSize: 22, weight: .bold)
        titleLbl.textColor = .labelColor
        
        let subtitleLbl = NSTextField(labelWithString: "System Optimization Suite")
        subtitleLbl.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLbl.textColor = .secondaryLabelColor
        
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        titleStack.addArrangedSubview(titleLbl)
        titleStack.addArrangedSubview(subtitleLbl)
        mainStack.addArrangedSubview(titleStack)

        // Feature Organization: Tabs
        tabView.tabViewType = .topTabsBezelBorder
        tabView.controlSize = .regular
        
        // Tab 1: Quick Actions
        let quickTab = NSTabViewItem(identifier: "quick")
        quickTab.label = "Quick Actions"
        let quickView = NSStackView()
        quickView.orientation = .vertical
        quickView.spacing = 15
        quickView.edgeInsets = NSEdgeInsets(top: 20, left: 10, bottom: 20, right: 10)
        
        modeSegment.controlSize = .large
        reopenCheck.font = .systemFont(ofSize: 13)
        
        quickView.addArrangedSubview(NSTextField(labelWithString: "Restart Mode"))
        quickView.addArrangedSubview(modeSegment)
        quickView.addArrangedSubview(reopenCheck)
        quickTab.view = quickView
        
        // Tab 2: Process Picker
        let procTab = NSTabViewItem(identifier: "proc")
        procTab.label = "Process Picker"
        let procContainer = NSView()
        let procStack = NSStackView()
        procStack.translatesAutoresizingMaskIntoConstraints = false
        procStack.orientation = .vertical
        procStack.spacing = 10
        procContainer.addSubview(procStack)
        
        searchField.placeholderString = "Filter running applications..."
        searchField.delegate = self
        procStack.addArrangedSubview(searchField)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .lineBorder
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("proc"))
        col.width = 380
        tableView.addTableColumn(col)
        tableView.dataSource = self; tableView.delegate = self
        scroll.documentView = tableView
        procStack.addArrangedSubview(scroll)
        
        NSLayoutConstraint.activate([
            procStack.leadingAnchor.constraint(equalTo: procContainer.leadingAnchor, constant: 10),
            procStack.trailingAnchor.constraint(equalTo: procContainer.trailingAnchor, constant: -10),
            procStack.topAnchor.constraint(equalTo: procContainer.topAnchor, constant: 10),
            procStack.bottomAnchor.constraint(equalTo: procContainer.bottomAnchor, constant: -10)
        ])
        
        procTab.view = procContainer
        
        tabView.addTabViewItem(quickTab)
        tabView.addTabViewItem(procTab)
        mainStack.addArrangedSubview(tabView)

        // Console Log (Terminal Style)
        let consoleScroll = NSScrollView()
        consoleScroll.heightAnchor.constraint(equalToConstant: 120).isActive = true
        console.isEditable = false
        console.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        console.textColor = .systemGreen
        console.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        consoleScroll.documentView = console
        consoleScroll.borderType = .noBorder
        mainStack.addArrangedSubview(consoleScroll)

        // Footer Action
        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.distribution = .equalSpacing
        
        let vLbl = NSTextField(labelWithString: "VERSION \(LOCAL_VER)")
        vLbl.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        vLbl.textColor = .tertiaryLabelColor
        
        let execBtn = NSButton(title: "INITIALIZE RESTART", target: self, action: #selector(execute))
        execBtn.bezelStyle = .rounded
        execBtn.isHighlighted = true
        execBtn.keyEquivalent = "\r" // Enter key triggers it
        
        footer.addArrangedSubview(vLbl)
        footer.addArrangedSubview(execBtn)
        mainStack.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 30),
            mainStack.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -30),
            mainStack.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -30)
        ])

        self.win = w
        refreshProcs()
        log("Soft Restart Engine v\(LOCAL_VER) Initialized.")
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
        log("Commencing System Cleanup...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Kill selected processes
            for p in self.allProcesses where p.isSelected { 
                self.log("Terminating process: \(p.name)")
                shell("kill -9 \(p.pid)") 
            }
            
            if mode == 0 || mode == 2 { 
                self.log("Refreshing UI Services...")
                shell("killall Dock Finder SystemUIServer") 
            }
            
            if mode == 1 || mode == 2 { 
                self.log("Clearing User Services...")
                shell("killall -u $(whoami) -m '.'") 
            }
            
            if reopen {
                for appPath in self.essentials {
                    if FileManager.default.fileExists(atPath: appPath) { 
                        self.log("Reopening Essential: \(appPath)")
                        shell("open \(appPath)") 
                    }
                }
            }
            
            self.log("System Restart Complete.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.win?.close()
                NSApp.terminate(nil)
            }
        }
    }

    // TableView Logic
    func numberOfRows(in tableView: NSTableView) -> Int { return filteredProcesses.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredProcesses[row]
        let btn = NSButton(checkboxWithTitle: "\(item.name) (\(item.pid))", target: self, action: #selector(rowChecked))
        btn.tag = row; btn.state = item.isSelected ? .on : .off
        btn.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
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
