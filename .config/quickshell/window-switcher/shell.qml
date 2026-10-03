import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool opened: false
    property bool loading: false
    property bool accepting: false
    property int steps: 0
    property int selected: 0
    property var targets: []
    property string monitorName: ""
    readonly property string helper: Qt.resolvedUrl("targets.py").toString().replace("file://", "")
    // Windows get a big tile because the point of them is the capture; tmux
    // entries have no capture to show, so they keep the original compact size
    // rather than padding an icon out to fill a thumbnail-sized frame.
    readonly property int winW: 520
    readonly property int winH: 330
    readonly property int tmuxW: 136
    readonly property int tmuxH: 110
    readonly property int tileGap: 12
    readonly property var activeScreen: Quickshell.screens.find(s => s.name === monitorName) || Quickshell.screens[0]
    readonly property int availWidth: activeScreen ? Math.min(activeScreen.width - 120, 1800) : 1200
    readonly property int maxViewHeight: activeScreen ? Math.round(activeScreen.height * 0.66) : 620

    // Mixed tile sizes rule out a fixed grid, so pack rows greedily: walk the
    // targets in order, start a new row when the next tile would overflow, and
    // give each row the height of its tallest member. Windows come first out of
    // discovery, so they naturally fill the top rows and tmux trails below.
    readonly property var layoutData: {
        const gap = tileGap, avail = availWidth, list = targets;
        const tiles = [], rows = [];
        let row = [], rowW = 0;
        let prevKind = "";
        for (let i = 0; i < list.length; i++) {
            const kind = list[i].kind;
            const isWin = kind === "window";
            const w = isWin ? winW : tmuxW, h = isWin ? winH : tmuxH;
            // Break the row when the tile would overflow, and also whenever the
            // kind changes: thumbnails and tmux entries get their own rows
            // rather than sharing one, so the two never sit side by side.
            const kindChanged = prevKind !== "" && kind !== prevKind;
            if (row.length && (kindChanged || rowW + gap + w > avail)) {
                rows.push({items: row, w: rowW});
                row = []; rowW = 0;
            }
            rowW += (row.length ? gap : 0) + w;
            row.push({i: i, w: w, h: h});
            prevKind = kind;
        }
        if (row.length) rows.push({items: row, w: rowW});
        let y = 0, maxW = 0;
        for (let r = 0; r < rows.length; r++) {
            let rh = 0;
            for (let k = 0; k < rows[r].items.length; k++) rh = Math.max(rh, rows[r].items[k].h);
            maxW = Math.max(maxW, rows[r].w);
            let x = 0;
            for (let k = 0; k < rows[r].items.length; k++) {
                const it = rows[r].items[k];
                // vertically centre a short tile against a tall neighbour
                tiles[it.i] = {x: x, y: y + (rh - it.h) / 2, w: it.w, h: it.h, row: r, rowW: rows[r].w};
                x += it.w + gap;
            }
            y += rh + gap;
        }
        return {tiles: tiles, width: maxW, height: Math.max(0, y - gap)};
    }

    // Match a discovery target to its Wayland toplevel so the tile can show a
    // live capture. Quickshell 0.3.1's Hyprland module tracks no toplevels, so
    // there is no address to go on: appId plus title is the available key, and
    // appId alone is the fallback when two windows share a class.
    function toplevelFor(target) {
        if (!target || target.kind !== "window") return null;
        const model = ToplevelManager.toplevels;
        const list = model ? model.values : [];
        const cls = (target.appClass || "").toLowerCase();
        const title = target.title || "";
        for (let i = 0; i < list.length; i++)
            if ((list[i].appId || "").toLowerCase() === cls && list[i].title === title) return list[i];
        for (let i = 0; i < list.length; i++)
            if ((list[i].appId || "").toLowerCase() === cls) return list[i];
        return null;
    }
    onSelectedChanged: Qt.callLater(() => list.revealSelected())

    function cycle(direction) {
        if (activation.running) return;
        if (loading) { steps += direction; return; }
        if (opened) {
            selected = (selected + direction + targets.length) % targets.length;
            return;
        }
        steps = direction;
        accepting = false;
        loading = true;
        discovery.running = true;
    }
    function accept() {
        if (loading) { accepting = true; return; }
        if (!opened || targets.length === 0) return;
        const target = targets[selected];
        opened = false;
        activation.command = ["python3", helper, JSON.stringify(target)];
        activation.running = true;
    }
    function moveRow(direction) {
        if (activation.running || loading || !opened || !targets.length) return;
        const tiles = layoutData.tiles;
        const cur = tiles[selected];
        if (!cur) return;
        // Nearest tile by horizontal centre in the adjacent row: with rows of
        // differing tile sizes an index offset would land arbitrarily.
        const wantRow = cur.row + direction;
        const curMid = cur.x + cur.w / 2;
        let best = -1, bestDist = Infinity;
        for (let i = 0; i < tiles.length; i++) {
            if (!tiles[i] || tiles[i].row !== wantRow) continue;
            const d = Math.abs(tiles[i].x + tiles[i].w / 2 - curMid);
            if (d < bestDist) { bestDist = d; best = i; }
        }
        if (best >= 0) selected = best;
    }
    function cancel() {
        opened = false;
        loading = false;
        accepting = false;
        discovery.running = false;
    }
    IpcHandler {
        target: "switcher"
        function next(): void { root.cycle(1); }
        function previous(): void { root.cycle(-1); }
        function accept(): void { root.accept(); }
        function cancel(): void { root.cancel(); }
        function status(): string { return JSON.stringify({opened: root.opened, loading: root.loading, selected: root.selected, target: root.targets[root.selected]}); }
    }
    Process {
        id: discovery
        command: ["python3", root.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.loading) return;
                root.loading = false;
                try {
                    const data = JSON.parse(text);
                    const found = data.targets || [];
                    // Discovery ranks by recency, so whichever kind was used
                    // last leads and the thumbnail row lands first or second at
                    // random. Group it: windows first, tmux after, each keeping
                    // its discovered order.
                    const windows = found.filter(t => t.kind === "window");
                    const others = found.filter(t => t.kind !== "window");
                    root.targets = windows.concat(others);
                    root.monitorName = data.monitor;
                    if (!root.targets.length) return;
                    // Cycling still starts from the recency order, so the first
                    // Tab lands on the last-used target rather than whatever now
                    // sits at the top of the grid.
                    const n = root.targets.length;
                    const wanted = found[((root.steps % n) + n) % n];
                    const landed = root.targets.indexOf(wanted);
                    root.selected = landed >= 0 ? landed : 0;
                    root.opened = true;
                    if (root.accepting) root.accept();
                } catch (error) { console.warn("Switcher discovery failed:", error); }
            }
        }
    }
    Process { id: activation }
    PanelWindow {
        id: overlay
        visible: root.opened || keyboardSurface.opacity > 0
        onVisibleChanged: if (visible) Qt.callLater(() => keyboardSurface.forceActiveFocus())
        screen: Quickshell.screens.find(s => s.name === root.monitorName) || Quickshell.screens[0]
        implicitWidth: Math.min(Math.max(360, root.layoutData.width + 40), screen.width - 40)
        implicitHeight: Math.min(root.layoutData.height, root.maxViewHeight) + 40 + 14 + 22
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "window-switcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Rectangle {
            id: keyboardSurface
            opacity: root.opened ? 1 : 0
            enabled: root.opened
            Behavior on opacity {
                NumberAnimation {
                    duration: 0
                    easing.type: Easing.OutCubic
                }
            }
            anchors.fill: parent
            color: "#8020232f"
            radius: 22
            border.color: "#818bb0"
            border.width: 1
            focus: true
            // The overlay owns keyboard focus. Listen to the actual key-up
            // here; compositor modifier-only shortcuts can be suppressed
            // after another key (Tab) was used while the modifier was held.
            Keys.onReleased: event => {
                if (!event.isAutoRepeat && (event.key === Qt.Key_Meta
                        || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R)) {
                    root.accept();
                    event.accepted = true;
                }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.accept(); event.accepted = true; }
                else if (event.key === Qt.Key_Right) { root.cycle(1); event.accepted = true; }
                else if (event.key === Qt.Key_Left) { root.cycle(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Down) { root.moveRow(1); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { root.moveRow(-1); event.accepted = true; }
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14
                Flickable {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.layoutData.height, root.maxViewHeight)
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: Math.max(height, root.layoutData.height)
                    function revealSelected() {
                        const g = root.layoutData.tiles[root.selected];
                        if (!g) return;
                        contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height),
                            g.y < contentY ? g.y
                                : g.y + g.h > contentY + height ? g.y + g.h - height
                                : contentY));
                    }
                    onHeightChanged: Qt.callLater(revealSelected)
                    onContentHeightChanged: Qt.callLater(revealSelected)
                    Repeater {
                    model: root.targets
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property var geom: root.layoutData.tiles[index]
                            || ({x: 0, y: 0, w: root.tmuxW, h: root.tmuxH, rowW: root.tmuxW})
                        readonly property bool isWindow: modelData.kind === "window"
                        readonly property var toplevel: root.toplevelFor(modelData)
                        readonly property int stripH: isWindow ? 36 : 30
                        width: geom.w
                        height: geom.h
                        // rows are centred as a unit, so each tile offsets by half
                        // the slack left over by its own row
                        x: (list.contentWidth - geom.rowW) / 2 + geom.x
                        y: geom.y
                        radius: 12
                        clip: true
                        color: index === root.selected ? "#99414e6c" : "#40292d3b"
                        border.width: index === root.selected ? 2 : 0
                        border.color: "#8ab4f8"

                        // live:false takes one frame when the overlay opens; this
                        // runs on an Iris Pro 5200 and continuously capturing every
                        // window would cost more than a switcher is worth.
                        ScreencopyView {
                            id: shot
                            anchors.fill: parent
                            anchors.margins: 4
                            anchors.bottomMargin: tile.stripH
                            captureSource: tile.toplevel
                            live: false
                            paintCursor: false
                            constraintSize: Qt.size(root.winW, root.winH)
                            visible: tile.toplevel !== null && hasContent
                        }

                        // tmux entries are not windows and have no capture; so do
                        // any window whose toplevel could not be matched.
                        Image {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -tile.stripH / 2
                            width: tile.isWindow ? 72 : 56
                            height: width
                            visible: !shot.visible
                            sourceSize.width: 128
                            sourceSize.height: 128
                            fillMode: Image.PreserveAspectFit
                            readonly property var entry: tile.isWindow
                                ? DesktopEntries.heuristicLookup(tile.modelData.appClass || "") : null
                            source: tile.modelData.kind === "tmux" ? Qt.resolvedUrl("assets/tmux.svg")
                                : (Quickshell.iconPath(entry ? entry.icon : (tile.modelData.appClass || ""), true)
                                    || Quickshell.iconPath("application-x-executable"))
                            Text {
                                anchors.centerIn: parent
                                visible: parent.status === Image.Error
                                text: "▣"
                                color: "#8ab4f8"
                                font.pixelSize: 48
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: tile.stripH
                            color: "#cc14161e"
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                text: tile.modelData.title
                                textFormat: Text.PlainText
                                color: "#edf0ff"
                                font.pixelSize: tile.isWindow ? 17 : 15
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.selected = index; root.accept(); } }
                    }
                    }
                }
                Text {
                    text: root.targets[root.selected] ? root.targets[root.selected].title : ""
                    textFormat: Text.PlainText
                    color: "#edf0ff"
                    font.pixelSize: 16
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
