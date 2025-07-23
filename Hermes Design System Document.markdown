# Hermes Design System Document

## Introduction
This document defines the design system for Hermes, a macOS dictation app. It is structured for direct use as context in AI code assistants (e.g., Claude Code) during the build process. Sections are modular for easy referencing in prompts—e.g., "Implement a primary button using the Hermes design system's button specs." Copy-paste relevant sections into AI prompts for generating SwiftUI code, ensuring consistency with Wispr Flow's premium, fluid style: minimalist, seamless, and high-end. Key inspirations: Icon-based sidebar, white main background, rounded cards, timeline feed.

Mindset: "Speak naturally, design fluidly" – Simplicity, accessibility, performance. Adapts to light/dark modes.


## 1. Color Palette
Minimalist with high contrast. Neon Robin #CCFF00 for primary accents. Tinted sidebar for separation.

- **Primary Accent (Buttons/CTAs)**: #CCFF00 (Neon Robin; verified hex for vibrant green).
- **Background (Main, Light Mode)**: #FFFFFF.
- **Background (Main, Dark Mode)**: #1C1C1E.
- **Sidebar Menu Tinted Background (Light Mode)**: #F5F5F7.
- **Sidebar Menu Tinted Background (Dark Mode)**: #2C2C2E.
- **Text Primary**: #000000 (light); #FFFFFF (dark).
- **Text Secondary**: #6C6C6C.
- **Success/Positive**: #34C759.
- **Error/Negative**: #FF3B30.
- **Neutral/Borders**: #E5E5E5.
- **Badge/Logo Accent**: #A020F0.

Guidelines:
- Neon Robin for high-impact only.
- 4.5:1 contrast (WCAG).


## 2. Typography
Sans-serif for readability, bold for emphasis.

- **Font Family**: SF Pro (fallback: Helvetica Neue).
- **Headings**:
  - H1: 32px, Bold (600).
  - H2: 24px, Bold (600).
  - H3: 20px, Medium (500).
- **Body Text**:
  - Paragraph: 16px, Regular (400); Line height 1.5.
  - Small Text: 14px, Regular (400).
- **Button Text**: 16px, Semibold (600).

Guidelines:
- Dynamic scaling for accessibility.


## 3. Components
Fluid, animated; responsive/theme-aware.

### 3.1 Buttons
- **Primary Button**: Background #CCFF00, Text #000000, Radius 8px, Padding 12px 24px, Shadow 0 2px 4px rgba(0,0,0,0.1).
  - Hover: Brightness +10%, Scale 1.05 (0.2s ease).
- **Secondary Button (Filled)**: Background #1C1C1E, Text #FFFFFF, Radius 8px, Padding 10px 20px.
  - Hover: Background #2C2C2E.
- **Secondary Button (Outlined)**: Background Transparent, Border 1px #1C1C1E, Text #1C1C1E (#FFFFFF dark), Padding 10px 20px.
  - Hover: Background #1C1C1E0A (5% opacity).
- **Tertiary Button**: Text-only (#1C1C1E/#FFFFFF), Underline on hover.
- **Disabled State**: Opacity 0.5.

Guidelines: Primary for key actions; Secondary for flexibility, neutral cohesion.


### 3.2 Cards/Timeline Items
- Layout: Radius 12px, Background #F9F9F9 (light)/#2C2C2E (dark), Padding 16px.
- Shadow: 0 4px 8px rgba(0,0,0,0.05).
- Animation: Fade-in (0.3s ease), Hover scale 1.02.

### 3.3 Navigation/Sidebar
- Tinted background (#F5F5F7 light/#2C2C2E dark), Width 200px, Icons + Labels.
- Items: 16px Semibold, 24px icons, Padding 12px, Hover #E5E5E5 (light)/#3A3A3C (dark).
- Top Badge: Rounded pill (#A020F0 accent).
- Animation: Fade on hover.

### 3.4 Popup/Modals
- Non-Intrusive Pop-up: Dark theme (#1C1C1E background, #FFFFFF text), Minimal 200x100px, Radius 12px.
  - Minimal: Icon/status; Expand on hover/active.
  - Active: #CCFF00 glow on mic.
  - Animation: Scale-in (0.2s spring), Fade-out dismiss.

### 3.5 Icons
- SF Symbols with emojis (e.g., 🔥 stats, 📝 Notes).
- Size: 24px sidebar, 16px inline.
- Color: Text or #CCFF00 active.

## 4. Layout and Spacing
- Grid: 8px base.
- Spacing: 24px sections, 8px elements.
- Responsive: Min-width 320px modals.

## 5. Onboarding Flow
- **Step 1: Welcome Screen**: H1 "Welcome to Hermes", Subtext "Boost productivity 5x faster with AI that adapts and saves time", CTA "Get Started" (#CCFF00, fade-in).
- **Step 2: Permissions**: Mic prompt, #CCFF00 spinner.
- **Step 3: Hotkey Setup**: Customize Cmd+`, Test demo, 👍 emoji feedback.
- **Step 4: Language/Dictionary**: Select/add terms.
- **Step 5: Team Invite (Optional)**: Code/SSO, 👥 emoji preview.
- **Step 6: Tutorial**: Demo, Dismiss with 🎉 confetti.

Guidelines: <10s/step, slide-in animations.

## 6. Themes and Modes
- Light/Dark: Auto-system; Sidebar tint adapts.
- High Contrast: Increase ratios.

## 7. Guidelines for Premium Fluid Mindset
- Fluidity: <400ms interactions; Spring animations.
- Premium Polish: Shadows, rounded edges, no clutter; Tinted sidebar separation.
- Onboarding: Ease with tooltips, previews, emojis.
- Consistency: System-wide; Test native feel, dark pop-up minimalism.

