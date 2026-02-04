# check:dependencies — Scan for missing or outdated dependencies

When run, detect the project type and execute appropriate diagnostics:

1. **Detect ecosystem** based on project files:
   - If `package.json` found → run `npm outdated` and `depcheck`
   - If Maven (`pom.xml`) found → run:
     - `mvn versions:display-dependency-updates`
     - `mvn dependency:analyze`
   - If .NET (`*.csproj`) found → run `dotnet package list --outdated`
   - If Rust (`Cargo.toml`) found → run `cargo outdated`

2. **Summarize results** in bullets:
   - Outdated dependencies (with versions)
   - Missing or unused dependencies (where applicable)
   - Any errors encountered or additional context

3. **Suggest next steps**, e.g.:
   - "Run `npm update`, `mvn versions:use-latest-versions`, `dotnet package add`, or `cargo update` as appropriate."
   - Optionally prompt: "Do you want to run updates now (yes/no)?"

If `$ARGUMENTS` is provided (e.g., `--fix` or `--interactive`), pass those flags into the underlying tool (e.g., `ncu -u` in npm). Otherwise, proceed with default checks only.
