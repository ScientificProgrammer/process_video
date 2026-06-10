# lib/deps.sh -- Dependency checking (required and optional tools, fabric patterns)
# Sourced by process_video. Do not execute directly.
# Depends on: ui.sh (debug, err, warn, die), config.sh (OPT_PANDOC_FORMATS),
#             constants.sh (DEFAULT_PREPROCESSING_PATTERNS, FABRIC_PATTERN_DIR)

[[ -n "${_PV_DEPS_LOADED:-}" ]] && return 0
readonly _PV_DEPS_LOADED=1

check_dependencies() {
    local missing=0

    for cmd in fabric jq; do
        if ! command -v "$cmd" &>/dev/null; then
            err "Required dependency not found: $cmd"
            ((missing++)) || true
        else
            debug "Found: $cmd -> $(command -v "$cmd")"
        fi
    done

    if [[ $missing -gt 0 ]]; then
        die "Missing $missing required dependency(ies). Install them and retry."
    fi

    # Note: Skipping fabric --version check because Go fabric is extremely slow (~30s+)
    # Just verify the binary exists (already done above via command -v)
}

check_optional_dependencies() {
    for cmd in pandoc yt-dlp fetch_transcript; do
        if command -v "$cmd" &>/dev/null; then
            debug "Optional: $cmd -> $(command -v "$cmd")"
        else
            debug "Optional dependency not found: $cmd"
        fi
    done

    if [[ ${#OPT_PANDOC_FORMATS[@]} -gt 0 ]] && ! command -v pandoc &>/dev/null; then
        warn "pandoc not found; --html/--docx/--pdf flags will be ignored"
        OPT_PANDOC_FORMATS=()
    fi
}

check_patterns_exist() {
    local all_patterns=("${DEFAULT_PREPROCESSING_PATTERNS[@]}" "${OPT_PATTERNS[@]}")
    local missing=0
    local pattern test_file

    for pattern in "${all_patterns[@]}"; do
        test_file="${FABRIC_PATTERN_DIR}/${pattern}/system.md"
        if [[ ! -f "$test_file" ]]; then
            err "Pattern not found: $pattern (expected: $test_file)"
            ((missing++)) || true
        fi
    done

    if [[ $missing -gt 0 ]]; then
        die "Missing $missing fabric pattern(s). Run 'fabric --updatepatterns' or review your pattern list."
    fi

    debug "All ${#all_patterns[@]} patterns verified"
}
