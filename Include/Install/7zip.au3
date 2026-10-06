; ==============================================================================
; Install\7zip.au3 —— 7-Zip 安装模块
; ------------------------------------------------------------------------------
; 安装类型：NSIS 安装包，静默参数 /S
; 安装位置：C:\Program Files\7-Zip（官方默认路径，不使用自定义安装根目录）
; 参数依据：docs/packages/7zip.md
;
; 本文件同时作为「静默安装类」软件的接入范例。写法只有三步：
;   1. 顶部 Installer_Register() 自注册，目录名须与 packages\ 下一致；
;   2. 声明本软件相关常量；
;   3. 调用 Installer_InstallSilent()，其余交给通用流程。
;
; 「已安装检测 -> 执行安装 -> 超时处理 -> 结果校验 -> 日志」全部实现在
; Installer_InstallSilent() 里，本文件不要再重复实现这些逻辑。
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
Global Const $ZIP7_DIR     = "7zip"                 ; packages 下的目录名
Global Const $ZIP7_SETUP   = "7z2604-x64.exe"       ; 安装包文件名
Global Const $ZIP7_SILENT  = $SILENT_NSIS           ; NSIS 静默参数
Global Const $ZIP7_INSTDIR = "7-Zip"                ; Program Files 下的安装目录
Global Const $ZIP7_MAINEXE = $FILE_7ZIP_EXE         ; 主程序，用于结果校验与 PATH 查找

Installer_Register($ZIP7_DIR, "Install_7zip")

Func Install_7zip($sInstallRoot)
    #forceref $sInstallRoot      ; 7-Zip 固定装到 Program Files，不使用自定义根目录

    ; Installer_InstallSilent(显示名, 安装包, 静默参数, 主程序名, 预期安装路径[, 超时])
    Return Installer_InstallSilent( _
            "7-Zip", _
            Installer_PackagePath($ZIP7_DIR, $ZIP7_SETUP), _
            $ZIP7_SILENT, _
            $ZIP7_MAINEXE, _
            Installer_ProgramFilesPath($ZIP7_INSTDIR, $ZIP7_MAINEXE))
EndFunc
