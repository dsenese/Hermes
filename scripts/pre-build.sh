#!/bin/bash

# Pre-build script for Hermes
# This script runs before each build to ensure the Xcode project is up-to-date
# Add this to your Xcode scheme as a "Pre-action" build script

# Only run if project.yml is newer than .xcodeproj or if new Swift files exist
PROJECT_DIR="${SRCROOT:-$(pwd)}"
cd "$PROJECT_DIR"

# Check if project.yml exists
if [ ! -f "project.yml" ]; then
    echo "⚠️  project.yml not found, skipping project update"
    exit 0
fi

# Check if xcodegen is available
if ! command -v xcodegen &> /dev/null; then
    echo "⚠️  xcodegen not found, install with: brew install xcodegen"
    exit 0
fi

# Find all Swift files (excluding build directories)
SWIFT_FILES=$(find . -name "*.swift" -not -path "./build/*" -not -path "./.build/*" -not -path "./DerivedData/*" -newer Hermes.xcodeproj/project.pbxproj 2>/dev/null || true)

# Check if project.yml is newer than the project file
PROJECT_YML_NEWER=$(find project.yml -newer Hermes.xcodeproj/project.pbxproj 2>/dev/null || true)

# Update project if needed
if [ -n "$SWIFT_FILES" ] || [ -n "$PROJECT_YML_NEWER" ]; then
    echo "🔄 Updating Xcode project (new files detected)..."
    xcodegen --quiet
    echo "✅ Project updated"
else 
    echo "✅ Project is up-to-date"
fi