# Workflow operation

## Normal interaction

1. Open the n8n chat interface for the imported workflow.
2. Submit a non-sensitive text message.
3. The Chat Trigger emits the message to the Basic LLM Chain.
4. The chain calls the local Ollama Chat Model.
5. n8n returns the model response to the chat interface.

## Safe review procedure

Import [the sanitized workflow export](../workflows/basic-local-ai-chatbot.json)
into a disposable local n8n instance. Review the Ollama model settings before
activating it. The export is currently marked active, so set it inactive during
review if it should not accept requests.

Use only synthetic prompts. Do not enter passwords, private documents, or
customer information into the chat.
