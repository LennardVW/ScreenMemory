import Foundation
import AppKit
import Vision

// MARK: - ScreenMemory
/// REAL searchable screenshot history with OCR

@main
struct ScreenMemory {
    static func main() async {
        let memory = ScreenMemoryCore()
        await memory.run()
    }
}

@MainActor
final class ScreenMemoryCore {
    private var screenshotsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Screenshots")
    }
    private var indexPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".screenmemory/index.json")
    }
    private var screenshots: [ScreenshotRecord] = []
    private var isWatching = false
    
    struct ScreenshotRecord: Codable, Identifiable {
        let id: UUID
        let filename: String
        let timestamp: Date
        let ocrText: String
        let appName: String
        let windowTitle: String
        let url: String?
    }
    
    func run() async {
        createDirectories()
        loadIndex()
        
        print("""
        📸 ScreenMemory - Searchable Screenshot History
        
        Commands:
          capture           Take screenshot now
          watch             Auto-capture every 30 seconds
          search <query>    Search through screenshots
          list [n]          List recent (default: 10)
          open <id>         Open screenshot
          text <id>         Show extracted text
          stop              Stop watching
          stats             Show statistics
          help              Show help
          quit              Exit
        
        Screenshots saved to: ~/Screenshots/
        """)
        
        while true {
            print("> ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
            
            let parts = input.split(separator: " ", maxSplits: 1)
            let command = parts.first?.lowercased() ?? ""
            let arg = parts.count > 1 ? String(parts[1]) : ""
            
            switch command {
            case "capture", "c", "snap":
                await captureScreenshot()
            case "watch", "w":
                await startWatching()
            case "stop", "s":
                stopWatching()
            case "search", "find", "f":
                await searchScreenshots(query: arg)
            case "list", "ls", "l":
                listScreenshots(count: Int(arg) ?? 10)
            case "open", "o":
                openScreenshot(id: arg)
            case "text", "t":
                showText(id: arg)
            case "stats", "stat":
                showStats()
            case "help", "h":
                showHelp()
            case "quit", "q", "exit":
                stopWatching()
                print("👋 Goodbye!")
                return
            default:
                print("Unknown command. Type 'help' for options.")
            }
        }
    }
    
    func captureScreenshot() async {
        let timestamp = Date()
        let filename = "screen_\(formatTimestamp(timestamp)).png"
        let filepath = screenshotsDir.appendingPathComponent(filename).path
        
        print("📸 Capturing screenshot...")
        
        // Use screencapture command
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", filepath]
        
        try? task.run()
        task.waitUntilExit()
        
        guard FileManager.default.fileExists(atPath: filepath) else {
            print("❌ Failed to capture screenshot")
            print("   Make sure Screen Recording permission is granted")
            return
        }
        
        // Get context
        let appName = getActiveApp()
        let windowTitle = getWindowTitle()
        let url = getCurrentURL()
        
        // Perform OCR
        print("🔍 Running OCR...")
        let ocrText = await performOCR(imagePath: filepath)
        
        let record = ScreenshotRecord(
            id: UUID(),
            filename: filename,
            timestamp: timestamp,
            ocrText: ocrText,
            appName: appName,
            windowTitle: windowTitle,
            url: url
        )
        
        screenshots.insert(record, at: 0)
        saveIndex()
        
        print("✅ Captured: \(filename)")
        print("   App: \(appName)")
        if !windowTitle.isEmpty { print("   Window: \(windowTitle)") }
        if let url = url { print("   URL: \(url)") }
        print("   Text: \(ocrText.prefix(80))\(ocrText.count > 80 ? "..." : "")")
    }
    
    func startWatching() async {
        guard !isWatching else {
            print("⚠️  Already watching")
            return
        }
        
        isWatching = true
        print("👁️  Watching... Capturing every 30 seconds")
        print("   Press Enter to stop")
        
        Task {
            while isWatching {
                await captureScreenshot()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
        
        _ = readLine()
        stopWatching()
    }
    
    func stopWatching() {
        isWatching = false
        print("🛑 Stopped watching")
    }
    
    func searchScreenshots(query: String) async {
        guard !query.isEmpty else {
            print("❌ Enter a search query")
            return
        }
        
        guard !screenshots.isEmpty else {
            print("⚠️  No screenshots captured yet")
            return
        }
        
        let lowerQuery = query.lowercased()
        
        // Parse special queries
        var appFilter: String?
        var timeFilter: TimeInterval?
        
        if lowerQuery.contains("from:") {
            let parts = lowerQuery.components(separatedBy: "from:")
            if parts.count > 1 {
                appFilter = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        
        if lowerQuery.contains("ago") {
            timeFilter = parseTimeQuery(lowerQuery)
        }
        
        let results = screenshots.filter { record in
            var matches = true
            
            if let appFilter = appFilter {
                matches = matches && record.appName.lowercased().contains(appFilter)
            }
            
            if let timeFilter = timeFilter {
                matches = matches && Date().timeIntervalSince(record.timestamp) <= timeFilter
            }
            
            if appFilter == nil && timeFilter == nil {
                matches = record.ocrText.lowercased().contains(lowerQuery) ||
                         record.appName.lowercased().contains(lowerQuery) ||
                         record.filename.lowercased().contains(lowerQuery)
            }
            
            return matches
        }
        
        print("🔍 Found \(results.count) screenshot(s):\n")
        for record in results {
            displayRecord(record, compact: true)
        }
    }
    
    func listScreenshots(count: Int) {
        let toShow = min(count, screenshots.count)
        
        guard toShow > 0 else {
            print("📭 No screenshots yet")
            return
        }
        
        print("📸 Last \(toShow) screenshot(s):\n")
        for record in screenshots.prefix(toShow) {
            displayRecord(record, compact: true)
        }
    }
    
    func openScreenshot(id: String) {
        guard let record = screenshots.first(where: { $0.id.uuidString.hasPrefix(id) }) else {
            print("❌ Screenshot not found")
            return
        }
        
        let path = screenshotsDir.appendingPathComponent(record.filename).path
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        try? task.run()
        
        print("📖 Opening \(record.filename)...")
    }
    
    func showText(id: String) {
        guard let record = screenshots.first(where: { $0.id.uuidString.hasPrefix(id) }) else {
            print("❌ Screenshot not found")
            return
        }
        
        print("━".repeating(50))
        print("📝 Extracted text from \(record.filename):")
        print()
        print(record.ocrText)
        print("━".repeating(50))
    }
    
    func showStats() {
        print("📊 Statistics:")
        print("   Total screenshots: \(screenshots.count)")
        
        let totalSize = screenshots.reduce(0) { total, record in
            let path = screenshotsDir.appendingPathComponent(record.filename).path
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            return total + size
        }
        print("   Total size: \(formatBytes(totalSize))")
        
        // App breakdown
        var appCounts: [String: Int] = [:]
        for record in screenshots {
            appCounts[record.appName, default: 0] += 1
        }
        
        print("\n   By app:")
        for (app, count) in appCounts.sorted(by: { $0.value > $1.value }).prefix(5) {
            print("      \(app): \(count)")
        }
    }
    
    private func performOCR(imagePath: String) async -> String {
        guard FileManager.default.fileExists(atPath: imagePath) else {
            return ""
        }
        
        let imageURL = URL(fileURLWithPath: imagePath)
        
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            let observations = request.results ?? []
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            return recognizedStrings.joined(separator: "\n")
        } catch {
            return "OCR Error: \(error.localizedDescription)"
        }
    }
    
    private func getActiveApp() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }
    
    private func getWindowTitle() -> String {
        // Would require Accessibility permissions to get actual window title
        return ""
    }
    
    private func getCurrentURL() -> String? {
        // Would use AppleScript to get URL from browsers
        return nil
    }
    
    private func parseTimeQuery(_ query: String) -> TimeInterval? {
        if query.contains("hour") {
            return 3600
        } else if query.contains("day") {
            return 86400
        } else if query.contains("week") {
            return 604800
        }
        return nil
    }
    
    private func displayRecord(_ record: ScreenshotRecord, compact: Bool) {
        let id = record.id.uuidString.prefix(8)
        let time = formatTime(record.timestamp)
        
        if compact {
            print("[\(id)] \(time) | \(record.appName) | \(record.ocrText.prefix(50))...")
        } else {
            print("━".repeating(50))
            print("📄 \(record.filename)")
            print("   ID: \(id)")
            print("   Time: \(time)")
            print("   App: \(record.appName)")
            if let url = record.url { print("   URL: \(url)") }
            print("   Text: \(record.ocrText.prefix(100))...")
        }
    }
    
    private func createDirectories() {
        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: indexPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
    
    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexPath),
              let records = try? JSONDecoder().decode([ScreenshotRecord].self, from: data) else {
            return
        }
        screenshots = records
    }
    
    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(screenshots) else { return }
        try? data.write(to: indexPath)
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
    
    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }
    
    private func showHelp() {
        print("""
        Commands:
          capture    Take screenshot now
          watch      Auto-capture every 30s
          search     Search screenshots
          list       List recent
          open       Open screenshot
          text       Show extracted text
          stop       Stop watching
          stats      Show statistics
          help       Show help
          quit       Exit
        """)
    }
}
