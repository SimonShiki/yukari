/// The gap m3e_core leaves between the buttons of a connected button group.
///
/// m3e_core keeps its own token private, so a group that computes its button
/// widths has to mirror the value; the theming mode selector and the share
/// choice group both measure against it, and both have tests that fail if it
/// drifts from the package's `2.0`.
const double connectedGap = 2.0;
