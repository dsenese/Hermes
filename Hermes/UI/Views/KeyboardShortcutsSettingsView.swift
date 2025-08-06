//
//  KeyboardShortcutsSettingsView.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import SwiftUI

/// Standalone keyboard shortcuts settings view that can be displayed modally or in any context
struct KeyboardShortcutsSettingsView: View {
    @EnvironmentObject private var userSettings: UserSettings
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Customize your global dictation shortcut")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    onDismiss()
                }
                .primaryButtonStyle()
            }
            
            Divider()
            
            // Keyboard shortcut customization
            KeyboardShortcutCustomizationView(
                onSave: {
                    // Don't dismiss on save - let user continue configuring
                    print("✅ Keyboard shortcut saved")
                },
                onCancel: {
                    onDismiss()
                },
                isMainApp: true
            )
            .environmentObject(userSettings)
            
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    KeyboardShortcutsSettingsView(onDismiss: {})
        .environmentObject(UserSettings.shared)
        .frame(width: 600, height: 500)
}