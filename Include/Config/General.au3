; ==============================================================================
; Config\General.au3 —— 通用配置项（安装根目录 / 资源拷贝目录 / 开机账户）
; ------------------------------------------------------------------------------
; 对应 config.ini 的 [General] 与 [Account] 两段里除 PackagesDir 之外的内容。
; 全是「读一个值 / 写一个值 / 需要时展开成真实路径」的小访问器，没有业务逻辑。
;
; 本文件负责的函数段：
;     Config_SoftwareName       Config_SetSoftwareName
;     Config_InstallRoot        Config_SetInstallRoot / Config_InstallRootReal
;     Config_LogFile
;     Config_CopySource         Config_SetCopySource / Config_CopySourceReal
;     Config_CopyDest           Config_SetCopyDest   / Config_CopyDestReal
;     Config_CopyEnabled
;     Config_UserName           Config_SetUserName
;     Config_Password           Config_SetPassword   / Config_AccountEnabled
;
; Config_DefaultRoot()（默认安装根目录算法）放在 Config\Shared.au3 ——
; Config_Init() 要用它，得比 Init() 更靠下。
;
; 安装包目录那三件套在 Config\Packages.au3（与「扫描软件列表」同属一个域）。
; 全局状态在 Config\Shared.au3，本文件自己 #include。
; ==============================================================================

#include-once

#include "..\Constants.au3"
#include "..\Common.au3"
#include "Shared.au3"

; ------------------------------------------------------------------------------
; 安装根目录
; ------------------------------------------------------------------------------

Func Config_SoftwareName()
    Return $g_sSoftwareName
EndFunc

Func Config_SetSoftwareName($sName)
    Local $s = StringStripWS($sName, 3)
    If $s = "" Then $s = $APP_NAME
    $g_sSoftwareName = $s
EndFunc

Func Config_InstallRoot()
    Return $g_sInstallRoot
EndFunc

Func Config_SetInstallRoot($sRoot)
    Local $s = StringStripWS($sRoot, 3)
    If $s = "" Then $s = Config_DefaultRoot($g_sSoftwareName)
    $g_sInstallRoot = $s
EndFunc

; 展开环境变量后的真实安装根目录
Func Config_InstallRootReal()
    Return Common_NormalizePath($g_sInstallRoot)
EndFunc

; 本次运行的日志文件完整路径
Func Config_LogFile()
    Return Common_JoinPath(Common_JoinPath(Config_InstallRootReal(), $DIR_LOGS), $g_sLogFileName)
EndFunc

; ------------------------------------------------------------------------------
; 资源拷贝目录
; ------------------------------------------------------------------------------

Func Config_CopySource()
    Return $g_sCopySource
EndFunc

Func Config_SetCopySource($sDir)
    $g_sCopySource = StringStripWS($sDir, 3)
EndFunc

; 解析后的拷贝源目录；未配置返回空串
Func Config_CopySourceReal()
    Return Common_ResolvePath($g_sCopySource, @ScriptDir)
EndFunc

Func Config_CopyDest()
    Return $g_sCopyDest
EndFunc

Func Config_SetCopyDest($sDir)
    $g_sCopyDest = StringStripWS($sDir, 3)
EndFunc

; 解析后的拷贝目标目录；未配置则回退到安装根目录
Func Config_CopyDestReal()
    If StringStripWS($g_sCopyDest, 3) = "" Then Return Config_InstallRootReal()
    Return Common_ResolvePath($g_sCopyDest, @ScriptDir)
EndFunc

; 是否启用了资源拷贝
Func Config_CopyEnabled()
    Return (Config_CopySourceReal() <> "")
EndFunc

; ------------------------------------------------------------------------------
; 开机账户（前置检查：确保存在一个确定的本地账户）
; ------------------------------------------------------------------------------

Func Config_UserName()
    Return $g_sUserName
EndFunc

Func Config_SetUserName($sName)
    $g_sUserName = StringStripWS($sName, 3)
EndFunc

; 开机账户密码。以明文保存在 config.ini（该文件不入库）。
Func Config_Password()
    Return $g_sPassword
EndFunc

Func Config_SetPassword($sPass)
    $g_sPassword = $sPass
EndFunc

; 是否配置了开机账户
Func Config_AccountEnabled()
    Return ($g_sUserName <> "")
EndFunc
