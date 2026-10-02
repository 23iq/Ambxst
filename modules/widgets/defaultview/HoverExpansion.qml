import QtQuick
import qs.config
import "IslandMedia.js" as Media

// Owns only pointer timing. Notifications do not change this state.
Item {
    id: root
    property bool hovered: false
    property bool available: false
    property bool suspended: false
    property bool expanded: false
    readonly property bool allowed: Media.canExpand(true, available, Config.notch.disableHoverExpansion) && !suspended

    onAllowedChanged: {
        if (!allowed) expanded = false;
    }
    Timer {
        interval: Math.max(0, Config.notch.hoverExpandDelay)
        running: root.allowed && root.hovered && !root.expanded
        onTriggered: root.expanded = true
    }
    Timer {
        interval: Math.max(0, Config.notch.hoverCollapseDelay)
        running: !root.hovered && root.expanded
        onTriggered: root.expanded = false
    }
}
