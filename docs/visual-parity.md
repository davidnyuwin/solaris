# Solaris — Visual Parity Baseline & Gap Analysis

> [!IMPORTANT]
> **Status:** `MEASURED & AUDITED` (June 2, 2026)
> This document establishes a visual parity baseline for **Solaris v0.2**, comparing the actual running SwiftUI application against our high-fidelity public README concept mockups. It maps out layout, styling, animation, and accessibility gaps, rating them by implementation effort and design impact.

---

## 🔍 Overview of Visual Parity

Our goal is to evolve the user interface from a basic dark-mode Swift wrapper to a highly premium, fluid Siri-style macOS AI control surface. We will do this while preserving complete compilation stability and keeping the underlying mock and diagnostics services decoupled.

### 🗺️ Visual Directions Comparison
*   **Actual SwiftUI App:** Solid charcoal-obsidian backgrounds, basic SwiftUI nested circles with hard lines and a bolt icon core, standard macOS native `List` sidebars, and default `.formStyle(.grouped)` settings menus.
*   **Target Concept Mockup:** Volumetric, glowing plasma orb with fluid noise boundaries and soft gradients, deep glassmorphic overlay backdrops (`.ultraThinMaterial`), custom capsule navigation states, and premium contextual form items with neon ambient color bleeds.

---

## 🎨 Detailed Gap Analysis

### 1. Dashboard View Gaps
| Visual Component | Actual SwiftUI Implementation | Target Mockup Design | Effort | Impact |
| :--- | :--- | :--- | :--- | :--- |
| **The Orb Canvas** | Flat nested `Circle` shapes, rotating a hard leading linear gradient, overlaid with an SF symbol bolt. | A volumetric, glowing, organic plasma field with volumetric depth, rotating soft radial blurs without hard glyphs. | **Medium** | **High** |
| **Layout Columns** | Simple vertical stack: Orb -> Title -> status card -> action chips -> timeline scroll. | Stately layout: left sidebar, central volumetric orb, right sidebar for contextual cards (Upcoming, Tasks). | **Large** | **High** |
| **Backdrop Material** | Solid opaque `Color.hermesObsidian` background. | Deep translucent glassmorphic backdrop with soft colored light bleeding from behind the window. | **Medium** | **High** |
| **Action Chips** | Simple capsules with thin borders. | Styled chips with responsive hover states and rounded background capsules. | **Small** | **Medium** |

---

## 2. Local Diagnostics View Gaps
| Visual Component | Actual SwiftUI Implementation | Target Mockup Design | Effort | Impact |
| :--- | :--- | :--- | :--- | :--- |
| **Section Layout** | Vertical list stacking raw `ProviderCard` and a standard Divider list of log items. | Grouped, distinct panes ("Parsed System Logs", "Local Processes (PID)") with clean spacing. | **Medium** | **High** |
| **Process Table** | No dedicated process list table in the UI yet. | Structured columns (Process name, PID, Active/Stable status badges) with clear alignment. | **Medium** | **High** |
| **Log Terminal Console** | Standard vertical divider stack of single-line log items. | Monospaced dark console window with unified timestamps and inline `[INFO]`, `[WARN]`, and `[ERROR]` color badges. | **Medium** | **High** |

---

## 3. Settings View Gaps
| Visual Component | Actual SwiftUI Implementation | Target Mockup Design | Effort | Impact |
| :--- | :--- | :--- | :--- | :--- |
| **Menu Forms** | Standard macOS `.formStyle(.grouped)` lists. | Sleek custom-designed connection server cards with glassmorphic backgrounds. | **Medium** | **Medium** |
| **Input Fields** | Standard TextField boxes with default borders. | Bordered custom fields with integrated inline status checks (e.g. green circle checkmark). | **Small** | **Medium** |
| **Dropdown Pickers** | Default standard native Picker structures. | Contextual select buttons that open clean overlays with styled details. | **Medium** | **Medium** |

---

## ⚙️ Layout, Resizing, Color, and Animation Analysis

### 4. Layout & Resizing Issues
*   **The Issue:** The split view column width is hardcoded to a minimum of 200 and maximum of 260. The detail pane is fully elastic but has no multi-column grid constraint. On large screens, the central orb is centered with wide gutters, which differs from the mockup's tightly structured columns.
*   **Effort:** **Medium** | **Impact:** **High**

