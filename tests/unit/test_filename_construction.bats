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
        
        local base="${processed_date}.${channel_slug}.${upload_date}.${video_id}.${title_slug}"
        
        # Final safety: remove problematic chars but preserve case
        printf '%s' "$base" \
            | sed -E 's/[^-._[:alnum:]]+/_/g' \
            | sed -E 's/_+/_/g' \
            | sed -E 's/^_|_$//g' \
            | tr -d '\n'
    }
}

@test "filename preserves VIDEO_ID case (mixed case)" {
    result="$(generate_base_filename "20260213_193000" "veritasium" "2024-01-15" "mD4jN6DyF7M" "quantum_computing")"
    [[ "$result" == *"mD4jN6DyF7M"* ]]
}

@test "filename preserves VIDEO_ID case (all uppercase in ID)" {
    result="$(generate_base_filename "20260213_193000" "channel" "2024-01-15" "ABCDEFGHIJK" "title")"
    [[ "$result" == *"ABCDEFGHIJK"* ]]
}

@test "filename has correct component order" {
    result="$(generate_base_filename "20260213_193000" "channel" "2024-01-15" "VideoID123" "title")"
    # Format: {processed_date}.{channel}.{upload_date}.{video_id}.{title_slug}
    [ "$result" = "20260213_193000.channel.2024-01-15.VideoID123.title" ]
}

@test "filename processed_date comes first (for sorting)" {
    result="$(generate_base_filename "20260213_193000" "zchannel" "2024-01-15" "id123" "title")"
    [[ "$result" == "20260213_193000."* ]]
}

@test "filename channel is lowercase" {
    # Channel should be pre-sanitized before calling generate_base_filename
    channel="$(sanitize_slug "Veritasium")"
    result="$(generate_base_filename "20260213_193000" "$channel" "2024-01-15" "id123" "title")"
    [[ "$result" == *".veritasium."* ]]
}

@test "filename title is lowercase" {
    # Title should be pre-sanitized before calling generate_base_filename
    title="$(sanitize_slug "Quantum Computing")"
    result="$(generate_base_filename "20260213_193000" "channel" "2024-01-15" "id123" "$title")"
    [[ "$result" == *".quantum_computing" ]]
}

@test "filename does not lowercase VIDEO_ID even when other parts are sanitized" {
    result="$(generate_base_filename "20260213_193000" "channel" "2024-01-15" "AbCdEfGhIjK" "title")"
    # The VIDEO_ID must retain its original case
    [[ "$result" == *"AbCdEfGhIjK"* ]]
    # Verify it's NOT lowercased
    [[ "$result" != *"abcdefghijk"* ]]
}

@test "filename handles VIDEO_ID with hyphen" {
    result="$(generate_base_filename "20260213_193000" "channel" "2024-01-15" "abc-def-123" "title")"
    [[ "$result" == *"abc-def-123"* ]]
}

@test "filename handles VIDEO_ID with underscore" {
    result="$(generate_base_filename "20260213_193000" "channel" "2024-01-15" "abc_def_123" "title")"
    [[ "$result" == *"abc_def_123"* ]]
}
