# Solaris — Local App Bundle Packaging

This document outlines the visual structure, compilation workflows, codesigning mechanisms, and packaging procedures for compiling **Solaris** into a standalone, Finder-launchable macOS application bundle (`Solaris.app`) and ZIP artifact.

---

## 🚀 How to Build and Package Locally

To build a local release version of Solaris and package/sign it, run the unified packaging script:

```bash
# Make the bundler script executable (if not already)
chmod +x scripts/build-app.sh

# Option 1: Default (Build local unsigned app bundle)
./scripts/build-app.sh

# Option 2: Ad-hoc codesign the built bundle
./scripts/build-app.sh --sign

# Option 3: Package the bundle as a local ZIP artifact
./scripts/build-app.sh --zip

# Option 4: Build, ad-hoc codesign, and create ZIP package
./scripts/build-app.sh --sign --zip
```

### Script Execution Flow
1. **Compilation:** Compiles the Solaris Swift target in high-optimization Release mode (`swift build -c release`).
2. **Structure:** Establishes the target bundle hierarchy under `dist/Solaris.app/`.
3. **Executable:** Copies the Release binary into the bundle's execution space (`Contents/MacOS/Solaris`).
4. **App Icon:** Downsamples the high-res master icon to construct `Contents/Resources/Solaris.icns`.
5. **Metadata:** Generates and validates the target `Contents/Info.plist`.
6. **Codesigning (Optional):** Signs the bundle with an ad-hoc identity (`-`) if `--sign` is passed.
7. **Packaging (Optional):** Generates `dist/Solaris-v0.3.0-dev.zip` using `ditto` (or `zip` fallback) if `--zip` is passed.

---

## 📂 App Bundle Layout

The resulting build directory structure matches standard macOS specifications:

```text
dist/
  ├── Solaris.app/
  │     └── Contents/
  │           ├── MacOS/
  │           │     └── Solaris     # Release executable binary
  │           ├── Resources/        # Solaris.icns compiled icon bundle
  │           └── Info.plist        # Application configuration metadata
  └── Solaris-v0.3.0-dev.zip        # Consolidated local ZIP distribution artifact
```

---

## 🕹️ How to Launch the Application

Once packaged, you can launch the bundle:

*   **From Terminal:**
    ```bash
    open dist/Solaris.app
    ```
*   **From Finder:**
    Navigate to `dist/` in Finder and double-click **`Solaris`** (the glowing orb package).

---

## 🔐 Codesigning & Packaging Workflows

The v0.3 release pipeline adds two critical local packaging milestones:

### 1. Optional Ad-Hoc Codesigning (`--sign`)
Ad-hoc signing validates code integrity and prevents runtime modifications from invalidating the package.
*   **Identity:** Uses the ad-hoc signing identity `-`.
*   **Validation:** Instantly runs `codesign --verify` to guarantee the integrity of the binary structure and nested components.
*   **Execution Commands:**
    ```bash
    codesign --force --deep --sign - dist/Solaris.app
    codesign --verify --deep --strict --verbose=2 dist/Solaris.app
    codesign -dv --verbose=4 dist/Solaris.app
    ```

> [!WARNING]
> **Ad-hoc signing is for local code integrity only.**
> It is **not** Developer ID signing, it is **not** notarized by Apple, and it does **not** prepare the app for App Store or trusted production distribution. Gatekeeper assessment (`spctl --assess`) will flag the signature as rejected for system-wide trust. This is expected and acceptable for local development.

### 2. Local ZIP Artifact Workflow (`--zip`)
To package the app for local transfer, a ZIP packaging workflow creates an archive at:
```text
dist/Solaris-v0.3.0-dev.zip
```
The script uses macOS native `ditto` to preserve standard package metadata, file permissions, resource forks, and Symlinks:
```bash
ditto -c -k --keepParent dist/Solaris.app dist/Solaris-v0.3.0-dev.zip
```
If `ditto` is unavailable, the pipeline falls back gracefully to standard `zip -r`.

---

## 🛡️ Sandbox Deferral & Local Diagnostics Restrictions

macOS App Sandboxing has been **deliberately deferred** at this stage of the baseline design.

### Why Sandboxing is Deferred
Our **Local Diagnostics Mode** requires direct access to host process state and system information. In particular, it performs:
1.  **Process Tracking:** Runs `pgrep`, `ps`, and similar tools to identify active process IDs (PIDs) running local nodes.
2.  **Network Inspections:** Queries `lsof` to find which local ports are bound by the nodes.
3.  **Log File Reading:** Inspects files directly inside the hidden user path `~/.hermes/logs/` or other user-defined locations.

### Sandbox Incompatibility Details
Under Apple's App Sandbox guidelines:
*   **Process Isolation:** The application is blocked from inspecting, interacting with, or checking the status of processes outside its own sandbox container (blocking `pgrep`, `ps`, and `kill` signals).
*   **System Commands:** Executing external binaries or querying active network listeners via `lsof` is strictly forbidden.
*   **File Access:** Reading arbitrary system/user files (e.g. `~/.hermes/logs/`) is blocked unless explicitly selected by the user via an interactive `NSOpenPanel`.

