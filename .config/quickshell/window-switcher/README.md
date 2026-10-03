# Window switcher

Standalone Quickshell 0.3.1 configuration for Hyprland and local tmux clients.
Link this directory to `~/.config/quickshell/window-switcher` and start with
`quickshell -n -c window-switcher -d`. Hyprland's configuration starts it at login.

Hold Cmd and press Tab to cycle forward, or Shift+Tab to cycle backward. The
Targets are shown in one row until there are more than eight; then the layout
uses two rows. Left/Right move through the sequence and Up/Down jump between
rows. The grid scrolls horizontally when both rows are full.
Release Cmd to activate. Escape cancels; arrows, Enter, and clicking also work.
The list is frozen during selection. Discovery runs only on opening, with no
background polling. Targets include windows across workspaces and windows on
the default local tmux server. Terminal hosts are matched by tmux client process
ancestry. If multiple Ghostty windows share that process, a temporary title
probe identifies the tmux client's exact terminal and restores its title.
The mapping is cached under `$XDG_RUNTIME_DIR/window-switcher-hosts.json`,
validated by client process lifetime and compositor window identity, so focus
order cannot redirect a tmux selection to a different Ghostty window.
A detached session opens in Ghostty when selected without a live client.

Dependencies: quickshell, python3, hyprctl, tmux, and Ghostty for detached sessions.
The background uses HyprGlass, configured in `~/.config/hypr/hyprglass.conf`,
with the plugin installed at `~/.local/lib/hyprglass/hyprglass.so`.
It is built from `~/projects/hyprglass` (v0.8.0, pinned for Hyprland 0.56.2).
Rebuild against matching headers after a Hyprland upgrade; do not bypass the
plugin's version check. Glass applies only to the `window-switcher` layer.
The helper invokes commands with argument arrays, so window names are never
interpreted as shell code.

IPC: `quickshell ipc -c window-switcher call switcher next` (also `previous`,
`accept`, `cancel`, and `status`). The overlay handles Cmd key release directly,
including when Shift is still held. Non-consuming Hyprland release bindings
provide a fallback for release before the overlay gains keyboard focus.
