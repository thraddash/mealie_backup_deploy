#!/bin/bash
# Mealie restore script
# Structure: mealie_test/mealie_restore.sh + mealie_test/backup_XXXX/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="ghcr.io/mealie-recipes/mealie:latest"
DATA_DIR="$HOME/mealie/data"
ENV_FILE="$SCRIPT_DIR/mealie.env"

BACKUP_DIR=$(ls -dt "$SCRIPT_DIR"/backup_* 2>/dev/null | head -1)
if [ -z "$BACKUP_DIR" ]; then
   echo "❌ No backup folder found in $SCRIPT_DIR/"
   exit 1
fi

echo "📂 Using backup: $BACKUP_DIR"

if [ ! -f "$BACKUP_DIR/mealie.db" ] || [ ! -f "$BACKUP_DIR/recipe_images.tar.gz" ]; then
   echo "❌ Backup files missing!"
   exit 1
fi

echo "🔄 Pulling $IMAGE..."
docker pull "$IMAGE"

MEALIE_ID=$(docker ps -aqf "ancestor=$IMAGE")
if [ -n "$MEALIE_ID" ]; then
   MEALIE_NAME=$(docker inspect --format '{{.Name}}' "$MEALIE_ID" | tr -d '/')
   echo "⏸ Stopping $MEALIE_NAME..."
   docker stop "$MEALIE_ID"
   docker rm "$MEALIE_ID"
fi

mkdir -p "$DATA_DIR"

echo "✅ Restoring database..."
cp "$BACKUP_DIR/mealie.db" "$DATA_DIR/mealie.db"

echo "✅ Restoring recipe images..."
tar xzf "$BACKUP_DIR/recipe_images.tar.gz" -C "$DATA_DIR"

# Build env var args from file
ENV_ARGS=()
if [ -f "$ENV_FILE" ]; then
   while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      ENV_ARGS+=(-e "$key=$value")
   done < "$ENV_FILE"
   echo "✅ Loaded $((${#ENV_ARGS[@]}/2)) environment variables"
fi

echo "▶️ Starting Mealie..."
docker run -d --name mealie \
  -p 9000:9000 \
  -v "$DATA_DIR:/app/data" \
  "${ENV_ARGS[@]}" \
  "$IMAGE"

echo ""
echo "📦 Restore complete! http://localhost:9000"
echo "DONE"
