# Daily use

## Applications and stages

Open CareerFlow and sign in with the local workspace password. Applications can be searched and filtered by company, role, source and stage. Open a record to edit it. Keep separate company/role applications separate, even when Gmail combines messages into a conversation. Original role titles are retained.

The usual path is submitted → reviewing → information requested → assessment/interview → offer → accepted → hired. Employers may skip stages. Rejected and withdrawn are terminal outcomes; no response or an expired job listing alone is not a rejection. Confirm acceptance or hiring only when supported by evidence.

The open workspace checks saved data every 30 seconds and refreshes when you return to the tab. Gmail intake runs separately every five minutes while Docker is running. Background screen updates pause while you edit a record or profile. You can also use Refresh workspace. If a stale-edit message appears, refresh and review the new record before retrying; the app does not silently overwrite it.

## Review inbox

1. Open **Review inbox**. Needs review, Opportunities and Resolved are separate views.
2. Open a message and read its plain-text evidence. Use Open in Gmail for the original context.
3. Choose link, create, opportunity or dismiss. Link only when the employer and role identify the right application.
4. Linking can keep the existing stage. Select a stage only if the email supports the change. Creating requires a company, role and stage.
5. Add a short reason when helpful, then save. The decision is recorded; Gmail delivery is queued separately.

Older evidence cannot overwrite a newer stage. A stale message can still be linked without changing the stage. Resolved messages are read-only in the review screen; correct application details from Applications. Dismissed review decisions do not delete Gmail messages.

## Actions

Open **Actions** to add an application-specific reply, assessment, interview, follow-up or other task. A due date is optional: leave it blank when the employer gave none. Dates use the Manila calendar; visible email/sync timestamps are also Manila time.

Complete or reopen a task from its controls. This records progress on your work without asserting employer progress. Follow-up suggestions after inactivity are suggestions, not deadlines or rejections. The app does not send replies or calendar invitations.

## Profile and internship documents

Save personal details, LinkedIn/GitHub/portfolio URLs and requirements in Profile. Upload PDF, DOCX, PNG or JPG files up to 8 MB, or save an HTTPS Drive link. Files persist under the Docker project's `local-data/profile` folder. Drive links do not connect the school account or change file permissions. Keep the private backup separate from the public release ZIP.

## Connections and recovery

Connections shows Gmail authorization, whether both schedules are enabled, intake completion, label checks and queue states. An account check alone is not a completed intake. A completion older than 15 minutes needs attention while the device is awake.

If a delivery fails, first fix the reported cause in local n8n (for example reconnect an expired Google credential), then retry the eligible item. Automatic attempts already use backoff. Delivery outside the authorized seven-day window is expired and cannot be retried from the screen. Unrelated Gmail labels remain untouched.

Use Sign out when finished on a shared device. Closing a tab is not sign-out. See the operations guide if a changed workspace password is not accepted.
