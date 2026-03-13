#!/bin/bash
# meister - Quick Install
# Usage: curl -fsSL https://raw.githubusercontent.com/maf4711/meister8/main/install.sh | bash

set -euo pipefail

echo "=== meister Installer ==="
echo ""

# Homebrew pruefen
if ! command -v brew &>/dev/null; then
    echo "Homebrew nicht gefunden. Installiere Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Installieren oder upgraden
if brew list maf4711/meister/meister &>/dev/null; then
    echo "meister ist bereits installiert - upgrade..."
    brew upgrade maf4711/meister/meister
else
    echo "Installiere meister..."
    brew install maf4711/meister/meister
fi

echo ""
echo "Fertig! Starte mit: meister -h"
