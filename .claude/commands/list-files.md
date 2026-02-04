# list:files — List project files matching filter criteria

When invoked, perform the following:

1. **Read `$ARGUMENTS`** as filter criteria. This can include:
   - Filename patterns (extensions or substrings), e.g., `*.js`, `README`, `.html`
   - Directory names, e.g., `src`, `tests`
   - Regex or combinations using quotes

2. **Construct and run a command**:
   - If `$ARGUMENTS` includes `tree`, run:
     ```
     tree -L 2
     ```
     (Limit depth to 2 levels for brevity.)
   - Else, run:
     ```
     find . -type f -name "$ARGUMENTS"
     ```
     For broader filtering (e.g., multiple patterns), you could:
     ```
     find . -type f \( -name "*.js" -o -name "*.ts" \)
     ```
   - Optionally pipe into `grep` for extra filtering:
     ```
     | grep -i "service"
     ```

3. **Report back results**:
   - Provide a concise summary: number of matches, key directories represented, etc.
   - Include a bullet list of the top 10–20 relevant paths.
   - If no matches found, ask user to refine the filter.

4. **Optional enhancement**:
   - If `$ARGUMENTS` is missing, prompt:
     > “What file patterns or criteria would you like to search for? For example: `*.py`, `src/`, `README`.”


Example usage:
/list:files *.js
/list:files src/
/list:files tree