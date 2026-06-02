# Solaris — Local App Bundle Packaging

This document outlines the visual structure, compilation workflows, and future milestones for packaging **Solaris** into a standalone, Finder-launchable macOS application bundle (`Solaris.app`).

---

## 🚀 How to Build and Package Locally

To build a local, standalone release version of Solaris and structure it into a standard macOS application bundle, execute the bundler script:

```bash
# Make the bundler script executable (if not already)
chmod +x scripts/build-app.sh

# Run the local bundler script
./scripts/build-app.sh
```

This script:
1. Compiles the Solaris Swift target in high-optimization Release mode (`swift build -c release`).
2. Creates the target bundle hierarchy under `dist/Solaris.app/`.
3. Copies the Release binary into the bundle's execution space (`Contents/MacOS/Solaris`).
4. Generates a valid and verified `Info.plist` container mapping standard macOS execution keys.

---

## 📂 App Bundle Layout

The resulting bundle matches the standard Apple Bundle Structure:

```text
dist/
  └── Solaris.app/
        └── Contents/
              ├── MacOS/
              │     └── Solaris     # Release executable binary
              ├── Resources/        # Solaris.icns multi-resolution compiled icon
              └── Info.plist        # Application configuration metadata
```

---

## 🕹️ How to Launch the Application

Once packaged, the application is ready for local developer verification:

*   **From Terminal:**
    ```bash
    open dist/Solaris.app
    ```
*   **From Finder:**
    Navigate to `~/Documents/Projects/solaris/dist/` in Finder and double-click **`Solaris`** (the glowing orb package).

---

## ⚠️ Scope Boundaries & Technical Limitations

> [!IMPORTANT]
> **This is a Local Packaging Baseline (dev-stage).** It is meant strictly for local developer loops, local performance testing, and design verification on your macOS system.

*   **Unsigned & Unnotarized:** The bundle is generated locally without codesigning certificates (`adhoc` or developer identities) or Apple notarization verification.
*   **Not Sandboxed:** The application is packaged without `.entitlements` or Sandbox confinement. This allows the application to utilize developer-tool shell permissions to perform local diagnostics (e.g. searching processes via `pgrep` and reading logs from `~/.hermes/logs/`).
*   **Gatekeeper Restraints:** If you copy this `.app` bundle to another machine, macOS Gatekeeper will block its launch as "untrusted/broken" until attributes are stripped (via `xattr -d com.apple.quarantine`) or custom system authorizations are granted.

---

## 🎨 App Icon Pipeline

The local bundler (`scripts/build-app.sh`) implements an automated, multi-resolution app icon pipeline:
1.  **Source Asset:** Ingests the high-resolution `1024x1024` master icon located at `docs/screenshots/app-icon.png`.
2.  **PNG Resizing:** Employs the native macOS `sips` command-line graphics utility to perform high-fidelity downsamplings. It forces PNG format conversion (handling JPEG-formatted source inputs cleanly) to generate all standard Apple icon sizes (`16x16`, `32x32`, `128x128`, `256x256`, `512x512`, and their high-DPI `@2x` Retina equivalents).
3.  **ICNS Assembly:** Combines the generated PNG icon set inside a temporary directory and compiles a unified `Solaris.icns` catalog using Apple's `iconutil` command.
4.  **Resource Packaging:** Copies the compiled catalog directly into the app bundle's resource space (`dist/Solaris.app/Contents/Resources/Solaris.icns`) and maps `CFBundleIconFile` inside the `Info.plist`.

### 🔄 Finder / Dock Icon Refreshing

macOS aggressive caches Finder and Dock icons. If you previously launched Solaris under a generic default sheet, the system may delay displaying the new Solaris icon. 

To force macOS to invalidate the cache and load the new `.icns` resources:
```bash
# Touch the app bundle folder to notify macOS of resource modifications
touch dist/Solaris.app

# Open the bundle via the Launch Services daemon
open dist/Solaris.app
```
*Note: If the Finder icon is still stale, relaunching Finder (`killall Finder`) or restarting your macOS Dock (`killall Dock`) will typically force immediate visual refresh.*

---

## 🛠️ Future Release Pipelines (v0.3 and Later)

To transition Solaris from a local developer package into a clean public distribution tool, the following packaging milestones remain in the roadmap:

1.  **App Icon Asset Pipeline:** (*Completed*) Compiled multi-resolution `Solaris.icns` resources directly inside `Contents/Resources`.
2.  **Ad-Hoc / Developer Signing:** Integrate local codesigning (`codesign -s -`) inside `build-app.sh` to prevent launch verification warnings.
3.  **Sandbox Entitlements:** Build a safe, isolated `Solaris.entitlements` file mapping only required operations.
4.  **Notarization and Stapling:** Wire Apple Notarization CLI tasks (`xcrun altool` or `xcrun notarytool`) to certify builds with Apple Security systems.
5.  **Durable Distribution Formats:** Script the creation of disk images (`.dmg`) or zipped installers (`.zip`) as ready-to-run GitHub Release attachments.
6.  **CI Packaging Actions:** Automate release tagging, bundle creation, and artifact attachments using GitHub Actions workflows.
