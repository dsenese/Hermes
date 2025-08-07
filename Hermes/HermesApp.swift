//
//  HermesApp.swift
//  Hermes
//
//  Created by Dom Senese on 7/23/25.
//

import SwiftUI
import AppKit
import AVFoundation

@main
struct HermesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Main app window
        WindowGroup {
            MainAppView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.automatic)
        
        // Settings window (if needed)
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate for Menu Bar Management

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem?
    private var menuBarWindowController: MenuBarWindowController?
    private var dictationPopupController: DictationPopupWindowController?
    private var floatingDictationController: FloatingDictationController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Starting Hermes application launch...")
        
        // Set as regular app with dock icon
        NSApp.setActivationPolicy(.regular)
        print("✅ App activation policy set to regular (with dock icon)")
        
        // Setup menu bar
        setupMenuBar()
        
        // Initialize WhisperKit in background immediately (critical for dictation)
        Task {
            await initializeWhisperKitInBackground()
        }
        
        // Initialize permission managers and global hotkeys - defer to avoid blocking UI startup
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            
            // Start permission monitoring
            await MainActor.run {
                AccessibilityManager.shared.startMonitoring()
                print("🔧 AppDelegate: Started permission monitoring")
            }
            
            // Wait a bit more for permission checks
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 more second
            
            await setupGlobalHotkeys()
            
            // Also ensure GlobalShortcutManager is set up for monitoring
            print("🔧 AppDelegate: Ensuring GlobalShortcutManager monitoring is active...")
            GlobalShortcutManager.shared.retrySetup()
        }
        
        // Main app window is now managed by SwiftUI WindowGroup
        
        // Setup floating dictation marker - defer to avoid blocking UI
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds
            await setupFloatingDictationMarker()
        }
        
        // Note: Permissions are now handled in the onboarding flow only
        
        // Setup notification observers
        setupNotificationObservers()
        
        print("🚀 Hermes launched successfully")
        print("📱 Main app window is open")
        print("👀 Look for the waveform icon in your menu bar (top right of screen) for quick access")
    }
    
    private func setupMenuBar() {
        // Create status bar item with fixed length first
        statusBarItem = NSStatusBar.system.statusItem(withLength: 30)
        
        guard let statusBarItem = statusBarItem else { 
            print("❌ Failed to create status bar item")
            return 
        }
        
        print("✅ Status bar item created with length 30")
        
        // Set menu bar icon - use simple text for guaranteed visibility
        if let button = statusBarItem.button {
            // Use simple text that should definitely be visible
            button.title = "🎤"
            button.font = NSFont.systemFont(ofSize: 16)
            print("✅ Menu bar button created with microphone emoji")
            
            button.target = self
            button.action = #selector(toggleMenuBar)
            
            // Make sure the button is visible
            button.isEnabled = true
            button.isHidden = false
            
            print("✅ Menu bar button configured and should be visible")
        } else {
            print("❌ Failed to create menu bar button")
        }
        
        // Create menu bar window controller
        menuBarWindowController = MenuBarWindowController()
        print("✅ Menu bar window controller created")
        
        // Try to make sure our item is visible
        statusBarItem.isVisible = true
        print("✅ Status bar item visibility set to true")
        
        // Additional debug info
        if let button = statusBarItem.button {
            print("🔍 Button frame: \(button.frame)")
            print("🔍 Button superview: \(String(describing: button.superview))")
            print("🔍 Button window: \(String(describing: button.window))")
        }
    }
    
    private func setupGlobalHotkeys() async {
        print("🔧 Setting up global shortcuts using GlobalShortcutManager...")
        
        Task { @MainActor in
            // Get user's preferred shortcut from settings, default to "fn"
            let userSettings = UserSettings.shared
            let shortcut = userSettings.keyboardShortcuts.globalDictationHotkey
            let accelerator = shortcut.displayString
            
            // Register the shortcut with GlobalShortcutManager (hold-to-dictate mode)
            let success = GlobalShortcutManager.shared.register(accelerator) {
                // This callback is not used for hold-to-dictate - GlobalShortcutManager handles it internally
                print("🔥 Global shortcut '\(accelerator)' registered (hold-to-dictate mode)")
            }
            
            if success {
                print("✅ Global shortcut '\(accelerator)' registered successfully")
            } else {
                print("❌ Failed to register global shortcut '\(accelerator)'")
            }
            
            // Enable Fn key monitoring only if user has configured Fn as their hotkey
            if shortcut.key == .fn {
                print("🔑 User has configured Fn key - enabling Fn key monitoring...")
                GlobalShortcutManager.shared.enableFnKeyDictation()
            } else {
                print("🔑 User has not configured Fn key - keeping Fn key monitoring disabled")
                GlobalShortcutManager.shared.disableFnKeyDictation()
            }
        }
    }
    
    /// Update global hotkey when settings change (called from onboarding)
    func updateGlobalHotkey(_ hotkey: HotkeyConfiguration) {
        Task { @MainActor in
            print("🔄 AppDelegate: Updating global shortcut to '\(hotkey.displayString)'")
            
            // Unregister all existing shortcuts
            GlobalShortcutManager.shared.unregisterAll()
            
            // Register new shortcut
            let accelerator = hotkey.displayString
            let success = GlobalShortcutManager.shared.register(accelerator) {
                // This callback is not used for hold-to-dictate - GlobalShortcutManager handles it internally
                print("🔥 Updated global shortcut '\(accelerator)' registered (hold-to-dictate mode)")
            }
            
            if success {
                print("✅ Global shortcut updated to '\(accelerator)'")
            } else {
                print("❌ Failed to update global shortcut to '\(accelerator)'")
            }
            
            // Update Fn key monitoring based on new hotkey setting
            if hotkey.key == .fn {
                print("🔑 User changed to Fn key - enabling Fn key monitoring...")
                GlobalShortcutManager.shared.enableFnKeyDictation()
            } else {
                print("🔑 User changed away from Fn key - disabling Fn key monitoring...")
                GlobalShortcutManager.shared.disableFnKeyDictation()
            }
            
            // Notify the dictation engine for UI consistency
            DictationEngine.shared.updateGlobalHotkey(hotkey)
        }
    }
    
    private func requestPermissions() {
        Task { @MainActor in
            // TEST: Request microphone permission immediately on launch to verify it works
            print("🔍 Testing microphone permission request...")
            
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            print("📱 Current microphone status: \(micStatus.rawValue)")
            
            if micStatus == .notDetermined {
                print("🎤 Requesting microphone permission...")
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        if granted {
                            print("✅ Microphone permission granted!")
                        } else {
                            print("❌ Microphone permission denied!")
                        }
                    }
                }
            } else {
                print("📱 Microphone permission already determined: \(micStatus)")
            }
            
            // Removed accessibility test - was breaking System Settings
        }
    }
    
    @objc private func toggleMenuBar() {
        print("🖱️ Menu bar icon clicked")
        menuBarWindowController?.toggle(relativeTo: statusBarItem)
    }
    
    @MainActor
    private func toggleDictation() async {
        print("🔥 AppDelegate.toggleDictation() called!")
        
        let dictationEngine = DictationEngine.shared
        
        if dictationEngine.isActive {
            print("⏹️ Stopping dictation session...")
            await dictationEngine.stopDictation()
            hideDictationPopup()
        } else {
            print("🚀 Starting dictation session...")
            await dictationEngine.startDictation()
            showDictationPopup(with: dictationEngine)
        }
    }
    
    @MainActor
    private func startDictation() async {
        print("🔥 AppDelegate.startDictation() called!")
        
        let dictationEngine = DictationEngine.shared
        
        // Only start if not already active
        if !dictationEngine.isActive {
            print("🚀 Starting dictation session...")
            await dictationEngine.startDictation()
            showDictationPopup(with: dictationEngine)
        } else {
            print("⚠️ Dictation already active, skipping start")
        }
    }
    
    @MainActor
    private func stopDictation() async {
        print("🛑 AppDelegate.stopDictation() called!")
        
        let dictationEngine = DictationEngine.shared
        
        // Only stop if currently active
        if dictationEngine.isActive {
            print("⏹️ Stopping dictation session...")
            await dictationEngine.stopDictation()
            hideDictationPopup()
        } else {
            print("⚠️ Dictation not active, skipping stop")
        }
    }
    
    private func showDictationPopup(with dictationEngine: DictationEngine) {
        if dictationPopupController == nil {
            dictationPopupController = DictationPopupWindowController()
        }
        dictationPopupController?.show(with: dictationEngine)
    }
    
    private func hideDictationPopup() {
        dictationPopupController?.hide()
    }
    
    @MainActor
    private func showPermissionAlert(for permission: PermissionType) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        
        switch permission {
        case .microphone:
            alert.informativeText = "Hermes needs microphone access to transcribe your speech. Please grant permission in System Preferences > Security & Privacy > Privacy > Microphone."
        case .accessibility:
            alert.informativeText = "Hermes needs accessibility access to inject text into other applications. Please grant permission in System Preferences > Security & Privacy > Privacy > Accessibility."
        }
        
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemPreferences(for: permission)
        }
    }
    
    private func openSystemPreferences(for permission: PermissionType) {
        let prefPane: String
        switch permission {
        case .microphone:
            prefPane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            prefPane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
        
        if let url = URL(string: prefPane) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @MainActor
    private func setupFloatingDictationMarker() async {
        print("🚀 Setting up floating dictation marker...")
        let dictationEngine = DictationEngine.shared
        
        floatingDictationController = FloatingDictationController(dictationEngine: dictationEngine)
        floatingDictationController?.show()
        print("✅ Floating dictation marker created and shown")
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainApp),
            name: .openMainApp,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateGlobalHotkey),
            name: .updateGlobalHotkey,
            object: nil
        )
    }
    
    @objc private func handleOpenMainApp() {
        // Activate the app to bring main window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func handleUpdateGlobalHotkey(_ notification: Notification) {
        if let hotkey = notification.object as? HotkeyConfiguration {
            updateGlobalHotkey(hotkey)
        }
    }
    
    /// Initialize WhisperKit in the background on app startup
    private func initializeWhisperKitInBackground() async {
        print("🤖 Starting WhisperKit initialization in background...")
        
        do {
            // Initialize the shared transcription service
            try await TranscriptionService.shared.initialize()
            print("✅ WhisperKit initialized successfully on app startup")
            
            // Post notification that models are ready
            await MainActor.run {
                NotificationCenter.default.post(name: .whisperKitReady, object: nil)
            }
            
        } catch {
            print("⚠️ WhisperKit initialization failed on startup: \(error)")
            print("💡 Models will be downloaded on first dictation attempt")
            
            // Not a critical failure - user can still use the app
            // Models will be downloaded when first needed
        }
    }
}

