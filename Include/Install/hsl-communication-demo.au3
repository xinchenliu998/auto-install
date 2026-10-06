; ==============================================================================
; Install\hsl-communication-demo.au3 —— HslCommunicationDemo 通讯调试工具
; ------------------------------------------------------------------------------
; 安装类型：绿色解压（zip），无需运行安装程序
; 安装位置：<安装根目录>\HslCommunicationDemo
;           （默认即 %LOCALAPPDATA%\BJ\<软件名>\HslCommunicationDemo）
; 参数依据：docs/packages/hsl-communication-demo.md
;
; 本模块属于「绿色解压类」：解压流程（已安装检测 -> 解压 -> 结果校验 -> 日志）
; 全部由 Installer_InstallGreen() 承担，本文件只声明常量 + 填参数。
; 压缩包内文件直接位于根层，解压后 HslCommunicationDemo.exe 与各依赖 DLL 同级。
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
Global Const $HSL_DIR     = "HslCommunicationDemo"      ; packages 下的目录名
Global Const $HSL_ZIP     = "HslCommunicationDemo.zip"  ; 安装包文件名
Global Const $HSL_SUBDIR  = "HslCommunicationDemo"      ; 安装根目录下的子目录名
Global Const $HSL_MAINEXE = "HslCommunicationDemo.exe"  ; 主程序，用于结果校验

Installer_Register($HSL_DIR, "Install_hsl_communication_demo")

Func Install_hsl_communication_demo($sInstallRoot)
    Local $sDest = Common_JoinPath($sInstallRoot, $HSL_SUBDIR)

    ; Installer_InstallGreen(显示名, 压缩包, 解压目标目录, 主程序名)
    ; 成功返回主程序完整路径，失败返回空串
    Local $sFound = Installer_InstallGreen( _
            "HslCommunicationDemo", _
            Installer_PackagePath($HSL_DIR, $HSL_ZIP), _
            $sDest, _
            $HSL_MAINEXE)
    If $sFound = "" Then Return False

    ; 该工具是带界面的调试程序，不写入 PATH；仅提示主程序位置，便于人工创建快捷方式
    Logger_Info("主程序位置：" & $sFound)
    Logger_Info("该工具为绿色版，未创建快捷方式；如需可从上述路径手动创建")

    Return True
EndFunc
