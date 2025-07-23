//
//  HermesApp.swift
//  Hermes
//
//  Created by Dom Senese on 7/23/25.
//

import SwiftUI
import AppKit

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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menu bar
        setupMenuBar()
        
        // Setup global hotkeys
        setupGlobalHotkeys()
        
        // Request necessary permissions
        requestPermissions()
        
        print("🚀 Hermes launched successfully")
    }
    
    private func setupMenuBar() {
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusBarItem = statusBarItem else { return }
        
        // Set menu bar icon
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Hermes")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(toggleMenuBar)
        }
        
        // Create menu bar window controller
        menuBarWindowController = MenuBarWindowController()
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
        Task { @MainActor in
            // Request microphone permission
            let audioManager = AudioManager()
            do {
                try await audioManager.startRecording()
                audioManager.stopRecording()
                print("✅ Microphone permission granted")
            } catch {
                print("❌ Microphone permission denied: \(error)")
                await showPermissionAlert(for: .microphone)
            }
            
            // Request accessibility permission
            let textInjector = TextInjector()
            if !textInjector.requestAccessibilityPermissions() {
                print("❌ Accessibility permission needed")
                await showPermissionAlert(for: .accessibility)
            }
        }
    }
    
    @objc private func toggleMenuBar() {
        menuBarWindowController?.toggle()
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
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    private func show() {
        guard let window = window,
              let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength).button else { return }
        
        // Position window below status bar item
        let buttonFrame = statusBarItem.frame
        let screenFrame = statusBarItem.window?.frame ?? .zero
        
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

// MARK: - Global Hotkey Manager (Placeholder)

class GlobalHotkeyManager {
    func registerHotkey(_ hotkey: String, callback: @escaping () -> Void) {
        // TODO: Implement global hotkey registration
        // This would use Carbon or other system APIs to register global shortcuts
        print("🔥 Registered hotkey: \(hotkey)")
    }
}
