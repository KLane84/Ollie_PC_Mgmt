# Capturing the Family Safety warning dialog (one-time prep)

The automation matches the **warning** window by **regex on the title** and clicks a button whose **caption** contains text you configure (default looks for `Request` and `more`).

Because Microsoft can change wording between builds and languages, you should confirm strings **once** on Oliver’s PC while the dialog is visible.

## Steps

1. Sign in as **Oliver** (or use Fast User Switching so his session is active).
2. Temporarily set a **very short** screen-time limit in [Microsoft Family Safety](https://account.microsoft.com/family) so the **15-minute** (or similar) warning appears soon.
3. With the dialog open, open **Window Spy** (installed with AutoHotkey v2: from Start menu, or `UIA-v2` / Spy depending on your install layout). Note:
   - **Window Title** (exact string)
   - **ahk_class** (if stable)
   - **ahk_exe** (often `wpcmon.exe` or another shell binary — use as an optional extra check)
4. Copy the **title** into `scripts/config.local.ini` as `TitleRegex`. Prefer a **minimal unique substring** converted to regex, e.g. if the title is `Less than 15 minutes of screen time left`, you might use:
   - `TitleRegex=.*minute.*screen.*time.*`
5. If the primary button is not found automatically, use Window Spy’s **control list** / **UIA** view to read the **button text**, then set `RequestButtonSubstrings` (comma-separated fragments that must all appear in the same control’s text).

## If nothing happens when the dialog appears

- Confirm AutoHotkey v2 is installed and the scheduled task runs as **Oliver** with **Run only when user is logged on**.
- Run `FamilySafetyRequestMoreTime.ahk` manually from Oliver’s session with `/diag` (see [README.md](../README.md)) and watch for log lines.
