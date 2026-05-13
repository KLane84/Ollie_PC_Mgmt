# Family Safety — request-more-time assist

This repo contains an **AutoHotkey v2** script that runs in the **child’s Windows session** (for example Oliver). It periodically looks for the **Microsoft Family Safety screen-time warning** dialog, clicks **Request more time** (configurable), and optionally posts to a **Discord incoming webhook** so you get a parallel ping when Microsoft sends the approval request.

This does **not** replace Family Safety enforcement. It only automates the warning dialog when it appears.

## Prerequisites

1. Install **[AutoHotkey v2](https://www.autohotkey.com/)** on the same PC (64-bit `AutoHotkey64.exe` is typical).
2. Copy [`scripts/config.example.ini`](scripts/config.example.ini) to `scripts/config.local.ini` and tune `TitleRegex` / button substrings after you capture the real dialog (see [`docs/DIALOG-CAPTURE.md`](docs/DIALOG-CAPTURE.md)).
3. Optional: set `DiscordWebhook=` in `config.local.ini`, **or** set a user environment variable `FAMILY_SAFETY_DISCORD_WEBHOOK` on the child account (not recommended for shared secrets on school profiles—prefer `config.local.ini` with NTFS permissions if you lock it down later).

## Scheduled task (run as the child, at logon)

The script **must** run under **Oliver’s account** with **Run only when user is logged on**, or it cannot drive his desktop UI.

### Option A — Task Scheduler (recommended)

1. Sign in to Windows as an **administrator**.
2. Open **Task Scheduler** → **Create Task…** (not Basic Task).
3. **General**
   - Name: `FamilySafetyRequestMoreTime`
   - Select **Run only when user is logged on**.
   - User: click **Change User or Group…** and pick **Oliver’s** Windows user (you may be prompted for Oliver’s password once).
   - Uncheck **Run with highest privileges** unless you discover the dialog cannot be clicked otherwise.
4. **Triggers** → **New…** → **At log on** → Specific user: **Oliver** → Advanced settings: enable **Delay task for:** `30 seconds` (reduces race with Explorer on slow logons).
5. **Actions** → **New…**
   - Program/script: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` (adjust if your install path differs).
   - Add arguments: `"C:\Code\FamilySafety\scripts\FamilySafetyRequestMoreTime.ahk"` (use the real full path to this repo’s script).
6. **Conditions** / **Settings**: allow start on AC and battery if this is a laptop; disable “Stop the task if it runs longer than” if present for long sessions.
7. OK, enter credentials if prompted.

### Option B — PowerShell helper (administrator)

From an elevated PowerShell session, run [`scripts/Install-ScheduledTask.ps1`](scripts/Install-ScheduledTask.ps1) with **explicit** `InteractiveUserId` (examples: `DESKTOP-AB12\Oliver`, `AzureAD\first.last@domain`):

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\Code\FamilySafety\scripts
.\Install-ScheduledTask.ps1 `
  -InteractiveUserId 'YOUR-PC\Oliver' `
  -ScriptPath 'C:\Code\FamilySafety\scripts\FamilySafetyRequestMoreTime.ahk' `
  -AutoHotkeyPath 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' `
  -DelaySeconds 30
```

If `Register-ScheduledTask` fails for another user, use **Option A** (GUI) so Windows can capture Oliver’s password for that task principal.

## Manual test (as Oliver)

1. Sign in as **Oliver**.
2. Double-click `FamilySafetyRequestMoreTime.ahk` (or run from Explorer). Confirm a green AutoHotkey icon appears in the tray (if enabled).
3. Run once with logging only:

   ```text
   AutoHotkey64.exe "...\FamilySafetyRequestMoreTime.ahk" /diag /dry
   ```

4. Trigger a real warning (short screen-time limit in Microsoft Family). Watch `%TEMP%\FamilySafetyRequestMoreTime.log` for `MATCH` lines. Adjust `TitleRegex` in `config.local.ini` until matches are correct.
5. Remove `/dry` and confirm the dialog is handled and you receive the **Family Safety** approval request plus optional Discord message.

## Validation checklist (complete after first real warning)

- [ ] Task runs only when **Oliver** is logged on (not your admin-only sessions).
- [ ] Log shows `MATCH` with the expected **title / class / exe**.
- [ ] `CLICK request` appears and the dialog closes without leaving the game in a bad state.
- [ ] Microsoft Family shows a **more time** request for you to approve or deny.
- [ ] If Discord is enabled, a message arrives when the automation runs.

## Troubleshooting

- **No `MATCH`:** tighten or loosen `TitleRegex`; capture the exact title (see [`docs/DIALOG-CAPTURE.md`](docs/DIALOG-CAPTURE.md)). Add `ExeName=wpcmon.exe` only if you have verified the dialog’s process name.
- **MATCH but no click:** button text may not be exposed to Win32 `ControlGetText`. Update `RequestButtonSubstrings` to unique fragments of the visible label, or ask for a follow-up change (UI Automation) if controls are empty.
- **“Request more time” fails in cloud:** some Windows 11 builds have reported Family bugs; automation cannot fix server-side errors.

## Security note

`config.local.ini` may contain a Discord webhook URL. It is listed in [`.gitignore`](.gitignore). Do not commit secrets.
