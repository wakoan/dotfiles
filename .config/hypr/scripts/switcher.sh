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
      --style "$HOME/.config/wofi/switcher.css")

# Nerd Font glyphs, written as escapes so the codepoints survive editing.
WIN_ICON=$'\U000f05af'       # nf-md-window_maximize
WIN_TMUX_ICON=$'\U000f018d'  # nf-md-console
APP_ICON=$'\U000f003b'       # nf-md-apps

declare -A ACTION
declare -a LINES

add() { # add <label> <action>
    local label=$1 n=2
    # Two entries can share a label, and the menu is keyed by its visible
    # text, so make collisions unique rather than letting one shadow another.
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

# --- running things -------------------------------------------------------

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

# --- installed apps -------------------------------------------------------

# Directories in XDG precedence order; the first .desktop file for a given
# basename wins, so a user override shadows the system copy.
APP_DIRS=(
    "$HOME/.local/share/applications"
    /usr/local/share/applications
    /usr/share/applications
    "$HOME/.local/share/flatpak/exports/share/applications"
    /var/lib/flatpak/exports/share/applications
)

mapfile -t DESKTOP_FILES < <(
    for d in "${APP_DIRS[@]}"; do
        [[ -d $d ]] && find "$d" -name '*.desktop' -type f 2>/dev/null | sort
    done
)

if ((${#DESKTOP_FILES[@]})); then
    declare -A SEEN
    # One awk pass over every file rather than one process per file. Only the
    # [Desktop Entry] group counts; localised keys (Name[de]=) are skipped
    # because the pattern requires = or space directly after the key.
    while IFS=$'\t' read -r file name gen; do
        id=${file##*/}
        [[ -n ${SEEN[$id]:-} ]] && continue
        SEEN[$id]=1
        label="$APP_ICON  $name"
        [[ -n $gen ]] && label+="  ·  $gen"
        add "$label" "app:$file"
    done < <(awk '
        function flush() {
            if (file != "" && !skip && type_ok && name != "")
                print file "\t" name "\t" gen
        }
        FNR == 1 { flush(); file = FILENAME; name = ""; gen = ""; skip = 0; in_de = 0; type_ok = 0 }
        /^\[/ { in_de = ($0 == "[Desktop Entry]"); next }
        !in_de { next }
        /^NoDisplay[ \t]*=[ \t]*true/ { skip = 1 }
        /^Hidden[ \t]*=[ \t]*true/ { skip = 1 }
        /^Type[ \t]*=[ \t]*Application/ { type_ok = 1 }
        /^Name[ \t]*=/ && name == "" { l = $0; sub(/^Name[ \t]*=[ \t]*/, "", l); name = l }
        /^GenericName[ \t]*=/ && gen == "" { l = $0; sub(/^GenericName[ \t]*=[ \t]*/, "", l); gen = l }
        END { flush() }
    ' "${DESKTOP_FILES[@]}" | sort -t$'\t' -k2,2 -f)
fi

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
