# lib/output.sh -- Report assembly, pandoc conversion, manifest generation, cleanup
# Sourced by process_video. Do not execute directly.
# Depends on: ui.sh, config.sh, video.sh, processing.sh, constants.sh

[[ -n "${_PV_OUTPUT_LOADED:-}" ]] && return 0
readonly _PV_OUTPUT_LOADED=1

# ------------------------------------------------------------------------------
# Report Assembly
# ------------------------------------------------------------------------------

assemble_report() {
    if [[ "$OPT_NO_REPORT" == "true" ]]; then
        debug "Skipping report assembly (--no-report)"
        return 0
    fi

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "[dry-run] Would assemble combined report"
        return 0
    fi

    info "Assembling report..."
    local start_time=$SECONDS
    local report_file="${OUTPUT_DIR}/${BASE_FILENAME}.report.md"
    local artifacts_dir="${OUTPUT_DIR}/artifacts/md"

    # YAML front matter
    cat > "$report_file" <<FRONTMATTER
---
title: "Video Analysis Report"
subtitle: "${VIDEO_TITLE}"
author: "${SCRIPT_NAME} v${SCRIPT_VERSION}"
date: "$(date '+%Y-%m-%d %H:%M:%S')"
video_url: "${VIDEO_URL}"
video_id: "${VIDEO_ID}"
channel: "${CHANNEL_NAME}"
model: "${OPT_MODEL}"
---

# Video Analysis Report

| Field | Value |
|-------|-------|
| **Title** | ${VIDEO_TITLE//|/-} |
| **Channel** | ${CHANNEL_NAME} |
| **Upload Date** | ${UPLOAD_DATE} |
| **Video ID** | ${VIDEO_ID} |
| **URL** | ${VIDEO_URL} |
| **Model** | ${OPT_MODEL} |
| **Processed** | $(date '+%Y-%m-%d %H:%M:%S') |
| **Patterns** | ${#PATTERNS_SUCCEEDED[@]} succeeded / ${#OPT_PATTERNS[@]} total |

FRONTMATTER

    # Build TOC
    printf '\n## Table of Contents\n\n' >> "$report_file"

    local prev_tier=""
    local entry tier pattern_name title anchor
    for entry in "${REPORT_SECTIONS[@]}"; do
        IFS='|' read -r tier pattern_name title <<< "$entry"
        local artifact_file="${artifacts_dir}/${BASE_FILENAME}.${pattern_name}.md"
        [[ -f "$artifact_file" ]] && [[ -s "$artifact_file" ]] || continue

        # Tier heading in TOC
        if [[ "$tier" != "$prev_tier" ]] && [[ "$tier" != "executive" ]]; then
            anchor="$(printf '%s' "${TIER_NAMES[$tier]}" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')"
            printf -- '- [%s](#%s)\n' "${TIER_NAMES[$tier]}" "$anchor" >> "$report_file"
            prev_tier="$tier"
        fi

        anchor="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')"
        if [[ "$tier" == "executive" ]]; then
            printf -- '- [%s](#%s)\n' "$title" "$anchor" >> "$report_file"
        else
            printf -- '  - [%s](#%s)\n' "$title" "$anchor" >> "$report_file"
        fi
    done

    # Build content sections
    printf '\n---\n\n' >> "$report_file"
    prev_tier=""

    for entry in "${REPORT_SECTIONS[@]}"; do
        IFS='|' read -r tier pattern_name title <<< "$entry"
        local artifact_file="${artifacts_dir}/${BASE_FILENAME}.${pattern_name}.md"
        [[ -f "$artifact_file" ]] && [[ -s "$artifact_file" ]] || continue

        # Tier H2 heading
        if [[ "$tier" != "$prev_tier" ]] && [[ "$tier" != "executive" ]]; then
            printf '\n## %s\n\n' "${TIER_NAMES[$tier]}" >> "$report_file"
            prev_tier="$tier"
        fi

        # Section heading
        if [[ "$tier" == "executive" ]]; then
            printf '## %s\n\n' "$title" >> "$report_file"
        else
            printf '### %s\n\n' "$title" >> "$report_file"
        fi

        cat "$artifact_file" >> "$report_file"
        printf '\n\n---\n\n' >> "$report_file"
    done

    local elapsed=$(( SECONDS - start_time ))
    info "Report assembled: $report_file $(format_duration $elapsed)"
}

# ------------------------------------------------------------------------------
# Pandoc Conversion
# ------------------------------------------------------------------------------

convert_report() {
    [[ ${#OPT_PANDOC_FORMATS[@]} -eq 0 ]] && return 0

    local report_md="${OUTPUT_DIR}/${BASE_FILENAME}.report.md"
    [[ -f "$report_md" ]] || { warn "No report.md to convert"; return 0; }

    if ! command -v pandoc &>/dev/null; then
        warn "pandoc not found; skipping format conversions"
        return 0
    fi

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "[dry-run] Would convert report to: ${OPT_PANDOC_FORMATS[*]}"
        return 0
    fi

    local fmt outfile
    for fmt in "${OPT_PANDOC_FORMATS[@]}"; do
        outfile="${OUTPUT_DIR}/${BASE_FILENAME}.report.${fmt}"
        info "Converting report to ${fmt^^}: $(basename "$outfile")"

        local -a pandoc_args=(
            "$report_md"
            --from=markdown
            --standalone
            --toc
            --toc-depth=3
            -o "$outfile"
        )

        # Format-specific options
        case "$fmt" in
            html) pandoc_args+=(--to=html5 --self-contained) ;;
            pdf)  ;; # pandoc auto-detects PDF via extension
            docx) ;;
        esac

        pandoc "${pandoc_args[@]}" 2>>"$LOG_FILE" || {
            err "pandoc conversion to $fmt failed"
            continue
        }
        debug "  Created: $outfile"
    done
}

convert_artifacts() {
    [[ "$OPT_CONVERT_ARTIFACTS" != "true" ]] && return 0
    [[ ${#OPT_PANDOC_FORMATS[@]} -eq 0 ]] && return 0

    if ! command -v pandoc &>/dev/null; then
        warn "pandoc not found; skipping artifact conversion"
        return 0
    fi

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        info "[dry-run] Would convert ${#PATTERNS_SUCCEEDED[@]} artifacts to: ${OPT_PANDOC_FORMATS[*]}"
        return 0
    fi

    local fmt
    for fmt in "${OPT_PANDOC_FORMATS[@]}"; do
        local fmt_dir="${OUTPUT_DIR}/artifacts/${fmt}"
        mkdir -p "$fmt_dir"

        info "Converting artifacts to ${fmt^^}..."
        local pattern md_file out_file
        for pattern in "${PATTERNS_SUCCEEDED[@]}"; do
            md_file="${OUTPUT_DIR}/artifacts/md/${BASE_FILENAME}.${pattern}.md"
            out_file="${fmt_dir}/${BASE_FILENAME}.${pattern}.${fmt}"

            [[ -f "$md_file" ]] || continue

            pandoc "$md_file" --from=markdown --standalone -o "$out_file" 2>>"$LOG_FILE" || {
                err "  Failed to convert $pattern to $fmt"
                continue
            }
        done
        debug "  Artifacts converted to $fmt: $fmt_dir"
    done
}

# ------------------------------------------------------------------------------
# Manifest Generation
# ------------------------------------------------------------------------------

generate_manifest() {
    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        debug "[dry-run] Would generate run manifest"
        return 0
    fi

    local manifest_file="${OUTPUT_DIR}/config/${BASE_FILENAME}.run_manifest.json"
    local end_time
    end_time="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    local succeeded_json failed_json requested_json pandoc_json
    succeeded_json="$(printf '%s\n' "${PATTERNS_SUCCEEDED[@]}" | jq -R . | jq -s .)"
    if [[ ${#PATTERNS_FAILED[@]} -gt 0 ]]; then
        failed_json="$(printf '%s\n' "${PATTERNS_FAILED[@]}" | jq -R . | jq -s .)"
    else
        failed_json="[]"
    fi
    requested_json="$(printf '%s\n' "${OPT_PATTERNS[@]}" | jq -R . | jq -s .)"
    if [[ ${#OPT_PANDOC_FORMATS[@]} -gt 0 ]]; then
        pandoc_json="$(printf '%s\n' "${OPT_PANDOC_FORMATS[@]}" | jq -R . | jq -s .)"
    else
        pandoc_json="[]"
    fi

    jq -n \
        --arg version "$SCRIPT_VERSION" \
        --arg ts_start "$RUN_START_TIME" \
        --arg ts_end "$end_time" \
        --argjson duration "$(( SECONDS - RUN_START_SECONDS ))" \
        --arg video_url "$VIDEO_URL" \
        --arg video_id "$VIDEO_ID" \
        --arg video_title "$VIDEO_TITLE" \
        --arg channel "$CHANNEL_NAME" \
        --arg upload_date "$UPLOAD_DATE" \
        --arg model "$OPT_MODEL" \
        --arg vendor "${OPT_VENDOR:-null}" \
        --arg strategy "${OPT_STRATEGY:-null}" \
        --arg config_file "${CLI_CONFIG:-null}" \
        --argjson patterns_requested "$requested_json" \
        --argjson patterns_succeeded "$succeeded_json" \
        --argjson patterns_failed "$failed_json" \
        --arg output_dir "$OUTPUT_DIR" \
        --argjson report_generated "$([ "$OPT_NO_REPORT" != "true" ] && echo true || echo false)" \
        --argjson pandoc_formats "$pandoc_json" \
        '{
            script_version: $version,
            timestamp_start: $ts_start,
            timestamp_end: $ts_end,
            duration_seconds: $duration,
            video_url: $video_url,
            video_id: $video_id,
            video_title: $video_title,
            channel_name: $channel,
            upload_date: $upload_date,
            model: $model,
            vendor: (if $vendor == "null" then null else $vendor end),
            strategy: (if $strategy == "null" then null else $strategy end),
            config_file: (if $config_file == "null" then null else $config_file end),
            patterns_requested: $patterns_requested,
            patterns_succeeded: $patterns_succeeded,
            patterns_failed: $patterns_failed,
            output_directory: $output_dir,
            report_generated: $report_generated,
            pandoc_formats: $pandoc_formats
        }' > "$manifest_file"

    debug "Manifest: $manifest_file"
}

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------

cleanup() {
    # Remove temp files
    rm -f "$OUTPUT_DIR"/.tmp_* 2>/dev/null || true

    # Remove artifacts if requested
    if [[ "$OPT_NO_ARTIFACTS" == "true" ]] && [[ -d "$OUTPUT_DIR/artifacts" ]]; then
        info "Removing artifacts (--no-artifacts)"
        rm -rf "$OUTPUT_DIR/artifacts"
    fi
}

_cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]] && [[ -n "${OUTPUT_DIR:-}" ]] && [[ -d "${OUTPUT_DIR:-}" ]]; then
        err "Script terminated with exit code $exit_code"
        err "Partial output may be in: $OUTPUT_DIR"
    fi
    rm -f "${OUTPUT_DIR:-.}"/.tmp_* 2>/dev/null || true
}
