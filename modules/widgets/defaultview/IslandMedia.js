.pragma library

function canExpand(hovered, player, disabled) {
    return !!hovered && !!player && !disabled;
}

function canSeek(player) {
    return !!player && !!player.canSeek && Number.isFinite(player.length) && player.length > 0;
}

function formatTime(seconds) {
    var total = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor(total / 60) % 60;
    var remainder = String(total % 60).padStart(2, '0');
    return hours > 0 ? hours + ':' + String(minutes).padStart(2, '0') + ':' + remainder : minutes + ':' + remainder;
}
