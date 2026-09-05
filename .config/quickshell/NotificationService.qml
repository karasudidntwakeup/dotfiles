import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Owns the org.freedesktop.Notifications daemon + history/popup models.
// UI/style lives in the card components; this file only manages state.
Item {
    id: svc

    property bool dnd: false // persisted to disk
    property bool centerOpen: false
    property int unreadCount: 0
    property var liveNotifs: ({})

    ListModel {
        id: historyModel
    }
    ListModel {
        id: popupsModel
    }
    property alias history: historyModel
    property alias popups: popupsModel

    property real lastNotifTime: 0
    property bool _loadingDnd: true

    function nextUid() {
        var id
        do {
            id = Math.floor(Math.random() * 0x7fffffff)
        } while (svc.liveNotifs[id] !== undefined)
        return id
    }

    // Resolve icon: desktop-entry > app icon > `image://icon/<name>` URL.
    // Returns a theme-icon NAME (or path); the card resolves names via iconPathFor.
    function resolveIcon(appName, desktopEntry, appIcon, image) {
        var entry = null
        if (desktopEntry && desktopEntry !== "")
            entry = DesktopEntries.byId(desktopEntry)
        if (!entry && appName && appName !== "")
            entry = DesktopEntries.heuristicLookup(appName)
        if (entry && entry.icon) return entry.icon
        if (appIcon && appIcon !== "") return appIcon
        var img = image ? image.toString() : ""
        if (img.indexOf("image://icon/") === 0) {
            var inner = img.substring("image://icon/".length)
            if (inner !== "") return inner
        }
        return ""
    }

    // Quickshell.iconPath() only rewraps image://icon URLs, so we resolve plain
    // theme names to real files ourselves (cached, one shell call per name).
    function iconPathFor(name) {
        if (!name || name === "") return ""
        var n = name.toString()
        if (n.indexOf("file://") === 0) n = n.substring("file://".length)
        if (n.indexOf("://") !== -1 || n.charAt(0) === "/") return n
        if (svc.iconCache[n] !== undefined) return svc.iconCache[n] || ""
        svc.resolveIconName(n)
        return ""
    }

    function resolveIconName(name) {
        if (svc.iconPending[name]) return
        svc.iconPending[name] = "queued"
        svc.drainIconQueue()
    }

    function drainIconQueue() {
        if (svc.iconResolving !== "") return
        for (var k in svc.iconPending) {
            if (svc.iconPending[k] === "queued") {
                svc.iconResolving = k
                svc.iconResolver.exec(["bash", "-c", svc.iconResolveScript, "iconresolver", k])
                return
            }
        }
    }

    property var iconCache: ({})
    property var iconPending: ({})
    property string iconResolving: ""
    signal iconPathsUpdated()
    property string iconResolveScript: `
        name="${'$'}1"
        [ -z "${'$'}name" ] && exit 1
        for f in "${'$'}name" "${'$'}name.svg" "${'$'}name.png" "${'$'}name.xpm"; do
            for b in /home/karasu/.local/share/icons /usr/share/icons /usr/share/pixmaps; do
                if [ -f "${'$'}b/${'$'}f" ]; then printf '%s' "${'$'}b/${'$'}f"; exit 0; fi
            done
        done
        theme=""
        if [ -f /home/karasu/.config/gtk-3.0/settings.ini ]; then
            theme=$(sed -n 's/^[[:space:]]*gtk-icon-theme-name=//p' /home/karasu/.config/gtk-3.0/settings.ini | head -n1)
        fi
        for t in "${'$'}theme" MacTahoe-dark MacTahoe MacTahoe-light Tahoe-Dark Mkos-Big-Sur breeze-dark breeze default Adwaita hicolor; do
            for b in /home/karasu/.local/share/icons /usr/share/icons; do
                [ -d "${'$'}b/${'$'}t" ] || continue
                for ext in svg png xpm; do
                    for dir in \
                        "${'$'}b/${'$'}t/apps/scalable" "${'$'}b/${'$'}t/apps/128x128" "${'$'}b/${'$'}t/apps/64x64" "${'$'}b/${'$'}t/apps/48x48" "${'$'}b/${'$'}t/apps/32x32" "${'$'}b/${'$'}t/apps/24x24" "${'$'}b/${'$'}t/apps/22x22" "${'$'}b/${'$'}t/apps/16x16" \
                        "${'$'}b/${'$'}t/actions/scalable" "${'$'}b/${'$'}t/status/scalable" "${'$'}b/${'$'}t/devices/scalable" "${'$'}b/${'$'}t/places/scalable" "${'$'}b/${'$'}t/categories/scalable" "${'$'}b/${'$'}t/mimetypes/scalable" \
                        "${'$'}b/${'$'}t/scalable/apps" "${'$'}b/${'$'}t/scalable/actions" "${'$'}b/${'$'}t/scalable/status" "${'$'}b/${'$'}t/scalable/devices" "${'$'}b/${'$'}t/scalable/places" \
                        "${'$'}b/${'$'}t/128x128/apps" "${'$'}b/${'$'}t/64x64/apps" "${'$'}b/${'$'}t/48x48/apps" "${'$'}b/${'$'}t/32x32/apps" "${'$'}b/${'$'}t/24x24/apps" "${'$'}b/${'$'}t/16x16/apps"
                    do
                        if [ -f "${'$'}dir/${'$'}name.${'$'}ext" ]; then printf '%s' "${'$'}dir/${'$'}name.${'$'}ext"; exit 0; fi
                    done
                done
                for dir in "${'$'}b/${'$'}t/apps/symbolic" "${'$'}b/${'$'}t/status/symbolic" "${'$'}b/${'$'}t/devices/symbolic"; do
                    if [ -f "${'$'}dir/${'$'}name-symbolic.svg" ]; then printf '%s' "${'$'}dir/${'$'}name-symbolic.svg"; exit 0; fi
                done
            done
        done
        exit 1
    `

    property string iconResolverOut: ""
    property Process iconResolver: Process {
        id: iconResolver
        stdout: SplitParser {
            onRead: data => {
                svc.iconResolverOut = data ? data.toString().trim() : ""
            }
        }
        onExited: code => {
            var name = svc.iconResolving
            var path = svc.iconResolverOut
            svc.iconCache[name] = (code === 0 && path) ? path : null
            svc.iconPending[name] = "done"
            svc.iconResolving = ""
            svc.iconResolverOut = ""
            svc.drainIconQueue()
            svc.iconPathsUpdated()
        }
    }

    function recountUnread() {
        var c = 0
        for (var i = 0; i < historyModel.count; i++)
            if (!historyModel.get(i).read) c++
        svc.unreadCount = c
    }

    function markRead(uid) {
        for (var i = 0; i < historyModel.count; i++) {
            var it = historyModel.get(i)
            if (it.uid === uid && !it.read) {
                historyModel.setProperty(i, "read", true)
                svc.recountUnread()
                break
            }
        }
    }

    function removeFromModel(model, uid) {
        for (var i = model.count - 1; i >= 0; i--) {
            if (model.get(i).uid === uid) {
                model.remove(i, 1)
                return
            }
        }
    }

    // Timeout/swipe-hide: toast disappears, stays in history (read).
    function hidePopup(uid) {
        svc.removeFromModel(popupsModel, uid)
        delete svc.liveNotifs[uid]
        svc.markRead(uid)
    }

    // Explicit dismissal: closes the DBus notification and drops it from history.
    function dismissNotif(uid) {
        var n = svc.liveNotifs[uid]
        if (n && typeof n.dismiss === "function") n.dismiss()
        svc.removeFromModel(popupsModel, uid)
        svc.removeFromModel(historyModel, uid)
        delete svc.liveNotifs[uid]
        svc.recountUnread()
    }

    function clearAll() {
        for (var key in svc.liveNotifs) {
            var n = svc.liveNotifs[key]
            if (n && typeof n.dismiss === "function") n.dismiss()
        }
        svc.liveNotifs = {}
        historyModel.clear()
        popupsModel.clear()
        svc.recountUnread()
    }

    function openCenter() { svc.centerOpen = true }
    function closeCenter() { svc.centerOpen = false }
    function toggleCenter() { svc.centerOpen = !svc.centerOpen }

    // Recompute unread whenever history is mutated.
    Connections {
        target: historyModel
        function onCountChanged() { svc.recountUnread() }
    }

    // DND persistence
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/notif-config.json"
        preload: true
        printErrors: false

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) cfgFile.writeAdapter()
        }
        onAdapterUpdated: cfgFile.writeAdapter()

        onLoaded: {
            svc._loadingDnd = true
            if (cfgAdapter.dnd !== undefined) svc.dnd = Boolean(cfgAdapter.dnd)
            Qt.callLater(() => svc._loadingDnd = false)
        }

        JsonAdapter {
            id: cfgAdapter
            property var dnd: false
        }
    }

    onDndChanged: {
        if (!svc._loadingDnd) cfgAdapter.dnd = svc.dnd
    }

    // DBus daemon
    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            var n = notification
            var now = Date.now()

            // Swallow duplicates from the same burst (<100ms).
            if (n.urgency !== NotificationUrgency.Critical && now - svc.lastNotifTime < 100)
                return
            svc.lastNotifTime = now

            n.tracked = true

            var acts = []
            if (n.actions) {
                for (var i = 0; i < n.actions.length; i++) {
                    acts.push({
                        id: n.actions[i].identifier || "",
                        text: n.actions[i].text || n.actions[i].name || "Action"
                    })
                }
            }

            var uid = svc.nextUid()
            svc.liveNotifs[uid] = n

            var imageVal = ""
            if (n.image) {
                var imgS = n.image.toString()
                if (imgS.length > 0 && imgS.indexOf("image://icon/") !== 0) imageVal = imgS
            }
            if (!imageVal && n.imagePath) {
                var imgP = n.imagePath.toString()
                if (imgP.length > 0 && imgP.indexOf("image://icon/") !== 0) imageVal = imgP
            }
            var appLabel = (n.appName && n.appName !== "") ? n.appName : "System"
            var summaryText = (n.summary && n.summary !== "") ? n.summary : "Notification"
            var bodyText = n.body || ""
            var iconName = svc.resolveIcon(n.appName, n.desktopEntry, n.appIcon, n.image)

            var entry = {
                uid: uid,
                appName: appLabel,
                desktopEntry: n.desktopEntry || "",
                appIcon: n.appIcon || "",
                iconName: iconName,
                image: imageVal,
                summary: summaryText,
                body: bodyText,
                actionsJson: JSON.stringify(acts),
                hasActions: acts.length > 0,
                notif: n,
                timestamp: now,
                urgency: n.urgency,
                read: false
            }

            historyModel.insert(0, entry)

            n.closed.connect(() => {
                if (svc.liveNotifs[uid] !== undefined) {
                    delete svc.liveNotifs[uid]
                    svc.removeFromModel(popupsModel, uid)
                    svc.markRead(uid)
                }
            })

            if (!svc.dnd || n.urgency === NotificationUrgency.Critical) {
                if (!svc.centerOpen) {
                    popupsModel.insert(0, {
                        uid: uid,
                        appName: appLabel,
                        desktopEntry: entry.desktopEntry,
                        appIcon: entry.appIcon,
                        iconName: iconName,
                        image: imageVal,
                        summary: summaryText,
                        body: bodyText,
                        actionsJson: entry.actionsJson,
                        hasActions: acts.length > 0,
                        notif: n,
                        timestamp: now,
                        urgency: n.urgency
                    })
                }
            }
        }
    }
}