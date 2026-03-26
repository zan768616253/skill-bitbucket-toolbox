# 🛠️ Bitbucket Toolbox — OpenClaw Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ClawHub](https://img.shields.io/badge/ClawHub-bitbucket--toolbox-orange)](https://clawhub.ai/skills/bitbucket-toolbox)

An [OpenClaw](https://openclaw.ai) skill that gives AI agents **read-only access to Bitbucket Cloud**, optimized for **Pull Request code review**.

The agent can safely review large PRs by splitting diffs file-by-file, inspect code changes, read comments, browse repository contents, and generate comprehensive code review reports — all without overflowing its context window.

---

## Features

| Capability | Commands |
|---|---|
| **PR Analysis** | `prs`, `pr`, `diffstat`, `diff`, `comments`, `pr-commits` |
| **Repo Browsing** | `repos`, `branches`, `commits`, `file`, `ls` |

**Key Design Decisions:**
- 🔒 **Read-only** — Cannot modify anything in Bitbucket (no approvals, merges, or pushes)
- 📄 **Diff splitting** — Large PRs are reviewed one file at a time via `diffstat` → `diff <REPO> <PR_ID> <FILEPATH>`
- 🛡️ **Input sanitization** — All user inputs are validated before being used in API calls
- 📊 **Structured JSON output** — All commands return properly formatted JSON for downstream processing

---

## Quick Start

### 1. Install the skill

```bash
# Via ClawHub
clawhub install bitbucket-toolbox

# Or manually: clone and add to your OpenClaw skills directory
git clone https://github.com/zan768616253/skill-bitbucket-toolbox.git
cp -r skill-bitbucket-toolbox/bitbucket-toolbox ~/.openclaw/skills/
```

### 2. Set environment variables

```bash
export BITBUCKET_API_TOKEN="your-app-password-or-token"
export BITBUCKET_WORKSPACE="your-workspace-slug"
```

> **Token scoping:** Create a Bitbucket App Password with only **Repositories: Read** and **Pull requests: Read** permissions. Never grant write access.

### 3. Make the script executable

```bash
chmod +x ~/.openclaw/skills/bitbucket-toolbox/bb-cli.sh
```

### 4. Use it

Ask your AI agent to review a PR:
```
Review PR #42 in the my-app repository
```

Or use the CLI directly:
```bash
./bb-cli.sh diffstat my-app 42
./bb-cli.sh diff my-app 42 src/main.py
./bb-cli.sh comments my-app 42
```

---

## Command Reference

| Command | Arguments | Description |
|---|---|---|
| `repos` | — | List all repositories in the workspace |
| `prs` | `REPO [STATE]` | List pull requests (`OPEN`/`MERGED`/`DECLINED`) |
| `pr` | `REPO PR_ID` | Get detailed PR metadata |
| `diffstat` | `REPO PR_ID` | Summary of changed files (always run first!) |
| `diff` | `REPO PR_ID [FILEPATH]` | Full diff or diff for a single file |
| `comments` | `REPO PR_ID` | PR comments (inline + general) |
| `pr-commits` | `REPO PR_ID` | List commits in a PR |
| `branches` | `REPO [FILTER]` | List branches, optionally filtered |
| `commits` | `REPO [BRANCH]` | Recent commits on a branch |
| `file` | `REPO FILEPATH [REV]` | Read file contents |
| `ls` | `REPO [PATH] [REV]` | List directory contents |

---

## Requirements

- **curl** — HTTP client
- **python3** — JSON processing
- **Bitbucket Cloud account** — With API access configured

---

## Security

- All operations are **read-only** (GET requests only)
- The API token is sent exclusively via the `Authorization` header over HTTPS
- User inputs (repo slugs, PR IDs, branch names) are validated against strict regex patterns
- No local files are read or written; no telemetry is collected
- Full security details in [SKILL.md](bitbucket-toolbox/SKILL.md)

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Author

**Eric Wang** — [GitHub](https://github.com/zan768616253)
