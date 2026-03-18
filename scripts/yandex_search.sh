#!/bin/bash
# Yandex Search API v2 CLI wrapper
# Usage: yandex_search.sh "search query" [--generative] [--folder-id ID]
#
# Prerequisites:
#   1. Install yc CLI: https://yandex.cloud/en/docs/cli/quickstart
#   2. Service account with search-api.webSearch.user role
#   3. Run: yc init (once)
#
# Token is auto-refreshed via yc CLI. No manual token management needed.

set -euo pipefail

QUERY="${1:?Usage: yandex_search.sh \"query\" [--generative] [--folder-id ID]}"
MODE="search"
FOLDER_ID="${YANDEX_FOLDER_ID:-}"

shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --generative) MODE="search_generative"; shift ;;
    --folder-id) FOLDER_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$FOLDER_ID" ]]; then
  echo "ERROR: Set YANDEX_FOLDER_ID env var or pass --folder-id" >&2
  exit 1
fi

# Get fresh IAM token (auto-refreshes, cached by yc)
TOKEN=$(yc iam create-token 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Failed to get IAM token. Run 'yc init' first." >&2
  exit 1
fi

MCP_URL="https://search.mcp.cloud.yandex.net/mcp"

if [[ "$MODE" == "search" ]]; then
  # Standard web search via MCP endpoint
  # MCP uses JSON-RPC over HTTP
  PAYLOAD=$(jq -n \
    --arg query "$QUERY" \
    '{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "tools/call",
      "params": {
        "name": "search",
        "arguments": {
          "query": $query
        }
      }
    }')
else
  # Generative search
  PAYLOAD=$(jq -n \
    --arg query "$QUERY" \
    '{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "tools/call",
      "params": {
        "name": "search_generative",
        "arguments": {
          "messages": [{"role": "user", "content": $query}]
        }
      }
    }')
fi

# Call MCP endpoint directly via HTTP
RESPONSE=$(curl -sS \
  -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Folder-Id: $FOLDER_ID" \
  -d "$PAYLOAD" \
  --max-time 30)

# Extract result content
echo "$RESPONSE" | jq -r '.result.content[]?.text // .result // .error // "No results"' 2>/dev/null || echo "$RESPONSE"
