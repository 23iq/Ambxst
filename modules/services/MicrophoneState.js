.pragma library

// First observation of a ready source establishes its baseline. Switching
// sources or losing readiness must not masquerade as a user mute action.
function observe(previous, source, ready, muted) {
    return {
        source: source,
        ready: !!ready,
        muted: !!muted,
        notify: !!previous && !!ready && previous.ready && previous.source === source && previous.muted !== !!muted
    };
}
