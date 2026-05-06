<#
.SYNOPSIS
    Toggles UI themes across VS Code, Windows Terminal, Neovim, and Obsidian.

.DESCRIPTION
    This script orchestrates theme changes across multiple developer tools. 
    It modifies JSON configuration files and Lua scripts to switch between 
    'Gruvbox' (light/retro) and 'Dark' modes.
    
    It maintains state in a local file to allow easy toggling.

    NOTE: The Obsidian vault path defaults to "$env:USERPROFILE\Documents\Obsidian Vault".
    If your vault is located elsewhere, update the ObsidianVault value in the 
    CONFIGURATION block near the top of the script before running.

.PARAMETER Theme
    The target theme to switch to. Options: 'gruvbox', 'dark', 'toggle'. 
    Defaults to 'toggle'.

.EXAMPLE
    .\Toggle-WorkTheme.ps1 -Theme dark
    Sets all applications to the Dark theme.

.EXAMPLE
    .\Toggle-WorkTheme.ps1
    Toggles between the two available themes based on previous state.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("gruvbox", "dark", "toggle")]
    [string]$Theme = "toggle"
)

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
$CONFIG = @{
    StateFile        = "$env:USERPROFILE\.theme-switcher-state"
    TerminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    NeovimConfig     = "$env:LOCALAPPDATA\nvim\theme.lua"
    # Using Join-Path for safer path construction across environments
    ObsidianVault    = Join-Path $env:USERPROFILE "Documents\Obsidian Vault"
    
    Themes           = @{
        gruvbox = @{
            VSCodeColorTheme  = "Gruvbox Dark Hard"
            VSCodeIconTheme   = "gruvbox-material-icon-theme"
            TerminalScheme    = "Treehouse"
            ObsidianTheme     = "Neo"
            NeovimThemeConfig = "vim.cmd('colorscheme retrobox')"
        }
        dark    = @{
            VSCodeColorTheme  = "Bearded Theme Black & Amethyst"
            VSCodeIconTheme   = "material-icon-theme"
            TerminalScheme    = "FirefoxDev"
            ObsidianTheme     = "Neo"
            NeovimThemeConfig = "vim.cmd('colorscheme moonfly')"
        }
    }
}

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

function Get-CurrentTheme {
    if (Test-Path $CONFIG.StateFile) {
        return (Get-Content $CONFIG.StateFile -Raw).Trim()
    }
    return "gruvbox" # Default fallback
}

function Set-CurrentTheme {
    param([string]$ThemeName)
    try {
        $ThemeName | Out-File -FilePath $CONFIG.StateFile -Encoding utf8 -NoNewline -Force
        Write-Verbose "State file updated to: $ThemeName"
    }
    catch {
        Write-Warning "Could not save state file. Next toggle may be inconsistent."
    }
}

function Update-VSCodeTheme {
    param([string]$ThemeName)
    
    Write-Host "  Processing VS Code..." -NoNewline
    
    $profilesPath = "$env:APPDATA\Code\User\profiles"
    $defaultSettingsPath = "$env:APPDATA\Code\User\settings.json"
    $filesUpdated = 0

    $targetConfig = $CONFIG.Themes[$ThemeName]

    # Helper to update a single JSON file
    function Update-JsonFile {
        param($Path)
        try {
            if (Test-Path $Path) {
                $json = Get-Content $Path -Raw | ConvertFrom-Json
                $json.'workbench.colorTheme' = $targetConfig.VSCodeColorTheme
                $json.'workbench.iconTheme' = $targetConfig.VSCodeIconTheme
                $json | ConvertTo-Json -Depth 10 | Out-File $Path -Encoding utf8
                return $true
            }
        }
        catch {
            Write-Warning "    Failed to update $Path : $($_.Exception.Message)"
        }
        return $false
    }

    # 1. Update Default Settings
    if (Update-JsonFile -Path $defaultSettingsPath) { $filesUpdated++ }

    # 2. Update Profiles
    if (Test-Path $profilesPath) {
        $profileDirs = Get-ChildItem -Path $profilesPath -Directory
        foreach ($dir in $profileDirs) {
            $settingsPath = Join-Path $dir.FullName "settings.json"
            if (Update-JsonFile -Path $settingsPath) { $filesUpdated++ }
        }
    }

    if ($filesUpdated -gt 0) {
        Write-Host " Done ($filesUpdated files)." -ForegroundColor Green
        return $true
    }
    else {
        Write-Host " Skipped (No config files found)." -ForegroundColor DarkGray
        return $false
    }
}

