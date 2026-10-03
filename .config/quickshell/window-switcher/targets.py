#!/usr/bin/env python3
"""Discover and activate local Hyprland windows and tmux windows."""
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path


def run(*args):
    return subprocess.run(args, text=True, capture_output=True, timeout=4, check=True).stdout


def optional(*args):
    try:
        return run(*args)
    except (subprocess.SubprocessError, OSError):
        return ""


def identify_terminal(tty, windows):
    """Disambiguate terminals sharing a PID via a reversible title probe."""
    if not tty.startswith('/dev/pts/'):
        return None
    marker = 'window-switcher-' + uuid.uuid4().hex
    fd = os.open(tty, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
    match = None
    try:
        # Save/restore the terminal title stack, including on lookup failure.
        os.write(fd, ('\x1b[22;2t\x1b]2;' + marker + '\x1b\\').encode())
        for _ in range(8):
            current = json.loads(run('hyprctl', 'clients', '-j'))
            address = next((w['address'] for w in current if w['title'] == marker), None)
            match = next((w for w in windows if w['address'] == address), None)
            if match:
                return match
            time.sleep(.015)
    finally:
        os.write(fd, b'\x1b[23;2t')
        if match:
            # Some terminal builds ignore title-stack restoration. Restore
            # the exact pre-probe title from the compositor as well.
            title = ''.join(c for c in match.get('title', '') if ord(c) >= 32 and not 127 <= ord(c) <= 159)
            os.write(fd, ('\x1b]2;' + title + '\x1b\\').encode())
        os.close(fd)
    return None


def host_for(pid, windows, tty='', cache=None):
    cache = cache if cache is not None else {}
    try:
        start = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[19]
    except (OSError, IndexError):
        return None
    key = f'{pid}:{start}:{tty}'
    saved = cache.get(key, {})
    for window in windows:
        if (window['address'] == saved.get('address')
                and window.get('stableId') == saved.get('stableId')
                and window['pid'] == saved.get('pid')):
            return window
    seen = set()
    while pid > 1 and pid not in seen:
        seen.add(pid)
        matches = [w for w in windows if w["pid"] == pid]
        if matches:
            match = matches[0] if len(matches) == 1 else identify_terminal(tty, matches)
            if match:
                cache[key] = {k: match.get(k) for k in ('address', 'stableId', 'pid')}
            return match
        try:
            # comm may contain spaces and parentheses.
            pid = int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return None


def snapshot():
    windows = json.loads(run("hyprctl", "clients", "-j"))
    windows = [w for w in windows if w.get("mapped", True) and not w.get("hidden", False)]
    active = json.loads(run("hyprctl", "activewindow", "-j")).get("address")
    monitors = json.loads(run("hyprctl", "monitors", "-j"))
    monitor = next((m["name"] for m in monitors if m.get("focused")), "")
    clients = []
    cache_path = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'window-switcher-hosts.json'
    try:
        cache = json.loads(cache_path.read_text())
    except (OSError, ValueError):
        cache = {}
    for line in optional("tmux", "list-clients", "-F", "#{client_pid}\t#{client_tty}\t#{session_id}\t#{window_id}").splitlines():
        pid, tty, session, win = line.split("\t", 3)
        host = host_for(int(pid), windows, tty, cache)
        if host:
            clients.append(dict(tty=tty, session=session, win=win, host=host))
    try:
        cache_path.write_text(json.dumps(cache))
    except OSError:
        pass
    hosts = {c["host"]["address"] for c in clients}
    targets = []
    for w in windows:
        if w["address"] not in hosts:
            targets.append(dict(kind="window", title=w["title"] or w["class"],
                                appClass=w["class"],
                                detail=f'{w["class"]} · workspace {w["workspace"]["name"]}',
                                address=w["address"], current=w["address"] == active,
                                rank=w.get("focusHistoryID", 999)))
    for line in optional("tmux", "list-windows", "-a", "-F", "#{session_id}\t#{window_id}\t#{session_name}\t#{window_index}\t#{window_name}").splitlines():
        session, win, name, index, title = line.split("\t", 4)
        candidates = sorted(clients, key=lambda c: (c["session"] != session, c["host"]["address"] != active, c["host"].get("focusHistoryID", 999)))
        client = candidates[0] if candidates else None
        targets.append(dict(kind="tmux", title=title, detail=f"tmux · {name}:{index}",
                            session=session, win=win, tty=client["tty"] if client else "",
                            address=client["host"]["address"] if client else "",
                            current=bool(client and client["host"]["address"] == active and client["session"] == session and client["win"] == win),
                            rank=client["host"].get("focusHistoryID", 999) if client else 999))
    targets.sort(key=lambda t: (not t["current"], t["rank"]))
    return dict(targets=targets, monitor=monitor)


def activate(target):
    if target["kind"] == "tmux":
        destination = target["session"] + ":" + target["win"]
        # Check the target still exists before switching or opening a terminal.
        run("tmux", "display-message", "-p", "-t", destination, "#{window_id}")
        live_ttys = optional("tmux", "list-clients", "-F", "#{client_tty}").splitlines()
        if target["tty"] not in live_ttys:
            subprocess.Popen(["ghostty", "-e", "tmux", "attach-session", "-t", destination], start_new_session=True)
            return
        run("tmux", "switch-client", "-c", target["tty"], "-t", destination)
    run("hyprctl", "dispatch", "focuswindow", "address:" + target["address"])
    run("hyprctl", "dispatch", "bringactivetotop")


if __name__ == "__main__":
    try:
        if len(sys.argv) == 1:
            print(json.dumps(snapshot()))
        else:
            activate(json.loads(sys.argv[1]))
    except (subprocess.SubprocessError, OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
