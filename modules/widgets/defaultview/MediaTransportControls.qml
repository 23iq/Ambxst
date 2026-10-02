import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme

RowLayout {
    id: root

    required property var player
    spacing: 8

    component TransportButton: Button {
        id: control

        required property string glyph
        required property string label

        implicitWidth: 36
        implicitHeight: 36
        padding: 0
        opacity: enabled ? 1 : 0.3
        Accessible.name: label
        ToolTip.visible: hovered
        ToolTip.delay: 1000
        ToolTip.text: label

        background: Item {}

        contentItem: Text {
            color: control.hovered || control.down ? Styling.srItem("overprimary") : Colors.overBackground
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(4)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: control.glyph
        }
    }

    TransportButton {
        glyph: Icons.previous
        label: I18n.t("island.previous")
        enabled: root.player?.canGoPrevious ?? false
        onClicked: root.player?.previous()
    }

    TransportButton {
        glyph: root.player?.isPlaying ? Icons.pause : Icons.play
        label: I18n.t("island.play_pause")
        enabled: root.player?.canTogglePlaying ?? false
        onClicked: root.player?.togglePlaying()
    }

    TransportButton {
        glyph: Icons.next
        label: I18n.t("island.next")
        enabled: root.player?.canGoNext ?? false
        onClicked: root.player?.next()
    }
}