// MARK: - Menu Bar Window Controller

class MenuBarWindowController: NSWindowController, NSWindowDelegate {
    private var isVisible = false
    private var eventMonitor: Any?
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .popUpMenu
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        self.init(window: window)
        
        window.delegate = self
        
        // Set up the SwiftUI content
        let hostingView = NSHostingView(rootView: MenuBarView())
        window.contentView = hostingView
    }
    
    func toggle(relativeTo statusBarItem: NSStatusItem?) {
        if isVisible {
            hide()
        } else {
            show(relativeTo: statusBarItem)
        }
    }
    
    private func show(relativeTo statusBarItem: NSStatusItem?) {
        guard let window = window,
              let statusBarItem = statusBarItem,
              let button = statusBarItem.button else { return }
        
        // Position window below status bar item
        let buttonFrame = button.frame
        let screenFrame = button.window?.frame ?? .zero
        
        let windowX = screenFrame.origin.x + buttonFrame.origin.x - (window.frame.width / 2) + (buttonFrame.width / 2)
        let windowY = screenFrame.origin.y - window.frame.height - 8
        
        window.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        window.makeKeyAndOrderFront(nil)
        
        isVisible = true
        
        // Setup click outside monitor to auto-hide
        setupEventMonitor()
    }
    
    private func hide() {
        window?.orderOut(nil)
        isVisible = false
        removeEventMonitor()
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.window else { return }
            
            // Check if click is outside our window
            let clickLocation = NSEvent.mouseLocation
            if !window.frame.contains(clickLocation) {
                self.hide()
            }
        }
    }
    
    private func removeEventMonitor() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
    
    deinit {
        removeEventMonitor()
    }
}

// MARK: - Supporting Types

enum PermissionType {
    case microphone
    case accessibility
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let updateGlobalHotkey = Notification.Name("updateGlobalHotkey")
    static let whisperKitReady = Notification.Name("whisperKitReady")
}


