import QtQuick
import qs.modules.services
import qs.config

Item {
    id: root
    focus: false
    width: implicitWidth
    height: implicitHeight
    property string screenName: ""
    property bool notchHovered: false
    property bool parentHoverActive: false
    // Stack transitions freeze idle interaction so closing a launcher cannot
    // simultaneously trigger a second media expansion.
    property bool interactionSuspended: false
    readonly property var activePlayer: MprisController.activePlayer
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0
    readonly property bool isBottom: Config.notchPosition === "bottom"
    readonly property bool mediaHovered: !interactionSuspended && (header.mediaHovered || mediaHover.hovered || (mediaHoverExpanded && (header.selectorOpen || Visibilities.playerMenuOpen)))
    readonly property bool expandedState: !interactionSuspended && (mediaHovered || notificationHover.hovered || notifications.navigating)
    readonly property bool mediaHoverExpanded: hoverExpansion.expanded

    implicitWidth: Math.max(header.contentWidth, mediaHoverExpanded ? Config.notch.expandedMediaWidth : 0, hasActiveNotifications ? (expandedState ? 452 : 352) : 0)
    readonly property int mediaMotionDuration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration))
    implicitHeight: header.implicitHeight + (mediaHoverExpanded ? expandedMedia.implicitHeight : 0) + notificationSlot.height

    HoverExpansion {
        id: hoverExpansion
        hovered: root.mediaHovered
        available: !!root.activePlayer
        suspended: root.interactionSuspended
    }
    Timer {
        id: mediaCloseTimer
        interval: root.mediaMotionDuration
    }
    onInteractionSuspendedChanged: {
        if (interactionSuspended) mediaCloseTimer.stop();
    }
    onMediaHoverExpandedChanged: {
        if (mediaHoverExpanded) mediaCloseTimer.stop();
        else if (activePlayer && !interactionSuspended && mediaMotionDuration > 0) mediaCloseTimer.restart();
    }
    IslandHeader {
        id: header
        width: parent.width
        height: implicitHeight
        anchors.top: root.isBottom ? undefined : parent.top
        anchors.bottom: root.isBottom ? parent.bottom : undefined
        player: root.activePlayer
        hovered: root.expandedState
        mediaExpanded: root.mediaHoverExpanded
    }
    Item {
        id: body
        width: parent.width
        height: mediaSlot.height + notificationSlot.height
        anchors.top: root.isBottom ? undefined : header.bottom
        anchors.bottom: root.isBottom ? header.top : undefined

        Item {
            id: mediaSlot
            width: parent.width
            height: root.mediaHoverExpanded || mediaCloseTimer.running ? Math.max(0, Math.min(expandedMedia.implicitHeight, root.height - header.implicitHeight - notificationSlot.height)) : 0
            clip: true
            HoverHandler { id: mediaHover; enabled: root.mediaHoverExpanded }
            ExpandedMedia {
                id: expandedMedia
                width: parent.width
                height: implicitHeight
                player: root.activePlayer
                visible: parent.height > 0
                enabled: root.mediaHoverExpanded
            }
        }
        Item {
            id: notificationSlot
            anchors.top: mediaSlot.bottom
            width: parent.width
            height: root.hasActiveNotifications ? notifications.implicitHeight : 0
            clip: true
            HoverHandler { id: notificationHover; enabled: root.hasActiveNotifications }
            IslandNotifications {
                id: notifications
                anchors.fill: parent
                visible: root.hasActiveNotifications
                hovered: root.expandedState
            }
        }
    }
}
