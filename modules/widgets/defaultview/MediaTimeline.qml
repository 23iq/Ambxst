import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme
import "IslandMedia.js" as Media

ColumnLayout {
    id: root

    required property var player
    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0
    readonly property bool hasDuration: Number.isFinite(length) && length > 0
    readonly property bool seekable: Media.canSeek(player)
    readonly property bool playing: player?.isPlaying ?? false
    spacing: 2

    StyledSlider {
        id: slider

        Layout.fillWidth: true
        Layout.preferredHeight: 20
        resizeParent: false
        enabled: root.seekable
        opacity: root.seekable ? 1 : 0.35
        progressColor: Styling.srItem("overprimary")
        backgroundColor: Colors.shadow
        wavy: true
        playing: root.playing
        wavyAmplitude: root.playing ? 1 : 0
        wavyFrequency: root.playing ? 8 : 0
        heightMultiplier: 8
        smoothDrag: true
        scroll: false
        tooltip: false
        updateOnRelease: true

        onValueChanged: {
            if (isDragging && root.seekable)
                root.player.position = value * root.length;
        }
    }

    // Keep playback updates reactive after a drag without seeking on timer ticks.
    Binding {
        target: slider
        property: "value"
        value: root.hasDuration && Number.isFinite(root.position) ? Math.max(0, Math.min(1, root.position / root.length)) : 0
        when: !slider.isDragging
        restoreMode: Binding.RestoreNone
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            color: Colors.overBackground
            font.family: Styling.defaultFont
            font.pixelSize: Styling.fontSize(-2)
            opacity: 0.65
            text: Media.formatTime(root.position)
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            color: Colors.overBackground
            font.family: Styling.defaultFont
            font.pixelSize: Styling.fontSize(-2)
            opacity: 0.65
            text: root.hasDuration ? Media.formatTime(root.length) : "—"
        }
    }
}
