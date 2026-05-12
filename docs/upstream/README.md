---
summary: How the Windows fork watches OpenClaw Peekaboo for upstream changes worth reviewing or porting.
read_when:
  - Reviewing upstream OpenClaw Peekaboo changes.
  - Deciding whether upstream macOS features should be ported to Windows.
---

# Upstream Watch

This fork tracks `openclaw/Peekaboo` with a scheduled GitHub Actions workflow.
The workflow is intentionally non-invasive: it does not merge, cherry-pick, or
edit product code. It only opens or updates one tracking issue when upstream
changes appear after the last reviewed upstream commit.

The review checkpoint lives in:

```text
docs/upstream/last-reviewed-upstream.txt
```

When the watch issue appears, review the generated buckets in this order:

1. `windows-direct`
2. `shared-contract-or-cli`
3. `mac-source-reference`
4. `docs-release`
5. `ci-tooling`
6. `other`

After reviewing or porting the useful changes, update
`last-reviewed-upstream.txt` to the latest upstream SHA listed in the issue.
