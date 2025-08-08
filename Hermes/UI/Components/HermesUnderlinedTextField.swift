//
//  HermesUnderlinedTextField.swift
//  Hermes
//
//  A minimal underlined text field suitable for search bars and compact inputs
//

import SwiftUI

struct HermesUnderlinedTextField: View {
    @Binding var text: String
    let placeholder: String
    var leadingSystemImage: String? = nil
    var onCommit: (() -> Void)? = nil

    @FocusState private var focused: Bool
    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = leadingSystemImage {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }

            TextField("", text: $text, onCommit: { onCommit?() })
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($focused)
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.vertical, 6)
        .onHover { hovered = $0 }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(underlineColor)
                .frame(height: focused ? 2 : 1)
        }
        .animation(.easeInOut(duration: 0.15), value: focused)
    }

    private var underlineColor: Color {
        if focused { return Color(hex: HermesConstants.primaryAccentColor) }
        if hovered { return .secondary.opacity(0.6) }
        return .secondary.opacity(0.35)
    }
}

// MARK: - Convenience
extension View {
    func hermesUnderlinedTextField(text: Binding<String>, placeholder: String, leadingSystemImage: String? = nil, onCommit: (() -> Void)? = nil) -> some View {
        HermesUnderlinedTextField(text: text, placeholder: placeholder, leadingSystemImage: leadingSystemImage, onCommit: onCommit)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        HermesUnderlinedTextField(text: .constant(""), placeholder: "Search notes", leadingSystemImage: "magnifyingglass")
        HermesUnderlinedTextField(text: .constant("query"), placeholder: "Search", leadingSystemImage: "magnifyingglass")
    }
    .padding(20)
}


