//
//  HermesDropdown.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// A custom dropdown component that follows Hermes design guidelines
struct HermesDropdown<SelectionValue: Hashable>: View {
    let title: String?
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]
    let placeholder: String
    
    @State private var isHovered = false
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool
    
    init(
        title: String? = nil,
        selection: Binding<SelectionValue>,
        options: [(value: SelectionValue, label: String)],
        placeholder: String = "Select an option"
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            // Dropdown button with popover
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(currentSelectionLabel)
                        .font(.system(size: 14))
                        .foregroundColor(hasSelection ? .primary : .secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isExpanded ? Color(hex: HermesConstants.primaryAccentColor) :
                                    isFocused ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.6) :
                                    isHovered ? Color.secondary.opacity(0.5) :
                                    Color.secondary.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .onHover { hovering in
                isHovered = hovering
            }
            .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
                dropdownContent
                    .frame(width: 250)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var currentSelectionLabel: String {
        if let option = options.first(where: { $0.value == selection }) {
            return option.label
        }
        return placeholder
    }
    
    private var hasSelection: Bool {
        options.contains(where: { $0.value == selection })
    }
    
    private func isSelected(_ value: SelectionValue) -> Bool {
        selection == value
    }
    
    private var dropdownContent: some View {
        VStack(spacing: 0) {
            let maxVisibleItems = 8
            let needsScroll = options.count > maxVisibleItems
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selection = option.value
                                isExpanded = false
                            }
                        }) {
                            HStack {
                                Text(option.label)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if isSelected(option.value) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(DropdownItemButtonStyle(isSelected: isSelected(option.value)))
                        
                        if index < options.count - 1 {
                            Divider()
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
            .frame(maxHeight: needsScroll ? 320 : nil)
        }
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Dropdown Item Button Style
struct DropdownItemButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Rectangle()
                    .fill(
                        configuration.isPressed ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.2) :
                        isHovered ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.1) :
                        isSelected ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.05) :
                        Color.clear
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Convenience initializer for String options
extension HermesDropdown where SelectionValue == String {
    init(
        title: String? = nil,
        selection: Binding<String>,
        options: [String],
        placeholder: String = "Select an option"
    ) {
        self.init(
            title: title,
            selection: selection,
            options: options.map { ($0, $0) },
            placeholder: placeholder
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        HermesDropdown(
            title: "Select Language",
            selection: .constant("English"),
            options: ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Japanese", "Korean", "Chinese", "Russian"],
            placeholder: "Choose a language"
        )
        .frame(width: 250)
        
        HermesDropdown(
            title: "Audio Input",
            selection: .constant("Built-in Microphone"),
            options: ["Built-in Microphone", "USB Microphone", "AirPods Pro"],
            placeholder: "Select microphone"
        )
        .frame(width: 300)
        
        Text("Some content below the dropdowns")
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
    }
    .padding(40)
    .frame(width: 600, height: 400)
    .background(Color(NSColor.windowBackgroundColor))
}