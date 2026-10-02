import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: root
    required property var player
    property bool hovered: false
    property bool mediaExpanded: false
    readonly property bool selectorOpen: summaryLoader.item?.selectorOpen ?? false
    readonly property real microphoneWidth: MicrophoneStatus.available && MicrophoneStatus.muted ? Styling.fontSize(4) : 0
    readonly property int motionDuration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration))
    readonly property real contentWidth: 200 + userInfo.width + separator1.width + separator2.width + notifIndicator.width + microphoneWidth + 36
    implicitHeight: Config.showBackground ? (Config.notchTheme === "island" ? 36 : 44) : (Config.notchTheme === "island" ? 36 : 40)

    // Edge anchoring avoids a second positioner layout pass at the end of a
    // microphone transition. The bell follows only the animated capsule edge.
    UserInfo {
        id: userInfo
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }
    Separator {
        id: separator1
        vert: true
        anchors.left: userInfo.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
    NotificationIndicator {
        id: notifIndicator
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }
    Item {
        id: micIndicator
        anchors.right: notifIndicator.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.microphoneWidth
        height: Styling.fontSize(4)
        clip: true
        Behavior on width {
            NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic }
        }
        Text {
            anchors.centerIn: parent
            text: Icons.micSlash
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(4)
            color: Colors.criticalRed
            opacity: root.microphoneWidth > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.motionDuration } }
        }
    }
    Separator {
        id: separator2
        vert: true
        anchors.right: micIndicator.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
    Loader {
        id: summaryLoader
        anchors.left: separator1.right
        anchors.leftMargin: 4
        anchors.right: separator2.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        height: 32
        sourceComponent: !root.player || Config.notch.disableHoverExpansion ? legacySummary : simpleSummary
    }
    Component {
        id: simpleSummary
        MediaSummary { player: root.player; mediaExpanded: root.mediaExpanded }
    }
    Component {
        id: legacySummary
        CompactPlayer { player: root.player; notchHovered: root.hovered }
    }
}
