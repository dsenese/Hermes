//
//  OnboardingStepContainer.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// Reusable container for onboarding steps with back button and flexible layout
struct OnboardingStepContainer<Content: View>: View {
    let showBackButton: Bool
    let useScrollView: Bool
    let verticalAlignment: VerticalAlignment
    let content: () -> Content
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    enum VerticalAlignment {
        case center
        case top
        case balanced // Less centered, more toward top for better space utilization
    }
    
    init(
        showBackButton: Bool = true,
        useScrollView: Bool = false,
        verticalAlignment: VerticalAlignment = .balanced,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showBackButton = showBackButton
        self.useScrollView = useScrollView
        self.verticalAlignment = verticalAlignment
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button area - more compact
            HStack {
                if showBackButton {
                    Button(action: coordinator.previousStep) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .frame(height: 48) // Reduced from 64
            
            // Dynamic content area
            if useScrollView {
                ScrollView {
                    contentWithAlignment
                        .padding(.horizontal, 32)
                }
            } else {
                contentWithAlignment
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var contentWithAlignment: some View {
        switch verticalAlignment {
        case .center:
            VStack {
                Spacer()
                content()
                Spacer()
            }
        case .top:
            VStack {
                content()
                    .padding(.top, 24)
                Spacer(minLength: 0)
            }
        case .balanced:
            VStack {
                Spacer(minLength: 20)
                content()
                Spacer(minLength: 40)
            }
        }
    }
}

#Preview {
    OnboardingStepContainer(verticalAlignment: .balanced) {
        VStack(spacing: 20) {
            Text("Sample Content")
                .font(.title)
            Text("This is a preview of the flexible container")
                .foregroundColor(.secondary)
        }
    }
    .environmentObject(OnboardingCoordinator(
        currentStep: .constant(.signIn),
        showingOnboarding: .constant(true)
    ))
    .frame(width: 1000, height: 700)
}