# lib/processing.sh -- Transcript fetching, preprocessing, and pattern execution
# Sourced by process_video. Do not execute directly.
# Depends on: ui.sh, config.sh, video.sh (OUTPUT_DIR, BASE_FILENAME, VIDEO_URL, VIDEO_ID)

[[ -n "${_PV_PROCESSING_LOADED:-}" ]] && return 0
readonly _PV_PROCESSING_LOADED=1

# ------------------------------------------------------------------------------
# Transcript Fetching and Preprocessing
# ------------------------------------------------------------------------------

fetch_transcript() {
    info "Fetching transcript..."
    local start_time=$SECONDS

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "  [dry-run] Would fetch transcript for: $VIDEO_URL"
        return 0
    fi

    local transcript_file="${OUTPUT_DIR}/transcripts/${BASE_FILENAME}.transcript_raw.txt"
    local exit_code=0

    # Try fetch_transcript first (fast, Python-based)
    if command -v fetch_transcript &>/dev/null; then
        debug "Trying fetch_transcript for transcript..."
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        (cd "$tmp_dir" && command fetch_transcript --quiet "$VIDEO_ID") 2>>"$LOG_FILE" || exit_code=$?

        if [[ $exit_code -eq 0 ]] && [[ -s "$tmp_dir/${VIDEO_ID}.txt" ]]; then
            mv "$tmp_dir/${VIDEO_ID}.txt" "$transcript_file"
            rm -rf "$tmp_dir"
            debug "Transcript fetched via fetch_transcript"
        else
            rm -rf "$tmp_dir"
            debug "fetch_transcript failed (exit=$exit_code), trying fabric fallback..."
            exit_code=1  # Signal to try fallback
        fi
    else
        exit_code=1  # No fetch_transcript, try fabric
    fi

    # Fallback to fabric if fetch_transcript failed or unavailable
    if [[ $exit_code -ne 0 ]] || [[ ! -s "$transcript_file" ]]; then
        local transcript_flag="--transcript"
        [[ "$OPT_TIMESTAMPS" == "true" ]] && transcript_flag="--transcript-with-timestamps"

        exit_code=0
        fabric --youtube="$VIDEO_URL" $transcript_flag --raw \
            > "$transcript_file" 2>>"$LOG_FILE" || exit_code=$?

        if [[ $exit_code -ne 0 ]] || [[ ! -s "$transcript_file" ]]; then
            die "All transcript extraction methods failed for: $VIDEO_URL"
        fi
    fi

    local lines words
    lines="$(wc -l < "$transcript_file")"
    words="$(wc -w < "$transcript_file")"
    info "  Transcript: $lines lines, $words words"

    local elapsed=$(( SECONDS - start_time ))
    info "  Transcript fetched $(format_duration $elapsed)"
}

preprocess_transcript() {
    local raw_file="${OUTPUT_DIR}/transcripts/${BASE_FILENAME}.transcript_raw.txt"
    local clean_file="${OUTPUT_DIR}/transcripts/${BASE_FILENAME}.transcript_clean.txt"

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "  [dry-run] Would preprocess transcript"
        return 0
    fi

    if [[ "$OPT_SKIP_PREPROCESSING" == "true" ]]; then
        info "Skipping preprocessing (--skip-preprocessing)"
        cp "$raw_file" "$clean_file"
        return 0
    fi

    # Stage 1: clean_text
    info "Preprocessing: clean_text..."
    local start_time=$SECONDS
    local tmp_clean="${OUTPUT_DIR}/.tmp_clean1.txt"

    local exit_code=0
    fabric --pattern=clean_text \
        ${OPT_MODEL:+--model="$OPT_MODEL"} \
        ${OPT_RAW:+--raw} \
        < "$raw_file" \
        > "$tmp_clean" 2>>"$LOG_FILE" || exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ ! -s "$tmp_clean" ]]; then
        warn "clean_text failed; using raw transcript"
        cp "$raw_file" "$clean_file"
        rm -f "$tmp_clean"
        return 0
    fi

    local elapsed=$(( SECONDS - start_time ))
    info "  clean_text done $(format_duration $elapsed)"

    # Stage 2: fix_typos
    info "Preprocessing: fix_typos..."
    start_time=$SECONDS
    exit_code=0

    fabric --pattern=fix_typos \
        ${OPT_MODEL:+--model="$OPT_MODEL"} \
        ${OPT_RAW:+--raw} \
        < "$tmp_clean" \
        > "$clean_file" 2>>"$LOG_FILE" || exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ ! -s "$clean_file" ]]; then
        warn "fix_typos failed; using clean_text output"
        mv "$tmp_clean" "$clean_file"
        return 0
    fi

    elapsed=$(( SECONDS - start_time ))
    info "  fix_typos done $(format_duration $elapsed)"

    rm -f "$tmp_clean"

    local words
    words="$(wc -w < "$clean_file")"
    info "  Cleaned transcript: $words words"
}

# ------------------------------------------------------------------------------
# Pattern Execution
# ------------------------------------------------------------------------------

