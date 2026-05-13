#Requires -Version 5.1
<#
.SYNOPSIS
  Registers a logon scheduled task to run FamilySafetyRequestMoreTime.ahk as the child's interactive user.

.NOTES
  Run in an elevated PowerShell ("Run as administrator").
  If Register-ScheduledTask fails when targeting another user, use Task Scheduler GUI (README Option A).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Principal for interactive session, e.g. DESKTOP-XYZ\Oliver")]
    [string] $InteractiveUserId,

    [Parameter(Mandatory = $true)]
    [string] $ScriptPath,

    [Parameter(Mandatory = $false)]
    [string] $AutoHotkeyPath = "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe",

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600)]
    [int] $DelaySeconds = 30,

    [Parameter(Mandatory = $false)]
    [string] $TaskName = "FamilySafetyRequestMoreTime"
)

$ErrorActionPreference = "Stop"

function Assert-FileExists([string] $Path, [string] $Label) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
}

Assert-FileExists $AutoHotkeyPath "AutoHotkey executable"
Assert-FileExists $ScriptPath "AHK script"

$scriptFull = (Resolve-Path -LiteralPath $ScriptPath).Path
$ahkFull = (Resolve-Path -LiteralPath $AutoHotkeyPath).Path

$argument = '"' + $scriptFull + '"'

$action = New-ScheduledTaskAction -Execute $ahkFull -Argument $argument
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $InteractiveUserId

# Delay after logon (ISO-8601 duration)
try {
    $trigger.Delay = "PT${DelaySeconds}S"
} catch {
    Write-Warning "Could not set trigger.Delay on this OS/PS build; set delay manually in Task Scheduler GUI."
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

$principal = New-ScheduledTaskPrincipal `
    -UserId $InteractiveUserId `
    -LogonType Interactive `
    -RunLevel Limited

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal | Out-Null
} catch {
    Write-Error "Register-ScheduledTask failed: $($_.Exception.Message)"
    Write-Warning "Use Task Scheduler GUI (README Option A) if registering for another user requires a password this cmdlet cannot supply."
    exit 1
}

Write-Host "Registered scheduled task '$TaskName' for $InteractiveUserId"
Write-Host "Action: `"$ahkFull`" $argument"
