#!/bin/bash
# tq - Task Queue CLI with direct Neon write-through
set -e

LOCAL_DSN="postgresql://botcache:localonly@127.0.0.1:5433/botcache"
NEON_DSN="${AGENT_DB_URL:-postgresql://neondb_owner:npg_24bYhdRcyZax@ep-polished-bread-ai1pqzi9-pooler.c-4.us-east-1.aws.neon.tech/neondb?sslmode=require}"
AGENT="${AGENT_NAME:-jean}"

write_db() { psql "$NEON_DSN" "$@"; }
read_db() { psql "$LOCAL_DSN" "$@"; }

case "${1:-help}" in
    list) read_db -c "SELECT id, title, assigned_to, status, priority FROM agent_tasks WHERE status NOT IN ('done', 'completed') ORDER BY priority, created_at" ;;
    mine) read_db -c "SELECT id, title, status, priority FROM agent_tasks WHERE assigned_to = '$AGENT' AND status NOT IN ('done', 'completed') ORDER BY priority" ;;
    add) shift; write_db -c "INSERT INTO agent_tasks (title, created_by) VALUES ('$*', '$AGENT') RETURNING id, title, status" ;;
    claim) write_db -c "UPDATE agent_tasks SET status = 'in_progress', assigned_to = '$AGENT', updated_at = NOW() WHERE id = $2 RETURNING id, title, status, assigned_to" ;;
    done) write_db -c "UPDATE agent_tasks SET status = 'done', updated_at = NOW() WHERE id = $2 RETURNING id, title, status" ;;
    show) read_db -c "SELECT * FROM agent_tasks WHERE id = $2" ;;
    inbox) read_db -c "SELECT id, from_agent, substring(content, 1, 50) as preview FROM agent_messages WHERE (to_agent = '$AGENT' OR to_agent IS NULL) AND read_at IS NULL ORDER BY created_at DESC" ;;
    send) shift; TO="$1"; shift; write_db -c "INSERT INTO agent_messages (from_agent, to_agent, content) VALUES ('$AGENT', '$TO', '$*') RETURNING id, to_agent" ;;
    standup) write_db -c "INSERT INTO agent_standups (agent_name, status, current_task) VALUES ('$AGENT', '${2:-online}', '$3') RETURNING agent_name, status" ;;
    status) read_db -c "SELECT DISTINCT ON (agent_name) agent_name, status, current_task FROM agent_standups ORDER BY agent_name, created_at DESC" ;;
    sync) echo "=== Neon ==="; write_db -c "SELECT id, title, status FROM agent_tasks ORDER BY id"; echo "=== Local ==="; read_db -c "SELECT id, title, status FROM agent_tasks ORDER BY id" ;;
    *) echo "tq [list|mine|add|claim|done|show|inbox|send|standup|status|sync]" ;;
esac
