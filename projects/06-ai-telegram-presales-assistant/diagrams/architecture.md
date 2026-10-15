# Architecture

```mermaid
flowchart LR
    T[Telegram] --> H[Public HTTPS tunnel]
    H --> A[01 authenticated intake]
    A --> P[02 atomic persistence]
    P --> I[(PostgreSQL inbox)]
    P -. durable receipt acknowledgement .-> T
    I --> O[00 scheduled decision worker]
    O --> X[03 preflight and extraction]
    X <--> L[Local Ollama]
    X --> K[04 approved catalog]
    K --> D[05 contextual discovery]
    D --> E[06 deterministic estimate]
    E --> Q[07 qualification]
    Q --> R[08 handoff decision]
    R --> C[Atomic decision commit]
    C --> S[(State and audit)]
    C --> B[(PostgreSQL outbox)]
    B --> W[09 scheduled delivery worker]
    W --> T
    U[10-12 manual operator views] --- S
```

Intake acknowledgement is separate from a completed AI decision or sent reply.
Commands and clear pending-question answers skip AI; open-ended messages receive
strict extraction validation. Code controls questions, estimates, and scoring.
An outbox preserves delivery ordering and quarantines uncertain sends for review.

See [architecture and lifecycle](../docs/architecture-lifecycle.md) for workflow
responsibilities and [database guide](../docs/database-guide.md) for the transaction
and lease protocol. This diagram does not imply a full live sales journey has
passed acceptance testing.
