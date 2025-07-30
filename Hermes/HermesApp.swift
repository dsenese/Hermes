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
    private var sharedDictationEngine: DictationEngine?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Starting Hermes application launch...")
        
        // Set as regular app with dock icon
        NSApp.setActivationPolicy(.regular)
        print("✅ App activation policy set to regular (with dock icon)")
        
        // Setup menu bar
        setupMenuBar()
        
        // Setup global hotkeys
        setupGlobalHotkeys()
        
        // Main app window is now managed by SwiftUI WindowGroup
        
        // Setup floating dictation marker
        setupFloatingDictationMarker()
        
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
    
    private func setupGlobalHotkeys() {
        Task { @MainActor in
            let hotkeyManager = GlobalHotkeyManager.shared
            let currentHotkey = UserSettings.shared.keyboardShortcuts.globalDictationHotkey
            
            // Register the configured hotkey for hold-to-talk behavior
            hotkeyManager.registerHotkey(currentHotkey, 
                onPressed: { [weak self] in
                    Task { @MainActor in
                        await self?.startDictation()
                    }
                },
                onReleased: { [weak self] in
                    Task { @MainActor in
                        await self?.stopDictation()
                    }
                }
            )
        }
    }
    
    private func requestPermissions() {
        // Only check permissions without requesting them during app launch
        Task { @MainActor in
            // Check microphone permission (without requesting)
            if #available(macOS 10.14, *) {
                let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                switch microphoneStatus {
                case .authorized:
                    print("✅ Microphone permission already granted")
                case .denied:
                    print("⚠️ Microphone permission denied")
                case .notDetermined:
                    print("⚠️ Microphone permission not determined")
                case .restricted:
                    print("⚠️ Microphone permission restricted")
                @unknown default:
                    print("⚠️ Unknown microphone permission status")
                }
            }
            
            // Check accessibility permission (without prompting)
            let hasAccessibility = AXIsProcessTrusted()
            if hasAccessibility {
                print("✅ Accessibility permission granted")
            } else {
                print("⚠️ Accessibility permissions not granted. Please enable in System Preferences > Security & Privacy > Privacy > Accessibility")
            }
        }
    }
    
    @objc private func toggleMenuBar() {
        print("🖱️ Menu bar icon clicked")
        menuBarWindowController?.toggle(relativeTo: statusBarItem)
    }
    
    @MainActor
    private func startDictation() async {
        // Use shared dictation engine instance to avoid audio conflicts
        if sharedDictationEngine == nil {
            sharedDictationEngine = DictationEngine()
        }
        
        guard let dictationEngine = sharedDictationEngine else { return }
        
        // Only start if not already active
        if !dictationEngine.isActive {
            await dictationEngine.startDictation()
            showDictationPopup(with: dictationEngine)
        }
    }
    
    @MainActor
    private func stopDictation() async {
        guard let dictationEngine = sharedDictationEngine else { return }
        
        // Only stop if currently active
        if dictationEngine.isActive {
            await dictationEngine.stopDictation()
            hideDictationPopup()
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
    
    private func setupFloatingDictationMarker() {
        floatingDictationController = FloatingDictationController()
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
    }
    
    @objc private func handleOpenMainApp() {
        // Activate the app to bring main window to front
        NSApp.activate(ignoringOtherApps: true)
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


