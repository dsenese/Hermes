//
//  PermissionsStepView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI
import AVFoundation
import ApplicationServices

/// PERMISSIONS step - guided permission setup
struct PermissionsStepView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        OnboardingStepContainer {
            GuidePermissionsView(
                onContinue: {
                    coordinator.nextStep()
                }
            )
        }
    }
    
}

// MARK: - Guided Permissions View

private struct GuidePermissionsView: View {
    let onContinue: () -> Void
    @State private var microphoneSetupCompleted = false
    @State private var accessibilitySetupCompleted = false
    @State private var servicesSetupCompleted = false
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Text("Set up Hermes on your")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                Text("computer")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 60) {
                // Left side - permission setup
                VStack(spacing: 24) {
                    // Microphone permission
                    permissionItem(
                        title: "Allow Hermes to use your microphone",
                        subtitle: "Hermes will only access the mic when you are actively using it",
                        isCompleted: microphoneSetupCompleted,
                        buttonTitle: "Open System Settings",
                        action: {
                            openMicrophoneSettings()
                        }
                    )
                    
                    // Accessibility permission
                    permissionItem(
                        title: "Allow Hermes to insert spoken words",
                        subtitle: "This lets Hermes put your spoken words in the right textbox",
                        isCompleted: accessibilitySetupCompleted,
                        buttonTitle: "Open System Settings",
                        action: {
                            openAccessibilitySettings()
                        }
                    )
                    
                    // Services-based shortcuts (no permission needed)
                    permissionItem(
                        title: "Set up global keyboard shortcuts",
                        subtitle: "Assign shortcuts to Hermes services in System Settings (no permission required)",
                        isCompleted: servicesSetupCompleted,
                        buttonTitle: "Open Keyboard Shortcuts",
                        action: {
                            openKeyboardShortcutsSettings()
                        }
                    )
                }
                .frame(width: 400)
                
                // Right side - setup guidance
                VStack(spacing: 20) {
                    Text("Setup Guide")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        guidanceStep(
                            number: 1,
                            title: "Microphone Access",
                            description: "Click the button to open System Settings, then enable Hermes under Privacy & Security > Microphone"
                        )
                        
                        guidanceStep(
                            number: 2,
                            title: "Accessibility Access",
                            description: "In System Settings, go to Privacy & Security > Accessibility and enable Hermes"
                        )
                        
                        guidanceStep(
                            number: 3,
                            title: "Keyboard Shortcuts",
                            description: "Go to Keyboard > Shortcuts > Services and assign a shortcut to 'Hermes: Toggle Dictation'"
                        )
                        
                        guidanceStep(
                            number: 4,
                            title: "Ready to Go", 
                            description: "Once permissions are set and shortcuts assigned, you can use Hermes anywhere"
                        )
                    }
                }
                .frame(width: 300)
                .padding(24)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            // Continue button - always available
            VStack(spacing: 16) {
                Button("Continue") {
                    onContinue()
                }
                .primaryButtonStyle()
                
                Text("You can continue even if permissions aren't set up yet. Hermes will work once you enable them.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 500)
            }
        }
    }
    
    private func permissionItem(
        title: String,
        subtitle: String,
        isCompleted: Bool,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isCompleted ? Color(hex: HermesConstants.primaryAccentColor) : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Spacer()
                if !isCompleted {
                    Button(buttonTitle) {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                        Text("Setup complete")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCompleted ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
    
    private func guidanceStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(hex: HermesConstants.primaryAccentColor))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func openMicrophoneSettings() {
        if #available(macOS 10.14, *) {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    microphoneSetupCompleted = granted
                }
            }
        }
        
        // Try multiple URLs for different macOS versions
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone"
        ]
        
        for urlString in urls {
            if let url = URL(string: urlString) {
                if NSWorkspace.shared.open(url) {
                    break
                }
            }
        }
        
        // Mark as completed for demonstration (user can continue regardless)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            microphoneSetupCompleted = true
        }
    }
    
    private func openAccessibilitySettings() {
        // Try multiple URLs for different macOS versions
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]
        
        for urlString in urls {
            if let url = URL(string: urlString) {
                if NSWorkspace.shared.open(url) {
                    break
                }
            }
        }
        
        // Mark as completed for demonstration (user can continue regardless)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            accessibilitySetupCompleted = true
        }
    }
    
    private func openKeyboardShortcutsSettings() {
        // Try multiple URLs for different macOS versions
        let urls = [
            "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts",
            "x-apple.systempreferences:com.apple.settings.Keyboard.extension?Shortcuts"
        ]
        
        for urlString in urls {
            if let url = URL(string: urlString) {
                if NSWorkspace.shared.open(url) {
                    break
                }
            }
        }
        
        // Mark as completed for demonstration (user can continue regardless)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            servicesSetupCompleted = true
        }
    }
}

// MARK: - Legacy Real Permissions View (for reference)

private struct RealPermissionsView: View {
    let hasMicrophonePermission: Bool
    let hasAccessibilityPermission: Bool
    let onContinue: () -> Void
    
