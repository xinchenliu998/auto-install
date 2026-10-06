; ==============================================================================
; Install\sublime-text.au3 —— Sublime Text
; ------------------------------------------------------------------------------
; 安装类型：Inno Setup 安装包，静默参数 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
; 安装位置：C:\Program Files\Sublime Text（官方默认路径）
; 参数依据：docs/packages/sublime-text.md
;
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
Global Const $SUBLIME_DIR     = "Sublime Text"      ; packages 下的目录名（含空格）
Global Const $SUBLIME_SETUP   = "sublime_text_build_4215_x64_setup.exe"
Global Const $SUBLIME_SILENT  = $SILENT_INNO        ; Inno Setup 静默参数
Global Const $SUBLIME_INSTDIR = "Sublime Text"      ; Program Files 下的安装目录
Global Const $SUBLIME_MAINEXE = "sublime_text.exe"  ; 主程序，用于结果校验与 PATH 查找

Installer_Register($SUBLIME_DIR, "Install_sublime_text")

Func Install_sublime_text($sInstallRoot)
    #forceref $sInstallRoot      ; 装到 Program Files，不使用自定义根目录

    ; Installer_InstallSilent(显示名, 安装包, 静默参数, 主程序名, 预期安装路径[, 超时])
    Return Installer_InstallSilent( _
            "Sublime Text", _
            Installer_PackagePath($SUBLIME_DIR, $SUBLIME_SETUP), _
            $SUBLIME_SILENT, _
            $SUBLIME_MAINEXE, _
            Installer_ProgramFilesPath($SUBLIME_INSTDIR, $SUBLIME_MAINEXE))
EndFunc
