//
//  GlobalHotkeyManager.swift
//  Hermes
//
//  Created by Claude Code on 7/29/25.
//

import Foundation
import AppKit
import Combine
import CoreGraphics

/// Modern global hotkey manager using CGEventTap APIs
class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()
    
    // MARK: - Published Properties
    
    @Published var isListening = false
    @Published var currentHotkey: HotkeyConfiguration?
    @Published var hotkeyPressed = false
    
    // MARK: - Private Properties
    
    // CGEventTap for reliable global key capture
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    
    // Callbacks
    private var onHotkeyPressed: (() -> Void)?
    private var onHotkeyReleased: (() -> Void)?
    
    // Current tracking state
    private var isCurrentlyPressed = false
    private var expectedKeyCode: Int32 = 0
    private var expectedModifiers: CGEventFlags = []
    
    private init() {
        // Modern initialization - no setup needed
    }
    
    deinit {
        // Clean up CGEventTap
        disableEventTap()
    }
    
    // MARK: - Public Methods
    
    /// Register a hotkey for global capture using modern CGEventTap APIs
    func registerHotkey(_ hotkey: HotkeyConfiguration, onPressed: @escaping () -> Void, onReleased: (() -> Void)? = nil) {
        print("🔥 Registering CGEventTap hotkey: \(hotkey.displayString)")
        
        // Check for Input Monitoring permissions
        guard hasInputMonitoringPermission() else {
            print("❌ Input Monitoring permission required for global hotkeys")
            requestInputMonitoringPermission()
            return
        }
        
        // Store callbacks
        self.onHotkeyPressed = onPressed
        self.onHotkeyReleased = onReleased
        
        // Unregister existing hotkey
        unregisterHotkey()
        
        // Convert to CGEvent key codes and modifiers
        self.expectedKeyCode = cgEventKeyCode(for: hotkey.key)
        self.expectedModifiers = cgEventModifiers(for: hotkey.modifiers)
        
        // Create the event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let result = GlobalHotkeyManager.shared.handleCGEvent(proxy: proxy, type: type, event: event, refcon: refcon)
                return result.map(Unmanaged.passRetained)
            },
            userInfo: nil
        )
        
        guard let eventTap = eventTap else {
            print("❌ Failed to create CGEventTap")
            return
        }
        
        // Create run loop source
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = eventTapRunLoopSource else {
            print("❌ Failed to create run loop source")
            return
        }
        
        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        currentHotkey = hotkey
        isListening = true
        print("✅ CGEventTap hotkey registered successfully")
        
        // Save to UserSettings
        Task { @MainActor in
            UserSettings.shared.keyboardShortcuts.globalDictationHotkey = hotkey
            UserSettings.shared.saveToLocalStorage()
        }
    }
    
    /// Unregister the current hotkey
    func unregisterHotkey() {
        disableEventTap()
        
        currentHotkey = nil
        isListening = false
        onHotkeyPressed = nil
        onHotkeyReleased = nil
        isCurrentlyPressed = false
        expectedKeyCode = 0
        expectedModifiers = []
        
        print("✅ CGEventTap hotkey unregistered")
    }
    
    /// Update the registered hotkey
    func updateHotkey(_ hotkey: HotkeyConfiguration) {
        if let onPressed = onHotkeyPressed {
            print("🔄 Updating CGEventTap hotkey to: \(hotkey.displayString)")
            registerHotkey(hotkey, onPressed: onPressed, onReleased: onHotkeyReleased)
        } else {
            print("⚠️ No callback set for hotkey update: \(hotkey.displayString)")
            // Still register it with a default callback
            registerHotkey(hotkey, onPressed: {
                print("🎤 Default CGEventTap hotkey callback: \(hotkey.displayString)")
            })
        }
    }
    
    // MARK: - Private Methods
    
    private func disableEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            
            if let runLoopSource = eventTapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                eventTapRunLoopSource = nil
            }
            
            self.eventTap = nil
            print("✅ CGEventTap disabled and removed")
        }
    }
    
    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> CGEvent? {
        // Handle different event types
        switch type {
        case .keyDown:
            if isMatchingHotkey(event: event) && !isCurrentlyPressed {
                isCurrentlyPressed = true
                DispatchQueue.main.async {
                    self.handleHotkeyPressed()
                }
            }
        case .keyUp:
            if isMatchingHotkey(event: event) && isCurrentlyPressed {
                isCurrentlyPressed = false
                DispatchQueue.main.async {
                    self.handleHotkeyReleased()
                }
            }
        case .flagsChanged:
            handleFlagsChangedCG(event: event)
        default:
            break
        }
        
        // Return the event unmodified (we're not consuming it)
        return event
    }
    
    private func isMatchingHotkey(event: CGEvent) -> Bool {
        let eventKeyCode = Int32(event.getIntegerValueField(.keyboardEventKeycode))
        let eventFlags = event.flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl, .maskSecondaryFn])
        
        // For regular keys
        if expectedKeyCode != 0 {
            return eventKeyCode == expectedKeyCode && eventFlags == expectedModifiers
        }
        
        return false
    }
    
    private func handleFlagsChangedCG(event: CGEvent) {
        let eventFlags = event.flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl, .maskSecondaryFn])
        
        // Special handling for fn key
        if let hotkey = currentHotkey, hotkey.key == .fn && hotkey.modifiers.isEmpty {
            let fnPressed = eventFlags.contains(.maskSecondaryFn)
            
            if fnPressed && !isCurrentlyPressed {
                isCurrentlyPressed = true
                DispatchQueue.main.async {
                    self.handleHotkeyPressed()
                }
            } else if !fnPressed && isCurrentlyPressed {
                isCurrentlyPressed = false
                DispatchQueue.main.async {
                    self.handleHotkeyReleased()
                }
            }
        }
    }
    
    // Permission checking methods
    private func hasInputMonitoringPermission() -> Bool {
        // Check if we can create a CGEventTap
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )
        
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            return true
        }
        
        return false
    }
    
    private func requestInputMonitoringPermission() {
        print("🔐 Input Monitoring permission required. Please grant access in System Preferences > Security & Privacy > Privacy > Input Monitoring")
        
        // Open System Preferences to Input Monitoring
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func cgEventKeyCode(for key: KeyboardKey) -> Int32 {
        switch key {
        case .fn: return 0 // Special case - handled by flags
        case .command: return 0 // Special case - handled by flags
        case .space: return 49
        case .enter: return 36
        case .tab: return 48
        case .escape: return 53
        case .a: return 0
        case .b: return 11
        case .c: return 8
        case .d: return 2
        case .e: return 14
        case .f: return 3
        case .g: return 5
        case .h: return 4
        case .i: return 34
        case .j: return 38
        case .k: return 40
        case .l: return 37
        case .m: return 46
        case .n: return 45
        case .o: return 31
        case .p: return 35
        case .q: return 12
        case .r: return 15
        case .s: return 1
        case .t: return 17
        case .u: return 32
        case .v: return 9
        case .w: return 13
        case .x: return 7
        case .y: return 16
        case .z: return 6
        case .zero: return 29
        case .one: return 18
        case .two: return 19
        case .three: return 20
        case .four: return 21
        case .five: return 23
        case .six: return 22
        case .seven: return 26
        case .eight: return 28
        case .nine: return 25
        case .f1: return 122
        case .f2: return 120
        case .f3: return 99
        case .f4: return 118
        case .f5: return 96
        case .f6: return 97
        case .f7: return 98
        case .f8: return 100
        case .f9: return 101
        case .f10: return 109
        case .f11: return 103
        case .f12: return 111
        }
    }
    
    private func cgEventModifiers(for modifiers: Set<KeyboardModifier>) -> CGEventFlags {
        var cgModifiers: CGEventFlags = []
        
        for modifier in modifiers {
            switch modifier {
            case .command:
                cgModifiers.insert(.maskCommand)
            case .option:
                cgModifiers.insert(.maskAlternate)
            case .shift:
                cgModifiers.insert(.maskShift)
            case .control:
                cgModifiers.insert(.maskControl)
            }
        }
        
        return cgModifiers
    }
    
    // MARK: - Event Handling
    
    private func handleHotkeyPressed() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🔥 CGEventTap hotkey PRESSED - setting hotkeyPressed = true")
            self.hotkeyPressed = true
            self.onHotkeyPressed?()
        }
    }
    
    private func handleHotkeyReleased() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🔥 CGEventTap hotkey RELEASED - setting hotkeyPressed = false")
            self.hotkeyPressed = false
            self.onHotkeyReleased?()
        }
    }
}