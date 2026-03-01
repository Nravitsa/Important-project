import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

// ─── Clip Item — holds either text or image ────────────────────────────────────
struct ClipItem: Equatable {
    enum Content: Equatable {
        case text(String)
        case image(NSImage)
        static func == (a: Content, b: Content) -> Bool {
            switch (a, b) {
            case (.text(let x), .text(let y)): return x == y
            case (.image(let x), .image(let y)): return x === y
            default: return false
            }
        }
    }
    let content: Content
    var displayLabel: String {
        switch content {
        case .text(let s):
            let flat = s.components(separatedBy: .newlines).joined(separator: " ↵ ")
            return flat.count > 42 ? String(flat.prefix(42)) + "…" : flat
        case .image(let img):
            let w = Int(img.size.width), h = Int(img.size.height)
            return "Image  \(w) × \(h)"
        }
    }
    var thumbnail: NSImage? {
        guard case .image(let img) = content else { return nil }
        let size = NSSize(width: 32, height: 22)
        let thumb = NSImage(size: size)
        thumb.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: size),
                 from: .zero, operation: .copy, fraction: 1)
        thumb.unlockFocus()
        return thumb
    }
}

// ─── Custom Row View ───────────────────────────────────────────────────────────
class ClipRowView: NSView {

    private let thumbView  = NSImageView()
    private let label      = NSTextField(labelWithString: "")
    private let pinBtn     = NSButton(title: "", target: nil, action: nil)

    var onCopy: (() -> Void)?
    var onPin:  (() -> Void)?
    private var highlighted = false

    init(item: ClipItem, isPinned: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 32))

        // Thumbnail (images only)
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.imageScaling = .scaleProportionallyUpOrDown
        thumbView.image = item.thumbnail
        addSubview(thumbView)

        // Label
        label.stringValue   = item.displayLabel
        label.font          = .systemFont(ofSize: 13)
        label.textColor     = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        // Pin button — always visible on right
        pinBtn.title      = isPinned ? "📌" : "🖇️"
        pinBtn.toolTip    = isPinned ? "Unpin" : "Pin to top"
        pinBtn.bezelStyle = .inline
        pinBtn.isBordered = false
        pinBtn.font       = .systemFont(ofSize: 15)
        pinBtn.target     = self
        pinBtn.action     = #selector(pinTapped)
        pinBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pinBtn)

        let hasThumbnail = item.thumbnail != nil
        NSLayoutConstraint.activate([
            // Thumbnail
            thumbView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            thumbView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: hasThumbnail ? 34 : 0),
            thumbView.heightAnchor.constraint(equalToConstant: hasThumbnail ? 22 : 0),

            // Label
            label.leadingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: hasThumbnail ? 8 : 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: pinBtn.leadingAnchor, constant: -6),

            // Pin button
            pinBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            pinBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinBtn.widthAnchor.constraint(equalToConstant: 26),
        ])

        updateTrackingAreas()
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func pinTapped() { onPin?() }

    // ── Highlight ───────────────────────────────────────────────────────────────
    private func setHighlight(_ on: Bool) {
        highlighted = on
        wantsLayer  = true
        layer?.cornerRadius    = 6
        layer?.backgroundColor = on
            ? NSColor.selectedContentBackgroundColor.cgColor
            : NSColor.clear.cgColor
        label.textColor = on ? .white : .labelColor
    }

    override func mouseEntered(with event: NSEvent) { setHighlight(true)  }
    override func mouseExited(with  event: NSEvent) { setHighlight(false) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil))
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        // If click lands on pin button area let the button handle it
        if pinBtn.frame.contains(pt) { return }
        onCopy?()
    }
}

// ─── App Delegate ──────────────────────────────────────────────────────────────
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var history:    [ClipItem] = []
    var pinned:     [ClipItem] = []
    var pollTimer:  Timer?
    var lastChangeCount = NSPasteboard.general.changeCount
    let maxHistory = 10

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startPolling()
    }

    // ── Menu Bar ────────────────────────────────────────────────────────────────
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📋"
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        // Header
        addDisabled("ClipSlots", to: menu)

        // Pinned
        if !pinned.isEmpty {
            menu.addItem(.separator())
            addDisabled("📌  PINNED", to: menu)
            for item in pinned { menu.addItem(makeRow(item: item, isPinned: true)) }
        }

        // History
        menu.addItem(.separator())
        addDisabled("🕐  RECENT  —  click to copy", to: menu)
        if history.isEmpty {
            addDisabled("  — nothing copied yet —", to: menu)
        } else {
            for item in history { menu.addItem(makeRow(item: item, isPinned: false)) }
        }

        // Footer
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear Pinned",  action: #selector(clearPinned),  keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ClipSlots", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func makeRow(item: ClipItem, isPinned: Bool) -> NSMenuItem {
        let mi   = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = ClipRowView(item: item, isPinned: isPinned)

        view.onCopy = { [weak self] in
            self?.copyToClipboard(item: item)
            self?.statusItem.menu?.cancelTracking()   // close menu
            self?.flashIcon(label: "📋✓")
        }
        view.onPin = { [weak self] in
            isPinned ? self?.unpin(item: item) : self?.pin(item: item)
            self?.statusItem.menu?.cancelTracking()
            self?.rebuildMenu()
        }

        mi.view = view
        return mi
    }

    // ── Actions ──────────────────────────────────────────────────────────────────
    func copyToClipboard(item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.content {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .image(let img):
            if let tiff = img.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
        }
        lastChangeCount = pb.changeCount   // don't re-track our own write
    }

    func pin(item: ClipItem) {
        guard !pinned.contains(item) else { return }
        pinned.insert(item, at: 0)
        history.removeAll { $0 == item }
    }

    func unpin(item: ClipItem) {
        pinned.removeAll { $0 == item }
        history.insert(item, at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
    }

    @objc func clearHistory() { history.removeAll(); rebuildMenu() }
    @objc func clearPinned()  { pinned.removeAll();  rebuildMenu() }

    // ── Clipboard Polling ─────────────────────────────────────────────────────────
    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkClipboard()
        }
    }

    func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        var newItem: ClipItem?

        // Check image FIRST — screenshots put both a filename string and
        // image data on the clipboard; we want the image, not the filename.
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .init("public.png"),
            .png,
            .tiff,
        ]
        if let matchedType = imageTypes.first(where: { pb.data(forType: $0) != nil }),
           let data = pb.data(forType: matchedType),
           let img  = NSImage(data: data) {
            newItem = ClipItem(content: .image(img))
        }
        // Then try text
        else if let s = pb.string(forType: .string),
                !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newItem = ClipItem(content: .text(s))
        }

        guard let clip = newItem else { return }
        if pinned.contains(clip)    { return }   // already pinned, ignore
        if history.first == clip    { return }   // already on top

        history.removeAll { $0 == clip }
        history.insert(clip, at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }

        rebuildMenu()
        flashIcon(label: "📋●")
    }

    // ── UI Feedback ───────────────────────────────────────────────────────────────
    func flashIcon(label: String) {
        statusItem.button?.title = label
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.statusItem.button?.title = "📋"
        }
    }
}
