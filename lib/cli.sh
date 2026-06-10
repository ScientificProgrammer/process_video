# lib/cli.sh -- Usage text and argument parsing
# Sourced by process_video. Do not execute directly.
# Depends on: ui.sh (die), constants (SCRIPT_VERSION, SCRIPT_NAME)

[[ -n "${_PV_CLI_LOADED:-}" ]] && return 0
readonly _PV_CLI_LOADED=1

show_usage() {
    cat <<'USAGE'
Usage: process_video [OPTIONS] <YOUTUBE_URL_OR_ID>

Extract a YouTube video transcript and process it through fabric patterns
to generate a structured analysis report.

Arguments:
  YOUTUBE_URL_OR_ID    YouTube URL or 11-character video ID

Options:
  -h, --help               Show this help message and exit
      --version            Print version and exit

  Configuration:
  -c, --config FILE        Path to JSON config file
  -m, --model MODEL        LLM model override (default: claude-sonnet-4-5)
  -V, --vendor VENDOR      LLM vendor override
      --strategy STRAT     Reasoning strategy (cot, tot, aot, etc.)
  -t, --temperature FLOAT  LLM temperature
  -p, --patterns p1,p2     Comma-separated pattern list override
  -S, --session NAME       Fabric session name
  -j, --jobs N             Parallel pattern jobs (default: 8)

  Output:
  -O, --output-dir DIR     Output directory (default: auto-generated)
      --html               Also generate HTML report via pandoc
      --docx               Also generate DOCX report via pandoc
      --pdf                Also generate PDF report via pandoc
      --convert-artifacts   Convert individual artifacts to pandoc formats too
      --no-artifacts       Remove artifact files after report assembly
      --no-report          Skip combined report (produce artifacts only)

  Transcript:
      --timestamps         Fetch transcript with timestamps
      --skip-preprocessing Skip clean_text/fix_typos preprocessing
      --no-llm-slug        Use mechanical slugs instead of LLM-generated
      --no-editorial       Skip editorial consolidation pass on report

  Display:
      --no-color           Disable color output
  -v, --verbose            Verbose output
  -q, --quiet              Suppress progress output (errors still shown)

  Utility:
  -n, --dry-run            Show what would be done without executing
      --init-config [FILE] Generate a default config file (default: stdout)
      --list-patterns      List the effective pattern set and exit
      --verify-patterns    Verify all patterns exist and exit

Config Precedence:
  CLI flags > JSON config file (--config) > built-in defaults

Session Naming:
  If no session is specified via --session or config file, a default session
  name is auto-generated: YYYYMMDD_HHMMSS.process_video.{VIDEO_ID}

Examples:
  process_video https://youtu.be/JKk77rzOL34
  process_video --model claude-sonnet-4-5 --vendor Anthropic --pdf JKk77rzOL34
  process_video -j 4 --model claude-sonnet-4-5 https://youtu.be/JKk77rzOL34
  process_video --config my_config.json --verbose https://youtu.be/JKk77rzOL34
  process_video --patterns analyze_claims,extract_wisdom_large JKk77rzOL34
  process_video --init-config > my_config.json
  process_video --list-patterns
  process_video --dry-run https://youtu.be/JKk77rzOL34

Version: VERSION_PLACEHOLDER
USAGE
}

