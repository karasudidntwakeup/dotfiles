import QtQuick
import QtQuick.Controls
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
    readonly property int cornerRadius: 20
    readonly property int pad: 16
    readonly property int cardWidth: 820
    readonly property int searchHeight: 40
    readonly property int maxItems: 48
    readonly property int visibleRows: 3
    readonly property int columns: 4
    readonly property int gridSpacing: 12
    readonly property int cellWidth: Math.floor((cardWidth - pad * 2 - gridSpacing * (columns - 1)) / columns)
    readonly property int cellInset: 5
    readonly property int thumbWidth: cellWidth - cellInset * 2
    readonly property int thumbHeight: Math.round(thumbWidth * 9 / 16)
    readonly property int titleHeight: Math.round((fontSize - 1) * 1.2) * 2
    readonly property int channelHeight: Math.max(10, fontSize - 3)
    readonly property int cellHeight: cellInset * 2 + thumbHeight + 7 + titleHeight + 3 + channelHeight
    readonly property string cardTile: "panel_bg"
    readonly property color cardColor: rootRef ? (rootRef.qsLight ? (rootRef.pillColor(cardTile)) : rootRef.colorOf(cardTile)) : "#f3dfd1"
    readonly property color cardBorder: rootRef ? rootRef.withAlpha(rootRef.colorOf("widget_border"), rootRef.qsLight ? 0.7 : 0.5) : "#00000000"
    readonly property color fg: rootRef ? (rootRef.qsLight ? rootRef.qsPillFg : rootRef.textColor) : "#000000"
    readonly property color accent: rootRef
        ? Qt.color(rootRef.colorOf("widget_error"))
        : "#bf616a"
    readonly property color accentText: ytx.contrastColor(ytx.accent)
    readonly property color selectedFg: rootRef
        ? Qt.color(rootRef.colorOf("widget_error"))
        : "#bf616a"

    function _lin(v: double): double {
        if (v <= 0.03928) return v / 12.92
        return Math.pow((v + 0.055) / 1.055, 2.4)
    }

    function relLum(c: color): double {
        return 0.2126 * ytx._lin(c.r) + 0.7152 * ytx._lin(c.g) + 0.0722 * ytx._lin(c.b)
    }

    function contrastColor(c: color): color {
        var l = ytx.relLum(c)
        var white = (1.05) / (l + 0.05)
        var black = (l + 0.05) / (0.05)
        return white >= black ? "#ffffff" : "#000000"
    }
    readonly property string iconFont: rootRef && rootRef.iconFont ? rootRef.iconFont : "Symbols Nerd Font"
    readonly property string fontFamily: rootRef && rootRef.fontFamily ? rootRef.fontFamily : "Ndot 57"
    readonly property string uiFont: rootRef && rootRef.uiFont ? rootRef.uiFont : "Inter"
    readonly property int fontSize: rootRef && rootRef.fontSize ? Math.round(rootRef.fontSize) : 13
    property real animProgress: ytx.active ? 1 : 0
    readonly property int bottomMargin: 24

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string thumbCache: homeDir + "/.cache/rofi-youtube"
    property real thumbTicks: 0
    property var videos: []
    property bool homeLoaded: false
    property bool homeFailed: false
    property bool pendingHome: false
    property string feedMode: "home"
    property var prefetched: ({
    })

    Process {
        id: thumbProc
        onExited: () => {
            ytx.thumbTicks++
        }
    }

    signal requestClose()

    function alpha(c: color, a: double) : color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function loadRecent() {
        if (recentFile)
            recentFile.reload();
    }

    function onRecentData(obj) {
        if (!obj || !obj.entries || !ytx.active)
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
        if (ytx.pendingHome || ytx.homeLoaded)
            return ;

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
        thumbProc.start();
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
        grid.currentIndex = 0;
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
        ytx.activeQuery = "";
        ytx.searching = false;
        ytx.searchFailed = false;
        ytx.homeLoaded = false;
        ytx.homeFailed = false;
        ytx.pendingHome = false;
        ytx.loadRecent();
        ytx.filter(searchField.text);
    }

    function ensureHome(force, mode) {
        ytx.feedMode = mode || "home";
        ytx.activeQuery = "";
        ytx.searching = false;
        ytx.searchFailed = false;
        if (!force) {
            homeFile.reload();
            return ;
        }

        ytx.pendingHome = true;
            Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/ytx-home.sh", ytx.feedMode, "force"]);
            pendingTimeout.restart();
    }

    function onHomeResults(obj) {
        if (ytx.searching || ytx.activeQuery.length > 0 || !ytx.active)
            return ;

        ytx.pendingHome = false;
        if (!obj || !obj.results || obj.results.length === 0) {
            ytx.homeFailed = true;
            return ;
        }
        var arr = [];
        for (var i = 0; i < obj.results.length && arr.length < ytx.maxItems; i++) {
            var r = obj.results[i];
            if (!r || !r.id || !r.url)
                continue;

            var tid = r.id.replace(/^RD/, "");
            var isMix = tid !== r.id;

            arr.push({
                "title": r.title || "",
                "vid": tid,
                "url": isMix ? ("https://www.youtube.com/watch?v=" + tid + "&list=" + r.id) : r.url,
                "channel": r.channel || "",
                "thumb": ytx.thumbCache + "/" + tid + ".jpg"
            });
        }
        if (arr.length === 0) {
            ytx.homeFailed = true;
            return ;
        }
        ytx.videos = arr;
        ytx.homeLoaded = true;
        ytx.homeFailed = false;
        ytx.filter(searchField.text);
        ytx.prefetchThumbs(arr);
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
            ytx.activeQuery = "";
            ytx.searching = false;
            ytx.searchFailed = false;
            searchField.text = "";
            ytx.loadRecent();
            ytx.ensureHome();
            ytx.filter("");
            focusRequest.restart();
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

        path: ytx.feedMode === "music" ? (ytx.homeDir + "/.cache/quickshell/ytx-music.json") : (ytx.homeDir + "/.cache/quickshell/ytx-home.json")
        watchChanges: true
        blockLoading: false
        onFileChanged: homeFile.reload()
        onLoaded: {
            if (!ytx.searching && ytx.activeQuery.length === 0) {
                try {
                    var obj = JSON.parse(String(homeFile.text()));
                    ytx.onHomeResults(obj);
                } catch (err) {
                    console.log("[ytx] home parse error:", err);
                    ytx.pendingHome = false;
                    ytx.homeFailed = true;
                }
            }
        }
        onLoadFailed: (error) => {
            console.log("[ytx] home results load failed:", error);
            ytx.pendingHome = false;
            ytx.homeFailed = true;
        }
    }

    FileView {
        id: recentFile

        path: ytx.homeDir + "/.config/yt-x/recent.json"
        watchChanges: false
        blockLoading: true
        onLoaded: {
            if (ytx.searching || ytx.activeQuery.length > 0)
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
        id: pendingTimeout

        interval: 20000
        repeat: false
        onTriggered: ytx.pendingHome = false
    }

    Rectangle {
        id: card

        width: ytx.cardWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.floor(parent.height - card.height - ytx.bottomMargin)
        height: contentColumn.implicitHeight + ytx.pad * 2
        radius: ytx.cornerRadius
        color: ytx.cardColor
        border.width: 2
        border.color: ytx.cardBorder
        clip: true

        SurfaceGradient {
            anchors.fill: parent
            inset: 1
            color: ytx.cardColor
            radius: ytx.cornerRadius
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
                radius: ytx.searchHeight / 2
                color: ytx.alpha(ytx.fg, 0.08)
                border.width: 1
                border.color: searchField.activeFocus ? ytx.alpha(ytx.fg, 0.4) : ytx.alpha(ytx.fg, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: "󰗃"
                        color: ytx.alpha(ytx.fg, 0.55)
                        font.family: ytx.iconFont
                        font.pixelSize: ytx.fontSize + 1
                    }

                    TextField {
                        id: searchField

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: ytx.fg
                        font.family: ytx.uiFont
                        font.pixelSize: ytx.fontSize + 1
                        font.weight: Font.Medium
                        placeholderText: "Search — Enter searches YouTube"
                        placeholderTextColor: ytx.alpha(ytx.fg, 0.4)
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        onTextEdited: {
                            if (searchField.text.trim().length === 0 && ytx.activeQuery.length > 0)
                                ytx.showRecent();
                            else
                                ytx.filter(searchField.text);
                        }
                        Keys.onDownPressed: (event) => {
                            grid.incrementCurrentIndex();
                            event.accepted = true;
                        }
                        Keys.onUpPressed: (event) => {
                            grid.decrementCurrentIndex();
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
                            var alt = event.modifiers & Qt.AltModifier;
                            var asAudio = (ytx.feedMode === "music") ? !alt : alt;
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
                            if (event.key === Qt.Key_2 && (event.modifiers & Qt.AltModifier)) {
                                ytx.ensureHome(false, "music");
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
                        color: clearHover.containsMouse ? ytx.alpha(ytx.fg, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: ytx.fg
                            font.family: ytx.iconFont
                            font.pixelSize: ytx.fontSize
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
                            ColorAnimation {
                                duration: 120
                            }

                        }

                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }

                }

            }

            Item {
                id: statusRow

                width: parent.width
                height: 22
                visible: ytx.searching || ytx.activeQuery.length > 0 || ytx.homeLoaded || ytx.homeFailed || ytx.pendingHome

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
                    width: parent.width - (chipRow.visible ? chipRow.width + 8 : 4)
                    elide: Text.ElideRight
                    text: ytx.searching ? "Searching for \u201C" + ytx.activeQuery + "\u201D\u2026" : ytx.pendingHome ? "Loading " + (ytx.feedMode === "music" ? "music mixes\u2026" : "recommendations\u2026") : ytx.searchFailed ? "No results for \u201C" + ytx.activeQuery + "\u201D" : ytx.activeQuery.length > 0 ? ytx.videos.length + " results for \u201C" + ytx.activeQuery + "\u201D" : ytx.homeFailed ? "Couldn\u2019t load " + (ytx.feedMode === "music" ? "music mixes" : "home recommendations") : ytx.homeLoaded ? ytx.videos.length + (ytx.feedMode === "music" ? " music mixes" : " recommended videos") : ""
                    font.family: ytx.uiFont
                    font.pixelSize: Math.max(10, ytx.fontSize - 1)
                    color: ytx.searchFailed || ytx.homeFailed ? Qt.rgba(1, 0.45, 0.4, 1) : ytx.alpha(ytx.fg, 0.6)
                }

                Row {
                    id: chipRow

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    visible: !ytx.searching && (ytx.activeQuery.length > 0 || ytx.homeLoaded || ytx.homeFailed || ytx.pendingHome)

                    Rectangle {
                        id: refreshChip

                        visible: ytx.activeQuery.length === 0 && (ytx.homeLoaded || ytx.homeFailed || ytx.pendingHome)
                        width: 24
                        height: 22
                        radius: 11
                        color: refreshHover.containsMouse ? ytx.alpha(ytx.fg, 0.2) : ytx.alpha(ytx.fg, 0.08)

                        Text {
                            id: refreshChipLabel

                            anchors.centerIn: parent
                            text: "󰑐"
                            color: refreshHover.containsMouse ? ytx.accent : ytx.fg
                            font.family: ytx.iconFont
                            font.pixelSize: Math.max(10, ytx.fontSize - 2)
                        }

                        MouseArea {
                            id: refreshHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ytx.ensureHome(true, ytx.feedMode);
                                searchField.forceActiveFocus();
                            }
                        }

                    }

                    Rectangle {
                        id: homeChip

                        visible: ytx.activeQuery.length === 0 && (ytx.homeLoaded || ytx.homeFailed || ytx.pendingHome)
                        width: homeChipLabel.implicitWidth + 20
                        height: 22
                        radius: 11
                        color: homeHover.containsMouse ? ytx.alpha(ytx.fg, 0.2) : ytx.alpha(ytx.fg, 0.08)

                        Text {
                            id: homeChipLabel

                            anchors.centerIn: parent
                            text: "󰅨 Home"
                            color: ytx.fg
                            font.family: ytx.iconFont
                            font.pixelSize: Math.max(10, ytx.fontSize - 2)
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
                        id: musicChip

                        visible: ytx.activeQuery.length === 0 && (ytx.homeLoaded || ytx.homeFailed || ytx.pendingHome)
                        width: musicChipLabel.implicitWidth + 20
                        height: 22
                        radius: 11
                        color: musicHover.containsMouse ? ytx.alpha(ytx.fg, 0.2) : ytx.alpha(ytx.fg, 0.08)

                        Text {
                            id: musicChipLabel

                            anchors.centerIn: parent
                            text: "󰝚 Music"
                            color: ytx.fg
                            font.family: ytx.iconFont
                            font.pixelSize: Math.max(10, ytx.fontSize - 2)
                        }

                        MouseArea {
                            id: musicHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ytx.ensureHome(false, "music");
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
                        color: recentHover.containsMouse ? ytx.alpha(ytx.fg, 0.2) : ytx.alpha(ytx.fg, 0.08)

                        Text {
                            id: recentChipLabel

                            anchors.centerIn: parent
                            text: "󰛉 Recent"
                            color: ytx.fg
                            font.family: ytx.iconFont
                            font.pixelSize: Math.max(10, ytx.fontSize - 2)
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

                }

            }

            Item {
                id: gridContainer

                width: parent.width
                height: ytx.gridHeight()

                GridView {
                    id: grid

                    anchors.fill: parent
                    model: listModel
                    cellWidth: ytx.cellWidth + ytx.gridSpacing
                    cellHeight: ytx.cellHeight + ytx.gridSpacing
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    currentIndex: 0
                    highlightFollowsCurrentItem: true

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
                            color: "transparent"
                            border.width: isSelected ? 2 : 0
                            border.color: ytx.accent

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

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
                                border.color: ytx.alpha(ytx.fg, 0.15)

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
                                    onStatusChanged: {
                                        if (thumbImg.status === Image.Error && thumbImg.source !== cell.remoteThumb)
                                            thumbImg.source = cell.remoteThumb;

                                    }
                                }

                                Rectangle {
                                    visible: thumbImg.status !== Image.Ready
                                    anchors.fill: parent
                                    radius: 8
                                    color: isSelected ? ytx.alpha(ytx.accent, 0.25) : ytx.alpha(ytx.fg, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶"
                                        color: ytx.alpha(ytx.fg, 0.7)
                                        font.family: ytx.fontFamily
                                        font.pixelSize: ytx.fontSize + 8
                                    }

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
                                    font.weight: isSelected ? Font.Black : Font.Medium
                                    color: isSelected ? ytx.selectedFg : ytx.fg
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
                                    color: isSelected ? ytx.alpha(ytx.selectedFg, 0.75) : ytx.alpha(ytx.fg, 0.55)
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                grid.currentIndex = index;
                                ytx.activate(ytx.feedMode === "music");
                            }
                        }

                    }

                }

            }

            Item {
                id: hintRow

                width: parent.width
                height: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (ytx.feedMode === "music" ? "Enter: audio  ·  Alt+Enter: video" : "Enter: video  ·  Alt+Enter: audio")
                                  + "  ·  P: playlist  ·  Alt+1: home  ·  Alt+2: music  ·  Esc: close"
                    font.family: ytx.uiFont
                    font.pixelSize: Math.max(10, ytx.fontSize - 2)
                    color: ytx.alpha(ytx.fg, 0.4)
                }

            }

        }

    }

    Behavior on animProgress {
        NumberAnimation {
            duration: ytx.active ? 320 : 220
            easing.type: Easing.OutCubic
        }

    }

}
