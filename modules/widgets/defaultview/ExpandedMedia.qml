import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config

Item {
    id: root

    required property var player
    readonly property int artworkSize: Math.max(32, Config.notch.expandedArtworkSize)
    readonly property int contentPadding: 16

    implicitHeight: content.implicitHeight + contentPadding * 2

    AlbumBackdrop {
        anchors.fill: parent
        anchors.margins: 4
        artwork: root.player?.trackArtUrl ?? ""
        strength: 0.2
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.contentPadding
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: root.contentPadding

            StyledRect {
                Layout.preferredHeight: root.artworkSize
                Layout.preferredWidth: root.artworkSize
                variant: "internalbg"
                radius: Styling.radius(-4)
                enableBorder: false

                Image {
                    id: artwork

                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: root.player?.trackArtUrl ?? ""
                    sourceSize: Qt.size(root.artworkSize * 2, root.artworkSize * 2)
                }

                Text {
                    anchors.centerIn: parent
                    color: Colors.overBackground
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(14)
                    text: Icons.player
                    visible: artwork.status !== Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    color: Colors.overBackground
                    elide: Text.ElideRight
                    font.bold: true
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(2)
                    text: root.player?.trackTitle || I18n.t("player.unknown")
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    color: Colors.overBackground
                    elide: Text.ElideRight
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    opacity: 0.65
                    text: root.player?.trackArtist || root.player?.identity || ""
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                }
            }
        }

        MediaTransportControls {
            Layout.alignment: Qt.AlignHCenter
            player: root.player
        }

        MediaTimeline {
            Layout.fillWidth: true
            player: root.player
        }

    }
}
