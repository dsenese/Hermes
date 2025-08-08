//
//  SettingsModalView.swift
//  Hermes
//
//  Created by GPT-5 on 8/8/25.
//

import SwiftUI

/// Full-screen settings modal with sidebar sections
struct SettingsModalView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    @State private var selected: Section = .defaults

    enum Section: String, CaseIterable, Identifiable {
        case defaults = "Defaults"
        case ai = "Personalization"
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let modalWidth = min(max(proxy.size.width - 160, 700), 1100)
            let modalHeight = min(max(proxy.size.height - 120, 500), proxy.size.height - 80)

            ZStack(alignment: .topTrailing) {
                // Panel background
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(NSColor.separatorColor).opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 240)
                        .background(Color(NSColor.windowBackgroundColor))

                    // Divider drawn as a view to respect clipping
                    Rectangle()
                        .fill(Color(NSColor.separatorColor).opacity(0.2))
                        .frame(width: 1)

                    // Scrollable content area only
                    ScrollView {
                        content
                    }
                    .padding(.trailing, 8) // inset scroller from rounded edge
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollIndicators(.hidden)
                    .clipped()
                }

                // Close button inside the panel bounds
                Button(action: { withAnimation { isPresented = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(8)
                        .background(Circle().fill(Color(NSColor.controlBackgroundColor)))
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .frame(width: modalWidth, height: modalHeight)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.clear, lineWidth: 0)
            )
            .mask(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .compositingGroup()
        }
        .environmentObject(UserSettings.shared)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GENERAL")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 20)

            sidebarItem(.defaults, icon: "keyboard")

            Text("ACCOUNT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 24)

            sidebarItem(.ai, icon: "sparkles")

            Spacer()
        }
        .padding(20)
    }

    private func sidebarItem(_ section: Section, icon: String) -> some View {
        Button(action: { withAnimation { selected = section } }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(selected == section ? Color(hex: HermesConstants.primaryAccentColor) : .secondary)

                Text(section.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selected == section ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected == section ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch selected {
        case .defaults:
            defaultsContent
        case .ai:
            aiContent
        }
    }

    private var defaultsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Defaults")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 20)

            VStack(spacing: 16) {
                // Keyboard shortcuts
                card {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Set default keyboard shortcuts")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Choose your preferred keyboard shortcuts for using Hermes.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Change shortcut") {
                            // no-op; section already visible
                        }
                        .secondaryButtonStyle(size: .regular)
                    }
                }

                KeyboardShortcutCustomizationView(onSave: {}, onCancel: { isPresented = false }, isMainApp: true)
                    .environmentObject(userSettings)
            }

            Spacer()
        }
        .padding(24)
    }

    private var aiContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Personalization")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 20)

            VStack(spacing: 16) {
                HermesToggle(
                    "Enable AI formatting",
                    subtitle: "Automatically refine casing and punctuation",
                    isOn: Binding(
                        get: { AIFormattingService.shared.config.isEnabled },
                        set: { newValue in
                            var cfg = AIFormattingService.shared.config
                            cfg.isEnabled = newValue
                            AIFormattingService.shared.updateConfig(cfg)
                        }
                    )
                )

                HermesToggle(
                    "Apply custom dictionary",
                    subtitle: "Use your saved terms and corrections",
                    isOn: .constant(true) // Always applied today; placeholder for separate toggle if needed
                )
            }

            Spacer()
        }
        .padding(24)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { content() }
            .padding(16)
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
    SettingsModalView(isPresented: .constant(true))
        .environmentObject(UserSettings.shared)
        .frame(width: 1100, height: 700)
}


