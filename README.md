# process_video

A CLI tool to extract YouTube video transcripts and process them through [Fabric](https://github.com/danielmiessler/fabric) AI patterns, generating comprehensive analysis reports.

## Features

- **Transcript extraction** from any YouTube URL or video ID
- **24 AI analysis patterns** run in parallel (claims analysis, insights extraction, summaries, etc.)
- **Automatic preprocessing** with `clean_text` and `fix_typos` patterns
- **Multiple output formats**: Markdown, PDF, DOCX, HTML
- **LLM-generated filename slugs** for clean, descriptive directory names
- **Configurable** via CLI flags or JSON config file

## Requirements

- **Bash** 4.0+
- **[Fabric](https://github.com/danielmiessler/fabric)** (Go version)
- **jq** for JSON processing
- **pandoc** (optional, for PDF/DOCX/HTML conversion)
- **youtube-transcript-api** Python package (fallback transcript fetcher)

## Installation

```bash
# Clone the repository
git clone https://github.com/ScientificProgrammer/process_video.git
cd process_video

# Install to ~/.local/bin
cp process_video ~/.local/bin/
cp fetch_transcript ~/.local/bin/

# Ensure ~/.local/bin is in your PATH
```

## Quick Start

```bash
# Basic usage
process_video https://youtu.be/VIDEO_ID

# Recommended: specify model and output format
process_video --model claude-sonnet-4-5 --vendor Anthropic --pdf https://youtu.be/VIDEO_ID
```

## Output Structure

Output directories follow this naming convention:
```
{processed_date}.{channel}.{upload_date}.{video_id}.{title_slug}/
```

Example: `20260213_193045.veritasium.2024-01-15.mD4jN6DyF7M.quantum_computing/`

**Components:**
- `processed_date` — UTC timestamp (YYYYMMDD_HHMMSS)
- `channel` — Channel name (max 20 chars, lowercase)
- `upload_date` — Video upload date (YYYY-MM-DD)
- `video_id` — YouTube video ID (case-sensitive, preserved verbatim)
- `title_slug` — Video title (max 20 chars, lowercase)

## Common Options

| Flag | Description | Default |
|------|-------------|---------|
| `-m, --model MODEL` | LLM model to use | `claude-sonnet-4-5` |
| `-V, --vendor VENDOR` | LLM vendor | `Anthropic` |
| `-j, --jobs N` | Parallel pattern jobs | `8` |
| `--pdf` | Generate PDF report | off |
| `--docx` | Generate DOCX report | off |
| `-n, --dry-run` | Preview without executing | off |
| `-v, --verbose` | Verbose output | off |

See `process_video --help` for all options.

## Configuration File

Instead of CLI flags, use a JSON config:

```bash
process_video --config config.json https://youtu.be/VIDEO_ID
```

Generate a template:
```bash
process_video --init-config > my_config.json
```

## Analysis Patterns

The tool runs 24 analysis patterns including:

- **Executive**: `youtube_summary`
- **Analysis**: `analyze_claims`, `analyze_presentation`, `analyze_tech_impact`, `analyze_personality`
- **Extraction**: `extract_wisdom_large`, `extract_ideas`, `extract_insights`, `extract_recommendations`
- **Strategic**: `create_ai_jobs_analysis`, `prepare_7s_strategy`, `extract_alpha`
- **Quality**: `find_logical_fallacies`, `explain_terms`

View all patterns: `process_video --list-patterns`

## Development

### Running Tests

```bash
# Install bats-core
sudo apt-get install bats  # Debian/Ubuntu
brew install bats-core     # macOS

# Run tests
bats tests/unit/*.bats
```

### Linting

This project uses [Trunk](https://trunk.io) for linting:

```bash
trunk check
trunk fmt
```

### Version

Version is derived from git tags:

```bash
./process_video --version
# Output: process_video v0.2.0
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests (`bats tests/unit/*.bats`)
5. Commit with [conventional commits](https://www.conventionalcommits.org/)
6. Push and create a Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.

## AI Agent Integration

For AI agents (Clawdbot, etc.), see [AGENTS.md](AGENTS.md) for operational guidance.
