#!/usr/bin/env bash
# Helper script to toggle between local production Firebase credentials and safe GitHub dummy placeholders.

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="$DIR/.firebase_local"

FILES=(
  "android/app/google-services.json"
  "ios/Runner/GoogleService-Info.plist"
  "lib/firebase_options.dart"
)

case "$1" in
  use-local)
    if [ ! -d "$LOCAL_DIR" ]; then
      echo "Error: $LOCAL_DIR not found. Cannot restore local credentials."
      exit 1
    fi
    echo "Restoring local Firebase credentials for device running / testing..."
    cp "$LOCAL_DIR/android/google-services.json" "$DIR/android/app/google-services.json"
    cp "$LOCAL_DIR/ios/GoogleService-Info.plist" "$DIR/ios/Runner/GoogleService-Info.plist"
    cp "$LOCAL_DIR/lib/firebase_options.dart" "$DIR/lib/firebase_options.dart"
    
    # Instruct git to ignore local credential changes so they are never committed or pushed
    echo "Protecting credentials from Git tracking with assume-unchanged..."
    for f in "${FILES[@]}"; do
      git -C "$DIR" update-index --assume-unchanged "$f"
    done
    echo "Local Firebase credentials restored and protected. Ready for local device testing!"
    ;;

  use-dummy)
    echo "Unlocking git index for dummy placeholders..."
    for f in "${FILES[@]}"; do
      git -C "$DIR" update-index --no-assume-unchanged "$f" 2>/dev/null || true
    done
    
    echo "Applying safe dummy placeholders for GitHub..."
    if [ -f "$DIR/android/app/google-services.json" ]; then
      sed -i '' 's/"current_key": "[^"]*"/"current_key": "FIREBASE_API_KEY_ANDROID_REPLACE_ME"/g' "$DIR/android/app/google-services.json"
    fi
    if [ -f "$DIR/ios/Runner/GoogleService-Info.plist" ]; then
      sed -i '' 's/<string>FIREBASE_[^<]*<\/string>/<string>FIREBASE_API_KEY_IOS_REPLACE_ME<\/string>/g' "$DIR/ios/Runner/GoogleService-Info.plist"
    fi
    if [ -f "$DIR/lib/firebase_options.dart" ]; then
      sed -i '' "s/apiKey: '[^']*'/apiKey: 'FIREBASE_API_KEY_PLACEHOLDER'/g" "$DIR/lib/firebase_options.dart"
    fi
    echo "Dummy placeholders active. Git tree is completely safe for public repositories."
    ;;

  status)
    if grep -q "FIREBASE_API_KEY" "$DIR/lib/firebase_options.dart" 2>/dev/null; then
      echo "Active Status: Using SAFE DUMMY placeholders."
    else
      echo "Active Status: Using LOCAL REAL credentials."
    fi
    ;;

  *)
    echo "Usage: $0 {use-local|use-dummy|status}"
    exit 1
    ;;
esac
