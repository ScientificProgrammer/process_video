# lib/config.sh -- Config file loading and option resolution
# Sourced by process_video. Do not execute directly.
# Depends on: ui.sh (debug, die), constants.sh (DEFAULT_ANALYSIS_PATTERNS)

[[ -n "${_PV_CONFIG_LOADED:-}" ]] && return 0
readonly _PV_CONFIG_LOADED=1

# Config file variables (populated by load_config)
# shellcheck disable=SC2034  # CFG_* vars used in option merging logic
CFG_MODEL="" CFG_VENDOR="" CFG_STRATEGY="" CFG_TEMPERATURE=""
CFG_SESSION="" CFG_RAW="" CFG_SLEEP="" CFG_JOBS=""
CFG_TIMESTAMPS="" CFG_SKIP_PREPROCESSING=""
CFG_PRESERVE_ARTIFACTS="" CFG_CONVERT_ARTIFACTS="" CFG_GENERATE_REPORT=""
declare -a CFG_PATTERNS=()
declare -a CFG_PANDOC_FORMATS=()

load_config() {
    local config_file="$1"
    [[ -f "$config_file" ]] || die "Config file not found: $config_file"
    jq empty "$config_file" 2>/dev/null || die "Invalid JSON in config file: $config_file"

    CFG_MODEL="$(jq -r '.process_video.fabric.model // empty' "$config_file")"
    CFG_VENDOR="$(jq -r '.process_video.fabric.vendor // empty' "$config_file")"
    CFG_STRATEGY="$(jq -r '.process_video.fabric.strategy // empty' "$config_file")"
    CFG_TEMPERATURE="$(jq -r '.process_video.fabric.temperature // empty' "$config_file")"
    CFG_SESSION="$(jq -r '.process_video.fabric.session // empty' "$config_file")"
    CFG_RAW="$(jq -r '.process_video.fabric.raw // empty' "$config_file")"
    CFG_SLEEP="$(jq -r '.process_video.fabric.sleep_between_patterns // empty' "$config_file")"
    CFG_JOBS="$(jq -r '.process_video.fabric.parallel_jobs // empty' "$config_file")"
    CFG_TIMESTAMPS="$(jq -r '.process_video.transcript.with_timestamps // empty' "$config_file")"
    CFG_SKIP_PREPROCESSING="$(jq -r '.process_video.transcript.skip_preprocessing // empty' "$config_file")"
    # shellcheck disable=SC2034  # Used in option merging
    CFG_PRESERVE_ARTIFACTS="$(jq -r '.process_video.output.preserve_artifacts // empty' "$config_file")"
    # shellcheck disable=SC2034
    CFG_CONVERT_ARTIFACTS="$(jq -r '.process_video.output.convert_artifacts // empty' "$config_file")"
    # shellcheck disable=SC2034
    CFG_GENERATE_REPORT="$(jq -r '.process_video.output.generate_report // empty' "$config_file")"

    mapfile -t CFG_PATTERNS < <(
        jq -r '.process_video.patterns[]? // empty' "$config_file" 2>/dev/null
    )
    mapfile -t CFG_PANDOC_FORMATS < <(
        jq -r '.process_video.output.pandoc_formats[]? // empty' "$config_file" 2>/dev/null
    )

    debug "Config loaded from: $config_file"
}

# ------------------------------------------------------------------------------
# Config Resolution (precedence: CLI > config > defaults)
# ------------------------------------------------------------------------------

# Effective option variables (used by the rest of the script)
OPT_MODEL="" OPT_VENDOR="" OPT_STRATEGY="" OPT_TEMPERATURE=""
OPT_SESSION="" OPT_RAW="" OPT_SLEEP="" OPT_JOBS=""
OPT_OUTPUT_DIR="" OPT_TIMESTAMPS="" OPT_SKIP_PREPROCESSING=""
OPT_NO_ARTIFACTS="" OPT_CONVERT_ARTIFACTS="" OPT_NO_REPORT=""
OPT_DRY_RUN="" OPT_VERBOSE="" OPT_QUIET="" OPT_NO_COLOR="" OPT_NO_LLM_SLUG=""
OPT_NO_EDITORIAL=""
declare -a OPT_PATTERNS=()
declare -a OPT_PANDOC_FORMATS=()

