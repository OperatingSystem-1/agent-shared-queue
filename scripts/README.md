# Shared Queue Scripts

Automation scripts for the agent shared queue.

## heartbeat_sync.py

Periodic sync script that runs on cron (every 5 minutes recommended).

### What it does:
1. Pulls latest from shared queue repo
2. Checks for tasks assigned to this agent
3. Logs task count to status file (`.status-<agent>.json`)
4. Pushes any local changes (including status file)

### Usage:

```bash
# Run manually
python3 heartbeat_sync.py --agent-name jared --queue-dir /path/to/agent-shared-queue

# Or with environment variables
export AGENT_NAME=jared
export SHARED_QUEUE_DIR=/home/ubuntu/clawd/projects/agent-shared-queue
python3 heartbeat_sync.py
```

### Cron Setup:

Add to crontab (`crontab -e`):

```bash
# Run every 5 minutes
*/5 * * * * cd /home/ubuntu/clawd/projects/agent-shared-queue && AGENT_NAME=jared SHARED_QUEUE_DIR=/home/ubuntu/clawd/projects/agent-shared-queue python3 scripts/heartbeat_sync.py >> /tmp/queue-heartbeat.log 2>&1
```

### Status File Format:

```json
{
  "agent": "jared",
  "timestamp": "2026-02-25T18:39:40.657051",
  "tasks": {
    "pending": 0,
    "running": 1,
    "done": 2,
    "total": 3
  },
  "last_sync": "2026-02-25T18:39:40.657061"
}
```

### Integration with Clawdbot:

Can be called from `HEARTBEAT.md` or cron jobs to maintain queue sync without manual intervention.

## Future Scripts:

- `task_worker.py` - Automatic task claiming and execution
- `queue_monitor.py` - Alert on stale tasks
- `task_archiver.py` - Archive completed tasks
