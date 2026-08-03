# v0ca. — Design System

Source: the mockups in `design/Design system for voice transcription app/` (three HTML files: the design system, the HUD, and the settings). This document is a distilled set of tokens for the SwiftUI implementation (`DesignSystem/`).

## Fonts

**System fonts only** — the bundle ships no font files at all. Google Sans was tried
side by side with SF Pro and turned out to be indistinguishable in this UI, so both
it and Google Sans Code were dropped (−5.7 MB).

| Role | Font | Weights |
|---|---|---|
| Interface (all text) — `Tokens.sans()` | **SF Pro** (`.system`) | 400 / 500 / 600 |
| Logo + everything monospaced (timers, hotkeys, file sizes, dates) — `Tokens.mono()` | **SF Mono** (`.system(design: .monospaced)`) | 400 / 500 / 600 |

The "v0ca." logo — SF Mono 600, the dot is always accent-red `#E03E3E`.

## Colors

### Light theme
| Token | Hex |
|---|---|
| background | `#F6F6F7` |
| surface | `#FFFFFF` |
| surface2 | `#EFEFF1` |
| border | `#E3E3E7` |
| text | `#1B1B1F` |
| text2 | `#6C6C74` |
| text3 | `#9B9BA3` |
| accentBg | `#FCEBEB` |

### Dark theme
| Token | Hex |
|---|---|
| background | `#131316` |
| surface | `#1C1C20` |
| surface2 | `#26262B` |
| border | `#2E2E34` |
| text | `#F2F2F4` |
| text2 | `#A5A5AE` |
| text3 | `#6E6E77` |
| accentBg | `#3A1D1F` |

### Accent (Signal Red) and semantics
- accent100 `#FCEBEB` · accent300 `#F5B8B8` · **accent500 `#E03E3E`** (primary) · accent600 hover `#C93232` · accent700 active `#A82626`
- processing `#E8A13C` (orange) · success `#3EAF6E` (green) · error/recording `#E03E3E`
- Alternative accents in settings: `#E03E3E`, `#D9823E`, `#5FA173`, `#5B84C0`, `#9C74C4`

## Typographic scale (SF Pro)

| Style | Size / weight / other |
|---|---|
| Display | 34 / 600 / -0.02em |
| Title | 22 / 600 / -0.01em |
| Headline | 15 / 600 |
| Body | 14 / 400 / lh 1.55 |
| Caption | 12 / 400 |
| Label (CAPS) | 11 / 500 / +0.1em |
| Timer | 26 / SF Mono, tabular-nums |

## Geometry

- Radii: 8 (controls) / 12 (cards) / 14 (windows) / 100 (pills, HUD).
- Heights: button 36 (compact 28), input 36.
- Padding: 12–16 inside inputs, 18 horizontal in buttons.
- Window shadow: `0 16px 36px rgba(24,32,48,0.10)`.

## HUD

- Position: bottom-center of the screen, ~112–260px from the bottom edge (the "Recording indicator position" setting).
- Glass capsule: backdrop blur 14px, background rgba(255,255,255,0.94) / dark theme — larger (44px) and a different opacity.
- States:
  1. **Hidden** — nothing (or the "⌥ Space" hint, mono 13px, dimmed).
  2. **Recording** — width ~136px: a blinking red dot (blink 1.2s), a waveform of 10 bars (scaleY animation with phase offsets), an ✕ button (28px circle).
  3. **Transcribing** — width ~172px: a spinner (0.9s), the "Transcribing…" text 12.5px gray, a cancel button.
  4. **Done** — shrinks to a ~38px circle, a green checkmark with a stroke animation (0.4s), then auto-hides.

## Settings window

- 920×640, a 44px top bar with traffic lights, the "Settings" title centered.
- Sidebar 208px: the "v0ca." logo (SF Mono 20/600), the tabs General / Models / Sound / History with 15px icons, "v 1.0.0" at the bottom.
- The full contents of each tab are in the `Экран · Настройки.dc.html` mockup; cross-check with it during implementation.
