#!/usr/bin/env bash
#
# sync-obsidian.sh
# Syncs blog posts from Obsidian vault to Quarto website.
#
# Obsidian folder: <vault>/blog/ready/
# Each .md file there becomes a post in posts/<slug>/index.qmd
#
# Requirements for each note:
#   - Must have YAML frontmatter with at least: title, date
#   - Optionally: author, categories, description
#   - Images referenced in the note should be in the same folder or
#     use Obsidian's ![[image.png]] syntax (converted automatically)
#
# Usage: ./sync-obsidian.sh [--dry-run]

set -euo pipefail

VAULT="/Users/diego.lopes/Documents/This sentence is false"
READY_DIR="$VAULT/blog/ready"
POSTS_DIR="$(cd "$(dirname "$0")" && pwd)/posts"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [[ ! -d "$READY_DIR" ]]; then
  echo "No ready folder found at $READY_DIR"
  exit 0
fi

count=0
for file in "$READY_DIR"/*.md; do
  [[ -f "$file" ]] || continue

  filename=$(basename "$file" .md)
  # Create a URL-friendly slug
  slug=$(echo "$filename" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

  target_dir="$POSTS_DIR/$slug"

  if $DRY_RUN; then
    echo "[dry-run] Would sync: $filename -> posts/$slug/"
    continue
  fi

  mkdir -p "$target_dir"

  # Copy the markdown file, converting .md to .qmd
  # Convert Obsidian image embeds ![[image.png]] to Quarto format ![](image.png)
  sed 's/!\[\[\([^]]*\)\]\]/![](\1)/g' "$file" > "$target_dir/index.qmd"

  # Copy any images referenced in the note from Obsidian's Files folder
  grep -oE '!\[\]\([^)]+\)' "$target_dir/index.qmd" 2>/dev/null | sed 's/!\[\](\(.*\))/\1/' | while read -r img; do
    # Check common Obsidian attachment locations
    for search_dir in "$READY_DIR" "$VAULT/Files" "$VAULT/Attachments" "$VAULT"; do
      if [[ -f "$search_dir/$img" ]]; then
        cp "$search_dir/$img" "$target_dir/$img"
        break
      fi
    done
  done

  echo "Synced: $filename -> posts/$slug/"
  count=$((count + 1))
done

if [[ $count -eq 0 ]]; then
  echo "No posts found in $READY_DIR"
else
  echo "Synced $count post(s). Run 'quarto render' to build."
fi
