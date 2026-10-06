; ==============================================================================
; Install\everything.au3 —— Everything（文件名快速搜索）
; ------------------------------------------------------------------------------
; 安装类型：Inno Setup 安装包，静默参数 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
; 安装位置：C:\Program Files\Everything（官方默认路径）
; 参数依据：docs/packages/everything.md
;
; 注意：当前 packages\ 中提供的是 x86 版本，在 64 位系统上同样可运行。
; 静默安装类，流程全部由 Installer_InstallSilent() 承担。
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
Global Const $EVERYTHING_DIR     = "everything"     ; packages 下的目录名
Global Const $EVERYTHING_SETUP   = "Everything-1.4.1.1032.x86-Setup.exe"
Global Const $EVERYTHING_SILENT  = $SILENT_INNO     ; Inno Setup 静默参数
Global Const $EVERYTHING_INSTDIR = "Everything"     ; Program Files 下的安装目录
Global Const $EVERYTHING_MAINEXE = "Everything.exe" ; 主程序，用于结果校验与 PATH 查找

Installer_Register($EVERYTHING_DIR, "Install_everything")

Func Install_everything($sInstallRoot)
    #forceref $sInstallRoot      ; 装到 Program Files，不使用自定义根目录

    ; Installer_InstallSilent(显示名, 安装包, 静默参数, 主程序名, 预期安装路径[, 超时])
    Local $bOk = Installer_InstallSilent( _
            "Everything", _
            Installer_PackagePath($EVERYTHING_DIR, $EVERYTHING_SETUP), _
            $EVERYTHING_SILENT, _
            $EVERYTHING_MAINEXE, _
            Installer_ProgramFilesPath($EVERYTHING_INSTDIR, $EVERYTHING_MAINEXE))
    If Not $bOk Then Return False

    Logger_Info("提示：Everything 依赖 NTFS 索引，首次启动需管理员权限建立索引服务")
    Return True
EndFunc
