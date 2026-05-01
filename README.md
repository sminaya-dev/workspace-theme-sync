# workspace-theme-sync

*Automated environment orchestrator for Windows developers*

![PowerShell 5.1](https://img.shields.io/badge/PowerShell-5.1-blue?logo=powershell) ![Platform](https://img.shields.io/badge/Platform-Windows%2011-lightgrey?logo=windows)

---

## About

Switching between day and night development sessions meant manually updating themes across VS Code, Windows Terminal, Neovim, and Obsidian — four separate config files, every time. `Set-WorkspaceTheme.ps1` reduces that to a single command.

The script serves as a single source of truth for your environment state: it parses each application's JSON (or Lua) configuration, updates the relevant theme keys, and persists the current state to a local dotfile so the next run knows what to toggle to.

---

## Features

- **Multi-app orchestration** — updates VS Code, Windows Terminal, Obsidian, and Neovim simultaneously
- **State persistence** — remembers your last theme via a local dotfile (`.theme-switcher-state`) so toggling always works correctly
- **Profile-aware VS Code support** — updates both the default `settings.json` and any VS Code profiles you have configured
- **Smart package detection** — gracefully skips any app whose config file isn't found, without failing the rest of the run
- **Defensive JSON parsing** — safely reads and writes config files using `ConvertFrom-Json` / `ConvertTo-Json` to avoid corruption

---

## Configuration

All paths and theme values are defined in the `$CONFIG` block near the top of the script:

```powershell
$CONFIG = @{
    StateFile        = "$env:USERPROFILE\.theme-switcher-state"
    TerminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    NeovimConfig     = "$env:LOCALAPPDATA\nvim\theme.lua"
    ObsidianVault    = Join-Path $env:USERPROFILE "Documents\Obsidian Vault"
    ...
}
```

Most paths resolve automatically via environment variables. The one value you may need to update is `ObsidianVault` — set it to the full path of your vault if it lives somewhere other than `Documents\Obsidian Vault`.

Theme values (color schemes, icon themes, etc.) can also be swapped out in the `Themes` section of the same block to match your personal preferences.

---

## Usage

```powershell
# Toggle between themes (default behavior)
.\Set-WorkspaceTheme.ps1

# Set a specific theme
.\Set-WorkspaceTheme.ps1 -Theme dark
.\Set-WorkspaceTheme.ps1 -Theme gruvbox
```

---

## Technical Highlights

**JSON config manipulation**
Rather than using regex or string replacement, the script loads each config file as a structured PowerShell object using `ConvertFrom-Json`, updates the specific property, and writes it back with `ConvertTo-Json -Depth 10`. This means the file structure and any other settings are always preserved.

**State management**
The current theme is written to a plain-text dotfile (`~/.theme-switcher-state`) after each successful switch. On the next run, `Get-CurrentTheme` reads this file to determine what to toggle to — no hardcoded assumptions about your current state.

**Graceful failure**
Each application is handled in its own function with a `Try/Catch` block. If one app's config is missing or fails to update, the script logs a warning and continues — the rest of your environment still gets updated.

---

## License

[MIT](LICENSE)