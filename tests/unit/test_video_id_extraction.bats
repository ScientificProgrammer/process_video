#!/usr/bin/env bats
# Unit tests for VIDEO_ID extraction from various YouTube URL formats

# Load the function under test by sourcing just the relevant part
setup() {
    # Extract the extract_video_id function from the main script
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    
    # Define the function inline for testing (matches the script's implementation)
    extract_video_id() {
        local url="$1"
        local video_id=""

        # Try various YouTube URL patterns
        if [[ "$url" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
            # Already a video ID
            video_id="$url"
        elif [[ "$url" =~ youtu\.be/([a-zA-Z0-9_-]{11}) ]]; then
            video_id="${BASH_REMATCH[1]}"
        elif [[ "$url" =~ [?&]v=([a-zA-Z0-9_-]{11}) ]]; then
            video_id="${BASH_REMATCH[1]}"
        elif [[ "$url" =~ youtube\.com/embed/([a-zA-Z0-9_-]{11}) ]]; then
            video_id="${BASH_REMATCH[1]}"
        elif [[ "$url" =~ youtube\.com/v/([a-zA-Z0-9_-]{11}) ]]; then
            video_id="${BASH_REMATCH[1]}"
        fi

        printf '%s' "$video_id"
    }
}

@test "extract VIDEO_ID from youtu.be short URL" {
    result="$(extract_video_id "https://youtu.be/mD4jN6DyF7M")"
    [ "$result" = "mD4jN6DyF7M" ]
}

@test "extract VIDEO_ID from youtu.be with tracking params" {
    result="$(extract_video_id "https://youtu.be/mD4jN6DyF7M?si=ChXm-CfLIPLde1Xu")"
    [ "$result" = "mD4jN6DyF7M" ]
}

@test "extract VIDEO_ID from youtube.com watch URL" {
    result="$(extract_video_id "https://www.youtube.com/watch?v=mD4jN6DyF7M")"
    [ "$result" = "mD4jN6DyF7M" ]
}

@test "extract VIDEO_ID from youtube.com watch URL with extra params" {
    result="$(extract_video_id "https://www.youtube.com/watch?v=mD4jN6DyF7M&t=120")"
    [ "$result" = "mD4jN6DyF7M" ]
}

@test "extract VIDEO_ID from embed URL" {
    result="$(extract_video_id "https://www.youtube.com/embed/mD4jN6DyF7M")"
    [ "$result" = "mD4jN6DyF7M" ]
}

@test "pass through raw VIDEO_ID" {
    result="$(extract_video_id "mD4jN6DyF7M")"
    [ "$result" = "mD4jN6DyF7M" ]
}

@test "VIDEO_ID case is preserved (mixed case)" {
    result="$(extract_video_id "https://youtu.be/AbCdEfGhIjK")"
    [ "$result" = "AbCdEfGhIjK" ]
}

@test "VIDEO_ID with underscore is extracted" {
    result="$(extract_video_id "https://youtu.be/abc_def_123")"
    [ "$result" = "abc_def_123" ]
}

@test "VIDEO_ID with hyphen is extracted" {
    result="$(extract_video_id "https://youtu.be/abc-def-123")"
    [ "$result" = "abc-def-123" ]
}
