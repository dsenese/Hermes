//
//  TryItStepView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// TRY IT step - contains app showcase and interactive demos
struct TryItStepView: View {
    @State private var currentSubStep: TryItSubStep = .appShowcase
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        OnboardingStepContainer(showBackButton: canGoBack) {
            Group {
                switch currentSubStep {
                case .appShowcase:
                    StaticAppShowcaseView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .interactiveDemo
                        }
                    })
                case .interactiveDemo:
                    InteractiveDemoView(onContinue: {
                        coordinator.nextStep() // This will complete onboarding
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
        true // Always show back button since we can always go back to previous main step or sub-step
    }
    
    private func handleSubStepBack() -> Bool {
        switch currentSubStep {
        case .appShowcase:
            return false // Let main step navigation handle this
        case .interactiveDemo:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .appShowcase
            }
            return true
        }
    }
}

enum TryItSubStep {
    case appShowcase
    case interactiveDemo
}

// MARK: - Sub-step Views

private struct StaticAppShowcaseView: View {
    let onContinue: () -> Void
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    private let features = [
        ("Universal Dictation", "Works in any app - Gmail, Slack, Word, or any text field", "text.cursor"),
        ("Smart Formatting", "Automatically formats emails, adds punctuation, and fixes capitalization", "wand.and.stars"),
        ("Command Mode", "Voice commands like 'new paragraph', 'select all', 'bold this'", "mic.badge.plus"),
        ("Real-time Processing", "See your words appear instantly with <400ms latency", "bolt.fill")
    ]
    
    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Hermes is ready!")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Here's what you can do with voice dictation")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            // Static feature grid (no slideshow) - more compact
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    featureCard(features[0])
                    featureCard(features[1])
                }
                
                HStack(spacing: 24) {
                    featureCard(features[2])
                    featureCard(features[3])
                }
            }
            
            VStack(spacing: 10) {
                Button("Try It Now") {
                    onContinue()
                }
                .primaryButtonStyle()
                
                Button("Skip Demo") {
                    // Skip directly to completion - bypass demo
                    coordinator.nextStep()
                }
                .secondaryButtonStyle()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }
    
    private func featureCard(_ feature: (String, String, String)) -> some View {
        VStack(spacing: 12) {
            Image(systemName: feature.2)
                .font(.system(size: 28))
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
            
            VStack(spacing: 6) {
                Text(feature.0)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(feature.1)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(width: 220, height: 130)
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

private struct AppShowcaseView: View {
    let onContinue: () -> Void
    @State private var currentFeature = 0
    
    private let features = [
        ("Universal Dictation", "Works in any app - Gmail, Slack, Word, or any text field", "text.cursor"),
        ("Smart Formatting", "Automatically formats emails, adds punctuation, and fixes capitalization", "wand.and.stars"),
        ("Command Mode", "Voice commands like 'new paragraph', 'select all', 'bold this'", "mic.badge.plus"),
        ("Real-time Processing", "See your words appear instantly with <400ms latency", "bolt.fill")
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Text("Hermes is ready!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Here's what you can do with voice dictation")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 32) {
                // Feature showcase
                VStack(spacing: 20) {
                    // Feature icon and description
                    VStack(spacing: 16) {
                        Image(systemName: features[currentFeature].2)
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                        
                        VStack(spacing: 8) {
                            Text(features[currentFeature].0)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(features[currentFeature].1)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(width: 400)
                        }
                    }
                    
                    // Feature dots indicator
                    HStack(spacing: 8) {
                        ForEach(0..<features.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentFeature ? Color(hex: HermesConstants.primaryAccentColor) : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                // Navigation buttons
                HStack(spacing: 16) {
                    Button("Previous") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentFeature = max(0, currentFeature - 1)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentFeature == 0)
                    
                    if currentFeature < features.count - 1 {
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentFeature = min(features.count - 1, currentFeature + 1)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                    } else {
                        Button("Try It Now") {
                            onContinue()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.black)
                    }
                }
            }
        }
        .onAppear {
            // Auto-advance through features
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
                if currentFeature < features.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentFeature += 1
                    }
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

private struct InteractiveDemoView: View {
    let onContinue: () -> Void
    @State private var selectedDemo: DemoApp = .slack // Default to Slack as requested
    @State private var isRecording = false
    @State private var demoText = ""
    @State private var showingFloatingMarker = false
    @State private var hasCompletedDemo = false
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var currentShortcut = "Fn" // Reference previous selection from setup step
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Try dictating in your")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                Text("favorite apps")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 24) {
                Text("Select an app to try voice dictation. Press \(currentShortcut) to start dictating.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .onAppear {
                        // Use the keyboard shortcut from the setup step if available
                        if let setupShortcut = coordinator.selectedKeyboardShortcut {
                            currentShortcut = setupShortcut
                        }
                    }
                
                // App tabs - Slack, Gmail, Notes, Cursor
                HStack(spacing: 2) {
                    appTabButton(.slack, "Slack")
                    appTabButton(.gmail, "Gmail") 
                    appTabButton(.notes, "Notes")
                    appTabButton(.cursor, "Cursor")
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Demo interface with accurate representations
                demoInterface
                
                // Recording status with keyboard shortcut reference
                if isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: HermesConstants.primaryAccentColor))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)
                        
                        Text("Listening... (Press \(currentShortcut) again to stop)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: HermesConstants.primaryAccentColor).opacity(0.1))
                    .cornerRadius(20)
                }
            }
            
            VStack(spacing: 12) {
                if hasCompletedDemo {
                    Button("Finish") {
                        onContinue()
                    }
                    .primaryButtonStyle()
                } else {
                    Button("Skip Demo") {
                        onContinue()
                    }
                    .secondaryButtonStyle()
                }
            }
        }
        .overlay(
            // Floating dictation marker (shown when recording)
            floatingDictationMarker
        )
    }
    
    private func appTabButton(_ app: DemoApp, _ title: String) -> some View {
        Button(action: {
            selectedDemo = app
            demoText = ""
            hasCompletedDemo = false
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedDemo == app ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(selectedDemo == app ? Color.blue : Color(NSColor.controlBackgroundColor))
                )
        }
        .plainHoverButtonStyle()
    }
    
    private var demoInterface: some View {
        VStack(spacing: 0) {
            // App-specific interface
            switch selectedDemo {
            case .slack:
                slackInterface
            case .gmail:
                gmailInterface
            case .notes:
                notesInterface
            case .cursor:
                cursorInterface
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(width: 500)
    }
    
    private var floatingDictationMarker: some View {
        Group {
            if showingFloatingMarker {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)
                        
                        Text("Hermes is listening...")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .position(x: 400, y: 100) // Floating position
            }
        }
    }
    
    private var slackInterface: some View {
        VStack(spacing: 0) {
            // Slack header
            HStack {
                Text("#general")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "phone")
                    Image(systemName: "info.circle")
                    Image(systemName: "person.2")
                        .overlay(
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 6, y: -6)
                        )
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(red: 0.25, green: 0.16, blue: 0.44)) // Slack purple
            .foregroundColor(.white)
            
            // Chat messages
            VStack(spacing: 12) {
                // Previous message
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("JD")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("John Doe")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("2:30 PM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("Great work on the presentation today!")
                            .font(.body)
                    }
                    Spacer()
                }
                
                Spacer()
                
                // Input area
                VStack(spacing: 8) {
                    TextEditor(text: $demoText)
                        .font(.body)
                        .overlay(
                            Group {
                                if demoText.isEmpty {
                                    VStack {
                                        HStack {
                                            Text("Message #general")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding(8)
                                    .allowsHitTesting(false)
                                }
                            }
                        )
                        .onTapGesture {
                            startDictation()
                        }
                    
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "paperclip")
                            Image(systemName: "face.smiling")
                            Image(systemName: "at")
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Send") {
                            hasCompletedDemo = true
                        }
                        .primaryButtonStyle(size: .small)
                    }
                }
            }
            .padding()
            .frame(height: 220)
        }
    }
    
    private var gmailInterface: some View {
        VStack(spacing: 0) {
            // Gmail header
            HStack {
                Text("Compose")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "minus")
                    Image(systemName: "arrow.up.right.and.arrow.down.left")
                    Image(systemName: "xmark")
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Email fields
            VStack(spacing: 0) {
                // To field
                HStack {
                    Text("To")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 40, alignment: .leading)
                    Text("john@company.com")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                // Subject field
                HStack {
                    Text("Subject")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 40, alignment: .leading)
                    Text("Project Update")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                // Body
                TextEditor(text: $demoText)
                    .font(.body)
                    .overlay(
                        Group {
                            if demoText.isEmpty {
                                VStack {
                                    HStack {
                                        Text("Compose email")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .allowsHitTesting(false)
                            }
                        }
                    )
                    .onTapGesture {
                        startDictation()
                    }
                
                // Bottom toolbar
                HStack {
                    Button("Send") {
                        hasCompletedDemo = true
                    }
                    .primaryButtonStyle(size: .small)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "paperclip")
                        Image(systemName: "link")
                        Image(systemName: "face.smiling")
                        Image(systemName: "photo")
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .frame(height: 220)
        }
    }
    
    private var notesInterface: some View {
        VStack(spacing: 0) {
            // Notes header
            HStack {
                VStack(alignment: .leading) {
                    Text("Meeting Notes")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("July 23, 2025 at 2:45 PM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                    Image(systemName: "ellipsis.circle")
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(red: 1.0, green: 0.96, blue: 0.75)) // Notes yellow
            
            // Notes content
            TextEditor(text: $demoText)
                .font(.body)
                .overlay(
                    Group {
                        if demoText.isEmpty {
                            VStack {
                                HStack {
                                    Text("Start typing or dictating your notes...")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(8)
                            .allowsHitTesting(false)
                        }
                    }
                )
                .onTapGesture {
                    startDictation()
                }
                .padding()
                .frame(height: 220)
        }
    }
    
    private var cursorInterface: some View {
        VStack(spacing: 0) {
            // Cursor header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                    Text("main.swift")
                        .font(.body)
                        .fontWeight(.medium)
                }
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                    Image(systemName: "square.split.2x1")
                    Image(systemName: "xmark")
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(red: 0.12, green: 0.12, blue: 0.12)) // Dark theme
            .foregroundColor(.white)
            
            // Code editor
            VStack(alignment: .leading, spacing: 0) {
                // Line numbers and code
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...8, id: \.self) { line in
                            Text("\(line)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 18)
                        }
                    }
                    .padding(.trailing, 8)
                    
                    // Code content
                    VStack(alignment: .leading, spacing: 0) {
                        Text("import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        VStack {")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(height: 90, alignment: .topLeading)
                        
                        TextEditor(text: $demoText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .background(Color.clear)
                            .overlay(
                                Group {
                                    if demoText.isEmpty {
                                        HStack {
                                            Text("            // Add your code comments here")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .allowsHitTesting(false)
                                    }
                                }
                            )
                            .onTapGesture {
                                startDictation()
                            }
                        
                        Text("        }\n    }\n}")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(height: 54, alignment: .topLeading)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .frame(height: 220)
            .background(Color(red: 0.09, green: 0.09, blue: 0.09))
        }
    }
    
    private func startDictation() {
        isRecording = true
        showingFloatingMarker = true
        
        // Simulate transcription after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let sampleText = selectedDemo.sampleText
            
            // Simulate typing animation
            for (index, character) in sampleText.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                    demoText.append(character)
                }
            }
            
            // Stop recording after typing completes
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(sampleText.count) * 0.05 + 1.0) {
                isRecording = false
                showingFloatingMarker = false
                hasCompletedDemo = true
            }
        }
    }
}

enum DemoApp {
    case gmail
    case slack
    case notes
    case cursor
    
    var title: String {
        switch self {
        case .gmail: return "Gmail"
        case .slack: return "Slack"
        case .notes: return "Notes"
        case .cursor: return "Cursor"
        }
    }
    
    var placeholder: String {
        switch self {
        case .gmail: return "Click here and try dictating an email..."
        case .slack: return "Click here and try dictating a message..."
        case .notes: return "Click here and try dictating a note..."
        case .cursor: return "Click here and try dictating code comments..."
        }
    }
    
    var sampleText: String {
        switch self {
        case .gmail: return "Hi John, I wanted to give you a quick update on the project. We've made great progress this week and should be on track for the deadline."
        case .slack: return "Hey team! Just finished the demo. The new voice dictation feature is working perfectly. Let me know if you have any questions."
        case .notes: return "Meeting notes from today: Discussed project timeline, assigned new tasks, and set up weekly check-ins. Next meeting scheduled for Friday."
        case .cursor: return "// This function handles user authentication and validates credentials before allowing access to protected routes"
        }
    }
}

#Preview {
    TryItStepView()
        .environmentObject(OnboardingCoordinator(
            currentStep: .constant(.tryIt),
            showingOnboarding: .constant(true)
        ))
        .frame(width: 1000, height: 700)
}