import QtQuick
import QtQuick.Effects
import qs.modules.components
import qs.modules.theme

StyledRect {
    id: root

    property url artwork: ""
    property real strength: 0.35
    readonly property real effectiveStrength: Number.isFinite(strength) ? Math.max(0, Math.min(1, strength)) : 0

    variant: "internalbg"
    backgroundOpacity: 0
    enableBorder: false
    radius: Styling.radius(-4)
    visible: image.status === Image.Ready && effectiveStrength > 0

    Image {
        id: image

        anchors.fill: parent
        source: root.artwork
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        blurEnabled: root.visible
        blurMax: 32
        blur: 0.8
        autoPaddingEnabled: false
        opacity: root.effectiveStrength
    }

    StyledRect {
        anchors.fill: parent
        variant: "internalbg"
        backgroundOpacity: 0.6
        enableBorder: false
        radius: root.radius
        opacity: root.effectiveStrength
    }
}
