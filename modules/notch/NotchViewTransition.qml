import QtQuick
import qs.config

// Exchange content at its natural size while the notch morphs around it.
Transition {
    id: root

    property bool entering: false

    SequentialAnimation {
        PropertyAction {
            property: "opacity"
            value: root.entering ? 0 : 1
        }
        PauseAnimation {
            duration: root.entering ? Config.animDuration / 4 : 0
        }
        NumberAnimation {
            property: "opacity"
            from: root.entering ? 0 : 1
            to: root.entering ? 1 : 0
            duration: root.entering ? Config.animDuration * 3 / 4 : Config.animDuration / 4
            easing.type: Easing.OutCubic
        }
    }
}
