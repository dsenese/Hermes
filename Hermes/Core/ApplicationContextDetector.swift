//
//  ApplicationContextDetector.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import Foundation
import AppKit
import ApplicationServices

/// Detects and classifies applications for context-aware text injection and formatting
@MainActor
class ApplicationContextDetector: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentContext: ApplicationContext = .unknown
    @Published private(set) var currentApplication: String = ""
    @Published private(set) var currentWindowTitle: String = ""
    
    // MARK: - Private Properties
    
    private var contextUpdateTimer: Timer?
    private let updateInterval: TimeInterval = 1.0 // Check context every second
    
    // Bundle ID to application type mappings
    private let applicationMappings: [String: ApplicationType] = [
        // Email Clients
        "com.apple.mail": .email,
        "com.microsoft.Outlook": .email,
        "com.google.Gmail": .email,
        "com.mailbutler.MailButler": .email,
        "com.readdle.smartemail-Mac": .email,
        
        // Code Editors
        "com.apple.dt.Xcode": .codeEditor,
        "com.microsoft.VSCode": .codeEditor,
        "com.sublimetext.4": .codeEditor,
        "com.jetbrains.intellij": .codeEditor,
        "com.github.atom": .codeEditor,
        "com.coteditor.CotEditor": .codeEditor,
        "com.panic.Coda2": .codeEditor,
        
        // Chat Applications
        "com.tinyspeck.slackmacgap": .chat,
        "com.microsoft.teams": .chat,
        "com.apple.iChatAgent": .chat,
        "com.hnc.Discord": .chat,
        "us.zoom.xos": .chat,
        "com.skype.skype": .chat,
        
        // Document Editors
        "com.apple.Pages": .document,
        "com.microsoft.Word": .document,
        "com.apple.TextEdit": .document,
        "com.google.GoogleDocs": .document,
        "com.notion.id": .document,
        "com.bear-writer.BearOSX": .document,
        "com.ulyssesapp.mac": .document,
        
        // Browsers
        "com.apple.Safari": .browser,
        "com.google.Chrome": .browser,
        "com.mozilla.firefox": .browser,
        "com.microsoft.edgemac": .browser,
        "com.operasoftware.Opera": .browser,
        "company.thebrowser.Browser": .browser,
        
        // Note Apps
        "com.apple.Notes": .notes,
        "com.evernote.Evernote": .notes,
        "com.omnigroup.OmniOutliner5": .notes,
        "md.obsidian": .notes,
        "com.logseq.logseq": .notes,
        
        // Terminal/Command Line
        "com.apple.Terminal": .terminal,
        "com.googlecode.iterm2": .terminal,
        "com.github.wez.wezterm": .terminal,
        
        // Design/Creative
        "com.adobe.Photoshop": .creative,
        "com.figma.Desktop": .creative,
        "com.bohemiancoding.sketch3": .creative,
        
        // Social Media
        "com.twitter.twitter-mac": .social,
        "com.facebook.archon.developerID": .social
    ]
    
    // Window title patterns for context detection
    private let windowTitlePatterns: [String: ApplicationContext] = [
        // Email patterns
        "compose": .emailCompose,
        "new message": .emailCompose,
        "reply": .emailReply,
        "forward": .emailForward,
        "inbox": .emailList,
        
        // Code patterns
        ".swift": .codeFile,
        ".py": .codeFile,
        ".js": .codeFile,
        ".html": .codeFile,
        ".css": .codeFile,
        "xcode": .codeEditor,
        
        // Document patterns
        "untitled": .documentNew,
        ".docx": .documentEdit,
        ".pages": .documentEdit,
        
        // Chat patterns
        "thread": .chatThread,
        "direct message": .chatDirect,
        "channel": .chatChannel,
        
        // Browser patterns
        "gmail": .webEmail,
        "outlook": .webEmail,
        "github": .webCode,
        "stackoverflow": .webCode,
        "twitter": .webSocial,
        "facebook": .webSocial,
        "linkedin": .webSocial
    ]
    
    // MARK: - Initialization
    
    init() {
        startMonitoring()
        updateContext() // Initial context check
    }
    
    deinit {
        contextUpdateTimer?.invalidate()
        contextUpdateTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring application context changes
    func startMonitoring() {
        contextUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updateContext()
            }
        }
    }
    
    /// Stop monitoring application context changes
    func stopMonitoring() {
        contextUpdateTimer?.invalidate()
        contextUpdateTimer = nil
    }
    
    /// Force immediate context update
    func updateContext() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            currentContext = .unknown
            currentApplication = ""
            currentWindowTitle = ""
            return
        }
        
        let appName = frontmostApp.localizedName ?? "Unknown"
        let bundleID = frontmostApp.bundleIdentifier ?? ""
        
        // Get window title if possible
        let windowTitle = getWindowTitle(for: frontmostApp) ?? ""
        
        // Determine application type
        let appType = applicationMappings[bundleID] ?? .other
        
        // Determine specific context based on app type and window title
        let detectedContext = determineSpecificContext(appType: appType, windowTitle: windowTitle, bundleID: bundleID)
        
        // Update published properties
        currentApplication = appName
        currentWindowTitle = windowTitle
        currentContext = detectedContext
        
        print("🔍 Context updated: \(appName) (\(appType)) → \(detectedContext)")
    }
    
    /// Get the current application context with metadata
    func getCurrentContextInfo() -> ContextInfo {
        return ContextInfo(
            context: currentContext,
            applicationType: getApplicationType(from: currentContext),
            applicationName: currentApplication,
            windowTitle: currentWindowTitle,
            bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
            processID: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Methods
    
    /// Get window title using Accessibility API
    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Try to get the focused window first
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success,
               let titleString = title as? String {
                return titleString
            }
        }
        
        // Fallback: get the main window
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
           let windowArray = windows as? [AXUIElement],
           let firstWindow = windowArray.first {
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(firstWindow, kAXTitleAttribute as CFString, &title) == .success,
               let titleString = title as? String {
                return titleString
            }
        }
        
        return nil
    }
    
    /// Determine specific context based on application type and window title
    private func determineSpecificContext(appType: ApplicationType, windowTitle: String, bundleID: String) -> ApplicationContext {
        let lowercaseTitle = windowTitle.lowercased()
        
        // Check for specific patterns first
        for (pattern, context) in windowTitlePatterns {
            if lowercaseTitle.contains(pattern) {
                return context
            }
        }
        
        // Fall back to general app type contexts
        switch appType {
        case .email:
            return .emailGeneral
        case .codeEditor:
            return .codeEditor
        case .chat:
            return .chatGeneral
        case .document:
            return .documentGeneral
        case .browser:
            return .browserGeneral
        case .notes:
            return .notesGeneral
        case .terminal:
            return .terminal
        case .creative:
            return .creative
        case .social:
            return .social
        case .other:
            return .other
        }
    }
    
    /// Extract application type from context
    private func getApplicationType(from context: ApplicationContext) -> ApplicationType {
        switch context {
        case .emailGeneral, .emailCompose, .emailReply, .emailForward, .emailList, .webEmail:
            return .email
        case .codeEditor, .codeFile, .webCode:
            return .codeEditor
        case .chatGeneral, .chatThread, .chatDirect, .chatChannel:
            return .chat
        case .documentGeneral, .documentNew, .documentEdit:
            return .document
        case .browserGeneral:
            return .browser
        case .notesGeneral:
            return .notes
        case .terminal:
            return .terminal
        case .creative:
            return .creative
        case .social, .webSocial:
            return .social
        case .other, .unknown:
            return .other
        }
    }
}

