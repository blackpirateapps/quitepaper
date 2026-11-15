# AI Agent Workflow Guidelines for Quiet Paper

When completing any task, bugfix, or feature in this repository, always follow this workflow:

1. **Verify Quality**:
   - Run static analysis: `flutter analyze`
   - Run only tests relevant to the change: `flutter test <relevant test files or directories>`.
   - Do not run the full test suite unless the user explicitly requests it.
   - Ensure static analysis and the relevant tests pass with zero warnings or errors.

2. **Update Documentation**:
   - Update `HANDOFF.md` with details of any architectural changes, bug fixes, UI adjustments, or new features.

3. **Commit & Push**:
   - Stage changes: `git add .`
   - Commit with a clear, conventional commit message describing the changes.
   - Push to remote: `git push origin main` (or the active branch).
