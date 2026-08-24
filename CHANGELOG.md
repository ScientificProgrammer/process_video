# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-02-13

### Added
- UTC `processed_date` prefix to output directory names for time-based sorting
- `sanitize_slug()` helper function for consistent filename sanitization
- Unit tests using bats-core (video ID extraction, slug generation, filename construction)
- GitHub Actions CI workflow (shellcheck, bats tests, syntax checks)
- Trunk configuration for linting (shellcheck, shfmt, markdownlint)
- README.md with human-readable documentation
- CHANGELOG.md for version history

### Changed
- **BREAKING**: Output directory format changed from `{channel}.{upload_date}.{video_id}.{title_slug}` to `{processed_date}.{channel}.{upload_date}.{video_id}.{title_slug}.{model}`
- Version now derived from git tags at runtime (`git describe --tags`)
- Title slug max length reduced from 40 to 20 characters
- VIDEO_ID is now preserved verbatim (case-sensitive) in filenames
- Processing model is included as a sanitized filename component
- Markdown report tables tolerate video titles containing pipe characters

### Fixed
- VIDEO_ID was incorrectly lowercased, breaking YouTube links

## [0.1.0] - 2026-02-12

### Added
- Initial release
- LLM-generated filename slugs
- Editorial consolidation pass
- 24 analysis patterns with parallel execution
- Transcript preprocessing (clean_text, fix_typos)
- Multiple output formats (Markdown, PDF, DOCX, HTML)
- JSON configuration file support

[Unreleased]: https://github.com/ScientificProgrammer/process_video/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ScientificProgrammer/process_video/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ScientificProgrammer/process_video/releases/tag/v0.1.0
