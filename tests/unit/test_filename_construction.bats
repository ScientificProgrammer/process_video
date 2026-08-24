#!/usr/bin/env bats
# Unit tests for filename construction
# Critical test: VIDEO_ID case must be preserved

setup() {
    # Helper function (matches script)
    sanitize_slug() {
        printf '%s' "$1" \
            | tr '[:upper:]' '[:lower:]' \
            | sed -E 's/[^a-z0-9_]+/_/g' \
            | sed -E 's/_+/_/g' \
            | sed -E 's/^_|_$//g' \
            | tr -d '\n'
    }

    # Simplified generate_base_filename for testing
    # In real script, this uses global vars; here we pass as params
    generate_base_filename() {
        local processed_date="$1"
        local channel_slug="$2"
        local upload_date="$3"
        local video_id="$4"
        local title_slug="$5"
        local model="$6"

        local safe_model
        safe_model="$(printf '%s' "$model" \
            | sed -E 's/[^A-Za-z0-9_-]+/_/g' \
            | sed -E 's/_+/_/g' \
            | sed -E 's/^_|_$//g' \
            | tr -d '\n')"
        [[ -n "$safe_model" ]] || safe_model="unknown_model"

        local base="${processed_date}.${channel_slug}.${upload_date}.${video_id}.${title_slug}.${safe_model}"

        # Final safety: remove problematic chars but preserve case
        printf '%s' "$base" \
            | sed -E 's/[^-._[:alnum:]]+/_/g' \
            | sed -E 's/_+/_/g' \
            | sed -E 's/^_|_$//g' \
            | tr -d '\n'
    }
}

@test "filename preserves VIDEO_ID case (mixed case)" {
    result="$(generate_base_filename "20260213_193000" "veritasium" "20240115" "mD4jN6DyF7M" "quantum_computing" "gpt-5.6-luna")"
    [[ "$result" == *"mD4jN6DyF7M"* ]]
}

@test "filename preserves VIDEO_ID case (all uppercase in ID)" {
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "ABCDEFGHIJK" "title" "gpt-5.6-luna")"
    [[ "$result" == *"ABCDEFGHIJK"* ]]
}

@test "filename has correct component order" {
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "VideoID123" "title" "gpt-5.6-luna")"
    # Format: {processed_date}.{channel}.{upload_date}.{video_id}.{title_slug}.{model}
    [ "$result" = "20260213_193000.channel.20240115.VideoID123.title.gpt-5_6-luna" ]
}

@test "filename processed_date comes first (for sorting)" {
    result="$(generate_base_filename "20260213_193000" "zchannel" "20240115" "id123" "title" "gpt-5.6-luna")"
    [[ "$result" == "20260213_193000."* ]]
}

@test "filename channel is lowercase" {
    # Channel should be pre-sanitized before calling generate_base_filename
    channel="$(sanitize_slug "Veritasium")"
    result="$(generate_base_filename "20260213_193000" "$channel" "20240115" "id123" "title" "gpt-5.6-luna")"
    [[ "$result" == *".veritasium."* ]]
}

@test "filename title is lowercase" {
    # Title should be pre-sanitized before calling generate_base_filename
    title="$(sanitize_slug "Quantum Computing")"
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "id123" "$title" "gpt-5.6-luna")"
    [[ "$result" == *".quantum_computing."* ]]
}

@test "filename does not lowercase VIDEO_ID even when other parts are sanitized" {
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "AbCdEfGhIjK" "title" "gpt-5.6-luna")"
    # The VIDEO_ID must retain its original case
    [[ "$result" == *"AbCdEfGhIjK"* ]]
    # Verify it's NOT lowercased
    [[ "$result" != *"abcdefghijk"* ]]
}

@test "filename handles VIDEO_ID with hyphen" {
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "abc-def-123" "title" "gpt-5.6-luna")"
    [[ "$result" == *"abc-def-123"* ]]
}

@test "filename handles VIDEO_ID with underscore" {
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "abc_def_123" "title" "gpt-5.6-luna")"
    [[ "$result" == *"abc_def_123"* ]]
}

@test "filename includes a sanitized model component" {
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "AbCdEfGhIjK" "title" "openai/gpt-5.6-luna")"
    [[ "$result" == *".openai_gpt-5_6-luna" ]]
}

@test "filename uses a non-empty model fallback" {
    result="$(generate_base_filename "20260213_193000" "channel" "20240115" "AbCdEfGhIjK" "title" "")"
    [[ "$result" == *".unknown_model" ]]
}
