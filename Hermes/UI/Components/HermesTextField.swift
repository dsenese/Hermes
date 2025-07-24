//
//  HermesTextField.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// A custom text field component that follows Hermes design guidelines
struct HermesTextField: View {
    let title: String?
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    // Note: keyboardType is iOS-specific, not used on macOS
    
    @State private var isHovered = false
    @State private var isFocused = false
    @FocusState private var textFieldFocused: Bool
    
    init(
        title: String? = nil,
        text: Binding<String>,
        placeholder: String,
        isSecure: Bool = false,
        keyboardType: Any? = nil // Placeholder for iOS compatibility
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
        // keyboardType not used on macOS
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            ZStack(alignment: .leading) {
                // Custom background and border
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                    .frame(height: 40)
                
                // Text field with no styling
                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .font(.system(size: 14))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .focused($textFieldFocused)
                
                // Custom placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .onChange(of: textFieldFocused) { _, focused in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFocused = focused
                }
            }
        }
    }
    
    private var borderColor: Color {
        if isFocused {
            return Color(hex: HermesConstants.primaryAccentColor)
        } else if isHovered {
            return Color.secondary.opacity(0.5)
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isFocused ? 2 : 1
    }
}


// MARK: - Convenience Extensions
extension View {
    func hermesTextField(
        title: String? = nil,
        text: Binding<String>,
        placeholder: String,
        isSecure: Bool = false,
        keyboardType: Any? = nil // Placeholder for iOS compatibility
    ) -> some View {
        HermesTextField(
            title: title,
            text: text,
            placeholder: placeholder,
            isSecure: isSecure,
            keyboardType: keyboardType
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        HermesTextField(
            title: "Email Address",
            text: Binding.constant(""),
            placeholder: "Enter your email"
        )
        .frame(width: 300)
        
        HermesTextField(
            title: "Password",
            text: Binding.constant(""),
            placeholder: "Enter your password",
            isSecure: true
        )
        .frame(width: 300)
        
        HermesTextField(
            text: Binding.constant("john@example.com"),
            placeholder: "Email"
        )
        .frame(width: 300)
    }
    .padding(40)
    .background(Color(NSColor.windowBackgroundColor))
}