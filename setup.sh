#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# PullTube — First-time setup script
# Run this once after cloning the repo to bootstrap the Flutter project.
# Requirements: Flutter SDK (stable channel), Xcode 15+, CocoaPods
# ─────────────────────────────────────────────────────────────────────────────
set -e

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

echo -e "${YELLOW}▶ PullTube Setup${NC}"
echo ""

# ── Check prerequisites ──────────────────────────────────────────────────────
if ! command -v flutter &> /dev/null; then
  echo -e "${RED}✗ Flutter not found. Install from https://docs.flutter.dev/get-started/install${NC}"
  exit 1
fi

if ! command -v pod &> /dev/null; then
  echo -e "${RED}✗ CocoaPods not found. Install with: sudo gem install cocoapods${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Flutter found:${NC} $(flutter --version | head -1)"
echo ""

# ── flutter pub get ───────────────────────────────────────────────────────────
echo -e "${YELLOW}▶ Installing Dart packages…${NC}"
flutter pub get
echo -e "${GREEN}✓ Packages installed${NC}"
echo ""

# ── CocoaPods ─────────────────────────────────────────────────────────────────
echo -e "${YELLOW}▶ Installing CocoaPods dependencies…${NC}"
(cd ios && pod install --repo-update)
echo -e "${GREEN}✓ CocoaPods ready${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete! Open ios/Runner.xcworkspace in Xcode to build.${NC}"
echo -e "${GREEN}  Or run:  flutter run --release${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
