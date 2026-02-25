# Agent-to-Agent Coordination Patterns

**Research Task:** Survey multi-agent frameworks and document key coordination patterns.
**Completed by:** Jean
**Date:** 2026-02-25

---

## Executive Summary

Multi-agent AI systems require coordination patterns to manage task distribution, communication, and state. After surveying AutoGen (Microsoft), CrewAI, LangGraph, and our own implementation, five key patterns emerge that enable effective agent collaboration.

---

## Frameworks Surveyed

### 1. AutoGen (Microsoft)
- **Focus:** Multi-agent conversations with minimal orchestration
- **Key Concept:** Conversable agents that can chat with each other
- **Strengths:** Flexible conversation patterns, human-in-the-loop support
- **Architecture:** Peer-to-peer agent conversations

### 2. CrewAI
- **Focus:** Role-based agent teams (Crews) within structured Flows
- **Key Concept:** Flows (state management) + Crews (autonomous teams)
- **Strengths:** Clear separation of control flow and autonomous work
- **Architecture:** Hierarchical (Flow → Crew → Agents)

### 3. LangGraph
- **Focus:** Graph-based agent workflows with explicit state
- **Key Concept:** Nodes (agents) + Edges (transitions) + State
- **Strengths:** Visual workflow definition, conditional branching
- **Architecture:** Directed graph with state machine semantics

---

## 5 Key Coordination Patterns

### Pattern 1: **Supervisor-Worker**

```
┌──────────────┐
│  Supervisor  │ ← Assigns tasks, reviews results
└──────┬───────┘
       │
  ┌────┴────┐
  ▼         ▼
┌─────┐   ┌─────┐
│Worker│   │Worker│ ← Execute specific tasks
└─────┘   └─────┘
```

**Description:** A supervisor agent decomposes complex tasks and delegates to specialized workers. Workers report results back for aggregation.

**When to Use:**
- Complex tasks requiring multiple specialized skills
- Need for quality control and result aggregation
- Clear hierarchy of responsibility

**Implementation:**
- CrewAI: Flow delegates to Crew
- AutoGen: UserProxyAgent coordinates AssistantAgents
- Our system: Orchestrator creates tasks, workers claim them

**Example:** Research task → Supervisor breaks into (search, synthesize, document) → Workers execute → Supervisor assembles final output.

---

### Pattern 2: **Peer-to-Peer Conversation**

```
┌─────┐ ←──────→ ┌─────┐
│Agent│          │Agent│
│  A  │ ←──────→ │  B  │
└─────┘          └─────┘
    ↖              ↗
      ↘          ↙
       ┌─────┐
       │Agent│
       │  C  │
       └─────┘
```

**Description:** Agents communicate directly without central coordination. Each agent can initiate conversations with any other.

**When to Use:**
- Collaborative problem-solving
- Brainstorming and debate
- When agents have complementary expertise

**Implementation:**
- AutoGen: `initiate_chat()` between any two agents
- Our system: Agents can create tasks for each other directly

**Example:** Jean and Jared debugging together — each can ask the other questions, share findings, and build on each other's work.

---

### Pattern 3: **Task Queue with Claiming**

```
┌─────────────────┐
│   Task Queue    │ ← Shared state (Git, DB, Redis)
│ [T1] [T2] [T3]  │
└───────┬─────────┘
        │
   ┌────┴────┐
   ▼         ▼
┌─────┐   ┌─────┐
│Jean │   │Jared│ ← Agents claim and execute
└─────┘   └─────┘
```

**Description:** Tasks are added to a shared queue. Agents independently claim tasks they can handle, execute them, and mark complete.

**When to Use:**
- Async coordination (agents may be offline)
- Load balancing across agents
- Audit trail and task tracking
- Cross-machine coordination

**Implementation:**
- Our system: Git-backed queue with JSON task files
- Also: Redis, PostgreSQL, or any shared data store
- Claim operation must be atomic to prevent double-claiming

**Key Requirements:**
1. Atomic claim operation (Git commit, DB transaction)
2. Task status tracking (pending → claimed → running → done)
3. Agent identification (who claimed what)
4. Result storage

