#!/bin/bash
# freshrss-auth.sh - Authentication + token caching (1hr TTL)
# Uses Google Reader API compatible endpoint

FRESHRSS_URL="${FRESHRSS_URL:-}"
FRESHRSS_USER="${FRESHRSS_USER:-}"
FRESHRSS_PASS="${FRESHRSS_API_PASSWORD:-}"

CACHE_DIR="$HOME/.hermes/cache/freshrss"
TOKEN_FILE="$CACHE_DIR/token.txt"
EXPIRY_FILE="$CACHE_DIR/expiry"

mkdir -p "$CACHE_DIR"

# Check if we have a valid cached token
if [ -f "$TOKEN_FILE" ] && [ -f "$EXPIRY_FILE" ]; then
    EXPIRY=$(cat "$EXPIRY_FILE")
    NOW=$(date +%s)
    if [ "$NOW" -lt "$EXPIRY" ]; then
        # Token is still valid
        export FRESHRSS_AUTH=$(cat "$TOKEN_FILE")
        echo "Using cached token (expires in $((EXPIRY - NOW))s)" >&2
        return 0  # Use return instead of exit when sourced
    fi
fi

# Get new token using Google Reader API
RESPONSE=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/accounts/ClientLogin" \
    -d "Email=$FRESHRSS_USER" \
    -d "Passwd=$FRESHRSS_PASS")

AUTH=$(echo "$RESPONSE" | grep "^Auth=" | cut -d= -f2)

if [ -z "$AUTH" ]; then
    echo "Error: Authentication failed" >&2
    echo "$RESPONSE" >&2
    exit 1
fi

# Save token and expiry (1 hour TTL)
echo "$AUTH" > "$TOKEN_FILE"
echo $(( $(date +%s) + 3600 )) > "$EXPIRY_FILE"

export FRESHRSS_AUTH="$AUTH"
echo "Token acquired (cached for 1hr)"
