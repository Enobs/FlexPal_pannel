# FlexPAL UI Design Specifications

## Chamber Card Design

```
┌─────────────────────────────────────────────┐
│  ╔═══╗                                      │
│  ║ 🔲 ║  Chamber 1      ⚫ ONLINE          │
│  ╚═══╝  CH-001                              │
│  ────────────────────────────────────────── │
│                                              │
│  ┌───┐  Length                              │
│  │ ↕ │  23.5 mm                            │
│  └───┘                                       │
│                                              │
│  ┌───┐  Pressure                            │
│  │ ⚡ │  5000.0 kPa                         │
│  └───┘                                       │
│                                              │
│  ┌───┐  Battery                             │
│  │ 🔋 │  87%                                │
│  └───┘                                       │
└─────────────────────────────────────────────┘
```

### Measurements
- **Card Size**: Flexible (grid-based)
- **Border Radius**: 16px
- **Padding**: 16px all sides
- **Icon Size**: 20px (header), 14px (metrics)
- **Border Width**: 1.5px
- **Shadow Blur**: 12px

### Colors (Online State)
```
Background: Linear Gradient
  - Start: #2A2A2A
  - End:   #1E1E1E

Border: #2ECC71 (30% opacity)
Shadow: #2ECC71 (10% opacity)
Glow Effect: Radial gradient from top-right
```

### Colors (Offline State)
```
Background: Same gradient
Border: #555555 (20% opacity)
Shadow: Black (30% opacity)
No glow effect
```

## Navigation Icons

```
┌──────────────────────────────────────────────────────────┐
│  [Grid]  [Gamepad]  [Chart]  [List]  [Gear]            │
│  Overview  Remote   Monitor  Logs    Settings           │
└──────────────────────────────────────────────────────────┘
```

### Icon Mapping
| Page | Icon | Font Awesome | Purpose |
|------|------|--------------|---------|
| Overview | ⊞ | `grip` | Dashboard view |
| Remote | 🎮 | `gamepad` | Control interface |
| Monitor | 📈 | `chart-line` | Real-time data |
| Logs | 📋 | `rectangle-list` | Event log |
| Settings | ⚙️ | `gear` | Configuration |

## Metric Icons

| Metric | Icon | Font Awesome | Color | Hex |
|--------|------|--------------|-------|-----|
| Length | ↕ | `arrows-up-down` | Blue | #3498DB |
| Pressure | ⚡ | `gauge-high` | Orange | #E67E22 |
| Battery | 🔋 | `battery-half` | Dynamic | See below |
| Chamber | 🔲 | `microchip` | Status-based | #2ECC71/#888888 |
| Error | ⚠️ | `circle-exclamation` | Grey | #999999 |

### Battery Color Logic
```dart
if (battery > 60%)  → Green  #2ECC71
if (battery > 30%)  → Orange #E67E22
else               → Red    #E74C3C
```

## Typography Scale

```
Large Heading:    18px, Bold, 0.5px spacing
Subheading:       11px, Medium, 1.0px spacing
Metric Label:     11px, Medium, 0px spacing
Metric Value:     14px, Bold, 0.3px spacing
Status Badge:     9px, Bold, 0.5px spacing
Body Text:        12px, Regular
```

### Font Stack
```
Primary: System Default
Fallback: Roboto, Inter, SF Pro, Segoe UI
Monospace: (for logs) SF Mono, Consolas
```

## Status Indicator Design

### Online Badge
```
┌─────────────────┐
│ ⚫ ONLINE       │  ← Glowing green border
└─────────────────┘
    ↑
  6px dot with 4px glow
```

**Specs:**
- Padding: 10px horizontal, 5px vertical
- Border radius: 20px (pill shape)
- Border: 1px solid
- Dot size: 6×6px circle
- Dot glow: 4px blur, 1px spread

### Offline Badge
```
┌─────────────────┐
│ ⚫ OFFLINE      │  ← Red border, no glow
└─────────────────┘
```

## Glow Effect Animation

```css
/* Conceptual - not actual CSS */
.chamber-card-online::before {
  content: '';
  position: absolute;
  top: -50px;
  right: -50px;
  width: 150px;
  height: 150px;
  background: radial-gradient(
    circle,
    rgba(46, 204, 113, 0.1),
    transparent
  );
  animation: pulse 2s ease-in-out infinite;
}
```

## Spacing System

```
XS:  4px   - Internal spacing
S:   8px   - Component spacing
M:   12px  - Section spacing
L:   16px  - Card padding
XL:  24px  - Major sections
XXL: 32px  - Page margins
```

## Elevation System

```
Level 0: No shadow (flat)
Level 1: 0 2px 4px rgba(0,0,0,0.1)
Level 2: 0 4px 8px rgba(0,0,0,0.2)
Level 3: 0 8px 16px rgba(0,0,0,0.3)
Level 4: 0 12px 24px rgba(0,0,0,0.4)  ← Chamber cards
```

## Interaction States

### Hover (Desktop)
```dart
opacity: 0.9
cursor: pointer
transition: 200ms ease-out
```

### Pressed
```dart
scale: 0.98
opacity: 0.8
transition: 100ms ease-in
```

### Disabled
```dart
opacity: 0.5
cursor: not-allowed
```

## Accessibility

### Contrast Ratios
- **Normal text**: 4.5:1 minimum (WCAG AA)
- **Large text**: 3:1 minimum
- **Interactive elements**: 3:1 minimum

### Touch Targets
- **Minimum size**: 48×48dp
- **Recommended**: 56×56dp for primary actions

### Focus Indicators
```dart
outline: 2px solid #3498DB
outline-offset: 2px
```

## Animation Timing

```
Fast:   100-200ms  (clicks, toggles)
Normal: 250-350ms  (transitions, fades)
Slow:   400-600ms  (page transitions)
Smooth: 1000-2000ms (ambient animations)
```

### Easing Functions
- **Ease-out**: User-initiated actions
- **Ease-in**: System-initiated removal
- **Ease-in-out**: Reversible animations

## Grid System

### Overview Page
```
3 columns × 3 rows = 9 chamber cards

┌────────┬────────┬────────┐
│ Card 1 │ Card 2 │ Card 3 │
├────────┼────────┼────────┤
│ Card 4 │ Card 5 │ Card 6 │
├────────┼────────┼────────┤
│ Card 7 │ Card 8 │ Card 9 │
└────────┴────────┴────────┘

Gap: 12px
Aspect ratio: 1.5:1 (width:height)
```

## Export for Designers

### Figma Colors
```
Green:  #2ECC71
Red:    #E74C3C
Blue:   #3498DB
Orange: #E67E22
Dark:   #1E1E1E
Card:   #2A2A2A
```

### Sketch/Adobe XD
Import Font Awesome 6.0 icon set for consistency.

---

**Design System Version**: 1.1.0
**Last Updated**: 2025-11-11
**Maintained by**: FlexPAL Team
