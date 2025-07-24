//
//  MainAppView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI
import AppKit

/// Main dashboard view with sidebar navigation and activity timeline
struct MainAppView: View {
    @StateObject private var dictationEngine = DictationEngine()
    @State private var selectedSection: SidebarSection = .home
    @State private var userName: String = "isabela"
    @State private var userEmail: String = "isaccosta.889@gmail.com"
    @State private var showingOnboarding: Bool = true // TODO: Check if user has completed onboarding
    @State private var showingProfileMenu: Bool = false
    @State private var showingSettingsMenu: Bool = false
    
    var body: some View {
        ZStack {
            // Main app content
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: 220)
                    .background(sidebarBackground)
                
                // Main content area
                mainContent
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
            .disabled(showingOnboarding)
            
            // Onboarding overlay - solid background
            if showingOnboarding {
                OnboardingView(showingOnboarding: $showingOnboarding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .cornerRadius(12)
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // TODO: Load user data and stats
            // TODO: Check if user has completed onboarding
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with logo
            sidebarHeader
                .padding(.top, 24)
                .padding(.horizontal, 16)
            
            // Navigation items - moved up
            navigationItems
                .padding(.horizontal, 8)
                .padding(.top, 24)
            
            Spacer()
            
            // Trial info - moved above footer
            trialInfoSection
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            // Footer items
            sidebarFooter
                .padding(.horizontal, 8)
                .padding(.bottom, 24)
        }
    }
    
    private var sidebarHeader: some View {
        // Logo with icon only
        HStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
            
            Text("Hermes")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            // Pro trial badge with green background and grey text
            Text("Pro Trial")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(hex: HermesConstants.primaryAccentColor))
                .cornerRadius(8)
        }
    }
    
    private var trialInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hermes Pro Trial")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("0 of 14 days used")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Progress bar
            HStack {
                Rectangle()
                    .fill(Color(hex: HermesConstants.primaryAccentColor))
                    .frame(width: 0, height: 3)
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(1.5)
            
            Text("Upgrade to Hermes Pro\nbefore your trial ends")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Button("Explore Pro") {
                // TODO: Handle upgrade action
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(6)
        }
    }
    
    private var navigationItems: some View {
        VStack(spacing: 4) {
            ForEach(SidebarSection.allCases, id: \.self) { section in
                sidebarItem(section)
            }
        }
    }
    
    private func sidebarItem(_ section: SidebarSection) -> some View {
        Button(action: {
            selectedSection = section
        }) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 16))
                    .foregroundColor(selectedSection == section ? Color(hex: HermesConstants.primaryAccentColor) : .secondary)
                    .frame(width: 20)
                
                Text(section.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedSection == section ? .primary : .secondary)
                
                Spacer()
                
                if section == .home {
                    // Activity indicator
                    Circle()
                        .fill(Color(hex: HermesConstants.primaryAccentColor))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSection == section ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var sidebarFooter: some View {
        VStack(spacing: 12) {
            // Add your team
            Button(action: {}) {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text("Add your team")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Refer a friend
            Button(action: {}) {
                HStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text("Refer a friend")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Help
            Button(action: {}) {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text("Help")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            mainHeader
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor))
                        .opacity(0.3),
                    alignment: .bottom
                )
            
            // Content
            ScrollView {
                contentForSelectedSection
                    .padding(.horizontal, 32)
                    .padding(.top, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                if showingProfileMenu {
                    showingProfileMenu = false
                }
                if showingSettingsMenu {
                    showingSettingsMenu = false
                }
            }
        }
    }
    
    private var mainHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back, \(userName)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("0 weeks")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // User profile menu with Pro Trial badge
            Button(action: {
                showingProfileMenu.toggle()
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(userName) carvalho")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Text(userEmail)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Profile avatar
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("IC")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                        )
                    
                    Text("Pro Trial")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: HermesConstants.primaryAccentColor))
                        .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .padding(8)
            
            // Settings button - moved outside and to the far right
            Button(action: {
                showingSettingsMenu.toggle()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .overlay(
            // Dropdown menus
            Group {
                if showingProfileMenu {
                    profileDropdownMenu
                        .offset(x: -80, y: 60)
                }
                
                if showingSettingsMenu {
                    settingsDropdownMenu
                        .offset(x: -20, y: 60)
                }
            },
            alignment: .topTrailing
        )
    }
    
    
    // MARK: - Content Sections
    
    @ViewBuilder
    private var contentForSelectedSection: some View {
        switch selectedSection {
        case .home:
            homeContent
        case .dictionary:
            dictionaryContent
        case .notes:
            notesContent
        }
    }
    
    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Voice dictation instructions
            voiceDictationSection
            
            // Recent Activity
            recentActivitySection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var profileDropdownMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Refer a friend section
            VStack(alignment: .leading, spacing: 8) {
                Text("Get 1 month of Hermes Pro free")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Refer friends, earn rewards")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Button("Refer a friend") {
                    // TODO: Handle refer action
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(6)
            }
            .padding(16)
            
            Divider()
            
            // Download app
            Button(action: {}) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                    Text("Download Hermes for iOS")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "qrcode")
                        .font(.system(size: 12))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // Manage account
            Button(action: {}) {
                Text("Manage account")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(width: 250)
        .zIndex(100)
    }
    
    private var settingsDropdownMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Keyboard shortcuts
            Button(action: {}) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // Preferences
            Button(action: {}) {
                Text("Preferences")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // About
            Button(action: {}) {
                Text("About Hermes")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(width: 180)
        .zIndex(100)
    }
    
    private var voiceDictationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice dictation in any app")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
                Text("Hold down the trigger key")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text("fn")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(NSColor.quaternaryLabelColor).opacity(0.3))
                    )
                
                Text("and speak into any textbox")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Other Content Sections
    
    private var dictionaryContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Dictionary")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Custom words and phrases coming soon...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var notesContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Notes")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Voice notes and recordings coming soon...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Computed Properties
    
    
    private var sidebarBackground: some View {
        // Use design system colors for sidebar
        Color(NSColor.windowBackgroundColor)
            .overlay(
                Rectangle()
                    .fill(sidebarTintColor)
            )
    }
    
    private var sidebarTintColor: Color {
        // Light mode: #F5F5F7, Dark mode: #2C2C2E (from design system)
        if NSApp.effectiveAppearance.name == .darkAqua {
            return Color(hex: "2C2C2E")
        } else {
            return Color(hex: "F5F5F7")
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent activity")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                HStack(spacing: 12) {
                    Text("03:04 PM")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    
                    Text("Hello, this is Isabela.")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    
}

// MARK: - Supporting Types

enum SidebarSection: String, CaseIterable {
    case home = "Home"
    case dictionary = "Dictionary"
    case notes = "Notes"
    
    var title: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .dictionary: return "book.fill"
        case .notes: return "note.text.fill"
        }
    }
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let time: String
    let icon: String
}

// MARK: - Mock Data

private let mockActivityItems: [ActivityItem] = [
    ActivityItem(title: "Dictated email to John", subtitle: "247 words in Gmail", time: "2m ago", icon: "envelope.fill"),
    ActivityItem(title: "Voice note in Slack", subtitle: "89 words in #general", time: "15m ago", icon: "message.fill"),
    ActivityItem(title: "Document editing", subtitle: "1,234 words in Pages", time: "1h ago", icon: "doc.text.fill")
]

// MARK: - Preview

#Preview {
    MainAppView()
        .frame(width: 1000, height: 700)
}

// MARK: - Extensions

