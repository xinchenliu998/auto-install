; ==============================================================================
; Install\wps.au3 —— WPS Office
; ------------------------------------------------------------------------------
; 安装类型：静默安装（参数按 NSIS 处理，务必实测确认）
; 安装位置：WPS 会自行选择，可能为下列之一，故把候选目录作为数组交给通用流程
;            · C:\Program Files\WPS Office
;            · C:\Program Files\Kingsoft\WPS Office
;            · %LOCALAPPDATA%\Kingsoft\WPS Office
;            · %APPDATA%\Kingsoft\WPS Office
; 参数依据：docs/packages/wps.md
;
; 注意：
;   · 安装包约 300MB，耗时较长，超时用 $TIMEOUT_INSTALL_LONG（30 分钟）；
;   · 不同渠道版本的静默参数可能不同，批量使用前必须在目标系统实测；
;   · 首次启动可能有引导 / 推广弹窗，需要的话另行预置统一配置。
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
Global Const $WPS_DIR     = "wps"                   ; packages 下的目录名
Global Const $WPS_SETUP   = "WPS_Setup_28505.exe"   ; 安装包文件名
Global Const $WPS_SILENT  = $SILENT_NSIS            ; 静默参数（待实测确认）
Global Const $WPS_TIMEOUT = $TIMEOUT_INSTALL_LONG   ; 大体积安装包，放宽超时
Global Const $WPS_MAINEXE = "wps.exe"               ; 主程序，用于结果校验与 PATH 查找

Installer_Register($WPS_DIR, "Install_wps")

Func Install_wps($sInstallRoot)
    #forceref $sInstallRoot      ; 装到 WPS 自选目录，不使用自定义根目录

    ; WPS 的安装位置不固定，把候选目录交给通用流程逐个判断（之后还会再查系统 PATH）
    Local $aCandidate[4]
    $aCandidate[0] = Common_JoinPath(@ProgramFilesDir, "WPS Office")
    $aCandidate[1] = Common_JoinPath(Common_JoinPath(@ProgramFilesDir, "Kingsoft"), "WPS Office")
    $aCandidate[2] = Common_JoinPath(Common_JoinPath(@LocalAppDataDir, "Kingsoft"), "WPS Office")
    $aCandidate[3] = Common_JoinPath(Common_JoinPath(@AppDataDir, "Kingsoft"), "WPS Office")

    ; Installer_InstallSilent(显示名, 安装包, 静默参数, 主程序名, 预期安装路径[, 超时])
    Local $bOk = Installer_InstallSilent( _
            "WPS Office", _
            Installer_PackagePath($WPS_DIR, $WPS_SETUP), _
            $WPS_SILENT, _
            $WPS_MAINEXE, _
            $aCandidate, _
            $WPS_TIMEOUT)
    If Not $bOk Then Return False

    Logger_Info("提示：如首次启动出现引导或推广弹窗，建议另行预置统一配置")
    Return True
EndFunc
