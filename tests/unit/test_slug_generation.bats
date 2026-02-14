#!/usr/bin/env bats
# Unit tests for slug generation and sanitization

setup() {
    # Define the sanitize_slug function (matches the script's implementation)
    sanitize_slug() {
        printf '%s' "$1" \
            | tr '[:upper:]' '[:lower:]' \
            | sed -E 's/[^a-z0-9_]+/_/g' \
            | sed -E 's/_+/_/g' \
            | sed -E 's/^_|_$//g' \
            | tr -d '\n'
    }
}

@test "sanitize_slug converts to lowercase" {
    result="$(sanitize_slug "HelloWorld")"
    [ "$result" = "helloworld" ]
}

@test "sanitize_slug replaces spaces with underscores" {
    result="$(sanitize_slug "hello world")"
    [ "$result" = "hello_world" ]
}

@test "sanitize_slug removes special characters" {
    result="$(sanitize_slug "hello@world#test!")"
    [ "$result" = "hello_world_test" ]
}

@test "sanitize_slug collapses multiple underscores" {
    result="$(sanitize_slug "hello___world")"
    [ "$result" = "hello_world" ]
}

@test "sanitize_slug strips leading underscores" {
    result="$(sanitize_slug "_hello")"
    [ "$result" = "hello" ]
}

@test "sanitize_slug strips trailing underscores" {
    result="$(sanitize_slug "hello_")"
    [ "$result" = "hello" ]
}

@test "sanitize_slug handles mixed input" {
    result="$(sanitize_slug "  The Quick Brown Fox! @#$ 123  ")"
    [ "$result" = "the_quick_brown_fox_123" ]
}

@test "sanitize_slug preserves digits" {
    result="$(sanitize_slug "test123")"
    [ "$result" = "test123" ]
}

@test "sanitize_slug handles unicode (locale-dependent)" {
    result="$(sanitize_slug "héllo wörld")"
    # Behavior is locale-dependent:
    # - C locale: unicode chars become underscores → h_llo_w_rld
    # - UTF-8 locale: unicode chars preserved → héllo_wörld
    # Accept either outcome
    [[ "$result" = "h_llo_w_rld" ]] || [[ "$result" = "héllo_wörld" ]]
}

@test "sanitize_slug handles empty input" {
    result="$(sanitize_slug "")"
    [ "$result" = "" ]
}

@test "sanitize_slug handles all-special-chars input" {
    result="$(sanitize_slug "@#$%^&*()")"
    [ "$result" = "" ]
}
