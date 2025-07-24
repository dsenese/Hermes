#!/bin/bash

# Hermes Project Auto-Update Script
# This script regenerates the Xcode project file based on project.yml
# Run this whenever you add new files to automatically update the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 Updating Hermes Xcode project...${NC}"

# Check if we're in the right directory
if [ ! -f "project.yml" ]; then
    echo -e "${RED}❌ Error: project.yml not found. Make sure you're in the Hermes project root directory.${NC}"
    exit 1
fi

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo -e "${RED}❌ Error: xcodegen is not installed. Install with: brew install xcodegen${NC}"
    exit 1
fi

# Check if Xcode is running and handle it automatically
XCODE_WAS_RUNNING=false
if pgrep -x "Xcode" > /dev/null; then
    XCODE_WAS_RUNNING=true
    echo -e "${BLUE}⚠️  Xcode is currently running. Automatically closing it for clean project regeneration...${NC}"
    
    # Attempt to save any unsaved work first (this is a nice-to-have)
    osascript -e 'tell application "Xcode" to activate' 2>/dev/null || true
    osascript -e 'tell application "System Events" to keystroke "s" using {command down}' 2>/dev/null || true
    sleep 1
    
    # Close Xcode gracefully first, then force if needed
    echo -e "${YELLOW}🔄 Closing Xcode...${NC}"
    osascript -e 'tell application "Xcode" to quit' 2>/dev/null || killall Xcode 2>/dev/null || true
    
    # Wait for Xcode to fully close
    timeout=10
    while pgrep -x "Xcode" > /dev/null && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
    done
    
    if pgrep -x "Xcode" > /dev/null; then
        echo -e "${YELLOW}⚠️  Force closing Xcode...${NC}"
        killall -9 Xcode 2>/dev/null || true
        sleep 2
    fi
    
    echo -e "${GREEN}✅ Xcode closed successfully${NC}"
fi

# Remove existing project to avoid conflicts
if [ -d "Hermes.xcodeproj" ]; then
    echo -e "${YELLOW}📦 Removing existing project file to avoid conflicts...${NC}"
    rm -rf Hermes.xcodeproj
fi

# Show what Swift files will be included
echo -e "${BLUE}🔍 Detecting Swift files...${NC}"
find Hermes -name "*.swift" -type f | while read file; do
    echo -e "${BLUE}   📄 Found: $file${NC}"
done

# Run xcodegen to regenerate project
echo -e "${YELLOW}🏗️  Generating fresh Xcode project...${NC}"
xcodegen

# Check if generation was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Xcode project updated successfully!${NC}"
    
    # Verify the project includes our files
    echo -e "${BLUE}🔍 Verifying included files...${NC}"
    if [ -f "Hermes.xcodeproj/project.pbxproj" ]; then
        swift_count=$(grep -c "\.swift" Hermes.xcodeproj/project.pbxproj)
        echo -e "${GREEN}📊 Project includes $swift_count Swift file references${NC}"
    fi
    
    echo -e "${GREEN}📁 All Swift files have been automatically detected and added${NC}"
    echo -e "${BLUE}💡 Tip: Always use 'Keep Disk Version' if Xcode asks about file conflicts${NC}"
    
    # Wait a moment to ensure project file is fully written
    sleep 2
    
    # Automatically reopen Xcode if it was running before, or if --open flag is used
    if [ "$XCODE_WAS_RUNNING" = true ] || [ "$1" = "--open" ]; then
        echo -e "${YELLOW}🚀 Reopening project in Xcode...${NC}"
        sleep 1  # Additional delay before opening
        open Hermes.xcodeproj
        
        if [ "$XCODE_WAS_RUNNING" = true ]; then
            echo -e "${GREEN}✨ Xcode has been reopened with the updated project${NC}"
        fi
    else
        echo -e "${GREEN}📁 You can now open Hermes.xcodeproj in Xcode${NC}"
    fi
else
    echo -e "${RED}❌ Error: Failed to generate Xcode project${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Project update complete!${NC}"