parse_args() {
    # CLI override variables (empty = not set via CLI)
    CLI_CONFIG=""
    CLI_MODEL=""
    CLI_VENDOR=""
    CLI_STRATEGY=""
    CLI_TEMPERATURE=""
    CLI_PATTERNS=""
    CLI_SESSION=""
    CLI_JOBS=""
    CLI_OUTPUT_DIR=""
    CLI_HTML="false"
    CLI_DOCX="false"
    CLI_PDF="false"
    CLI_CONVERT_ARTIFACTS="false"
    CLI_NO_ARTIFACTS="false"
    CLI_NO_REPORT="false"
    CLI_NO_COLOR="false"
    CLI_DRY_RUN="false"
    CLI_VERBOSE="false"
    CLI_QUIET="false"
    CLI_TIMESTAMPS="false"
    CLI_SKIP_PREPROCESSING="false"
    CLI_NO_LLM_SLUG="false"
    CLI_NO_EDITORIAL="false"
    CLI_LIST_PATTERNS="false"
    CLI_VERIFY_PATTERNS="false"
    CLI_INIT_CONFIG=""
    VIDEO_INPUT=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)                show_usage | sed "s/VERSION_PLACEHOLDER/${SCRIPT_VERSION}/"; exit 0 ;;
            --version)                printf '%s v%s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
            -c|--config)              CLI_CONFIG="${2:?--config requires a FILE argument}"; shift 2 ;;
            --config=*)               CLI_CONFIG="${1#*=}"; shift ;;
            -m|--model)               CLI_MODEL="${2:?--model requires a MODEL argument}"; shift 2 ;;
            --model=*)                CLI_MODEL="${1#*=}"; shift ;;
            -V|--vendor)              CLI_VENDOR="${2:?--vendor requires a VENDOR argument}"; shift 2 ;;
            --vendor=*)               CLI_VENDOR="${1#*=}"; shift ;;
            --strategy)               CLI_STRATEGY="${2:?--strategy requires a STRATEGY argument}"; shift 2 ;;
            --strategy=*)             CLI_STRATEGY="${1#*=}"; shift ;;
            -t|--temperature)         CLI_TEMPERATURE="${2:?--temperature requires a FLOAT argument}"; shift 2 ;;
            --temperature=*)          CLI_TEMPERATURE="${1#*=}"; shift ;;
            -p|--patterns)            CLI_PATTERNS="${2:?--patterns requires a comma-separated list}"; shift 2 ;;
            --patterns=*)             CLI_PATTERNS="${1#*=}"; shift ;;
            -S|--session)             CLI_SESSION="${2:?--session requires a NAME argument}"; shift 2 ;;
            --session=*)              CLI_SESSION="${1#*=}"; shift ;;
            -j|--jobs)                CLI_JOBS="${2:?--jobs requires a NUMBER argument}"; shift 2 ;;
            --jobs=*)                 CLI_JOBS="${1#*=}"; shift ;;
            -O|--output-dir)          CLI_OUTPUT_DIR="${2:?--output-dir requires a DIR argument}"; shift 2 ;;
            --output-dir=*)           CLI_OUTPUT_DIR="${1#*=}"; shift ;;
            --html)                   CLI_HTML="true"; shift ;;
            --docx)                   CLI_DOCX="true"; shift ;;
            --pdf)                    CLI_PDF="true"; shift ;;
            --convert-artifacts)      CLI_CONVERT_ARTIFACTS="true"; shift ;;
            --no-artifacts)           CLI_NO_ARTIFACTS="true"; shift ;;
            --no-report)              CLI_NO_REPORT="true"; shift ;;
            --no-color)               CLI_NO_COLOR="true"; shift ;;
            -n|--dry-run)             CLI_DRY_RUN="true"; shift ;;
            -v|--verbose)             CLI_VERBOSE="true"; shift ;;
            -q|--quiet)               CLI_QUIET="true"; shift ;;
            --timestamps)             CLI_TIMESTAMPS="true"; shift ;;
            --skip-preprocessing)     CLI_SKIP_PREPROCESSING="true"; shift ;;
            --no-llm-slug)            CLI_NO_LLM_SLUG="true"; shift ;;
            --no-editorial)           CLI_NO_EDITORIAL="true"; shift ;;
            --init-config)
                # Next arg is optional output file; peek to see if it's a flag or file
                if [[ "${2:-}" == "" ]] || [[ "${2:-}" == -* ]]; then
                    CLI_INIT_CONFIG="-"  # stdout
                else
                    CLI_INIT_CONFIG="$2"; shift
                fi
                shift ;;
            --init-config=*)          CLI_INIT_CONFIG="${1#*=}"; shift ;;
            --list-patterns)          CLI_LIST_PATTERNS="true"; shift ;;
            --verify-patterns)        CLI_VERIFY_PATTERNS="true"; shift ;;
            --)                       shift; break ;;
            -*)                       die "Unknown option: $1. See --help." ;;
            *)
                if [[ -z "$VIDEO_INPUT" ]]; then
                    VIDEO_INPUT="$1"
                else
                    die "Unexpected argument: $1 (only one video URL/ID allowed)"
                fi
                shift ;;
        esac
    done

    # Consume remaining positional args after --
    if [[ $# -gt 0 ]] && [[ -z "$VIDEO_INPUT" ]]; then
        VIDEO_INPUT="$1"
        shift
    fi
    if [[ $# -gt 0 ]]; then
        die "Unexpected trailing arguments: $*"
    fi
}