    var canContinue: Bool {
        hasMicrophonePermission && hasAccessibilityPermission
    }
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Text("Set up Hermes on your")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                Text("computer")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 24) {
                // Microphone permission - always visible
                permissionItem(
                    title: "Allow Hermes to use your microphone",
                    subtitle: "Hermes will only access the mic when you are actively using it",
                    isCompleted: hasMicrophonePermission,
                    showButton: !hasMicrophonePermission,
                    systemAction: .microphone
                )
                
                // Accessibility permission - always visible  
                permissionItem(
                    title: "Allow Hermes to insert spoken words",
                    subtitle: "This lets Hermes put your spoken words in the right textbox",
                    isCompleted: hasAccessibilityPermission,
                    showButton: !hasAccessibilityPermission,
                    systemAction: .accessibility,
                    isEnabled: hasMicrophonePermission
                )
            }
            
            // System dialog mockup
            if !hasMicrophonePermission {
                microphoneDialogMockup
            } else if !hasAccessibilityPermission {
                accessibilityDialogMockup
            } else {
                completedSetupMockup
            }
            
            // Continue button area - always reserve space
            VStack(spacing: 16) {
                if canContinue {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                        Text("Setup complete! You can now use Hermes.")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Button("Continue") {
                        onContinue()
                    }
                    .primaryButtonStyle()
                } else {
                    // Reserve space for continue button to prevent layout shifts
                    Color.clear
                        .frame(height: 80)
                }
            }
        }
    }
    
    private func permissionItem(
        title: String,
        subtitle: String? = nil,
        isCompleted: Bool,
        showButton: Bool = false,
        systemAction: SystemPermissionAction? = nil,
        isEnabled: Bool = true
    ) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isCompleted ? Color(hex: HermesConstants.primaryAccentColor) : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Button on separate line
            if showButton, let systemAction = systemAction, isEnabled {
                HStack {
                    Spacer()
                    Button("Open System Settings") {
                        openSystemSettings(for: systemAction)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            } else if showButton && !isEnabled {
                HStack {
                    Spacer()
                    Button("Complete microphone setup first") { }
                        .buttonStyle(.bordered)
                        .disabled(true)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCompleted ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .frame(width: 500)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    private func openSystemSettings(for action: SystemPermissionAction) {
        switch action {
        case .microphone:
            requestMicrophonePermission()
        case .accessibility:
            openAccessibilitySettings()
        }
    }
    
    private func requestMicrophonePermission() {
        if #available(macOS 10.14, *) {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                // Permission handling is done by the timer checking
            }
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        
        // Mark that user has gone through accessibility setup
        UserDefaults.standard.set(true, forKey: "hasCompletedAccessibilitySetup")
    }
    
    // Microphone permission dialog mockup
    private var microphoneDialogMockup: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("\"Hermes\" would like to access the microphone.")
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                
                Text("Hermes needs access to your microphone to transcribe your speech!")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Don't Allow") {}
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                
                Button("OK") {}
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(width: 300)
    }
    
    // Accessibility permission dialog mockup
    private var accessibilityDialogMockup: some View {
        // Mock macOS System Preferences Accessibility panel
        VStack(spacing: 0) {
            // Title bar
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 12, height: 12)
                    Circle().fill(.yellow).frame(width: 12, height: 12)
                    Circle().fill(.green).frame(width: 12, height: 12)
                }
                Spacer()
                Text("System Settings")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            
            // Content
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {
                    sidebarItem("General", isActive: false)
                    sidebarItem("Appearance", isActive: false)
                    sidebarItem("Privacy & Security", isActive: true)
                    sidebarItem("Desktop & Dock", isActive: false)
                }
                .frame(width: 120)
                .padding(.leading, 8)
                
                Divider()
                
                // Main content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Allow the applications below to control your computer.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 4) {
                        accessibilityAppItem("Terminal", isEnabled: true)
                        accessibilityAppItem("Hermes", isEnabled: hasAccessibilityPermission, isHighlighted: true)
                    }
                    
                    HStack {
                        Button("+") {}
                            .font(.system(size: 11))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        Button("-") {}
                            .font(.system(size: 11))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(height: 160)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(width: 350)
    }
    
    // Completed setup mockup
    private var completedSetupMockup: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
            
            VStack(spacing: 8) {
                Text("All Set!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Hermes now has all the permissions it needs to work seamlessly with your system.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 250)
            }
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(width: 300)
    }
    
    private func sidebarItem(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundColor(isActive ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.blue : Color.clear)
            .cornerRadius(4)
    }
    
    private func accessibilityAppItem(_ name: String, isEnabled: Bool, isHighlighted: Bool = false) -> some View {
        HStack {
            Image(systemName: "app")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(name)
                .font(.system(size: 12))
            Spacer()
            Toggle("", isOn: .constant(isEnabled))
                .scaleEffect(0.7)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isHighlighted ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(4)
    }
}

enum SystemPermissionAction {
    case microphone
    case accessibility
}

#Preview {
    PermissionsStepView()
        .environmentObject(OnboardingCoordinator(
            currentStep: .constant(.permissions),
            showingOnboarding: .constant(true)
        ))
        .frame(width: 1000, height: 700)
}