### 5. Light & Dark Mode Issues
*   **The Issue:** The application forces a dark color scheme (`.preferredColorScheme(.dark)`). While the mockups are also dark-themed, the app's solid black background fails to adapt to standard translucent desktop light reflection, preventing the native window-under-material brightness from bleeding through.
*   **Effort:** **Small** | **Impact:** **Medium**

### 6. Animation Issues
*   **The Issue:** The current orb breathing effect is a basic `.easeInOut` loop scaling the circles from 1.0 to 1.15. It lacks the fluid, shifting, volumetric movement that represents active intelligence.
*   **Effort:** **Medium** | **Impact:** **High**

### 7. Accessibility & Readability Issues
*   **The Issue:** Font sizing and weights in headers use generic SwiftUI system fonts. High-opacity colors (e.g. `white.opacity(0.5)`) can create contrast concerns in smaller fonts against dark gray backdrops.
*   **Effort:** **Small** | **Impact:** **Medium**

---

## 🚀 Recommended v0.2 Implementation Plan

To achieve maximum visual upgrade with minimal compile-risk, we break the visual parity goals into three distinct, manageable batches for v0.2:

### Batch 1: Volumetric Orb & Glassmorphism (Highest Impact)
*   **Task 1:** Rebuild the `HermesOrbView` to simulate the volumetric plasma orb. We will overlay 3–4 blurring circular gradients, rotating them in opposite directions at varying speeds, and breathing them dynamically without the center SF Symbol bolt.
*   **Task 2:** Apply a custom `.background(.ultraThinMaterial)` sidebar structure and enable soft light colors to bleed from behind the main window area to establish realistic glassmorphism.
*   *Effort: Medium | Impact: High*

### Batch 2: Diagnostics Columns & Badges
*   **Task 1:** Upgrade the diagnostics/providers layout into the organized "Parsed System Logs" console and "Local Processes (PID)" list.
*   **Task 2:** Implement badge colors in the lists matching standard status parameters (emerald for `Active`, blue for `Stable`, amber for `Idle`).
*   *Effort: Medium | Impact: High*

### Batch 3: Custom Form Fields & Verification
*   **Task 1:** Refactor `SettingsView` from basic Form rows into elegant connection cards.
*   **Task 2:** Embed custom TextField styling with inline connection status indicators.
*   *Effort: Small | Impact: Medium*

---

## 🛠️ Batch 1 Status & Updates (June 2, 2026)

### ✅ What Changed
*   **Volumetric Solaris Orb:** Completely rebuilt `HermesOrbView` from standard circles to a highly premium volumetric sun. Embedded 5 layered, overlapping circular/radial gradients, dynamic breathing scale animation, slow clockwise/counter-clockwise multi-rotational layers, a soft radial indigo edge glow for three-dimensional perspective, and full support for Reduce Motion accessibility properties. Removed the hard SF Symbol glyph center.
*   **Glassmorphic Backdrops:** Rebuilt the `MainView` detail pane with a deep graphite/violet backdrop gradient and a top-center radial solar orange glow to reflect behind the central orb canvas. Configured all detail views (`DashboardView`, `RunsView`, `ProvidersView`, `SettingsView`) to use transparent backgrounds (`Color.clear`), enabling the ambient backdrop glow to seamlessly bleed through.

### ⚠️ What Remains
*   **Grouped Diagnostics Panes:** Batch 2 remains next in order to organize list details into parsed column tables and status badges.
*   **Custom Settings Cards:** Batch 3 is required to convert default Form structures to elegant connection panels.

### 💡 Visual Compromises & Technical Decisions
*   **Sidebar Vibrant Material:** Left the sidebar's native material blending intact to let macOS manage window transparency naturally rather than hardcoding overdone, high-vibrancy colored graphics.
*   **Mockup Parity:** While the orb and backdrop represent an immense, high-impact jump in quality matching the concept art style, the app window does not fully duplicate the three-column greeting details because structural functionality (which requires core app model changes) remains decoupled in this visual batch.
