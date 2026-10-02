# Dynamic island media and microphone

Goal: expand Ambxst's existing island into a media card on hover and display real microphone mute state.

Approved design: compact idle capsule; 90 ms hover opens artwork, title/artist, transport and seek/time; 200 ms leave delay. No empty card. Notifications coexist below music and never reset hover. Super+Alt+M toggles the default PipeWire input; muted icon remains visible and reveals an auto-hidden island on the focused monitor.

Implementation in the user's existing fork checkout, on feat/dynamic-island-media-mic. Preserve pre-existing import fixes without staging them.

- [x] Add behavioral tests for expansion eligibility and invalid/live media durations.
- [x] Implement isolated media card and timed hover; defaults and adapter stay synchronized.
- [x] Add microphone status service, focused-monitor reveal and idle indicator.
- [x] Configure the user's hover setting and keybinding; document command for other installations.
- [x] Run Node tests, QML parse checks, available runtime checks, review and commit only feature changes.

Review: loss of player while expanded; live/non-seekable media; pointer traversal through growing input mask; notifications; unavailable/replaced audio source; startup must not display an unmute notice. Existing local import fixes belong to the user.

User refinements: suppress mute-only bottom OSD; fix launcher closing geometry; no flash of legacy hover controls; improve media layout using separate contributors. User requested no further live-session tests; final checks are static/automated only.

Final refinement: one 160 ms media morph (no nested geometry animations); persistent player badge with opacity-only hover feedback, no insertion/reflow.

Final animation corrections: idle content follows animated viewport, geometry targets use independent implicit dimensions; outgoing media retained until close completes; microphone footprint animates without reserved space; only its glyph is shown.

Final header correction: direct edge anchors replace Row positioner, so bell follows only capsule width with no second layout pass. Buttons/progress match existing shell; blurred album background crossfades from title to card during expansion.
