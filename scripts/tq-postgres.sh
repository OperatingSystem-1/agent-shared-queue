#!/bin/bash
# tq-postgres - Task Queue CLI for shared Postgres infrastructure
# Usage: tq-postgres [command] [args]

set -e

DSN="${TQ_DSN:-postgresql://botcache:localonly@127.0.0.1:5433/botcache}"
AGENT="${AGENT_NAME:-$(hostname | cut -d- -f2)}"

usage() {
    cat << EOF
Task Queue CLI - Shared Postgres Infrastructure

Usage: tq-postgres <command> [args]

Commands:
  list              List all open tasks
  mine              List my assigned tasks
  add <title>       Create new task
  claim <id>        Claim a task
  done <id>         Mark task complete
  show <id>         Show task details
  assign <id> <agent>  Assign task to agent
  inbox             Check messages for me
  send <to> <msg>   Send message to agent
  standup <status>  Post status update
  status            Show all agents' status

Environment:
  AGENT_NAME        Your agent name (default: from hostname)
  TQ_DSN            Database connection string

EOF
}

case "${1:-help}" in
    list)
        psql "$DSN" -c "
            SELECT id, title, assigned_to, status, priority 
            FROM agent_tasks 
            WHERE status NOT IN ('done', 'completed')
            ORDER BY priority, created_at"
        ;;
    mine)
        psql "$DSN" -c "
            SELECT id, title, status, priority, created_at::date as created
            FROM agent_tasks 
            WHERE assigned_to = '$AGENT' AND status NOT IN ('done', 'completed')
            ORDER BY priority, created_at"
        ;;
    add)
        shift
        TITLE="$*"
        if [ -z "$TITLE" ]; then echo "Usage: tq-postgres add <title>"; exit 1; fi
        psql "$DSN" -c "
            INSERT INTO agent_tasks (title, created_by) 
            VALUES ('$TITLE', '$AGENT')
            RETURNING id, title, status"
        ;;
    claim)
        ID="$2"
        if [ -z "$ID" ]; then echo "Usage: tq-postgres claim <id>"; exit 1; fi
        psql "$DSN" -c "
            UPDATE agent_tasks 
            SET status = 'in_progress', assigned_to = '$AGENT', updated_at = NOW()
            WHERE id = $ID
            RETURNING id, title, status, assigned_to"
        ;;
    done)
        ID="$2"
        if [ -z "$ID" ]; then echo "Usage: tq-postgres done <id>"; exit 1; fi
        psql "$DSN" -c "
            UPDATE agent_tasks 
            SET status = 'done', updated_at = NOW()
            WHERE id = $ID
            RETURNING id, title, status"
        ;;
    show)
        ID="$2"
        if [ -z "$ID" ]; then echo "Usage: tq-postgres show <id>"; exit 1; fi
        psql "$DSN" -c "SELECT * FROM agent_tasks WHERE id = $ID"
        ;;
    assign)
        ID="$2"
        TO="$3"
        if [ -z "$ID" ] || [ -z "$TO" ]; then echo "Usage: tq-postgres assign <id> <agent>"; exit 1; fi
        psql "$DSN" -c "
            UPDATE agent_tasks 
            SET assigned_to = '$TO', updated_at = NOW()
            WHERE id = $ID
            RETURNING id, title, assigned_to"
        ;;
    inbox)
        psql "$DSN" -c "
            SELECT id, from_agent, message_type, 
                   substring(content, 1, 50) as content_preview,
                   created_at::timestamp(0)
            FROM agent_messages 
            WHERE (to_agent = '$AGENT' OR to_agent IS NULL) AND read_at IS NULL
            ORDER BY created_at DESC"
        ;;
    send)
        TO="$2"
        shift 2
        MSG="$*"
        if [ -z "$TO" ] || [ -z "$MSG" ]; then echo "Usage: tq-postgres send <to> <message>"; exit 1; fi
        psql "$DSN" -c "
            INSERT INTO agent_messages (from_agent, to_agent, content)
            VALUES ('$AGENT', '$TO', '$MSG')
            RETURNING id, to_agent, content"
        ;;
    standup)
        STATUS="${2:-online}"
        TASK="$3"
        psql "$DSN" -c "
            INSERT INTO agent_standups (agent_name, status, current_task)
            VALUES ('$AGENT', '$STATUS', '$TASK')
            RETURNING id, agent_name, status"
        ;;
    status)
        psql "$DSN" -c "
            SELECT DISTINCT ON (agent_name) 
                   agent_name, status, current_task, created_at::timestamp(0)
            FROM agent_standups
            ORDER BY agent_name, created_at DESC"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac
