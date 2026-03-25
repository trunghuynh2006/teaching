#!/usr/bin/env bash
# Hourly backup of study_platform_api and study_platform_ai.
# Keeps the last 48 backups per database (2 days at hourly cadence).
set -euo pipefail

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres}"
export PGPASSWORD

BACKUP_DIR="${BACKUP_DIR:-$HOME/db-backups/study-platform}"
KEEP=48

DATABASES=(study_platform_api study_platform_ai)

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

for DB in "${DATABASES[@]}"; do
    FILE="$BACKUP_DIR/${DB}_${TIMESTAMP}.dump"
    echo "[$(date -Iseconds)] backing up $DB → $FILE"
    pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -Fc "$DB" -f "$FILE"
    echo "[$(date -Iseconds)] done ($(du -sh "$FILE" | cut -f1))"

    # Rotate: keep only the newest $KEEP backups for this database
    mapfile -t OLD < <(ls -1t "$BACKUP_DIR/${DB}"_*.dump 2>/dev/null | tail -n +$((KEEP + 1)))
    if (( ${#OLD[@]} > 0 )); then
        echo "[$(date -Iseconds)] removing ${#OLD[@]} old backup(s) for $DB"
        rm -f "${OLD[@]}"
    fi
done
