#!/usr/bin/env bash
# Push best-block-blast (Block Rush 1:1) to GitHub using the PAT stored in
# /home/z/my-project/CREDENTIALS.md — no need to re-enter the token.
#
#   bash push-with-token.sh [commit_message]
set -euo pipefail
cd "$(dirname "$0")"

TOKEN=$(grep -o 'github_pat_[A-Za-z0-9_]*' /home/z/my-project/CREDENTIALS.md | head -1)
if [ -z "$TOKEN" ]; then
  echo "Token non trovato in CREDENTIALS.md" >&2
  exit 1
fi

REMOTE_URL="https://${TOKEN}@github.com/jessicacarter9955/best-block-blast.git"
git remote remove rush 2>/dev/null || true
git remote add rush "$REMOTE_URL"

if [ -n "${1:-}" ]; then
  git add -A
  git commit -m "$1" || true
fi

echo "Push su rush/master..."
git push rush master
echo
echo "Build APK: https://github.com/jessicacarter9955/best-block-blast/actions"
