#!/bin/bash
# One menu for everything: Hyprland windows, tmux windows, and installed apps.
#
# Things that already exist are listed first, applications after, so the same
# keystroke either takes you to a running thing or starts a new one -- you
# type a name without having to remember which of the two it is.
#
# Picking a tmux window focuses the terminal whose client is attached to that
# session and then moves tmux to the window, so the compositor/multiplexer
# split stops mattering. Terminals hosting an attached client are dropped from
# the window list, since their tmux windows are listed individually and
# focusing one raises the terminal anyway.

set -u

TMUX_BIN=/usr/bin/tmux
MENU=(wofi --dmenu -i --prompt "Go to" --width 950 --height 560
      --allow-images --define image_size=28
      # dmenu mode reorders by usage frequency, which overrides the deliberate
      # running-things-first ordering below; /dev/null disables that cache.
      --cache-file /dev/null
      --style "$HOME/.config/wofi/switcher.css")

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ICON_RESOLVER="$SCRIPT_DIR/switcher-icons.py"
TMUX_ICON_SRC="$HOME/.config/hypr/icons/tmux.svg"

declare -A ACTION
declare -a LINES

# wofi renders "img:<path>:text:<label>" as an icon beside the text when
# --allow-images is on, and returns the whole escaped string on selection
# (parse_action defaults to false), so the raw entry is a usable lookup key.
add() { # add <icon-path> <label> <action>
    local entry
    if [[ -n $1 ]]; then
        entry="img:$1:text:$2"
    else
        entry=$2
    fi
    local n=2 base=$entry
    # Two entries can share a label; make collisions unique rather than
    # letting one shadow another. The suffix lands on the text, which is
    # last, so it cannot corrupt the image escape.
    while [[ -n ${ACTION[$entry]:-} ]]; do
        entry="$base ($n)"
        ((n++))
    done
    ACTION[$entry]=$3
    LINES+=("$entry")
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

# --- running things -------------------------------------------------------

# One resolver call for every class on screen plus the app list; starting a
# Python interpreter is ~200ms, so it must not happen per entry.
mapfile -t WM_CLASSES < <(jq -r '.[].class' <<<"$HYPR_JSON" | sort -u)
RESOLVER_ARGS=(--icon application-x-executable --file "$TMUX_ICON_SRC")
for c in "${WM_CLASSES[@]}"; do
    [[ -n $c ]] && RESOLVER_ARGS+=(--class "$c")
done

TMUX_ICON=""
declare -A CLASS_ICON
declare -a APP_ROWS
FALLBACK_ICON=""
while IFS=$'\t' read -r kind f1 f2 f3 f4; do
    case $kind in
    CLS) CLASS_ICON[$f1]=$f2 ;;
    APP) APP_ROWS+=("$f1"$'\t'"$f2"$'\t'"$f3"$'\t'"$f4") ;;
    ICON) FALLBACK_ICON=$f2 ;;
    FILE) TMUX_ICON=$f2 ;;
    esac
done < <(python3 "$ICON_RESOLVER" "${RESOLVER_ARGS[@]}" 2>/dev/null)

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
    icon=${CLASS_ICON[$class]:-}
    [[ -z $icon ]] && icon=$FALLBACK_ICON
    add "$icon" "$title  ·  $class  ·  ws$ws" "win:$addr"
done < <(jq -r '.[] | [.address, (.workspace.name|tostring), .class, .title] | @tsv' <<<"$HYPR_JSON")

if ((HAVE_TMUX)); then
    # Windows, not panes: a tmux window carries a name the user chose, which
    # identifies it far better than the pane titles the shell happens to set.
    while IFS=$'\t' read -r win label; do
        add "$TMUX_ICON" "$label" "tmux:$win"
    done < <($TMUX_BIN list-windows -a -F $'#{window_id}\t#{session_name}:#{window_index}  ·  #{window_name}  ·  #{pane_current_command}')
fi

# --- installed apps -------------------------------------------------------

# Rows come from the resolver, which uses Gio.AppInfo: that honours NoDisplay,
# Hidden and OnlyShowIn/NotShowIn, which a hand-rolled .desktop parse gets
# wrong, and is already sorted by name.
for row in "${APP_ROWS[@]:-}"; do
    [[ -z $row ]] && continue
    IFS=$'\t' read -r file icon name generic <<<"$row"
    [[ -z $name ]] && continue
    [[ -z $icon ]] && icon=$FALLBACK_ICON
    label=$name
    [[ -n $generic ]] && label+="  ·  $generic"
    add "$icon" "$label" "app:$file"
done

# --- pick and act ---------------------------------------------------------

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

    # The session exists but has no terminal anywhere: give it one.
    if [[ -z $ctty ]]; then
        exec setsid ghostty -e "$TMUX_BIN" attach -t "$session"
    fi

    if addr=$(window_for_tty "$ctty"); then
        hyprctl dispatch focuswindow "address:$addr"
    fi
    $TMUX_BIN switch-client -c "$ctty" -t "$session"
    $TMUX_BIN select-window -t "$win"
    ;;
app:*)
    # gio handles Exec field codes, Terminal=true and DBusActivatable, none of
    # which a naive Exec= parse gets right.
    exec setsid gio launch "${TARGET#app:}" >/dev/null 2>&1
    ;;
esac
