#!/usr/bin/env bash
#
# Faehrt eine Wegwerf-PostgreSQL-Instanz hoch, spielt alle Migrationen aus
# `supabase/migrations/` der Reihe nach ein und laesst danach die SQL-Tests aus
# `scripts/tests/*.sql` laufen. Danach wird der Cluster restlos geloescht.
#
# Hintergrund: Bis KL-WEB-003 lief die RPC-SQL dieses Projekts nie gegen ein
# echtes PostgreSQL, bevor der Nutzer sie auf der oeffentlichen Instanz
# anwendete — und genau dort kamen dann zwei echte Fehler heraus, die kein
# Unit-Test finden konnte. Dieses Skript schliesst diese Luecke lokal.
#
#   ./scripts/verify-supabase-migrations.sh              # alle Tests
#   ./scripts/verify-supabase-migrations.sh table-context # nur einer
#
# Es braucht ein lokales PostgreSQL 16+ (z. B. `brew install postgresql@16`).
# Es fasst weder die echte Supabase-Instanz noch Secrets an.
#
# ACHTUNG, geteilte Datenbank: alle Tests aus `scripts/tests/` laufen
# nacheinander auf **einem** Cluster, in alphabetischer Reihenfolge. Ein Test
# muss deshalb (a) aufraeumen, was er anlegt, und (b) einen **eigenen
# UUID-Block** fuer seine Testkonten benutzen. Belegt sind:
#
#   …0000000000aa/bb   Personal und Fremde (payments, table-context, stations,
#                      business-shift)
#   …0000000000c1/c2   Gaeste (payments)
#   …0000000000d1-d3   Gaeste (business-shift)
#   …0000000000e1-e9   Konten (roles-and-permissions)
#   …0000000000f1-f9   Konten (manager-pin)
#   …000000009901-9909 Konten (time-clock)
#
# Kollidieren zwei Tests auf einer Kennung, laesst `on conflict (id) do
# nothing` die Konten des spaeteren Tests still fallen — und der Fehler taucht
# weit entfernt als „kein Konto" auf.
#
# Zusaetzlich wird jede Migration ein zweites Mal eingespielt. Grund: die
# Instanz wird auf zwei Wegen gepflegt (CLI `supabase db push` und der
# SQL-Editor im Dashboard). Wird eine Migration von Hand im Editor ausgefuehrt,
# erfaehrt die Ledger-Tabelle `supabase_migrations.schema_migrations` davon
# nichts — ein spaeteres `db push` spielt sie dann erneut ein. Das darf nicht
# scheitern und nichts doppelt anlegen. Nur ein wiederholbares Migrationsset
# macht die beiden Wege vertraeglich.

set -euo pipefail

# Ohne gueltige Locale bricht der Postmaster auf macOS beim Start ab
# ("Postmaster ist waehrend des Starts multithreaded geworden"). Die Daten
# bleiben UTF-8; nur die Sortierreihenfolge ist C, was fuer die Tests egal ist.
export LC_ALL="${LC_ALL:-C}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="$REPO_ROOT/supabase/migrations"
TESTS_DIR="$REPO_ROOT/scripts/tests"

find_pg_bin() {
  if [[ -n "${PG_BIN:-}" ]]; then
    echo "$PG_BIN"
    return
  fi
  local candidate
  for candidate in \
    "$(brew --prefix postgresql@17 2>/dev/null || true)/bin" \
    "$(brew --prefix postgresql@16 2>/dev/null || true)/bin" \
    "$(brew --prefix libpq 2>/dev/null || true)/bin"; do
    if [[ -x "$candidate/initdb" ]]; then
      echo "$candidate"
      return
    fi
  done
  if command -v initdb >/dev/null 2>&1; then
    dirname "$(command -v initdb)"
    return
  fi
  echo ""
}

PG_BIN="$(find_pg_bin)"
if [[ -z "$PG_BIN" || ! -x "$PG_BIN/initdb" ]]; then
  echo "FEHLER: kein lokales PostgreSQL gefunden (initdb). Etwa: brew install postgresql@16" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kitchenlink-pg.XXXXXX")"
DATA_DIR="$WORK_DIR/data"
LOG_FILE="$WORK_DIR/postgres.log"
STARTED=0

cleanup() {
  if [[ "$STARTED" == "1" ]]; then
    "$PG_BIN/pg_ctl" -D "$DATA_DIR" -m immediate stop >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "PostgreSQL: $("$PG_BIN/postgres" --version)"
"$PG_BIN/initdb" -D "$DATA_DIR" -U postgres --auth=trust --encoding=UTF8 >/dev/null

# Nur ueber Unix-Socket im Arbeitsverzeichnis: kein Port, keine Kollision mit
# einer lokal laufenden Datenbank des Nutzers.
"$PG_BIN/pg_ctl" -D "$DATA_DIR" -l "$LOG_FILE" \
  -o "-k '$WORK_DIR' -h '' -c fsync=off -c full_page_writes=off" \
  -w start >/dev/null
STARTED=1

export PGHOST="$WORK_DIR"
export PGUSER=postgres
export PGDATABASE=postgres

run_sql() {
  "$PG_BIN/psql" --quiet --no-psqlrc -v ON_ERROR_STOP=1 -f "$1"
}

echo "Supabase-Stubs …"
run_sql "$TESTS_DIR/supabase-stubs.sql" >/dev/null

echo "Migrationen:"
for migration in "$MIGRATIONS_DIR"/*.sql; do
  echo "  $(basename "$migration")"
  run_sql "$migration" >/dev/null
done

# Zweiter Durchlauf: jede Migration muss sich auf einem Stand, auf dem sie schon
# angewendet wurde, wiederholen lassen (siehe Kopf dieser Datei).
echo "Migrationen erneut (Wiederholbarkeit):"
reapply_failed=0
for migration in "$MIGRATIONS_DIR"/*.sql; do
  name="$(basename "$migration")"
  if run_sql "$migration" >/dev/null 2>"$WORK_DIR/reapply.err"; then
    echo "  $name: wiederholbar"
  else
    echo "  $name: NICHT WIEDERHOLBAR" >&2
    sed 's/^/    /' "$WORK_DIR/reapply.err" >&2
    reapply_failed=1
  fi
done

if [[ "$reapply_failed" != "0" ]]; then
  echo "Migrationen sind nicht wiederholbar — ein 'db push' nach einer" >&2
  echo "Anwendung im SQL-Editor wuerde scheitern." >&2
  exit 1
fi

selected=("$@")
if [[ ${#selected[@]} -eq 0 ]]; then
  for test_file in "$TESTS_DIR"/*.sql; do
    name="$(basename "$test_file" .sql)"
    [[ "$name" == "supabase-stubs" ]] && continue
    selected+=("$name")
  done
fi

echo "Tests:"
failed=0
for name in "${selected[@]}"; do
  test_file="$TESTS_DIR/$name.sql"
  if [[ ! -f "$test_file" ]]; then
    echo "  $name: Datei fehlt ($test_file)" >&2
    failed=1
    continue
  fi
  if run_sql "$test_file"; then
    echo "  $name: bestanden"
  else
    echo "  $name: FEHLGESCHLAGEN" >&2
    failed=1
  fi
done

if [[ "$failed" != "0" ]]; then
  echo "Migrationstests fehlgeschlagen." >&2
  exit 1
fi

echo "Alle Migrationen und SQL-Tests bestanden."
