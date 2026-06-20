#!/bin/bash
set -e

echo "=== 1. Building Flutter Frontend (Web) ==="
cd frontend
flutter pub get
flutter build web --release
cd ..

echo "=== 2. Setting up Web Assets for Backend ==="
rm -rf backend/web
cp -R frontend/build/web backend/web

echo "=== 3. Compiling Python Backend (with Embedded Web Assets) ==="
cd backend
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements_ci.txt
.venv/bin/pip install pyinstaller
.venv/bin/pyinstaller --noconfirm --onedir --noconsole --name "Kivo Workspace" --add-data "web:web" main.py
cd ..

echo "=== 4. Packaging Drag-and-Drop DMG Installer ==="
cd backend/dist
rm -rf dmg_staging
mkdir -p dmg_staging
cp -R "Kivo Workspace.app" dmg_staging/
ln -s /Applications dmg_staging/Applications
rm -f ../../KivoWorkspace-macOS.dmg
hdiutil create -fs HFS+ -srcfolder dmg_staging -volname "Kivo Workspace" -format UDZO ../../KivoWorkspace-macOS.dmg
rm -rf dmg_staging
cd ../..

echo "=== Done! macOS DMG is ready in the project root folder. ==="
