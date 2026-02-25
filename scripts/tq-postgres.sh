#!/bin/bash
# tq v3 - with description support
set -e

LOCAL_DSN="postgresql://botcache:localonly@127.0.0.1:5433/botcache"
NEON_DSN="${AGENT_DB_URL:-postgresql://neondb_owner:npg_24bYhdRcyZax@ep-polished-bread-ai1pqzi9-pooler.c-4.us-east-1.aws.neon.tech/neondb?sslmode=require}"
AGENT="${AGENT_NAME:-}"

require_agent() {
    [ -z "$AGENT" ] && { echo "Error: AGENT_NAME not set" >&2; exit 1; }
}

write_db() { psql "$NEON_DSN" "$@"; }
read_db() { psql "$LOCAL_DSN" "$@"; }

case "${1:-help}" in
    list) read_db -c "SELECT id, title, assigned_to, status, priority FROM agent_tasks WHERE status NOT IN ('done', 'completed') ORDER BY priority, created_at" ;;
    mine) require_agent; read_db -c "SELECT id, title, status, priority FROM agent_tasks WHERE assigned_to = '$AGENT' AND status NOT IN ('done', 'completed') ORDER BY priority" ;;
    add)
        require_agent
        shift
        TITLE=""
        DESC=""
        PRIORITY=5
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --desc=*) DESC="${1#*=}"; shift ;;
                --desc) DESC="$2"; shift 2 ;;
                --priority=*) PRIORITY="${1#*=}"; shift ;;
                --priority|-p) PRIORITY="$2"; shift 2 ;;
                *) TITLE="$TITLE $1"; shift ;;
            esac
        done
        TITLE="${TITLE# }"
        [ -z "$TITLE" ] && { echo "Usage: tq add <title> [--desc <description>] [--priority <n>]" >&2; exit 1; }
        if [ -n "$DESC" ]; then
            write_db -c "INSERT INTO agent_tasks (title, description, priority, created_by) VALUES ('$TITLE', '$DESC', $PRIORITY, '$AGENT') RETURNING id, title, priority"
        else
            write_db -c "INSERT INTO agent_tasks (title, priority, created_by) VALUES ('$TITLE', $PRIORITY, '$AGENT') RETURNING id, title, priority"
        fi
        ;;
    claim) require_agent; [ -z "$2" ] && { echo "Usage: tq claim <id>" >&2; exit 1; }; write_db -c "UPDATE agent_tasks SET status = 'in_progress', assigned_to = '$AGENT', updated_at = NOW() WHERE id = $2 RETURNING id, title, status, assigned_to" ;;
    done) [ -z "$2" ] && { echo "Usage: tq done <id>" >&2; exit 1; }; write_db -c "UPDATE agent_tasks SET status = 'done', updated_at = NOW() WHERE id = $2 RETURNING id, title, status" ;;
    show) [ -z "$2" ] && { echo "Usage: tq show <id>" >&2; exit 1; }; read_db -c "SELECT * FROM agent_tasks WHERE id = $2" ;;
    inbox) require_agent; read_db -c "SELECT id, from_agent, substring(content, 1, 50) as preview FROM agent_messages WHERE (to_agent = '$AGENT' OR to_agent IS NULL) AND read_at IS NULL ORDER BY created_at DESC" ;;
    send) require_agent; shift; TO="$1"; shift; [ -z "$TO" ] || [ -z "$*" ] && { echo "Usage: tq send <to> <message>" >&2; exit 1; }; write_db -c "INSERT INTO agent_messages (from_agent, to_agent, content) VALUES ('$AGENT', '$TO', '$*') RETURNING id, to_agent" ;;
    standup) require_agent; write_db -c "INSERT INTO agent_standups (agent_name, status, current_task) VALUES ('$AGENT', '${2:-online}', '$3') RETURNING agent_name, status" ;;
    status) read_db -c "SELECT DISTINCT ON (agent_name) agent_name, status, current_task FROM agent_standups ORDER BY agent_name, created_at DESC" ;;
    sync) echo "=== Neon ==="; write_db -c "SELECT id, title, status FROM agent_tasks ORDER BY id"; echo "=== Local ==="; read_db -c "SELECT id, title, status FROM agent_tasks ORDER BY id" ;;
    help|--help|-h) cat << EOF
tq v3 - Task Queue CLI

Usage: tq <command> [args]

Commands:
  add <title> [--desc <d>] [--priority <n>]  Create task with description
  list | mine | claim <id> | done <id> | show <id>
  inbox | send <to> <msg> | standup | status | sync

Examples:
  tq add "Fix bug" --desc "Crashes on startup" --priority 2
  tq claim 22
  tq done 22
EOF
        ;;
    *) echo "Unknown: $1. Run 'tq help'" >&2; exit 1 ;;
esac
