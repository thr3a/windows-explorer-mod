#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode "Mouse", "Screen"

global g_ClickState := {
    hwnd: 0,
    tick: 0,
    x: 0,
    y: 0,
}

#HotIf IsExplorerWindowActive()
*~LButton Up::HandleExplorerClick()
#HotIf

IsExplorerWindowActive() {
    return WinActive("ahk_class CabinetWClass ahk_exe explorer.exe")
}

HandleExplorerClick() {
    global g_ClickState

    explorerHwnd := WinActive("A")
    if !explorerHwnd {
        ResetClickState()
        return
    }

    if HasModifierKeyDown() {
        ResetClickState()
        return
    }

    MouseGetPos &mouseX, &mouseY

    if !IsDoubleClick(explorerHwnd, mouseX, mouseY) {
        RememberClick(explorerHwnd, mouseX, mouseY)
        return
    }

    ResetClickState()

    if !IsExplorerWhitespace(explorerHwnd, mouseX, mouseY)
        return

    Send "!{Up}"
}

HasModifierKeyDown() {
    return GetKeyState("Ctrl", "P")
        || GetKeyState("Shift", "P")
        || GetKeyState("Alt", "P")
        || GetKeyState("LWin", "P")
        || GetKeyState("RWin", "P")
}

IsDoubleClick(explorerHwnd, mouseX, mouseY) {
    global g_ClickState
    static SM_CXDOUBLECLK := 36
    static SM_CYDOUBLECLK := 37

    if !g_ClickState.tick
        return false

    if g_ClickState.hwnd != explorerHwnd
        return false

    if (A_TickCount - g_ClickState.tick) > DllCall("GetDoubleClickTime", "UInt")
        return false

    return Abs(mouseX - g_ClickState.x) <= DllCall("GetSystemMetrics", "Int", SM_CXDOUBLECLK, "Int")
        && Abs(mouseY - g_ClickState.y) <= DllCall("GetSystemMetrics", "Int", SM_CYDOUBLECLK, "Int")
}

RememberClick(explorerHwnd, mouseX, mouseY) {
    global g_ClickState

    g_ClickState.hwnd := explorerHwnd
    g_ClickState.tick := A_TickCount
    g_ClickState.x := mouseX
    g_ClickState.y := mouseY
}

ResetClickState() {
    global g_ClickState

    g_ClickState.hwnd := 0
    g_ClickState.tick := 0
    g_ClickState.x := 0
    g_ClickState.y := 0
}

IsExplorerWhitespace(explorerHwnd, mouseX, mouseY) {
    static ROLE_SYSTEM_LIST := 0x21
    static ROLE_SYSTEM_WHITESPACE := 0x3B

    hoveredHwnd := DllCall("user32\WindowFromPoint", "Int64", MakePoint(mouseX, mouseY), "Ptr")
    if !hoveredHwnd
        return false

    rootHwnd := DllCall("GetAncestor", "Ptr", hoveredHwnd, "UInt", 2, "Ptr")
    if rootHwnd != explorerHwnd
        return false

    childId := 0
    accObj := AccObjectFromPoint(&childId, mouseX, mouseY)
    if !accObj
        return false

    try role := accObj.accRole[childId]
    catch
        return false

    return role = ROLE_SYSTEM_LIST || role = ROLE_SYSTEM_WHITESPACE
}

AccObjectFromPoint(&childId, mouseX, mouseY) {
    static VT_DISPATCH := 9
    static F_OWNVALUE := 1
    static childBufferSize := 8 + (2 * A_PtrSize)
    static _ := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")

    childId := 0
    varChild := Buffer(childBufferSize, 0)

    if DllCall("oleacc\AccessibleObjectFromPoint", "Int64", MakePoint(mouseX, mouseY), "Ptr*", &pAcc := 0, "Ptr", varChild.Ptr) != 0
        return 0

    if !pAcc
        return 0

    childId := NumGet(varChild, 8, "UInt")
    return ComValue(VT_DISPATCH, pAcc, F_OWNVALUE)
}

MakePoint(x, y) {
    return (x & 0xFFFFFFFF) | ((y & 0xFFFFFFFF) << 32)
}
