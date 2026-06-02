# AGENTS.md

Guidance for AI agents working in this repository.

## Project overview

**ToastPRPScript** is a single-file PowerShell automation script (`ToastPRP.ps1`) for Fallout 4 modding. It orchestrates the Creation Kit, FO4Edit/xEdit, and BSArchive to generate Precombine and Previs data for mod `.esp` plugins.

There is no application server, package manager manifest, Docker setup, or in-repo test suite.

## Cursor Cloud specific instructions

### Platform constraints

- **Production runtime is Windows-only.** The script depends on:
  - Windows registry (`HKLM:\Software\Wow6432Node\Bethesda Softworks\Fallout4`)
  - `System.Windows.Forms` (file dialogs)
  - Win32 GUI automation (`SendKeys` / `user32.dll`)
  - Fallout 4, Creation Kit, FO4Edit/xEdit, and Mod Organizer 2 on the host machine
- **Linux cloud VMs** can validate and edit the script but **cannot run full end-to-end** without a Windows + Fallout 4 toolchain.

### Development tooling (Linux VM)

| Tool | Purpose |
|------|---------|
| `pwsh` (PowerShell 7+) | Parse, lint, and smoke-test script logic |
| `PSScriptAnalyzer` module | Static analysis (`Invoke-ScriptAnalyzer`) |

### Common commands

From repo root (`/workspace`):

```bash
# Syntax check
pwsh -NoProfile -Command '$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("/workspace/ToastPRP.ps1", [ref]$null, [ref]$e); if($e){$e; exit 1} else {"OK"}'

# Lint (errors only)
pwsh -NoProfile -Command 'Import-Module PSScriptAnalyzer; Invoke-ScriptAnalyzer -Path /workspace/ToastPRP.ps1 -Severity Error'

# Lint (include warnings)
pwsh -NoProfile -Command 'Import-Module PSScriptAnalyzer; Invoke-ScriptAnalyzer -Path /workspace/ToastPRP.ps1 -Severity Error, Warning'

# Smoke test (logic validation without Fallout 4)
pwsh -NoProfile -File scripts/dev-smoke-test.ps1
```

`scripts/dev-smoke-test.ps1` validates parsing, function inventory, file-wait polling, JSON config round-trip, and zero PSScriptAnalyzer errors without requiring Fallout 4.

### Running the real script

On **Windows** with Fallout 4 installed:

1. Copy `ToastPRP.ps1` into the Fallout 4 install directory (the script can also move itself there).
2. Ensure PJM prerequisites are complete and the target `.esp` exists.
3. Run from PowerShell in that directory:

```powershell
.\ToastPRP.ps1
```

Useful flags: `-Debug`, `-toast` (skip confirmations), `-OneOff <FunctionName>`.

### Gotchas

- `Add-Type -AssemblyName System.Windows.Forms` fails on Linux; expect early failure if you run the full script on non-Windows hosts.
- PSScriptAnalyzer reports many `PSAvoidUsingWriteHost` warnings; these are stylistic and expected for this interactive CLI script.
- No CI, pre-commit hooks, or automated tests are defined in the repo.
