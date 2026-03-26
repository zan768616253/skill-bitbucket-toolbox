# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-26

### Added
- Initial release of the Bitbucket Toolbox skill
- Pull Request commands: `prs`, `pr`, `diffstat`, `diff`, `comments`, `pr-commits`
- Repository commands: `repos`, `branches`, `commits`, `file`, `ls`
- Input sanitization for all user-supplied arguments (repo slugs, PR IDs, branch names)
- Security manifest in `bb-cli.sh` documenting all env vars, endpoints, and file I/O
- Pagination support for all list endpoints
- Per-file diff splitting for safe review of large PRs
- ClawHub-compatible SKILL.md with capabilities, security, and trust sections
- Comprehensive README with quick start guide and command reference

### Security
- All operations are read-only (GET requests only)
- API token scoping enforced via documentation
- Strict regex validation on all user inputs before URL interpolation
- No local filesystem read/write operations
