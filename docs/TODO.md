# Kamalen Shell TODO

This is the current, intentionally small roadmap. It replaces the old numbered
"next phases" at the bottom of the bar changelog. Items are grouped by evidence
and user value, not by speculation.

## Now

- [x] Curate live screenshots for the README and documentation gallery.
- [ ] Perform a real multi-monitor acceptance pass: arrangement drag, scale,
  refresh rate, preview timeout, confirm, and revert on physical outputs.
- [ ] Perform visual acceptance on representative GTK 3 and GTK 4 applications
  after each new skin; preserve automatic palette behavior in each case.

## Next

- [ ] Add focused visual-regression fixtures for the skin preview and generated
  GTK material CSS, without asserting wallpaper-specific literal colors.
- [ ] Review the bar on narrow displays and high UI scales for cross-area overlap
  before adding additional widgets.
- [ ] Audit remaining controls for concise tooltips where icon-only affordances
  are not self-explanatory.
- [ ] Improve the optional clock expansion only if it remains legible across all
  four bar modes and does not compete with media metadata.

## Later

- [ ] Add new skin families only after they have a distinct material recipe,
  GTK counterpart, palette-adaptive behavior, and a screenshot/reference plan.
- [ ] Document the experimental NixOS/Home Manager port with a separate runtime
  validation matrix once it can exercise the same shell lifecycle reliably.

## Explicitly out of scope for the current skin engine

- Window titlebar decoration.
- A dock or taskbar.

Those features are separate shell projects and must not be smuggled into visual
skin work.

## Completion rule

An item moves to done only after its narrow test or manual acceptance path is
recorded, the relevant documentation is updated, and the result does not break
the automatic color pipeline.
