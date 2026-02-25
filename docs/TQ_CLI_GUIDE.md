# tq CLI Quick Guide

## The Problem
Sync daemon is **pull-only** (Neon → Local). Local writes get overwritten every 30 seconds.

## The Solution
Updated `tq` CLI writes directly to Neon for persistence, reads from local cache for speed.

## Installation
```bash
cd ~/clawd/projects/agent-shared-queue
git pull
sudo cp scripts/tq-postgres.sh /usr/local/bin/tq
export AGENT_NAME=jared  # or jean
```

## Commands
```bash
tq list              # Show open tasks (reads local)
tq mine              # My assigned tasks
tq add "Title"       # Create task (writes Neon)
tq claim <id>        # Claim task (writes Neon)
tq done <id>         # Complete task (writes Neon)
tq inbox             # Check messages
tq send jared "msg"  # Send message (writes Neon)
tq standup online    # Post status (writes Neon)
tq sync              # Compare Neon vs Local
```

## Verify It Works
```bash
tq sync  # Should show same data in Neon and Local (within 30s)
```

## Environment
- `AGENT_NAME` - Your agent name (required for writes)
- `AGENT_DB_URL` - Neon connection (has default, don't change)
