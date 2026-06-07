import AppKit
import Foundation

final class ClipboardHistoryStore {
    static let maxItems = 12

    private let pasteboard = NSPasteboard.general
    private let saveURL: URL
    private var timer: Timer?
    private var lastChangeCount: Int
    private var observers: [([ClipboardItem]) -> Void] = []

    private(set) var items: [ClipboardItem] = [] {
        didSet {
            save()
            notifyObservers()
        }
    }

    init() {
        lastChangeCount = pasteboard.changeCount
        saveURL = Self.makeSaveURL()
        load()
        captureCurrentClipboard()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    func observe(_ observer: @escaping ([ClipboardItem]) -> Void) {
        observers.append(observer)
        observer(items)
    }

    func clear() {
        items.removeAll()
    }

    func writeToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        add(text: item.text, createdAt: item.createdAt)
    }

    private func pollPasteboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = changeCount
        captureCurrentClipboard()
    }

    private func captureCurrentClipboard() {
        guard let text = pasteboard.string(forType: .string) else {
            return
        }

        let cleaned = sanitize(text)
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        add(text: cleaned)
    }

    private func add(text: String, createdAt: Date = Date()) {
        let cleaned = sanitize(text)
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        items.removeAll { $0.text == cleaned }
        items.insert(ClipboardItem(text: cleaned, createdAt: createdAt), at: 0)

        if items.count > Self.maxItems {
            items.removeLast(items.count - Self.maxItems)
        }
    }

    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{0000}", with: "")
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else {
            return
        }

        do {
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: saveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            NSLog("Failed to save clipboard history: \(error)")
        }
    }

    private func notifyObservers() {
        observers.forEach { $0(items) }
    }

    private static func makeSaveURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return appSupport
            .appendingPathComponent("GlobalClipboard", isDirectory: true)
            .appendingPathComponent("history.json")
    }
}
