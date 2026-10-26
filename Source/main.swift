import Cocoa
import UniformTypeIdentifiers
import Darwin

func sizeText(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }

final class Entry {
    let url: URL
    let folder: Bool
    weak var parent: Entry?
    var children: [Entry] = []
    var logical: Int64 = 0
    var allocated: Int64 = 0
    var files: Int = 0
    init(_ url: URL, folder: Bool) { self.url = url; self.folder = folder }
    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }
}

struct ScanResult { let root: Entry; let errors: Int; let skippedVolumes: Int; let hardlinks: Int; let cancelled: Bool }
final class Scanner {
    private let lock = NSLock()
    private var stopped = false
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func scan(_ url: URL, progress: @escaping (Int, String) -> Void) -> ScanResult {
        var errors = 0, volumes = 0, links = 0, count = 0
        var seen = Set<String>()
        var rootStat = stat()
        let rootOK = url.path.withCString { lstat($0, &rootStat) } == 0
        let device = rootStat.st_dev
        var last = Date.distantPast
        func walk(_ path: URL, parent: Entry?) -> Entry? {
            if cancelled { return nil }
            var s = stat()
            guard path.path.withCString({ lstat($0, &s) }) == 0 else { errors += 1; return nil }
            let kind = s.st_mode & S_IFMT
            // Do not follow symbolic links, devices, sockets, or mounted volumes.
            guard kind == S_IFDIR || kind == S_IFREG else { return nil }
            if s.st_dev != device { volumes += 1; return nil }
            let e = Entry(path, folder: kind == S_IFDIR); e.parent = parent
            count += 1
            if Date().timeIntervalSince(last) > 0.15 { last = Date(); progress(count, path.path) }
            if e.folder {
                do {
                    let urls = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [])
                    for child in urls {
                        if cancelled { break }
                        if let c = walk(child, parent: e) {
                            e.children.append(c); e.logical += c.logical; e.allocated += c.allocated; e.files += c.files
                        }
                    }
                    e.children.sort { $0.allocated == $1.allocated ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.allocated > $1.allocated }
                } catch { errors += 1 }
            } else {
                e.files = 1
                let key = "\(s.st_dev):\(s.st_ino)"
                if s.st_nlink > 1 && !seen.insert(key).inserted { links += 1 }
                else { e.logical = Int64(s.st_size); e.allocated = Int64(s.st_blocks) * 512 }
            }
            return e
        }
        let root = rootOK ? (walk(url, parent: nil) ?? Entry(url, folder: true)) : Entry(url, folder: true)
        if !rootOK { errors += 1 }
        progress(count, url.path)
        return ScanResult(root: root, errors: errors, skippedVolumes: volumes, hardlinks: links, cancelled: cancelled)
    }
}

// MARK: - Visual components
let palette: [NSColor] = [
    NSColor(srgbRed: 0.16, green: 0.43, blue: 0.84, alpha: 1),
    NSColor(srgbRed: 0.04, green: 0.48, blue: 0.51, alpha: 1),
    NSColor(srgbRed: 0.48, green: 0.31, blue: 0.77, alpha: 1),
    NSColor(srgbRed: 0.72, green: 0.35, blue: 0.13, alpha: 1),
    NSColor(srgbRed: 0.67, green: 0.25, blue: 0.43, alpha: 1),
    NSColor(srgbRed: 0.24, green: 0.49, blue: 0.25, alpha: 1)
]
func colorFor(_ e: Entry) -> NSColor {
    let key = e.folder ? e.name : e.url.pathExtension.lowercased()
    let hash = key.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) & 0x7fffffff }
    return palette[hash % palette.count]
}
func label(_ text: String, _ size: CGFloat = 12, _ weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSTextField {
    let v = NSTextField(labelWithString: text)
    v.font = .systemFont(ofSize: size, weight: weight)
    v.textColor = secondary ? .secondaryLabelColor : .labelColor
    v.lineBreakMode = .byTruncatingMiddle
    return v
}
func button(_ title: String, _ symbol: String, target: AnyObject?, action: Selector?) -> NSButton {
    let v = NSButton(title: title, target: target, action: action)
    v.bezelStyle = .rounded; v.controlSize = .large; v.font = .systemFont(ofSize: 12, weight: .medium)
    v.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    v.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
    if title.isEmpty { v.widthAnchor.constraint(equalToConstant: 40).isActive = true }
    v.heightAnchor.constraint(equalToConstant: 36).isActive = true
    return v
}
func row(_ views: [NSView], spacing: CGFloat = 10) -> NSStackView {
    let s = NSStackView(views: views); s.orientation = .horizontal; s.distribution = .fill; s.alignment = .centerY; s.spacing = spacing; return s
}
func column(_ views: [NSView], spacing: CGFloat = 10) -> NSStackView {
    let s = NSStackView(views: views); s.orientation = .vertical; s.alignment = .leading; s.spacing = spacing; return s
}
func spacer() -> NSView { let v = NSView(); v.setContentHuggingPriority(.init(1), for: .horizontal); return v }
func pin(_ child: NSView, to parent: NSView, inset: CGFloat = 0) {
    child.translatesAutoresizingMaskIntoConstraints = false; parent.addSubview(child)
    NSLayoutConstraint.activate([child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset), child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset), child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset), child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)])
}
final class BackgroundView: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) { NSColor.windowBackgroundColor.setFill(); bounds.fill() }
}
final class Card: NSView {
    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true; layer?.cornerRadius = 14; layer?.borderWidth = 1; updateColors() }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateColors() }
    private func updateColors() { effectiveAppearance.performAsCurrentDrawingAppearance { layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor; layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor } }
}
final class StatCard: NSView {
    let value = label("—", 25, .semibold)
    init(_ title: String, _ symbol: String, _ color: NSColor) {
        super.init(frame: .zero)
        let card = Card(); pin(card, to: self)
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()); icon.contentTintColor = color
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        let heading = row([icon, label(title, 11, .medium, secondary: true)], spacing: 8)
        value.font = .monospacedDigitSystemFont(ofSize: 25, weight: .semibold)
        let body = column([heading, value], spacing: 9); pin(body, to: card, inset: 16)
        heightAnchor.constraint(equalToConstant: 95).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
}

