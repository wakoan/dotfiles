#!/usr/bin/env bash
set -eu

client="${1:-codex}"
today=$(date +%F)

case "$client" in
  codex)
    history="$HOME/.codex/history.jsonl"
    if [ -r "$history" ]; then
      sessions=$(awk -v day="$today" 'match($0, /"ts":[0-9]+/) { stamp=substr($0, RSTART + 5, RLENGTH - 5); if (strftime("%F", stamp) == day && match($0, /"session_id":"[^"]+"/)) seen[substr($0, RSTART + 14, RLENGTH - 15)] = 1 } END { for (id in seen) n++; print n + 0 }' "$history")
      records=$(awk -v day="$today" 'match($0, /"ts":[0-9]+/) { stamp=substr($0, RSTART + 5, RLENGTH - 5); if (strftime("%F", stamp) == day) n++ } END { print n + 0 }' "$history")
    else sessions=0; records=0; fi
    processes=$(pgrep -fc '[c]odex' || true)
    ;;
  claude)
    sessions=$(find "$HOME/.claude/projects" -type f -name '*.jsonl' -newermt "$today" 2>/dev/null | wc -l)
    records=$(find "$HOME/.claude/projects" -type f -name '*.jsonl' -newermt "$today" -exec cat {} + 2>/dev/null | wc -l)
    processes=$(pgrep -fc '[c]laude' || true)
    ;;
  antigravity)
    db=$(find "$HOME/.gemini/antigravity-cli/conversations" -type f -name '*.db' -print -quit 2>/dev/null)
    sessions=$([ -n "$db" ] && printf 1 || printf 0)
    records=$([ -n "$db" ] && sqlite3 "$db" 'select count(*) from steps;' 2>/dev/null || printf 0)
    processes=$(pgrep -fc '([a]ntigravity|[a]gentapi)' || true)
    ;;
  *) exit 2 ;;
esac

printf 'Sessions\t%s\nRecords\t%s\nProcesses\t%s\n' "$sessions" "$records" "$processes"

usage="$HOME/.local/state/omarchy/agents/usage/$client.json"
if [ "$client" = codex ] || [ "$client" = claude ]; then
  [ -r "$usage" ] || usage=""
  if [ -n "$usage" ]; then
    jq -r '.limits[]? | ["Limit", .label, ((.percent * 100) | round | tostring), (.resetsAt // "")] | @tsv' "$usage"
  fi
fi
