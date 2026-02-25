#!/usr/bin/env python3
"""
Shared Queue Heartbeat Sync

Runs periodically (cron every 5 min) to:
1. Pull latest from shared queue repo
2. Check for tasks assigned to this agent
3. Log task count to status file
4. Push any local changes

Usage:
  python3 heartbeat_sync.py [--agent-name NAME] [--queue-dir PATH]

Environment Variables:
  AGENT_NAME - Agent identifier (default: from hostname)
  SHARED_QUEUE_DIR - Path to shared queue repo (default: /data/shared-queue)
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime
import argparse
import socket


def run_cmd(cmd, cwd=None, check=True):
    """Run shell command and return output."""
    result = subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        capture_output=True,
        text=True
    )
    if check and result.returncode != 0:
        print(f"Error running: {cmd}", file=sys.stderr)
        print(f"stderr: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip(), result.returncode


def sync_repo(queue_dir):
    """Pull latest and push any local changes."""
    print(f"[{datetime.now().isoformat()}] Syncing repo at {queue_dir}")
    
    # Pull latest
    out, rc = run_cmd("git pull --rebase origin main", cwd=queue_dir, check=False)
    if rc != 0:
        print(f"Warning: git pull failed: {out}", file=sys.stderr)
    
    # Push any local changes
    run_cmd("git push origin main", cwd=queue_dir, check=False)
    
    print("Sync complete")


def count_my_tasks(queue_dir, agent_name):
    """Count tasks assigned to this agent by status."""
    tasks_dir = queue_dir / "tasks"
    if not tasks_dir.exists():
        return {"pending": 0, "running": 0, "done": 0, "total": 0}
    
    counts = {"pending": 0, "running": 0, "done": 0, "total": 0}
    
    for task_file in tasks_dir.glob("*.json"):
        try:
            task = json.loads(task_file.read_text())
            if task.get("for_agent") == agent_name or task.get("for_agent") == "any":
                status = task.get("status", "pending")
                counts[status] = counts.get(status, 0) + 1
                counts["total"] += 1
        except Exception as e:
            print(f"Warning: Failed to read {task_file}: {e}", file=sys.stderr)
    
    return counts


def write_status(status_file, agent_name, counts):
    """Write status to JSON file."""
    status = {
        "agent": agent_name,
        "timestamp": datetime.now().isoformat(),
        "tasks": counts,
        "last_sync": datetime.now().isoformat()
    }
    
    status_file.parent.mkdir(parents=True, exist_ok=True)
    status_file.write_text(json.dumps(status, indent=2))
    print(f"Status written to {status_file}")


def main():
    parser = argparse.ArgumentParser(description="Shared queue heartbeat sync")
    parser.add_argument("--agent-name", help="Agent identifier")
    parser.add_argument("--queue-dir", help="Path to shared queue repo")
    parser.add_argument("--status-file", help="Path to status file")
    args = parser.parse_args()
    
    # Get config
    agent_name = args.agent_name or os.environ.get("AGENT_NAME", socket.gethostname().split(".")[0])
    queue_dir = Path(args.queue_dir or os.environ.get("SHARED_QUEUE_DIR", "/data/shared-queue"))
    status_file = Path(args.status_file or queue_dir / f".status-{agent_name}.json")
    
    print(f"=== Shared Queue Heartbeat Sync ===")
    print(f"Agent: {agent_name}")
    print(f"Queue: {queue_dir}")
    print(f"Status: {status_file}")
    print()
    
    if not queue_dir.exists():
        print(f"Error: Queue directory not found: {queue_dir}", file=sys.stderr)
        sys.exit(1)
    
    # Sync repo
    sync_repo(queue_dir)
    
    # Count my tasks
    counts = count_my_tasks(queue_dir, agent_name)
    
    print(f"Tasks for {agent_name}:")
    print(f"  Pending: {counts.get('pending', 0)}")
    print(f"  Running: {counts.get('running', 0)}")
    print(f"  Done: {counts.get('done', 0)}")
    print(f"  Total: {counts['total']}")
    print()
    
    # Write status
    write_status(status_file, agent_name, counts)
    
    # Commit status file if changed
    run_cmd(f"git add {status_file.name}", cwd=queue_dir, check=False)
    run_cmd(f'git commit -m "Update {agent_name} heartbeat status"', cwd=queue_dir, check=False)
    run_cmd("git push origin main", cwd=queue_dir, check=False)
    
    print("Heartbeat complete ✓")


if __name__ == "__main__":
    main()
