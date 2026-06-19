#!/bin/bash
set -e

echo "=== 1. Compiling Python Backend ==="
cd backend
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements_ci.txt
.venv/bin/pip install pyinstaller
.venv/bin/pyinstaller --noconfirm --onedir --noconsole --name "kivo_backend" main.py
cd ..

echo "=== 2. Building Flutter Frontend ==="
cd frontend
flutter build macos --release

echo "=== 3. Injecting Backend into macOS App Bundle ==="
mkdir -p "build/macos/Build/Products/Release/Kivo Workspace.app/Contents/Resources/bin"
cp -R ../backend/dist/kivo_backend "build/macos/Build/Products/Release/Kivo Workspace.app/Contents/Resources/bin/"

echo "=== 4. Packaging Drag-and-Drop DMG Installer ==="
cd build/macos/Build/Products/Release
rm -rf dmg_staging
mkdir -p dmg_staging
cp -R "Kivo Workspace.app" dmg_staging/
ln -s /Applications dmg_staging/Applications
rm -f ../../../../../KivoWorkspace-macOS-Intel.dmg
hdiutil create -fs HFS+ -srcfolder dmg_staging -volname "Kivo Workspace" -format UDZO ../../../../../KivoWorkspace-macOS-Intel.dmg
rm -rf dmg_staging

echo "=== Done! macOS Intel DMG is ready in the project root folder. ==="
