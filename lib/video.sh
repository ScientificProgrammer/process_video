# lib/video.sh -- URL normalization, metadata fetching, LLM slug generation,
#                 filename generation, and output directory setup
# Sourced by process_video. Do not execute directly.
# Depends on: ui.sh, config.sh, constants.sh

[[ -n "${_PV_VIDEO_LOADED:-}" ]] && return 0
readonly _PV_VIDEO_LOADED=1

# ------------------------------------------------------------------------------
# URL Normalization
# ------------------------------------------------------------------------------

VIDEO_URL=""
VIDEO_ID=""

normalize_video_url() {
    local input="$1"

    # Bare video ID (11 chars, alphanumeric + dash + underscore)
    if [[ "$input" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
        VIDEO_URL="https://www.youtube.com/watch?v=${input}"
        VIDEO_ID="$input"
        return 0
    fi

    # Extract video ID from various URL formats
    local vid_id=""
    if [[ "$input" =~ youtu\.be/([A-Za-z0-9_-]{11}) ]]; then
        vid_id="${BASH_REMATCH[1]}"
    elif [[ "$input" =~ [\?\&]v=([A-Za-z0-9_-]{11}) ]]; then
        vid_id="${BASH_REMATCH[1]}"
    fi

    if [[ -z "$vid_id" ]]; then
        die "Cannot extract video ID from: $input"
    fi

    VIDEO_URL="$input"
    VIDEO_ID="$vid_id"
}

# ------------------------------------------------------------------------------
# Output Directory Setup
# ------------------------------------------------------------------------------

OUTPUT_DIR=""
BASE_FILENAME=""

setup_output_dir() {
    if [[ -n "$OPT_OUTPUT_DIR" ]]; then
        OUTPUT_DIR="$OPT_OUTPUT_DIR"
    else
        OUTPUT_DIR="${PWD}/${BASE_FILENAME}"
    fi

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "Would create output directory: $OUTPUT_DIR"
        return 0
    fi

    mkdir -p "$OUTPUT_DIR"/{artifacts/md,transcripts,config,logs}
    LOG_FILE="${OUTPUT_DIR}/logs/${BASE_FILENAME}.process_video.log"
    : > "$LOG_FILE"

    log "INFO" "$SCRIPT_NAME v${SCRIPT_VERSION} started"
    log "INFO" "Command: $0 $ORIGINAL_ARGS"
    log "INFO" "Working directory: $(pwd)"
}

# ------------------------------------------------------------------------------
# Metadata and Filename Generation
# ------------------------------------------------------------------------------

VIDEO_TITLE="" CHANNEL_NAME="" UPLOAD_DATE=""

# Fetch metadata using yt-dlp (fast) or fabric (slow fallback)
# Args: $1 = output file path
# Returns: 0 on success, non-zero on failure
fetch_metadata_to_file() {
    local output_file="$1"
    local exit_code=0

    # Try yt-dlp first (much faster than fabric)
    if command -v yt-dlp &>/dev/null; then
        debug "Trying yt-dlp for metadata..."
        yt-dlp --dump-json --no-download "$VIDEO_URL" \
            > "$output_file" 2>/dev/null || exit_code=$?

        if [[ $exit_code -eq 0 ]] && [[ -s "$output_file" ]] && jq empty "$output_file" 2>/dev/null; then
            debug "yt-dlp metadata fetch succeeded"
            return 0
        fi
        debug "yt-dlp failed (exit=$exit_code), trying fabric fallback..."
    fi

    # Fallback to fabric (slow but sometimes works when yt-dlp doesn't)
    exit_code=0
    fabric --youtube="$VIDEO_URL" --metadata --raw \
        > "$output_file" 2>/dev/null || exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ ! -s "$output_file" ]]; then
        return 1
    fi

    # Validate JSON -- fabric sometimes outputs non-JSON preamble
    if ! jq empty "$output_file" 2>/dev/null; then
        local tmp_json
        tmp_json="$(grep -m1 '^{' "$output_file" | jq '.' 2>/dev/null)" || true
        if [[ -n "$tmp_json" ]]; then
            printf '%s' "$tmp_json" > "$output_file"
        else
            return 1
        fi
    fi

    return 0
}

# Parse metadata from JSON file into global variables
parse_metadata_file() {
    local meta_file="$1"
    VIDEO_TITLE="$(jq -r '.title // "untitled"' "$meta_file")"
    CHANNEL_NAME="$(jq -r '.channel // .channelTitle // .uploader // "unknown"' "$meta_file")"
    UPLOAD_DATE="$(jq -r '(.upload_date // (.publishedAt | split("T")[0] | gsub("-";""))) // "unknown"' "$meta_file")"
}