_resolve() {
    # Return first non-empty value from args
    local val
    for val in "$@"; do
        if [[ -n "$val" ]]; then
            printf '%s' "$val"
            return
        fi
    done
}

resolve_config() {
    OPT_MODEL="$(_resolve "$CLI_MODEL" "$CFG_MODEL" "claude-sonnet-4-5")"
    OPT_VENDOR="$(_resolve "$CLI_VENDOR" "$CFG_VENDOR" "Anthropic")"
    OPT_STRATEGY="$(_resolve "$CLI_STRATEGY" "$CFG_STRATEGY" "")"
    OPT_TEMPERATURE="$(_resolve "$CLI_TEMPERATURE" "$CFG_TEMPERATURE" "")"
    OPT_SESSION="$(_resolve "$CLI_SESSION" "$CFG_SESSION" "")"
    OPT_RAW="$(_resolve "$CFG_RAW" "true")"
    OPT_SLEEP="$(_resolve "$CFG_SLEEP" "0")"
    OPT_JOBS="$(_resolve "$CLI_JOBS" "$CFG_JOBS" "8")"
    OPT_OUTPUT_DIR="$CLI_OUTPUT_DIR"
    OPT_TIMESTAMPS="$(_resolve "$CLI_TIMESTAMPS" "$CFG_TIMESTAMPS" "false")"
    OPT_SKIP_PREPROCESSING="$(_resolve "$CLI_SKIP_PREPROCESSING" "$CFG_SKIP_PREPROCESSING" "false")"
    OPT_NO_LLM_SLUG="$CLI_NO_LLM_SLUG"
    OPT_NO_EDITORIAL="$CLI_NO_EDITORIAL"
    OPT_NO_ARTIFACTS="$CLI_NO_ARTIFACTS"
    OPT_CONVERT_ARTIFACTS="$(_resolve "$CLI_CONVERT_ARTIFACTS" "$CFG_CONVERT_ARTIFACTS" "false")"
    OPT_NO_REPORT="$CLI_NO_REPORT"
    OPT_DRY_RUN="$CLI_DRY_RUN"
    OPT_VERBOSE="$CLI_VERBOSE"
    OPT_QUIET="$CLI_QUIET"
    OPT_NO_COLOR="$CLI_NO_COLOR"

    # Patterns: CLI > config > defaults
    if [[ -n "$CLI_PATTERNS" ]]; then
        IFS=',' read -ra OPT_PATTERNS <<< "$CLI_PATTERNS"
    elif [[ ${#CFG_PATTERNS[@]} -gt 0 ]]; then
        OPT_PATTERNS=("${CFG_PATTERNS[@]}")
    else
        OPT_PATTERNS=("${DEFAULT_ANALYSIS_PATTERNS[@]}")
    fi

    # Pandoc formats: build from CLI flags + config
    OPT_PANDOC_FORMATS=()
    if [[ "$CLI_HTML" == "true" ]]; then OPT_PANDOC_FORMATS+=(html); fi
    if [[ "$CLI_DOCX" == "true" ]]; then OPT_PANDOC_FORMATS+=(docx); fi
    if [[ "$CLI_PDF" == "true" ]]; then OPT_PANDOC_FORMATS+=(pdf); fi
    if [[ ${#OPT_PANDOC_FORMATS[@]} -eq 0 ]] && [[ ${#CFG_PANDOC_FORMATS[@]} -gt 0 ]]; then
        OPT_PANDOC_FORMATS=("${CFG_PANDOC_FORMATS[@]}")
    fi
}
