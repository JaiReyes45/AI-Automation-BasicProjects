# Failure and recovery

This prototype does not implement a durable recovery design. If the model or
n8n is unavailable, the practical recovery is to restore the local service and
submit the message again.

There is currently no outbox, retry counter, dead-letter queue, correlation ID,
or persisted conversation state. That limitation is deliberate to document: it
separates this learning project from the reliability controls demonstrated by
the Helpdesk project.

Before expanding this workflow, add a defined timeout, bounded retries, safe
error responses, and logs that do not retain private prompt content.
