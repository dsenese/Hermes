//
//  OnboardingView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// Main onboarding container view that manages the 4-step flow
struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .signIn
    @Binding var showingOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar - always stays at top
            OnboardingProgressBar(currentStep: currentStep)
            
            // Step content
            Group {
                switch currentStep {
                case .signIn:
                    SignInStepView()
                case .permissions:
                    PermissionsStepView()
                case .setUp:
                    SetUpStepView()
                case .tryIt:
                    TryItStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .environmentObject(OnboardingCoordinator(
            currentStep: $currentStep,
            showingOnboarding: $showingOnboarding
        ))
    }
}

/// Onboarding step coordinator for navigation
class OnboardingCoordinator: ObservableObject {
    @Binding var currentStep: OnboardingStep
    @Binding var showingOnboarding: Bool
    @Published var selectedKeyboardShortcut: String?
    
    // Sub-step navigation callbacks
    var subStepBackHandler: (() -> Bool)?
    
    init(currentStep: Binding<OnboardingStep>, showingOnboarding: Binding<Bool>) {
        _currentStep = currentStep
        _showingOnboarding = showingOnboarding
    }
    
    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .signIn:
                currentStep = .permissions
            case .permissions:
                currentStep = .setUp
            case .setUp:
                currentStep = .tryIt
            case .tryIt:
                Task { @MainActor in
                    completeOnboarding()
                }
            }
        }
    }
    
    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // First try sub-step navigation if available
            if let subStepHandler = subStepBackHandler, subStepHandler() {
                return // Sub-step handled the back navigation
            }
            
            // Otherwise navigate between main steps
            switch currentStep {
            case .signIn:
                break // Can't go back from first step
            case .permissions:
                currentStep = .signIn
            case .setUp:
                currentStep = .permissions
            case .tryIt:
                currentStep = .setUp
            }
        }
    }
    
    @MainActor
    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Mark onboarding as completed in UserSettings
            UserSettings.shared.isOnboardingCompleted = true
            UserSettings.shared.saveToLocalStorage()
            
            showingOnboarding = false
        }
    }
}

enum OnboardingStep: String, Codable, CaseIterable {
    case signIn = "sign_in"
    case permissions = "permissions"
    case setUp = "setup"
    case tryIt = "try_it"
    
    var title: String {
        switch self {
        case .signIn: return "SIGN IN"
        case .permissions: return "PERMISSIONS"
        case .setUp: return "SET UP"
        case .tryIt: return "TRY IT"
        }
    }
}

#Preview {
    OnboardingView(showingOnboarding: .constant(true))
        .frame(width: 1000, height: 700)
}