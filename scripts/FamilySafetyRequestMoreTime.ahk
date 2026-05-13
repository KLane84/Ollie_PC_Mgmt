#Requires AutoHotkey v2.0
#SingleInstance Force

; -----------------------------------------------------------------------------
; Family Safety — detect time-warning dialog, click "Request more time", and
; optionally notify Discord. Intended to run in the child's interactive session.
; See ..\README.md and ..\docs\DIALOG-CAPTURE.md
; -----------------------------------------------------------------------------
; Args: /diag  — verbose logging to %TEMP%\FamilySafetyRequestMoreTime.log
;       /dry   — detect only; do not click (same as DryRun=1 in config)
; -----------------------------------------------------------------------------

global g_cfgPath := A_ScriptDir "\config.local.ini"
global g_logPath := ""
global g_dryRun := false
global g_diag := false

global g_titleRegex := ".*\d+\s+minute.*"
global g_windowClass := ""
global g_exeName := ""
global g_reqParts := ["Request", "more"]
global g_confirmParts := []
global g_debounceMs := 90_000
global g_discordWebhook := ""
global g_lastHandledTick := 0

ReadArgs()
LoadConfig()
InitLog()
LogWrite("Start FamilySafetyRequestMoreTime (dry=" g_dryRun ", diag=" g_diag ")")

SetTimer Poll, 500
return

ReadArgs() {
    global g_diag, g_dryRun
    for a in A_Args {
        al := StrLower(Trim(a))
        if (al = "/diag")
            g_diag := true
        if (al = "/dry")
            g_dryRun := true
    }
}

Cfg(key, default) {
    global g_cfgPath
    if !FileExist(g_cfgPath)
        return default
    return IniRead(g_cfgPath, "FamilySafety", key, default)
}

LoadConfig() {
    global g_titleRegex, g_windowClass, g_exeName, g_reqParts, g_confirmParts
    global g_debounceMs, g_discordWebhook, g_dryRun, g_logPath

    g_titleRegex := Cfg("TitleRegex", g_titleRegex)
    g_windowClass := Trim(Cfg("WindowClass", ""))
    g_exeName := Trim(Cfg("ExeName", ""))

    subs := Cfg("RequestButtonSubstrings", "Request,more")
    g_reqParts := SplitParts(subs)

    csubs := Trim(Cfg("ConfirmButtonSubstrings", ""))
    g_confirmParts := csubs = "" ? [] : SplitParts(csubs)

    g_debounceMs := Integer(Cfg("DebounceSeconds", "90")) * 1000
    if (g_debounceMs < 5000)
        g_debounceMs := 5000

    g_discordWebhook := Trim(Cfg("DiscordWebhook", ""))
    if (g_discordWebhook = "")
        g_discordWebhook := Trim(EnvGet("FAMILY_SAFETY_DISCORD_WEBHOOK"))

    if Integer(Cfg("DryRun", "0"))
        g_dryRun := true

    g_logPath := Trim(Cfg("LogPath", ""))
    if (g_logPath = "")
        g_logPath := A_Temp "\FamilySafetyRequestMoreTime.log"
}

SplitParts(csv) {
    out := []
    for p in StrSplit(csv, ",") {
        t := Trim(p)
        if (t != "")
            out.Push(t)
    }
    if !out.Length
        out.Push("Request", "more")
    return out
}

InitLog() {
    global g_logPath
    dir := RegExReplace(g_logPath, "\\[^\\]+$", "")
    if (dir != "" && dir != g_logPath)
        try DirCreate(dir)
}

LogWrite(msg) {
    global g_logPath, g_diag
    line := FormatTime(, "yyyy-MM-dd HH:mm:ss") " " msg "`n"
    try FileAppend(line, g_logPath, "UTF-8")
    if g_diag
        OutputDebug(line)
}

