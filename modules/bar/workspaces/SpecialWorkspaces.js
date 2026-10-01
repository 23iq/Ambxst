.pragma library

// Hyprland keeps the underlying normal workspace active while a special
// workspace is open, so read the monitor's specialWorkspace explicitly.
function namesFromMonitors(monitors) {
    const names = {};
    for (const monitor of monitors || []) {
        const workspace = monitor.specialWorkspace;
        if (!workspace || !(workspace.id < 0))
            continue;
        const name = String(workspace.name || "").replace(/^special:/, "");
        names[monitor.name] = name || "special";
    }
    return names;
}
