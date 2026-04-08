#!/usr/bin/env bash
# normalize_r128.sh — EBU R128 two-pass loudness normalization via FFmpeg
#
# Usage:
#   ./normalize_r128.sh [OPTIONS] input_file [output_file]
#
# Options:
#   -i <value>   Target integrated loudness in LUFS  (default: -23)
#   -t <value>   Target true peak in dBTP            (default: -1)
#   -r <value>   Target loudness range (LRA) in LU   (default: 18)
#   -o <dir>     Output directory                    (default: same as input)
#   -s <suffix>  Suffix appended before extension    (default: _EBU_R128(<target>LUFS))
#   -f           Force overwrite of existing output
#   -v           Verify output loudness after normalization
#   -h           Show this help message

set -euo pipefail

# Defaults (EBU R128 spec)
TARGET_IL=-23.0
TARGET_TP=-1.0
TARGET_LRA=18.0
OUTPUT_DIR=""
SUFFIX=""
CUSTOM_SUFFIX=false
FORCE=false
VERIFY=false

# Colours
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

check_deps() {
    command -v ffmpeg  >/dev/null 2>&1 || die "ffmpeg not found. Install it first."
    command -v ffprobe >/dev/null 2>&1 || die "ffprobe not found. Install it first."
    command -v jq      >/dev/null 2>&1 || die "jq not found. Install it first."
}

usage() {
    sed -n 's/^# //p' "$0" | head -12
    exit 0
}

require_number() {
    local name="$1"
    local value="$2"
    [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || die "$name must be numeric: $value"
}

default_suffix_for_target() {
    local target="$1"
    target="${target%\.0}"

    if [[ "$target" == "-23" ]]; then
        printf "_EBU_R128(%sLUFS)" "$target"
    else
        printf "_(%sLUFS)" "$target"
    fi
}

extract_loudnorm_json() {
    awk '/^[[:space:]]*\{[[:space:]]*$/ { in_block=1 }
         in_block { print }
         /^[[:space:]]*\}[[:space:]]*$/ && in_block { in_block=0 }'
}

measure_loudness() {
    local file="$1"

    ffmpeg -nostdin -hide_banner -v info \
        -i "$file" \
        -af "loudnorm=I=${TARGET_IL}:TP=${TARGET_TP}:LRA=${TARGET_LRA}:print_format=json" \
        -vn -sn -f null /dev/null 2>&1 | extract_loudnorm_json
}

probe_input() {
    PROBE_JSON=$(ffprobe -v error -select_streams a:0 \
        -show_entries stream=codec_name,codec_type,sample_rate,sample_fmt,bits_per_raw_sample,bits_per_sample,bit_rate,channels \
        -show_entries format=format_name,bit_rate \
        -of json "$INPUT")

    AUDIO_STREAMS=$(echo "$PROBE_JSON" | jq -r '.streams | length')
    [[ "$AUDIO_STREAMS" =~ ^[0-9]+$ ]] || die "Failed to parse ffprobe stream count."
    (( AUDIO_STREAMS > 0 )) || die "No audio stream found in input: $INPUT"

    INPUT_CODEC=$(echo "$PROBE_JSON" | jq -r '.streams[0].codec_name // empty')
    INPUT_SR=$(echo "$PROBE_JSON" | jq -r '.streams[0].sample_rate // empty')
    INPUT_FMT=$(echo "$PROBE_JSON" | jq -r '.streams[0].sample_fmt // empty')
    INPUT_BITS=$(echo "$PROBE_JSON" | jq -r '.streams[0].bits_per_raw_sample // .streams[0].bits_per_sample // empty')
    INPUT_BITRATE=$(echo "$PROBE_JSON" | jq -r '.streams[0].bit_rate // .format.bit_rate // empty')
    INPUT_CHANNELS=$(echo "$PROBE_JSON" | jq -r '.streams[0].channels // empty')
    INPUT_FORMAT=$(echo "$PROBE_JSON" | jq -r '.format.format_name // empty')

    [[ -n "$INPUT_CODEC" ]] || die "Could not determine input audio codec."
    [[ -n "$INPUT_SR" ]] || die "Could not determine input sample rate."

    if [[ -z "$INPUT_BITS" || "$INPUT_BITS" == "0" ]]; then
        case "$INPUT_FMT" in
            u8) INPUT_BITS=8 ;;
            s16|s16p) INPUT_BITS=16 ;;
            s24|s24p) INPUT_BITS=24 ;;
            s32|s32p|flt|fltp) INPUT_BITS=32 ;;
            dbl|dblp) INPUT_BITS=64 ;;
            *) INPUT_BITS="unknown" ;;
        esac
    fi
}

