import SwiftUI

@main
struct YearProgressMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock immediately
        NSApp.setActivationPolicy(.accessory)
        
        // Create menu bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Make button fit content tightly
        if let button = statusItem?.button {
            button.imagePosition = .noImage
        }
        
        // Create menu
        let menu = NSMenu()
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        // --- NEW: Add Observers for Wake and Day Change ---
        
        // 1. Listen for when the computer wakes from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateMenuBar),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // 2. Listen for when the screen wakes (redundancy check)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateMenuBar),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        // 3. Listen for system clock changes (e.g. user changes time zone or date manually)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBar),
            name: NSNotification.Name.NSSystemClockDidChange,
            object: nil
        )

        // 4. Update immediately on launch
        updateMenuBar()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func updateMenuBar() {
        // 1. Perform the Calculation
        let calendar = Calendar.current
        let now = Date()
        
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let daysInYear = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let daysRemaining = daysInYear - dayOfYear
        let percentage = Int(floor(Double(dayOfYear) / Double(daysInYear) * 100))
        
        // 2. Update the UI
        if let button = statusItem?.button {
            let text = "\(daysRemaining)d left · \(percentage)%"
            let attributedString = NSAttributedString(
                string: " \(text) ",  // Single space padding
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 12)
                ]
            )
            button.attributedTitle = attributedString
            button.sizeToFit()
        }
        
        // 3. Schedule the NEXT timer
        scheduleNextUpdate()
    }
    
    func scheduleNextUpdate() {
        // Clear any existing timer so we don't have duplicates
        timer?.invalidate()
        
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next midnight
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return }
        let midnight = calendar.startOfDay(for: tomorrow)
        
        // Create a timer that fires once at the next midnight
        let interval = midnight.timeIntervalSince(now)
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.updateMenuBar()
        }
        
        // Ensure timer runs even if menu is open or scrolling happens
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}
