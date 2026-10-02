pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import qs.config
import "MicrophoneState.js" as State

Singleton {
    id: root

    readonly property bool available: !!Audio.source?.ready && !!Audio.source?.audio
    readonly property bool muted: available && Audio.source.audio.muted
    property string noticeScreen: ""
    property bool noticeVisible: false
    property var observation: null

    function observe() {
        const ready = !!Audio.source?.ready && !!Audio.source?.audio;
        const next = State.observe(observation, Audio.source, ready, ready && Audio.source.audio.muted);
        observation = next;
        if (!ready) {
            noticeVisible = false;
            noticeTimer.stop();
        }
        if (next.notify) {
            noticeScreen = AxctlService.focusedMonitor?.name ?? "";
            noticeVisible = true;
            noticeTimer.restart();
        }
    }

    Component.onCompleted: observe()
    onAvailableChanged: observe()
    onMutedChanged: observe()

    Connections {
        function onSourceChanged() {
            root.noticeVisible = false;
            noticeTimer.stop();
            root.observe();
        }

        target: Audio
    }
    Timer {
        id: noticeTimer

        interval: Math.max(0, Config.notch.microphoneNoticeDuration)

        onTriggered: root.noticeVisible = false
    }
}
