import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var shell
    property string audioIcon: ""
    property int audioVol: 0
    property bool audioMuted: false
    property var audioSinks: []
    property string audioDefaultSink: ""
    property string _audioSinksSer: ""

    function setDefaultSink(id) {
        if (!id)
            return;

        root.audioDefaultSink = id;
        shell.run("wpctl set-default " + id);
        audioSinksProbe.running = false;
        audioSinksProbe.running = true;
    }

    function refreshAudioSinks() {
        audioSinksProbe.running = false;
        audioSinksProbe.running = true;
    }

    function setVolume(pct) {
        pct = Math.max(0, Math.min(150, Math.round(pct)));
        root.audioVol = pct;
        shell.run("pamixer --allow-boost --set-volume " + pct);
    }

    function toggleMute() {
        root.audioMuted = !root.audioMuted;
        shell.run("pamixer -t");
    }

    Process {
        id: audioProbe

        running: false
        command: ["bash", "-lc", "v=$(pamixer --get-volume 2>/dev/null || echo 0); " + "m=$(pamixer --get-mute 2>/dev/null || echo false); " + "printf '%s|%s' \"$v\" \"$m\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("|");
                if (p.length !== 2)
                    return;

                const v = parseInt(p[0]);
                const m = p[1].trim() === "true";
                root.audioVol = isNaN(v) ? 0 : v;
                root.audioMuted = m;
                if (m)
                    root.audioIcon = shell.icoMute;
                else if (isNaN(v) || v <= 0)
                    root.audioIcon = shell.icoVol1;
                else if (v < 50)
                    root.audioIcon = shell.icoVol2;
                else
                    root.audioIcon = shell.icoVol3;
            }
        }

    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            audioProbe.running = false;
            audioProbe.running = true;
        }
    }

    Process {
        id: audioSinksProbe

        running: false
        command: ["bash", "-lc", "wpctl status 2>/dev/null | awk '" + "  /^Audio$/                                    {sec=\"audio\"; sub=\"\"; next}" + "  /^[A-Z][a-zA-Z]+$/                           {sec=\"\";      sub=\"\"; next}" + "  /^[[:space:]]*[├└]─[[:space:]]*Sinks:/       {sub=\"sinks\"; next}" + "  /^[[:space:]]*[├└]─/                          {sub=\"\";      next}" + "  sec==\"audio\" && sub==\"sinks\" {" + "    star=(index($0,\"*\")>0 && index($0,\"*\")<index($0,\".\")) ? 1 : 0;" + "    line=$0;" + "    sub(/^[ │├─└*]+/, \"\", line);" + "    if (match(line, /^([0-9]+)\\. (.+)\\[/, m)) {" + "      gsub(/[ \\t]+$/, \"\", m[2]);" + "      printf \"%s\\t%s\\t%d\\n\", m[1], m[2], star;" + "    }" + "  }'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter((s) => {
                    return s.length > 0;
                });
                const sinks = lines.map((line) => {
                    const f = line.split("\t");
                    return {
                        "id": f[0] || "",
                        "name": (f[1] || "").trim(),
                        "isDefault": f[2] === "1"
                    };
                });
                const ser = JSON.stringify(sinks);
                if (ser !== root._audioSinksSer) {
                    root._audioSinksSer = ser;
                    root.audioSinks = sinks;
                }
                const def = sinks.find((s) => {
                    return s.isDefault;
                });
                if (def && root.audioDefaultSink !== def.id)
                    root.audioDefaultSink = def.id;

            }
        }

    }

}
