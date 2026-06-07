import AppKit
import Carbon

final class ClipboardHistoryPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true {
            return
        }

        super.keyDown(with: event)
    }
}

final class HistoryRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let onChoose: () -> Void
    private var trackingAreaRef: NSTrackingArea?
    private var isHovering = false

    var isSelected = false {
        didSet {
            updateAppearance()
        }
    }

    init(item: ClipboardItem, onChoose: @escaping () -> Void) {
        self.onChoose = onChoose
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 7

        titleLabel.stringValue = item.previewText
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 3
        titleLabel.textColor = .labelColor
        titleLabel.usesSingleLineMode = false
        titleLabel.cell?.wraps = true
        titleLabel.cell?.isScrollable = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(titleLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 76),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingAreaRef = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        onChoose()
    }

    private func updateAppearance() {
        if isSelected {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.20).cgColor
        } else if isHovering {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

final class ClipboardPanelController {
    private let panel: ClipboardHistoryPanel
    private let rootView = NSVisualEffectView()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let headerLabel = NSTextField(labelWithString: "剪贴板历史")
    private let hintLabel = NSTextField(labelWithString: "↑↓ 选择 · Enter 粘贴 · Esc 关闭")
    private var rowViews: [HistoryRowView] = []
    private var items: [ClipboardItem] = []
    private var selectedIndex = 0
    private var onChoose: ((ClipboardItem) -> Void)?
    private var onClose: (() -> Void)?
    private var outsideClickMonitor: Any?

    init() {
        panel = ClipboardHistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        rootView.material = .popover
        rootView.blendingMode = .withinWindow
        rootView.state = .active
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 10
        rootView.layer?.masksToBounds = true

        let headerStack = NSStackView(views: [headerLabel, hintLabel])
        headerStack.orientation = .vertical
        headerStack.spacing = 2
        headerStack.alignment = .leading
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        headerLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.lineBreakMode = .byTruncatingTail

        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = stackView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(headerStack)
        rootView.addSubview(scrollView)
        panel.contentView = rootView

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            headerStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -14),

            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -8),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        panel.keyHandler = { [weak self] event in
            self?.handleKey(event) ?? false
        }
    }

    func show(
        items: [ClipboardItem],
        near point: NSPoint,
        onChoose: @escaping (ClipboardItem) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.items = items
        self.onChoose = onChoose
        self.onClose = onClose
        selectedIndex = items.isEmpty ? -1 : 0

        renderRows()

        let panelSize = fittedPanelSize(for: items.count, near: point)
        panel.setFrame(positionedFrame(size: panelSize, near: point), display: true)

        panel.makeKeyAndOrderFront(nil)
        beginOutsideClickMonitoring()
    }

    func close() {
        endOutsideClickMonitoring()
        panel.orderOut(nil)
        onClose?()
    }

    private func beginOutsideClickMonitoring() {
        endOutsideClickMonitoring()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closeIfClickOutside()
            }
        }
    }

    private func endOutsideClickMonitoring() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }

        outsideClickMonitor = nil
    }

    private func closeIfClickOutside() {
        guard panel.isVisible, !panel.frame.contains(NSEvent.mouseLocation) else {
            return
        }

        close()
    }

    private func renderRows() {
        rowViews.removeAll()
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if items.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "复制一些文字后再按 ⌥⌘V")
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.alignment = .center
            stackView.addArrangedSubview(emptyLabel)
            emptyLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            emptyLabel.heightAnchor.constraint(equalToConstant: 76).isActive = true
            return
        }

        for (index, item) in items.enumerated() {
            let row = HistoryRowView(item: item) { [weak self] in
                self?.chooseItem(at: index)
            }
            row.isSelected = index == selectedIndex
            rowViews.append(row)
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
    }

    private func updateSelection() {
        for (index, row) in rowViews.enumerated() {
            row.isSelected = index == selectedIndex
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Escape:
            close()
            return true
        case kVK_UpArrow:
            moveSelection(by: -1)
            return true
        case kVK_DownArrow:
            moveSelection(by: 1)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            chooseItem(at: selectedIndex)
            return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        guard !items.isEmpty else {
            return
        }

        selectedIndex = (selectedIndex + delta + items.count) % items.count
        updateSelection()
    }

    private func chooseItem(at index: Int) {
        guard items.indices.contains(index) else {
            return
        }

        let item = items[index]
        endOutsideClickMonitoring()
        panel.orderOut(nil)
        onChoose?(item)
    }

    private func fittedPanelSize(for itemCount: Int, near point: NSPoint) -> NSSize {
        let width: CGFloat = 360
        let headerHeight: CGFloat = 58
        let rowHeight: CGFloat = 80
        let emptyHeight: CGFloat = 96
        let screen = screen(containing: point)
        let maxHeight = max(260, min(500, screen.visibleFrame.height - 24))

        if itemCount == 0 {
            return NSSize(width: width, height: headerHeight + emptyHeight)
        }

        let height = min(headerHeight + CGFloat(itemCount) * rowHeight + 12, maxHeight)
        return NSSize(width: width, height: height)
    }

    private func positionedFrame(size: NSSize, near point: NSPoint) -> NSRect {
        let screen = screen(containing: point)
        let visibleFrame = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let gap: CGFloat = 10
        let anchorInset: CGFloat = 30

        var x = point.x - anchorInset
        if x + size.width > visibleFrame.maxX {
            x = point.x - size.width + anchorInset
        }
        x = clamp(x, lower: visibleFrame.minX, upper: visibleFrame.maxX - size.width)

        let belowY = point.y - size.height - gap
        let aboveY = point.y + gap
        let hasRoomBelow = belowY >= visibleFrame.minY
        let hasRoomAbove = aboveY + size.height <= visibleFrame.maxY
        let y: CGFloat

        if hasRoomBelow {
            y = belowY
        } else if hasRoomAbove {
            y = aboveY
        } else {
            let clampedBelow = clamp(
                belowY,
                lower: visibleFrame.minY,
                upper: visibleFrame.maxY - size.height
            )
            y = clampedBelow
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func screen(containing point: NSPoint) -> NSScreen {
        NSScreen.screens.first { screen in
            NSMouseInRect(point, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
