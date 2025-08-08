//
//  ButtonStyles.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI
import AppKit

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    let isEnabled: Bool
    
    init(size: ButtonSize = .large, isEnabled: Bool = true) {
        self.size = size
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration, size: size, isEnabled: isEnabled)
    }
}

// MARK: - Internal hoverable primitives
private struct HoverStateModifier: ViewModifier {
    @State private var isHovering = false
    let onHoverChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                onHoverChange(hovering)
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

private struct PrimaryButton: View {
    let configuration: ButtonStyle.Configuration
    let size: ButtonSize
    let isEnabled: Bool
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(size.font)
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? .black : Color.secondary)
            .frame(height: size.height)
            .frame(maxWidth: size.maxWidth)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(isEnabled ? Color(hex: HermesConstants.primaryAccentColor) : Color.secondary.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(isEnabled ? Color.black.opacity(isHovering ? 0.2 : 0.12) : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: (isHovering && isEnabled) ? Color.black.opacity(0.18) : Color.clear, radius: 8, x: 0, y: 3)
            .modifier(HoverStateModifier { isHovering = $0 })
            .disabled(!isEnabled)
    }
}

private struct SecondaryButton: View {
    let configuration: ButtonStyle.Configuration
    let size: ButtonSize
    let isEnabled: Bool
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(size.font)
            .fontWeight(.medium)
            .foregroundColor(isEnabled ? .primary : Color.secondary)
            .frame(height: size.height)
            .frame(maxWidth: size.maxWidth)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(isEnabled ? Color(hex: HermesConstants.primaryAccentColor) : Color.secondary.opacity(0.2), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .fill(isHovering && isEnabled ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.08) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .modifier(HoverStateModifier { isHovering = $0 })
            .disabled(!isEnabled)
    }
}

// OAuth primitives (sized 180x36, 14pt medium as standardized)
private struct OAuthGoogleButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            GoogleGLogoView()
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12)) // ~#1F1F1F
        }
        .frame(width: 180, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isHovering ? Color(red: 0.24, green: 0.25, blue: 0.26) : Color(red: 0.45, green: 0.47, blue: 0.46), lineWidth: 1) // hover ~#3C4043, default #747775
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .modifier(HoverStateModifier { isHovering = $0 })
    }
}

private struct OAuthMicrosoftButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 0.5) {
                HStack(spacing: 0.5) {
                    Rectangle().fill(Color(red: 0.95, green: 0.31, blue: 0.20)).frame(width: 8, height: 8) // F25022
                    Rectangle().fill(Color(red: 0.50, green: 0.71, blue: 0.20)).frame(width: 8, height: 8) // 7FBA00
                }
                HStack(spacing: 0.5) {
                    Rectangle().fill(Color(red: 0.00, green: 0.64, blue: 0.94)).frame(width: 8, height: 8) // 00A4EF
                    Rectangle().fill(Color(red: 1.00, green: 0.74, blue: 0.02)).frame(width: 8, height: 8) // FFB900
                }
            }
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 180, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.00, green: 0.47, blue: 0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(isHovering ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .modifier(HoverStateModifier { isHovering = $0 })
    }
}

private struct OAuthAppleButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.logo")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 180, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovering ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .modifier(HoverStateModifier { isHovering = $0 })
    }
}

private struct OAuthSSOButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.29, green: 0.29, blue: 0.29))
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.29, green: 0.29, blue: 0.29))
        }
        .frame(width: 180, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isHovering ? Color(red: 0.60, green: 0.60, blue: 0.60) : Color(red: 0.70, green: 0.70, blue: 0.70), lineWidth: 1)
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .modifier(HoverStateModifier { isHovering = $0 })
    }
}

