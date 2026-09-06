#!/usr/bin/env python3
"""Resolve icon file paths for switcher.sh.

Icon lookup is not a filesystem glob: a name like "chromium" can live in any
theme directory at any size, may be inherited from a parent theme, and may be
an absolute path already. GTK's IconTheme implements the XDG rules, so use it
rather than reimplementing them.

Prints TSV, one record per line:

    APP <tab> desktop-file <tab> icon-path <tab> name <tab> generic-name
    CLS <tab> window-class <tab> icon-path
    ICON <tab> requested-name <tab> icon-path
    FILE <tab> requested-path <tab> icon-path

usage: switcher-icons.py [--icon NAME]... [--class WM_CLASS]... [--file PATH]...
"""

import hashlib
import os
import sys

# Read the command line before importing gi: initialising GTK consumes
# sys.argv, so anything read afterwards comes back empty.
ARGV = sys.argv[1:]

import warnings

import gi

# Gio.DesktopAppInfo is flagged deprecated in favour of GioUnix, which is not
# available everywhere yet; the warning would land on stderr on every run.
warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*DesktopAppInfo.*")

gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, Gio, GLib, Gtk  # noqa: E402

SIZE = 48
theme = Gtk.IconTheme.get_default()

# wofi renders image escapes through gdk-pixbuf but will not display SVGs --
# the row simply comes out iconless, with no error. Many themes ship only a
# scalable icon, so rasterise those once into a cache and hand over the PNG.
CACHE = os.path.join(GLib.get_user_cache_dir(), "switcher-icons")


def rasterize(path):
    if not path or not path.lower().endswith(".svg"):
        return path
    try:
        os.makedirs(CACHE, exist_ok=True)
        stamp = hashlib.sha1(path.encode()).hexdigest()[:16]
        out = os.path.join(CACHE, f"{stamp}-{SIZE}.png")
        if not os.path.exists(out) or os.path.getmtime(out) < os.path.getmtime(path):
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(path, SIZE, SIZE)
            pixbuf.savev(out, "png", [], [])
        return out
    except (GLib.Error, OSError):
        return ""


def resolve(icon):
    """Take a GIcon, an icon name, or a path; return a PNG file path or ''."""
    return rasterize(_lookup(icon))


def _lookup(icon):
    if icon is None:
        return ""
    if isinstance(icon, str):
        if icon.startswith("/"):
            return icon if os.path.exists(icon) else ""
        names = [icon]
    elif isinstance(icon, Gio.FileIcon):
        return icon.get_file().get_path() or ""
    elif isinstance(icon, Gio.ThemedIcon):
        names = list(icon.get_names())
    else:
        return ""
    for name in names:
        info = theme.lookup_icon(name, SIZE, Gtk.IconLookupFlags.FORCE_REGULAR)
        if info is not None:
            path = info.get_filename()
            if path:
                return path
    return ""


def apps():
    out = []
    for app in Gio.AppInfo.get_all():
        # should_show() honours NoDisplay, Hidden and OnlyShowIn/NotShowIn,
        # which a hand-rolled .desktop parse tends to get wrong.
        if not app.should_show():
            continue
        path = app.get_filename() or ""
        if not path:
            continue
        out.append(
            (
                path,
                resolve(app.get_icon()),
                app.get_display_name() or "",
                app.get_generic_name() or "",
            )
        )
    out.sort(key=lambda r: r[2].lower())
    return out


def icon_for_class(wm_class):
    """Find the app a Hyprland window belongs to, then take its icon."""
    lowered = wm_class.lower()

    for candidate in (f"{wm_class}.desktop", f"{lowered}.desktop"):
        # PyGObject raises TypeError instead of returning None when the
        # desktop file does not exist.
        try:
            app = Gio.DesktopAppInfo.new(candidate)
        except TypeError:
            continue
        if app is not None:
            found = resolve(app.get_icon())
            if found:
                return found

    # Chromium and friends announce a StartupWMClass that differs from the
    # desktop file name, so fall back to scanning for it.
    for app in Gio.AppInfo.get_all():
        if not isinstance(app, Gio.DesktopAppInfo):
            continue
        declared = app.get_startup_wm_class()
        if declared and declared.lower() == lowered:
            found = resolve(app.get_icon())
            if found:
                return found

    # Last resort: the class may itself name an icon in the theme.
    for name in (wm_class, lowered, lowered.split(".")[-1]):
        if theme.has_icon(name):
            found = resolve(name)
            if found:
                return found
    return ""


def main(argv):
    icons, classes, files = [], [], []
    it = iter(argv)
    for arg in it:
        if arg == "--icon":
            icons.append(next(it, ""))
        elif arg == "--class":
            classes.append(next(it, ""))
        elif arg == "--file":
            files.append(next(it, ""))

    for path, icon, name, generic in apps():
        print(f"APP\t{path}\t{icon}\t{name}\t{generic}")
    for wm_class in classes:
        print(f"CLS\t{wm_class}\t{icon_for_class(wm_class)}")
    for name in icons:
        print(f"ICON\t{name}\t{resolve(name)}")
    for path in files:
        print(f"FILE\t{path}\t{rasterize(path)}")


if __name__ == "__main__":
    main(ARGV)
