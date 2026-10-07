#!/usr/bin/env bash
# Push the ChocoBlock Flutter port to GitHub.
#
# Run this from any terminal that has git + GitHub auth configured
# (either via SSH key, HTTPS credential helper, or `gh auth login`).
#
# Usage:
#   bash /home/z/my-project/best-block-blast/push-to-github.sh
#
# Or from a local clone:
#   git clone https://github.com/jessicacarter9955/best-block-blast.git
#   cp -r /path/to/sandbox/best-block-blast/* best-block-blast/
#   cd best-block-blast
#   bash push-to-github.sh

set -euo pipefail
cd "$(dirname "$0")"

REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-master}"

echo "Repo: $(pwd)"
echo "Remote: $REMOTE"
echo "Branch: $BRANCH"
echo
echo "Current HEAD: $(git rev-parse HEAD)"
echo "Pending commits to push:"
git log --oneline "$REMOTE/$BRANCH..HEAD" || git log --oneline -n 5
echo
echo "Files changed (vs remote):"
git diff --stat "$REMOTE/$BRANCH..HEAD" 2>/dev/null | tail -3 || true
echo
read -r -p "Push now? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

echo
echo "Pushing to $REMOTE/$BRANCH..."
git push "$REMOTE" "$BRANCH"

echo
echo "Done."
echo "Watch the build at: https://github.com/jessicacarter9955/best-block-blast/actions"