// MARK: - Supporting Types

/// Application types for high-level categorization
enum ApplicationType: String, CaseIterable {
    case email = "Email"
    case codeEditor = "Code Editor"
    case chat = "Chat"
    case document = "Document"
    case browser = "Browser"
    case notes = "Notes"
    case terminal = "Terminal"
    case creative = "Creative"
    case social = "Social"
    case other = "Other"
}

/// Specific application contexts for targeted formatting
enum ApplicationContext: String, CaseIterable {
    // General contexts
    case unknown = "Unknown"
    case other = "Other"
    
    // Email contexts
    case emailGeneral = "Email General"
    case emailCompose = "Email Compose"
    case emailReply = "Email Reply"
    case emailForward = "Email Forward"
    case emailList = "Email List"
    
    // Code editor contexts
    case codeEditor = "Code Editor"
    case codeFile = "Code File"
    
    // Chat contexts
    case chatGeneral = "Chat General"
    case chatThread = "Chat Thread"
    case chatDirect = "Chat Direct Message"
    case chatChannel = "Chat Channel"
    
    // Document contexts
    case documentGeneral = "Document General"
    case documentNew = "Document New"
    case documentEdit = "Document Edit"
    
    // Browser contexts
    case browserGeneral = "Browser General"
    case webEmail = "Web Email"
    case webCode = "Web Code"
    case webSocial = "Web Social"
    
    // Other specific contexts
    case notesGeneral = "Notes"
    case terminal = "Terminal"
    case creative = "Creative"
    case social = "Social"
}

/// Complete context information for a detected application state
struct ContextInfo {
    let context: ApplicationContext
    let applicationType: ApplicationType
    let applicationName: String
    let windowTitle: String
    let bundleID: String
    let processID: pid_t
    let timestamp: Date
    
    /// Get a user-friendly description
    var description: String {
        if windowTitle.isEmpty {
            return "\(applicationName) (\(applicationType.rawValue))"
        } else {
            return "\(applicationName): \(windowTitle) (\(applicationType.rawValue))"
        }
    }
    
    /// Check if this context suggests formal communication
    var isFormalContext: Bool {
        switch context {
        case .emailCompose, .emailReply, .emailForward, .webEmail, .documentEdit:
            return true
        default:
            return false
        }
    }
    
    /// Check if this context suggests casual communication
    var isCasualContext: Bool {
        switch context {
        case .chatGeneral, .chatThread, .chatDirect, .chatChannel, .social, .webSocial:
            return true
        default:
            return false
        }
    }
    
    /// Check if this context suggests code formatting
    var isCodeContext: Bool {
        switch context {
        case .codeEditor, .codeFile, .webCode, .terminal:
            return true
        default:
            return false
        }
    }
}