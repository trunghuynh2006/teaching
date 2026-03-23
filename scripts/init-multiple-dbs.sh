#!/usr/bin/env bash
# Creates multiple PostgreSQL databases from the POSTGRES_MULTIPLE_DATABASES env var.
# Usage: set POSTGRES_MULTIPLE_DATABASES=db1,db2,db3 in docker-compose.
set -e

create_db() {
  local db="$1"
  echo "Creating database: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
    SELECT 'CREATE DATABASE $db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
SQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
  for db in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' ' '); do
    create_db "$db"
  done
fi
