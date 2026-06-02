# Security Policy

## ⚠️ Safe Credentials Policy
**Never commit credentials, API keys, or private tokens directly into the codebase.**
This project is open-source and git-tracked. If you are developing features or linking live adapters, ensure no sensitive data is added to your local staging areas.

---

## 🔒 Recommended Credential Management
*   **System Keychain:** For future credential storage, utilize the macOS native Keychain services API (`Security` framework) or safe encrypted local stores instead of plain text environment files.
*   **Decoupled Environment Configs:** Local servers should ingest API keys via untracked `.env` configurations standard to the local daemon home folder (`~/.hermes/.env`), never inside the companion app package itself.

---

## 🔌 Configurable Localhost & Port
*   The connection endpoint target is completely customizable inside your in-app **Settings View**. 
*   It defaults to the verified standard loopback address of **`http://127.0.0.1:9119`** served dynamically by the local daemon process.
*   Binding to public addresses is dangerous and exposes credentials on the network. Always run loops locally.

## 📂 Diagnostics Mode & Log Safety
This app includes a **Local Diagnostics Mode** to scan:
*   Local background processes using safe fixed executable paths.
*   System log files under `~/.hermes/logs/agent.log` and `~/.hermes/logs/gateway.log`.

**Important Log Warnings:**
*   These local log files contain prompt histories, execution states, and diagnostic outputs from your local daemon.
*   **Never copy, stage, or commit real system log files, process dumps, PIDs, or active traces into public git repositories.**
*   Always ensure your logs are sanitized of personal API keys or directory details before sharing diagnostic reports.

---

## ☄️ Safe Public Demonstrations
The **Developer Mock Data Mode** is completely isolated inside local SwiftUI actors:
*   Mock mode generates 100% simulated telemetry, health statistics, and logs locally.
*   It operates entirely offline and makes **zero network requests**.
*   **Always engage Mock Data Mode when recording public demos or presenting system designs.**
