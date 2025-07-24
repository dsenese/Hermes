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
        // Empty scene - we're using menu bar only
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
    private var globalHotkeyManager: GlobalHotkeyManager?
    private var mainAppWindowController: MainAppWindowController?
    private var floatingDictationController: FloatingDictationController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Starting Hermes application launch...")
        
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
        print("✅ App activation policy set to accessory")
        
        // Setup menu bar
        setupMenuBar()
        
        // Setup global hotkeys
        setupGlobalHotkeys()
        
        // Setup main app window (initially hidden)
        setupMainAppWindow()
        
        // Setup floating dictation marker
        setupFloatingDictationMarker()
        
        // Note: Permissions are now handled in the onboarding flow only
        
        // Setup notification observers
        setupNotificationObservers()
        
        print("🚀 Hermes launched successfully")
        print("👀 Look for the waveform icon in your menu bar (top right of screen)")
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
        globalHotkeyManager = GlobalHotkeyManager()
        
        // Register default hotkey (⌘⌘)
        globalHotkeyManager?.registerHotkey(HermesConstants.defaultHotkey) { [weak self] in
            Task { @MainActor in
                await self?.toggleDictation()
            }
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
    private func toggleDictation() async {
        // Get the shared dictation engine instance
        // For now, create a new one - in production, this would be a shared singleton
        let dictationEngine = DictationEngine()
        await dictationEngine.toggleDictation()
        
        if dictationEngine.isActive {
            showDictationPopup(with: dictationEngine)
        } else {
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
    
    private func setupMainAppWindow() {
        mainAppWindowController = MainAppWindowController()
        print("✅ Main app window controller created")
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
        showMainApp()
    }
    
    private func showMainApp() {
        mainAppWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Bar Window Controller

class MenuBarWindowController: NSWindowController {
    private var isVisible = false
    
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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.init(window: window)
        
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
    }
    
    private func hide() {
        window?.orderOut(nil)
        isVisible = false
    }
}

// MARK: - Supporting Types

enum PermissionType {
    case microphone
    case accessibility
}

// MARK: - Main App Window Controller

class MainAppWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Hermes"
        window.minSize = NSSize(width: 800, height: 600)
        window.center()
        window.setFrameAutosaveName("MainAppWindow")
        
        self.init(window: window)
        
        // Set up the SwiftUI content
        let hostingView = NSHostingView(rootView: MainAppView())
        window.contentView = hostingView
    }
}

// MARK: - Global Hotkey Manager (Placeholder)

class GlobalHotkeyManager {
    func registerHotkey(_ hotkey: String, callback: @escaping () -> Void) {
        // TODO: Implement global hotkey registration
        // This would use Carbon or other system APIs to register global shortcuts
        print("🔥 Registered hotkey: \(hotkey)")
    }
}
