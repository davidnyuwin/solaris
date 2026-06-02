#!/bin/bash
# scripts/smoke-test.sh

# Colors for terminal styling
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[0;33m'

TARGET_PORT=9119
BASE_URL="http://127.0.0.1:$TARGET_PORT"

echo "☄️ Starting Hermes API Smoke Test..."
echo "Target: $BASE_URL"
echo ""

# Helper check function
check_endpoint() {
    local path=$1
    local name=$2
    echo -n "Checking $name ($path)... "
    
    # 4s connection timeout
    response=$(curl -sS --max-time 4 -w "%{http_code}" "$BASE_URL$path" 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}FAILED${NC} (Curl error: $response)"
        return 1
    fi
    
    # Extract status code (last 3 chars of response)
    http_status="${response: -3}"
    
    if [ "$http_status" = "200" ]; then
        echo -e "${GREEN}PASS${NC} (HTTP 200)"
        return 0
    else
        echo -e "${RED}FAILED${NC} (HTTP status: $http_status)"
        return 1
    fi
}

# 1. Probing Port 9119
echo "Checking if port $TARGET_PORT is active..."
if ! lsof -iTCP:$TARGET_PORT -sTCP:LISTEN >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: No local listener detected on port $TARGET_PORT.${NC}"
    echo -e "Start the dashboard first using: hermes dashboard --port $TARGET_PORT"
    echo ""
fi

# 2. Probe endpoints
check_endpoint "/api/status" "Status API"
STATUS_TEST=$?

check_endpoint "/api/sessions?limit=1" "Sessions History API"
SESSIONS_TEST=$?

check_endpoint "/api/logs?file=agent&lines=5" "Logs Console API"
LOGS_TEST=$?

echo ""
echo "=== Summary ==="
if [ $STATUS_TEST -eq 0 ] && [ $SESSIONS_TEST -eq 0 ] && [ $LOGS_TEST -eq 0 ]; then
    echo -e "${GREEN}All local REST endpoints are responding correctly! Live integration is healthy.${NC}"
    exit 0
else
    echo -e "${RED}Some endpoints failed checks. Ensure 'hermes dashboard' daemon is active and running dependencies.${NC}"
    exit 1
fi
