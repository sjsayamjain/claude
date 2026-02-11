#!/bin/bash
# Auto-format files after Claude edits/writes them
# Runs prettier on supported file types silently

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only format supported file types
if echo "$FILE_PATH" | grep -qE '\.(ts|tsx|js|jsx|json|css|scss|md|html|yaml|yml|graphql)$'; then
  npx prettier --write "$FILE_PATH" 2>/dev/null || true
fi

exit 0
