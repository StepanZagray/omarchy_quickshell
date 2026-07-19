import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Owns org.freedesktop.Notifications and exposes the live model plus the
// keyboard operations that Mako previously provided.
Item {
    id: service

    readonly property var notifications: server.trackedNotifications
    property bool silent: false
    property var lastDismissed: null

    function values() {
        return server.trackedNotifications.values;
    }

    function snapshot(notification) {
        if (!notification)
            return null;
        return {
            appName: String(notification.appName || "Notification"),
            appIcon: String(notification.appIcon || ""),
            summary: String(notification.summary || "Notification"),
            body: String(notification.body || ""),
            urgency: notification.urgency
        };
    }

    function dismissLast() {
        const list = service.values();
        if (list.length === 0)
            return;
        const notification = list[list.length - 1];
        service.lastDismissed = service.snapshot(notification);
        notification.dismiss();
    }

    function dismissAll() {
        const list = service.values().slice();
        if (list.length > 0)
            service.lastDismissed = service.snapshot(list[list.length - 1]);
        for (let i = list.length - 1; i >= 0; i--)
            list[i].dismiss();
    }

    function invoke(notification) {
        if (!notification)
            return;
        const actions = notification.actions;
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") {
                actions[i].invoke();
                return;
            }
        }
        if (actions.length > 0)
            actions[0].invoke();
    }

    function invokeLast() {
        const list = service.values();
        if (list.length > 0)
            service.invoke(list[list.length - 1]);
    }

    function restoreLast() {
        const saved = service.lastDismissed;
        if (!saved)
            return;
        service.lastDismissed = null;
        let urgency = "normal";
        if (saved.urgency === NotificationUrgency.Low)
            urgency = "low";
        else if (saved.urgency === NotificationUrgency.Critical)
            urgency = "critical";
        const command = ["notify-send", "-a", saved.appName, "-u", urgency];
        if (saved.appIcon.length > 0)
            command.push("-i", saved.appIcon);
        command.push(saved.summary, saved.body);
        Quickshell.execDetached(command);
    }

    function toggleSilent() {
        service.silent = !service.silent;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false

        onNotification: function(notification) {
            notification.tracked = !service.silent;
        }
    }
}