### Future Design Alternatives for Sandboxing
To successfully enable App Sandboxing in future iterations without breaking diagnostics, we will investigate:
*   **Privileged Helper Tool:** Designing a launchd helper tool installed with root/system permissions (managed via `SMAppService`) to execute diagnostic checks on the host.
*   **Network-Only API Diagnostics:** Transitioning Local Diagnostics from host process scraping to querying structured HTTP or WebSocket diagnostic endpoints exposed directly by local nodes (eliminating the need to inspect host PIDs or run shell utilities).
*   **Security-Scoped Bookmarks:** Prompts users to select their local workspace directory once, storing a security-scoped bookmark to retain continuous read access to workspace logs.

---

## 🎨 App Icon Pipeline

The local bundler (`scripts/build-app.sh`) implements an automated, multi-resolution app icon pipeline:
1.  **Source Asset:** Ingests the high-resolution `1024x1024` master icon located at `docs/screenshots/app-icon.png`.
2.  **PNG Resizing:** Employs the native macOS `sips` command-line graphics utility to perform high-fidelity downsamplings. It forces PNG format conversion (handling JPEG-formatted source inputs cleanly) to generate all standard Apple icon sizes (`16x16`, `32x32`, `128x128`, `256x256`, `512x512`, and their high-DPI `@2x` Retina equivalents).
3.  **ICNS Assembly:** Combines the generated PNG icon set inside a temporary directory and compiles a unified `Solaris.icns` catalog using Apple's `iconutil` command.
4.  **Resource Packaging:** Copies the compiled catalog directly into the app bundle's resource space (`dist/Solaris.app/Contents/Resources/Solaris.icns`) and maps `CFBundleIconFile` inside the `Info.plist`.

### 🔄 Finder / Dock Icon Refreshing

macOS aggressively caches Finder and Dock icons. If you previously launched Solaris under a generic default sheet, the system may delay displaying the new Solaris icon. 

To force macOS to invalidate the cache and load the new `.icns` resources:
```bash
# Touch the app bundle folder to notify macOS of resource modifications
touch dist/Solaris.app

# Open the bundle via the Launch Services daemon
open dist/Solaris.app
```
*Note: If the Finder icon is still stale, relaunching Finder (`killall Finder`) or restarting your macOS Dock (`killall Dock`) will typically force an immediate visual refresh.*


---

## ⚙️ GitHub Actions CI Pipeline

Solaris includes an automated continuous integration pipeline defined at `.github/workflows/ci.yml`. This pipeline runs on a macOS runner (`macos-latest`) to validate each push and pull request targeting the `main` branch.

### Pipeline Stages
1. **Build & Verify (`build` job):**
   * **Compiler Verification:** Compiles the Swift codebase (`swift build`) to ensure there are no compilation syntax errors or warnings.
   * **Smoke Test Semantics:** Executes the non-interactive API smoke test runner (`./scripts/smoke-test.sh`).
   * **Secret Scanner Check:** Executes the project-wide repository scan (`./scripts/secret-scan.sh`) to detect committed high-risk API keys, raw paths, or local files.
2. **Package & Codesign (`package` job):**
   * **Packaging Automation:** Runs the unified app builder script with full parameters (`./scripts/build-app.sh --sign --zip`).
   * **Package Validation:** Verifies file existence (`Solaris.app`, executable bin, `.icns` files), runs the `plutil` plist linter, and runs strict `codesign --verify` on the generated package.
   * **CI Release Artifacts:** Packages the release ZIP bundle and uploads it to GitHub's Actions storage as a downloadable development run attachment (`Solaris-v0.3.0-dev`).

> [!IMPORTANT]
> **CI Artifact Purpose & Limitations:**
> * **Testing Only:** Zipped packages generated on the CI runner use the standard ad-hoc signature (`-`) for structural integrity tests only.
> * **Not Production Ready:** These development artifacts are **not notarized** or signed using an Apple Developer ID. Downloading and running them on external macOS machines will be blocked by Gatekeeper unless manual trust controls are overridden.

---

## 🛠️ Future Release Pipelines (v0.4 and Later)

To transition Solaris from a local developer package into a clean public distribution tool, the following packaging milestones remain in the roadmap:

1.  **App Icon Asset Pipeline:** (*Completed*) Compiled multi-resolution `Solaris.icns` resources directly inside `Contents/Resources`.
2.  **Ad-Hoc Signing & Local packaging:** (*Completed*) Ad-hoc code integrity signing (`--sign`) and native ditto ZIP creation (`--zip`).
3.  **Sandbox Entitlements:** Build a safe, isolated `Solaris.entitlements` file mapping only required operations.
4.  **Notarization and Stapling:** Wire Apple Notarization CLI tasks (`xcrun altool` or `xcrun notarytool`) to certify builds with Apple Security systems.
5.  **Durable Distribution Formats:** Script the creation of disk images (`.dmg`) as ready-to-run GitHub Release attachments.
6.  **CI Packaging Actions:** Automate release tagging, bundle creation, and artifact attachments using GitHub Actions workflows.
