# Hermes UI Feedback Instructions for Main App View and Floating Dictation Marker

## Introduction
This document provides detailed feedback instructions for two key UI elements in Hermes: the Main App View (based on the first Wispr Flow screenshot) and the Floating Dictation Marker (based on the provided screenshots). These instructions are optimized for use as context in AI code assistants like Claude Code during the build process. They outline structure, behavior, and integration to match Wispr Flow's fluid, premium style while incorporating Hermes' design system (e.g., Neon Robin accents, tinted sidebar, dark pop-up).

Structure the app as "always-on" like Wispr Flow: Main view for dashboard/settings, floating marker for dictation across apps. Reference in prompts: "Build Main App View per Hermes feedback: Sidebar with tinted background, welcome header with stats."

## 1. Main App View Feedback Instructions
The Main App View is the central dashboard, opened from the menu bar icon or on launch. It mirrors Wispr Flow's layout: Left sidebar for navigation, top header with user greeting and stats, main area for content like recent activity timeline. Focus on fluidity, minimalism, and value-add stats to encourage usage.

### Key Elements and Instructions
- **Overall Layout**:
  - Sidebar (Left): Fixed width ~200px, tinted background (#F5F5F7 light / #2C2C2E dark) for separation from white main area.
  - Main Content: White background (#FFFFFF light / #1C1C1E dark), flexible width, centered elements.
  - Radius: 12px on window for premium feel.
  - Responsiveness: Adapt to window resize; min-width 800px.

- **Header**:
  - Greeting: H1 "Welcome back, [User]" (32px Bold), left-aligned.
  - Stats Badges: Right-aligned, rounded pills (e.g., 🔥 "3 weeks", 🚀 "26.0K words", 🏆 "109 WPM"); Use emojis for character, purple accent (#A020F0) background.
  - Instructions: Make stats interactive (hover tooltips with details); Update dynamically from user data.

- **Sidebar Navigation**:
  - Items: Icon + Label (e.g., Home 🏠, Dictionary 📖, Notes 📝, Add Team 👥, Refer Friend 🎁, Help ❓).
  - Top: Logo "Hermes" in purple (#A020F0), "Pro Trial" badge below (pill with progress bar, e.g., purple outline).
  - Bottom: Upgrade CTA (e.g., "Upgrade to Pro" button, Neon Robin #CCFF00).
  - Instructions: Hover effects (background #E5E5E5 light / #3A3A3C dark); Active item bold or accented (#CCFF00 icon).

- **Main Content Area**:
  - Top Card: Rounded card with H2 "Voice dictation in any app", Subtext "Hold down the trigger key ctrl and speak into any textbox", CTA "Explore use cases" (Neon Robin button).
  - Timeline: "Recent activity" H2, Vertical list of timestamped cards (e.g., "01:00 PM" H3 + body text); Each card rounded, subtle shadow.
  - Instructions: Timeline scrolls; Cards fade-in on load; Clickable for details/edit.

- **Behavior and Animations**:
  - Fluidity: <400ms interactions; Fade-in on open (0.3s).
  - Always-On Integration: View minimizes to menu bar when closed; Stats update in real-time from background dictation.

- **Accessibility**: VoiceOver labels (e.g., "Pro Trial badge: 12 of 14 days used"); High contrast.

**AI Prompt Example**: "Implement Main App View in SwiftUI: Tinted sidebar #F5F5F7 with icons/labels, header with greeting and emoji stats, timeline cards per Hermes feedback."

## 2. Floating Dictation Marker Feedback Instructions
The Floating Dictation Marker is an always-on overlay that floats over all apps while Hermes runs, similar to Wispr Flow. It informs dictation status and triggers input. Minimized when idle (small form), expands on hover or active dictation for minimal intrusion. Dark theme for subtlety. The marker is not draggable but dynamic when command controls are active—e.g., expands automatically during dictation or when commands (like "new paragraph") are detected in speech, showing relevant controls or feedback briefly before minimizing. It should feel "minimal and magical," with low visual noise, auto-adapting based on user intent without manual positioning.

Based on the provided screenshots and descriptions:
- **Inactive State (No Dictation, First Screenshot)**: Very minimal pill (e.g., ~50x8px) with 80% opacity, designed to not obstruct the view.
- **Active State (Dictating, Not Hovered, 80x30px)**: Shows a real-time waveform (simple, fluid lines pulsing from mic input) to indicate audio collection; Remains compact pill size without text or expansion unless hovered.
- **Hovered/Clicked State (Second Screenshot)**: On hover and click to start, expands slightly (e.g., ~80x30px) with waveform feedback for input confirmation; Dotted line when not active. "Click to start dictating" in a pill above the pill below as click target to activate Hermes differently from Command keys.

### Key Elements and Instructions
- **Overall Layout**:
  - Position: Fixed, non-draggable; Defaults to bottom-center or user-set via settings (e.g., persists position but no drag).
  - Size: Inactive ~50x8px (rounded pill); Expanded ~80x30px on hover/active/command detection.
  - Theme: Dark (#1C1C1E background, #FFFFFF text); Radius 24px (pill shape minimized).
  - Border: Subtle shadow for depth.

- **Inactive State (No Dictation, First Screenshot)**:
  - Content: Very minimal pill with 80% opacity, no text or icons, designed to not obstruct the view.
  - Instructions: Low profile; Auto-hide option in settings.

- **Active State (Dictating, Not Hovered, 80x30px)**:
  - Content: Simple real-time waveform animation (minimal pulsing lines representing mic input; fluid, non-distracting, no text).
  - Instructions: Indicates audio collection; Remains compact pill size; Copies text directly to the selected textbox in the current app for a "magical" feel—no expansion or extra feedback beyond waveform.

- **Hovered/Clicked State (Second Screenshot)**:
  - Expand: Animate width/height (0.2s ease) on hover or click to start dictation.
  - Content: Top Pill: "Click to start dictating" text (16px Semibold, #FFFFFF) as click target (alternative to Command keys); Bottom Pill: Dotted line when not active, or waveform + status (e.g., "Dictating...") on click/start.
  - Instructions: Waveform appears post-click for input confirmation; Expands briefly for commands (e.g., flash ✅ or Neon Robin highlight), then auto-minimizes after 2-3s; Fade partial text gray to white.

- **Dynamic Command Controls**:
  - When commands active (e.g., speech detects "new paragraph"): Briefly expand to show dynamic feedback (e.g., quick ✅ or Neon Robin highlight), then auto-minimize after 2-3s.
  - Instructions: Keep minimal—avoid persistent expansion unless hovered.

- **Behavior and Animations**:
  - Fluidity: Appear on app launch; Auto-adjust position based on screen (e.g., avoid edges dynamically).
  - Interactions: Hover or click (on "Click to start dictating" pill) to expand/start dictation (triggers waveform/audio collection); Idle timeout to minimize.
  - Always-On: Persists over all apps; Non-intrusive (semi-transparent when minimized); "Magical" – Minimal feedback (waveform only during active/hover), relies on direct text insertion for delight.

- **Accessibility**: VoiceOver ("Floating dictation button: Click to start"); Keyboard shortcuts to focus.

**AI Prompt Example**: "Build Floating Dictation Marker in SwiftUI: Dark #1C1C1E theme, inactive pill with 80% opacity, active waveform on dictation, expand on hover with 'Click to start dictating' pill, per Hermes feedback."

## 3. General Integration Instructions
- **App Structure**: Main View as dashboard (opens from menu bar); Floating Marker as persistent NSWindow for dictation.
- **Consistency**: Apply design system (e.g., Neon Robin CTAs in both).
- **Testing**: Fluid transitions; Minimal CPU impact.

**AI Context Notes**: Use in Claude Projects: "Reference Hermes feedback for Main View sidebar and Floating Marker hover expansion." Test: "claude-code simulate 'floating marker minimization after idle.'"

This document guides AI-assisted builds, ensuring Hermes' structure aligns with Wispr Flow's fluidity.