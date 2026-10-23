# D1.2 — Interactive CRM verification

October 23, 2026. Local preview scope only.

## Delivered

- Applications screen with case-insensitive company/role/source search, combined role and stage filters, result counts, and clear-filter/no-match states.
- Add and edit forms with required company/role/source validation and length limits. Cancel discards pending edits.
- Application details with stage, independent next action, and history displayed in Manila time.
- Stable application IDs keep two roles at one company separate. Manual stage, identity, and next-action edits append history; unchanged saves do not add events.
- Session repository returns immutable lists. Dashboard and Activity reflect saved edits when returning from details.
- Preview and Gmail-disconnected notices remain explicit. Refresh resets changes.

## Evidence

- Flutter tests: 9 passed (six existing checks plus creation/validation/combined-filter/stage/history/role-isolation flow and two responsive cancellation tests).
- Static analysis: no issues after four style fixes.
- Release web build succeeded with locally hosted renderer assets.
- Impeccable detector returned no findings; Dart coverage is limited, so rendered screens were also inspected.
- Browser: opened Applications, inspected accessible controls, saved Browser Test Labs / IT Intern, and confirmed its details and manual creation history.
- Desktop 1440x1000 application list and mobile 390x844 form/details inspected without clipping.
- Screenshots: d1-2-desktop.png, d1-2-mobile-form.png, d1-2-mobile-detail.png. Captured before the final top-banner wording improvement; functionality/layout unchanged.
- Docker Compose configuration validated; only Project 07 web was rebuilt. No workflow credentials or volumes changed.

## Limits and next milestone

Records are browser-memory previews, not persisted browser storage or backend records. Closing/reloading the page discards edits. No real Gmail connection, attachments, deadlines, or durable task completion is implemented. The workflow engine remains separate.

Next: D3.1 shared application database and frontend integration. Stop at D1.2 for review.
