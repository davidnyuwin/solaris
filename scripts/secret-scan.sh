#!/bin/bash
# scripts/secret-scan.sh

# Colors for terminal styling
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[0;33m'

echo "🔒 Starting Solaris Security Secret & Path Scan..."
echo ""

# Scan targeting:
# 1. OpenAI / Stripe / standard secret keys: sk-[A-Za-z0-9]{20,}
# 2. Personal macOS user path: /Users/dnguyen
# 3. Variable assignments with actual key values: (key|secret|token|password|passwd|client_secret|auth)[_-]?(value|string)?[[:space:]]*[=:][[:space:]]*["'][A-Za-z0-9_\-\.\+]{8,}["']
# 4. Bearer tokens in headers: bearer[[:space:]]+[A-Za-z0-9_\-\.]{12,}

echo "Scanning repository files..."
echo ""

# Scan for personal paths
matches_paths=$(git grep -nEi "/Users/dnguyen" -- ':!scripts/secret-scan.sh' ':!docs/visual-parity.md' 2>/dev/null)

# Scan for hardcoded keys and tokens (sk-...)
matches_keys=$(git grep -nEi "sk-[A-Za-z0-9]{20,}" -- ':!scripts/secret-scan.sh' ':!docs/visual-parity.md' 2>/dev/null)

# Scan for bearer token values
matches_bearer=$(git grep -nEi "bearer[[:space:]]+[A-Za-z0-9_\-\.]{12,}" -- ':!scripts/secret-scan.sh' ':!docs/visual-parity.md' 2>/dev/null)

# Scan for direct credentials assignments, ignoring standard SwiftUI/Swift 'forKey:' parameters
matches_assignments=$(git grep -nEi "(key|secret|token|password|passwd|client_secret|auth)[a-zA-Z0-9_-]*[[:space:]]*[=:][[:space:]]*[\"'][A-Za-z0-9_\-\.\+]{8,}[\"']" -- ':!scripts/secret-scan.sh' ':!docs/visual-parity.md' ':!Sources/HermesCompanion/Mock/MockHermesService.swift' 2>/dev/null | grep -vi "forKey:")

# Combine matches
all_matches=""
if [ ! -z "$matches_paths" ]; then
    all_matches="${all_matches}${matches_paths}\n"
fi
if [ ! -z "$matches_keys" ]; then
    all_matches="${all_matches}${matches_keys}\n"
fi
if [ ! -z "$matches_bearer" ]; then
    all_matches="${all_matches}${matches_bearer}\n"
fi
if [ ! -z "$matches_assignments" ]; then
    all_matches="${all_matches}${matches_assignments}\n"
fi

if [ -z "$all_matches" ]; then
    echo -e "${GREEN}SUCCESS: No high-risk secrets, API keys, or personal paths detected!${NC}"
    echo "Repository is clean and safe for public GitHub."
    exit 0
else
    echo -e "${RED}WARNING: Possible secrets or absolute developer paths detected!${NC}"
    echo "Please review the following occurrences:"
    echo "----------------------------------------"
    echo -e "$all_matches" | sed '/^$/d'
    echo "----------------------------------------"
    echo ""
    echo -e "${YELLOW}Ensure no real production keys, passwords, or personal paths are committed.${NC}"
    exit 1
fi
