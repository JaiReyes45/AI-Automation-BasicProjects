# Architecture

```mermaid
flowchart LR
  Browser[Flutter web] --> Web[nginx localhost:8087]
  Web --> Profile[Private profile service]
  Profile --> Folder[Ignored local profile folder / SQLite and files]
  User[Local operator] --> N8N[n8n localhost:5678]
  N8N --> Postgres[PostgreSQL: n8n state]
  N8N --> Engine[Private synthetic workflow engine]
  Engine --> SQLite[Persistent synthetic SQLite store]
```

Application editing remains in browser memory. The Flutter CRM is not yet connected to the workflow engine. Gmail OAuth and live labels remain pending. Profile files are stored separately from application data.
