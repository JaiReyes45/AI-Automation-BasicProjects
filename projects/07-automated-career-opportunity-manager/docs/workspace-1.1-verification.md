# Workspace 1.1 verification — October 26, 2026

- Flutter analysis: clean. 27 widget/regression tests pass, including inclusive date filtering, newest/oldest sorting, unknown dates last, description search, journey stage navigation and linked email text.
- Layout checks: 375 px, landscape and desktop, 2× text and reduced motion. Real browser inspection confirmed the desktop journey, company search, received-email controls and mobile profile menu/tabs.
- Production web build succeeds. Post-build font fingerprinting fixes old browser icon subsets after deployment; a normal reload was verified to render the new icons.
- 38 existing parser/engine tests pass. Four CRM suites pass, including rollback-only tests of original Manila submission date, reviewed actions, stale versions/leases, account isolation, duplicate confirmation, uncertain-send protection and calendar collisions.
- Isolated profile test passes upload, normalized JPEG size, invalid-image rejection, documents/Drive links and restart persistence. No real profile data was replaced by the test.
- Calendar credential and bounded event import succeeded. Workflows 06, 07, 08 and 09 are active in local n8n. Both new worker live checks had empty queues: no test reply or invitation was sent.
- Local Qwen3 4B returned the verified five-application count after bounding long Calendar data. A warm query completed in 1.8 seconds. The initial cold load timed out; do not treat warm timing as a guarantee. Browser chat completed after deployment with the response panel rendered.
- Runtime screenshots remain private under `.runtime`; no personal profile/email/calendar screenshot is included in public source.

See `backup-verification.json` for the final isolated restore counts. The public release contains source/build assets only, not the private backup. Live reply/meeting creation still needs readback during the first intentional user action; genuine employer follow-up progression remains a field-acceptance item.
