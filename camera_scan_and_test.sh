#!/usr/bin/env bash
set -Eeuo pipefail

# -------------------------------------------------------------------
# Lorex/Dahua/Hikvision RTSP scanner + interactive tester
#
# What it does:
#   1) Finds hosts with port 554 open on your subnet (or a subnet you pass).
#   2) For each host, tries a set of candidate RTSP URLs common to Lorex/Dahua/Hik.
#   3) Launches each candidate in mpv (low-latency), waits for you to close it.
#   4) Asks if the stream displayed correctly.
#   5) Collects your feedback and prints + saves a full report (CSV).
#
# Usage:
#   ./scan_lorex_streams.sh [-s SUBNET] [-u USERNAME] [-p PASSWORD] [-t SECONDS]
#
# Examples:
#   ./scan_lorex_streams.sh -u admin -p 'MyPa$$w0rd'
#   ./scan_lorex_streams.sh -s 192.168.86.0/24 -u admin -p lorexadmin -t 8
#
# Notes:
#   - If you omit -s, the script will try to auto-detect your primary /24.
#   - If your password contains URL-reserved characters (#, ?, @, /, &, %),
#     consider changing it or URL-encoding (this script sends raw credentials).
#   - You can press Ctrl+C anytime; partial results still save to CSV.
# -------------------------------------------------------------------

# -------- Config defaults (overridable via CLI) ---------------------
SUBNET=""
USER=""
PASS=""
MPV_TIMEOUT=10   # seconds mpv will try before giving up when the URL is bad (network timeout)
PLAY_MIN=0       # if > 0, mpv will auto-quit after this many seconds (for quick peeks); 0 = wait for manual close

# -------- Parse arguments -------------------------------------------
usage() {
  sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'
}

while getopts ":s:u:p:t:h" opt; do
  case "$opt" in
    s) SUBNET="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    t) MPV_TIMEOUT="${OPTARG}" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done

# -------- Dependency checks -----------------------------------------
need() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not found. Please install it."; exit 1; }
}
need nmap
need mpv

# 'column' is optional; we'll detect later.

# -------- Auto-detect subnet if not provided ------------------------
if [[ -z "$SUBNET" ]]; then
  # Try to detect the default interface's /24
  # We pick the first global IPv4 that isn't Docker/loopback and convert to a /24 CIDR.
  if ip -o -4 addr show scope global | awk '{print $4}' | grep -qE '.'; then
    # Grab the first IP, convert X.Y.Z.W/XX -> X.Y.Z.0/24
    IP_CIDR=$(ip -o -4 addr show scope global | awk 'NR==1{print $4}')
    BASE=$(echo "$IP_CIDR" | cut -d/ -f1 | awk -F. '{print $1"."$2"."$3".0"}')
    SUBNET="${BASE}/24"
    echo "Auto-detected subnet: ${SUBNET}"
  else
    echo "Could not auto-detect subnet. Use -s X.Y.Z.0/24"
    exit 1
  fi
fi

# -------- Prompt for credentials if not provided --------------------
if [[ -z "$USER" ]]; then
  read -rp "Camera username (e.g., admin): " USER
fi
if [[ -z "$PASS" ]]; then
  # -s for silent (no echo)
  read -rs -p "Camera password: " PASS
  echo
fi

# -------- Candidate RTSP URL templates ------------------------------
# For Lorex/Dahua (most common on Lorex): /cam/realmonitor?channel=1&subtype=N
# For Hikvision-line: /Streaming/Channels/101 (main) /102 (sub)
# You can add/remove patterns here if needed.
declare -a CANDIDATES=(
  'rtsp://__USER__:__PASS__@__HOST__:554/cam/realmonitor?channel=1&subtype=0'
  'rtsp://__USER__:__PASS__@__HOST__:554/cam/realmonitor?channel=1&subtype=1'
  'rtsp://__USER__:__PASS__@__HOST__:554/cam/realmonitor?channel=1&subtype=2'
  'rtsp://__USER__:__PASS__@__HOST__:554/Streaming/Channels/101'
  'rtsp://__USER__:__PASS__@__HOST__:554/Streaming/Channels/102'
)

# -------- Discover hosts with RTSP (554) open -----------------------
echo "Scanning ${SUBNET} for hosts with RTSP (port 554) open..."
NMAP_OUT=$(mktemp)
trap 'rm -f "$NMAP_OUT" "$REPORT_CSV" "$REPORT_TMP"' EXIT

# Use a fast nmap scan on port 554. You can add ,80 to help identify web UIs too.
nmap -n -p 554 --open --host-timeout 10s --max-retries 1 "$SUBNET" -oG "$NMAP_OUT" >/dev/null

