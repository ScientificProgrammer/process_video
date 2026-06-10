# lib/ui.sh -- Color setup, header printing, logging, and display utilities
# Sourced by process_video. Do not execute directly.

[[ -n "${_PV_UI_LOADED:-}" ]] && return 0
readonly _PV_UI_LOADED=1

# shellcheck disable=SC2034  # Colors used via variable expansion in logging functions
setup_colors() {
    if [[ "${OPT_NO_COLOR:-}" == "true" ]] || [[ "${NO_COLOR:-}" == "1" ]] || [[ ! -t 1 ]]; then
        COLOR_RED="" COLOR_GREEN="" COLOR_YELLOW="" COLOR_BLUE=""
        COLOR_BOLD_RED="" COLOR_BOLD_GREEN="" COLOR_BOLD_YELLOW=""
        COLOR_BOLD_BLUE="" COLOR_BOLD_WHITE="" COLOR_BOLD_CYAN=""
        COLOR_BOLD_MAGENTA="" COLOR_RESET="" COLOR_GRAY=""
    elif [[ -z "${COLOR_RESET:-}" ]]; then
        COLOR_RED=$'\e[0;31m'
        COLOR_GREEN=$'\e[0;32m'
        COLOR_YELLOW=$'\e[0;33m'
        COLOR_BLUE=$'\e[0;34m'
        COLOR_GRAY=$'\e[0;37m'
        COLOR_BOLD_RED=$'\e[1;31m'
        COLOR_BOLD_GREEN=$'\e[1;32m'
        COLOR_BOLD_YELLOW=$'\e[1;33m'
        COLOR_BOLD_BLUE=$'\e[1;34m'
        COLOR_BOLD_WHITE=$'\e[1;37m'
        COLOR_BOLD_CYAN=$'\e[1;36m'
        COLOR_BOLD_MAGENTA=$'\e[1;35m'
        COLOR_RESET=$'\e[0m'
    fi
}

# ------------------------------------------------------------------------------
# phdr (header printing) -- source or provide fallback
# ------------------------------------------------------------------------------

_phdr_impl() {
    local text="${1:-}"
    local width="${COLUMNS:-80}"
    local line
    printf -v line "%*s" "$width" ""
    printf "%s\n" "${line// /-}"
    if [[ -n "$text" ]]; then
        local -i padlen=$(( (width - ${#text} - 2) / 2 ))
        padlen=$(( padlen < 0 ? 0 : padlen ))
        local pad
        printf -v pad "%*s" "$padlen" ""
        printf "%s %s %s\n" "${pad// /-}" "$text" "${pad// /-}"
        printf "%s\n" "${line// /-}"
    fi
}

# Ensure COLUMNS is set (not available in non-interactive shells)
: "${COLUMNS:=80}"

if [[ -f "${HOME}/.local/bin/phdr.sh" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.local/bin/phdr.sh"
    # Wrap the sourced phdr to handle set -u with missing $1
    _orig_phdr="$(declare -f phdr)"
    eval "${_orig_phdr/phdr ()/_sourced_phdr ()}"
    phdr() { _sourced_phdr "${1:-}"; }
elif ! declare -f phdr &>/dev/null; then
    phdr() { _phdr_impl "${1:-}"; }
fi

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------

LOG_FILE="/dev/null"

log() {
    local level="$1" msg="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s [%-5s] %s\n' "$timestamp" "$level" "$msg" >> "$LOG_FILE"
}

die() {
    local msg="$1"
    local code="${2:-1}"
    log "FATAL" "$msg"
    printf '%s[FATAL]%s %s\n' "${COLOR_BOLD_RED:-}" "${COLOR_RESET:-}" "$msg" >&2
    exit "$code"
}

err() {
    local msg="$1"
    log "ERROR" "$msg"
    printf '%s[ERROR]%s %s\n' "${COLOR_BOLD_RED:-}" "${COLOR_RESET:-}" "$msg" >&2
}

warn() {
    local msg="$1"
    log "WARN" "$msg"
    [[ "${OPT_QUIET:-}" == "true" ]] && return 0
    printf '%s[WARN]%s %s\n' "${COLOR_BOLD_YELLOW:-}" "${COLOR_RESET:-}" "$msg" >&2
}

info() {
    local msg="$1"
    log "INFO" "$msg"
    [[ "${OPT_QUIET:-}" == "true" ]] && return 0
    printf '%s[INFO]%s %s\n' "${COLOR_GREEN:-}" "${COLOR_RESET:-}" "$msg"
}

debug() {
    local msg="$1"
    log "DEBUG" "$msg"
    [[ "${OPT_VERBOSE:-}" != "true" ]] && return 0
    printf '%s[DEBUG]%s %s\n' "${COLOR_BLUE:-}" "${COLOR_RESET:-}" "$msg"
}

format_duration() {
    local secs="$1"
    if (( secs >= 60 )); then
        printf '%dm %ds' $(( secs / 60 )) $(( secs % 60 ))
    else
        printf '%ds' "$secs"
    fi
}
