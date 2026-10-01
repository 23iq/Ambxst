# Special workspace indicator

On Hyprland, an open special workspace appears as a centered pill over blurred
normal workspace icons. Its name comes from the monitor's `specialWorkspace`
state, with only the leading `special:` prefix removed. Hovering over the widget
reveals the normal workspace buttons for navigation. Both bar orientations are
supported; vertical bars rotate the label to fit.

Configure `~/.config/ambxst/config/workspaces.json`:

```json
{
    "showSpecialWorkspace": true,
    "specialWorkspaceAnimationDuration": 100,
    "specialWorkspaceFont": ""
}
```

The duration is in milliseconds; zero disables the transition. The global
animation switch and GameMode also disable it. An empty font setting uses the
Qt application's system font. Set a font family explicitly to override it.
The existing theme font size controls the label size.

This indicator does not change normal workspace navigation on other compositors.
Special workspaces are excluded from the dynamic normal-workspace button list.

Run the parsing tests with `node tests/special-workspaces.test.cjs`.
