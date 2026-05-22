#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode "Mouse", "Screen"

global g_ClickState := {
    hwnd: 0,
    tick: 0,
    x: 0,
    y: 0,
    whitespace: false,
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

    ; カーソル直下が余白かどうかは、ナビゲーションが起きていない「今この瞬間」に判定する。
    ; フォルダをダブルクリックして開いた直後だと、2 回目の Up 時点ではすでに移動先の
    ; 余白を指してしまうため、毎回のクリックでこの値を捕まえておく。
    isWhitespaceNow := IsExplorerWhitespace(explorerHwnd, mouseX, mouseY)

    if !IsDoubleClick(explorerHwnd, mouseX, mouseY) {
        RememberClick(explorerHwnd, mouseX, mouseY, isWhitespaceNow)
        return
    }

    wasWhitespace := g_ClickState.whitespace
    ResetClickState()

    ; 1 回目と 2 回目の両方が余白上のクリックだったときだけ上の階層へ移動する。
    ; 1 回目で項目を掴んでいたら、ナビゲーション後に 2 回目が余白に当たっても弾く。
    if !(wasWhitespace && isWhitespaceNow)
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

RememberClick(explorerHwnd, mouseX, mouseY, isWhitespace) {
    global g_ClickState

    g_ClickState.hwnd := explorerHwnd
    g_ClickState.tick := A_TickCount
    g_ClickState.x := mouseX
    g_ClickState.y := mouseY
    g_ClickState.whitespace := isWhitespace
}

ResetClickState() {
    global g_ClickState

    g_ClickState.hwnd := 0
    g_ClickState.tick := 0
    g_ClickState.x := 0
    g_ClickState.y := 0
    g_ClickState.whitespace := false
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

    if role = ROLE_SYSTEM_WHITESPACE
        return true

    ; ファイルペイン本体は ROLE_SYSTEM_LIST を返す。コンテナそのもの (childId = 0)
    ; に当たっているときだけを「余白」とみなし、リスト内の項目は除外する。
    return role = ROLE_SYSTEM_LIST && childId = 0
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
