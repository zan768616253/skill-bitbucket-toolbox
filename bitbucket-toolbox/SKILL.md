---
name: bitbucket-toolbox
version: "1.0.0"
description: "Bitbucket Cloud wrapper optimized for Pull Request Code Analysis. Enables the agent to securely review Pull Requests, split large diffs by file, review code structure, and read specific repository files. Ideal for providing automated code reviews or debugging PRs."
author: Eric Wang
license: MIT
homepage: "https://github.com/zan768616253/skill-bitbucket-toolbox"
files: ["bb-cli.sh"]
capabilities:
  - id: bitbucket-pr-review
    description: "Review and analyze Bitbucket Cloud Pull Requests including diffs, comments, and commits"
  - id: bitbucket-repo-browse
    description: "Browse Bitbucket Cloud repositories, branches, files, and directory listings"
metadata:
  clawdbot:
    emoji: "🛠️"
    requires:
      env: ["BITBUCKET_API_TOKEN", "BITBUCKET_WORKSPACE"]
      bins: ["curl", "python3"]
---

# Bitbucket PR Code Reviewer Skill

This skill provides the AI agent with read-only access to Bitbucket Cloud via a bash wrapper script (`bb-cli.sh`). It is **heavily optimized for Pull Request analysis**—allowing agents to securely investigate PR diffs, review file changes one-by-one, and provide comprehensive code reviews without overflowing their context window.

### ⚠️ Critical Rules for the Agent
1. **Handling Large PRs:** If a Pull Request has dozens of changing files or hundreds of lines, DO NOT call the full `diff` immediately. **ALWAYS call `diffstat` first.** Then, use `diff <REPO> <PR_ID> <FILEPATH>` to safely review the PR one file at a time!
2. **Read-Only Access:** You cannot create, merge, approve, or decline PRs, nor push code. Do not attempt any write operations.
3. **Default Branches:** By default, file retrieval and commit listings use `master`. Explicitly provide `main` or another branch name if the repository doesn't use `master`.

---

## Setup & Configuration

To use this skill, ensure the following environment variables are present in your workspace:
- `BITBUCKET_API_TOKEN` — A strictly scoped token with **Repositories: Read** and **Pull requests: Read** only.
- `BITBUCKET_WORKSPACE` — The workspace slug from the Bitbucket URL (e.g., `dbvisitsoftware`).

*Note: The script is located at `{baseDir}/bb-cli.sh`. Ensure it has execute permissions (`chmod +x {baseDir}/bb-cli.sh`). `{baseDir}` resolves to the directory containing this SKILL.md file.*

---

## Available Commands

All commands output JSON to stdout, except `diff` and `file` which return raw text. 

### Pull Requests (Primary Focus)

**List pull requests**
```bash
{baseDir}/bb-cli.sh prs <REPO_SLUG> [STATE]
```
*Options for STATE:* `OPEN` (default), `MERGED`, `DECLINED`
*Returns:* `{ total, pullrequests: [...] }`

**Get PR details**
```bash
{baseDir}/bb-cli.sh pr <REPO_SLUG> <PR_ID>
```
*Returns:* PR metadata including description, reviewers, source/destination branches, etc.

**Get PR comments** (contains both general and inline comments)
```bash
{baseDir}/bb-cli.sh comments <REPO_SLUG> <PR_ID>
```
*Returns:* `{ count, comments: [{ id, author, content, inline:{path, from, to}, created }] }`

**List commits in a PR**
```bash
{baseDir}/bb-cli.sh pr-commits <REPO_SLUG> <PR_ID>
```
*Returns:* `[{ hash, message, author, date }]`

### Code Changes & Diffs

**Get PR diffstat (Summary of changed files) - ALWAYS RUN THIS FIRST**
```bash
{baseDir}/bb-cli.sh diffstat <REPO_SLUG> <PR_ID>
```
*Returns:* `{ files_changed, total_added, total_removed, files: [{ path, status, lines_added, lines_removed }] }`

**Get PR diff (Full or Specific File)**
```bash
{baseDir}/bb-cli.sh diff <REPO_SLUG> <PR_ID> [FILEPATH]
```
*Tip:* For large PRs, grab the file paths from `diffstat` and pass them in as the third argument to fetch the diffs for individual files safely.
*Returns:* Raw unified diff text.

### Repositories, Branches & Source Code

**List all repositories**
```bash
{baseDir}/bb-cli.sh repos
```
*Returns:* `[{ slug, name, full_name, language, updated, is_private, url }]`

**List branches in a repository** (can optionally filter by name)
```bash
{baseDir}/bb-cli.sh branches <REPO_SLUG> [FILTER]
```
*Returns:* `[{ name, hash, date, author }]`

**List recent commits on a branch**
```bash
{baseDir}/bb-cli.sh commits <REPO_SLUG> [BRANCH]
```
*Note:* Defaults to `master`. Returns list of commit hashes and messages.

**Read file contents from source tree**
```bash
{baseDir}/bb-cli.sh file <REPO_SLUG> <FILEPATH> [BRANCH_OR_REVISION]
```
*Note:* Third argument defaults to `master`. Returns raw file contents.

**List directory contents**
```bash
{baseDir}/bb-cli.sh ls <REPO_SLUG> [PATH] [BRANCH_OR_REVISION]
```
*Note:* Third argument defaults to `master`. Returns: `[{ path, type, size }]`

---

## External Endpoints

This skill makes **HTTPS GET requests** to the following endpoint only:

| Endpoint | Data Sent | Purpose |
|---|---|---|
| `https://api.bitbucket.org/2.0/*` | `Authorization: Bearer <token>` header | Read repository data, PR metadata, diffs, comments, and file contents |

No data is POST-ed, PUT, or DELETE-d. The token is sent exclusively via the `Authorization` header over HTTPS.

---

## Security & Privacy

- **Read-only access:** This skill cannot modify any data in Bitbucket. It uses only GET requests.
- **Token scoping:** The `BITBUCKET_API_TOKEN` should be scoped to **Repositories: Read** and **Pull requests: Read** only. Do not use tokens with write permissions.
- **Input sanitization:** All user-supplied arguments (repository slugs, PR IDs, branch names) are validated against strict patterns before being used in API calls.
- **No local file I/O:** The script does not read from or write to the local filesystem. All output goes to stdout/stderr.
- **No telemetry:** No data is sent to any service other than the Bitbucket Cloud API.

---

## Trust Statement

This skill is open-source and available for inspection at [github.com/zan768616253/skill-bitbucket-toolbox](https://github.com/zan768616253/skill-bitbucket-toolbox). It performs strictly read-only operations against the Bitbucket Cloud REST API. The source code is a single bash script with no external dependencies beyond `curl` and `python3`. All API interactions use HTTPS and Bearer token authentication. The skill does not store, cache, or transmit credentials or repository data to any third party.