// Simple SwiftUI drawing of the Google "G" with brand colors for macOS app usage until asset is added
private struct GoogleGShape: View {
    var body: some View {
        ZStack {
            // Using a simple circle segments approximation for the G logo look
            Circle().trim(from: 0.0, to: 0.25).rotation(Angle(degrees: 0)).stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: 3)
            Circle().trim(from: 0.25, to: 0.5).rotation(Angle(degrees: 0)).stroke(Color(red: 0.98, green: 0.74, blue: 0.02), lineWidth: 3)
            Circle().trim(from: 0.5, to: 0.75).rotation(Angle(degrees: 0)).stroke(Color(red: 0.20, green: 0.66, blue: 0.34), lineWidth: 3)
            Circle().trim(from: 0.75, to: 0.95).rotation(Angle(degrees: 0)).stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: 3)
            Rectangle()
                .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                .frame(width: 6, height: 3)
                .offset(x: 3, y: 0)
        }
    }
}

// Prefer official asset "GoogleG" in Assets.xcassets (PDF/SVG); fallback to vector shape
private struct GoogleGLogoView: View {
    var body: some View {
        Group {
            if NSImage(named: "GoogleG") != nil {
                Image("GoogleG")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                GoogleGShape()
            }
        }
        .frame(width: 18, height: 18)
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
        SecondaryButton(configuration: configuration, size: size, isEnabled: isEnabled)
    }
}

// Neutral secondary style (pre-brand-border look) for places like email toggle
struct SecondaryNeutralButtonStyle: ButtonStyle {
    let size: ButtonSize
    let isEnabled: Bool
    @State private var isHovering = false

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
                    .stroke(isEnabled ? (isHovering ? Color.secondary.opacity(0.5) : Color.secondary.opacity(0.3)) : Color.secondary.opacity(0.2), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .fill(isHovering && isEnabled ? Color.secondary.opacity(0.06) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .modifier(HoverStateModifier { isHovering = $0 })
            .disabled(!isEnabled)
    }
}

// MARK: - OAuth Button Styles (Following Official Design Guidelines)

/// Google Sign-In button following Google's exact design guidelines
/// Ref: https://developers.google.com/identity/branding-guidelines
/// Note: Replace "globe" with actual Google G logo asset when available
struct GoogleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OAuthGoogleButton(configuration: configuration)
    }
}

/// Microsoft Sign-In button following Microsoft's exact guidelines
/// Ref: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-branding-in-azure-ad-apps
struct MicrosoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OAuthMicrosoftButton(configuration: configuration)
    }
}

/// Apple Sign-In button following Apple's Human Interface Guidelines
/// Ref: https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
struct AppleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OAuthAppleButton(configuration: configuration)
    }
}

/// Enterprise/SSO Sign-In button with professional styling
struct SSOButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OAuthSSOButton(configuration: configuration)
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

// MARK: - Plain/Borderless Hover Button Styles (global pointer + subtle feedback)
struct PlainHoverButtonStyle: ButtonStyle {
    @State private var isHovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.secondary.opacity(0.08) : Color.clear)
            )
            .modifier(HoverStateModifier { isHovering = $0 })
    }
}

struct BorderlessHoverButtonStyle: ButtonStyle {
    @State private var isHovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovering ? Color.secondary.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .modifier(HoverStateModifier { isHovering = $0 })
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
    
    func secondaryNeutralButtonStyle(size: ButtonSize = .regular, isEnabled: Bool = true) -> some View {
        self.buttonStyle(SecondaryNeutralButtonStyle(size: size, isEnabled: isEnabled))
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
    
    func keyboardKeyStyle(isSelected: Bool = false, isPressed: Bool = false, width: CGFloat = 50) -> some View {
        self.buttonStyle(KeyboardKeyStyle(isSelected: isSelected, isPressed: isPressed, width: width))
    }

    // Global replacements for plain/borderless to add pointer cursor and hover
    func plainHoverButtonStyle() -> some View {
        self.buttonStyle(PlainHoverButtonStyle())
    }

    func borderlessHoverButtonStyle() -> some View {
        self.buttonStyle(BorderlessHoverButtonStyle())
    }
}