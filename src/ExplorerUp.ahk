#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== タスクトレイ設定 =====
A_IconTip := "ExplorerUp - 空白ダブルクリックで親フォルダへ"
TraySetIcon(A_WinDir "\system32\imageres.dll", 109)

A_TrayMenu.Delete()
A_TrayMenu.Add("ExplorerUp v0.1", (*) => 0)
A_TrayMenu.Disable("ExplorerUp v0.1")
A_TrayMenu.Add()
A_TrayMenu.Add("終了(&X)", (*) => ExitApp())

; ===== ダブルクリック検出 =====
; ~ プレフィックス = クリック自体はそのまま Explorer へ通す
~LButton:: {
    ; 直前のホットキーが同じ LButton かつ 400ms 以内 → ダブルクリック
    if (A_PriorHotkey != "~LButton" || A_TimeSincePriorHotkey > 400)
        return

    ; Explorer ウィンドウ (CabinetWClass) のみ対象
    if !WinActive("ahk_class CabinetWClass")
        return

    ; マウス座標取得 (スクリーン絶対座標)
    CoordMode "Mouse", "Screen"
    MouseGetPos &mX, &mY

    ; IAccessible でマウス下の UI 要素ロールを取得
    role := GetAccRole(mX, mY)

    ; ROLE_SYSTEM_LIST = 33 (0x21)
    ;   → ファイルリストの空白部分（アイテムが乗っていない場所）
    ; ROLE_SYSTEM_LISTITEM = 34 (0x22)
    ;   → ファイル・フォルダアイテム上 → 何もしない
    if (role = 33)
        Send "!{Up}"  ; Alt+↑ で親フォルダへ移動
}

; ===== IAccessible ヘルパー関数 =====
; Win32 API AccessibleObjectFromPoint で座標上の要素ロールを返す
GetAccRole(x, y) {
    try {
        varChild := Buffer(16, 0)  ; VARIANT 構造体 (16 bytes)
        pAcc := 0

        ; POINT 構造体を int64 に詰める: x = 下位 32bit, y = 上位 32bit
        result := DllCall("oleacc\AccessibleObjectFromPoint"
            , "int64", x | (y << 32)
            , "ptr*", &pAcc
            , "ptr", varChild
            , "int")

        if (result != 0 || !pAcc)
            return 0

        acc := ComObject(9, pAcc, 1)

        ; VARIANT の vt (offset 0) が VT_I4 (3) なら childId を読む
        vt := NumGet(varChild, 0, "ushort")
        childId := (vt = 3) ? NumGet(varChild, 8, "int") : 0

        return acc.accRole(childId)
    } catch {
        return 0
    }
}