fetch_metadata() {
    info "Fetching metadata..."
    local start_time=$SECONDS

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "  [dry-run] Would fetch metadata for: $VIDEO_URL"
        VIDEO_TITLE="Dry Run Title"
        CHANNEL_NAME="DryRunChannel"
        UPLOAD_DATE="20260212"
        return 0
    fi

    local meta_file="${OUTPUT_DIR}/config/${BASE_FILENAME}.metadata.json"

    if ! fetch_metadata_to_file "$meta_file"; then
        die "Failed to fetch video metadata. Check URL: $VIDEO_URL"
    fi

    parse_metadata_file "$meta_file"

    local elapsed=$(( SECONDS - start_time ))
    info "  Title:   $VIDEO_TITLE"
    info "  Channel: $CHANNEL_NAME"
    info "  Date:    $UPLOAD_DATE"
    info "  Metadata fetched $(format_duration $elapsed)"
}

# ------------------------------------------------------------------------------
# LLM Slug Generation
# ------------------------------------------------------------------------------

readonly SLUG_PATTERN_NAME="generate_filename_slug"
readonly SLUG_MODEL="claude-3-5-haiku-latest"
readonly EDITORIAL_PATTERN_NAME="editorial_consolidation"
LLM_TITLE_SLUG=""
LLM_CHANNEL_SLUG=""

ensure_slug_pattern() {
    local pattern_dir="${FABRIC_PATTERN_DIR}/${SLUG_PATTERN_NAME}"
    local system_file="${pattern_dir}/system.md"

    local desired
    desired="$(cat <<'SLUG_PATTERN_EOF'
# IDENTITY and PURPOSE

You are a filename slug generator. You take a video title and channel name and
produce concise, descriptive filesystem-safe slugs.

# INSTRUCTIONS

You will receive JSON input with `title` and `channel` fields.

For the **title_slug**:
- Distill the title into its essential topic or theme using 3-5 words
- Maximum 40 characters
- Use only lowercase letters, digits, and underscores
- Capture the core subject matter, not filler words
- Drop subtitles, speaker names, series names, and parenthetical asides
- Example: "AI Productivity Bubble: Early Adopters Are Already Burning Out | Natasha Bernal" → "ai_productivity_burnout"

For the **channel_slug**:
- Simplify the channel name to its shortest recognizable form
- Maximum 20 characters
- Use only lowercase letters, digits, and underscores
- Drop common suffixes like "official", "channel", "podcast", "daily", "news"
- Example: "AI News & Strategy Daily | Nate B Jones" → "nate_b_jones"
- Example: "The Tech Report" → "tech_report"

# OUTPUT FORMAT

Return ONLY a single JSON object on one line, no markdown fencing, no explanation:

{"title_slug": "...", "channel_slug": "..."}

# OUTPUT INSTRUCTIONS

- Output ONLY the JSON object, nothing else
- No markdown code fences
- No explanatory text before or after
- Slugs must use only: lowercase a-z, digits 0-9, underscores
- No leading or trailing underscores
- No consecutive underscores
SLUG_PATTERN_EOF
)"

    if [[ -f "$system_file" ]] && [[ "$(cat "$system_file")" == "$desired" ]]; then
        return 0
    fi

    debug "Installing fabric pattern: $SLUG_PATTERN_NAME"
    mkdir -p "$pattern_dir"
    printf '%s\n' "$desired" > "$system_file"
}