# Extract IPs from the grepable output format
mapfile -t HOSTS < <(awk '/Ports: 554\/open/{print $2}' "$NMAP_OUT")

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "No hosts with port 554 open were found on ${SUBNET}."
  echo "Tip: If your cameras use a different subnet or are isolated, pass -s to target the right network."
  exit 0
fi

echo "Found ${#HOSTS[@]} host(s) with RTSP open:"
for h in "${HOSTS[@]}"; do echo "  - $h"; done
echo

# -------- Report storage --------------------------------------------
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
REPORT_CSV="rtsp_scan_report_${TIMESTAMP}.csv"
REPORT_TMP=$(mktemp)

# CSV Header
echo "timestamp,host,url,mpv_exit_code,user_feedback" > "$REPORT_CSV"

# Pretty report table we'll print at the end as well
printf "%-19s | %-15s | %-50s | %-4s | %-8s\n" "timestamp" "host" "url" "ec" "feedback" > "$REPORT_TMP"
printf -- "-------------------+-----------------+----------------------------------------------------+------+----------\n" >> "$REPORT_TMP"

# -------- Helper: run one candidate in mpv and ask for feedback -----
play_and_ask() {
  local url="$1"
  local host="$2"

  echo
  echo "Opening in mpv: $url"
  echo " - Close mpv when you've seen enough."
  echo " - If the URL is bad, mpv will exit quickly."
  echo

  # Build mpv command. We set a modest network-timeout to avoid hanging on dead URLs.
  # If PLAY_MIN > 0, mpv will auto-quit after that many seconds; otherwise you close it manually.
  if [[ "$PLAY_MIN" -gt 0 ]]; then
    mpv --no-config --profile=low-latency --rtsp-transport=tcp \
        --network-timeout="$MPV_TIMEOUT" --length="$PLAY_MIN" \
        "$url" || true
  else
    mpv --no-config --profile=low-latency --rtsp-transport=tcp \
        --network-timeout="$MPV_TIMEOUT" \
        "$url" || true
  fi

  local ec=$?
  local feedback="n"

  # Ask user for feedback ONLY if mpv started (even if it errored quickly, user may have seen something)
  read -rp "Did the stream display correctly? [y/N/s = skip host] " ans || true
  case "${ans:-}" in
    y|Y) feedback="y" ;;
    s|S) feedback="skip";;
    *)   feedback="n" ;;
  esac

  # Write to report files
  local ts
  ts=$(date +'%Y-%m-%d %H:%M:%S')
  # Escape double quotes in URL for CSV safety
  local safe_url=${url//\"/\"\"}
  echo "\"$ts\",\"$host\",\"$safe_url\",\"$ec\",\"$feedback\"" >> "$REPORT_CSV"
  printf "%-19s | %-15s | %-50s | %-4s | %-8s\n" "$ts" "$host" "$(echo "$url" | sed -E 's#://[^@]+@#://***:***@#')" "$ec" "$feedback" >> "$REPORT_TMP"

  echo "$feedback"
}

# -------- Iterate hosts and candidates ------------------------------
echo
echo "==================== BEGIN TESTS ===================="
for host in "${HOSTS[@]}"; do
  echo
  echo ">>> Testing host: $host"
  echo "-----------------------------------------------------"

  for template in "${CANDIDATES[@]}"; do
    url="${template/__HOST__/$host}"
    url="${url/__USER__/$USER}"
    url="${url/__PASS__/$PASS}"

    result=$(play_and_ask "$url" "$host")

    # If the user said 'skip', stop testing this host and move on
    if [[ "$result" == "skip" ]]; then
      echo "Skipping remaining candidates for $host."
      break
    fi
    # Otherwise continue to next candidate; the user asked to "try the next possible feed after I close mpv" – that's exactly what we do.
  done
done
echo "===================== END TESTS ====================="
echo

# -------- Final report ----------------------------------------------
echo "Results saved to: $REPORT_CSV"
echo
if command -v column >/dev/null 2>&1; then
  # Pretty table using 'column' if available
  column -t -s '|' "$REPORT_TMP"
else
  cat "$REPORT_TMP"
fi

echo
echo "Legend:"
echo "  ec = mpv exit code (0 often means clean exit; non-zero often means connection error)"
echo "  feedback = your input per URL: y = worked, n = did not display correctly, skip = you skipped rest of host"
echo
echo "Tips:"
echo "  - If nothing works for a host, try changing the camera's stream to H.264 and re-run."
echo "  - If your password has special characters (#, ?, @, &, /, %), consider URL-encoding or using a simpler test password."
echo "  - Add/remove URL patterns in the CANDIDATES array near the top as needed."