select_output_codec() {
    PRESERVES_BIT_DEPTH=true
    LOSSY_CODEC=false
    EXTRA_CODEC_ARGS=()

    case "$INPUT_CODEC" in
        pcm_u8)    OUT_CODEC="pcm_u8" ;;
        pcm_s16le) OUT_CODEC="pcm_s16le" ;;
        pcm_s16be) OUT_CODEC="pcm_s16be" ;;
        pcm_s24le) OUT_CODEC="pcm_s24le" ;;
        pcm_s24be) OUT_CODEC="pcm_s24be" ;;
        pcm_s32le) OUT_CODEC="pcm_s32le" ;;
        pcm_s32be) OUT_CODEC="pcm_s32be" ;;
        pcm_f32le) OUT_CODEC="pcm_f32le" ;;
        pcm_f32be) OUT_CODEC="pcm_f32be" ;;
        pcm_f64le) OUT_CODEC="pcm_f64le" ;;
        pcm_f64be) OUT_CODEC="pcm_f64be" ;;
        flac)
            OUT_CODEC="flac"
            case "$INPUT_BITS" in
                24) EXTRA_CODEC_ARGS=(-sample_fmt s32) ;;
                16) EXTRA_CODEC_ARGS=(-sample_fmt s16) ;;
            esac
            ;;
        alac) OUT_CODEC="alac" ;;
        mp3)
            OUT_CODEC="libmp3lame"
            LOSSY_CODEC=true
            PRESERVES_BIT_DEPTH=false
            [[ -n "$INPUT_BITRATE" ]] && EXTRA_CODEC_ARGS=(-b:a "$INPUT_BITRATE")
            ;;
        aac)
            OUT_CODEC="aac"
            LOSSY_CODEC=true
            PRESERVES_BIT_DEPTH=false
            [[ -n "$INPUT_BITRATE" ]] && EXTRA_CODEC_ARGS=(-b:a "$INPUT_BITRATE")
            ;;
        opus)
            OUT_CODEC="libopus"
            LOSSY_CODEC=true
            PRESERVES_BIT_DEPTH=false
            if [[ -n "$INPUT_BITRATE" ]]; then
                EXTRA_CODEC_ARGS=(-b:a "$INPUT_BITRATE")
            else
                EXTRA_CODEC_ARGS=(-b:a 192k)
            fi
            ;;
        vorbis)
            OUT_CODEC="libvorbis"
            LOSSY_CODEC=true
            PRESERVES_BIT_DEPTH=false
            [[ -n "$INPUT_BITRATE" ]] && EXTRA_CODEC_ARGS=(-b:a "$INPUT_BITRATE")
            ;;
        ac3)
            OUT_CODEC="ac3"
            LOSSY_CODEC=true
            PRESERVES_BIT_DEPTH=false
            [[ -n "$INPUT_BITRATE" ]] && EXTRA_CODEC_ARGS=(-b:a "$INPUT_BITRATE")
            ;;
        eac3)
            OUT_CODEC="eac3"
            LOSSY_CODEC=true
            PRESERVES_BIT_DEPTH=false
            [[ -n "$INPUT_BITRATE" ]] && EXTRA_CODEC_ARGS=(-b:a "$INPUT_BITRATE")
            ;;
        *) die "Unsupported or ambiguous codec for format-preserving normalization: $INPUT_CODEC" ;;
    esac
}

while getopts ":i:t:r:o:s:fvh" opt; do
    case $opt in
        i) TARGET_IL="$OPTARG" ;;
        t) TARGET_TP="$OPTARG" ;;
        r) TARGET_LRA="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        s) SUFFIX="$OPTARG"; CUSTOM_SUFFIX=true ;;
        f) FORCE=true ;;
        v) VERIFY=true ;;
        h) usage ;;
        :) die "Option -$OPTARG requires an argument." ;;
        \?) die "Unknown option: -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))

