//
//  HermesTextArea.swift
//  Hermes
//
//  Created by GPT-5 on 8/7/25.
//

import SwiftUI

/// A custom multiline text area with Hermes styling, placeholder, and focus states
struct HermesTextArea: View {
    let title: String?
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let font: Font?
    let foregroundColor: Color?
    let backgroundColor: Color?

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    init(
        title: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 120,
        maxHeight: CGFloat? = nil,
        font: Font? = .system(size: 14),
        foregroundColor: Color? = .primary,
        backgroundColor: Color? = Color(NSColor.textBackgroundColor)
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor ?? Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                    .shadow(color: isFocused ? Color.black.opacity(0.08) : Color.clear,
                            radius: isFocused ? 6 : 0, x: 0, y: 2)

                TextEditor(text: $text)
                    .font(font)
                    .foregroundColor(foregroundColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .frame(minHeight: minHeight, maxHeight: maxHeight)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)

                if text.isEmpty {
                    Text(placeholder)
                        .font(font)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.2), value: isFocused)
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

    private var borderWidth: CGFloat { isFocused ? 2 : 1 }
}

// MARK: - Convenience
extension View {
    func hermesTextArea(
        title: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 120,
        maxHeight: CGFloat? = nil,
        font: Font? = .system(size: 14),
        foregroundColor: Color? = .primary,
        backgroundColor: Color? = Color(NSColor.textBackgroundColor)
    ) -> some View {
        HermesTextArea(
            title: title,
            text: text,
            placeholder: placeholder,
            minHeight: minHeight,
            maxHeight: maxHeight,
            font: font,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HermesTextArea(
            title: "Message",
            text: .constant(""),
            placeholder: "Type your message...",
            minHeight: 100
        )
        HermesTextArea(
            title: "Code",
            text: .constant("// Write here"),
            placeholder: "// Add code...",
            minHeight: 120,
            font: .system(size: 12, design: .monospaced),
            foregroundColor: .white,
            backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.12)
        )
    }
    .padding(24)
}


