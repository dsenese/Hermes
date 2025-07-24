//
//  SignInStepView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// SIGN IN step - contains authentication, free trial, data privacy, and welcome survey sub-flows
struct SignInStepView: View {
    @State private var currentSubStep: SignInSubStep = .authentication
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        OnboardingStepContainer(
            showBackButton: canGoBack,
            useScrollView: true,
            verticalAlignment: .balanced
        ) {
            Group {
                switch currentSubStep {
                case .authentication:
                    AuthenticationView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .freeTrial
                        }
                    })
                case .freeTrial:
                    FreeTrialView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .dataPrivacy
                        }
                    })
                case .dataPrivacy:
                    DataPrivacyView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .welcomeSurvey
                        }
                    })
                case .welcomeSurvey:
                    WelcomeSurveyView(onContinue: {
                        coordinator.nextStep()
                    })
                }
            }
        }
        .onAppear {
            // Set up sub-step back navigation handler
            coordinator.subStepBackHandler = handleSubStepBack
        }
        .onDisappear {
            // Clean up handler when leaving this step
            coordinator.subStepBackHandler = nil
        }
    }
    
    private var canGoBack: Bool {
        currentSubStep != .authentication
    }
    
    private func handleSubStepBack() -> Bool {
        switch currentSubStep {
        case .authentication:
            return false // Can't go back from first sub-step
        case .freeTrial:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .authentication
            }
            return true
        case .dataPrivacy:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .freeTrial
            }
            return true
        case .welcomeSurvey:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .dataPrivacy
            }
            return true
        }
    }
}

enum SignInSubStep {
    case authentication
    case freeTrial
    case dataPrivacy
    case welcomeSurvey
}

// MARK: - Sub-step Views

private struct AuthenticationView: View {
    let onContinue: () -> Void
    @State private var showEmailSection = false
    
    var body: some View {
        VStack(spacing: 32) {
            // App icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
            
            VStack(spacing: 12) {
                Text("Get started with Hermes")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Dictate 3x faster. Everywhere you type.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 24) {
                // OAuth buttons - 4 options in 2x2 grid with proper spacing
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button("Sign in with Gmail") {
                            onContinue()
                        }
                        .gmailButtonStyle()
                        
                        Button("Sign in with Apple") {
                            onContinue()
                        }
                        .appleButtonStyle()
                    }
                    
                    HStack(spacing: 16) {
                        Button("Sign in with Microsoft") {
                            onContinue()
                        }
                        .microsoftButtonStyle()
                        
                        Button("Single sign-on (SSO)") {
                            onContinue()
                        }
                        .ssoButtonStyle()
                    }
                }
                
                // Show email option button
                Button("Continue with Email") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showEmailSection = true
                    }
                }
                .secondaryButtonStyle()
                .opacity(showEmailSection ? 0 : 1)
                
                // Email input section - only shown when requested
                if showEmailSection {
                    VStack(spacing: 16) {
                        // Divider with OR
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)
                        
                        VStack(spacing: 16) {
                            HermesTextField(
                                text: Binding.constant(""),
                                placeholder: "Enter your work or school email"
                            )
                            .frame(width: 400)
                            
                            Text("Use your work or school email to enjoy the upcoming team and collaboration features.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(width: 400)
                            
                            Button("Continue with Email") {
                                onContinue()
                            }
                            .primaryButtonStyle()
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Text("By signing up, you agree to our Terms of Service and Privacy Policy. Your name and email will be used to personalize your Hermes experience.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 380)
                    .padding(.top, 6)
            }
        }
    }
    
}

private struct FreeTrialView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Title with better hierarchy
            VStack(spacing: 6) {
                Text("Congratulations isabel!")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            
            // Content with improved hierarchy
            VStack(spacing: 28) {
                // Main offer
                VStack(spacing: 16) {
                    Text("We're giving you 2 weeks of")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Hermes Pro")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                    
                    Text("free")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                // Features
                VStack(spacing: 16) {
                    Text("You get everything in Hermes Basic, plus:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        featureItem("Unlimited words per week")
                        featureItem("Access to command mode")
                    }
                }
                
                // Trial details
                VStack(spacing: 12) {
                    Text("Unlimited access until August 6")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Experience Hermes Pro for the next 14 days. You can upgrade at just $12 / month any time.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 400)
                    
                    Text("No credit card required.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                    
                    Text("If you decide not to upgrade by August 6, your account will go back to Hermes Basic.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 400)
                }
            }
            
            Button("Continue") {
                onContinue()
            }
            .primaryButtonStyle()
        }
    }
    
    private func featureItem(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .frame(width: 300)
    }
}

private struct DataPrivacyView: View {
    let onContinue: () -> Void
    @State private var selectedMode: PrivacyMode = .helpImprove
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("You control your data")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                // Help improve option
                privacyOption(
                    mode: .helpImprove,
                    title: "Help improve Hermes",
                    description: "To make Hermes better, this option lets us collect your audio, transcript, and edits to evaluate, train and improve Hermes's features and AI models",
                    isSelected: selectedMode == .helpImprove
                ) {
                    selectedMode = .helpImprove
                }
                
                // Privacy mode option
                privacyOption(
                    mode: .privacyMode,
                    title: "Privacy Mode",
                    description: "If you enable Privacy Mode, none of your dictation data will be stored or used for model training by us or any third party.",
                    isSelected: selectedMode == .privacyMode,
                    hasLockIcon: true
                ) {
                    selectedMode = .privacyMode
                }
                
                Text("You can always change this later in settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Read more here.")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Button("Continue") {
                onContinue()
            }
            .primaryButtonStyle()
        }
    }
    
    private func privacyOption(
        mode: PrivacyMode,
        title: String,
        description: String,
        isSelected: Bool,
        hasLockIcon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    if hasLockIcon {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                    }
                }
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: HermesConstants.primaryAccentColor) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    enum PrivacyMode {
        case helpImprove
        case privacyMode
    }
}

private struct WelcomeSurveyView: View {
    let onContinue: () -> Void
    @State private var selectedSource = "Reddit"
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Welcome, isabel!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Where did you hear about us?")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            VStack(spacing: 20) {
                HermesDropdown(
                    selection: $selectedSource,
                    options: ["Reddit", "Twitter", "LinkedIn", "Friend referral", "Other"],
                    placeholder: "Where did you hear about us?"
                )
                .frame(width: 250)
                
                VStack(spacing: 12) {
                    Button("Continue") {
                        onContinue()
                    }
                    .primaryButtonStyle()
                    
                    Button("Skip") {
                        onContinue()
                    }
                    .secondaryButtonStyle()
                }
            }
        }
    }
}

#Preview {
    SignInStepView()
        .environmentObject(OnboardingCoordinator(
            currentStep: .constant(.signIn),
            showingOnboarding: .constant(true)
        ))
        .frame(width: 1000, height: 700)
}