ensure_editorial_pattern() {
    local pattern_dir="${FABRIC_PATTERN_DIR}/${EDITORIAL_PATTERN_NAME}"
    local system_file="${pattern_dir}/system.md"

    local desired
    desired="$(cat <<'EDITORIAL_PATTERN_EOF'
# IDENTITY and PURPOSE

You are the chief editor of a prestigious international news organization. You
are renowned for your ability to synthesize complex multi-source analyses into
cohesive, authoritative reports. You write and speak parsimoniously — every word
earns its place. You have zero tolerance for redundancy, padding, or restating
what has already been said.

# INSTRUCTIONS

You will receive a multi-section analysis report generated from a YouTube video
transcript. Multiple analytical patterns were run independently against the same
source material, which means there is significant overlap and duplication across
sections.

Your task is to consolidate this report into a single, cohesive document that:

1. **Eliminates redundancy** — If the same insight, claim, or recommendation
   appears in multiple sections, it should appear exactly once, in the most
   appropriate section.

2. **Preserves all unique information** — Every distinct insight, data point,
   claim, or observation must survive the consolidation. Do not discard
   information merely because it appears minor.

3. **Maintains the section structure** — Keep the existing heading hierarchy
   (H2 tier headings, H3 section headings). Do not rename sections, merge
   sections, or create new sections. You may remove a section entirely only if
   every piece of information in it already appears in another section.

4. **Preserves the YAML front matter** — The document begins with YAML front
   matter between `---` delimiters. Copy it through unchanged.

5. **Preserves the metadata table** — The document has an info table after the
   H1 heading. Copy it through unchanged.

6. **Tightens the prose** — Where the original is verbose or uses filler
   language, tighten the writing. Prefer active voice, concrete language, and
   shorter sentences. Do not add your own commentary, analysis, or opinions.

7. **Maintains markdown formatting** — Preserve bullet lists, numbered lists,
   bold/italic emphasis, and code formatting as used in the original. Keep the
   Table of Contents section and update it to reflect any removed sections.

# OUTPUT FORMAT

Output the complete consolidated report as a single markdown document. Include
everything from the YAML front matter through the final section. Do not wrap
the output in code fences. Do not add any preamble or postscript.

# OUTPUT INSTRUCTIONS

- Output ONLY the consolidated markdown report
- No commentary before or after the report
- No markdown code fences wrapping the output
- Preserve all YAML front matter exactly as provided
- Preserve all heading levels (H1, H2, H3) exactly as provided
- Update the Table of Contents to reflect any removed sections
- If a section becomes empty after deduplication, remove it and its TOC entry
EDITORIAL_PATTERN_EOF
)"

    if [[ -f "$system_file" ]] && [[ "$(cat "$system_file")" == "$desired" ]]; then
        return 0
    fi

    debug "Installing fabric pattern: $EDITORIAL_PATTERN_NAME"
    mkdir -p "$pattern_dir"
    printf '%s\n' "$desired" > "$system_file"
}

run_editorial_pass() {
    if [[ "$OPT_NO_EDITORIAL" == "true" ]]; then
        debug "Editorial consolidation disabled (--no-editorial)"
        return 0
    fi

    if [[ "$OPT_NO_REPORT" == "true" ]]; then
        return 0
    fi

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "[dry-run] Would run editorial consolidation pass"
        return 0
    fi

    local report_file="${OUTPUT_DIR}/${BASE_FILENAME}.report.md"
    [[ -f "$report_file" ]] || { warn "No report.md for editorial pass"; return 0; }

    ensure_editorial_pattern

    info "Running editorial consolidation..."
    local start_time=$SECONDS

    # Save the raw assembled report
    local raw_report="${OUTPUT_DIR}/${BASE_FILENAME}.report.raw.md"
    cp "$report_file" "$raw_report"

    # Build fabric command
    local -a fabric_cmd=(
        fabric
        --pattern="$EDITORIAL_PATTERN_NAME"
        --model="$OPT_MODEL"
    )
    [[ -n "$OPT_VENDOR" ]] && fabric_cmd+=(--vendor="$OPT_VENDOR")
    [[ "$OPT_RAW" == "true" ]] && fabric_cmd+=(--raw)

    local edited_output exit_code=0
    edited_output="$(cat "$report_file" | "${fabric_cmd[@]}" 2>>"$LOG_FILE")" || exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ -z "$edited_output" ]]; then
        warn "Editorial consolidation failed (exit=$exit_code); keeping raw report"
        # Restore the raw report as the primary report
        cp "$raw_report" "$report_file"
        return 0
    fi

    # Write the consolidated version as the primary report
    printf '%s\n' "$edited_output" > "$report_file"

    local elapsed=$(( SECONDS - start_time ))
    local raw_lines edited_lines
    raw_lines="$(wc -l < "$raw_report")"
    edited_lines="$(wc -l < "$report_file")"
    info "  Editorial pass done: ${raw_lines} → ${edited_lines} lines $(format_duration $elapsed)"
}

