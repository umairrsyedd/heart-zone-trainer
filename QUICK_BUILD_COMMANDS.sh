#!/bin/bash
# Quick build script for Heart Zone Trainer AAB
# Run this script to build the Android App Bundle for Play Store

set -e  # Exit on error

echo "🏗️  Building Heart Zone Trainer v1.0.0 AAB for Play Store..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build the AAB
echo "🔨 Building Android App Bundle (release)..."
flutter build appbundle --release

# Verify output
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_PATH" ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 AAB file location:"
    echo "   $AAB_PATH"
    echo ""
    echo "📊 File size:"
    ls -lh "$AAB_PATH" | awk '{print "   " $5}'
    echo ""
    echo "🚀 Ready to upload to Google Play Console!"
    echo ""
    echo "Next steps:"
    echo "1. Go to Google Play Console"
    echo "2. Select 'Heart Zone Trainer'"
    echo "3. Production → Create new release"
    echo "4. Upload: $AAB_PATH"
else
    echo ""
    echo "❌ Build failed - AAB file not found"
    echo "Check the error messages above"
    exit 1
fi

