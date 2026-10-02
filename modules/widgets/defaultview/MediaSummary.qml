import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config

// The player badge keeps a stable place in the capsule; hover only changes tint.
Item {
    id: root
    required property var player
    property bool mediaExpanded: false
    readonly property bool selectorOpen: selector.isOpen

    AlbumBackdrop {
        anchors.fill: parent
        artwork: root.player?.trackArtUrl ?? ""
        strength: root.mediaExpanded ? 0 : 0.6
        Behavior on strength {
            NumberAnimation { duration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration)); easing.type: Easing.OutCubic }
        }
    }
    Text {
        anchors.left: parent.left
        anchors.right: playerBadge.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 6
        text: root.player ? (root.player.trackTitle || I18n.t("player.unknown")) : (Config.notch.customText || "Ambxst")
        textFormat: Text.PlainText
        color: Colors.overBackground
        font.family: Styling.defaultFont
        font.pixelSize: Styling.fontSize(0)
        font.bold: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    Item {
        id: playerBadge
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.player ? 24 : 0
        height: 24
        visible: !!root.player
        Text {
            anchors.centerIn: parent
            text: /spotify/i.test((root.player?.dbusName ?? "") + (root.player?.identity ?? "") + (root.player?.desktopEntry ?? "")) ? Icons.spotify : Icons.player
            color: Colors.overBackground
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(4)
            opacity: badgeHover.hovered ? 1 : 0.65
            Behavior on opacity {
                NumberAnimation { duration: Math.min(Config.animDuration, 120) }
            }
        }
        HoverHandler { id: badgeHover }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: selector.toggle()
        }
        ToolTip.visible: badgeHover.hovered
        ToolTip.delay: 700
        ToolTip.text: root.player?.identity || I18n.t("player.unknown_player")
    }
    MouseArea {
        anchors.left: parent.left
        anchors.right: playerBadge.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        enabled: !!root.player
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: selector.toggle()
    }
    BarPopup {
        id: selector
        anchorItem: root
        bar: ({ barPosition: Config.notchPosition })
        contentWidth: Math.max(220, root.width)
        contentHeight: players.implicitHeight + popupPadding * 2
        ColumnLayout {
            id: players
            anchors.fill: parent
            spacing: 4
            Repeater {
                model: MprisController.filteredPlayers
                delegate: StyledRect {
                    id: choice
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    variant: root.player === modelData ? "focus" : "common"
                    radius: Styling.radius(-4)
                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: choice.modelData.identity || choice.modelData.trackTitle || I18n.t("player.unknown_player")
                        textFormat: Text.PlainText
                        color: choice.item
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.setActivePlayer(choice.modelData)
                    }
                }
            }
        }
    }
}
