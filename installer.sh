#!/bin/bash

SWIFT_FILE="$HOME/Documents/soft_restart_pro.swift"
rm -f "$SWIFT_FILE"

cat > "$SWIFT_FILE" << 'SWIFT_EOF'
import Cocoa
import Foundation

let LOCAL_VER = "2.1"

// ── Shell ─────────────────────────────────────────────────────
@discardableResult
func sh(_ cmd: String) -> String {
    let t = Process(); let p = Pipe()
    t.launchPath = "/bin/zsh"; t.arguments = ["-c", cmd]
    t.standardOutput = p; t.standardError = p
    try? t.run(); t.waitUntilExit()
    return String(data: p.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

// ── Palette ───────────────────────────────────────────────────
extension NSColor {
    static let P_BG     = NSColor(red:0.055,green:0.062,blue:0.075,alpha:1)
    static let P_SURF   = NSColor(red:0.09, green:0.10, blue:0.12, alpha:1)
    static let P_CARD   = NSColor(red:0.11, green:0.125,blue:0.145,alpha:1)
    static let P_BDR    = NSColor(red:0.17, green:0.185,blue:0.21, alpha:1)
    static let P_BDR2   = NSColor(red:0.22, green:0.24, blue:0.27, alpha:1)
    static let P_RED    = NSColor(red:0.97, green:0.33, blue:0.33, alpha:1)
    static let P_REDD   = NSColor(red:0.97, green:0.33, blue:0.33, alpha:0.13)
    static let P_GRN    = NSColor(red:0.18, green:0.82, blue:0.55, alpha:1)
    static let P_GRND   = NSColor(red:0.18, green:0.82, blue:0.55, alpha:0.12)
    static let P_BLU    = NSColor(red:0.24, green:0.60, blue:1.00, alpha:1)
    static let P_BLUD   = NSColor(red:0.24, green:0.60, blue:1.00, alpha:0.12)
    static let P_ORG    = NSColor(red:1.00, green:0.62, blue:0.18, alpha:1)
    static let P_ORGD   = NSColor(red:1.00, green:0.62, blue:0.18, alpha:0.12)
    static let P_PUR    = NSColor(red:0.68, green:0.42, blue:1.00, alpha:1)
    static let P_PURD   = NSColor(red:0.68, green:0.42, blue:1.00, alpha:0.12)
    static let P_PRI    = NSColor(red:0.91, green:0.93, blue:0.95, alpha:1)
    static let P_SEC    = NSColor(red:0.52, green:0.57, blue:0.63, alpha:1)
    static let P_DIM    = NSColor(red:0.30, green:0.34, blue:0.39, alpha:1)
}

// ── Label helpers ─────────────────────────────────────────────
func L(_ s:String, size:CGFloat=12, weight:NSFont.Weight = .regular,
        color:NSColor = .P_PRI, align:NSTextAlignment = .left) -> NSTextField {
    let f = NSTextField(labelWithString:s)
    f.font = .systemFont(ofSize:size, weight:weight)
    f.textColor = color; f.alignment = align
    f.translatesAutoresizingMaskIntoConstraints = false
    f.lineBreakMode = .byWordWrapping; f.maximumNumberOfLines = 0
    return f
}
func M(_ s:String, size:CGFloat=10) -> NSTextField {
    let f = NSTextField(labelWithString:s)
    f.font = .monospacedSystemFont(ofSize:size, weight:.regular)
    f.textColor = .P_SEC; f.translatesAutoresizingMaskIntoConstraints = false
    f.lineBreakMode = .byTruncatingTail
    return f
}
func Ln() -> NSView {
    let v = NSView(); v.wantsLayer=true
    v.layer?.backgroundColor = NSColor.P_BDR.cgColor
    v.translatesAutoresizingMaskIntoConstraints = false; return v
}

// ── Tab button ────────────────────────────────────────────────
class TabBtn: NSView {
    var active = false { didSet { refresh() } }
    var action: (()->Void)?
    private let lbl: NSTextField
    private var ta: NSTrackingArea?
    private var hov = false
    private let ac: NSColor; private let acd: NSColor

    init(_ title:String, ac:NSColor = .P_BLU, acd:NSColor = .P_BLUD) {
        self.ac = ac; self.acd = acd
        lbl = L(title, size:11, weight:.semibold, align:.center)
        super.init(frame:.zero)
        wantsLayer=true; layer?.cornerRadius=8
        addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo:centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo:centerYAnchor),
        ])
        refresh()
    }
    required init?(coder:NSCoder){fatalError()}
    func refresh() {
        if active {
            layer?.backgroundColor = acd.cgColor
            lbl.textColor = ac
        } else if hov {
            layer?.backgroundColor = NSColor.P_CARD.cgColor
            lbl.textColor = .P_PRI
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            lbl.textColor = .P_SEC
        }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t=ta{removeTrackingArea(t)}
        ta=NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeInKeyWindow],owner:self)
        addTrackingArea(ta!)
    }
    override func mouseEntered(with e:NSEvent){hov=true;refresh()}
    override func mouseExited (with e:NSEvent){hov=false;refresh()}
    override func mouseDown  (with e:NSEvent){action?()}
    override var isFlipped:Bool{true}
}

// ── Toggle ────────────────────────────────────────────────────
class Tog: NSView {
    var on = false { didSet { anim() } }
    var changed:((Bool)->Void)?
    private let track=NSView(); private let thumb=NSView()
    private var tl:NSLayoutConstraint!; private var ta:NSTrackingArea?
    override init(frame:NSRect){
        super.init(frame:NSRect(x:0,y:0,width:40,height:22))
        wantsLayer=true
        track.wantsLayer=true; track.layer?.cornerRadius=11
        thumb.wantsLayer=true; thumb.layer?.cornerRadius=8
        thumb.layer?.backgroundColor=NSColor.white.cgColor
        track.translatesAutoresizingMaskIntoConstraints=false
        thumb.translatesAutoresizingMaskIntoConstraints=false
        addSubview(track); addSubview(thumb)
        tl=thumb.leadingAnchor.constraint(equalTo:leadingAnchor,constant:3)
        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo:topAnchor),
            track.bottomAnchor.constraint(equalTo:bottomAnchor),
            track.leadingAnchor.constraint(equalTo:leadingAnchor),
            track.trailingAnchor.constraint(equalTo:trailingAnchor),
            thumb.centerYAnchor.constraint(equalTo:centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant:16),
            thumb.heightAnchor.constraint(equalToConstant:16), tl,
        ]); anim()
    }
    required init?(coder:NSCoder){fatalError()}
    func anim(){
        track.layer?.backgroundColor = on ? NSColor.P_GRN.cgColor : NSColor.P_BDR.cgColor
        tl.constant = on ? 21 : 3
        NSAnimationContext.runAnimationGroup{c in c.duration=0.18;c.allowsImplicitAnimation=true;layoutSubtreeIfNeeded()}
    }
    override func updateTrackingAreas(){
        super.updateTrackingAreas()
        if let t=ta{removeTrackingArea(t)}
        ta=NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeInKeyWindow],owner:self)
        addTrackingArea(ta!)
    }
    override func mouseDown(with e:NSEvent){on.toggle();changed?(on)}
    override var intrinsicContentSize:NSSize{NSSize(width:40,height:22)}
    override var isFlipped:Bool{true}
}

// ── Process row ───────────────────────────────────────────────
class ProcRow: NSView {
    var isChecked = false { didSet { refresh() } }
    var onToggle: ((Bool)->Void)?
    private let nameL: NSTextField; private let pidL: NSTextField
    private let cpuL:  NSTextField; private let box: NSView
    private var ta: NSTrackingArea?; private var hov = false

