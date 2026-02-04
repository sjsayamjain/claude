# Search Web — Find relevant information

When invoked, perform the following steps:

1. **Interpret `$ARGUMENTS`** as a search query.
2. **Search the web** using that query.
3. **Provide a concise summary** of the most relevant information that directly addresses the query.
4. **Include key findings** as bullet points—highlight the most important data or insights.
5. **List relevant links** (titles only, not raw URLs) where the user can read more.

If `$ARGUMENTS` is empty, respond:

> “What would you like me to search the web for?”

Make sure to focus strictly on the query and avoid extraneous context.