function Update-TerminalTheme {
    param([string]$ThemeName)
    
    Write-Host "  Processing Windows Terminal..." -NoNewline

    if (-not (Test-Path $CONFIG.TerminalSettings)) {
        Write-Host " Skipped (File not found)." -ForegroundColor DarkGray
        return $false
    }

    try {
        $json = Get-Content $CONFIG.TerminalSettings -Raw | ConvertFrom-Json
        $targetScheme = $CONFIG.Themes[$ThemeName].TerminalScheme
        
        # Safely update the property
        if ($null -ne $json.profiles.defaults) {
            # Add-Member -Force will overwrite if it exists, or add if it doesn't
            $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'colorScheme' -Value $targetScheme -Force
        }

        $json | ConvertTo-Json -Depth 20 | Out-File $CONFIG.TerminalSettings -Encoding utf8
        Write-Host " Done." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " Failed." -ForegroundColor Red
        Write-Verbose "Terminal Error: $($_.Exception.Message)"
        return $false
    }
}

function Update-NeovimTheme {
    param([string]$ThemeName)
    
    Write-Host "  Processing Neovim..." -NoNewline

    try {
        $neovimConfigDir = Split-Path $CONFIG.NeovimConfig -Parent
        if (-not (Test-Path $neovimConfigDir)) {
            New-Item -ItemType Directory -Path $neovimConfigDir -Force | Out-Null
        }

        $luaContent = "-- Auto-generated by ThemeSwitcher`n$($CONFIG.Themes[$ThemeName].NeovimThemeConfig)"
        $luaContent | Out-File $CONFIG.NeovimConfig -Encoding utf8
        
        Write-Host " Done." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " Failed." -ForegroundColor Red
        return $false
    }
}

function Update-ObsidianTheme {
    param([string]$ThemeName)
    
    Write-Host "  Processing Obsidian..." -NoNewline
    
    $obsidianConfigPath = Join-Path $CONFIG.ObsidianVault ".obsidian"
    $appearancePath = Join-Path $obsidianConfigPath "appearance.json"

    if (-not (Test-Path $obsidianConfigPath)) {
        Write-Host " Skipped (Vault not found)." -ForegroundColor DarkGray
        return $false
    }

    try {
        $json = @{}
        if (Test-Path $appearancePath) {
            $json = Get-Content $appearancePath -Raw | ConvertFrom-Json
        }
        
        $json.cssTheme = $CONFIG.Themes[$ThemeName].ObsidianTheme
        $json | ConvertTo-Json -Depth 10 | Out-File $appearancePath -Encoding utf8
        
        Write-Host " Done." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " Failed." -ForegroundColor Red
        return $false
    }
}

function Start-ThemeSwitch {
    param([string]$Target)

    Write-Host "`n🎨 Switching to [$Target]..." -ForegroundColor Cyan
    Write-Host ("-" * 40) -ForegroundColor Gray

    Update-VSCodeTheme -ThemeName $Target
    Update-TerminalTheme -ThemeName $Target
    Update-NeovimTheme -ThemeName $Target
    Update-ObsidianTheme -ThemeName $Target

    Set-CurrentTheme -ThemeName $Target
    
    Write-Host ("-" * 40) -ForegroundColor Gray
    Write-Host "✨ Switch complete." -ForegroundColor Cyan
}

# -----------------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------------

$TargetTheme = $Theme

if ($Theme -eq "toggle") {
    $current = Get-CurrentTheme
    $TargetTheme = if ($current -eq "gruvbox") { "dark" } else { "gruvbox" }
}

Start-ThemeSwitch -Target $TargetTheme