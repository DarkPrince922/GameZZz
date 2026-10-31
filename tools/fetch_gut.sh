#!/usr/bin/env bash
# Fetch the pinned GUT version into addons/gut (not committed to the repo).
# Version facts: GUT 9.5.0 supports Godot 4.5.x (bitwes/Gut README version table).
set -euo pipefail

GUT_VERSION="${GUT_VERSION:-9.5.0}"

if [ -d "addons/gut" ] && [ -f "addons/gut/gut_cmdln.gd" ]; then
  echo "GUT already present in addons/gut"
  exit 0
fi

mkdir -p addons
ZIP="/tmp/gut-${GUT_VERSION}.zip"
URL="https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.zip"
echo "Downloading GUT ${GUT_VERSION} from ${URL}"
if command -v wget >/dev/null 2>&1; then
  wget -q "$URL" -O "$ZIP"
else
  curl -sSL "$URL" -o "$ZIP"
fi
rm -rf /tmp/gut_src
mkdir -p /tmp/gut_src
unzip -q "$ZIP" -d /tmp/gut_src
cp -r "/tmp/gut_src/Gut-${GUT_VERSION}/addons/gut" addons/gut
echo "GUT ${GUT_VERSION} installed into addons/gut"