[[ $# -lt 1 ]] && die "No input file specified. Use -h for help."

require_number "Target integrated loudness" "$TARGET_IL"
require_number "Target true peak" "$TARGET_TP"
require_number "Target loudness range" "$TARGET_LRA"

if [[ "$CUSTOM_SUFFIX" == false ]]; then
    SUFFIX="$(default_suffix_for_target "$TARGET_IL")"
fi

INPUT="$1"
[[ -f "$INPUT" ]] || die "Input file not found: $INPUT"

INPUT_DIR="$(dirname "$INPUT")"
INPUT_BASE="$(basename "$INPUT")"
if [[ "$INPUT_BASE" == *.* ]]; then
    INPUT_NAME="${INPUT_BASE%.*}"
    INPUT_EXT="${INPUT_BASE##*.}"
else
    INPUT_NAME="$INPUT_BASE"
    INPUT_EXT=""
fi

if [[ $# -ge 2 ]]; then
    OUTPUT="$2"
else
    OUT_DIR="${OUTPUT_DIR:-$INPUT_DIR}"
    OUTPUT="${OUT_DIR}/${INPUT_NAME}${SUFFIX}${INPUT_EXT:+.${INPUT_EXT}}"
fi

[[ -f "$OUTPUT" && "$FORCE" == false ]] && \
    die "Output already exists: $OUTPUT\nUse -f to overwrite."

OUT_DIR_FINAL="$(dirname "$OUTPUT")"
mkdir -p "$OUT_DIR_FINAL" || die "Cannot create output directory: $OUT_DIR_FINAL"
[[ -w "$OUT_DIR_FINAL" ]] || die "Output directory is not writable: $OUT_DIR_FINAL"

check_deps
probe_input
select_output_codec

OUTPUT_DIRNAME="$(dirname "$OUTPUT")"
OUTPUT_BASENAME="$(basename "$OUTPUT")"
if [[ -n "$INPUT_EXT" ]]; then
    TMP_OUTPUT="${OUTPUT_DIRNAME}/.${OUTPUT_BASENAME%.*}.tmp.$$.${INPUT_EXT}"
else
    TMP_OUTPUT="${OUTPUT_DIRNAME}/.${OUTPUT_BASENAME}.tmp.$$"
fi
PASS2_LOG=$(mktemp)
trap 'rm -f "$TMP_OUTPUT" "$PASS2_LOG"' EXIT

if [[ "$FORCE" == true ]]; then
    OVERWRITE=(-y)
else
    OVERWRITE=(-n)
fi

echo
echo -e "${BOLD}EBU R128 Two-Pass Normalization${RESET}"
echo "────────────────────────────────────────"
echo -e "  Input   : $INPUT"
echo -e "  Output  : $OUTPUT"
echo -e "  Target  : IL=${TARGET_IL} LUFS  TP=${TARGET_TP} dBTP  LRA=${TARGET_LRA} LU"
echo -e "  Codec   : ${INPUT_CODEC} -> ${OUT_CODEC}"
echo -e "  Format  : ${INPUT_BITS}-bit / ${INPUT_SR} Hz / ${INPUT_CHANNELS:-?} ch"
echo "────────────────────────────────────────"
echo

log "Pass 1/2 — Analysing loudness..."
PASS1_JSON=$(measure_loudness "$INPUT")
[[ -n "$PASS1_JSON" ]] || die "Pass 1 failed — no loudnorm JSON output detected."

extract_json_field() {
    local field="$1"
    local value
    value=$(echo "$PASS1_JSON" | jq -r --arg f "$field" '.[$f] // empty') \
        || die "Pass 1 failed — could not parse JSON field: $field"
    [[ -n "$value" ]] || die "Pass 1 JSON missing expected field: $field"
    require_number "$field" "$value"
    printf '%s' "$value"
}

IL=$(extract_json_field "input_i")
MEASURED_LRA=$(extract_json_field "input_lra")
TP=$(extract_json_field "input_tp")
TH=$(extract_json_field "input_thresh")
OFF=$(extract_json_field "target_offset")

log "Measured — IL: ${IL} LUFS  LRA: ${MEASURED_LRA} LU  TP: ${TP} dBTP  Thresh: ${TH} LUFS  Offset: ${OFF} LU"

log "Pass 2/2 — Applying normalization..."
FILTER="loudnorm=I=${TARGET_IL}:TP=${TARGET_TP}:LRA=${TARGET_LRA}"
FILTER+=":measured_I=${IL}:measured_LRA=${MEASURED_LRA}:measured_TP=${TP}"
FILTER+=":measured_thresh=${TH}:offset=${OFF}:linear=true:print_format=json"

ffmpeg_args=(
    -nostdin
    -hide_banner
    "${OVERWRITE[@]}"
    -i "$INPUT"
    -map_metadata 0
    -map 0:a:0
    -map "0:v?"
    -c:v copy
    -af "$FILTER"
    -ar "$INPUT_SR"
    -c:a "$OUT_CODEC"
)

if (( ${#EXTRA_CODEC_ARGS[@]} > 0 )); then
    ffmpeg_args+=("${EXTRA_CODEC_ARGS[@]}")
fi

ffmpeg_args+=("$TMP_OUTPUT")

set +e
ffmpeg "${ffmpeg_args[@]}" 2>"$PASS2_LOG"
PASS2_RC=$?
set -e

if [[ $PASS2_RC -ne 0 ]]; then
    cat "$PASS2_LOG" >&2
    die "Pass 2 failed (ffmpeg exit code $PASS2_RC) — see output above."
fi

mv -f "$TMP_OUTPUT" "$OUTPUT"
rm -f "$PASS2_LOG"
trap - EXIT

if [[ "$VERIFY" == true ]]; then
    log "Verifying output loudness..."
    VERIFY_JSON=$(measure_loudness "$OUTPUT")

    if [[ -n "$VERIFY_JSON" ]]; then
        FINAL_IL=$(echo "$VERIFY_JSON" | jq -r '.input_i')
        FINAL_LRA=$(echo "$VERIFY_JSON" | jq -r '.input_lra')
        FINAL_TP=$(echo "$VERIFY_JSON" | jq -r '.input_tp')
        ok "Output    — IL: ${FINAL_IL} LUFS  LRA: ${FINAL_LRA} LU  TP: ${FINAL_TP} dBTP"
    else
        warn "Verification did not return loudnorm JSON output."
    fi
fi

if [[ "$PRESERVES_BIT_DEPTH" == false ]]; then
    warn "Input codec ${INPUT_CODEC} is lossy; format and sample rate were preserved, but bit depth cannot be meaningfully preserved after re-encoding."
fi

echo
ok "Done → $OUTPUT"
echo
