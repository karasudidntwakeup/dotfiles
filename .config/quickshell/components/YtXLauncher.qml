pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: ytx

    property var rootRef: null
    property bool active: false
    property bool searching: false
    property bool searchFailed: false
    property string activeQuery: ""
    readonly property int cornerRadius: 12
    readonly property int pad: 14
    readonly property int cardWidth: Math.min(640, Math.max(0, ytx.width - 32))
    readonly property int searchHeight: 36
    readonly property int maxItems: 48
    readonly property int visibleRows: 2
    readonly property int columns: Math.max(1, Math.min(4, Math.floor((cardWidth - pad * 2 + gridSpacing) / 180)))
    readonly property int gridSpacing: 12
    readonly property real cellWidth: (cardWidth - pad * 2 + gridSpacing) / columns - gridSpacing
    readonly property int cellInset: 5
    readonly property real thumbWidth: cellWidth - cellInset * 2
    readonly property int thumbHeight: Math.round(thumbWidth * 9 / 16)
    readonly property int titleHeight: Math.round((fontSize - 1) * 1.2) * 2
    readonly property int channelHeight: Math.max(10, fontSize - 3)
    readonly property int cellHeight: cellInset * 2 + thumbHeight + 7 + titleHeight + 3 + channelHeight
    readonly property string cardTile: "ytx_card"
    // Muted take on the periwinkle token — text/borders follow via contrastColor.
    readonly property color cardColor: {
        var base = rootRef ? (rootRef.qsLight ? (rootRef.pillColor(cardTile)) : rootRef.colorOf(cardTile)) : "#f3dfd1"
        if (rootRef && rootRef.mixColor && rootRef.colorOf)
            base = rootRef.mixColor(base, rootRef.colorOf("surface_container_highest"), 0.2)
        return Qt.darker(base, 1.2)
    }
    readonly property color cardBorder: rootRef ? rootRef.withAlpha(rootRef.colorOf("widget_border"), rootRef.qsLight ? 0.7 : 0.5) : "#00000000"
    readonly property color fg: rootRef ? rootRef.contrastColor(ytx.cardColor) : "#000000"
    readonly property color accent: rootRef
        ? Qt.color(rootRef.colorOf("widget_error"))
        : "#bf616a"
    // Solid darkened selection bg: the old translucent-accent wash on the
    // pink card measured ~1.1:1 and red-on-pink text ~1.36:1 (unreadable).
    readonly property color selBg: Qt.darker(ytx.accent, 1.5)

    // Text/alpha helpers live on root (contrastColor/withAlpha).
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string fontFamily: uiFont
    readonly property string uiFont: "Geist"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    property real animProgress: ytx.active ? 1 : 0
    readonly property int bottomMargin: 24

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string thumbCache: homeDir + "/.cache/rofi-youtube"
    property real thumbTicks: 0
    property var videos: []
    property bool initialized: false
    property bool homeLoaded: false
    property bool homeFailed: false
    property bool pendingHome: false
    property bool showingRecent: false
    readonly property bool showingHome: !ytx.showingRecent && !ytx.searching && ytx.activeQuery.length === 0
    property var prefetched: ({
    })

    Process {
        id: thumbProc
        onExited: () => {
            ytx.thumbTicks++
        }
    }

    Process {
        id: homeProc

        onExited: (exitCode, exitStatus) => {
            ytx.pendingHome = false;
            if (exitCode === 0 && exitStatus === 0)
                homeFile.reload();
            else if (ytx.showingHome)
                ytx.homeFailed = true;
        }
    }

    signal requestClose()

    // (alpha helper removed: use rootRef.withAlpha)

    function loadRecent() {
        if (recentFile)
            recentFile.reload();
    }

    function onRecentData(obj) {
        if (!obj || !obj.entries || !ytx.active || !ytx.showingRecent)
            return ;

        var arr = [];
        for (var i = 0; i < obj.entries.length && arr.length < ytx.maxItems; i++) {
            var e = obj.entries[i];
            if (!e || !e.id || !e.url)
                continue;

            arr.push({
                "title": e.title || "",
                "vid": e.id,
                "url": e.url,
                "channel": e.channel || "",
                "thumb": ytx.thumbCache + "/" + e.id + ".jpg"
            });
        }
        ytx.videos = arr;
        if (ytx.active)
            ytx.filter(searchField.text);

        ytx.prefetchThumbs(arr);
    }

    function prefetchThumbs(arr) {
        if (!ytx.active) return
        var cmds = [];
        for (var i = 0; i < arr.length; i++) {
            var v = arr[i];
            if (ytx.prefetched[v.vid])
                continue;

            ytx.prefetched[v.vid] = true;
            cmds.push("test -s '" + v.thumb + "' || { curl -sfL --max-time 10 " + "'https://i.ytimg.com/vi/" + v.vid + "/mqdefault.jpg' -o '" + v.thumb + ".part' && mv '" + v.thumb + ".part' '" + v.thumb + "'; }");
        }
        if (cmds.length === 0) return
        thumbProc.command = ["bash", "-c", cmds.join("; ")];
    }

    function isSubsequence(sub, str) {
        var i = 0;
        var j = 0;
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j])
                i++;

            j++;
        }
        return i === sub.length;
    }

    function filter(text) {
        var q = text.trim().toLowerCase();
        listModel.clear();
        for (var i = 0; i < ytx.videos.length; i++) {
            var v = ytx.videos[i];
            var titleLower = v.title.toLowerCase();
            var ok = q.length === 0 || titleLower.indexOf(q) >= 0 || (v.channel.length > 0 && v.channel.toLowerCase().indexOf(q) >= 0) || ytx.isSubsequence(q, titleLower);
            if (!ok)
                continue;

            listModel.append({
                "title": v.title,
                "vid": v.vid,
                "url": v.url,
                "channel": v.channel,
                "thumb": v.thumb
            });
        }
        grid.currentIndex = listModel.count > 0 ? 0 : -1;
        grid.positionViewAtBeginning();
    }

    function play(args) {
        var cmd = ["bash", Quickshell.shellDir + "/scripts/ytx-play.sh"];
        for (var i = 0; i < args.length; i++)
            cmd.push(args[i]);
        Quickshell.execDetached(cmd);
    }

    function activate(asAudio) {
        var idx = grid.currentIndex;
        if (idx < 0 || idx >= listModel.count)
            return ;

        var it = listModel.get(idx);
        if (!it.url)
            return ;

        if (asAudio)
            ytx.play(["--no-video", "--ytdl-format=bestaudio/best", "--force-media-title=" + it.title, it.url]);
        else
            ytx.play(["--force-media-title=" + it.title, it.url]);
        ytx.requestClose();
    }

    function playAll(asAudio) {
        var urls = [];
        for (var i = 0; i < listModel.count; i++) {
            var it = listModel.get(i);
            if (it.url)
                urls.push(it.url);
        }
        if (urls.length === 0)
            return ;

        var args = [];
        if (asAudio)
            args.push("--no-video", "--ytdl-format=bestaudio/best");
        for (var j = 0; j < urls.length; j++)
            args.push(urls[j]);
        ytx.play(args);
        ytx.requestClose();
    }

    function runSearch(q) {
        var query = q.trim();
        if (query.length === 0)
            return ;

        ytx.pendingHome = false;
        ytx.showingRecent = false;
        ytx.homeFailed = false;

        ytx.activeQuery = query;
        ytx.searchFailed = false;
        ytx.searching = true;
        Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/ytx-search.sh", query]);
    }

    function onSearchResults(obj) {
        if (!ytx.searching)
            return ;

        ytx.searching = false;
        if (!obj || !obj.results || obj.results.length === 0) {
            ytx.searchFailed = true;
            return ;
        }
        ytx.searchFailed = false;
        var arr = [];
        for (var i = 0; i < obj.results.length && arr.length < ytx.maxItems; i++) {
            var r = obj.results[i];
            if (!r || !r.id || !r.url)
                continue;

            arr.push({
                "title": r.title || "",
                "vid": r.id,
                "url": r.url,
                "channel": r.channel || "",
                "thumb": ytx.thumbCache + "/" + r.id + ".jpg"
            });
        }
        if (arr.length === 0) {
            ytx.searchFailed = true;
            return ;
        }
        ytx.videos = arr;
        ytx.filter("");
        ytx.prefetchThumbs(arr);
    }

    function showRecent() {
        searchField.text = "";
        ytx.videos = [];
        ytx.filter("");
        ytx.activeQuery = "";
        ytx.searching = false;
        ytx.searchFailed = false;
        ytx.homeLoaded = false;
        ytx.homeFailed = false;
        ytx.pendingHome = false;
        ytx.showingRecent = true;
        ytx.loadRecent();
        ytx.filter(searchField.text);
    }

    function ensureHome(force) {
        var switching = !ytx.showingHome;
        searchField.text = "";
        ytx.activeQuery = "";
        ytx.searching = false;
        ytx.searchFailed = false;
        ytx.showingRecent = false;
        if (switching) {
            ytx.videos = [];
            ytx.homeLoaded = false;
        }
        ytx.filter("");
        homeFile.reload();
        ytx.refreshFeed(force);
    }

    function refreshFeed(force) {
        if (homeProc.running)
            return ;

        ytx.homeFailed = false;
        ytx.pendingHome = true;
        homeProc.command = ["bash", Quickshell.shellDir + "/scripts/ytx-home.sh", "feed", force ? "force" : ""];
        homeProc.running = true;
    }

    function onHomeResults(obj) {
        if (!ytx.showingHome || !ytx.active)
            return ;

        ytx.pendingHome = homeProc.running;
        if (!obj || !obj.results || obj.results.length === 0) {
            ytx.homeFailed = true;
            return ;
        }
        var arr = [];
        for (var i = 0; i < obj.results.length && arr.length < ytx.maxItems; i++) {
            var r = obj.results[i];
            if (!r || !r.id || !r.url)
                continue;

            arr.push({
                "title": r.title || "",
                "vid": r.id,
                "url": r.url,
                "channel": r.channel || "",
                "thumb": ytx.thumbCache + "/" + r.id + ".jpg"
            });
        }
        if (arr.length === 0) {
            ytx.homeFailed = true;
            return ;
        }
        ytx.homeLoaded = true;
        ytx.homeFailed = false;
        if (JSON.stringify(ytx.videos) !== JSON.stringify(arr)) {
            ytx.videos = arr;
            ytx.filter(searchField.text);
            ytx.prefetchThumbs(arr);
        }
    }

    function gridHeight() {
        var rows = Math.min(Math.ceil(listModel.count / ytx.columns), ytx.visibleRows);
        if (rows < 1)
            rows = 1;

        return rows * ytx.cellHeight + (rows - 1) * ytx.gridSpacing;
    }

    opacity: ytx.animProgress
    onActiveChanged: {
        if (ytx.active) {
            if (!ytx.initialized) {
                ytx.initialized = true;
                ytx.ensureHome(false);
            } else if (ytx.showingHome) {
                homeFile.reload();
                ytx.refreshFeed(false);
            }
            focusRequest.restart();
        } else {
            focusRequest.stop();
        }
    }

    ListModel {
        id: listModel
    }

    FileView {
        id: searchFile

        property var resultData: ({
        })

        path: ytx.homeDir + "/.cache/quickshell/ytx-results.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: searchFile.reload()
        onLoaded: {
            if (!ytx.searching)
                return ;

            try {
                var obj = JSON.parse(String(searchFile.text()));
                ytx.onSearchResults(obj);
            } catch (err) {
                console.log("[ytx] search parse error:", err);
                ytx.searching = false;
            }
        }
        onLoadFailed: (error) => {
            console.log("[ytx] search results load failed:", error);
            ytx.searching = false;
        }
    }

    FileView {
        id: homeFile

        path: ytx.homeDir + "/.cache/quickshell/ytx-home.json"
        watchChanges: true
        blockLoading: false
        onFileChanged: homeFile.reload()
        onLoaded: {
            if (!ytx.showingHome)
                return ;

            try {
                var obj = JSON.parse(String(homeFile.text()));
                ytx.onHomeResults(obj);
            } catch (err) {
                console.log("[ytx] home parse error:", err);
                ytx.pendingHome = homeProc.running;
                ytx.homeFailed = true;
            }
        }
        onLoadFailed: (error) => {
            if (!ytx.showingHome)
                return ;

            console.log("[ytx] home results load failed:", error);
            ytx.pendingHome = homeProc.running;
            ytx.homeFailed = true;
        }
    }

    FileView {
        id: recentFile

        path: ytx.homeDir + "/.config/yt-x/recent.json"
        watchChanges: false
        blockLoading: true
        onLoaded: {
            if (!ytx.showingRecent)
                return ;

            try {
                var obj = JSON.parse(String(recentFile.text()));
                ytx.onRecentData(obj);
            } catch (err) {
                console.log("[ytx] recent parse error:", err);
            }
        }
        onLoadFailed: (error) => {
            console.log("[ytx] recent load failed:", error);
        }
    }

    Timer {
        id: focusRequest

        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    Timer {
        id: feedTicker

        interval: 300000
        repeat: true
        running: ytx.active && ytx.showingHome
        onTriggered: ytx.refreshFeed(false)
    }

    Rectangle {
        id: card


        width: ytx.cardWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - ytx.bottomMargin)
        height: contentColumn.implicitHeight + ytx.pad * 2
        radius: ytx.cornerRadius
        color: ytx.cardColor
        border.width: 1
        border.color: ytx.cardBorder
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.9
            blurMax: 28
            shadowHorizontalOffset: 5
            shadowVerticalOffset: 10
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowOpacity: 0.95
        }


        transform: Translate {
            y: (1.0 - ytx.animProgress) * 8
        }

        Column {
            id: contentColumn

            x: ytx.pad
            y: ytx.pad
            width: ytx.cardWidth - ytx.pad * 2
            spacing: 12

            Rectangle {
                id: searchBox

                width: parent.width
                height: ytx.searchHeight
                radius: 8
                color: rootRef.withAlpha(ytx.fg, 0.08)
                border.width: 1
                border.color: searchField.activeFocus ? rootRef.withAlpha(ytx.fg, 0.4) : rootRef.withAlpha(ytx.fg, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Image {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 20
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        source: Qt.resolvedUrl("../assets/youtube.svg")
                    }

                    TextField {
                        id: searchField

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: ytx.fg
                        font.family: ytx.uiFont
                        font.pixelSize: ytx.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search YouTube"
                        placeholderTextColor: rootRef.withAlpha(ytx.fg, 0.4)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        onTextEdited: {
                            if (searchField.text.trim().length === 0 && ytx.activeQuery.length > 0)
                                ytx.showRecent();
                            else
                                ytx.filter(searchField.text);
                        }
                        Keys.onDownPressed: (event) => {
                            grid.moveCurrentIndexDown();
                            event.accepted = true;
                        }
                        Keys.onUpPressed: (event) => {
                            grid.moveCurrentIndexUp();
                            event.accepted = true;
                        }
                        Keys.onRightPressed: (event) => {
                            if (grid.currentIndex < listModel.count - 1)
                                grid.currentIndex++;

                            event.accepted = true;
                        }
                        Keys.onLeftPressed: (event) => {
                            if (grid.currentIndex > 0)
                                grid.currentIndex--;

                            event.accepted = true;
                        }
                        Keys.onReturnPressed: (event) => {
                            var q = searchField.text.trim();
                            var asAudio = event.modifiers & Qt.AltModifier;
                            if (q.length > 0 && q !== ytx.activeQuery && !ytx.searching)
                                ytx.runSearch(q);
                            else
                                ytx.activate(asAudio);
                            event.accepted = true;
                        }
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_1 && (event.modifiers & Qt.AltModifier)) {
                                ytx.ensureHome(false);
                                searchField.text = "";
                                searchField.forceActiveFocus();
                                ytx.filter("");
                                event.accepted = true;
                                return ;
                            }
                            if (event.key === Qt.Key_P) {
                                var q = searchField.text.trim();
                                if (q.length > 0 && ytx.activeQuery.length === 0 && !ytx.searching)
                                    ytx.runSearch(q);
                                else if (listModel.count > 0)
                                    ytx.playAll(false);
                                event.accepted = true;
                            }
                        }
                        Keys.onEscapePressed: (event) => {
                            ytx.requestClose();
                            event.accepted = true;
                        }

                        background: Item {
                        }

                    }

                    Rectangle {
                        visible: searchField.text.length > 0
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        color: clearHover.containsMouse ? rootRef.withAlpha(ytx.fg, 0.25) : "transparent"

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/close.svg")
                            color: ytx.fg
                            iconSize: ytx.fontSize + 2
                        }

                        MouseArea {
                            id: clearHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = "";
                                searchField.forceActiveFocus();
                                if (ytx.activeQuery.length > 0)
                                    ytx.showRecent();
                                else
                                    ytx.filter("");
                            }
                        }

                        Behavior on color {
                            CAnim { type: CAnim.FastEffects }

                        }

                    }

                }

                Behavior on border.color {
                    CAnim { type: CAnim.FastEffects }

                }

            }

            Item {
                id: statusRow

                width: parent.width
                height: 22
                visible: true

                BusyIndicator {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    running: ytx.searching || ytx.pendingHome
                    visible: ytx.searching || ytx.pendingHome
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: ytx.searching || ytx.pendingHome ? 22 : 2
                    anchors.right: chipRow.visible ? chipRow.left : parent.right
                    anchors.rightMargin: chipRow.visible ? 12 : 2
                    elide: Text.ElideRight
                    text: ytx.searching ? "Searching\u2026" : ytx.pendingHome ? "Loading\u2026" : ytx.searchFailed ? "No results" : ytx.activeQuery.length > 0 ? ytx.videos.length + " results" : ytx.homeFailed ? "Couldn\u2019t load" : ytx.homeLoaded ? ytx.videos.length + " recommended" : ""
                    font.family: ytx.uiFont
                    font.pixelSize: Math.max(10, ytx.fontSize - 1)
                    color: ytx.searchFailed || ytx.homeFailed ? Qt.rgba(1, 0.45, 0.4, 1) : rootRef.withAlpha(ytx.fg, 0.6)
                }

                Row {
                    id: chipRow

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    visible: true

                    Rectangle {
                        id: homeChip

                        width: homeChipLabel.implicitWidth + 20
                        height: 22
                        radius: 11
                        color: homeHover.containsMouse ? rootRef.withAlpha(ytx.fg, 0.2) : rootRef.withAlpha(ytx.fg, 0.08)

                        Row {
                            id: homeChipLabel

                            anchors.centerIn: parent
                            spacing: 5

                            QIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("../assets/icons/home.svg")
                                color: ytx.fg
                                iconSize: Math.max(10, ytx.fontSize - 1)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Home"
                                color: ytx.fg
                                font.family: ytx.uiFont
                                font.pixelSize: Math.max(10, ytx.fontSize - 2)
                            }
                        }

                        MouseArea {
                            id: homeHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ytx.ensureHome(false);
                                searchField.text = "";
                                searchField.forceActiveFocus();
                                ytx.filter("");
                            }
                        }

                    }

                    Rectangle {
                        id: recentChip

                        width: recentChipLabel.implicitWidth + 20
                        height: 22
                        radius: 11
                        color: recentHover.containsMouse ? rootRef.withAlpha(ytx.fg, 0.2) : rootRef.withAlpha(ytx.fg, 0.08)

                        Row {
                            id: recentChipLabel

                            anchors.centerIn: parent
                            spacing: 5

                            QIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: Qt.resolvedUrl("../assets/icons/history.svg")
                                color: ytx.fg
                                iconSize: Math.max(10, ytx.fontSize - 1)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Recent"
                                color: ytx.fg
                                font.family: ytx.uiFont
                                font.pixelSize: Math.max(10, ytx.fontSize - 2)
                            }
                        }

                        MouseArea {
                            id: recentHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ytx.showRecent();
                                searchField.text = "";
                                searchField.forceActiveFocus();
                            }
                        }

                    }

                    Rectangle {
                        id: refreshChip

                        visible: ytx.showingHome
                        enabled: !homeProc.running
                        width: 22
                        height: 22
                        radius: 11
                        color: refreshHover.containsMouse ? rootRef.withAlpha(ytx.fg, 0.2) : rootRef.withAlpha(ytx.fg, 0.08)

                        QIcon {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../assets/icons/refresh.svg")
                            color: ytx.fg
                            iconSize: Math.max(10, ytx.fontSize)
                        }

                        MouseArea {
                            id: refreshHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ytx.ensureHome(true);
                            }
                        }

                    }

                }

            }

            Item {
                id: gridContainer

                width: parent.width
                height: ytx.gridHeight()

                GridView {
                    id: grid

                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: parent.width + ytx.gridSpacing
                    height: parent.height
                    model: listModel
                    cellWidth: width / ytx.columns
                    cellHeight: ytx.cellHeight + ytx.gridSpacing
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    currentIndex: 0
                    highlightFollowsCurrentItem: true

                    // Springy grid motion while filtering.
                    move: Transition {
                        Anim { property: "x"; type: Anim.BouncyFast }
                        Anim { property: "y"; type: Anim.BouncyFast }
                        Anim { property: "opacity"; to: 1; type: Anim.DefaultEffects }
                    }
                    displaced: Transition {
                        Anim { property: "x"; type: Anim.BouncyFast }
                        Anim { property: "y"; type: Anim.BouncyFast }
                    }
                    add: Transition {
                        Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
                    }

                    delegate: Item {
                        id: cell

                        required property int index
                        required property string title
                        required property string vid
                        required property string channel
                        required property string thumb
                        readonly property bool isSelected: grid.currentIndex === index
                        readonly property string remoteThumb: "https://i.ytimg.com/vi/" + vid + "/mqdefault.jpg"

                        width: ytx.cellWidth
                        height: ytx.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: isSelected ? rootRef.withAlpha(ytx.selBg, 0.28) : "transparent"
                            border.width: isSelected ? 2 : 0
                            border.color: ytx.selBg

                            Behavior on color {
                                CAnim { type: CAnim.FastEffects }

                            }

                        }

                        Column {
                            anchors.fill: parent
                            anchors.topMargin: ytx.cellInset
                            anchors.leftMargin: ytx.cellInset
                            anchors.rightMargin: ytx.cellInset
                            anchors.bottomMargin: ytx.cellInset
                            spacing: 7

                            Rectangle {
                                width: ytx.thumbWidth
                                height: ytx.thumbHeight
                                radius: 8
                                clip: true
                                color: "transparent"
                                border.width: 1
                                border.color: rootRef.withAlpha(ytx.fg, 0.15)

                                Image {
                                    id: thumbImg

                                    anchors.fill: parent
                                    source: ytx.thumbTicks > 0
                                        ? "file://" + thumb + "?t=" + ytx.thumbTicks
                                        : "https://i.ytimg.com/vi/" + vid + "/mqdefault.jpg"
                                    sourceSize: Qt.size(ytx.thumbWidth * 2, ytx.thumbHeight * 2)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    clip: true
                                    // Thumbnails used to snap in abruptly when
                                    // the async load finished — fade + spring
                                    // instead so covers bounce into place.
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                                    scale: status === Image.Ready ? 1 : 0.9
                                    Behavior on scale { Anim { type: Anim.BouncyFast } }
                                    transformOrigin: Item.Center
                                    onStatusChanged: {
                                        if (thumbImg.status === Image.Error && thumbImg.source !== cell.remoteThumb)
                                            thumbImg.source = cell.remoteThumb;

                                    }
                                }

                                Rectangle {
                                    visible: thumbImg.status !== Image.Ready
                                    anchors.fill: parent
                                    radius: 8
                                    color: isSelected ? ytx.selBg : rootRef.withAlpha(ytx.fg, 0.08)
                                }

                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Text {
                                    id: titleText

                                    width: parent.width
                                    height: ytx.titleHeight
                                    text: title
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    font.family: ytx.uiFont
                                    font.pixelSize: ytx.fontSize - 1
                                    // NOTE: the title sits on the card (or a
                                    // translucent wash of it), never on solid
                                    // selBg, so it uses card-based fg.
                                    font.weight: isSelected ? Font.DemiBold : Font.Medium
                                    color: ytx.fg
                                    lineHeight: 1.2
                                }

                                Text {
                                    width: parent.width
                                    height: ytx.channelHeight
                                    visible: channel.length > 0
                                    text: channel
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: ytx.uiFont
                                    font.pixelSize: Math.max(9, ytx.fontSize - 3)
                                    color: isSelected ? rootRef.withAlpha(ytx.fg, 0.85) : rootRef.withAlpha(ytx.fg, 0.75)
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                grid.currentIndex = index;
                                ytx.activate(false);
                            }
                        }

                    }

                }

            }

        }

    }

    Behavior on animProgress {
        Anim { type: Anim.Bouncy }
    }

}