    init(name:String, pid:String, cpu:String, mem:String) {
        nameL = L(name, size:11, weight:.medium)
        pidL  = M("PID \(pid)", size:9)
        cpuL  = M("CPU \(cpu)%  MEM \(mem)%", size:9)
        box   = NSView(); box.wantsLayer=true; box.layer?.cornerRadius=4
        box.layer?.borderWidth=1.5; box.translatesAutoresizingMaskIntoConstraints=false
        super.init(frame:.zero); wantsLayer=true; layer?.cornerRadius=6
        translatesAutoresizingMaskIntoConstraints=false
        addSubview(box); addSubview(nameL); addSubview(pidL); addSubview(cpuL)
        let ln = Ln(); addSubview(ln)
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo:leadingAnchor,constant:14),
            box.centerYAnchor.constraint(equalTo:centerYAnchor),
            box.widthAnchor.constraint(equalToConstant:14),
            box.heightAnchor.constraint(equalToConstant:14),
            nameL.leadingAnchor.constraint(equalTo:box.trailingAnchor,constant:10),
            nameL.topAnchor.constraint(equalTo:topAnchor,constant:9),
            nameL.trailingAnchor.constraint(equalTo:cpuL.leadingAnchor,constant:-8),
            pidL.leadingAnchor.constraint(equalTo:nameL.leadingAnchor),
            pidL.topAnchor.constraint(equalTo:nameL.bottomAnchor,constant:2),
            pidL.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-9),
            cpuL.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-14),
            cpuL.centerYAnchor.constraint(equalTo:centerYAnchor),
            ln.bottomAnchor.constraint(equalTo:bottomAnchor),
            ln.leadingAnchor.constraint(equalTo:leadingAnchor,constant:14),
            ln.trailingAnchor.constraint(equalTo:trailingAnchor),
            ln.heightAnchor.constraint(equalToConstant:1),
        ]); refresh()
    }
    required init?(coder:NSCoder){fatalError()}

    func refresh() {
        if isChecked {
            box.layer?.backgroundColor = NSColor.P_RED.cgColor
            box.layer?.borderColor     = NSColor.P_RED.cgColor
            layer?.backgroundColor     = NSColor.P_REDD.cgColor
        } else if hov {
            box.layer?.backgroundColor = NSColor.clear.cgColor
            box.layer?.borderColor     = NSColor.P_BDR2.cgColor
            layer?.backgroundColor     = NSColor.P_CARD.cgColor
        } else {
            box.layer?.backgroundColor = NSColor.clear.cgColor
            box.layer?.borderColor     = NSColor.P_BDR.cgColor
            layer?.backgroundColor     = NSColor.clear.cgColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t=ta{removeTrackingArea(t)}
        ta=NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeInKeyWindow],owner:self)
        addTrackingArea(ta!)
    }
    override func mouseEntered(with e:NSEvent){hov=true;refresh()}
    override func mouseExited (with e:NSEvent){hov=false;refresh()}
    override func mouseDown   (with e:NSEvent){isChecked.toggle();onToggle?(isChecked)}
    override var isFlipped:Bool{true}
}

// ── Stat card ─────────────────────────────────────────────────
class StatCard: NSView {
    init(value:String, label:String, color:NSColor) {
        super.init(frame:.zero); wantsLayer=true; layer?.cornerRadius=10
        layer?.backgroundColor=color.withAlphaComponent(0.08).cgColor
        layer?.borderWidth=1; layer?.borderColor=color.withAlphaComponent(0.2).cgColor
        translatesAutoresizingMaskIntoConstraints=false
        let v=L(value,size:22,weight:.bold,color:color,align:.center)
        let lb=L(label,size:9,weight:.semibold,color:.P_SEC,align:.center)
        addSubview(v); addSubview(lb)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo:topAnchor,constant:14),
            v.leadingAnchor.constraint(equalTo:leadingAnchor,constant:8),
            v.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-8),
            lb.topAnchor.constraint(equalTo:v.bottomAnchor,constant:4),
            lb.leadingAnchor.constraint(equalTo:v.leadingAnchor),
            lb.trailingAnchor.constraint(equalTo:v.trailingAnchor),
            lb.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-14),
        ])
    }
    required init?(coder:NSCoder){fatalError()}
    override var isFlipped:Bool{true}
}

// ── Main controller ───────────────────────────────────────────
class Controller: NSObject, NSWindowDelegate {
    var win: NSWindow!
    var pages = [String:NSView]()
    var tabBtns = [String:TabBtn]()
    var currentTab = "restart"

    // Process state
    struct Proc { var pid:String; var name:String; var cpu:String; var mem:String; var selected=false }
    var allProcs  = [Proc]()
    var filtProcs = [Proc]()
    var procRows  = [ProcRow]()
    var procStack: NSView!
    var procScroll: NSScrollView!
    var searchField: NSTextField!
    var procCountL: NSTextField!

    // Log
    var logView: NSTextView!
    var logScroll: NSScrollView!

    // Options
    var optReopen  = true
    var optFlushDNS = false
    var optAudio    = false
    var optPurgeMem = false
    var optDock     = false
    var optFinder   = false
    var optMenuBar  = false

    // Progress
    var spinner: NSProgressIndicator!
    var progBar: NSProgressIndicator!
    var statusL: NSTextField!
    var doneBtn: NSButton!
    var runBtn:  NSButton!

    // Stats
    var statProcCount: NSTextField!
    var statCPULoad:   NSTextField!
    var statMemFree:   NSTextField!

    let ESSENTIALS = ["/Applications/Stats.app","/Applications/boringNotch.app"]
    let PROTECTED  = Set(["boringNotch","BoringNotchXPC","Stats","Finder","Dock",
                          "SystemUIServer","WindowServer","loginwindow","launchd",
                          "kernel_task","swift","swiftc","soft_restart_pro"])

