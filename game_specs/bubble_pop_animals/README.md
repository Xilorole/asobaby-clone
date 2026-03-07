# Bubble Pop Animals

## Game Type
bubblePop

## Target Age
6 months - 3 years

## Description
Colorful bubbles float up from the bottom of the screen. Each bubble
has a bright, cheerful color. Baby taps a bubble to pop it — it bursts
with a fun particle animation. Bubbles keep spawning endlessly.

## Visual Theme
- Light sky-blue background
- Bubbles in rainbow colors with a shiny glossy look (radial gradient + white highlight)
- When popped, 8 small particles burst outward and fade

## Gameplay Rules
1. Bubbles spawn at the bottom of the screen and float upward
2. Each bubble gently wobbles side-to-side as it rises
3. Baby taps any bubble → it pops with a burst animation
4. Bubbles that reach the top of the screen disappear
5. New bubbles continuously spawn to replace popped/vanished ones
6. The game is endless — no score, no win/lose

## Required Assets

### Images
| Filename | Description | Size |
|----------|-------------|------|
| thumbnail.png | Preview showing colorful bubbles on blue background | 200x200 |

### Sounds
| Filename | Description | Duration |
|----------|-------------|----------|
| sounds/pop.mp3 | Soft bubbly pop sound | 0.3s |

## Settings (config.json)
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| bubbleCount | int | 8 | Maximum simultaneous bubbles on screen |
| speed | double | 1.0 | Float speed multiplier |
| minSize | double | 35 | Minimum bubble radius (dp) |
| maxSize | double | 65 | Maximum bubble radius (dp) |
| colors | List | rainbow | Hex color strings for bubbles |

## Notes
- This is the first/default game — keep it simple and reliable
- No assets strictly needed since the bubble renderer draws everything with code
- Sound effects can be added later via the assets map
