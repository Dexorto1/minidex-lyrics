import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: root

    // Active Player & Track State
    property string activeSource: "@multiplex"
    property string currentTrackTitle: ""
    property string currentArtist: ""
    property string currentAlbum: ""
    property string currentArtUrl: ""
    property string playbackStatus: "Stopped"
    property real trackLengthSec: 0
    property real trackPositionSec: 0

    // Lyrics toggle
    property bool showLyrics: true

    // Playback and active state detection
    readonly property bool isPlaying: root.playbackStatus.toLowerCase() === "playing"
    readonly property bool isPaused: root.playbackStatus.toLowerCase() === "paused"
    readonly property bool hasMusic: (root.currentTrackTitle !== "") && (root.isPlaying || root.isPaused)

    // Hide plasmoid from panel/desktop when no music is playing
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: root.hasMusic ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    Plasmoid.icon: "multimedia-audio-player"
    Plasmoid.title: root.hasMusic ? (root.currentTrackTitle + " - " + root.currentArtist) : i18n("minidex-lyrics")

    visible: true
    opacity: root.hasMusic ? 1.0 : 0.0
    implicitWidth: root.hasMusic ? 400 : 0
    implicitHeight: root.hasMusic ? (root.showLyrics ? 540 : 185) : 0

    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    // Lyrics State
    property var lyricsLines: []
    property int activeLyricIndex: -1
    property string lyricsStatus: "idle"
    property string lastFetchedKey: ""
    property real lyricsAnchorPos: 0
    property real lyricsAnchorTime: 0

    // Plasma MPRIS DataEngine
    PlasmaCore.DataSource {
        id: mprisSource
        engine: "mpris2"
        connectedSources: ["@multiplex"]
        interval: 500

        onSourceAdded: function(source) {
            connectSource(source);
            updatePlayerData();
        }

        onSourceRemoved: function(source) {
            disconnectSource(source);
            updatePlayerData();
        }

        onDataChanged: {
            updatePlayerData();
        }
    }

    Component.onCompleted: {
        for (var i = 0; i < mprisSource.sources.length; i++) {
            mprisSource.connectSource(mprisSource.sources[i]);
        }
        updatePlayerData();
    }

    function parseArtist(raw) {
        if (!raw) return "";
        if (Array.isArray(raw)) return raw.join(", ");
        if (typeof raw === "object" && raw.length !== undefined) {
            var list = [];
            for (var i = 0; i < raw.length; i++) list.push(raw[i]);
            return list.join(", ");
        }
        return raw.toString();
    }

    function updatePlayerData() {
        var sources = mprisSource.sources;
        if (!sources || sources.length === 0) {
            clearTrack();
            return;
        }

        var bestSource = "";
        for (var i = 0; i < sources.length; i++) {
            var src = sources[i];
            var d = mprisSource.data[src];
            if (d && (d["PlaybackStatus"] || "").toString().toLowerCase() === "playing") {
                bestSource = src;
                break;
            }
        }

        if (!bestSource) {
            for (var j = 0; j < sources.length; j++) {
                var s = sources[j];
                var dataItem = mprisSource.data[s];
                if (dataItem) {
                    var meta = dataItem["Metadata"] || {};
                    var t = dataItem["Track"] || meta["xesam:title"] || meta["title"] || "";
                    if (t) {
                        bestSource = s;
                        break;
                    }
                }
            }
        }

        if (!bestSource) {
            if (mprisSource.data["@multiplex"]) {
                bestSource = "@multiplex";
            } else if (sources.length > 0) {
                bestSource = sources[0];
            }
        }

        root.activeSource = bestSource;
        var data = mprisSource.data[root.activeSource];
        if (!data) {
            clearTrack();
            return;
        }

        var meta = data["Metadata"] || {};
        var title = data["Track"] || meta["xesam:title"] || meta["title"] || "";
        var artist = parseArtist(data["Artist"] || meta["xesam:artist"] || meta["artist"] || "");
        var album = data["Album"] || meta["xesam:album"] || meta["album"] || "";
        var artUrl = data["ArtUrl"] || meta["mpris:artUrl"] || meta["artUrl"] || "";
        var status = (data["PlaybackStatus"] || "Stopped").toString();

        root.playbackStatus = status;
        root.currentTrackTitle = title.toString();
        root.currentArtist = artist;
        root.currentAlbum = album.toString();
        root.currentArtUrl = artUrl.toString();

        var lenUs = data["Length"] || meta["mpris:length"] || meta["length"] || 0;
        root.trackLengthSec = Math.max(0, Number(lenUs) / 1000000.0);

        var posUs = data["Position"] || 0;
        var reportedPos = Math.max(0, Number(posUs) / 1000000.0);
        if (Math.abs(reportedPos - root.trackPositionSec) > 1.5) {
            root.trackPositionSec = reportedPos;
            root.lyricsAnchorPos = reportedPos;
            root.lyricsAnchorTime = Date.now();
        }

        if (root.hasMusic) {
            checkAndFetchLyrics();
        } else {
            root.lyricsLines = [];
            root.lyricsStatus = "idle";
        }
    }

    function clearTrack() {
        root.currentTrackTitle = "";
        root.currentArtist = "";
        root.currentAlbum = "";
        root.currentArtUrl = "";
        root.playbackStatus = "Stopped";
        root.trackLengthSec = 0;
        root.trackPositionSec = 0;
        root.lyricsLines = [];
        root.lyricsStatus = "idle";
        root.lastFetchedKey = "";
    }

    function sendMprisCommand(cmd, args) {
        if (!root.activeSource) return;
        var service = mprisSource.serviceForSource(root.activeSource);
        if (!service) return;
        var op = service.operationDescription(cmd);
        if (args) {
            for (var key in args) op[key] = args[key];
        }
        service.startOperationCall(op);
    }

    function togglePlayPause() { sendMprisCommand("PlayPause"); }
    function nextTrack() { sendMprisCommand("Next"); }
    function previousTrack() { sendMprisCommand("Previous"); }

    function seekTo(seconds) {
        if (root.trackLengthSec <= 0) return;
        var posUs = Math.floor(seconds * 1000000.0);
        sendMprisCommand("SetPosition", { "Position": posUs });
        root.trackPositionSec = seconds;
        root.lyricsAnchorPos = seconds;
        root.lyricsAnchorTime = Date.now();
    }

    // Direct Native High-Speed QML Lyrics Fetcher
    function cleanTitle(t) {
        if (!t) return "";
        var cleaned = t;
        var patterns = [
            /\(feat\..*?\)/gi, /\[feat\..*?\]/gi, /\(ft\..*?\)/gi, /\[ft\..*?\]/gi,
            /\(official\s+.*?\)/gi, /\[official\s+.*?\]/gi,
            /\(music\s+video.*?\)/gi, /\[music\s+video.*?\]/gi,
            /\(audio\)/gi, /\[audio\]/gi,
            /\(visualizer\)/gi, /\[visualizer\]/gi,
            /\(lyrics?\)/gi, /\[lyrics?\]/gi,
            /\(lyrics?\s+video\)/gi, /\[lyrics?\s+video\]/gi,
            /\(remaster(?:ed)?(?:\s+\d{4})?\)/gi, /\[remaster(?:ed)?(?:\s+\d{4})?\]/gi,
            /-\s*remaster(?:ed)?(?:\s+\d{4})?/gi, /-\s*live/gi, /\(live.*?\)/gi
        ];
        for (var i = 0; i < patterns.length; i++) {
            cleaned = cleaned.replace(patterns[i], "");
        }
        cleaned = cleaned.replace(/\s+/g, " ").trim().replace(/^[-_\s]+|[-_\s]+$/g, "");
        return (cleaned.length > 1) ? cleaned : t;
    }

    function parseLrc(lrcText) {
        if (!lrcText) return [];
        var lines = lrcText.split("\n");
        var result = [];
        var stampRegex = /\[(\d{1,3}):(\d{2}(?:\.\d{1,3})?)\]/g;
        for (var i = 0; i < lines.length; i++) {
            var raw = lines[i].trim();
            if (!raw) continue;
            var matches = [];
            var match;
            while ((match = stampRegex.exec(raw)) !== null) {
                var min = parseInt(match[1], 10);
                var sec = parseFloat(match[2].replace(":", "."));
                matches.push(min * 60 + sec);
            }
            if (matches.length === 0) continue;
            var text = raw.replace(/\[\d{1,3}:\d{2}(?:\.\d{1,3})?\]/g, "").trim();
            for (var m = 0; m < matches.length; m++) {
                result.push({ "time": matches[m], "text": text || "♪" });
            }
        }
        result.sort(function(a, b) { return a.time - b.time; });
        return result;
    }

    function checkAndFetchLyrics() {
        if (!root.currentTrackTitle || !root.currentArtist) {
            root.lyricsLines = [];
            root.lyricsStatus = "no_info";
            root.lastFetchedKey = "";
            return;
        }

        var key = root.currentTrackTitle + ":::" + root.currentArtist;
        if (key === root.lastFetchedKey) return;

        root.lastFetchedKey = key;
        root.lyricsStatus = "loading";
        root.lyricsLines = [];
        root.activeLyricIndex = 0;

        var cleaned = cleanTitle(root.currentTrackTitle);

        var url1 = "https://lrclib.net/api/get?track_name=" + encodeURIComponent(cleaned) + "&artist_name=" + encodeURIComponent(root.currentArtist);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url1, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data && data.syncedLyrics) {
                            var parsed = parseLrc(data.syncedLyrics);
                            if (parsed.length > 0) {
                                root.lyricsLines = parsed;
                                root.lyricsStatus = "ok";
                                root.activeLyricIndex = 0;
                                return;
                            }
                        }
                    } catch (e) {}
                }
                fetchSearchFallback(cleaned, root.currentArtist);
            }
        };
        xhr.send();
    }

    function fetchSearchFallback(cleanedTitle, artist) {
        var query = encodeURIComponent(cleanedTitle + " " + artist);
        var url2 = "https://lrclib.net/api/search?q=" + query;
        var xhr2 = new XMLHttpRequest();
        xhr2.open("GET", url2, true);
        xhr2.onreadystatechange = function() {
            if (xhr2.readyState === XMLHttpRequest.DONE) {
                if (xhr2.status === 200) {
                    try {
                        var list = JSON.parse(xhr2.responseText);
                        if (Array.isArray(list)) {
                            for (var i = 0; i < list.length; i++) {
                                if (list[i] && list[i].syncedLyrics) {
                                    var parsed = parseLrc(list[i].syncedLyrics);
                                    if (parsed.length > 0) {
                                        root.lyricsLines = parsed;
                                        root.lyricsStatus = "ok";
                                        root.activeLyricIndex = 0;
                                        return;
                                    }
                                }
                            }
                        }
                    } catch (e) {}
                }
                root.lyricsLines = [];
                root.lyricsStatus = "not_found";
            }
        };
        xhr2.send();
    }

    // Position Tracker & Lyric Synchronizer
    Timer {
        interval: 200
        running: root.isPlaying && root.hasMusic
        repeat: true
        onTriggered: {
            var now = Date.now();
            var est = root.lyricsAnchorPos + (now - root.lyricsAnchorTime) / 1000.0;
            if (root.trackLengthSec > 0 && est > root.trackLengthSec) est = root.trackLengthSec;
            root.trackPositionSec = est;

            if (root.lyricsLines.length > 0) {
                var idx = 0;
                for (var i = 0; i < root.lyricsLines.length; i++) {
                    if (root.lyricsLines[i].time <= est) {
                        idx = i;
                    } else {
                        break;
                    }
                }
                if (idx !== root.activeLyricIndex) {
                    root.activeLyricIndex = idx;
                }
            }
        }
    }

    // Full Representation: Deep Dark Theme with Rich Ambient Album Tint
    Plasmoid.fullRepresentation: Item {
        id: fullRep
        visible: root.hasMusic
        opacity: root.hasMusic ? 1.0 : 0.0

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: root.hasMusic ? 300 : 0
        Layout.minimumHeight: root.hasMusic ? (root.showLyrics ? 320 : 160) : 0
        Layout.preferredWidth: 400
        Layout.preferredHeight: root.showLyrics ? 540 : 185

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
        }

        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: mainCard
            anchors.fill: parent
            visible: root.hasMusic
            color: "#0B0D12" // Deep solid dark base
            radius: 18
            clip: true
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)

            // Ambient Album Cover Shade (~30% rich color wash)
            Image {
                id: ambientArt
                anchors.fill: parent
                source: root.currentArtUrl
                fillMode: Image.PreserveAspectCrop
                opacity: 0.32
                visible: root.currentArtUrl !== ""
                smooth: true
                asynchronous: true

                Behavior on opacity {
                    NumberAnimation { duration: 300 }
                }
            }

            // Dark Vignette Gradient for high contrast text readability
            Rectangle {
                anchors.fill: parent
                radius: 18
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0.04, 0.05, 0.07, 0.45) }
                    GradientStop { position: 0.4; color: Qt.rgba(0.04, 0.05, 0.07, 0.68) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.05, 0.07, 0.85) }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                visible: root.hasMusic

                // Header: Album Art & Track Details (Dark Mode)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 68
                        radius: 12
                        color: Qt.rgba(0, 0, 0, 0.4)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.currentArtUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: root.currentArtUrl !== ""
                        }

                        PlasmaCore.IconItem {
                            anchors.centerIn: parent
                            width: 34
                            height: 34
                            source: "multimedia-audio-player"
                            visible: root.currentArtUrl === ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.currentTrackTitle || i18n("No media playing")
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentArtist || i18n("Ready")
                            font.pixelSize: 13
                            color: Qt.rgba(1, 1, 1, 0.75)
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentAlbum
                            font.pixelSize: 11
                            color: Qt.rgba(1, 1, 1, 0.45)
                            elide: Text.ElideRight
                            visible: root.currentAlbum !== ""
                        }
                    }
                }

                // Progress Bar & Timestamp Row (Dark Mode)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: root.trackLengthSec > 0

                    Slider {
                        id: progressSlider
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(1, root.trackLengthSec)
                        value: root.trackPositionSec
                        onMoved: {
                            root.seekTo(value);
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            function formatTime(s) {
                                var m = Math.floor(s / 60);
                                var sec = Math.floor(s % 60);
                                return m + ":" + (sec < 10 ? "0" : "") + sec;
                            }
                            text: formatTime(root.trackPositionSec)
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.65)
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            function formatTime(s) {
                                var m = Math.floor(s / 60);
                                var sec = Math.floor(s % 60);
                                return m + ":" + (sec < 10 ? "0" : "") + sec;
                            }
                            text: formatTime(root.trackLengthSec)
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.65)
                        }
                    }
                }

                // Controls Row: Centered Playback Controls + White Lyrics Pill Button
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 42

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 16

                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-backward"
                            implicitWidth: 36
                            implicitHeight: 36
                            onClicked: root.previousTrack()
                        }

                        PlasmaComponents.Button {
                            id: playButton
                            icon.name: root.isPlaying ? "media-playback-pause" : "media-playback-start"
                            highlighted: true
                            implicitWidth: 44
                            implicitHeight: 44
                            onClicked: root.togglePlayPause()
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-forward"
                            implicitWidth: 36
                            implicitHeight: 36
                            onClicked: root.nextTrack()
                        }
                    }

                    Rectangle {
                        id: whiteLyricsButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 10
                        color: root.showLyrics ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        border.color: root.showLyrics ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.35)

                        Behavior on color {
                            ColorAnimation { duration: 180 }
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 120 }
                        }

                        scale: lyricsMouseArea.pressed ? 0.92 : (lyricsMouseArea.containsMouse ? 1.06 : 1.0)

                        PlasmaCore.IconItem {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: "media-view-subtitles"
                        }

                        MouseArea {
                            id: lyricsMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.showLyrics = !root.showLyrics;
                            }
                        }

                        PlasmaComponents.ToolTip.text: root.showLyrics ? i18n("Hide Lyrics") : i18n("Show Lyrics")
                        PlasmaComponents.ToolTip.visible: lyricsMouseArea.containsMouse
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.14)
                    visible: root.showLyrics
                }

                // Synced Lyrics Card Viewport (ListView with Smooth Centered Scrolling)
                Item {
                    id: lyricsViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.showLyrics
                    clip: true

                    // Status Placeholder
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: root.lyricsLines.length === 0

                        PlasmaComponents.BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            running: root.lyricsStatus === "loading"
                            visible: root.lyricsStatus === "loading"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                if (root.lyricsStatus === "loading") return i18n("Fetching lyrics from LRCLIB...");
                                if (root.lyricsStatus === "not_found") return i18n("No synchronized lyrics found");
                                if (root.lyricsStatus === "no_info") return i18n("Play a song to view lyrics");
                                return i18n("Lyrics will appear here");
                            }
                            color: Qt.rgba(1, 1, 1, 0.70)
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }

                    // High-performance Scrolling ListView (Dark Mode)
                    ListView {
                        id: lyricsListView
                        anchors.fill: parent
                        visible: root.lyricsLines.length > 0
                        model: root.lyricsLines
                        currentIndex: root.activeLyricIndex
                        spacing: 14

                        preferredHighlightBegin: height / 2 - 25
                        preferredHighlightEnd: height / 2 + 25
                        highlightRangeMode: ListView.ApplyRange
                        highlightFollowsCurrentItem: true

                        Behavior on contentY {
                            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: lineWrapper
                            width: lyricsListView.width
                            height: lineText.implicitHeight + 8

                            readonly property bool isActive: index === root.activeLyricIndex

                            Text {
                                id: lineText
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 24, 600)
                                text: modelData.text || "♪"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap

                                font.pixelSize: isActive ? 19 : 14
                                font.weight: isActive ? Font.Bold : Font.Normal
                                color: isActive ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.50)
                                scale: isActive ? 1.12 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.seekTo(modelData.time);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Compact Representation (Panel Icon / Status)
    Plasmoid.compactRepresentation: Item {
        visible: root.hasMusic
        opacity: root.hasMusic ? 1.0 : 0.0
        Layout.minimumWidth: root.hasMusic ? 28 : 0
        Layout.minimumHeight: root.hasMusic ? 28 : 0
        Layout.preferredWidth: root.hasMusic ? 28 : 0
        Layout.preferredHeight: root.hasMusic ? 28 : 0
        implicitWidth: root.hasMusic ? 28 : 0
        implicitHeight: root.hasMusic ? 28 : 0

        PlasmaCore.IconItem {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            source: root.isPlaying ? "media-playback-start" : "multimedia-audio-player"
            visible: root.hasMusic
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                plasmoid.expanded = !plasmoid.expanded;
            }
        }
    }
}