generate_llm_slug() {
    if [[ "$OPT_NO_LLM_SLUG" == "true" ]]; then
        debug "LLM slug generation disabled (--no-llm-slug)"
        return 0
    fi

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "  [dry-run] Would generate LLM filename slugs"
        return 0
    fi

    ensure_slug_pattern

    info "Generating filename slugs..."
    local start_time=$SECONDS

    local input_json
    input_json="$(jq -n \
        --arg title "$VIDEO_TITLE" \
        --arg channel "$CHANNEL_NAME" \
        '{"title": $title, "channel": $channel}')"

    local raw_output exit_code=0
    raw_output="$(printf '%s' "$input_json" | \
        fabric --pattern="$SLUG_PATTERN_NAME" \
            --model="$SLUG_MODEL" \
            --vendor=Anthropic \
            --raw \
            2>>"$LOG_FILE")" || exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ -z "$raw_output" ]]; then
        warn "LLM slug generation failed (exit=$exit_code); using mechanical slugs"
        log "WARN" "LLM slug generation failed: exit=$exit_code"
        return 0
    fi

    # Extract JSON from output (LLM may wrap in markdown fences)
    local json_line
    json_line="$(printf '%s' "$raw_output" | grep -m1 '^{' || true)"
    if [[ -z "$json_line" ]]; then
        warn "LLM slug output is not JSON; using mechanical slugs"
        log "WARN" "LLM slug raw output: $raw_output"
        return 0
    fi

    # Parse and validate slugs
    local title_slug channel_slug
    title_slug="$(printf '%s' "$json_line" | jq -r '.title_slug // empty' 2>/dev/null)" || true
    channel_slug="$(printf '%s' "$json_line" | jq -r '.channel_slug // empty' 2>/dev/null)" || true

    if [[ -z "$title_slug" ]] || [[ -z "$channel_slug" ]]; then
        warn "LLM slug output missing fields; using mechanical slugs"
        log "WARN" "LLM slug parsed: title='$title_slug' channel='$channel_slug'"
        return 0
    fi

    # Sanitize: enforce lowercase, allowed chars, length limits
    title_slug="$(printf '%s' "$title_slug" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9_]+/_/g' \
        | sed -E 's/_+/_/g' \
        | sed -E 's/^_|_$//g')"
    channel_slug="$(printf '%s' "$channel_slug" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9_]+/_/g' \
        | sed -E 's/_+/_/g' \
        | sed -E 's/^_|_$//g')"

    # Enforce max widths (title_slug shortened to 20 for manageable filenames)
    title_slug="${title_slug:0:20}"
    channel_slug="${channel_slug:0:20}"

    if [[ -z "$title_slug" ]] || [[ -z "$channel_slug" ]]; then
        warn "LLM slug sanitization produced empty result; using mechanical slugs"
        return 0
    fi

    LLM_TITLE_SLUG="$title_slug"
    LLM_CHANNEL_SLUG="$channel_slug"

    local elapsed=$(( SECONDS - start_time ))
    info "  Channel slug: $LLM_CHANNEL_SLUG"
    info "  Title slug:   $LLM_TITLE_SLUG"
    info "  Slugs generated $(format_duration $elapsed)"
}

# ------------------------------------------------------------------------------
# Filename Generation
# ------------------------------------------------------------------------------

# Helper: sanitize a string for use in filenames (lowercase, safe chars only)
sanitize_slug() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9_]+/_/g' \
        | sed -E 's/_+/_/g' \
        | sed -E 's/^_|_$//g' \
        | tr -d '\n'
}

generate_base_filename() {
    # Processed date in UTC: YYYYMMDD_HHMMSS
    local processed_date
    processed_date="$(date -u +%Y%m%d_%H%M%S)"

    local channel_part title_part

    if [[ -n "$LLM_TITLE_SLUG" ]] && [[ -n "$LLM_CHANNEL_SLUG" ]]; then
        # LLM slugs are already sanitized and lowercased
        channel_part="$LLM_CHANNEL_SLUG"
        title_part="$LLM_TITLE_SLUG"
    else
        # Fallback: sanitize raw metadata (but preserve VIDEO_ID verbatim)
        channel_part="$(sanitize_slug "$CHANNEL_NAME")"
        title_part="$(sanitize_slug "$VIDEO_TITLE")"
        # Enforce length limits on fallback slugs
        channel_part="${channel_part:0:20}"
        title_part="${title_part:0:20}"
    fi

    # Assemble filename: VIDEO_ID preserved verbatim (case-sensitive)
    # Format: {processed_date}.{channel}.{upload_date}.{video_id}.{title_slug}
    # Include the model name in the base filename
    local safe_model="${OPT_MODEL//[^a-zA-Z0-9_-]/_}"
    BASE_FILENAME="${processed_date}.${channel_part}.${UPLOAD_DATE}.${VIDEO_ID}.${title_part}.${safe_model}"

    # Final safety: remove any remaining problematic characters (but preserve case)
    BASE_FILENAME="$(printf '%s' "$BASE_FILENAME" \
        | sed -E 's/[^-._[:alnum:]]+/_/g' \
        | sed -E 's/_+/_/g' \
        | sed -E 's/^_|_$//g' \
        | tr -d '\n')"

    # Truncate to a reasonable length to avoid filesystem issues
    if [[ ${#BASE_FILENAME} -gt 200 ]]; then
        BASE_FILENAME="${BASE_FILENAME:0:200}"
    fi

    debug "Base filename: $BASE_FILENAME"
}
