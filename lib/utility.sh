# lib/utility.sh -- Utility modes (init-config, list-patterns, verify-patterns)
# Sourced by process_video. Do not execute directly.
# Depends on: ui.sh, config.sh, constants.sh

[[ -n "${_PV_UTILITY_LOADED:-}" ]] && return 0
readonly _PV_UTILITY_LOADED=1

do_init_config() {
    local output_target="$1"
    local config_content
    config_content="$(cat <<'CONFIG_EOF'
{
  "process_video": {
    "fabric": {
      "model": "claude-sonnet-4-5",
      "vendor": "Anthropic",
      "strategy": null,
      "raw": true,
      "temperature": null,
      "session": null,
      "sleep_between_patterns": 0,
      "parallel_jobs": 8,
      "llm_slug": true
    },
    "patterns": [
      "analyze_claims",
      "analyze_presentation",
      "analyze_tech_impact",
      "analyze_personality",
      "extract_wisdom_large",
      "extract_core_message",
      "extract_ideas",
      "extract_insights",
      "extract_business_ideas",
      "extract_recommendations",
      "extract_predictions",
      "extract_controversial_ideas",
      "extract_extraordinary_claims",
      "extract_questions",
      "create_ai_jobs_analysis",
      "prepare_7s_strategy",
      "extract_alpha",
      "youtube_summary",
      "create_summary",
      "summarize",
      "find_logical_fallacies",
      "explain_terms"
    ],
    "transcript": {
      "with_timestamps": false,
      "skip_preprocessing": false
    },
    "output": {
      "preserve_artifacts": true,
      "convert_artifacts": false,
      "generate_report": true,
      "pandoc_formats": []
    }
  }
}
CONFIG_EOF
)"

    if [[ "$output_target" == "-" ]]; then
        printf '%s\n' "$config_content"
    else
        if [[ -f "$output_target" ]]; then
            die "Config file already exists: $output_target (will not overwrite)"
        fi
        printf '%s\n' "$config_content" > "$output_target"
        info "Config file created: $output_target"
    fi
}

do_list_patterns() {
    printf '%s%s v%s -- Effective Pattern Set%s\n\n' \
        "${COLOR_BOLD_WHITE:-}" "$SCRIPT_NAME" "$SCRIPT_VERSION" "${COLOR_RESET:-}"

    printf '%sPreprocessing:%s\n' "${COLOR_BOLD_CYAN:-}" "${COLOR_RESET:-}"
    local p
    for p in "${DEFAULT_PREPROCESSING_PATTERNS[@]}"; do
        printf '  %s\n' "$p"
    done

    printf '\n%sAnalysis (%d patterns):%s\n' "${COLOR_BOLD_CYAN:-}" "${#OPT_PATTERNS[@]}" "${COLOR_RESET:-}"
    local idx=0
    for p in "${OPT_PATTERNS[@]}"; do
        ((idx++)) || true
        printf '  %2d. %s\n' "$idx" "$p"
    done

    printf '\n%sTotal API calls per video: %d%s\n' \
        "${COLOR_BOLD_WHITE:-}" "$(( ${#DEFAULT_PREPROCESSING_PATTERNS[@]} + ${#OPT_PATTERNS[@]} ))" "${COLOR_RESET:-}"
}

do_verify_patterns() {
    printf '%s%s v%s -- Pattern Verification%s\n\n' \
        "${COLOR_BOLD_WHITE:-}" "$SCRIPT_NAME" "$SCRIPT_VERSION" "${COLOR_RESET:-}"
    printf '%sPatterns directory:%s %s\n\n' \
        "${COLOR_BOLD_WHITE:-}" "${COLOR_RESET:-}" "$FABRIC_PATTERN_DIR"

    local all_patterns=("${DEFAULT_PREPROCESSING_PATTERNS[@]}" "${OPT_PATTERNS[@]}")
    local missing=0 pattern test_file

    printf '%-35s %s\n' "PATTERN" "STATUS"
    phdr

    for pattern in "${all_patterns[@]}"; do
        test_file="${FABRIC_PATTERN_DIR}/${pattern}/system.md"
        printf '%-35s ' "$pattern"
        if [[ -f "$test_file" ]]; then
            printf '%sFound%s\n' "${COLOR_GREEN:-}" "${COLOR_RESET:-}"
        else
            printf '%sNOT FOUND%s\n' "${COLOR_BOLD_RED:-}" "${COLOR_RESET:-}"
            ((missing++)) || true
        fi
    done

    phdr
    if [[ $missing -gt 0 ]]; then
        printf '%s%d pattern(s) missing%s\n' "${COLOR_BOLD_RED:-}" "$missing" "${COLOR_RESET:-}"
        exit 1
    else
        printf '%sAll %d patterns verified%s\n' "${COLOR_GREEN:-}" "${#all_patterns[@]}" "${COLOR_RESET:-}"
    fi
}
