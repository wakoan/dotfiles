import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

ShellRoot {
    id: root

    property int tick: 0
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                required property var modelData
                id: barWindow
                screen: modelData
                property bool powerOpen: false
                property bool audioOpen: false
                property bool bluetoothOpen: false
                property bool wifiOpen: false
                property bool agentOpen: false
                property string selectedAgent: "codex"
                property string powerText: "Reading battery telemetry…"
                property real correctedFraction: -1
                property string batteryStatus: "—"
                property string batteryCapacityText: "—"
                property string batteryCyclesText: "—"
                property string batteryLimitText: "Not configured"
                property string batteryProfileText: "Balanced"
                property string batteryPowerText: "—"
                property string batteryVoltageText: "—"
                property string batteryCurrentText: "—"
                property string agentSessionsText: "—"
                property string agentTurnsText: "—"
                property string agentProcessesText: "—"
                property var agentLimits: []
                // PipeWire exposes change signals for volume and mute state.
                // This binding therefore updates for media keys immediately,
                // without repeatedly starting wpctl in the background.
                readonly property var audioNodes: Pipewire.nodes ? Pipewire.nodes.values : []
                // WirePlumber can temporarily retain a removed Bluetooth
                // device as its configured default. In that case, use the
                // first live physical sink (normally the built-in speakers).
                readonly property var audioSink: {
                    var preferred = Pipewire.defaultAudioSink
                    if (preferred?.ready && preferred?.audio) return preferred
                    for (var i = 0; i < audioNodes.length; i++) {
                        var node = audioNodes[i]
                        if (node?.isSink && !node.isStream && node.ready && node.audio)
                            return node
                    }
                    return preferred
                }
                readonly property bool audioReady: !!audioSink?.ready && !!audioSink?.audio
                readonly property var audioSource: Pipewire.defaultAudioSource
                readonly property bool audioSourceReady: !!audioSource?.ready && !!audioSource?.audio
                readonly property real inputVolume: audioSourceReady ? audioSource.audio.volume : 0
                property string audioFallbackText: "Audio…"
                readonly property string audioText: {
                    var audio = audioReady ? audioSink.audio : null
                    if (!audio) return audioFallbackText
                    return audio.muted ? "󰖁 muted" : "󰕾 " + Math.round(audio.volume * 100) + "%"
                }
                property string bluetoothText: "Bluetooth…"
                property string airpodsBatteryText: "Battery unavailable"
                readonly property bool airpodsConnected: bluetoothText.indexOf("AirPods") >= 0
                property string wifiText: "Wi‑Fi…"
                property string wifiDetailsText: "Reading connection details…"
                property string wifiPingText: "Measuring…"
                property string wifiNetworkName: "Disconnected"
                property var wifiDetailRows: []
                property string wifiPacketLossText: "—"
                property string wifiReceivingText: "—"
                property string wifiSendingText: "—"
                property string wifiDownloadedText: "—"
                property string wifiUploadedText: "—"
                property string wifiIpText: "—"
                property string wifiGatewayText: "—"
                property string wifiBandText: "—"
                property string wifiDnsText: "—"
                property string wifiDnsProviderText: "DHCP"
                property string wifiInterface: ""
                property var wifiKnownNetworks: []
                property var wifiOtherNetworks: []
                property string wifiConnectingName: ""
                property real wifiPreviousRx: -1
                property real wifiPreviousTx: -1
                property double wifiPreviousAt: 0

                function setPowerData(raw) {
                    powerText = String(raw).trim()
                    String(raw).trim().split("\n").forEach(function(line) {
                        var pair = line.split("\t")
                        if (pair.length < 2) return
                        if (pair[0] === "Status") batteryStatus = pair[1]
                        else if (pair[0] === "Capacity") batteryCapacityText = pair[1]
                        else if (pair[0] === "Cycles") batteryCyclesText = pair[1]
                        else if (pair[0] === "Limit") batteryLimitText = pair[1]
                        else if (pair[0] === "Profile") batteryProfileText = pair[1]
                        else if (pair[0] === "Power") batteryPowerText = pair[1]
                        else if (pair[0] === "Voltage") batteryVoltageText = pair[1]
                        else if (pair[0] === "Current") batteryCurrentText = pair[1]
                    })
                }

                function setAirpodsBattery(raw) {
                    var values = {}
                    String(raw).trim().split("\n").forEach(function(line) {
                        var pair = line.split("=")
                        if (pair.length === 2) values[pair[0]] = pair[1]
                    })
                    var parts = []
                    if (values.LEFT) parts.push("L " + values.LEFT + "%")
                    if (values.RIGHT) parts.push("R " + values.RIGHT + "%")
                    if (values.CASE) parts.push("Case " + values.CASE + "%")
                    airpodsBatteryText = parts.length > 0 ? parts.join("  ·  ") : "Battery unavailable"
                }

                function setAgentStats(raw) {
                    var limits = []
                    String(raw).trim().split("\n").forEach(function(line) {
                        var pair = line.split("\t")
                        if (pair.length < 2) return
                        if (pair[0] === "Sessions") agentSessionsText = pair[1]
                        else if (pair[0] === "Records") agentTurnsText = pair[1]
                        else if (pair[0] === "Processes") agentProcessesText = pair[1]
                        else if (pair[0] === "Limit" && pair.length >= 4) limits.push({ label: pair[1], percent: Number(pair[2]), reset: pair[3] })
                    })
                    agentLimits = limits
                }

                function refreshAgentStats() {
                    if (agentStatsProcess.running) return
                    agentStatsProcess.command = ["/home/wako/.config/quickshell/caelestia-minimal/scripts/agent-stats.sh", selectedAgent]
                    agentStatsProcess.running = true
                }

                function formatLimitReset(value) {
                    var timestamp = Date.parse(value)
                    if (!isFinite(timestamp)) return "Reset time unavailable"
                    var minutes = Math.max(0, Math.round((timestamp - Date.now()) / 60000))
                    var days = Math.floor(minutes / 1440)
                    var hours = Math.floor((minutes % 1440) / 60)
                    var mins = minutes % 60
                    return "Resets in " + (days > 0 ? days + "d " : "") + (hours > 0 ? hours + "h " : "") + mins + "m"
                }

                function setPowerProfile(profile) {
                    if (powerProfileAction.running) return
                    powerProfileAction.command = ["pkexec", "/home/wako/.config/quickshell/caelestia-minimal/scripts/set-power-profile.sh", profile]
                    powerProfileAction.running = true
                }

                function cleanWifiOutput(raw) {
                    return String(raw)
                        .replace(/\u001b\[[0-9;]*[A-Za-z]/g, "")
                        .replace(/\\n/g, "\n")
                        .trim()
                }

                function setWifiDetails(raw) {
                    var cleaned = cleanWifiOutput(raw)
                    wifiDetailsText = cleaned
                    wifiDetailRows = cleaned.split("\n").map(function(line) {
                        var separator = line.indexOf(":")
                        if (separator < 0) return { label: "", value: line.trim() }
                        return {
                            label: line.substring(0, separator).trim(),
                            value: line.substring(separator + 1).trim()
                        }
                    }).filter(function(row) {
                        return row.value.length > 0
                            && row.label !== "Address"
                            && row.label !== "Gateway"
                            && row.label !== "Frequency"
                    })
                    var networkRow = wifiDetailRows.find(function(row) { return row.label === "Network" })
                    wifiNetworkName = networkRow ? networkRow.value : "Disconnected"
                }

                function formatBytes(value) {
                    var n = Number(value)
                    if (!isFinite(n) || n < 0) return "—"
                    if (n >= 1073741824) return (n / 1073741824).toFixed(2) + " GB"
                    if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB"
                    if (n >= 1024) return (n / 1024).toFixed(1) + " KB"
                    return Math.round(n) + " B"
                }

                function setWifiMetrics(raw) {
                    var fields = String(raw).trim().split("\t")
                    var rx = Number(fields[3] || 0)
                    var tx = Number(fields[4] || 0)
                    var now = Date.now()
                    var elapsed = wifiPreviousAt > 0 ? (now - wifiPreviousAt) / 1000 : 0
                    wifiIpText = fields[1] || "—"
                    wifiInterface = fields[0] || ""
                    wifiGatewayText = fields[2] || "—"
                    wifiDownloadedText = formatBytes(rx)
                    wifiUploadedText = formatBytes(tx)
                    wifiPingText = fields[5] || "unreachable"
                    wifiPacketLossText = fields[6] || "100%"
                    var frequency = Number(fields[7] || 0)
                    wifiBandText = frequency >= 5925 ? "6 GHz" : (frequency >= 4900 ? "5 GHz" : (frequency >= 2400 ? "2.4 GHz" : "—"))
                    wifiDnsText = fields[8] || "—"
                    wifiDnsProviderText = wifiDnsText === "1.1.1.1" || wifiDnsText === "1.0.0.1"
                        ? "Cloudflare" : (wifiDnsText === "8.8.8.8" || wifiDnsText === "8.8.4.4" ? "Google" : "DHCP")
                    if (elapsed > 0 && wifiPreviousRx >= 0 && wifiPreviousTx >= 0) {
                        wifiReceivingText = formatBytes(Math.max(0, rx - wifiPreviousRx) / elapsed) + "/s"
                        wifiSendingText = formatBytes(Math.max(0, tx - wifiPreviousTx) / elapsed) + "/s"
                    }
                    wifiPreviousRx = rx
                    wifiPreviousTx = tx
                    wifiPreviousAt = now
                }

                function setDnsProvider(provider) {
                    if (wifiInterface === "" || wifiDnsProcess.running) return
                    wifiDnsProviderText = provider
                    if (provider === "Cloudflare")
                        wifiDnsProcess.command = ["resolvectl", "dns", wifiInterface, "1.1.1.1", "1.0.0.1"]
                    else if (provider === "Google")
                        wifiDnsProcess.command = ["resolvectl", "dns", wifiInterface, "8.8.8.8", "8.8.4.4"]
                    else
                        wifiDnsProcess.command = ["resolvectl", "revert", wifiInterface]
                    wifiDnsProcess.running = true
                }

                function parseNetworkNames(raw) {
                    return cleanWifiOutput(raw).split("\n").map(function(line) {
                        var value = line.replace(/^[>*\s]+/, "").trim()
                        if (value.length === 0 || /^(known networks|available networks|name\s+security)/i.test(value) || /^[-─]+$/.test(value)) return ""
                        return value.split(/\s{2,}/)[0].trim()
                    }).filter(function(name) { return name.length > 0 })
                }

                function setKnownNetworks(raw) {
                    wifiKnownNetworks = parseNetworkNames(raw)
                }

                function setOtherNetworks(raw) {
                    var known = wifiKnownNetworks
                    wifiOtherNetworks = parseNetworkNames(raw).filter(function(name) {
                        return name !== wifiNetworkName && known.indexOf(name) < 0
                    })
                }

                function setAudioVolume(value) {
                    var volume = Math.max(0, Math.min(1.5, value))
                    if (audioReady) {
                        audioSink.audio.muted = false
                        audioSink.audio.volume = volume
                    } else {
                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(volume * 100) + "%"])
                        audioSettleTimer.restart()
                    }
                }

                function toggleAudioMute() {
                    if (audioReady)
                        audioSink.audio.muted = !audioSink.audio.muted
                    else if (!audioAction.running) {
                        audioAction.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                        audioAction.running = true
                    }
                }

                function setInputVolume(value) {
                    if (!audioSourceReady) return
                    audioSource.audio.muted = false
                    audioSource.audio.volume = Math.max(0, Math.min(1, value))
                }

                function toggleAirPods() {
                    if (bluetoothAction.running) return
                    bluetoothAction.command = ["bash", "-lc", "mac=$(bluetoothctl devices | awk '/AirPods/ {print $2; exit}'); [ -n \"$mac\" ] || exit 1; if bluetoothctl info \"$mac\" | grep -q 'Connected: yes'; then bluetoothctl disconnect \"$mac\"; sleep 1; fallback=$(wpctl status | sed -n '/Sinks:/,/Sources:/ { /bluez/! s/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p }' | head -1); [ -z \"$fallback\" ] || wpctl set-default \"$fallback\"; else bluetoothctl connect \"$mac\" || exit; for i in 1 2 3 4 5 6 7 8 9 10; do sink=$(wpctl status | sed -n '/Sinks:/,/Sources:/ { /AirPods/ s/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p }' | head -1); [ -z \"$sink\" ] || { wpctl set-default \"$sink\"; break; }; sleep 1; done; fi"]
                    bluetoothAction.running = true
                }

                function closePopups(except) {
                    audioOpen = except === "audio"
                    agentOpen = except === "agent"
                    bluetoothOpen = except === "bluetooth"
                    wifiOpen = except === "wifi"
                    powerOpen = except === "power"
                }
                anchors { top: true; left: true; right: true }
                implicitHeight: 48
                color: "#171923"
                exclusionMode: ExclusionMode.Auto
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "caelestia-minimal"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    RowLayout {
                        spacing: 5
                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                required property int index
                                readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1
                                readonly property var accents: ["#ff7a90", "#ffb86b", "#b6e36f", "#76d7ea", "#ba9cff"]
                                implicitWidth: 30
                                implicitHeight: 30
                                radius: 8
                                color: active ? accents[index] : (workspaceMouse.containsMouse ? "#3a3e4e" : "#292c37")
                                Text {
                                    anchors.centerIn: parent
                                    text: index + 1
                                    color: parent.active ? "#171923" : "#dce1ef"
                                    font.pixelSize: 14
                                    font.bold: parent.active
                                }
                                MouseArea {
                                    id: workspaceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(index + 1)])
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: dateText.implicitWidth + 22
                        implicitHeight: 30
                        radius: 8
                        color: "#292c37"
                        Text {
                            id: dateText
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")
                            color: "#e9e7ff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 36; implicitHeight: 30; radius: 8
                        color: wifiMouse.containsMouse ? "#2d4354" : "#242f3b"
                        Text {
                            anchors.centerIn: parent
                            text: barWindow.wifiText.indexOf("connected") >= 0 ? "󰤨" : "󰤭"
                            color: "#7dd9f5"; font.pixelSize: 18
                        }
                        MouseArea { id: wifiMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: barWindow.closePopups("wifi") }
                    }

                    Rectangle {
                        implicitWidth: audioLabel.implicitWidth + 22; implicitHeight: 30; radius: 8
                        color: audioMouse.containsMouse ? "#41354d" : "#30283a"
                        Text {
                            id: audioLabel
                            anchors.centerIn: parent
                            text: barWindow.audioText
                            color: "#e5b7ff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        MouseArea {
                            id: audioMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barWindow.closePopups("audio")
                            onWheel: function(wheel) {
                                var current = Number(barWindow.audioText.match(/[0-9]+/) || 0) / 100
                                barWindow.setAudioVolume(current + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: agentLabel.implicitWidth + 20; implicitHeight: 30; radius: 8
                        color: agentMouse.containsMouse ? "#3d3446" : "#2c2734"
                        Text {
                            id: agentLabel
                            anchors.centerIn: parent
                            text: "󰚩"
                            color: "#f1bd90"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        MouseArea { id: agentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: barWindow.closePopups("agent") }
                    }

                    Rectangle {
                        implicitWidth: batteryLabel.implicitWidth + 22; implicitHeight: 30; radius: 8
                        color: batteryMouse.containsMouse ? "#3b452d" : "#2c3523"
                        Text {
                            id: batteryLabel
                            anchors.centerIn: parent
                            readonly property var battery: UPower.displayDevice
                            readonly property real fraction: barWindow.correctedFraction >= 0
                                ? barWindow.correctedFraction
                                : (battery && battery.isPresent ? battery.percentage : 0)
                            text: battery && battery.isPresent ? "󰁹 " + Math.round(fraction * 100) + "%" : ""
                            color: "#c8ec8c"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        MouseArea {
                            id: batteryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barWindow.closePopups("power")
                        }
                    }
                }

                Process {
                    id: powerProcess
                    command: ["bash", "-lc", "p=/sys/class/power_supply/BAT0; status=$(cat $p/status 2>/dev/null || echo Unknown); full=$(cat $p/charge_full_design 2>/dev/null || cat $p/charge_full 2>/dev/null || echo 0); voltage=$(cat $p/voltage_min_design 2>/dev/null || cat $p/voltage_now 2>/dev/null || echo 0); now_voltage=$(cat $p/voltage_now 2>/dev/null || echo 0); current=$(cat $p/current_now 2>/dev/null || echo 0); cycles=$(cat $p/cycle_count 2>/dev/null || echo '—'); start=$(cat $p/charge_control_start_threshold 2>/dev/null || true); end=$(cat $p/charge_control_end_threshold 2>/dev/null || true); governor=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo schedutil); case \"$governor\" in powersave) profile='Power saver' ;; performance) profile='Performance' ;; *) profile='Balanced' ;; esac; capacity=$(awk -v c=\"$full\" -v v=\"$voltage\" 'BEGIN { if (c > 0 && v > 0) printf \"%.0f Wh\", c*v/1000000000000; else print \"—\" }'); power=$(awk -v c=\"$current\" -v v=\"$now_voltage\" 'BEGIN { if (c != 0 && v != 0) printf \"%.1f W\", c*v/1000000000000; else print \"—\" }'); volts=$(awk -v v=\"$now_voltage\" 'BEGIN { if (v != 0) printf \"%.2f V\", v/1000000; else print \"—\" }'); amps=$(awk -v c=\"$current\" 'BEGIN { if (c != 0) printf \"%.0f mA\", c/1000; else print \"—\" }'); limit=$([ -n \"$end\" ] && { [ -n \"$start\" ] && printf \"%s–%s%%\" \"$start\" \"$end\" || printf \"0–%s%%\" \"$end\"; } || printf 'Not configured'); printf 'Status\\t%s\\nCapacity\\t%s\\nCycles\\t%s\\nLimit\\t%s\\nProfile\\t%s\\nPower\\t%s\\nVoltage\\t%s\\nCurrent\\t%s' \"$status\" \"$capacity\" \"$cycles\" \"$limit\" \"$profile\" \"$power\" \"$volts\" \"$amps\""]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: barWindow.setPowerData(text)
                    }
                }

                Process {
                    id: agentStatsProcess
                    stdout: StdioCollector { waitForEnd: true; onStreamFinished: barWindow.setAgentStats(text) }
                }

                Process {
                    id: powerProfileAction
                    onExited: if (!powerProcess.running) powerProcess.running = true
                }

                Process {
                    id: chargeFractionProcess
                    command: ["bash", "-lc", "now=$(cat /sys/class/power_supply/BAT0/charge_now 2>/dev/null) && full=$(cat /sys/class/power_supply/BAT0/charge_full 2>/dev/null) && awk -v n=\"$now\" -v f=\"$full\" 'BEGIN { if (f > 0) printf \"%.6f\\n\", n / f }'"]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: {
                            var value = Number(String(text).trim())
                            if (isFinite(value) && value >= 0 && value <= 1) barWindow.correctedFraction = value
                        }
                    }
                }

                Process {
                    id: audioStatus
                    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: {
                            var raw = String(text).trim()
                            var match = raw.match(/([0-9]+(?:\.[0-9]+)?)/)
                            barWindow.audioFallbackText = raw.indexOf("MUTED") >= 0 ? "󰖁 muted" : (match ? "󰕾 " + Math.round(Number(match[1]) * 100) + "%" : "󰕾 ?")
                        }
                    }
                }

                // PipeWire only supplies live properties for objects that a
                // tracker retains. Tracking the current default sink also
                // follows an output-device change automatically.
                PwObjectTracker { objects: barWindow.audioNodes }

                Process {
                    id: audioAction
                    onExited: if (!audioStatus.running) audioStatus.running = true
                }

                Timer {
                    id: audioSettleTimer
                    interval: 180
                    repeat: false
                    onTriggered: if (!audioStatus.running) audioStatus.running = true
                }

                Process {
                    id: bluetoothStatus
                    command: ["bash", "-lc", "bluetoothctl show 2>/dev/null; echo '---'; bluetoothctl devices Connected 2>/dev/null"]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: barWindow.bluetoothText = String(text).trim()
                    }
                }

                Process {
                    id: airpodsBatteryProcess
                    command: ["bash", "-lc", "cat \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/airpods-battery.env\" 2>/dev/null"]
                    stdout: StdioCollector { waitForEnd: true; onStreamFinished: barWindow.setAirpodsBattery(text) }
                }

                Process { id: bluetoothAction; onExited: if (!bluetoothStatus.running) bluetoothStatus.running = true }

                Process {
                    id: wifiStatus
                    command: ["bash", "-lc", "iwctl station list 2>/dev/null"]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: barWindow.wifiText = barWindow.cleanWifiOutput(text)
                    }
                }

                Process { id: wifiAction; onExited: if (!wifiStatus.running) wifiStatus.running = true }

                // Omarchy's network panel shows the active interface and
                // connection details above the nearby-network list. Keep the
                // same useful information here while using the laptop's iwd
                // backend directly.
                Process {
                    id: wifiDetailsProcess
                    command: ["bash", "-lc", "iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}'); if [ -z $iface ]; then echo 'No wireless interface found'; exit; fi; ip=$(ip -4 -o addr show dev $iface 2>/dev/null | awk '{print $4; exit}'); gw=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}'); link=$(iw dev $iface link 2>/dev/null); ssid=$(printf '%s\\n' \"$link\" | sed -n 's/.*SSID: //p' | head -1); signal=$(printf '%s\\n' \"$link\" | sed -n 's/.*signal: //p' | head -1); freq=$(printf '%s\\n' \"$link\" | sed -n 's/.*freq: //p' | head -1); printf 'Interface: %s\\nAddress: %s\\nGateway: %s\\nNetwork: %s\\nSignal: %s\\nFrequency: %s' $iface ${ip:-unknown} ${gw:-unknown} ${ssid:-unknown} ${signal:-unknown} ${freq:-unknown}"]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: barWindow.setWifiDetails(text)
                    }
                }

                Process {
                    id: wifiPingProcess
                    command: ["bash", "-lc", "ping -n -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'time[=<]' '/time[=<]/ { split($2, p, \" \" ); print p[1] \" ms\"; found=1 } END { if (!found) print \"unreachable\" }'"]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: barWindow.wifiPingText = String(text).trim()
                    }
                }

                Process {
                    id: wifiMetricsProcess
                    command: ["bash", "-lc", "iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i == \"dev\") {print $(i+1); exit}}'); [ -z $iface ] && iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}'); ip=$(ip -4 -o addr show dev $iface 2>/dev/null | awk '{print $4; exit}'); gw=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}'); rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0); tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0); freq=$(iw dev $iface link 2>/dev/null | awk '/freq:/ {print $2; exit}'); dns=$(resolvectl dns $iface 2>/dev/null | sed 's/.*: //' | awk '{print $1; exit}'); result=$(ping -n -c 1 -W 1 1.1.1.1 2>/dev/null); ping_ms=$(printf '%s\\n' \"$result\" | awk -F'time[=<]' '/time[=<]/ {split($2,p,\" \" ); print p[1] \" ms\"; found=1} END {if (!found) print \"unreachable\"}'); loss=$(printf '%s\\n' \"$result\" | grep -q '1 received' && echo 0% || echo 100%); printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s' \"$iface\" \"${ip:-—}\" \"${gw:-—}\" \"$rx\" \"$tx\" \"$ping_ms\" \"$loss\" \"${freq:-0}\" \"${dns:-—}\""]
                    stdout: StdioCollector {
                        waitForEnd: true
                        onStreamFinished: barWindow.setWifiMetrics(text)
                    }
                }

                Process {
                    id: wifiKnownProcess
                    command: ["bash", "-lc", "timeout 3 iwctl known-networks list 2>/dev/null"]
                    stdout: StdioCollector { waitForEnd: true; onStreamFinished: barWindow.setKnownNetworks(text) }
                }

                Process {
                    id: wifiScanProcess
                    command: ["bash", "-lc", "iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}'); if [ -n $iface ]; then timeout 2 iwctl station $iface scan 2>/dev/null; sleep 1; timeout 3 iwctl station $iface get-networks 2>/dev/null; fi"]
                    stdout: StdioCollector { waitForEnd: true; onStreamFinished: barWindow.setOtherNetworks(text) }
                }

                Process {
                    id: wifiConnectProcess
                    onExited: {
                        barWindow.wifiConnectingName = ""
                        if (!wifiDetailsProcess.running) wifiDetailsProcess.running = true
                        if (!wifiMetricsProcess.running) wifiMetricsProcess.running = true
                        if (!wifiKnownProcess.running) wifiKnownProcess.running = true
                        if (!wifiScanProcess.running) wifiScanProcess.running = true
                    }
                }

                Process {
                    id: wifiDnsProcess
                    onExited: if (!wifiMetricsProcess.running) wifiMetricsProcess.running = true
                }

                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: if (!powerProcess.running) powerProcess.running = true
                }

                Timer {
                    interval: 30000
                    running: barWindow.agentOpen
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: barWindow.refreshAgentStats()
                }

                Timer {
                    interval: 10000
                    running: barWindow.audioOpen
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: if (!airpodsBatteryProcess.running) airpodsBatteryProcess.running = true
                }

                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        if (!barWindow.audioReady && !audioStatus.running) audioStatus.running = true
                        if (!bluetoothStatus.running) bluetoothStatus.running = true
                        if (!wifiStatus.running) wifiStatus.running = true
                        if (!wifiDetailsProcess.running) wifiDetailsProcess.running = true
                        if (!wifiPingProcess.running) wifiPingProcess.running = true
                        if (!wifiMetricsProcess.running) wifiMetricsProcess.running = true
                        if (!wifiKnownProcess.running) wifiKnownProcess.running = true
                        if (!wifiScanProcess.running) wifiScanProcess.running = true
                    }
                }

                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: if (!chargeFractionProcess.running) chargeFractionProcess.running = true
                }

                Shortcut {
                    sequence: "Escape"
                    onActivated: barWindow.closePopups("")
                }

                PopupWindow {
                    id: audioPopup
                    visible: barWindow.audioOpen
                    color: "transparent"
                    implicitWidth: 390
                    implicitHeight: 420
                    HyprlandFocusGrab {
                        active: barWindow.audioOpen
                        windows: [barWindow, audioPopup]
                        onCleared: barWindow.closePopups("")
                    }
                    anchor {
                        window: barWindow
                        // Anchor at the bar's bottom and expand downward.
                        edges: Edges.Top | Edges.Right
                        gravity: Edges.Bottom | Edges.Right
                        rect.x: barWindow.width - 105
                        rect.y: barWindow.height
                        rect.width: 1
                        rect.height: 1
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 14
                        radius: 24
                        color: "#20232f"
                        border.width: 1
                        border.color: "#53586d"
                    }
                    Canvas {
                        id: audioNotch
                        width: 86; height: 26
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.beginPath()
                            ctx.moveTo(0, 26)
                            ctx.lineTo(0, 15)
                            ctx.bezierCurveTo(0, 6, 10, 0, 20, 0)
                            ctx.lineTo(66, 0)
                            ctx.bezierCurveTo(76, 0, 86, 6, 86, 15)
                            ctx.lineTo(86, 26)
                            ctx.closePath()
                            ctx.fillStyle = "#20232f"
                            ctx.fill()
                            ctx.strokeStyle = "#53586d"
                            ctx.lineWidth = 1
                            ctx.stroke()
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        anchors.topMargin: 32
                        opacity: barWindow.audioOpen ? 1 : 0
                        scale: barWindow.audioOpen ? 1 : 0.96
                        transformOrigin: Item.TopRight
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰕾"; color: "#c9cbf5"; font.pixelSize: 30 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: "Audio"; color: "#eceefe"; font.pixelSize: 19; font.bold: true }
                                Text { text: "EASY LISTENING"; color: "#9da1bb"; font.pixelSize: 11; font.bold: true }
                            }
                            Rectangle {
                                Layout.preferredWidth: 42; Layout.preferredHeight: 28; radius: 5
                                color: barWindow.audioText.indexOf("muted") >= 0 ? "#454858" : "#333747"
                                Text { anchors.centerIn: parent; text: barWindow.audioText.indexOf("muted") >= 0 ? "󰖁" : "󰕾"; color: "#d9dbff"; font.pixelSize: 16 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: barWindow.toggleAudioMute() }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#303342" }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "OUTPUT"; color: "#9da1bb"; font.pixelSize: 12; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: barWindow.audioText.match(/[0-9]+/) || "Muted"; color: "#c9cbf5"; font.pixelSize: 13; font.bold: true }
                        }
                        Rectangle {
                            id: volumeTrack
                            Layout.fillWidth: true; Layout.preferredHeight: 10
                            radius: 6
                            color: "#353846"
                            Rectangle {
                                width: volumeTrack.width * Math.max(0, Math.min(1, Number(barWindow.audioText.match(/[0-9]+/) || 0) / 100))
                                height: parent.height
                                radius: parent.radius
                                color: "#c9cbf5"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: function(mouse) { barWindow.setAudioVolume(mouse.x / width) }
                                onWheel: function(wheel) {
                                    var current = Number(barWindow.audioText.match(/[0-9]+/) || 0) / 100
                                    barWindow.setAudioVolume(current + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 6
                            color: !barWindow.airpodsConnected ? "#414357" : "#252833"
                            Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "󰓃  Laptop Speakers"; color: "#eceefe"; font.pixelSize: 15 }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 56; radius: 6
                            color: barWindow.airpodsConnected ? "#414357" : "#252833"
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { text: "󰋋  Andrey’s AirPods #3"; color: "#eceefe"; font.pixelSize: 15 }
                                Text { text: barWindow.airpodsConnected ? barWindow.airpodsBatteryText : "Disconnected"; color: "#b8bdd3"; font.pixelSize: 11 }
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: bluetoothAction.running ? "Working…" : (barWindow.airpodsConnected ? "Disconnect" : "Connect")
                                color: "#c9cbf5"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !bluetoothAction.running
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: barWindow.toggleAirPods()
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#303342" }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "INPUT"; color: "#9da1bb"; font.pixelSize: 12; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: Math.round(barWindow.inputVolume * 100) + "%"; color: "#c9cbf5"; font.pixelSize: 13; font.bold: true }
                        }
                        Rectangle {
                            id: inputTrack
                            Layout.fillWidth: true; Layout.preferredHeight: 10; radius: 6; color: "#353846"
                            Rectangle { width: inputTrack.width * Math.max(0, Math.min(1, barWindow.inputVolume)); height: parent.height; radius: parent.radius; color: "#c9cbf5" }
                            MouseArea { anchors.fill: parent; enabled: barWindow.audioSourceReady; onClicked: function(mouse) { barWindow.setInputVolume(mouse.x / width) } }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 6; color: "#252833"
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                text: "󰍬  " + (barWindow.audioSourceReady ? (barWindow.audioSource.description || "Built-in Microphone") : "No microphone")
                                color: "#eceefe"; font.pixelSize: 15; elide: Text.ElideRight; width: parent.width - 28
                            }
                        }
                    }
                }

                PopupWindow {
                    visible: barWindow.bluetoothOpen
                    color: "#202124"
                    implicitWidth: 280
                    implicitHeight: 150
                    id: bluetoothPopup
                    HyprlandFocusGrab {
                        active: barWindow.bluetoothOpen
                        windows: [barWindow, bluetoothPopup]
                        onCleared: barWindow.closePopups("")
                    }
                    anchor { window: barWindow; edges: Edges.Top | Edges.Right; gravity: Edges.Bottom | Edges.Right; rect.x: barWindow.width - 135; rect.y: barWindow.height + 8; rect.width: 1; rect.height: 1 }
                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        opacity: barWindow.bluetoothOpen ? 1 : 0
                        scale: barWindow.bluetoothOpen ? 1 : 0.96
                        transformOrigin: Item.TopRight
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        spacing: 8
                        Text { text: barWindow.bluetoothText || "Bluetooth unavailable"; color: "#e8eaed"; font.pixelSize: 12; wrapMode: Text.Wrap }
                        Text {
                            text: barWindow.bluetoothText.indexOf("Powered: yes") >= 0 ? "Turn Bluetooth off" : "Turn Bluetooth on"
                            color: "#8ab4f8"
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    bluetoothAction.command = ["bluetoothctl", "power", barWindow.bluetoothText.indexOf("Powered: yes") >= 0 ? "off" : "on"]
                                    bluetoothAction.running = true
                                }
                            }
                        }
                        Text { text: "Close"; color: "#8ab4f8"; font.pixelSize: 12; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: barWindow.bluetoothOpen = false } }
                    }
                }

                PopupWindow {
                    id: agentPopup
                    visible: barWindow.agentOpen
                    color: "#1b1d27"
                    implicitWidth: 390
                    implicitHeight: 430
                    HyprlandFocusGrab {
                        active: barWindow.agentOpen
                        windows: [barWindow, agentPopup]
                        onCleared: barWindow.closePopups("")
                    }
                    anchor { window: barWindow; edges: Edges.Top | Edges.Right; gravity: Edges.Bottom | Edges.Right; rect.x: barWindow.width - 170; rect.y: barWindow.height + 8; rect.width: 1; rect.height: 1 }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        opacity: barWindow.agentOpen ? 1 : 0
                        scale: barWindow.agentOpen ? 1 : 0.96
                        transformOrigin: Item.TopRight
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 8
                                color: barWindow.selectedAgent === "codex" ? "#276a5a" : "transparent"
                                Image {
                                    anchors.centerIn: parent
                                    source: barWindow.selectedAgent === "codex"
                                        ? "file:///home/wako/.local/share/quattro/shell/plugins/agents/assets/codex.svg"
                                        : (barWindow.selectedAgent === "claude"
                                            ? "file:///home/wako/.local/share/quattro/shell/plugins/agents/assets/claude.svg"
                                            : "file:///home/wako/.config/quickshell/caelestia-minimal/assets/antigravity-light.svg")
                                    width: 26; height: 26; fillMode: Image.PreserveAspectFit
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: barWindow.selectedAgent === "codex" ? "Codex" : (barWindow.selectedAgent === "claude" ? "Claude Code" : "Antigravity"); color: "#f5e8df"; font.pixelSize: 19; font.bold: true }
                                Text { text: "LOCAL AGENT ACTIVITY"; color: "#b6a29a"; font.pixelSize: 11; font.bold: true }
                            }
                            Text { text: barWindow.agentProcessesText + " active"; color: "#f1bd90"; font.pixelSize: 13 }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: ["Codex", "Claude", "Antigravity"]
                                delegate: Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 6
                                    readonly property string key: modelData === "Codex" ? "codex" : (modelData === "Claude" ? "claude" : "antigravity")
                                    color: barWindow.selectedAgent === key ? "#414357" : "#252833"
                                    border.width: 1; border.color: barWindow.selectedAgent === key ? "#777b98" : "#454858"
                                    Row {
                                        anchors.centerIn: parent; spacing: 6
                                        Rectangle {
                                            width: 18; height: 18; radius: 5
                                            color: modelData === "Codex" ? "#276a5a" : "transparent"
                                            Image {
                                                anchors.centerIn: parent
                                                source: modelData === "Codex"
                                                    ? "file:///home/wako/.local/share/quattro/shell/plugins/agents/assets/codex.svg"
                                                    : (modelData === "Claude"
                                                        ? "file:///home/wako/.local/share/quattro/shell/plugins/agents/assets/claude.svg"
                                                        : "file:///home/wako/.config/quickshell/caelestia-minimal/assets/antigravity-light.svg")
                                                width: 15; height: 15; fillMode: Image.PreserveAspectFit
                                            }
                                        }
                                        Text { text: modelData; color: parent.parent.color === "#414357" ? "#f0f1ff" : "#8d91a8"; font.pixelSize: 13 }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { barWindow.selectedAgent = parent.key; barWindow.refreshAgentStats() } }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#303342" }
                        Text { text: "TODAY"; color: "#9da1bb"; font.pixelSize: 11; font.bold: true }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Repeater {
                                model: [["Sessions", barWindow.agentSessionsText], ["Records", barWindow.agentTurnsText], ["Processes", barWindow.agentProcessesText]]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 66; radius: 7; color: "#252833"
                                    Column { anchors.centerIn: parent; spacing: 4
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]; color: "#e9d7ca"; font.pixelSize: 23; font.bold: true }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0].toUpperCase(); color: "#9da1bb"; font.pixelSize: 10; font.bold: true }
                                    }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#303342" }
                        Text { text: "USAGE LIMITS"; color: "#9da1bb"; font.pixelSize: 11; font.bold: true }
                        Repeater {
                            model: barWindow.agentLimits
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true; spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: modelData.label; color: "#d9dced"; font.pixelSize: 13 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: modelData.percent + "%"; color: "#e9d7ca"; font.pixelSize: 13; font.bold: true }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 4; color: "#353846"
                                    Rectangle { width: parent.width * Math.max(0, Math.min(1, modelData.percent / 100)); height: parent.height; radius: parent.radius; color: modelData.percent >= 80 ? "#ef8b8b" : "#c9cbf5" }
                                }
                                Text { text: barWindow.formatLimitReset(modelData.reset); color: "#8d91a8"; font.pixelSize: 11 }
                            }
                        }
                        Rectangle {
                            visible: barWindow.agentLimits.length === 0
                            Layout.fillWidth: true; Layout.preferredHeight: visible ? 52 : 0; radius: 7; color: "#252833"
                            Text { anchors.fill: parent; anchors.margins: 10; text: barWindow.selectedAgent === "antigravity" ? "Antigravity does not expose account limits locally." : "No usage-limit record is available yet."; color: "#b9bdce"; font.pixelSize: 12; wrapMode: Text.Wrap; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }

                PopupWindow {
                    visible: barWindow.wifiOpen
                    color: "transparent"
                    // Soramane opens one surface from above the screen and lets it
                    // settle in the middle. Keep the bar visible and use the same
                    // vertical reveal for the network surface.
                    implicitWidth: Math.min(720, barWindow.width - 48)
                    implicitHeight: 690
                    id: wifiPopup
                    property real revealY: -implicitHeight
                    onVisibleChanged: revealY = visible ? 0 : -implicitHeight
                    HyprlandFocusGrab {
                        active: barWindow.wifiOpen
                        windows: [barWindow, wifiPopup]
                        onCleared: barWindow.closePopups("")
                    }
                    anchor {
                        id: wifiAnchor
                        window: barWindow
                        adjustment: PopupAdjustment.Slide
                        edges: Edges.Top | Edges.Left
                        gravity: Edges.Bottom | Edges.Right
                        rect.width: 1
                        rect.height: 1
                        // This is the same positioning strategy used by
                        // Caelestia's PopupCard: coordinates are assigned at
                        // anchor time, after Quickshell knows the window size.
                        onAnchoring: {
                            // The anchor's gravity is Bottom|Right, so its x
                            // coordinate is the sheet's right edge.
                            wifiAnchor.rect.x = Math.round(barWindow.width / 2 + wifiPopup.implicitWidth / 2)
                            wifiAnchor.rect.y = Math.round(barWindow.height + 10)
                        }
                    }
                    Rectangle {
                        id: wifiSurface
                        x: 0
                        y: wifiPopup.revealY
                        width: parent.width
                        height: parent.height
                        radius: 24
                        color: "#20232f"
                        border.width: 1
                        border.color: "#53586d"
                        Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            anchors.topMargin: 18
                            spacing: 8
                        Rectangle {
                            width: parent.width
                            height: 66
                            radius: 8
                            color: "#2d3139"
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                Text { text: "󰤨"; color: "#8ab4f8"; font.pixelSize: 28 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: barWindow.wifiNetworkName; color: "#f1f3f4"; font.pixelSize: 18; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: "Connected"; color: "#aeb4bf"; font.pixelSize: 12 }
                                }
                            }
                        }
                        GridLayout {
                            width: parent.width
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 8
                            Repeater {
                                model: [
                                    { label: "Ping", value: barWindow.wifiPingText, accent: true },
                                    { label: "Packet loss", value: barWindow.wifiPacketLossText },
                                    { label: "Receiving", value: barWindow.wifiReceivingText },
                                    { label: "Sending", value: barWindow.wifiSendingText },
                                    { label: "Downloaded", value: barWindow.wifiDownloadedText },
                                    { label: "Uploaded", value: barWindow.wifiUploadedText },
                                    { label: "IP address", value: barWindow.wifiIpText },
                                    { label: "Gateway", value: barWindow.wifiGatewayText },
                                    { label: "Wi‑Fi band", value: barWindow.wifiBandText },
                                    { label: "DNS", value: barWindow.wifiDnsText }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 52
                                    radius: 8
                                    color: "#292b30"
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 4
                                        Text { text: modelData.label.toUpperCase(); color: "#9aa0aa"; font.pixelSize: 10; font.bold: true }
                                        Text { text: modelData.value; color: modelData.accent ? "#8ab4f8" : "#e8eaed"; font.family: "monospace"; font.pixelSize: 14; elide: Text.ElideRight; width: parent.width }
                                    }
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: "#3b3d42" }
                        Text { text: "DNS PROVIDER"; color: "#9aa0aa"; font.pixelSize: 11; font.bold: true }
                        RowLayout {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: ["DHCP", "Cloudflare", "Google"]
                                delegate: Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    radius: 6
                                    color: barWindow.wifiDnsProviderText === modelData ? "#3b4658" : "#292b30"
                                    border.width: 1
                                    border.color: barWindow.wifiDnsProviderText === modelData ? "#8ab4f8" : "#41444b"
                                    Text { anchors.centerIn: parent; text: modelData; color: parent.border.color; font.pixelSize: 12 }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: barWindow.wifiInterface !== "" && !wifiDnsProcess.running
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: barWindow.setDnsProvider(modelData)
                                    }
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: "#3b3d42" }
                        Text { text: "KNOWN NETWORKS"; color: "#9aa0aa"; font.pixelSize: 11; font.bold: true }
                        Column {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: {
                                    var names = barWindow.wifiKnownNetworks.slice()
                                    if (barWindow.wifiNetworkName !== "Disconnected" && names.indexOf(barWindow.wifiNetworkName) < 0) names.unshift(barWindow.wifiNetworkName)
                                    return names.slice(0, 3)
                                }
                                delegate: Rectangle {
                                    required property string modelData
                                    width: parent.width
                                    height: 46
                                    radius: 7
                                    color: modelData === barWindow.wifiNetworkName ? "#3b4658" : "#292b30"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "󰤨  " + modelData; color: "#e8eaed"; font.pixelSize: 14 }
                                    Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: barWindow.wifiConnectingName === modelData ? "Connecting…" : (modelData === barWindow.wifiNetworkName ? "Connected" : "Connect"); color: "#8ab4f8"; font.pixelSize: 12 }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: modelData !== barWindow.wifiNetworkName && barWindow.wifiConnectingName === "" && barWindow.wifiInterface !== ""
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            barWindow.wifiConnectingName = modelData
                                            wifiConnectProcess.command = ["iwctl", "station", barWindow.wifiInterface, "connect", modelData]
                                            wifiConnectProcess.running = true
                                        }
                                    }
                                }
                            }
                        }
                        Text { text: "OTHER NETWORKS"; color: "#9aa0aa"; font.pixelSize: 11; font.bold: true }
                        Column {
                            width: parent.width
                            spacing: 3
                            Text {
                                visible: barWindow.wifiOtherNetworks.length === 0
                                text: "Scanning for networks…"
                                color: "#9aa0aa"
                                font.pixelSize: 12
                            }
                            Repeater {
                                model: barWindow.wifiOtherNetworks.slice(0, 4)
                                delegate: Text {
                                    required property string modelData
                                    width: parent.width
                                    text: "󰤪  " + modelData
                                    color: "#c8ccd4"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
                    }

                PopupWindow {
                    visible: barWindow.powerOpen
                    color: "#1b1d27"
                    implicitWidth: 430
                    implicitHeight: 390
                    id: powerPopup
                    HyprlandFocusGrab {
                        active: barWindow.powerOpen
                        windows: [barWindow, powerPopup]
                        onCleared: barWindow.closePopups("")
                    }
                    anchor {
                        window: barWindow
                        edges: Edges.Top | Edges.Right
                        gravity: Edges.Bottom | Edges.Right
                        rect.x: barWindow.width - 18
                        rect.y: barWindow.height + 8
                        rect.width: 1
                        rect.height: 1
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        opacity: barWindow.powerOpen ? 1 : 0
                        scale: barWindow.powerOpen ? 1 : 0.96
                        transformOrigin: Item.TopRight
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰁹"; color: "#c9cbf5"; font.pixelSize: 30 }
                            ColumnLayout {
                                spacing: 1
                                Text { text: "Battery"; color: "#eceefe"; font.pixelSize: 19; font.bold: true }
                                Text { text: barWindow.batteryStatus.toUpperCase(); color: "#9da1bb"; font.pixelSize: 11; font.bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property real charge: barWindow.correctedFraction >= 0 ? barWindow.correctedFraction : 0
                                text: Math.round(charge * 100) + "%"
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                color: "#d9dbff"; font.pixelSize: 40
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 12; radius: 6; color: "#2c2f3d"
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, barWindow.correctedFraction >= 0 ? barWindow.correctedFraction : 0))
                                height: parent.height; radius: parent.radius; color: "#c9cbf5"
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true; columns: 2; columnSpacing: 30; rowSpacing: 8
                            Text { text: "Design capacity"; color: "#9da1bb"; font.pixelSize: 13 }
                            Text { text: barWindow.batteryCapacityText; color: "#e5e7fa"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                            Text { text: "Charge cycles"; color: "#9da1bb"; font.pixelSize: 13 }
                            Text { text: barWindow.batteryCyclesText; color: "#e5e7fa"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                            Text { text: "Charge limit"; color: "#9da1bb"; font.pixelSize: 13 }
                            Text { text: barWindow.batteryLimitText; color: "#e5e7fa"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                            Text { text: "Power profile"; color: "#9da1bb"; font.pixelSize: 13 }
                            Text { text: barWindow.batteryProfileText; color: "#e5e7fa"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                            Text { text: "Power draw"; color: "#9da1bb"; font.pixelSize: 13 }
                            Text { text: barWindow.batteryPowerText; color: "#e5e7fa"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                            Text { text: "Voltage"; color: "#9da1bb"; font.pixelSize: 13 }
                            Text { text: barWindow.batteryVoltageText; color: "#e5e7fa"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                            Text { text: "Current"; color: "#9da1bb"; font.pixelSize: 13 }
                            Text { text: barWindow.batteryCurrentText; color: "#e5e7fa"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#303342" }
                        Text { text: "POWER PROFILE"; color: "#9da1bb"; font.pixelSize: 11; font.bold: true }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: ["Power saver", "Balanced", "Performance"]
                                delegate: Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 7
                                    readonly property bool selected: barWindow.batteryProfileText.toLowerCase().indexOf(modelData.toLowerCase()) >= 0
                                    color: selected ? "#414357" : "#252833"
                                    border.width: 1; border.color: selected ? "#74789c" : "#454858"
                                    Text { anchors.centerIn: parent; text: powerProfileAction.running ? "Applying…" : modelData; color: parent.selected ? "#f0f1ff" : "#aeb2ca"; font.pixelSize: 13 }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !powerProfileAction.running
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: barWindow.setPowerProfile(modelData === "Power saver" ? "power-saver" : modelData.toLowerCase())
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