Poll() {
    global g_titleRegex, g_windowClass, g_exeName, g_reqParts, g_confirmParts
    global g_debounceMs, g_discordWebhook, g_dryRun, g_lastHandledTick

    prevMode := A_TitleMatchMode
    prevSpeed := A_TitleMatchModeSpeed
    SetTitleMatchMode "RegEx", "Slow"
    hwnd := WinExist(g_titleRegex)
    SetTitleMatchMode prevMode, prevSpeed

    if !hwnd
        return

    winTitle := WinGetTitle("ahk_id " hwnd)
    winClass := WinGetClass("ahk_id " hwnd)
    exe := WinGetProcessName("ahk_id " hwnd)

    if (g_windowClass != "" && StrCompare(winClass, g_windowClass, false) != 0) {
        if g_diag
            LogWrite("Skip hwnd=" hwnd " class mismatch got=" winClass)
        return
    }
    if (g_exeName != "" && !InStr(StrLower(exe), StrLower(g_exeName))) {
        if g_diag
            LogWrite("Skip hwnd=" hwnd " exe mismatch got=" exe)
        return
    }

    if (A_TickCount - g_lastHandledTick < g_debounceMs) {
        if g_diag
            LogWrite("Debounce skip hwnd=" hwnd " title=" winTitle)
        return
    }

    ; Claim debounce window for this match so we do not hammer ControlClick every 500ms.
    g_lastHandledTick := A_TickCount

    LogWrite("MATCH hwnd=" hwnd " title=" winTitle " class=" winClass " exe=" exe)

    if g_dryRun
        return

    try WinActivate("ahk_id " hwnd)
    catch as e
        LogWrite("WARN WinActivate: " e.Message)

    Sleep 150

    if !ClickMatchingButton(hwnd, g_reqParts, "request") {
        LogWrite("WARN No request button for hwnd=" hwnd)
        return
    }

    Sleep 400

    if g_confirmParts.Length {
        fg := WinActive("A")
        target := (fg && fg != hwnd) ? fg : hwnd
        if ClickMatchingButton(target, g_confirmParts, "confirm")
            LogWrite("Clicked confirm control on hwnd=" target)
    }

    msg := "Family Safety: handled time warning. Requested more time. title=" winTitle
    NotifyDiscord(msg)
    LogWrite("DONE " msg)
}

MatchesParts(text, parts) {
    h := StrLower(text)
    for p in parts {
        if !InStr(h, StrLower(p))
            return false
    }
    return true
}

ClickMatchingButton(hwnd, parts, tag) {
    id := "ahk_id " hwnd
    controls := WinGetControls(id)
    if !controls {
        LogWrite("WARN WinGetControls empty tag=" tag)
        return false
    }

    loop parse, controls, "`n", "`r" {
        ctl := A_LoopField
        if (ctl = "")
            continue
        try {
            txt := ControlGetText(ctl, id)
        } catch {
            continue
        }
        if !MatchesParts(txt, parts)
            continue

        try {
            ControlClick ctl, id
        } catch as e {
            LogWrite("WARN ControlClick " ctl " tag=" tag " err=" e.Message)
            return false
        }
        LogWrite("CLICK " tag " ctl=" ctl " text=" txt)
        return true
    }
    return false
}

NotifyDiscord(message) {
    global g_discordWebhook
    if (g_discordWebhook = "")
        return

    body := '{"content":"' JsonEscape(message) '"}'
    tmp := A_Temp "\FamilySafetyRequestMoreTime_discord.json"
    try FileDelete tmp
    try {
        f := FileOpen(tmp, "w", "UTF-8")
        f.Write(body)
        f.Close()
    } catch as e {
        LogWrite("WARN Discord body write: " e.Message)
        return
    }

    ; Prefer curl (present on current Windows); hide window.
    curlExe := A_WinDir "\System32\curl.exe"
    if !FileExist(curlExe) {
        LogWrite("WARN curl not found at " curlExe)
        return
    }
    ; Quote paths so spaces in %TEMP% / usernames do not break curl.
    cmd := '"' curlExe '" -sS -X POST -H "Content-Type: application/json" --data-binary @' Chr(34) tmp Chr(34) ' "' g_discordWebhook '"'
    try {
        shell := ComObject("WScript.Shell")
        ex := shell.Exec(cmd)
        out := ex.StdOut.ReadAll()
        err := ex.StdErr.ReadAll()
        code := ex.ExitCode
        if (code != 0)
            LogWrite("WARN Discord curl exit=" code " err=" err " out=" out)
        else if g_diag
            LogWrite("Discord ok out=" out)
    } catch as e {
        LogWrite("WARN Discord curl: " e.Message)
    }
}

JsonEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    return s
}
