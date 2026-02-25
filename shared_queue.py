#!/usr/bin/env python3
"""
Git-backed Shared Agent Queue

Cross-machine task queue using a Git repo as the sync layer.
Tasks are stored as JSON files in a shared repo.

Usage:
  shared_queue.py init <repo_url>
  shared_queue.py add <title> [--desc=<desc>] [--type=<type>] [--for=<agent>]
  shared_queue.py list [--status=<status>]
  shared_queue.py claim <task_id> [--agent=<agent>]
  shared_queue.py complete <task_id> [--result=<result>]
  shared_queue.py sync
"""

import json
import os
import sys
import subprocess
from datetime import datetime
from pathlib import Path
import uuid

QUEUE_DIR = Path(os.environ.get('SHARED_QUEUE_DIR', '/data/shared-queue'))
TASKS_DIR = QUEUE_DIR / 'tasks'
MY_AGENT = os.environ.get('AGENT_NAME', 'jean')

def run_git(cmd, cwd=QUEUE_DIR):
    """Run a git command in the queue directory."""
    result = subprocess.run(
        ['git'] + cmd,
        cwd=cwd,
        capture_output=True,
        text=True
    )
    return result.returncode == 0, result.stdout, result.stderr

def sync():
    """Pull latest and push any local changes."""
    run_git(['pull', '--rebase', 'origin', 'main'])
    run_git(['push', 'origin', 'main'])

def init_repo(repo_url):
    """Clone or init the shared queue repo."""
    if QUEUE_DIR.exists():
        print(f"Queue dir exists at {QUEUE_DIR}, pulling...")
        sync()
    else:
        subprocess.run(['git', 'clone', repo_url, str(QUEUE_DIR)])
        TASKS_DIR.mkdir(exist_ok=True)
        (QUEUE_DIR / '.gitkeep').touch()
        run_git(['add', '.'])
        run_git(['commit', '-m', 'Init shared queue'])
        run_git(['push', 'origin', 'main'])
    print(f"Shared queue ready at {QUEUE_DIR}")

def add_task(title, desc=None, task_type='general', for_agent='any'):
    """Add a new task to the queue."""
    sync()
    
    task_id = datetime.now().strftime('%Y%m%d%H%M%S') + '-' + uuid.uuid4().hex[:8]
    task = {
        'id': task_id,
        'title': title,
        'description': desc,
        'type': task_type,
        'for_agent': for_agent,
        'status': 'pending',
        'created_at': datetime.now().isoformat(),
        'created_by': MY_AGENT,
        'claimed_by': None,
        'claimed_at': None,
        'completed_at': None,
        'result': None
    }
    
    TASKS_DIR.mkdir(exist_ok=True)
    task_file = TASKS_DIR / f'{task_id}.json'
    task_file.write_text(json.dumps(task, indent=2))
    
    run_git(['add', str(task_file)])
    run_git(['commit', '-m', f'Add task: {title}'])
    run_git(['push', 'origin', 'main'])
    
    print(json.dumps({'id': task_id, 'title': title, 'status': 'pending'}))

def list_tasks(status=None):
    """List tasks from the queue."""
    sync()
    
    tasks = []
    if TASKS_DIR.exists():
        for f in TASKS_DIR.glob('*.json'):
            task = json.loads(f.read_text())
            if status is None or task['status'] == status:
                tasks.append(task)
    
    tasks.sort(key=lambda t: (t['status'] != 'pending', t['created_at']))
    print(json.dumps(tasks, indent=2))

def claim_task(task_id, agent=None):
    """Claim a task."""
    sync()
    agent = agent or MY_AGENT
    
    task_file = TASKS_DIR / f'{task_id}.json'
    if not task_file.exists():
        print(json.dumps({'error': f'Task {task_id} not found'}))
        return
    
    task = json.loads(task_file.read_text())
    if task['status'] != 'pending':
        print(json.dumps({'error': f'Task already {task["status"]}'}))
        return
    
    task['status'] = 'running'
    task['claimed_by'] = agent
    task['claimed_at'] = datetime.now().isoformat()
    task_file.write_text(json.dumps(task, indent=2))
    
    run_git(['add', str(task_file)])
    run_git(['commit', '-m', f'{agent} claimed: {task["title"]}'])
    run_git(['push', 'origin', 'main'])
    
    print(json.dumps(task))

def complete_task(task_id, result=None):
    """Mark a task as complete."""
    sync()
    
    task_file = TASKS_DIR / f'{task_id}.json'
    if not task_file.exists():
        print(json.dumps({'error': f'Task {task_id} not found'}))
        return
    
    task = json.loads(task_file.read_text())
    task['status'] = 'done'
    task['completed_at'] = datetime.now().isoformat()
    task['result'] = result
    task_file.write_text(json.dumps(task, indent=2))
    
    run_git(['add', str(task_file)])
    run_git(['commit', '-m', f'Completed: {task["title"]}'])
    run_git(['push', 'origin', 'main'])
    
    print(json.dumps(task))

if __name__ == '__main__':
    args = sys.argv[1:]
    
    if not args or args[0] == 'help':
        print(__doc__)
        sys.exit(0)
    
    cmd = args[0]
    
    if cmd == 'init' and len(args) > 1:
        init_repo(args[1])
    elif cmd == 'add' and len(args) > 1:
        title = args[1]
        desc = next((a.split('=')[1] for a in args if a.startswith('--desc=')), None)
        task_type = next((a.split('=')[1] for a in args if a.startswith('--type=')), 'general')
        for_agent = next((a.split('=')[1] for a in args if a.startswith('--for=')), 'any')
        add_task(title, desc, task_type, for_agent)
    elif cmd == 'list':
        status = next((a.split('=')[1] for a in args if a.startswith('--status=')), None)
        list_tasks(status)
    elif cmd == 'claim' and len(args) > 1:
        task_id = args[1]
        agent = next((a.split('=')[1] for a in args if a.startswith('--agent=')), None)
        claim_task(task_id, agent)
    elif cmd == 'complete' and len(args) > 1:
        task_id = args[1]
        result = next((a.split('=')[1] for a in args if a.startswith('--result=')), None)
        complete_task(task_id, result)
    elif cmd == 'sync':
        sync()
        print("Synced")
    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)
        sys.exit(1)
