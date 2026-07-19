import QtQuick
import Quickshell.Io

// Executes selected Omni rows and Quick tiles. Keeping launch policy here
// makes OmniMenu.qml a state coordinator instead of a shell-command catalog.
Item {
    id: dispatcher

    required property var omni
    required property var processes
    required property var bookmarks
    required property var ollamaChat

    Process { id: runner; running: false }

    function runDetached(command) {
        runner.command = ["sh", "-c",
                          "setsid -f uwsm-app -- bash -c "
                          + JSON.stringify(command)
                          + " >/dev/null 2>&1"];
        runner.running = false;
        runner.running = true;
    }

    function activateQuickTile(tile) {
        if (!tile || !tile.action) return;
        dispatcher.runDetached(tile.action);
        dispatcher.omni.close();
    }

    function longActivateQuickTile(tile) {
        if (!tile || !tile.longAction) return;
        dispatcher.runDetached(tile.longAction);
    }

    function activate(item) {
        if (!item) return;

        if (item.isCategory) {
            dispatcher.omni.categoryFilter = item.target;
            dispatcher.omni.query = "";
            dispatcher.omni.selectedIndex = 0;
            return;
        }

        if (item.isProcess) {
            dispatcher.processes.killPid(item.pid, false);
            return;
        }

        if (item.isTheme) {
            runner.command = ["sh", "-c",
                "setsid -f uwsm-app -- omarchy-theme-set \"$1\" >/dev/null 2>&1",
                "sh", item.themeName];
            runner.running = false;
            runner.running = true;
            dispatcher.omni.close();
            return;
        }

        if (item.isOllama) {
            const status = dispatcher.ollamaChat.status;
            if (status === "no-ollama") return;

            if (status === "no-daemon") {
                runner.command = ["setsid", "-f", "uwsm-app", "--",
                    "xdg-terminal-exec",
                    "--app-id=org.omarchy.terminal",
                    "--title=Omarchy",
                    "-e", "bash", "-c",
                    "echo 'Starting ollama daemon...'; "
                    + "systemctl --user start ollama 2>/dev/null "
                    + "|| sudo systemctl start ollama 2>/dev/null "
                    + "|| ollama serve; "
                    + "echo; echo '[done — close to return]'; exec bash"];
                runner.running = false;
                runner.running = true;
                dispatcher.omni.close();
                return;
            }

            if (status === "no-model") {
                runner.command = ["setsid", "-f", "uwsm-app", "--",
                    "xdg-terminal-exec",
                    "--app-id=org.omarchy.terminal",
                    "--title=Omarchy",
                    "-e", "bash", "-c",
                    "ollama pull \"$1\"; "
                    + "echo; echo '[done — close to return]'; exec bash",
                    "--", dispatcher.ollamaChat.model_];
                runner.running = false;
                runner.running = true;
                dispatcher.omni.close();
                return;
            }

            if (status === "ok" && !dispatcher.ollamaChat.submitted)
                dispatcher.ollamaChat.submit();
            return;
        }

        if (item.isTldr) {
            runner.command = ["setsid", "-f", "uwsm-app", "--",
                "xdg-terminal-exec",
                "--app-id=org.omarchy.terminal",
                "--title=Omarchy",
                "-e", "bash", "-c",
                "read -e -i \"$1 \" line; eval \"$line\"; exec bash",
                "_", item.tldrPreFill || item.tldrName || ""];
            runner.running = false;
            runner.running = true;
            dispatcher.omni.close();
            return;
        }

        dispatcher.bookmarks.record(item);
        const command = item.tui ? item.tui + " " + item.exec : item.exec;
        dispatcher.runDetached(command);
        dispatcher.omni.close();
    }
}
