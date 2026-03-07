/// Enum representing the types of games available in the app.
///
/// Each type corresponds to a built-in renderer that interprets
/// the game's config and assets to produce interactive gameplay.
enum GameType {
  /// Tap anywhere → animation + sound + color change.
  tapResponse,

  /// Drag shapes to matching outlines.
  shapeMatching,

  /// Tap to reveal hidden objects with surprise animations.
  peekaboo,

  /// Pop bubbles/objects that float across the screen.
  bubblePop,

  /// Free-form finger painting on a canvas.
  drawing,
}
