import Foundation
import Vision
import AppKit

// MARK: - ScreenMemory
/// Searchable screenshot history with OCR
/// Captures, indexes, and searches through all screenshots

@main
struct ScreenMemory {
    static func main() async {
        let memory = ScreenMemoryCore()
        await memory.run()
    }
}

@MainActor
final class ScreenMemoryCore {
    private var screenshots: [Screenshot] = []
    private let screenshotsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Screenshots")
    
    struct Screenshot: Identifiable {
        let id = UUID()
        let path: String
        let timestamp: Date
        let ocrText: String
        let appContext: String
    }
    
    func run() async {
        print("""
        📸 ScreenMemory - Searchable Screenshot History
        
        Commands:
          capture              Take screenshot and index it
          search <query>       Search through all screenshots
          list [n]             List recent screenshots
          watch                Auto-capture every 30 seconds
          export <id>          Export screenshot to desktop
          delete <id>          Delete screenshot
          stats                Show collection statistics
          help                 Show this help
          quit                 Exit
        """)
        
        createScreenshotsDirectory()
        loadExistingScreenshots()
        
        while true {
            print("> ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
            
            let parts = input.split(separator: " ", maxSplits: 1)
            let command = parts.first?.lowercased() ?? ""
            let arg = parts.count > 1 ? String(parts[1]) : ""
            
            switch command {
            case "capture", "c":
                await captureScreenshot()
            case "search", "s", "find":
                await searchScreenshots(query: arg)
            case "list", "ls":
                listScreenshots(count: Int(arg) ?? 10)
            case "watch", "w":
                await watchMode()
            case "export", "e":
                exportScreenshot(id: arg)
            case "delete", "rm":
                deleteScreenshot(id: arg)
            case "stats":
                showStats()
            case "help", "h":
                showHelp()
            case "quit", "q", "exit":
                print("👋 Goodbye!")
                return
            default:
                print("Unknown command. Type 'help' for options.")
            }
        }
    }
    
    func captureScreenshot() async {
        print("📸 Capturing screenshot...")
        
        let timestamp = Date()
        let filename = "screenshot_\(formatTimestamp(timestamp)).png"
        let filepath = screenshotsDir.appendingPathComponent(filename).path
        
        // Use screencapture command
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", filepath] // -x = no sound
        
        try? task.run()
        task.waitUntilExit()
        
        // Perform OCR
        print("🔍 Running OCR...")
        let ocrText = await performOCR(on: filepath)
        
        // Get active app
        let app = getActiveApp()
        
        let screenshot = Screenshot(
            path: filepath,
            timestamp: timestamp,
            ocrText: ocrText,
            appContext: app
        )
        
        screenshots.insert(screenshot, at: 0)
        
        print("✅ Captured and indexed")
        print("   Time: \(formatTime(timestamp))")
        print("   App: \(app)")
        print("   Text found: \(ocrText.prefix(100))\(ocrText.count > 100 ? "..." : "")")
    }
    
    func searchScreenshots(query: String) async {
        guard !query.isEmpty else {
            print("❌ Please enter a search query")
            return
        }
        
        print("🔍 Searching for '\(query)'...")
        
        let results = screenshots.filter { screenshot in
            screenshot.ocrText.lowercased().contains(query.lowercased()) ||
            screenshot.appContext.lowercased().contains(query.lowercased())
        }
        
        if results.isEmpty {
            print("No screenshots found matching '\(query)'")
        } else {
            print("Found \(results.count) screenshot(s):\n")
            for screenshot in results {
                displayScreenshotInfo(screenshot)
            }
        }
    }
    
    func listScreenshots(count: Int) {
        let toShow = min(count, screenshots.count)
        
        print("📸 Recent \(toShow) screenshot(s):\n")
        
        for screenshot in screenshots.prefix(toShow) {
            displayScreenshotInfo(screenshot, compact: true)
        }
    }
    
    func watchMode() async {
        print("👁️  Watch mode started (capture every 30s)")
        print("   Press Enter to stop...")
        
        var isWatching = true
        
        Task {
            while isWatching {
                await captureScreenshot()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
        
        _ = readLine()
        isWatching = false
        print("👁️  Watch mode stopped")
    }
    
    private func displayScreenshotInfo(_ screenshot: Screenshot, compact: Bool = false) {
        let id = screenshot.id.uuidString.prefix(8)
        let time = formatTime(screenshot.timestamp)
        
        if compact {
            print("[\(id)] \(time) - \(screenshot.appContext)")
        } else {
            print("━".repeating(50))
            print("ID: \(id)")
            print("Time: \(time)")
            print("App: \(screenshot.appContext)")
            print("Text: \(screenshot.ocrText.prefix(150))\(screenshot.ocrText.count > 150 ? "..." : "")")
            print()
        }
    }
    
    private func performOCR(on imagePath: String) async -> String {
        // In production: Use Vision framework
        // For now, return placeholder
        return "OCR not implemented in demo. Would extract all visible text."
    }
    
    private func getActiveApp() -> String {
        let workspace = NSWorkspace.shared
        return workspace.frontmostApplication?.localizedName ?? "Unknown"
    }
    
    private func exportScreenshot(id: String) {
        guard let screenshot = screenshots.first(where: { $0.id.uuidString.hasPrefix(id) }) else {
            print("❌ Screenshot not found")
            return
        }
        
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
        let dest = desktop.appendingPathComponent(URL(fileURLWithPath: screenshot.path).lastPathComponent)
        
        try? FileManager.default.copyItem(atPath: screenshot.path, toPath: dest.path)
        print("✅ Exported to Desktop")
    }
    
    private func deleteScreenshot(id: String) {
        guard let index = screenshots.firstIndex(where: { $0.id.uuidString.hasPrefix(id) }) else {
            print("❌ Screenshot not found")
            return
        }
        
        let screenshot = screenshots[index]
        try? FileManager.default.removeItem(atPath: screenshot.path)
        screenshots.remove(at: index)
        
        print("✅ Deleted screenshot")
    }
    
    private func showStats() {
        print("📊 Statistics:")
        print("   Total screenshots: \(screenshots.count)")
        print("   Oldest: \(screenshots.last.map { formatTime($0.timestamp) } ?? "N/A")")
        print("   Newest: \(screenshots.first.map { formatTime($0.timestamp) } ?? "N/A")")
        
        // App breakdown
        var appCounts: [String: Int] = [:]
        for screenshot in screenshots {
            appCounts[screenshot.appContext, default: 0] += 1
        }
        
        print("\n   By app:")
        for (app, count) in appCounts.sorted(by: { $0.value > $1.value }) {
            print("      \(app): \(count)")
        }
    }
    
    private func createScreenshotsDirectory() {
        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
    }
    
    private func loadExistingScreenshots() {
        // In production: Load from CoreData or JSON index
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func showHelp() {
        print("""
        Commands:
          capture     Take screenshot and index it
          search      Search through screenshots
          list        List recent screenshots
          watch       Auto-capture every 30s
          export      Export screenshot to desktop
          delete      Delete screenshot
          stats       Show statistics
          help        Show this help
          quit        Exit
        """)
    }
}

extension String {
    func repeating(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
