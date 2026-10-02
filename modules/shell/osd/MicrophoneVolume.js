.pragma library

// Audio emits the current volume for mute events too. Only a change against
// an established baseline for this same ready source should display the OSD.
function observe(previous, node, volume, available) {
    if (!available || !node || !Number.isFinite(volume))
        return { node: null, volume: 0, show: false };

    return {
        node: node,
        volume: volume,
        show: !!previous && previous.node === node && previous.volume !== volume
    };
}
