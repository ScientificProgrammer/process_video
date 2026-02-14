# process_video -- AI Agent Operations Guide

This document is for AI agents (@Data, @Clawdbot, @JARVIS) that need to invoke
`process_video` on behalf of the user.

## File Locations

| Item | Path |
|------|------|
| **Installed executable** | `~/.local/bin/process_video` (stable release copy) |
| **Development source** | `~/Projects/git-repos/github-repos/process_video/process_video` |
| **Default config** | `~/Projects/git-repos/github-repos/process_video/process_video.config.json` |
| **Fallback transcript tool** | `~/.local/bin/fetch_transcript` |
| **Fabric patterns directory** | `~/.config/fabric/patterns/` |

The installed copy at `~/.local/bin/process_video` is the stable release. The
development source lives in the git repo. At release milestones, the release
copy is updated via:
```bash
cp ~/Projects/git-repos/github-repos/process_video/process_video ~/.local/bin/process_video
```
Always invoke via `process_video` (the `~/.local/bin` copy) in production.

## What It Does

`process_video` takes a YouTube URL or video ID and:

1. Fetches video metadata (title, channel, upload date) via `fabric --metadata`
2. Fetches the transcript via `fabric --transcript` (falls back to `fetch_transcript`)
3. Preprocesses the transcript through `clean_text` and `fix_typos` fabric patterns
4. Runs N analysis patterns in parallel (default: 8 concurrent jobs) against the cleaned transcript
5. Assembles all pattern outputs into a single combined Markdown report
6. Optionally converts the report to HTML, DOCX, or PDF via pandoc

## Quick Start

Minimal invocation:
```bash
process_video https://youtu.be/VIDEO_ID
```

Recommended full invocation:
```bash
process_video --model claude-sonnet-4-5 --vendor Anthropic --pdf https://youtu.be/VIDEO_ID
```

## Common Flags

| Flag | Description | Default |
|------|-------------|---------|
| `-m, --model MODEL` | LLM model to use | `claude-sonnet-4-5` |
| `-V, --vendor VENDOR` | LLM vendor | `Anthropic` |
| `-j, --jobs N` | Parallel pattern jobs | `8` |
| `-p, --patterns p1,p2` | Override pattern list (comma-separated) | 24 built-in patterns |
| `-c, --config FILE` | JSON config file | none |
| `--pdf` | Generate PDF report via pandoc | off |
| `--docx` | Generate DOCX report via pandoc | off |
| `--html` | Generate HTML report via pandoc | off |
| `--skip-preprocessing` | Skip clean_text/fix_typos steps | off |
| `-n, --dry-run` | Show what would happen without executing | off |
| `-v, --verbose` | Verbose output | off |
| `-q, --quiet` | Suppress progress output | off |

## Output Structure

The script creates an output directory in the current working directory named:
`{processed_date}.{channel}.{upload_date}.{video_id}.{title_slug}/`

**Filename components:**
- `processed_date` -- UTC timestamp when processing started (`YYYYMMDD_HHMMSS`)
- `channel` -- Sanitized channel name (max 20 chars, lowercase)
- `upload_date` -- Video upload date (`YYYY-MM-DD`)
- `video_id` -- YouTube video ID (**preserved verbatim, case-sensitive**)
- `title_slug` -- Sanitized title (max 20 chars, lowercase)

**Example:** `20260213_193045.veritasium.2024-01-15.mD4jN6DyF7M.quantum_computing/`

```
{base}/
  artifacts/md/          # Individual pattern outputs (one .md per pattern)
  transcripts/           # Raw and cleaned transcript files
  config/                # Metadata JSON and run manifest
  logs/                  # Execution log
  {base}.report.md       # Combined report (all patterns assembled)
  {base}.report.pdf      # (if --pdf was used)
  {base}.report.docx     # (if --docx was used)
```

## Using a Config File

Instead of passing many flags, use a JSON config:
```bash
process_video --config /path/to/config.json https://youtu.be/VIDEO_ID
```

See `process_video.config.json` in this repo for the full template. Key fields:
- `.process_video.fabric.model` -- LLM model
- `.process_video.fabric.vendor` -- LLM vendor
- `.process_video.fabric.parallel_jobs` -- concurrent job count
- `.process_video.patterns[]` -- array of pattern names to run

**Precedence:** CLI flags > config file > built-in defaults.

## Important Operational Notes

1. **Working directory matters.** The output directory is created relative to `$PWD`.
   Always `cd` to the appropriate working session directory before invoking.

2. **Fabric must be installed.** The Go version at `~/go/bin/fabric` is required.
   Run `fabric --version` to verify.

3. **Transcript fallback.** If `fabric --transcript` fails (common with the Go
   version), the script automatically falls back to `fetch_transcript` which uses
   the Python `youtube-transcript-api` package directly. Ensure
   `youtube-transcript-api` is installed: `pip install youtube-transcript-api`.

4. **Rate limits.** When using high `-j` values (6-8), LLM API rate limits may
   cause pattern failures. If you see multiple `[FAIL]` results, retry with
   `-j 4` or add `"sleep_between_patterns": 2` in the config.

5. **Session names.** If no `--session` is given, one is auto-generated as
   `YYYYMMDD_HHMMSS.process_video.{VIDEO_ID}`. Fabric sessions provide
   conversational context across patterns -- generally leave this at the default.

6. **Pandoc is optional.** It's only needed for `--pdf`, `--docx`, `--html`
   conversion. The Markdown report is always generated.

## Typical Agent Workflow

```bash
# 1. Navigate to the working session directory
cd ~/Projects/working_sessions/youtube-transcripts/YYYYMMDD_HHMMSS.session_name/

# 2. Run process_video
process_video --model claude-sonnet-4-5 --vendor Anthropic --pdf https://youtu.be/VIDEO_ID

# 3. The output directory and report are created in $PWD
# 4. Read the .report.md for analysis results
```

## Utility Commands

```bash
# List all patterns that will run
process_video --list-patterns

# Verify all patterns exist on disk
process_video --verify-patterns

# Generate a default config file
process_video --init-config > my_config.json

# Preview what would happen without running anything
process_video --dry-run https://youtu.be/VIDEO_ID
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `transcript extraction failed` for both fabric and fallback | `youtube-transcript-api` outdated or video has no captions | `pip install -U youtube-transcript-api` |
| Many `[FAIL]` patterns | API rate limiting | Lower `-j` value or add sleep in config |
| `unknown.unknown` in filenames | Metadata fields not parsed | Update script (metadata field names changed between fabric Python/Go versions) |
| No colors in output | `COLOR_*` env vars set with literal `\e` instead of `$'\e'` | Fix in `~/.bashrc` SetColorEnvVars to use `$'\e[...]'` quoting |