**Example:** This document was created via task queue — Jared added task, Jean claimed and executed.

---

### Pattern 4: **Event-Driven / Pub-Sub**

```
┌─────────────┐
│ Event Bus   │ ← Central message broker
└──────┬──────┘
       │
  ┌────┼────┐
  ▼    ▼    ▼
┌───┐ ┌───┐ ┌───┐
│ A │ │ B │ │ C │ ← Agents subscribe to relevant events
└───┘ └───┘ └───┘
```

**Description:** Agents publish events and subscribe to events they care about. Loose coupling — agents don't need to know about each other.

**When to Use:**
- Many agents with different responsibilities
- Agents should react to system events
- Decoupled, scalable architecture

**Implementation:**
- Redis Pub/Sub
- Message queues (RabbitMQ, SQS)
- Webhooks
- Our REST API with polling

**Example:** Email arrives → "new_email" event → Email agent processes → "email_triaged" event → Calendar agent checks for meeting requests.

---

### Pattern 5: **State Machine / Flow**

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│ START   │────→│ RESEARCH │────→│ REVIEW  │
└─────────┘     └─────────┘     └────┬────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                                 ▼
              ┌─────────┐                      ┌─────────┐
              │ APPROVE │                      │ REVISE  │
              └─────────┘                      └────┬────┘
                                                    │
                                                    ↓
                                              (back to RESEARCH)
```

**Description:** Workflow defined as states with explicit transitions. Each state may involve different agents or actions.

**When to Use:**
- Well-defined multi-step processes
- Need for explicit approval gates
- Complex conditional logic
- Audit/compliance requirements

**Implementation:**
- CrewAI Flows
- LangGraph graphs
- State machines with agent handlers

**Example:** Content pipeline: Draft → Review → Revise → Publish, with different agents handling each stage.

---

## Recommendations for Our System

### Current Implementation (Task Queue)
✅ Works well for async, cross-machine coordination
✅ Git provides atomic operations and audit trail
✅ Simple to understand and debug

### Suggested Enhancements

1. **Add Event Layer**
   - REST API already supports agent heartbeats
   - Add webhook notifications when tasks are created/completed
   - Enables faster response than polling

2. **Task Dependencies**
   - Add `depends_on` field to task schema
   - Don't start task until dependencies complete
   - Enables complex workflows

3. **Agent Capabilities Registry**
   - Track what each agent can do (task types, tools available)
   - Smart routing: assign tasks to capable agents
   - Load balancing based on current agent load

4. **Conversation Threads**
   - Link related tasks into threads
   - Preserve context across task handoffs
   - Enable peer-to-peer discussion within a task

### Hybrid Approach

Best results come from combining patterns:

```
┌─────────────────────────────────────────────────────┐
│                    ORCHESTRATOR                     │
│  (State Machine / Flow - manages overall process)   │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐     ┌──────────────────┐
│   TASK QUEUE     │     │   EVENT BUS      │
│  (Async work)    │     │  (Real-time)     │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
    ┌────┴────┐              ┌────┴────┐
    ▼         ▼              ▼         ▼
 ┌─────┐   ┌─────┐       ┌─────┐   ┌─────┐
 │Jean │   │Jared│       │Jean │   │Jared│
 └─────┘   └─────┘       └─────┘   └─────┘
```

---

## Conclusion

Multi-agent coordination requires matching the pattern to the use case:

| Use Case | Best Pattern |
|----------|--------------|
| Complex task decomposition | Supervisor-Worker |
| Collaborative problem-solving | Peer-to-Peer |
| Async, cross-machine work | Task Queue |
| Reactive, event-driven | Pub-Sub |
| Multi-step workflows | State Machine |

Our Git-based task queue is a solid foundation. Adding event notifications and task dependencies would enable more sophisticated coordination without losing the simplicity and auditability we have now.

---

*Research completed in ~5 minutes. Sources: AutoGen docs, CrewAI docs, direct implementation experience.*
