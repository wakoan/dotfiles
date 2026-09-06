#!/bin/bash
# One switcher for Hyprland windows and tmux panes.
#
# Picking a window focuses it. Picking a tmux pane focuses the terminal whose
# client is attached to that pane's session and then moves tmux to the pane,
# so a single keystroke reaches anything regardless of which side of the
# compositor/multiplexer boundary it lives on.
#
# Terminals hosting an attached tmux client are dropped from the window half
# of the list: their panes are already listed individually, and focusing any
# pane focuses the terminal anyway.

set -u

TMUX_BIN=/usr/bin/tmux
MENU=(wofi --dmenu -i --prompt "Switch to" --width 950 --height 560
      --style "$HOME/.config/wofi/switcher.css")

# Nerd Font glyphs, written as escapes so the codepoints survive editing.
WIN_ICON=$'\U000f05af'   # nf-md-window_maximize
WIN_TMUX_ICON=$'\U000f018d'  # nf-md-console

declare -A ACTION
declare -a LINES

add() { # add <label> <action>
    local label=$1 n=2
    # Two panes can share a title, and the menu is keyed by its visible text,
    # so make collisions unique rather than letting one shadow the other.
    while [[ -n ${ACTION[$label]:-} ]]; do
        label="$1 ($n)"
        ((n++))
    done
    ACTION[$label]=$2
    LINES+=("$label")
}

HYPR_JSON=$(hyprctl clients -j)

# Walk up from any process on a tty until a pid matches a Hyprland window.
# A tmux client's parent chain ends at the terminal that spawned it, which is
# the window we need to raise.
window_for_tty() {
    local tty=${1#/dev/} pid p addr
    for pid in $(ps -t "$tty" -o pid= 2>/dev/null); do
        p=$pid
        while [[ -n $p && $p != 1 ]]; do
            addr=$(jq -r --argjson x "$p" '.[]|select(.pid==$x)|.address' <<<"$HYPR_JSON")
            [[ -n $addr ]] && { echo "$addr"; return 0; }
            p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        done
    done
    return 1
}

HOSTS=" "
HAVE_TMUX=0
if $TMUX_BIN has-session 2>/dev/null; then
    HAVE_TMUX=1
    while read -r ctty _; do
        [[ -z $ctty ]] && continue
        if addr=$(window_for_tty "$ctty"); then
            HOSTS+="$addr "
        fi
    done < <($TMUX_BIN list-clients -F '#{client_tty} #{client_session}' 2>/dev/null)
fi

while IFS=$'\t' read -r addr ws class title; do
    [[ $HOSTS == *" $addr "* ]] && continue
    add "$WIN_ICON  ws$ws  ·  $class  ·  $title" "win:$addr"
done < <(jq -r '.[] | [.address, (.workspace.name|tostring), .class, .title] | @tsv' <<<"$HYPR_JSON")

if ((HAVE_TMUX)); then
    # Windows, not panes: a tmux window carries a name the user chose, which
    # identifies it far better than the pane titles the shell happens to set.
    while IFS=$'\t' read -r win label; do
        add "$WIN_TMUX_ICON  $label" "tmux:$win"
    done < <($TMUX_BIN list-windows -a -F $'#{window_id}\t#{session_name}:#{window_index}  ·  #{window_name}  ·  #{pane_current_command}')
fi

((${#LINES[@]})) || exit 0

CHOICE=$(printf '%s\n' "${LINES[@]}" | "${MENU[@]}") || exit 0
TARGET=${ACTION[$CHOICE]:-}
[[ -n $TARGET ]] || exit 0

case $TARGET in
win:*)
    hyprctl dispatch focuswindow "address:${TARGET#win:}"
    ;;
tmux:*)
    win=${TARGET#tmux:}
    session=$($TMUX_BIN display -pt "$win" '#{session_name}')

    # Prefer a client already on that session; any client will do otherwise.
    ctty=$($TMUX_BIN list-clients -F '#{client_tty} #{client_session}' |
        awk -v s="$session" '$2 == s { print $1; exit }')
    [[ -z $ctty ]] && ctty=$($TMUX_BIN list-clients -F '#{client_tty}' | head -n1)

    # Nothing attached anywhere: the session exists but has no terminal.
    if [[ -z $ctty ]]; then
        exec setsid ghostty -e "$TMUX_BIN" attach -t "$session"
    fi

    if addr=$(window_for_tty "$ctty"); then
        hyprctl dispatch focuswindow "address:$addr"
    fi
    $TMUX_BIN switch-client -c "$ctty" -t "$session"
    $TMUX_BIN select-window -t "$win"
    ;;
esac
