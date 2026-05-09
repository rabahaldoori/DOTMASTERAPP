---
name: Compliance-First Mobile
colors:
  surface: '#f9f9ff'
  surface-dim: '#d3daea'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eefe'
  surface-container-high: '#e2e8f8'
  surface-container-highest: '#dce2f3'
  on-surface: '#151c27'
  on-surface-variant: '#44474e'
  inverse-surface: '#2a313d'
  inverse-on-surface: '#ebf1ff'
  outline: '#75777e'
  outline-variant: '#c5c6cf'
  surface-tint: '#4e5e80'
  primary: '#031634'
  on-primary: '#ffffff'
  primary-container: '#1a2b4a'
  on-primary-container: '#8293b7'
  inverse-primary: '#b6c6ee'
  secondary: '#0453cd'
  on-secondary: '#ffffff'
  secondary-container: '#356ee7'
  on-secondary-container: '#fefcff'
  tertiary: '#13181a'
  on-tertiary: '#ffffff'
  tertiary-container: '#282c2e'
  on-tertiary-container: '#8f9396'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#b6c6ee'
  on-primary-fixed: '#081b39'
  on-primary-fixed-variant: '#364767'
  secondary-fixed: '#dae2ff'
  secondary-fixed-dim: '#b2c5ff'
  on-secondary-fixed: '#001848'
  on-secondary-fixed-variant: '#0040a2'
  tertiary-fixed: '#e0e3e6'
  tertiary-fixed-dim: '#c3c7ca'
  on-tertiary-fixed: '#181c1e'
  on-tertiary-fixed-variant: '#43474a'
  background: '#f9f9ff'
  on-background: '#151c27'
  surface-variant: '#dce2f3'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-page: 16px
  gutter-grid: 12px
  unit-xs: 4px
  unit-sm: 8px
  unit-md: 16px
  unit-lg: 24px
  unit-xl: 32px
  touch-target: 48px
---

## Brand & Style

The brand identity focuses on reliability, precision, and executive oversight. The target audience includes long-haul owner-operators and fleet managers who require high-density information that remains readable under varied lighting conditions. 

The design style is **Corporate / Modern** with a **Tactile** edge. It leverages the "Compliance-First Professional" aesthetic from desktop but adapts it for mobile through increased contrast and touch-friendly targets. The UI evokes a sense of "digital hardware"—tools that feel solid, responsive, and indestructible. By combining clean whitespace with subtle depth, this design system ensures that regulatory tasks feel streamlined rather than decorative.

## Colors

The palette is anchored by the core compliance blue (#1A2B4A), used for primary actions, navigation headers, and brand moments to establish authority. A secondary bright blue (#0052CC) is used for interactive elements like links and active toggles to ensure high visibility on mobile screens. 

Neutral tones lean toward cool grays to maintain the professional atmosphere. Backgrounds utilize a tiered approach: a pure white base for primary cards and a soft tertiary gray (#F4F7FA) for the global scaffold to create subtle separation between content blocks. Status colors (Success, Error, Warning) are highly saturated to ensure compliance alerts are impossible to miss during quick inspections.

## Typography

This design system utilizes **Inter** exclusively to ensure maximum legibility across different mobile resolutions. The hierarchy is tight and functional. Headlines use a heavier weight and slight negative letter-spacing to appear "locked-in" and authoritative. 

Body text is optimized for readability, with `body-md` serving as the workhorse for data lists and logs. Labels are used for metadata and status indicators, often paired with slightly increased letter spacing or uppercase transformations to distinguish them from interactive text. All typography scales are based on a 4px baseline grid to ensure vertical rhythm.

## Layout & Spacing

The layout philosophy follows a **Fluid Grid** model adapted for small screens. The standard page margin is 16px, ensuring content doesn't feel cramped while maximizing horizontal real estate for complex data tables. 

Components are laid out using an 8pt grid system. Interactive elements must adhere to a minimum 48px touch target height. For lists of compliance records, a 12px gutter is used to maintain a high-density feel without sacrificing clarity. Horizontal scrolling is permitted for wide data tables, provided the primary identifier column remains sticky.

## Elevation & Depth

Visual hierarchy is established through **Tonal Layers** and **Ambient Shadows**. This design system avoids aggressive shadows in favor of a "stacked paper" look.

1.  **Level 0 (Surface):** The background scaffold (#F4F7FA).
2.  **Level 1 (Cards/Inputs):** Pure white surfaces with a 1px stroke (#E5E7EB) and a very soft, diffused shadow (0px 2px 4px rgba(0,0,0,0.05)).
3.  **Level 2 (Active/Floating):** Used for Bottom Sheets and Floating Action Buttons (FABs). These feature a more pronounced shadow (0px 8px 16px rgba(26, 43, 74, 0.1)) to indicate they sit above the primary content.

This approach creates a tactile environment where the user understands that cards can be tapped or swiped.

## Shapes

The shape language is defined as **Rounded**, directly inheriting the `rounded-lg` (8px-16px) aesthetic from the desktop system. 

- **Standard Components:** 8px (0.5rem) radius for buttons, input fields, and small cards.
- **Large Containers:** 16px (1rem) radius for bottom sheets and main dashboard cards.
- **Micro-elements:** 4px (0.25rem) for checkboxes and small tags.

The use of rounded corners softens the professional "Blue" palette, making the app feel modern and user-friendly rather than strictly bureaucratic.

## Components

- **Buttons:** Primary buttons use the #1A2B4A background with white text and 8px rounded corners. They should have a subtle "press" animation (slight scale down) to provide tactile feedback.
- **Input Fields:** Outlined style with a 1px border (#D1D5DB). When focused, the border thickens to 2px and changes to the primary color. Labels are always visible above the field.
- **Cards:** Used for trip summaries and vehicle stats. Cards include a white background, 16px padding, and a 1px border.
- **Chips/Badges:** Used for IFTA status (e.g., "Compliant", "Pending"). These use a "Pill" shape (32px radius) with a light tinted background and dark text of the same hue.
- **Lists:** High-density list items with 16px vertical padding. Use chevron-right icons for navigable items and trailing metadata for status values.
- **Checkboxes/Radios:** Use the primary blue for selected states. Checkboxes are slightly rounded (4px) to match the overall system.
- **Specialized Components:** 
    - **Data Log Strip:** A compressed horizontal list item showing "Start Odometer" and "End Odometer" with a vertical connector line between them.
    - **Compliance Gauge:** A circular progress indicator for tracking tax deadlines or fuel quotas.