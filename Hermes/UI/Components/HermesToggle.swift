//
//  HermesToggle.swift
//  Hermes
//
//  Created by GPT-5 on 8/8/25.
//

import SwiftUI

/// Hermes-styled modern toggle switch
struct HermesToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: HermesConstants.primaryAccentColor)))
                .labelsHidden()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        HermesToggle("Enable AI formatting", subtitle: "Automatically improve punctuation and casing", isOn: .constant(true))
        HermesToggle("Apply custom dictionary", subtitle: "Use your saved terms and corrections", isOn: .constant(true))
    }
    .padding()
    .frame(width: 480)
}


