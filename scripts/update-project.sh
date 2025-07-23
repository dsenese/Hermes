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

# Check if Xcode is running and warn user
if pgrep -x "Xcode" > /dev/null; then
    echo -e "${BLUE}⚠️  Xcode is currently running. For best results:${NC}"
    echo -e "${BLUE}   1. Save your work in Xcode${NC}"
    echo -e "${BLUE}   2. Close Xcode temporarily${NC}"
    echo -e "${BLUE}   3. Run this script${NC}"
    echo -e "${BLUE}   4. Reopen Xcode${NC}"
    echo ""
    read -p "Continue anyway? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}👋 Aborted. Close Xcode and run again for best results.${NC}"
        exit 0
    fi
fi

# Remove existing project to avoid conflicts
if [ -d "Hermes.xcodeproj" ]; then
    echo -e "${YELLOW}📦 Removing existing project file to avoid conflicts...${NC}"
    rm -rf Hermes.xcodeproj
fi

# Run xcodegen to regenerate project
echo -e "${YELLOW}🏗️  Generating fresh Xcode project...${NC}"
xcodegen

# Check if generation was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Xcode project updated successfully!${NC}"
    echo -e "${GREEN}📁 You can now open Hermes.xcodeproj in Xcode${NC}"
    echo -e "${BLUE}💡 Tip: Always use 'Keep Disk Version' if Xcode asks about file conflicts${NC}"
    
    # Optional: Open the project in Xcode
    if [ "$1" = "--open" ]; then
        echo -e "${YELLOW}🚀 Opening project in Xcode...${NC}"
        open Hermes.xcodeproj
    fi
else
    echo -e "${RED}❌ Error: Failed to generate Xcode project${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Project update complete!${NC}"