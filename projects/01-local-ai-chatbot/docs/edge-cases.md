# Edge cases and limitations

| Scenario | Current behavior | Portfolio implication |
| --- | --- | --- |
| Ollama is unavailable | The model call cannot return a response. | No fallback or retry is documented. |
| Model gives an incorrect answer | The response is returned as generated. | There is no validation or human-review path. |
| Repeated question | Each message is handled independently. | There is no long-term memory. |
| Sensitive prompt | The workflow does not classify or redact content. | Users must provide only synthetic, safe input. |
| Large or abusive request volume | No rate limit is shown in the export. | Not suitable for public exposure. |

Future improvements could add memory, retrieval-augmented generation, prompt
limits, error handling, logging, and evaluation fixtures.
