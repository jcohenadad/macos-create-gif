#!/bin/bash
# Install the "Create GIF" Quick Action into ~/Library/Services
set -e
cd "$(dirname "$0")"
DEST="$HOME/Library/Services"
mkdir -p "$DEST"
rm -rf "$DEST/Create GIF.workflow"
cp -R "Create GIF.workflow" "$DEST/"
# Refresh the Services/Quick Actions cache
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
echo "Installed to $DEST/Create GIF.workflow"
echo "If it doesn't appear under Quick Actions, enable it in:"
echo "  System Settings > General > Login Items & Extensions > Finder"
