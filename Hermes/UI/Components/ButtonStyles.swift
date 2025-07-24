//
//  ButtonStyles.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    let isEnabled: Bool
    
    init(size: ButtonSize = .large, isEnabled: Bool = true) {
        self.size = size
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? .black : Color.secondary)
            .frame(height: size.height)
            .frame(maxWidth: size.maxWidth)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(isEnabled ? Color(hex: HermesConstants.primaryAccentColor) : Color.secondary.opacity(0.3))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .disabled(!isEnabled)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    let isEnabled: Bool
    
    init(size: ButtonSize = .large, isEnabled: Bool = true) {
        self.size = size
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.medium)
            .foregroundColor(isEnabled ? .primary : Color.secondary)
            .frame(height: size.height)
            .frame(maxWidth: size.maxWidth)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(isEnabled ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .fill(Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .disabled(!isEnabled)
    }
}

// MARK: - OAuth Button Styles (Following Official Design Guidelines)

/// Google Sign-In button following Google's exact design guidelines
/// Ref: https://developers.google.com/identity/branding-guidelines
/// Note: Replace "globe" with actual Google G logo asset when available
struct GoogleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            // Google "G" logo with correct colors
            // TODO: Replace with actual Google G logo asset
            Image(systemName: "globe") // Placeholder - should use actual Google G logo
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96)) // Google Blue #4285F4
            
            configuration.label
                .font(.system(size: 14, weight: .medium)) // Google's Roboto medium
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25)) // #3c4043
        }
        .frame(width: 180, height: 36) // Consistent OAuth button size
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1) // #dadce0
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

/// Microsoft Sign-In button following Microsoft's exact guidelines
/// Ref: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-branding-in-azure-ad-apps
struct MicrosoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            // Microsoft 4-square logo with exact colors
            VStack(spacing: 0.5) {
                HStack(spacing: 0.5) {
                    Rectangle().fill(Color(red: 0.96, green: 0.26, blue: 0.21)).frame(width: 8, height: 8) // #F25022
                    Rectangle().fill(Color(red: 0.50, green: 0.71, blue: 0.20)).frame(width: 8, height: 8) // #7FBA00
                }
                HStack(spacing: 0.5) {
                    Rectangle().fill(Color(red: 0.01, green: 0.66, blue: 0.96)).frame(width: 8, height: 8) // #00A4EF
                    Rectangle().fill(Color(red: 1.00, green: 0.74, blue: 0.02)).frame(width: 8, height: 8) // #FFB900
                }
            }
            
            configuration.label
                .font(.system(size: 13, weight: .semibold)) // Segoe UI Semibold 13pt
                .foregroundColor(.white)
        }
        .frame(width: 180, height: 36) // Consistent OAuth button size
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.00, green: 0.47, blue: 0.84)) // #0078D4 Microsoft Blue
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

/// Apple Sign-In button following Apple's Human Interface Guidelines
/// Ref: https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
struct AppleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.logo")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            configuration.label
                .font(.system(size: 16, weight: .semibold)) // Apple specifies semibold
                .foregroundColor(.white)
        }
        .frame(width: 180, height: 36) // Consistent with other OAuth buttons
        .background(
            RoundedRectangle(cornerRadius: 6) // Apple uses 6pt radius
                .fill(Color.black)
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

/// Enterprise/SSO Sign-In button with professional styling
struct SSOButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.29, green: 0.29, blue: 0.29)) // Professional gray
            
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.29, green: 0.29, blue: 0.29))
        }
        .frame(width: 180, height: 36) // Consistent with other OAuth buttons
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 0.70, green: 0.70, blue: 0.70), lineWidth: 1)
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Keyboard Key Button Style
struct KeyboardKeyStyle: ButtonStyle {
    let isSelected: Bool
    let isPressed: Bool
    let width: CGFloat
    
    init(isSelected: Bool = false, isPressed: Bool = false, width: CGFloat = 50) {
        self.isSelected = isSelected
        self.isPressed = isPressed
        self.width = width
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isPressed ? .black : (isSelected ? Color(hex: HermesConstants.primaryAccentColor) : .primary))
            .frame(width: width, height: 36)
            .background(
                ZStack {
                    // 3D shadow effect
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                        .offset(y: 2)
                    
                    // Main button
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPressed ? Color(hex: HermesConstants.primaryAccentColor) : Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color(hex: HermesConstants.primaryAccentColor) : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Sizes
enum ButtonSize {
    case small
    case regular
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return 28
        case .regular: return 36
        case .large: return 40
        }
    }
    
    var font: Font {
        switch self {
        case .small: return .system(size: 13, weight: .medium)
        case .regular: return .system(size: 14, weight: .medium)
        case .large: return .system(size: 16, weight: .semibold)
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small: return 6
        case .regular: return 8
        case .large: return 10
        }
    }
    
    var maxWidth: CGFloat? {
        switch self {
        case .small: return 100
        case .regular: return 160
        case .large: return 200
        }
    }
}

// MARK: - Convenience Extensions
extension View {
    func primaryButtonStyle(size: ButtonSize = .regular, isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(size: size, isEnabled: isEnabled))
    }
    
    func secondaryButtonStyle(size: ButtonSize = .regular, isEnabled: Bool = true) -> some View {
        self.buttonStyle(SecondaryButtonStyle(size: size, isEnabled: isEnabled))
    }
    
    func googleButtonStyle() -> some View {
        self.buttonStyle(GoogleButtonStyle())
    }
    
    func microsoftButtonStyle() -> some View {
        self.buttonStyle(MicrosoftButtonStyle())
    }
    
    func appleButtonStyle() -> some View {
        self.buttonStyle(AppleButtonStyle())
    }
    
    func ssoButtonStyle() -> some View {
        self.buttonStyle(SSOButtonStyle())
    }
    
    func gmailButtonStyle() -> some View {
        self.buttonStyle(GoogleButtonStyle())
    }
    
    func keyboardKeyStyle(isSelected: Bool = false, isPressed: Bool = false, width: CGFloat = 50) -> some View {
        self.buttonStyle(KeyboardKeyStyle(isSelected: isSelected, isPressed: isPressed, width: width))
    }
}