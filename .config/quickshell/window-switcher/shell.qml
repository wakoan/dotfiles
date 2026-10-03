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
    readonly property int gridRows: targets.length > 8 ? 2 : 1
    readonly property int gridColumns: Math.max(1, Math.ceil(targets.length / gridRows))
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
        if (activation.running || loading || !opened || !targets.length || gridRows < 2) return;
        selected = Math.max(0, Math.min(targets.length - 1, selected + direction * gridColumns));
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
                    root.targets = data.targets;
                    root.monitorName = data.monitor;
                    if (!root.targets.length) return;
                    root.selected = ((root.steps % root.targets.length) + root.targets.length) % root.targets.length;
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
        implicitWidth: Math.min(Math.max(360, root.gridColumns * 146 - 10 + 40), 1200, screen.width - 40)
        implicitHeight: root.gridRows === 2 ? 310 : 200
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
                    Layout.preferredHeight: root.gridRows * 120 - 10
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: Math.max(width, root.gridColumns * 146 - 10)
                    contentHeight: height
                    function tileX(index) {
                        const row = Math.floor(index / root.gridColumns);
                        const count = Math.min(root.gridColumns, root.targets.length - row * root.gridColumns);
                        return (contentWidth - (count * 146 - 10)) / 2 + (index % root.gridColumns) * 146;
                    }
                    function revealSelected() {
                        const left = tileX(root.selected);
                        contentX = Math.max(0, Math.min(contentWidth - width,
                            left < contentX ? left : left + 136 > contentX + width ? left + 136 - width : contentX));
                    }
                    onWidthChanged: Qt.callLater(revealSelected)
                    onContentWidthChanged: Qt.callLater(revealSelected)
                    Repeater {
                    model: root.targets
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 136
                        height: 110
                        x: list.tileX(index)
                        y: Math.floor(index / root.gridColumns) * 120
                        radius: 12
                        color: index === root.selected ? "#99414e6c" : "#40292d3b"
                        border.width: index === root.selected ? 1 : 0
                        border.color: "#8ab4f8"
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4
                            Item { Layout.fillHeight: true }
                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                sourceSize.width: 128
                                sourceSize.height: 128
                                fillMode: Image.PreserveAspectFit
                                readonly property var entry: modelData.kind === "window"
                                    ? DesktopEntries.heuristicLookup(modelData.appClass || "") : null
                                source: modelData.kind === "tmux" ? Qt.resolvedUrl("assets/tmux.svg")
                                    : (Quickshell.iconPath(entry ? entry.icon : (modelData.appClass || ""), true)
                                        || Quickshell.iconPath("application-x-executable"))
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.status === Image.Error
                                    text: "▣"
                                    color: "#8ab4f8"
                                    font.pixelSize: 48
                                }
                            }
                            Text {
                                text: modelData.title
                                textFormat: Text.PlainText
                                color: "#edf0ff"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                            }
                            Item { Layout.fillHeight: true }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.selected = index; root.accept(); } }
                    }
                    }
                }
                Text {
                    text: root.targets[root.selected] ? root.targets[root.selected].title : ""
                    textFormat: Text.PlainText
                    color: "#edf0ff"
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
