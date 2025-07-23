# XcodeGen Workflow for Hermes

## Overview
This project uses `xcodegen` to automatically manage the Xcode project file. This prevents merge conflicts and ensures consistent project structure across the team.

## Workflow

### When Adding New Files:
1. Create your Swift files in the appropriate directories (e.g., `Hermes/Core/`, `Hermes/UI/`)
2. Run: `./scripts/update-project.sh`
3. Open/reopen the project in Xcode

### Best Practices:
- **Always close Xcode** before running the update script for best results
- **Never manually add files** to the Xcode project - they'll be overwritten
- **Always choose "Keep Disk Version"** if Xcode shows file conflict dialogs
- **Run the update script** after pulling changes that include new files

### Directory Structure:
- `Hermes/Core/` - Core dictation engine files
- `Hermes/UI/` - SwiftUI views and UI components  
- `Hermes/Features/` - Feature-specific implementations
- `Hermes/Team/` - Team management and Supabase integration
- `Hermes/Utilities/` - Helper classes and extensions

### Commands:
```bash
# Update project after adding files
./scripts/update-project.sh

# Update and open in Xcode
./scripts/update-project.sh --open

# Manual generation (if needed)
xcodegen
```

### Troubleshooting:
- If you see "modified by another application" errors, always choose "Keep Disk Version"
- If Xcode seems confused, close it completely and reopen the project
- If you accidentally add files through Xcode, run the update script to reset

### Configuration:
- Project structure is defined in `project.yml`
- Build settings and schemes are managed there
- Swift Package dependencies will be added to `project.yml` when needed