struct MapTile { let rect: NSRect; let entry: Entry?; let bytes: Double }
func treemap(_ entries: [Entry], logical: Bool, in rect: NSRect) -> [MapTile] {
    let sorted = entries.filter { (logical ? $0.logical : $0.allocated) > 0 }.sorted { (logical ? $0.logical : $0.allocated) > (logical ? $1.logical : $1.allocated) }
    var items: [(Entry?, Double)] = sorted.prefix(600).map { ($0, Double(logical ? $0.logical : $0.allocated)) }
    let remainder = sorted.dropFirst(600).reduce(0.0) { $0 + Double(logical ? $1.logical : $1.allocated) }
    if remainder > 0 { items.append((nil, remainder)) }
    var tiles: [MapTile] = []
    func divide(_ list: ArraySlice<(Entry?, Double)>, _ r: NSRect) {
        guard !list.isEmpty, r.width > 0, r.height > 0 else { return }
        if list.count == 1 { tiles.append(MapTile(rect: r, entry: list.first!.0, bytes: list.first!.1)); return }
        let total = list.reduce(0) { $0 + $1.1 }
        var sum = 0.0, split = list.startIndex + 1
        for i in list.startIndex..<(list.endIndex - 1) { sum += list[i].1; split = i + 1; if sum >= total / 2 { break } }
        let ratio = CGFloat(sum / total)
        if r.width >= r.height {
            let w = r.width * ratio
            divide(list[..<split], NSRect(x: r.minX, y: r.minY, width: w, height: r.height))
            divide(list[split...], NSRect(x: r.minX + w, y: r.minY, width: r.width - w, height: r.height))
        } else {
            let h = r.height * ratio
            divide(list[..<split], NSRect(x: r.minX, y: r.minY, width: r.width, height: h))
            divide(list[split...], NSRect(x: r.minX, y: r.minY + h, width: r.width, height: r.height - h))
        }
    }
    divide(items[...], rect); return tiles
}
final class MapView: NSView {
    var entries: [Entry] = [] { didSet { needsDisplay = true } }
    var logical = false { didSet { needsDisplay = true } }
    var selected: Entry? { didSet { needsDisplay = true } }
    var onSelect: ((Entry) -> Void)?
    var onOpen: ((Entry) -> Void)?
    var onMagnify: ((CGFloat) -> Void)?
    var emptyMessage = "Bir klasör seçerek alan haritasını oluşturun."
    private(set) var boxes: [MapTile] = []
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); bounds.fill(); removeAllToolTips()
        boxes = treemap(entries, logical: logical, in: bounds.insetBy(dx: 5, dy: 5))
        guard !boxes.isEmpty else {
            let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 14)]
            let text = emptyMessage as NSString; let s = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: max(18, (bounds.width - s.width) / 2), y: bounds.height / 2), withAttributes: attrs)
            return
        }
        let total = boxes.reduce(0) { $0 + $1.bytes }
        for tile in boxes {
            let r = tile.rect.insetBy(dx: 2, dy: 2)
            guard r.width > 0, r.height > 0 else { continue }
            (tile.entry.map(colorFor) ?? .darkGray).setFill()
            let shape = NSBezierPath(roundedRect: r, xRadius: 7, yRadius: 7); shape.fill()
            NSColor.white.withAlphaComponent(0.15).setStroke(); shape.lineWidth = 1; shape.stroke()
            if let e = tile.entry {
                addToolTip(r, owner: self, userData: nil)
                if e === selected { NSColor.white.setStroke(); let border = NSBezierPath(roundedRect: r.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5); border.lineWidth = 3; border.stroke() }
            }
            guard r.width > 65 && r.height > 31 else { continue }
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingMiddle
            let name = tile.entry.map { ($0.folder ? "▸ " : "") + $0.name } ?? "Diğer öğeler"
            (name as NSString).draw(in: NSRect(x: r.minX + 10, y: r.minY + 10, width: r.width - 20, height: 19), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: style])
            if r.height > 58 {
                let sub = sizeText(Int64(tile.bytes)) + (r.width > 160 ? String(format: "  ·  %.1f%%", tile.bytes / total * 100) : "")
                (sub as NSString).draw(in: NSRect(x: r.minX + 10, y: r.minY + 33, width: r.width - 20, height: 17), withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.85), .paragraphStyle: style])
            }
        }
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let e = boxes.first(where: { $0.rect.contains(point) })?.entry { onSelect?(e); if event.clickCount == 2 { onOpen?(e) } }
    }
    override func magnify(with event: NSEvent) { onMagnify?(event.magnification) }
    @objc func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard let e = boxes.first(where: { $0.rect.contains(point) })?.entry else { return "Diğer öğeleri klasör ağacında inceleyebilirsiniz." }
        return "\(e.url.path)\nDiskte: \(sizeText(e.allocated)) · Mantıksal: \(sizeText(e.logical))\(e.folder ? "\nÇift tıklayarak klasöre girin." : "")"
    }
}
final class MapPanel: NSView {
    let map = MapView()
    let scroll = NSScrollView()
    let title = label("Alan haritası", 16, .semibold)
    let subtitle = label("Kutuların alanı dosya ve klasör boyutunu gösterir.", 11, secondary: true)
    let percent = label("100%", 11, .medium, secondary: true)
    let legend = row([], spacing: 14)
    private var resizeObserver: NSObjectProtocol?
    private(set) var zoom: CGFloat = 1
    var onEnlarge: (() -> Void)?
    lazy var minus = button("", "minus.magnifyingglass", target: self, action: #selector(zoomOut))
    lazy var plus = button("", "plus.magnifyingglass", target: self, action: #selector(zoomIn))
    lazy var fit = button("Sığdır", "arrow.down.right.and.arrow.up.left", target: self, action: #selector(resetZoom))
    lazy var enlarge = button("Büyüt", "arrow.up.left.and.arrow.down.right", target: self, action: #selector(openLarge))
    init(standalone: Bool = false) {
        super.init(frame: .zero)
        minus.toolTip = "Uzaklaştır (⌘−)"; minus.setAccessibilityLabel("Uzaklaştır")
        plus.toolTip = "Yakınlaştır (⌘+)"; plus.setAccessibilityLabel("Yakınlaştır")
        fit.toolTip = "Haritayı pencereye sığdır (⌘0)"; enlarge.toolTip = "Haritayı ayrı büyük pencerede aç"
        percent.widthAnchor.constraint(equalToConstant: 42).isActive = true
        let controls = row(standalone ? [minus, percent, plus, fit] : [minus, percent, plus, fit, enlarge], spacing: 5)
        let headings = column([title, subtitle], spacing: 4)
        let header = row([headings, spacer(), controls], spacing: 8)
        headings.setContentCompressionResistancePriority(.init(100), for: .horizontal)
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = false; scroll.scrollerStyle = .overlay; scroll.documentView = map
        scroll.contentView.postsFrameChangedNotifications = true
        resizeObserver = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in self?.resizeCanvas() }
        map.onMagnify = { [weak self] delta in guard let self = self else { return }; self.setZoom(self.zoom * (1 + delta)) }
        let hint = label("Çift tık: klasöre gir  ·  Yakınlaştırınca kaydırarak gezin", 11, secondary: true)
        let stack = column([header, scroll, legend, hint], spacing: 12); pin(stack, to: self, inset: 16)
        for v in [header, scroll, legend, hint] { v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        legend.heightAnchor.constraint(equalToConstant: 20).isActive = true
        map.setAccessibilityLabel("Dosya ve klasörlerin alan haritası. Öğelere klavyeyle erişmek için klasör ağacını kullanın.")
        updateControls()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { if let observer = resizeObserver { NotificationCenter.default.removeObserver(observer) } }
    override func layout() { super.layout(); resizeCanvas() }
    func resizeCanvas() {
        let viewport = scroll.contentView.bounds.size
        let size = NSSize(width: max(1, viewport.width) * zoom, height: max(1, viewport.height) * zoom)
        if map.frame.size != size { map.setFrameSize(size); map.needsDisplay = true }
    }
    func setZoom(_ value: CGFloat) {
        let oldSize = map.frame.size
        let visible = scroll.contentView.bounds
        let center = NSPoint(x: visible.midX / max(oldSize.width, 1), y: visible.midY / max(oldSize.height, 1))
        zoom = min(4, max(1, value)); resizeCanvas()
        let x = max(0, min(map.frame.width - visible.width, center.x * map.frame.width - visible.width / 2))
        let y = max(0, min(map.frame.height - visible.height, center.y * map.frame.height - visible.height / 2))
        scroll.contentView.scroll(to: NSPoint(x: x, y: y)); scroll.reflectScrolledClipView(scroll.contentView); updateControls()
    }
    func updateControls() { percent.stringValue = "\(Int((zoom * 100).rounded()))%"; minus.isEnabled = zoom > 1; plus.isEnabled = zoom < 4; fit.isEnabled = zoom > 1 }
    @objc func zoomIn() { setZoom(zoom * 1.25) }
    @objc func zoomOut() { setZoom(zoom / 1.25) }
    @objc func resetZoom() { setZoom(1); scroll.contentView.scroll(to: .zero) }
    @objc func openLarge() { onEnlarge?() }
    func show(_ entry: Entry?, logical: Bool, reset: Bool) {
        map.entries = entry?.children ?? []; map.logical = logical
        title.stringValue = entry?.name ?? "Alan haritası"
        title.toolTip = entry?.url.path
        let count = entry?.children.count ?? 0
        subtitle.stringValue = entry == nil ? "Bir klasör seçerek başlayın." : "\(count.formatted()) öğe · \(logical ? "Mantıksal boyut" : "Diskte kapladığı alan")"
        map.emptyMessage = entry == nil ? "Bir klasör seçerek alan haritasını oluşturun." : "Bu klasörde gösterilecek alan yok."
        legend.arrangedSubviews.forEach { legend.removeArrangedSubview($0); $0.removeFromSuperview() }
        for e in (entry?.children ?? []).filter({ (logical ? $0.logical : $0.allocated) > 0 }).prefix(3) {
            let dot = NSView(); dot.wantsLayer = true; dot.layer?.cornerRadius = 3; dot.layer?.backgroundColor = colorFor(e).cgColor
            dot.widthAnchor.constraint(equalToConstant: 9).isActive = true; dot.heightAnchor.constraint(equalToConstant: 9).isActive = true
            let name = label(e.name, 10, secondary: true); name.widthAnchor.constraint(lessThanOrEqualToConstant: 130).isActive = true
            legend.addArrangedSubview(row([dot, name], spacing: 5))
        }
        legend.addArrangedSubview(spacer())
        if reset { resetZoom() }
    }
}

// MARK: - Application
final class App: NSObject, NSApplicationDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var window: NSWindow!
    let outline = NSOutlineView()
    let panel = MapPanel()
    let path = label("Alan kullanımını keşfedin", 12, secondary: true)
    let status = label("Başlamak için bir klasör seçin.", 11, secondary: true)
    let detail = label("Bir öğe seçerek ayrıntılarını görün.", 12)
    let selectionTitle = label("SEÇİLİ ÖĞE", 10, .semibold, secondary: true)
    let allocatedCard = StatCard("DİSKTE KAPLADIĞI", "internaldrive", .systemBlue)
    let logicalCard = StatCard("MANTIKSAL BOYUT", "doc", .systemTeal)
    let filesCard = StatCard("DOSYA SAYISI", "square.stack.3d.up", .systemPurple)
    let meter = NSProgressIndicator()
    let mode = NSSegmentedControl(labels: ["Diskte kapladığı", "Mantıksal boyut"], trackingMode: .selectOne, target: nil, action: nil)
    lazy var choose = button("Klasör seç…", "folder.badge.plus", target: self, action: #selector(pick))
    lazy var cancel = button("Durdur", "stop.circle", target: self, action: #selector(stop))
    lazy var refresh = button("", "arrow.clockwise", target: self, action: #selector(rescan))
    lazy var up = button("", "arrow.up", target: self, action: #selector(goUp))
    lazy var home = button("", "house", target: self, action: #selector(goRoot))
    lazy var reveal = button("Finder’da göster", "arrow.up.forward.square", target: self, action: #selector(showFinder))
    lazy var export = button("CSV aktar…", "square.and.arrow.up", target: self, action: #selector(saveCSV))
    var root: Entry?, current: Entry?, selected: Entry?, scanner: Scanner?
    var lastURL: URL?
    var chartWindow: NSWindow?
    var largePanel: MapPanel?
    var logical: Bool { mode.selectedSegment == 1 }
    var activePanel: MapPanel { chartWindow?.isKeyWindow == true ? (largePanel ?? panel) : panel }
    func applicationDidFinishLaunching(_ notification: Notification) {
        build(show: true)
        if CommandLine.arguments.contains("--demo") { loadDemo() }
        else if CommandLine.arguments.count > 1 { start(URL(fileURLWithPath: CommandLine.arguments[1])) }
    }
    func build(show: Bool) {
        NSApp.setActivationPolicy(.regular); buildMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "MacSizeExplorer"; window.minSize = NSSize(width: 1060, height: 690)
        window.collectionBehavior = [.fullScreenPrimary]; window.center(); window.isReleasedWhenClosed = false
        let body = BackgroundView(); window.contentView = body
        let title = label("MacSizeExplorer", 25, .bold)
        let subtitle = label("Diskinizde neyin yer kapladığını görün.", 12, secondary: true)
        let branding = column([title, subtitle], spacing: 4)
        let toolbar = row([branding, spacer(), choose, refresh, cancel, export], spacing: 9)
        choose.bezelColor = .controlAccentColor
        refresh.setAccessibilityLabel("Yeniden tara"); refresh.toolTip = "Seçili kök klasörü yeniden tara (⌘R)"
        up.setAccessibilityLabel("Üst klasör"); up.toolTip = "Üst klasöre git (⌘↑)"
        home.setAccessibilityLabel("Tarama köküne dön"); home.toolTip = "Tarama köküne dön"
        path.isSelectable = true
        mode.selectedSegment = 0; mode.target = self; mode.action = #selector(changeMode)
        mode.widthAnchor.constraint(equalToConstant: 250).isActive = true
        reveal.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let location = row([home, up, path, mode], spacing: 8)
        path.setContentCompressionResistancePriority(.init(100), for: .horizontal)
        let stats = row([allocatedCard, logicalCard, filesCard], spacing: 12); stats.distribution = .fillEqually
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")); name.title = "Klasör / Dosya"; name.width = 220; name.minWidth = 130
        let size = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size")); size.title = "Boyut ↓"; size.width = 90; size.minWidth = 75
        outline.addTableColumn(name); outline.addTableColumn(size); outline.outlineTableColumn = name
        outline.delegate = self; outline.dataSource = self; outline.rowHeight = 32
        outline.style = .sourceList; outline.usesAlternatingRowBackgroundColors = false; outline.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outline.target = self; outline.doubleAction = #selector(drillTree); scroll.documentView = outline
        let treeHeader = row([label("Klasörler", 15, .semibold), spacer(), label("Büyükten küçüğe", 10, secondary: true)])
        let treeBody = column([treeHeader, scroll], spacing: 12)
        scroll.widthAnchor.constraint(equalTo: treeBody.widthAnchor).isActive = true
        treeHeader.widthAnchor.constraint(equalTo: treeBody.widthAnchor).isActive = true
        let treeCard = Card(); pin(treeBody, to: treeCard, inset: 14)
        let mapCard = Card(); pin(panel, to: mapCard)
        let split = NSSplitView(); split.isVertical = true; split.dividerStyle = .thin
        split.addArrangedSubview(treeCard); split.addArrangedSubview(mapCard)
        treeCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 290).isActive = true
        treeCard.widthAnchor.constraint(lessThanOrEqualToConstant: 420).isActive = true
        mapCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 570).isActive = true
        let selectionCard = Card()
        detail.isSelectable = true; detail.setContentCompressionResistancePriority(.init(100), for: .horizontal)
        let info = column([selectionTitle, detail], spacing: 5)
        info.setContentHuggingPriority(.init(1), for: .horizontal)
        info.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        detail.widthAnchor.constraint(equalTo: info.widthAnchor).isActive = true
        let selectionRow = row([info, reveal]); pin(selectionRow, to: selectionCard, inset: 12)
        meter.style = .bar; meter.isIndeterminate = true; meter.isHidden = true
        let note = label("Salt okunur tarama · APFS’de paylaşılan bloklar ve anlık görüntüler nedeniyle boşaltılabilir alan farklı olabilir.", 10, secondary: true)
        let stack = column([toolbar, location, stats, split, selectionCard, meter, status, note], spacing: 14)
        pin(stack, to: body, inset: 20)
        for v in [toolbar, location, stats, split, selectionCard, meter, status, note] { v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        split.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        configure(panel); panel.onEnlarge = { [weak self] in self?.openLargeChart() }
        updateButtons()
        body.layoutSubtreeIfNeeded(); split.setPosition(350, ofDividerAt: 0)
        if show { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    }
    func configure(_ p: MapPanel) {
        p.map.onSelect = { [weak self] e in self?.select(e) }
        p.map.onOpen = { [weak self] e in if e.folder { self?.navigate(e) } }
    }
    func buildMenu() {
        let menu = NSMenu()
        func add(_ title: String, _ entries: [(String, Selector, String)]) {
            let item = NSMenuItem(); let sub = NSMenu(title: title)
            for (name, action, key) in entries { let entry = sub.addItem(withTitle: name, action: action, keyEquivalent: key); entry.target = self }
            item.submenu = sub; menu.addItem(item)
        }
        let appItem = NSMenuItem(); let appMenu = NSMenu(); appMenu.addItem(withTitle: "MacSizeExplorer’ı kapat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = appMenu; menu.addItem(appItem)
        add("Dosya", [("Klasör seç…", #selector(pick), "o"), ("Yeniden tara", #selector(rescan), "r"), ("CSV aktar…", #selector(saveCSV), "s")])
        let editItem = NSMenuItem(); let edit = NSMenu(title: "Düzen"); edit.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c"); edit.addItem(withTitle: "Tümünü seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"); editItem.submenu = edit; menu.addItem(editItem)
        add("Görünüm", [("Yakınlaştır", #selector(zoomIn), "+"), ("Uzaklaştır", #selector(zoomOut), "-"), ("Pencereye sığdır", #selector(fitChart), "0"), ("Haritayı büyük pencerede aç", #selector(openLargeChart), "2"), ("Üst klasör", #selector(goUp), String(UnicodeScalar(NSUpArrowFunctionKey)!)), ("Tam ekran", #selector(fullscreen), "f")])
        NSApp.mainMenu = menu
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { scanner?.cancel() }
    @objc func pick() {
        guard scanner == nil else { return }
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false
        p.prompt = "Tara"; p.message = "İncelemek istediğiniz klasörü veya diski seçin."
        p.beginSheetModal(for: window) { [weak self] response in if response == .OK, let url = p.url { self?.start(url) } }
    }
    @objc func rescan() { if let url = lastURL, scanner == nil { start(url) } }
    func start(_ url: URL) {
        guard scanner == nil else { return }
        let job = Scanner(); scanner = job; lastURL = url
        root = nil; current = nil; selected = nil; outline.reloadData(); updateCharts(reset: true)
        path.stringValue = url.path; path.toolTip = url.path
        allocatedCard.value.stringValue = "Taranıyor…"; logicalCard.value.stringValue = "—"; filesCard.value.stringValue = "—"
        detail.stringValue = "Dosyalar değiştirilmeden inceleniyor."
        meter.isHidden = false; meter.startAnimation(nil); updateButtons()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = job.scan(url) { count, name in DispatchQueue.main.async { [weak self] in self?.status.stringValue = "\(count.formatted()) öğe · \(name)" } }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scanner = nil; self.meter.stopAnimation(nil); self.meter.isHidden = true
                if result.cancelled { self.allocatedCard.value.stringValue = "Durduruldu"; self.status.stringValue = "Yeni bir klasör seçin veya yeniden tarayın."; self.updateButtons(); return }
                self.root = result.root; self.sortTree(result.root); self.outline.reloadData(); self.outline.expandItem(result.root)
                self.navigate(result.root)
                self.status.stringValue = "Tamamlandı · \(result.errors) erişim/okuma hatası · \(result.skippedVolumes) farklı disk atlandı · \(result.hardlinks) sabit bağlantı tek sayıldı"
                self.status.textColor = result.errors > 0 ? .systemOrange : .secondaryLabelColor
                if result.errors > 0 { self.status.toolTip = "Bazı içerikler okunamadı; toplam eksik olabilir. Gerekirse Sistem Ayarları → Gizlilik ve Güvenlik → Tam Disk Erişimi’nden izin verip yeniden tarayın." }
                self.updateButtons()
            }
        }
    }
    @objc func stop() { scanner?.cancel(); cancel.isEnabled = false; status.stringValue = "Tarama durduruluyor…" }
    func updateButtons() {
        let idle = scanner == nil
        choose.isEnabled = idle; refresh.isEnabled = idle && lastURL != nil; cancel.isEnabled = !idle
        up.isEnabled = idle && current?.parent != nil; home.isEnabled = idle && root != nil && current !== root
        reveal.isEnabled = idle && selected != nil; export.isEnabled = idle && root != nil; mode.isEnabled = idle
        panel.enlarge.isEnabled = root != nil
    }
    func updateCharts(reset: Bool) {
        for p in [panel, largePanel].compactMap({ $0 }) { p.show(current, logical: logical, reset: reset); p.map.selected = selected }
        chartWindow?.title = "MacSizeExplorer — \(current?.name ?? "Alan haritası")"
    }
    func navigate(_ e: Entry) {
        guard e.folder else { select(e); return }
        let changed = current !== e; current = e
        path.stringValue = e.url.path; path.toolTip = e.url.path
        allocatedCard.value.stringValue = sizeText(e.allocated); logicalCard.value.stringValue = sizeText(e.logical); filesCard.value.stringValue = e.files.formatted()
        select(e); updateCharts(reset: changed); updateButtons()
    }
    func select(_ e: Entry) {
        selected = e; panel.map.selected = e; largePanel?.map.selected = e
        selectionTitle.stringValue = e.folder ? "SEÇİLİ KLASÖR" : "SEÇİLİ DOSYA"
        detail.stringValue = "\(e.name) · Diskte: \(sizeText(e.allocated)) · Mantıksal: \(sizeText(e.logical))"
        detail.toolTip = e.url.path; updateButtons()
    }
    @objc func goUp() { if let p = current?.parent { navigate(p) } }
    @objc func goRoot() { if let e = root { navigate(e) } }
    @objc func showFinder() { if let e = selected { NSWorkspace.shared.activateFileViewerSelecting([e.url]) } }
    @objc func drillTree() { guard outline.clickedRow >= 0 else { return }; if let e = outline.item(atRow: outline.clickedRow) as? Entry, e.folder { navigate(e) } }
    func sortTree(_ e: Entry) {
        e.children.sort { let a = logical ? $0.logical : $0.allocated; let b = logical ? $1.logical : $1.allocated; return a == b ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : a > b }
        for c in e.children where c.folder { sortTree(c) }
    }
    @objc func changeMode() { if let e = root { sortTree(e) }; outline.reloadData(); updateCharts(reset: false) }
    @objc func zoomIn() { activePanel.zoomIn() }
    @objc func zoomOut() { activePanel.zoomOut() }
    @objc func fitChart() { activePanel.resetZoom() }
    @objc func fullscreen() { (chartWindow?.isKeyWindow == true ? chartWindow : window)?.toggleFullScreen(nil) }
    @objc func openLargeChart() {
        guard root != nil else { return }
        if chartWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.minSize = NSSize(width: 700, height: 480); w.isReleasedWhenClosed = false; w.collectionBehavior = [.fullScreenPrimary]
            let p = MapPanel(standalone: true); configure(p)
            let container = BackgroundView(); w.contentView = container
            let back = button("Üst klasör", "arrow.up", target: self, action: #selector(goUp))
            let help = label("Klasöre çift tıklayın · ⌘0: sığdır · ⌘F: tam ekran", 11, secondary: true)
            let nav = row([back, spacer(), help]); let stack = column([nav, p], spacing: 6); pin(stack, to: container, inset: 12)
            p.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true; nav.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            chartWindow = w; largePanel = p; w.center()
        }
        updateCharts(reset: false); chartWindow?.makeKeyAndOrderFront(nil)
    }
    func outlineView(_ v: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int { (item as? Entry)?.children.count ?? (root == nil ? 0 : 1) }
    func outlineView(_ v: NSOutlineView, child i: Int, ofItem item: Any?) -> Any { if let e = item as? Entry { return e.children[i] }; return root! }
    func outlineView(_ v: NSOutlineView, isItemExpandable item: Any) -> Bool { (item as? Entry)?.children.isEmpty == false }
    func outlineView(_ v: NSOutlineView, viewFor col: NSTableColumn?, item: Any) -> NSView? {
        guard let e = item as? Entry else { return nil }
        if col?.identifier.rawValue == "size" {
            let text = label(sizeText(logical ? e.logical : e.allocated), 11, secondary: true)
            text.alignment = .right; text.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular); text.toolTip = e.url.path; return text
        }
        let icon = NSImageView(image: NSImage(systemSymbolName: e.folder ? "folder.fill" : "doc", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = e.folder ? .systemBlue : .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        let text = label(e.name, 12, e.folder ? .medium : .regular)
        text.setContentCompressionResistancePriority(.init(100), for: .horizontal)
        let cell = row([icon, text], spacing: 7); cell.toolTip = e.url.path; return cell
    }
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard outline.selectedRow >= 0, let e = outline.item(atRow: outline.selectedRow) as? Entry else { return }
        if e.folder { navigate(e) } else { select(e) }
    }
    @objc func saveCSV() {
        guard let root = root, scanner == nil else { return }
        let p = NSSavePanel(); p.nameFieldStringValue = "MacSizeExplorer.csv"; p.allowedContentTypes = [.commaSeparatedText]
        p.beginSheetModal(for: window) { response in
            guard response == .OK, let url = p.url else { return }
            // Values that spreadsheet software might interpret as formulas are escaped.
            func quote(_ s: String) -> String {
                let safe = ["=", "+", "-", "@", "\t", "\r", "\n"].contains(where: { s.hasPrefix($0) }) ? "'" + s : s
                return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            var lines = ["path,type,allocated_bytes,logical_bytes,file_count"]
            func visit(_ e: Entry) { lines.append("\(quote(e.url.path)),\(e.folder ? "folder" : "file"),\(e.allocated),\(e.logical),\(e.files)"); for c in e.children { visit(c) } }
            visit(root)
            do { try lines.joined(separator: "\r\n").write(to: url, atomically: true, encoding: .utf8) }
            catch { NSAlert(error: error).beginSheetModal(for: self.window) }
        }
    }
    func loadDemo() {
        let e = Entry(URL(fileURLWithPath: "/Demo/Örnek Disk"), folder: true)
        for (name, amount) in [("Videolar", 42), ("Projeler", 23), ("Fotoğraflar", 16), ("Uygulamalar", 10), ("Belgeler", 6), ("Arşiv.zip", 3)] {
            let c = Entry(e.url.appendingPathComponent(name), folder: !name.contains(".")); c.parent = e
            if c.folder {
                for i in 1...4 { let f = Entry(c.url.appendingPathComponent("Örnek-\(i).dat"), folder: false); f.parent = c; f.allocated = Int64(amount) * 250_000_000; f.logical = f.allocated; f.files = 1; c.children.append(f) }
                c.allocated = c.children.reduce(0) { $0 + $1.allocated }; c.files = 4
            } else { c.allocated = Int64(amount) * 1_000_000_000; c.files = 1 }
            c.logical = c.allocated; e.children.append(c); e.allocated += c.allocated; e.logical += c.logical; e.files += c.files
        }
        root = e; sortTree(e); outline.reloadData(); outline.expandItem(e); navigate(e)
        status.stringValue = "ÖRNEK VERİ · Bu görünüm gerçek dosyalarınızdan oluşturulmamıştır."
    }
}

func selfTest() {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("MacSizeExplorer-test-\(UUID().uuidString)")
    do {
        try fm.createDirectory(at: dir.appendingPathComponent("nested"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let a = dir.appendingPathComponent("a.bin")
        try Data(repeating: 7, count: 12345).write(to: a)
        try Data(repeating: 1, count: 54321).write(to: dir.appendingPathComponent("nested/b.bin"))
        try Data().write(to: dir.appendingPathComponent("empty"))
        try fm.linkItem(at: a, to: dir.appendingPathComponent("hardlink"))
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("loop").path, withDestinationPath: dir.path)
        let scan = Scanner().scan(dir) { _, _ in }
        precondition(scan.root.logical == 66666, "Hard links must be counted once")
        precondition(scan.root.files == 4 && scan.hardlinks == 1 && scan.errors == 0)
        precondition(scan.root.children.count == 4, "Symbolic link must be skipped")
        precondition(scan.root.children.reduce(Int64(0)) { $0 + $1.allocated } == scan.root.allocated)
        precondition(scan.root.children.first(where: { $0.name == "nested" })?.children.first?.parent?.name == "nested")
        let cancelled = Scanner(); cancelled.cancel(); precondition(cancelled.scan(dir) { _, _ in }.cancelled)
        let missing = Scanner().scan(dir.appendingPathComponent("missing")) { _, _ in }; precondition(missing.errors == 1)
        print("PASS: byte totals, hard-link deduplication, symlink cycle exclusion, nested totals, parent navigation, cancellation, missing-path errors")
    } catch { fputs("Self-test failed: \(error)\n", stderr); exit(1) }
}
func renderingTests(_ destination: String) {
    let app = NSApplication.shared
    app.finishLaunching()
    let controller = App(); app.delegate = controller; controller.build(show: true); controller.loadDemo()
    let dir = URL(fileURLWithPath: destination, isDirectory: true)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    func capture(_ view: NSView, _ file: String) {
        view.layoutSubtreeIfNeeded()
        controller.panel.resizeCanvas(); controller.largePanel?.resizeCanvas()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.12))
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("Cannot render view") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try! bitmap.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(file))
    }
    let root = controller.root!
    let tiles = treemap(root.children, logical: false, in: NSRect(x: 0, y: 0, width: 1000, height: 600))
    precondition(tiles.count == 6)
    precondition(abs(tiles.reduce(0) { $0 + $1.rect.width * $1.rect.height } - 600000) < 0.01)
    for tile in tiles { precondition(abs(tile.rect.width * tile.rect.height / 600000 - tile.bytes / Double(root.allocated)) < 0.000001) }
    // More than 600 entries retain their total area through the aggregate tile.
    var many: [Entry] = []
    for i in 0..<800 { let e = Entry(URL(fileURLWithPath: "/Demo/f\(i)"), folder: false); e.allocated = 1; many.append(e) }
    let capped = treemap(many, logical: false, in: NSRect(x: 0, y: 0, width: 800, height: 600))
    precondition(capped.count == 601 && capped.reduce(0) { $0 + $1.bytes } == 800)
    for (theme, name) in [(NSAppearance.Name.aqua, "preview-light.png"), (.darkAqua, "preview-dark.png")] {
        controller.window.appearance = NSAppearance(named: theme)
        capture(controller.window.contentView!, name)
    }
    let p = controller.panel; p.layoutSubtreeIfNeeded(); p.resizeCanvas()
    let base = p.map.frame.size
    p.zoomIn(); p.zoomIn()
    precondition(p.zoom > 1.5 && p.map.frame.width > base.width * 1.5)
    p.setZoom(100); precondition(p.zoom == 4 && !p.plus.isEnabled)
    capture(controller.window.contentView!, "preview-zoom.png")
    p.zoomOut(); precondition(p.zoom < 4)
    p.resetZoom(); precondition(p.zoom == 1 && !p.minus.isEnabled && p.map.frame.size == base)
    controller.openLargeChart()
    controller.chartWindow!.appearance = NSAppearance(named: .darkAqua)
    capture(controller.chartWindow!.contentView!, "preview-large.png")
    let child = root.children.first(where: { $0.folder })!
    controller.navigate(child)
    precondition(controller.largePanel!.map.entries.count == child.children.count)
    precondition(controller.panel.map.entries.first === child.children.first)
    controller.largePanel!.setZoom(2)
    controller.goUp()
    precondition(controller.current === root && controller.largePanel!.zoom == 1)
    controller.mode.selectedSegment = 1; controller.changeMode()
    precondition(controller.panel.map.logical && controller.largePanel!.map.logical)
    controller.navigate(child); controller.goRoot(); precondition(controller.current === root)
    controller.window.setContentSize(NSSize(width: 1060, height: 690))
    capture(controller.window.contentView!, "preview-minimum.png")
    precondition(controller.panel.scroll.contentView.bounds.width > 300)
    controller.chartWindow?.orderOut(nil)
    print("PASS: proportional tile geometry, aggregate area, 100–400% zoom limits, fit, separate window, synchronized navigation, size-mode synchronization, minimum layout, light/dark rendering")
}
if CommandLine.arguments.contains("--self-test") { selfTest() }
else if let index = CommandLine.arguments.firstIndex(of: "--ui-test"), CommandLine.arguments.count > index + 1 { renderingTests(CommandLine.arguments[index + 1]) }
else { let app = NSApplication.shared; let delegate = App(); app.delegate = delegate; app.run() }
