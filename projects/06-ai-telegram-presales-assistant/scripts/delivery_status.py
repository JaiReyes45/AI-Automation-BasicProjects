"""Recent delivery timing without customer text, chat identifiers or credentials."""
import subprocess
q="""SELECT j.status AS processing_status,j.attempts,o.status AS reply_status,
round(extract(epoch FROM o.updated_at-j.created_at)::numeric,1) AS seconds_until_delivery,
(o.telegram_message_id IS NOT NULL) AS telegram_receipt
FROM presales.inbox_jobs j LEFT JOIN presales.outbox_jobs o ON o.update_id=j.update_id AND o.job_type='telegram_reply'
ORDER BY j.created_at DESC LIMIT 5;"""
subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d','presales','-v','ON_ERROR_STOP=1'],input=q,text=True,check=True)
