import AppKit
import ApplicationServices

enum AccessibilityPermission {
    private struct ResetError: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }

    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestPrompt() {
        _ = isTrusted(prompt: true)
    }

    static func resetAuthorization() throws {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw ResetError(message: "无法读取应用 Bundle ID。")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleIdentifier]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ResetError(message: message?.isEmpty == false ? message! : "刷新辅助功能权限记录失败。")
        }
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
