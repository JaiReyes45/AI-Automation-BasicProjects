# Construction CRM — diagram style receipt

Selected by the user on 7 November 2026: use this workspace's existing warm paper, dark ink and construction-orange palette. Source: [DESIGN.md](../../DESIGN.md). This local receipt is the effective style for this architecture; no installed skill or global profile is changed.

| Role | Light value | Provenance |
| --- | --- | --- |
| paper | `#f5f3eb` | Existing project |
| paper-2 | `#fffef9` | Existing project surface |
| ink | `#172c2c` | Existing project |
| ink-strong | `#172c2c` | Existing project |
| muted | `#586966` | Existing project |
| soft | `#586966` | Same readable secondary ink |
| rule | `rgba(23,44,44,0.12)` | Derived decorative rule |
| rule-solid | `#cbd1c7` | Existing project decorative rule |
| accent | `#a94b26` | Existing incident/construction accent |
| accent-tint | `rgba(169,75,38,0.08)` | Derived fill |
| link | `#194d45` | Existing action color used for external paths |

The existing project specifies system sans and monospace, not branded font binaries. Node names use `system-ui, sans-serif` at 12px/600; sublabels, arrows and eyebrows use `ui-monospace, Consolas, monospace` at 9/8/8px. The editorial title uses Georgia/serif as an explicitly disclosed fallback for the diagram skill's Instrument Serif role. The self-contained output has no network font dependency. Use 14px for group headings. Keep chart/node geometry on the 4px grid, at most nine nodes per figure, and no model-generated motion.

Format: one HTML architecture atlas with five accessible inline SVG figures. Each uses the `doc-inline` 960×600 preset, local horizontal scrolling, bottom legend, static rendering and print scaling. Visual types: architecture overview, Build architecture, Operate architecture, hybrid deployment and ER model. The overview and deployment express trust boundaries; the detail views carry dependencies and event flow. Detailed failure behavior remains in the design document rather than squeezing every path into the overview.
