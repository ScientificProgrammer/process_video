# lib/constants.sh -- Pattern definitions, report structure, and shared constants
# Sourced by process_video. Do not execute directly.

[[ -n "${_PV_CONSTANTS_LOADED:-}" ]] && return 0
readonly _PV_CONSTANTS_LOADED=1

readonly FABRIC_PATTERN_DIR="${HOME}/.config/fabric/patterns"

# Default patterns: 2 preprocessing + 24 analysis
readonly -a DEFAULT_PREPROCESSING_PATTERNS=(
    clean_text
    fix_typos
)

readonly -a DEFAULT_ANALYSIS_PATTERNS=(
    analyze_claims
    analyze_presentation
    analyze_tech_impact
    analyze_personality
    extract_wisdom_large
    extract_core_message
    extract_ideas
    extract_insights
    extract_business_ideas
    extract_recommendations
    extract_predictions
    extract_controversial_ideas
    extract_extraordinary_claims
    extract_questions
    create_ai_jobs_analysis
    prepare_7s_strategy
    extract_alpha
    youtube_summary
    create_summary
    summarize
    find_logical_fallacies
    explain_terms
)

# Report section ordering: "tier|pattern_name|Display Title"
readonly -a REPORT_SECTIONS=(
    "executive|youtube_summary|Executive Summary"
    "analysis|analyze_claims|Claims Analysis"
    "analysis|analyze_presentation|Presentation Analysis"
    "analysis|analyze_tech_impact|Technology Impact Analysis"
    "analysis|analyze_personality|Personality Analysis"
    "extraction|extract_wisdom_large|Wisdom (Comprehensive)"
    "extraction|extract_core_message|Core Message"
    "extraction|extract_ideas|Ideas"
    "extraction|extract_insights|Insights"
    "extraction|extract_business_ideas|Business Ideas"
    "extraction|extract_recommendations|Recommendations"
    "extraction|extract_predictions|Predictions"
    "extraction|extract_controversial_ideas|Controversial Ideas"
    "extraction|extract_extraordinary_claims|Extraordinary Claims"
    "extraction|extract_questions|Questions Raised"
    "strategic|create_ai_jobs_analysis|AI Jobs Impact Analysis"
    "strategic|prepare_7s_strategy|McKinsey 7S Strategic Framework"
    "strategic|extract_alpha|Alpha Extraction"
    "summary|create_summary|Structured Summary"
    "summary|summarize|General Summary"
    "quality|find_logical_fallacies|Logical Fallacies"
    "reference|explain_terms|Key Terms Glossary"
)

# Tier display names
declare -A TIER_NAMES=(
    [executive]="Executive Summary"
    [analysis]="Core Analysis"
    [extraction]="Key Extractions"
    [strategic]="Strategic Intelligence"
    [summary]="Summaries"
    [quality]="Quality Assessment"
    [reference]="Reference"
)