    // ── Build window ──────────────────────────────────────────
    func run() {
        NSApp.setActivationPolicy(.regular)
        win = NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:680),
                       styleMask:[.titled,.closable,.fullSizeContentView],
                       backing:.buffered,defer:false)
        win.title="Soft Restart Pro"
        win.titlebarAppearsTransparent=true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground=true
        win.backgroundColor = .P_BG
        win.center(); win.delegate=self

        let root=NSView(); root.wantsLayer=true
        root.layer?.backgroundColor=NSColor.P_BG.cgColor
        win.contentView=root

        buildTopBar(root)
        buildPages(root)
        showTab("restart")
        refreshStats()

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
        NSApp.run()
    }

    func windowWillClose(_ n:Notification){ NSApp.terminate(nil) }

    // ── Top bar ───────────────────────────────────────────────
    func buildTopBar(_ root:NSView) {
        let bar=NSView(); bar.wantsLayer=true
        bar.layer?.backgroundColor=NSColor.P_SURF.cgColor
        bar.translatesAutoresizingMaskIntoConstraints=false
        root.addSubview(bar)

        // Logo
        let logo = L("SR", size:13, weight:.bold, color:.P_RED)
        let logoBg = NSView(); logoBg.wantsLayer=true
        logoBg.layer?.backgroundColor=NSColor.P_REDD.cgColor
        logoBg.layer?.cornerRadius=8; logoBg.translatesAutoresizingMaskIntoConstraints=false
        logoBg.addSubview(logo)

        let title = L("Soft Restart Pro", size:13, weight:.semibold)
        let ver   = L("v\(LOCAL_VER)", size:10, color:.P_DIM)

        // Tabs
        let tabs:[(String,String,NSColor,NSColor)] = [
            ("restart","Restart",.P_RED,.P_REDD),
            ("processes","Processes",.P_BLU,.P_BLUD),
            ("advanced","Advanced",.P_PUR,.P_PURD),
            ("log","Log",.P_GRN,.P_GRND),
        ]
        var tabViews=[NSView]()
        for (id,name,ac,acd) in tabs {
            let tb=TabBtn(name,ac:ac,acd:acd); tb.translatesAutoresizingMaskIntoConstraints=false
            tb.action={ [weak self] in self?.showTab(id) }
            tabBtns[id]=tb; tabViews.append(tb)
        }

        bar.addSubview(logoBg); bar.addSubview(title); bar.addSubview(ver)

        let s=Ln(); root.addSubview(s)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo:root.topAnchor),
            bar.leadingAnchor.constraint(equalTo:root.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo:root.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant:56),
            logoBg.leadingAnchor.constraint(equalTo:bar.leadingAnchor,constant:20),
            logoBg.centerYAnchor.constraint(equalTo:bar.centerYAnchor),
            logoBg.widthAnchor.constraint(equalToConstant:30),
            logoBg.heightAnchor.constraint(equalToConstant:30),
            logo.centerXAnchor.constraint(equalTo:logoBg.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo:logoBg.centerYAnchor),
            title.leadingAnchor.constraint(equalTo:logoBg.trailingAnchor,constant:10),
            title.topAnchor.constraint(equalTo:bar.topAnchor,constant:13),
            ver.leadingAnchor.constraint(equalTo:title.leadingAnchor),
            ver.topAnchor.constraint(equalTo:title.bottomAnchor,constant:1),
            s.topAnchor.constraint(equalTo:bar.bottomAnchor),
            s.leadingAnchor.constraint(equalTo:root.leadingAnchor),
            s.trailingAnchor.constraint(equalTo:root.trailingAnchor),
            s.heightAnchor.constraint(equalToConstant:1),
        ])

        // Place tabs flush to the right of the bar
        let tabStack = NSStackView(views: tabViews)
        tabStack.orientation = .horizontal
        tabStack.spacing = 4
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(tabStack)
        NSLayoutConstraint.activate([
            tabStack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            tabStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
        for tb in tabViews {
            NSLayoutConstraint.activate([
                tb.heightAnchor.constraint(equalToConstant: 32),
                tb.widthAnchor.constraint(equalToConstant: 88),
            ])
        }
    }

    // ── Pages container ───────────────────────────────────────
    func buildPages(_ root:NSView) {
        let container=NSView(); container.translatesAutoresizingMaskIntoConstraints=false
        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo:root.topAnchor,constant:57),
            container.leadingAnchor.constraint(equalTo:root.leadingAnchor),
            container.trailingAnchor.constraint(equalTo:root.trailingAnchor),
            container.bottomAnchor.constraint(equalTo:root.bottomAnchor),
        ])

        buildRestartPage(container)
        buildProcessesPage(container)
        buildAdvancedPage(container)
        buildLogPage(container)
    }

    func pinPage(_ v:NSView, in c:NSView) {
        v.translatesAutoresizingMaskIntoConstraints=false; c.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo:c.topAnchor),
            v.bottomAnchor.constraint(equalTo:c.bottomAnchor),
            v.leadingAnchor.constraint(equalTo:c.leadingAnchor),
            v.trailingAnchor.constraint(equalTo:c.trailingAnchor),
        ])
    }

    func showTab(_ id:String) {
        currentTab=id
        pages.values.forEach{$0.isHidden=true}
        tabBtns.values.forEach{$0.active=false}
        pages[id]?.isHidden=false
        tabBtns[id]?.active=true
        if id=="processes" { loadProcs() }
        if id=="restart"   { refreshStats() }
    }

    // ═══════════════════════════════════════════════════════
    // RESTART PAGE
    // ═══════════════════════════════════════════════════════
    func buildRestartPage(_ c:NSView) {
        let pg=NSView(); pinPage(pg,in:c); pages["restart"]=pg; pg.isHidden=true

        let scr=NSScrollView(); scr.translatesAutoresizingMaskIntoConstraints=false
        scr.hasVerticalScroller=true; scr.borderType = .noBorder
        scr.backgroundColor = .P_BG; scr.drawsBackground=true
        pg.addSubview(scr)
        let inner=NSView(); inner.translatesAutoresizingMaskIntoConstraints=false
        scr.documentView=inner
        NSLayoutConstraint.activate([
            scr.topAnchor.constraint(equalTo:pg.topAnchor),
            scr.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            scr.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            scr.bottomAnchor.constraint(equalTo:pg.bottomAnchor),
            inner.leadingAnchor.constraint(equalTo:scr.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo:scr.trailingAnchor),
            inner.topAnchor.constraint(equalTo:scr.contentView.topAnchor),
        ])

        // Stats row
        statProcCount = L("—", size:22, weight:.bold, color:.P_BLU, align:.center)
        statCPULoad   = L("—", size:22, weight:.bold, color:.P_ORG, align:.center)
        statMemFree   = L("—", size:22, weight:.bold, color:.P_GRN, align:.center)

        let sc1=makeStatCard(valueL:statProcCount, label:"PROCESSES", color:.P_BLU)
        let sc2=makeStatCard(valueL:statCPULoad,   label:"CPU USAGE",  color:.P_ORG)
        let sc3=makeStatCard(valueL:statMemFree,   label:"MEM FREE",   color:.P_GRN)

        let statsRow=NSView(); statsRow.translatesAutoresizingMaskIntoConstraints=false
        statsRow.addSubview(sc1); statsRow.addSubview(sc2); statsRow.addSubview(sc3)
        inner.addSubview(statsRow)
        NSLayoutConstraint.activate([
            sc1.topAnchor.constraint(equalTo:statsRow.topAnchor),
            sc1.bottomAnchor.constraint(equalTo:statsRow.bottomAnchor),
            sc1.leadingAnchor.constraint(equalTo:statsRow.leadingAnchor),
            sc2.topAnchor.constraint(equalTo:statsRow.topAnchor),
            sc2.bottomAnchor.constraint(equalTo:statsRow.bottomAnchor),
            sc2.leadingAnchor.constraint(equalTo:sc1.trailingAnchor,constant:10),
            sc2.widthAnchor.constraint(equalTo:sc1.widthAnchor),
            sc3.topAnchor.constraint(equalTo:statsRow.topAnchor),
            sc3.bottomAnchor.constraint(equalTo:statsRow.bottomAnchor),
            sc3.leadingAnchor.constraint(equalTo:sc2.trailingAnchor,constant:10),
            sc3.trailingAnchor.constraint(equalTo:statsRow.trailingAnchor),
            sc3.widthAnchor.constraint(equalTo:sc1.widthAnchor),
        ])

        // Mode section
        let modeL=L("RESTART MODE",size:9,weight:.semibold,color:.P_DIM)
        inner.addSubview(modeL)

        let modes:[(String,String,String,NSColor,NSColor)] = [
            ("Win","Kill Windows","Close all visible windows via AppleScript. Finder is preserved.",.P_BLU,.P_BLUD),
            ("Svc","Kill Services","Terminate background processes. Essentials relaunch automatically.",.P_RED,.P_REDD),
            ("All","Kill All","Full soft reset — closes windows then terminates services.",.P_ORG,.P_ORGD),
        ]
        var modeCards=[ModeCard2]()
        var lastMC:ModeCard2?=nil
        for (i,(icon,title,desc,ac,acd)) in modes.enumerated() {
            let mc=ModeCard2(icon:icon,title:title,desc:desc,ac:ac,acd:acd)
            mc.translatesAutoresizingMaskIntoConstraints=false; inner.addSubview(mc)
            let idx=i
            mc.tap={
                modeCards.forEach{$0.sel=false;$0.clearHov()}
                mc.sel=true
                self.selectedModeIdx=idx
            }
            if i==0{mc.sel=true}
            modeCards.append(mc)
            NSLayoutConstraint.activate([
                mc.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),
                mc.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),
                mc.heightAnchor.constraint(equalToConstant:70),
            ])
            if let p=lastMC{mc.topAnchor.constraint(equalTo:p.bottomAnchor,constant:8).isActive=true}
            else{mc.topAnchor.constraint(equalTo:modeL.bottomAnchor,constant:10).isActive=true}
            lastMC=mc
        }
        self.modeCards2=modeCards

        // Options row
        let optL=L("OPTIONS",size:9,weight:.semibold,color:.P_DIM); inner.addSubview(optL)
        let reopenTog=Tog(); reopenTog.on=true; reopenTog.translatesAutoresizingMaskIntoConstraints=false
        reopenTog.changed={[weak self] on in self?.optReopen=on}
        let reopenL=L("Reopen Essentials",size:12)
        let reopenS=L("Relaunches boringNotch and Stats after restart",size:10,color:.P_SEC)

        let optBox=NSView(); optBox.wantsLayer=true
        optBox.layer?.backgroundColor=NSColor.P_SURF.cgColor
        optBox.layer?.cornerRadius=10; optBox.layer?.borderWidth=1
        optBox.layer?.borderColor=NSColor.P_BDR.cgColor
        optBox.translatesAutoresizingMaskIntoConstraints=false
        optBox.addSubview(reopenTog); optBox.addSubview(reopenL); optBox.addSubview(reopenS)
        inner.addSubview(optBox)

        // Progress area
        spinner=NSProgressIndicator(); spinner.style = .spinning
        spinner.controlSize = .regular; spinner.isIndeterminate=true
        spinner.translatesAutoresizingMaskIntoConstraints=false; spinner.isHidden=true

        progBar=NSProgressIndicator(); progBar.style = .bar
        progBar.isIndeterminate=false; progBar.minValue=0
        progBar.maxValue=100; progBar.doubleValue=0
        progBar.translatesAutoresizingMaskIntoConstraints=false; progBar.isHidden=true

        statusL=L("Ready",size:11,color:.P_SEC,align:.center)
        statusL.translatesAutoresizingMaskIntoConstraints=false

        // Buttons
        runBtn=makeBtn("Run Restart", accent:.P_RED)
        runBtn.target=self; runBtn.action=#selector(doRun)
        let refreshBtn=makeBtn("Refresh Stats",ghost:true)
        refreshBtn.target=self; refreshBtn.action=#selector(doRefreshStats)

        doneBtn=makeBtn("Done")
        doneBtn.target=self; doneBtn.action=#selector(doClose)
        doneBtn.isHidden=true

        inner.addSubview(spinner); inner.addSubview(progBar)
        inner.addSubview(statusL); inner.addSubview(runBtn)
        inner.addSubview(refreshBtn); inner.addSubview(doneBtn)

        let pad=NSView(); pad.translatesAutoresizingMaskIntoConstraints=false; inner.addSubview(pad)

        NSLayoutConstraint.activate([
            statsRow.topAnchor.constraint(equalTo:inner.topAnchor,constant:24),
            statsRow.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),
            statsRow.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),
            statsRow.heightAnchor.constraint(equalToConstant:76),

            modeL.topAnchor.constraint(equalTo:statsRow.bottomAnchor,constant:24),
            modeL.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),

            optL.topAnchor.constraint(equalTo:lastMC?.bottomAnchor ?? modeL.bottomAnchor,constant:24),
            optL.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),

            reopenTog.leadingAnchor.constraint(equalTo:optBox.leadingAnchor,constant:16),
            reopenTog.centerYAnchor.constraint(equalTo:optBox.centerYAnchor),
            reopenTog.widthAnchor.constraint(equalToConstant:40),
            reopenTog.heightAnchor.constraint(equalToConstant:22),
            reopenL.leadingAnchor.constraint(equalTo:reopenTog.trailingAnchor,constant:12),
            reopenL.topAnchor.constraint(equalTo:optBox.topAnchor,constant:14),
            reopenS.leadingAnchor.constraint(equalTo:reopenL.leadingAnchor),
            reopenS.topAnchor.constraint(equalTo:reopenL.bottomAnchor,constant:2),
            reopenS.bottomAnchor.constraint(equalTo:optBox.bottomAnchor,constant:-14),
            optBox.topAnchor.constraint(equalTo:optL.bottomAnchor,constant:10),
            optBox.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),
            optBox.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),

            spinner.topAnchor.constraint(equalTo:optBox.bottomAnchor,constant:20),
            spinner.centerXAnchor.constraint(equalTo:inner.centerXAnchor),
            progBar.topAnchor.constraint(equalTo:spinner.bottomAnchor,constant:12),
            progBar.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),
            progBar.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),
            statusL.topAnchor.constraint(equalTo:progBar.bottomAnchor,constant:8),
            statusL.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),
            statusL.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),

            runBtn.topAnchor.constraint(equalTo:statusL.bottomAnchor,constant:16),
            runBtn.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),
            runBtn.widthAnchor.constraint(equalToConstant:140),
            runBtn.heightAnchor.constraint(equalToConstant:34),

            refreshBtn.topAnchor.constraint(equalTo:statusL.bottomAnchor,constant:16),
            refreshBtn.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20),
            refreshBtn.widthAnchor.constraint(equalToConstant:120),
            refreshBtn.heightAnchor.constraint(equalToConstant:34),

            doneBtn.topAnchor.constraint(equalTo:runBtn.bottomAnchor,constant:10),
            doneBtn.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),
            doneBtn.widthAnchor.constraint(equalToConstant:100),
            doneBtn.heightAnchor.constraint(equalToConstant:34),

            pad.topAnchor.constraint(equalTo:doneBtn.bottomAnchor),
            pad.heightAnchor.constraint(equalToConstant:24),
            pad.leadingAnchor.constraint(equalTo:inner.leadingAnchor),
            pad.trailingAnchor.constraint(equalTo:inner.trailingAnchor),
            pad.bottomAnchor.constraint(equalTo:inner.bottomAnchor),
        ])
    }

    var modeCards2 = [ModeCard2]()
    var selectedModeIdx = 0

    func makeStatCard(valueL:NSTextField, label:String, color:NSColor) -> NSView {
        let v=NSView(); v.wantsLayer=true; v.layer?.cornerRadius=10
        v.layer?.backgroundColor=color.withAlphaComponent(0.08).cgColor
        v.layer?.borderWidth=1; v.layer?.borderColor=color.withAlphaComponent(0.18).cgColor
        v.translatesAutoresizingMaskIntoConstraints=false
        let lb=L(label,size:8,weight:.semibold,color:color.withAlphaComponent(0.7),align:.center)
        v.addSubview(valueL); v.addSubview(lb)
        NSLayoutConstraint.activate([
            valueL.topAnchor.constraint(equalTo:v.topAnchor,constant:14),
            valueL.leadingAnchor.constraint(equalTo:v.leadingAnchor,constant:6),
            valueL.trailingAnchor.constraint(equalTo:v.trailingAnchor,constant:-6),
            lb.topAnchor.constraint(equalTo:valueL.bottomAnchor,constant:4),
            lb.leadingAnchor.constraint(equalTo:valueL.leadingAnchor),
            lb.trailingAnchor.constraint(equalTo:valueL.trailingAnchor),
            lb.bottomAnchor.constraint(equalTo:v.bottomAnchor,constant:-14),
        ]); return v
    }

    func refreshStats() {
        DispatchQueue.global(qos:.background).async { [weak self] in
            let procs = sh("ps -u $(whoami) -o pid= | wc -l | tr -d ' '").trimmingCharacters(in:.whitespacesAndNewlines)
            let cpu   = sh("top -l 1 -s 0 | awk '/CPU usage/{print $3}' | tr -d '%'").trimmingCharacters(in:.whitespacesAndNewlines)
            let pages = sh("vm_stat | awk '/Pages free/{gsub(/\\./, \"\", $3); print int($3)*4096/1073741824}'").trimmingCharacters(in:.whitespacesAndNewlines)
            DispatchQueue.main.async { [weak self] in
                self?.statProcCount.stringValue = procs.isEmpty ? "—" : procs
                self?.statCPULoad.stringValue   = cpu.isEmpty   ? "—" : cpu+"%"
                let gb = Double(pages) ?? 0
                self?.statMemFree.stringValue   = gb < 0.1 ? "—" : String(format:"%.1fG",gb)
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // PROCESSES PAGE
    // ═══════════════════════════════════════════════════════
    func buildProcessesPage(_ c:NSView) {
        let pg=NSView(); pinPage(pg,in:c); pages["processes"]=pg; pg.isHidden=true

        // Search bar
        let searchBox=NSView(); searchBox.wantsLayer=true
        searchBox.layer?.backgroundColor=NSColor.P_SURF.cgColor
        searchBox.translatesAutoresizingMaskIntoConstraints=false
        let sf=NSSearchField(); sf.translatesAutoresizingMaskIntoConstraints=false
        sf.placeholderString="Filter processes..."
        sf.font = .systemFont(ofSize:12)
        (sf.cell as? NSSearchFieldCell)?.searchButtonCell?.isHighlighted=false
        searchField=sf
        let sn=Ln()
        searchBox.addSubview(sf); pg.addSubview(searchBox); pg.addSubview(sn)

        procCountL=L("",size:10,color:.P_DIM)
        procCountL.translatesAutoresizingMaskIntoConstraints=false
        searchBox.addSubview(procCountL)

        NotificationCenter.default.addObserver(forName:NSControl.textDidChangeNotification, object:sf, queue:.main){[weak self] _ in self?.filterProcs()}

        // Scroll + stack
        procScroll=NSScrollView(); procScroll.translatesAutoresizingMaskIntoConstraints=false
        procScroll.hasVerticalScroller=true; procScroll.borderType = .noBorder
        procScroll.backgroundColor = .P_BG
        pg.addSubview(procScroll)
        procStack=NSView(); procStack.translatesAutoresizingMaskIntoConstraints=false
        procScroll.documentView=procStack

        // Bottom bar
        let bbar=NSView(); bbar.wantsLayer=true
        bbar.layer?.backgroundColor=NSColor.P_SURF.cgColor
        bbar.translatesAutoresizingMaskIntoConstraints=false
        let bSep=Ln()
        let killSelBtn=makeBtn("Kill Selected",accent:.P_RED)
        killSelBtn.target=self; killSelBtn.action=#selector(killSelected)
        let selectAllBtn=makeBtn("Select All",ghost:true)
        selectAllBtn.target=self; selectAllBtn.action=#selector(selectAll)
        let clearBtn=makeBtn("Clear",ghost:true)
        clearBtn.target=self; clearBtn.action=#selector(clearSel)
        let reloadBtn=makeBtn("Reload",ghost:true)
        reloadBtn.target=self; reloadBtn.action=#selector(reloadProcs)
        bbar.addSubview(killSelBtn); bbar.addSubview(selectAllBtn)
        bbar.addSubview(clearBtn);   bbar.addSubview(reloadBtn)
        pg.addSubview(bSep); pg.addSubview(bbar)

        NSLayoutConstraint.activate([
            searchBox.topAnchor.constraint(equalTo:pg.topAnchor),
            searchBox.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            searchBox.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            searchBox.heightAnchor.constraint(equalToConstant:52),
            sf.leadingAnchor.constraint(equalTo:searchBox.leadingAnchor,constant:16),
            sf.centerYAnchor.constraint(equalTo:searchBox.centerYAnchor),
            sf.widthAnchor.constraint(equalToConstant:260),
            procCountL.trailingAnchor.constraint(equalTo:searchBox.trailingAnchor,constant:-16),
            procCountL.centerYAnchor.constraint(equalTo:searchBox.centerYAnchor),
            sn.topAnchor.constraint(equalTo:searchBox.bottomAnchor),
            sn.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            sn.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            sn.heightAnchor.constraint(equalToConstant:1),
            procScroll.topAnchor.constraint(equalTo:sn.bottomAnchor),
            procScroll.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            procScroll.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            procScroll.bottomAnchor.constraint(equalTo:bSep.topAnchor),
            procStack.leadingAnchor.constraint(equalTo:procScroll.leadingAnchor),
            procStack.trailingAnchor.constraint(equalTo:procScroll.trailingAnchor),
            procStack.topAnchor.constraint(equalTo:procScroll.contentView.topAnchor),
            bSep.bottomAnchor.constraint(equalTo:bbar.topAnchor),
            bSep.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            bSep.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            bSep.heightAnchor.constraint(equalToConstant:1),
            bbar.bottomAnchor.constraint(equalTo:pg.bottomAnchor),
            bbar.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            bbar.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            bbar.heightAnchor.constraint(equalToConstant:56),
            killSelBtn.trailingAnchor.constraint(equalTo:bbar.trailingAnchor,constant:-16),
            killSelBtn.centerYAnchor.constraint(equalTo:bbar.centerYAnchor),
            killSelBtn.widthAnchor.constraint(equalToConstant:120),
            killSelBtn.heightAnchor.constraint(equalToConstant:32),
            selectAllBtn.trailingAnchor.constraint(equalTo:killSelBtn.leadingAnchor,constant:-8),
            selectAllBtn.centerYAnchor.constraint(equalTo:bbar.centerYAnchor),
            selectAllBtn.widthAnchor.constraint(equalToConstant:90),
            selectAllBtn.heightAnchor.constraint(equalToConstant:32),
            clearBtn.trailingAnchor.constraint(equalTo:selectAllBtn.leadingAnchor,constant:-8),
            clearBtn.centerYAnchor.constraint(equalTo:bbar.centerYAnchor),
            clearBtn.widthAnchor.constraint(equalToConstant:70),
            clearBtn.heightAnchor.constraint(equalToConstant:32),
            reloadBtn.leadingAnchor.constraint(equalTo:bbar.leadingAnchor,constant:16),
            reloadBtn.centerYAnchor.constraint(equalTo:bbar.centerYAnchor),
            reloadBtn.widthAnchor.constraint(equalToConstant:70),
            reloadBtn.heightAnchor.constraint(equalToConstant:32),
        ])
    }

    func loadProcs() {
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            guard let self=self else{return}
            let raw=sh("ps -u $(whoami) -o pid=,comm=,pcpu=,pmem= 2>/dev/null")
            self.allProcs = raw.components(separatedBy:"\n").compactMap { line in
                let p=line.trimmingCharacters(in:.whitespaces).components(separatedBy:.whitespaces)
                guard p.count>=4, let _=Int(p[0]) else{return nil}
                let name=URL(fileURLWithPath:p[1]).lastPathComponent
                guard !self.PROTECTED.contains(name),!name.isEmpty,name != "-" else{return nil}
                return Proc(pid:p[0],name:name,cpu:p[2],mem:p[3])
            }.sorted{$0.name.lowercased()<$1.name.lowercased()}
            self.filtProcs=self.allProcs
            DispatchQueue.main.async{self.renderProcRows()}
        }
    }

    func filterProcs() {
        let q=searchField.stringValue.lowercased()
        filtProcs = q.isEmpty ? allProcs : allProcs.filter{$0.name.lowercased().contains(q)}
        renderProcRows()
    }

    func renderProcRows() {
        procStack.subviews.forEach{$0.removeFromSuperview()}
        procRows=[]
        procCountL.stringValue="\(filtProcs.count) processes"
        var y:CGFloat=0
        for p in filtProcs {
            let row=ProcRow(name:p.name,pid:p.pid,cpu:p.cpu,mem:p.mem)
            row.isChecked = allProcs.first(where:{$0.pid==p.pid})?.selected ?? false
            let pid=p.pid
            row.onToggle={[weak self] on in
                if let i=self?.allProcs.firstIndex(where:{$0.pid==pid}){self?.allProcs[i].selected=on}
                if let i=self?.filtProcs.firstIndex(where:{$0.pid==pid}){self?.filtProcs[i].selected=on}
            }
            procStack.addSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo:procStack.leadingAnchor),
                row.trailingAnchor.constraint(equalTo:procStack.trailingAnchor),
                row.topAnchor.constraint(equalTo:procStack.topAnchor,constant:y),
                row.heightAnchor.constraint(equalToConstant:46),
            ])
            procRows.append(row); y+=46
        }
        procStack.frame=NSRect(x:0,y:0,width:620,height:max(y,60))
    }

    @objc func selectAll(){ allProcs.indices.forEach{allProcs[$0].selected=true}; filtProcs.indices.forEach{filtProcs[$0].selected=true}; renderProcRows() }
    @objc func clearSel (){ allProcs.indices.forEach{allProcs[$0].selected=false}; filtProcs.indices.forEach{filtProcs[$0].selected=false}; renderProcRows() }
    @objc func reloadProcs(){ loadProcs() }
    @objc func killSelected() {
        let sel=allProcs.filter{$0.selected}
        guard !sel.isEmpty else{return}
        DispatchQueue.global(qos:.userInitiated).async{[weak self] in
            for p in sel{
                sh("kill -9 \(p.pid) 2>/dev/null")
                self?.addLog("Killed \(p.name) [\(p.pid)]",.P_RED)
            }
            DispatchQueue.main.async{[weak self] in self?.loadProcs()}
        }
    }

    // ═══════════════════════════════════════════════════════
    // ADVANCED PAGE
    // ═══════════════════════════════════════════════════════
    func buildAdvancedPage(_ c:NSView) {
        let pg=NSView(); pinPage(pg,in:c); pages["advanced"]=pg; pg.isHidden=true

        let scr=NSScrollView(); scr.translatesAutoresizingMaskIntoConstraints=false
        scr.hasVerticalScroller=true; scr.borderType = .noBorder
        scr.backgroundColor = .P_BG
        pg.addSubview(scr)
        let inner=NSView(); inner.translatesAutoresizingMaskIntoConstraints=false
        scr.documentView=inner
        NSLayoutConstraint.activate([
            scr.topAnchor.constraint(equalTo:pg.topAnchor),
            scr.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            scr.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            scr.bottomAnchor.constraint(equalTo:pg.bottomAnchor),
            inner.leadingAnchor.constraint(equalTo:scr.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo:scr.trailingAnchor),
            inner.topAnchor.constraint(equalTo:scr.contentView.topAnchor),
        ])

        struct AdvOpt{let title:String;let desc:String;let key:String;let color:NSColor}
        let sections:[(String,[(String,String,String,NSColor)])]=[
            ("System Services",[
                ("Flush DNS Cache","Fix domain resolution failures and slow DNS lookups","dns",.P_BLU),
                ("Restart Audio","Kill coreaudiod to fix audio glitches and silence","audio",.P_PUR),
                ("Purge Memory","Force-free inactive memory pages (may cause brief slowness)","mem",.P_GRN),
            ]),
            ("UI & Shell",[
                ("Restart Dock","Fix unresponsive Dock or missing application icons","dock",.P_ORG),
                ("Restart Finder","Fix unresponsive desktop or broken file operations","finder",.P_BLU),
                ("Restart Menu Bar","Fix frozen or missing menu bar icons (SystemUIServer)","menubar",.P_RED),
            ]),
        ]

        var toggleMap=[String:Tog]()
        var lastSec:NSView?=nil

        for (secTitle,opts) in sections {
            let secL=L(secTitle.uppercased(),size:9,weight:.semibold,color:.P_DIM)
            inner.addSubview(secL)
            if let p=lastSec{secL.topAnchor.constraint(equalTo:p.bottomAnchor,constant:24).isActive=true}
            else{secL.topAnchor.constraint(equalTo:inner.topAnchor,constant:24).isActive=true}
            secL.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20).isActive=true

            let box=NSView(); box.wantsLayer=true
            box.layer?.backgroundColor=NSColor.P_SURF.cgColor
            box.layer?.cornerRadius=10; box.layer?.borderWidth=1
            box.layer?.borderColor=NSColor.P_BDR.cgColor
            box.translatesAutoresizingMaskIntoConstraints=false
            inner.addSubview(box)
            box.topAnchor.constraint(equalTo:secL.bottomAnchor,constant:8).isActive=true
            box.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:20).isActive=true
            box.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20).isActive=true

            var lastRow:NSView?=nil
            for (ot,od,ok,oc) in opts {
                let row=NSView(); row.translatesAutoresizingMaskIntoConstraints=false
                let dot=NSView(); dot.wantsLayer=true; dot.layer?.cornerRadius=3
                dot.layer?.backgroundColor=oc.cgColor; dot.translatesAutoresizingMaskIntoConstraints=false
                let tl=L(ot,size:12,weight:.medium)
                let dl=L(od,size:10,color:.P_SEC)
                let tg=Tog(); tg.translatesAutoresizingMaskIntoConstraints=false
                let k=ok; tg.changed={[weak self] on in self?.setAdvOpt(k,on)}
                toggleMap[ok]=tg
                let rl=Ln()
                row.addSubview(dot); row.addSubview(tl); row.addSubview(dl)
                row.addSubview(tg); row.addSubview(rl); box.addSubview(row)
                NSLayoutConstraint.activate([
                    row.leadingAnchor.constraint(equalTo:box.leadingAnchor),
                    row.trailingAnchor.constraint(equalTo:box.trailingAnchor),
                    row.heightAnchor.constraint(equalToConstant:54),
                    dot.leadingAnchor.constraint(equalTo:row.leadingAnchor,constant:16),
                    dot.centerYAnchor.constraint(equalTo:row.centerYAnchor),
                    dot.widthAnchor.constraint(equalToConstant:6),
                    dot.heightAnchor.constraint(equalToConstant:6),
                    tl.leadingAnchor.constraint(equalTo:dot.trailingAnchor,constant:12),
                    tl.topAnchor.constraint(equalTo:row.topAnchor,constant:10),
                    tl.trailingAnchor.constraint(equalTo:tg.leadingAnchor,constant:-12),
                    dl.leadingAnchor.constraint(equalTo:tl.leadingAnchor),
                    dl.topAnchor.constraint(equalTo:tl.bottomAnchor,constant:2),
                    dl.trailingAnchor.constraint(equalTo:tl.trailingAnchor),
                    tg.trailingAnchor.constraint(equalTo:row.trailingAnchor,constant:-16),
                    tg.centerYAnchor.constraint(equalTo:row.centerYAnchor),
                    tg.widthAnchor.constraint(equalToConstant:40),
                    tg.heightAnchor.constraint(equalToConstant:22),
                    rl.bottomAnchor.constraint(equalTo:row.bottomAnchor),
                    rl.leadingAnchor.constraint(equalTo:row.leadingAnchor,constant:16),
                    rl.trailingAnchor.constraint(equalTo:row.trailingAnchor),
                    rl.heightAnchor.constraint(equalToConstant:1),
                ])
                if let p=lastRow{row.topAnchor.constraint(equalTo:p.bottomAnchor).isActive=true}
                else{row.topAnchor.constraint(equalTo:box.topAnchor).isActive=true}
                lastRow=row
            }
            if let l=lastRow{box.bottomAnchor.constraint(equalTo:l.bottomAnchor).isActive=true}
            lastSec=box
        }

        // Run advanced button
        let runAdvBtn=makeBtn("Run Advanced Operations",accent:.P_PUR)
        runAdvBtn.target=self; runAdvBtn.action=#selector(doRunAdvanced)
        inner.addSubview(runAdvBtn)
        let pad=NSView(); pad.translatesAutoresizingMaskIntoConstraints=false; inner.addSubview(pad)
        NSLayoutConstraint.activate([
            runAdvBtn.topAnchor.constraint(equalTo:lastSec?.bottomAnchor ?? inner.topAnchor,constant:20),
            runAdvBtn.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-20),
            runAdvBtn.widthAnchor.constraint(equalToConstant:220),
            runAdvBtn.heightAnchor.constraint(equalToConstant:34),
            pad.topAnchor.constraint(equalTo:runAdvBtn.bottomAnchor),
            pad.heightAnchor.constraint(equalToConstant:24),
            pad.leadingAnchor.constraint(equalTo:inner.leadingAnchor),
            pad.trailingAnchor.constraint(equalTo:inner.trailingAnchor),
            pad.bottomAnchor.constraint(equalTo:inner.bottomAnchor),
        ])
    }

    func setAdvOpt(_ k:String,_ on:Bool){
        switch k{
        case "dns":    optFlushDNS=on; case "audio":   optAudio=on
        case "mem":    optPurgeMem=on; case "dock":    optDock=on
        case "finder": optFinder=on;  case "menubar":  optMenuBar=on
        default:break}
    }

    // ═══════════════════════════════════════════════════════
    // LOG PAGE
    // ═══════════════════════════════════════════════════════
    func buildLogPage(_ c:NSView) {
        let pg=NSView(); pinPage(pg,in:c); pages["log"]=pg; pg.isHidden=true

        let hdr=NSView(); hdr.wantsLayer=true
        hdr.layer?.backgroundColor=NSColor.P_SURF.cgColor
        hdr.translatesAutoresizingMaskIntoConstraints=false
        let tl=L("Activity Log",size:13,weight:.semibold)
        let clrBtn=makeBtn("Clear",ghost:true)
        clrBtn.target=self; clrBtn.action=#selector(clearLog)
        hdr.addSubview(tl); hdr.addSubview(clrBtn)
        pg.addSubview(hdr)
        let s=Ln(); pg.addSubview(s)

        logScroll=NSScrollView(); logScroll.translatesAutoresizingMaskIntoConstraints=false
        logScroll.hasVerticalScroller=true; logScroll.borderType = .noBorder
        logScroll.backgroundColor = .P_BG
        pg.addSubview(logScroll)

        logView=NSTextView(); logView.isEditable=false
        logView.backgroundColor = .P_BG; logView.isSelectable=true
        logView.textContainerInset=NSSize(width:16,height:14)
        logScroll.documentView=logView

        NSLayoutConstraint.activate([
            hdr.topAnchor.constraint(equalTo:pg.topAnchor),
            hdr.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            hdr.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            hdr.heightAnchor.constraint(equalToConstant:52),
            tl.leadingAnchor.constraint(equalTo:hdr.leadingAnchor,constant:20),
            tl.centerYAnchor.constraint(equalTo:hdr.centerYAnchor),
            clrBtn.trailingAnchor.constraint(equalTo:hdr.trailingAnchor,constant:-16),
            clrBtn.centerYAnchor.constraint(equalTo:hdr.centerYAnchor),
            clrBtn.widthAnchor.constraint(equalToConstant:60),
            clrBtn.heightAnchor.constraint(equalToConstant:28),
            s.topAnchor.constraint(equalTo:hdr.bottomAnchor),
            s.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            s.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            s.heightAnchor.constraint(equalToConstant:1),
            logScroll.topAnchor.constraint(equalTo:s.bottomAnchor),
            logScroll.leadingAnchor.constraint(equalTo:pg.leadingAnchor),
            logScroll.trailingAnchor.constraint(equalTo:pg.trailingAnchor),
            logScroll.bottomAnchor.constraint(equalTo:pg.bottomAnchor),
        ])
        addLog("Soft Restart Pro v\(LOCAL_VER) ready",.P_GRN)
    }

    func addLog(_ text:String,_ color:NSColor = .P_SEC) {
        DispatchQueue.main.async{[weak self] in
            guard let self=self, let ls=self.logView else{return}
            let ts=DateFormatter(); ts.dateFormat="HH:mm:ss"
            let time=ts.string(from:Date())
            let line="[\(time)]  \(text)\n"
            let a:[NSAttributedString.Key:Any]=[
                .font:NSFont.monospacedSystemFont(ofSize:10,weight:.regular),
                .foregroundColor:color
            ]
            ls.textStorage?.append(NSAttributedString(string:line,attributes:a))
            ls.scrollToEndOfDocument(nil)
        }
    }

    @objc func clearLog(){logView?.string=""}

    // ═══════════════════════════════════════════════════════
    // ACTIONS
    // ═══════════════════════════════════════════════════════
    @objc func doClose(){ NSApp.terminate(nil) }
    @objc func doRefreshStats(){ refreshStats() }

    @objc func doRun() {
        runBtn.isEnabled=false; spinner.isHidden=false; progBar.isHidden=false
        spinner.startAnimation(nil); progBar.doubleValue=0; doneBtn.isHidden=true
        showTab("log")

        DispatchQueue.global(qos:.userInitiated).async{[weak self] in
            guard let self=self else{return}
            let mode=self.selectedModeIdx
            var done=0.0
            let winList  = mode==0||mode==2 ? self.getWins() : []
            let procList = mode==1||mode==2 ? self.getProcsToKill() : []
            let total=Double(winList.count+procList.count+2)
            func tick(){done+=1;DispatchQueue.main.async{self.progBar.doubleValue=min(done/max(total,1)*100,97)}}

            if mode==0||mode==2{
                self.addLog("Closing windows...",.P_BLU)
                DispatchQueue.main.async{self.statusL.stringValue="Closing windows..."}
                for w in winList{
                    self.addLog("  window: \(w)")
                    sh("osascript -e 'tell application \"System Events\" to do shell script \"kill -9 \" & (unix id of process \"\(w)\")' 2>/dev/null")
                    tick(); Thread.sleep(forTimeInterval:0.05)
                }
            }
            if mode==1||mode==2{
                self.addLog("Killing services...",.P_RED)
                DispatchQueue.main.async{self.statusL.stringValue="Killing services..."}
                for p in procList{
                    self.addLog("  kill \(p.name) [\(p.pid)]")
                    sh("kill -9 \(p.pid) 2>/dev/null")
                    tick(); Thread.sleep(forTimeInterval:0.02)
                }
            }
            if self.optReopen{
                Thread.sleep(forTimeInterval:1.5)
                self.addLog("Relaunching essentials...",.P_GRN)
                for app in self.ESSENTIALS where FileManager.default.fileExists(atPath:app){
                    sh("open \"\(app)\" 2>/dev/null")
                    self.addLog("  launched \(URL(fileURLWithPath:app).deletingPathExtension().lastPathComponent)",.P_GRN)
                }
            }
            DispatchQueue.main.async{[weak self] in
                guard let self=self else{return}
                self.progBar.doubleValue=100
                self.statusL.stringValue="Complete"
                self.spinner.stopAnimation(nil); self.spinner.isHidden=true
                self.doneBtn.isHidden=false; self.runBtn.isEnabled=true
                self.addLog("Done.",.P_GRN)
            }
        }
    }

    @objc func doRunAdvanced(){
        showTab("log")
        addLog("Running advanced operations...",.P_PUR)
        DispatchQueue.global(qos:.userInitiated).async{[weak self] in
            guard let self=self else{return}
            if self.optFlushDNS{
                self.addLog("Flushing DNS...",.P_BLU)
                sh("dscacheutil -flushcache 2>/dev/null; killall -HUP mDNSResponder 2>/dev/null")
                self.addLog("  DNS flushed",.P_BLU)
            }
            if self.optAudio{
                self.addLog("Restarting audio...",.P_PUR)
                sh("killall coreaudiod 2>/dev/null")
                self.addLog("  coreaudiod restarted",.P_PUR)
            }
            if self.optPurgeMem{
                self.addLog("Purging memory...",.P_GRN)
                sh("purge 2>/dev/null")
                self.addLog("  memory purged",.P_GRN)
            }
            if self.optDock{
                self.addLog("Restarting Dock...",.P_ORG)
                sh("killall Dock 2>/dev/null")
                self.addLog("  Dock restarted",.P_ORG)
            }
            if self.optFinder{
                self.addLog("Restarting Finder...",.P_BLU)
                sh("killall Finder 2>/dev/null")
                self.addLog("  Finder restarted",.P_BLU)
            }
            if self.optMenuBar{
                self.addLog("Restarting menu bar...",.P_RED)
                sh("killall SystemUIServer 2>/dev/null")
                self.addLog("  SystemUIServer restarted",.P_RED)
            }
            self.addLog("Advanced operations complete.",.P_GRN)
        }
    }

    func getWins()->[String]{
        return sh("osascript -e 'tell application \"System Events\" to get name of every process whose visible is true' 2>/dev/null")
            .components(separatedBy:",")
            .map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}
            .filter{!$0.isEmpty && !PROTECTED.contains($0)}
    }
    func getProcsToKill()->[(pid:String,name:String)]{
        return sh("ps -u $(whoami) -o pid=,comm= 2>/dev/null")
            .components(separatedBy:"\n").compactMap{ line in
                let p=line.trimmingCharacters(in:.whitespaces).components(separatedBy:.whitespaces)
                guard p.count>=2, let _=Int(p[0]) else{return nil}
                let name=URL(fileURLWithPath:p[1]).lastPathComponent
                guard !PROTECTED.contains(name),!name.isEmpty,name != "-" else{return nil}
                return (p[0],name)
            }
    }

    // ── Button factory ────────────────────────────────────────
    func makeBtn(_ t:String, accent:NSColor = .P_RED, ghost:Bool=false) -> NSButton {
        let b=NSButton(title:t,target:nil,action:nil)
        b.bezelStyle = .rounded; b.isBordered=false; b.wantsLayer=true
        b.layer?.cornerRadius=8; b.font = .systemFont(ofSize:11,weight:.medium)
        b.translatesAutoresizingMaskIntoConstraints=false
        if ghost{
            b.layer?.backgroundColor=NSColor.P_SURF.cgColor
            b.layer?.borderColor=NSColor.P_BDR.cgColor; b.layer?.borderWidth=1
            b.contentTintColor = .P_SEC
        }else{
            b.layer?.backgroundColor=accent.cgColor; b.contentTintColor = .white
        }
        return b
    }
}

