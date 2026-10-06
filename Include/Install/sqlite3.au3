; ==============================================================================
; Install\sqlite3.au3 —— SQLite3 命令行工具包
; ------------------------------------------------------------------------------
; 安装类型：绿色解压（zip），无需运行安装程序
; 安装位置：<安装根目录>\SQLite3   （即默认的 %LOCALAPPDATA%\BJ\auto-install\SQLite3）
; 参数依据：docs/packages/sqlite3.md
;
; 本文件同时作为「绿色解压类」软件的接入范例：
;   · 解压流程（已安装检测 -> 解压 -> 结果校验 -> 日志）由 Installer_InstallGreen() 承担；
;   · 这类软件会真正用到 $sInstallRoot，是它存在的主要意义；
;   · 解压后若需全局调用命令，再用 Installer_AddToSystemPath() 写入 PATH。
; ==============================================================================

#include-once

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"
#include "..\Installer.au3"

; ------------------------------------------------------------------------------
; 本软件相关常量
; ------------------------------------------------------------------------------
Global Const $SQLITE_DIR     = "SQLite3"        ; packages 下的目录名
Global Const $SQLITE_ZIP     = "sqlite-tools-win-x64-3530400.zip"
Global Const $SQLITE_SUBDIR  = "SQLite3"        ; 安装根目录下的子目录名
Global Const $SQLITE_MAINEXE = "sqlite3.exe"    ; 主程序，用于结果校验与 PATH 查找

; 是否把解压目录写入系统 PATH（需管理员权限）。改为 False 则只解压、不动环境变量。
Global Const $SQLITE_ADD_PATH = True

Installer_Register($SQLITE_DIR, "Install_sqlite3")

Func Install_sqlite3($sInstallRoot)
    Local $sDest = Common_JoinPath($sInstallRoot, $SQLITE_SUBDIR)

    ; Installer_InstallGreen(显示名, 压缩包, 解压目标目录, 主程序名)
    ; 成功返回主程序完整路径，失败返回空串
    Local $sFound = Installer_InstallGreen( _
            "SQLite3", _
            Installer_PackagePath($SQLITE_DIR, $SQLITE_ZIP), _
            $sDest, _
            $SQLITE_MAINEXE)
    If $sFound = "" Then Return False

    ; ---- 环境变量：让 sqlite3 命令可全局调用 ----
    If Not $SQLITE_ADD_PATH Then
        Logger_Info("已跳过 PATH 配置（如需全局调用 sqlite3，请手动把该目录加入 PATH）")
        Return True
    EndIf

    If FileExists(Common_JoinPath($sDest, $SQLITE_MAINEXE)) Then
        ; 本次解压到了安装根目录，确保它在 PATH 中
        If Not Installer_AddToSystemPath($sDest) Then
            Logger_Warn("系统 PATH 写入失败，可手动把该目录加入 PATH：" & $sDest)
        EndIf
    Else
        Logger_Info("sqlite3 已可在系统 PATH 中调用，无需调整 PATH")
    EndIf

    Return True
EndFunc
