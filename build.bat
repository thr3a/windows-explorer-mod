@echo off
chcp 65001 > nul

:: Ahk2Exe の場所を自動探索 (デフォルトインストール先)
set AHK2EXE=
for %%P in (
    "%ProgramFiles%\AutoHotkey\Compiler\Ahk2Exe.exe"
    "%ProgramFiles(x86)%\AutoHotkey\Compiler\Ahk2Exe.exe"
    "%LocalAppData%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"
) do (
    if exist %%P set AHK2EXE=%%P
)

if "%AHK2EXE%"=="" (
    echo [ERROR] Ahk2Exe.exe が見つかりません。AutoHotkey v2 をインストールしてください。
    echo   https://www.autohotkey.com/
    pause
    exit /b 1
)

if not exist "dist" mkdir dist

echo [BUILD] コンパイル中...
%AHK2EXE% /in "src\ExplorerUp.ahk" /out "dist\ExplorerUp.exe" /compress 2

if %errorlevel% == 0 (
    echo [OK] dist\ExplorerUp.exe を生成しました。
) else (
    echo [ERROR] コンパイル失敗。
)

pause