// ── Mode card (used in Restart page) ─────────────────────────
class ModeCard2: NSView {
    var sel=false{didSet{draw()}}
    private var hov=false
    var tap:(()->Void)?
    private let tl:NSTextField; private let dl:NSTextField; private let ic:NSTextField
    private let badge:NSView; private let ac:NSColor; private let acd:NSColor
    private var ta:NSTrackingArea?

    init(icon:String,title:String,desc:String,ac:NSColor,acd:NSColor){
        self.ac=ac; self.acd=acd
        tl=NSTextField(labelWithString:title); tl.font = .systemFont(ofSize:13,weight:.semibold)
        tl.textColor = .P_PRI; tl.translatesAutoresizingMaskIntoConstraints=false
        dl=NSTextField(labelWithString:desc); dl.font = .systemFont(ofSize:10)
        dl.textColor = .P_SEC; dl.translatesAutoresizingMaskIntoConstraints=false
        dl.lineBreakMode = .byWordWrapping; dl.maximumNumberOfLines=2
        ic=NSTextField(labelWithString:icon); ic.font = .systemFont(ofSize:14)
        ic.alignment = .center; ic.translatesAutoresizingMaskIntoConstraints=false
        badge=NSView(); badge.wantsLayer=true; badge.layer?.cornerRadius=12
        badge.translatesAutoresizingMaskIntoConstraints=false
        super.init(frame:.zero); wantsLayer=true; layer?.cornerRadius=10; layer?.borderWidth=1
        badge.addSubview(ic); addSubview(badge); addSubview(tl); addSubview(dl)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo:leadingAnchor,constant:16),
            badge.centerYAnchor.constraint(equalTo:centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant:34),
            badge.heightAnchor.constraint(equalToConstant:34),
            ic.centerXAnchor.constraint(equalTo:badge.centerXAnchor),
            ic.centerYAnchor.constraint(equalTo:badge.centerYAnchor),
            tl.leadingAnchor.constraint(equalTo:badge.trailingAnchor,constant:14),
            tl.topAnchor.constraint(equalTo:topAnchor,constant:14),
            tl.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-14),
            dl.leadingAnchor.constraint(equalTo:tl.leadingAnchor),
            dl.topAnchor.constraint(equalTo:tl.bottomAnchor,constant:3),
            dl.trailingAnchor.constraint(equalTo:tl.trailingAnchor),
            dl.bottomAnchor.constraint(lessThanOrEqualTo:bottomAnchor,constant:-14),
        ]); draw()
    }
    required init?(coder:NSCoder){fatalError()}
    func clearHov(){hov=false;draw()}
    func draw(){
        if sel{
            layer?.backgroundColor=acd.cgColor; layer?.borderColor=ac.cgColor
            badge.layer?.backgroundColor=ac.withAlphaComponent(0.2).cgColor; tl.textColor=ac
        }else if hov{
            layer?.backgroundColor=NSColor.P_CARD.cgColor
            layer?.borderColor=NSColor.P_BDR.withAlphaComponent(0.8).cgColor
            badge.layer?.backgroundColor=NSColor.P_BDR.withAlphaComponent(0.4).cgColor; tl.textColor = .P_PRI
        }else{
            layer?.backgroundColor=NSColor.P_SURF.cgColor; layer?.borderColor=NSColor.P_BDR.cgColor
            badge.layer?.backgroundColor=NSColor.P_BDR.withAlphaComponent(0.25).cgColor; tl.textColor = .P_PRI
        }
    }
    override func updateTrackingAreas(){
        super.updateTrackingAreas()
        if let t=ta{removeTrackingArea(t)}
        ta=NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeInKeyWindow],owner:self)
        addTrackingArea(ta!)
    }
    override func mouseEntered(with e:NSEvent){hov=true;draw()}
    override func mouseExited (with e:NSEvent){hov=false;draw()}
    override func mouseDown   (with e:NSEvent){tap?()}
    override var isFlipped:Bool{true}
}

Controller().run()
SWIFT_EOF

swift "$SWIFT_FILE"
