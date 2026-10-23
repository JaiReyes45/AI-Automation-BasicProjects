# Profile and documents — local storage

Open http://localhost:8087 and select Profile. Save personal details, school/course, year, hours, availability, notes, LinkedIn, GitHub, portfolio and school Drive folder links. Upload PDF, DOCX, PNG or JPG documents (8 MB maximum) under a requirement name, or save an HTTPS link. Download/open controls appear for saved documents. Multiple versions can coexist; deletion and version management are deferred.

## Storage

The profile service is internal to Docker and proxied by nginx at /api. Data persists in the portfolio project folder:

`/home/guienne_jairo_reyes/code/AI-Automation-BasicProjects/projects/07-automated-career-opportunity-manager/local-data/profile/`

`profile.sqlite` holds profile/document metadata; `files/` holds uploads under generated IDs. This folder is ignored by Git and excluded from image builds. It is plain local storage, not encrypted or a backup. Back up the entire folder while the profile container is stopped. Never delete it during rebuilds. The browser can download stored documents individually.

The web port stays bound to 127.0.0.1:8087. There is no user-login layer; this deployment is for a trusted single-user device and must not be exposed publicly. Host validation and custom request headers protect against cross-origin browser writes. Google Drive links do not authorize an account, sync files, or change sharing permissions.

Application CRM records remain session-only; this profile store does not complete D3.1's shared application/workflow database integration.

## Verification

Nine existing Flutter tests and three profile tests passed, covering phone 375x812, landscape 844x390, desktop 1440x1000, and link validation. Static analysis passed before the profile test was added. Release web build succeeded. Python storage check covers profile round-trip, request-header rejection, unsafe links, upload/download, external document links, blocked extensions, and persistence after a server restart. Fixed connection closure discovered during Windows cleanup. Browser screenshots record deployed desktop/mobile profile layout.

Run `python tests/profile_storage_check.py` for synthetic temporary storage checks; it does not modify the live profile folder.