run_fabric_pattern() {
    local pattern="$1"
    local input_file="$2"
    local output_file="$3"
    local exit_code=0

    local -a fabric_args=(
        --pattern="$pattern"
    )
    [[ -n "$OPT_MODEL" ]] && fabric_args+=(--model="$OPT_MODEL")
    [[ -n "$OPT_VENDOR" ]] && fabric_args+=(--vendor="$OPT_VENDOR")
    [[ -n "$OPT_SESSION" ]] && fabric_args+=(--session="$OPT_SESSION")
    [[ -n "$OPT_STRATEGY" ]] && fabric_args+=(--strategy="$OPT_STRATEGY")
    [[ -n "$OPT_TEMPERATURE" ]] && fabric_args+=(--temperature="$OPT_TEMPERATURE")
    [[ "$OPT_RAW" == "true" ]] && fabric_args+=(--raw)

    fabric "${fabric_args[@]}" \
        < "$input_file" \
        > "$output_file" 2>>"$LOG_FILE" || exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ ! -s "$output_file" ]]; then
        rm -f "$output_file"
        return 1
    fi
    return 0
}

run_all_patterns() {
    local -a failed_patterns=()
    local -a succeeded_patterns=()
    local total=${#OPT_PATTERNS[@]}
    local idx=0
    local clean_file="${OUTPUT_DIR}/transcripts/${BASE_FILENAME}.transcript_clean.txt"

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "[dry-run] Would run $total patterns (jobs=${OPT_JOBS}):"
        for pattern in "${OPT_PATTERNS[@]}"; do
            ((idx++)) || true
            printf '  [%2d/%2d] %s\n' "$idx" "$total" "$pattern"
        done
        return 0
    fi

    local max_jobs="${OPT_JOBS:-8}"
    phdr "Running $total analysis patterns (${max_jobs} parallel)"

    # Temp dir for per-pattern status files (avoids subshell variable scoping)
    local status_dir
    status_dir="$(mktemp -d)"

    # FIFO-based semaphore for concurrency control
    local fifo="${status_dir}/.job_fifo"
    mkfifo "$fifo"
    exec 7<>"$fifo"
    rm -f "$fifo"

    # Pre-fill semaphore with N tokens
    local i
    for (( i = 0; i < max_jobs; i++ )); do
        printf '\n' >&7
    done

    # Launch all patterns as background jobs
    for pattern in "${OPT_PATTERNS[@]}"; do
        ((idx++)) || true

        # Acquire a semaphore slot (blocks until one is available)
        read -r -u 7

        info "  [${idx}/${total}] Launching: ${pattern}"

        # Rate limiting stagger between launches
        local sleep_secs="${OPT_SLEEP:-0}"
        if [[ "$sleep_secs" != "0" ]] && (( idx > 1 )); then
            sleep "$sleep_secs"
        fi

        (
            local _start=$SECONDS
            local _output_file="${OUTPUT_DIR}/artifacts/md/${BASE_FILENAME}.${pattern}.md"
            local _exit=0

            run_fabric_pattern "$pattern" "$clean_file" "$_output_file" || _exit=$?

            local _elapsed=$(( SECONDS - _start ))
            printf '%s %s\n' "$_exit" "$_elapsed" > "${status_dir}/${pattern}.status"

            # Release semaphore slot
            printf '\n' >&7
        ) &
    done

    # Wait for all background jobs to finish
    wait

    # Close semaphore fd
    exec 7>&-

    # Collect results in original pattern order
    phdr "Results"
    for pattern in "${OPT_PATTERNS[@]}"; do
        local status_file="${status_dir}/${pattern}.status"
        local exit_code=1 elapsed=0

        if [[ -f "$status_file" ]]; then
            read -r exit_code elapsed < "$status_file"
        fi

        if [[ "$exit_code" -eq 0 ]]; then
            printf '  %-45s %s[OK]%s   (%s)\n' \
                "$pattern" "${COLOR_GREEN:-}" "${COLOR_RESET:-}" "$(format_duration "$elapsed")"
            succeeded_patterns+=("$pattern")
        else
            printf '  %-45s %s[FAIL]%s (%s)\n' \
                "$pattern" "${COLOR_BOLD_RED:-}" "${COLOR_RESET:-}" "$(format_duration "$elapsed")"
            failed_patterns+=("$pattern")
            err "Pattern '$pattern' failed"
        fi
    done

    rm -rf "$status_dir"
    phdr

    info "Results: ${#succeeded_patterns[@]} succeeded, ${#failed_patterns[@]} failed"
    if [[ ${#failed_patterns[@]} -gt 0 ]]; then
        warn "Failed patterns: ${failed_patterns[*]}"
    fi

    # Export for manifest
    PATTERNS_SUCCEEDED=("${succeeded_patterns[@]}")
    PATTERNS_FAILED=("${failed_patterns[@]}")
}

# Arrays populated by run_all_patterns
declare -a PATTERNS_SUCCEEDED=()
declare -a PATTERNS_FAILED=()
