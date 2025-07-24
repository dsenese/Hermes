//
//  OnboardingProgressBar.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// Top progress bar showing the 4 main onboarding steps
struct OnboardingProgressBar: View {
    let currentStep: OnboardingStep
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(OnboardingStep.allCases.indices, id: \.self) { index in
                let step = OnboardingStep.allCases[index]
                let isActive = step == currentStep
                let isCompleted = OnboardingStep.allCases.firstIndex(of: currentStep)! > index
                
                HStack(spacing: 8) {
                    // Step label
                    Text(step.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isActive || isCompleted ? .primary : .secondary)
                    
                    // Arrow (except for last step)
                    if index < OnboardingStep.allCases.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor))
                .opacity(0.3),
            alignment: .bottom
        )
    }
}

#Preview {
    OnboardingProgressBar(currentStep: .signIn)
}