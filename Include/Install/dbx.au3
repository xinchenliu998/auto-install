; ==============================================================================
; Install\dbx.au3 —— DBX 数据库客户端
; ------------------------------------------------------------------------------
; 安装类型：NSIS 静默安装（Tauri 打包），静默参数 /S
; 安装位置：%LOCALAPPDATA%\DBX
;           安装包 PE 清单为 asInvoker，即 Tauri 的「当前用户」安装模式，
;           装到用户目录而非 Program Files，不需要管理员权限。
; 参数依据：docs/packages/dbx.md
;
; 静默安装类，流程全部由 Installer_InstallSilent() 承担。
; 注意：安装包内附带 WebView2 离线运行时，体积大、耗时较长，故放宽超时。
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
Global Const $DBX_DIR     = "DBX"                               ; packages 下的目录名
Global Const $DBX_SETUP   = "DBX_0.6.34_x64-offline-setup.exe"  ; 安装包文件名
Global Const $DBX_SILENT  = $SILENT_NSIS                        ; NSIS 静默参数
Global Const $DBX_TIMEOUT = $TIMEOUT_INSTALL_LONG               ; 体积大且附带装 WebView2，放宽超时
Global Const $DBX_MAINEXE = "dbx.exe"                           ; 主程序，用于结果校验与 PATH 查找

Installer_Register($DBX_DIR, "Install_dbx")

Func Install_dbx($sInstallRoot)
    #forceref $sInstallRoot      ; 装到 DBX 自己的默认目录，不使用自定义根目录

    ; DBX 是 Tauri 应用，默认按「当前用户」装到 %LOCALAPPDATA%\DBX；
    ; 若打包配置改成 perMachine，则落在 Program Files，故两个候选都给出。
    Local $aCandidate[2]
    $aCandidate[0] = Common_JoinPath(@LocalAppDataDir, "DBX")
    $aCandidate[1] = Common_JoinPath(@ProgramFilesDir, "DBX")

    ; Installer_InstallSilent(显示名, 安装包, 静默参数, 主程序名, 预期安装路径[, 超时])
    Return Installer_InstallSilent( _
            "DBX", _
            Installer_PackagePath($DBX_DIR, $DBX_SETUP), _
            $DBX_SILENT, _
            $DBX_MAINEXE, _
            $aCandidate, _
            $DBX_TIMEOUT)
EndFunc
