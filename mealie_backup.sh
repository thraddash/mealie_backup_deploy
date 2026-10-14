#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups/backup_$(date +%y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

docker info >/dev/null 2>&1 || { echo "❌ Docker not accessible"; exit 1; }

# -a includes stopped containers
MEALIE_ID=$(docker ps -aqf "ancestor=ghcr.io/mealie-recipes/mealie:latest")
if [ -z "$MEALIE_ID" ]; then
   echo "❌ ERROR: No Mealie container found!"
   exit 1
fi

MEALIE_NAME=$(docker inspect --format '{{.Name}}' "$MEALIE_ID" | tr -d '/')
IS_RUNNING=$(docker inspect --format '{{.State.Running}}' "$MEALIE_ID")

if [ "$IS_RUNNING" = "true" ]; then
   echo "⏸ Stopping $MEALIE_NAME..."
   docker stop "$MEALIE_ID"
fi

echo "✅ Exporting SQLite database..."
docker cp "${MEALIE_ID}:/app/data/mealie.db" "$BACKUP_DIR/mealie.db"

echo "✅ Exporting recipe images..."
docker cp "${MEALIE_ID}:/app/data/recipes" "$BACKUP_DIR/recipes"
tar czf "$BACKUP_DIR/recipe_images.tar.gz" -C "$BACKUP_DIR" recipes
rm -rf "$BACKUP_DIR/recipes"

if [ "$IS_RUNNING" = "true" ]; then
   echo "▶️ Starting $MEALIE_NAME..."
   docker start "$MEALIE_ID"
fi

echo ""
echo "📦 Backup complete!"
echo "   Location: $BACKUP_DIR"
echo "   Contents:"
ls -lh "$BACKUP_DIR"
echo "DONE"
