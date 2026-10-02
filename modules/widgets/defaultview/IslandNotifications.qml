import QtQuick
import qs.modules.notch
import qs.config

Item {
    id: root
    property bool hovered: false
    readonly property bool navigating: notificationView.isNavigating
    readonly property int bottomPadding: Config.notchTheme === "island" ? 20 : 16
    implicitHeight: notificationView.implicitHeight + 8 + bottomPadding

    NotchNotificationView {
        id: notificationView
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: root.bottomPadding
        notchHovered: root.hovered
    }
}
