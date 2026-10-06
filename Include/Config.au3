; ==============================================================================
; Config.au3 —— 配置管理模块
; ------------------------------------------------------------------------------
; 配置文件：<脚本目录>\config.ini
;
;   [General]
;   SoftwareName=auto-install
;   InstallRoot=%LOCALAPPDATA%\BJ\auto-install
;   PackagesDir=packages
;   CopySourceDir=
;   CopyDestDir=
;
;   [Packages]
;   7zip=1
;   SQLite3=0
;
;   [Account]
;   UserName=admin
;   Password=BJ88888888
;
; 说明：
;   * InstallRoot 保存的是「可含环境变量的模板」，便于换机器 / 换账户后仍可用；
;     实际使用时通过 Config_InstallRootReal() 展开成真实路径。
;   * PackagesDir 是安装包所在目录，默认 `packages`（相对本程序，即「启动程序同级」）。
;     填相对路径时相对本程序解析，填绝对路径则原样使用 —— 这样可以和项目解耦。
;   * CopySourceDir / CopyDestDir 是资源拷贝（文档、驱动等）的源与目标目录。
;     目标留空时默认用安装根目录。
;   * [Account] 是前置检查用的开机账户：确保该本地账户存在（不存在则创建）、
;     属 Administrators 组（系统管理员）、密码可用且永不过期。
;     默认值 $ACCT_DEF_USER / $ACCT_DEF_PASS（见 Constants.au3），改配置即可覆盖。
;     密码以**明文**保存，config.ini 本身不入库。
;   * 软件列表由 PackagesDir 下的子目录自动扫描得出，勾选状态记录在 [Packages]。
;
; 段名 / 键名 / 目录名 / 数组列索引等一律取自 Constants.au3。
; ==============================================================================

#include-once

#include <File.au3>
#include <FileConstants.au3>

#include "Constants.au3"
#include "Common.au3"

; ------------------------------------------------------------------------------
; 全局状态
; ------------------------------------------------------------------------------
Global $g_sConfigFile   = ""
Global $g_sSoftwareName = $APP_NAME
Global $g_sInstallRoot  = ""
Global $g_sLogFileName  = ""
Global $g_sPackagesDir  = ""
Global $g_sCopySource   = ""
Global $g_sCopyDest     = ""
Global $g_sUserName     = ""        ; 开机账户（前置检查用，见 Precheck\Account.au3）
Global $g_sPassword     = ""

; 软件列表：[i][$PKG_COL_*]
Global $g_aPackages[1][$PKG_COL_COUNT]
Global $g_iPackageCount = 0

; ==============================================================================
; 初始化与访问器
; ==============================================================================

Func Config_Init()
    $g_sConfigFile  = Common_JoinPath(@ScriptDir, $FILE_CONFIG)
    $g_sLogFileName = $FILE_LOG_PREFIX & Common_TimeStamp() & $FILE_LOG_EXT
    $g_sInstallRoot = Config_DefaultRoot($g_sSoftwareName)
    $g_sPackagesDir = $DIR_PACKAGES_DEF
    $g_sUserName    = $ACCT_DEF_USER        ; 开机账户默认值，见 Constants.au3
    $g_sPassword    = $ACCT_DEF_PASS
EndFunc

Func Config_File()
    Return $g_sConfigFile
EndFunc

; 默认安装根目录：%LOCALAPPDATA%\<公司名>\<软件名>
Func Config_DefaultRoot($sSoftwareName)
    Local $sName = StringStripWS($sSoftwareName, 3)
    If $sName = "" Then $sName = $APP_NAME

    Return Common_JoinPath(Common_JoinPath($ENV_INSTALL_BASE, $APP_COMPANY), $sName)
EndFunc

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
; 安装包目录
; ------------------------------------------------------------------------------

Func Config_PackagesDir()
    Return $g_sPackagesDir
EndFunc

Func Config_SetPackagesDir($sDir)
    Local $s = StringStripWS($sDir, 3)
    If $s = "" Then $s = $DIR_PACKAGES_DEF
    $g_sPackagesDir = $s
EndFunc

; 解析后的安装包目录（相对路径相对本程序解析）
Func Config_PackagesDirReal()
    Return Common_ResolvePath($g_sPackagesDir, @ScriptDir)
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

; ==============================================================================
; 软件列表
; ==============================================================================

; 扫描安装包目录下的子目录，生成软件列表（勾选状态取自 config.ini）
Func Config_ScanPackages()
    Local $sPkgDir  = Config_PackagesDirReal()
    Local $aFolders = _FileListToArray($sPkgDir, "*", $FLTA_FOLDERS)

    If @error Or Not IsArray($aFolders) Then
        $g_iPackageCount = 0
        ReDim $g_aPackages[1][$PKG_COL_COUNT]
        Return 0
    EndIf

    Local $iCount = $aFolders[0]
    ReDim $g_aPackages[$iCount][$PKG_COL_COUNT]

    Local $sFolder, $sPath, $sDisplay, $sIni

    For $i = 1 To $iCount
        $sFolder = $aFolders[$i]
        $sPath   = Common_JoinPath($sPkgDir, $sFolder)
        $sIni    = Common_JoinPath($sPath, $FILE_PACKAGE_INI)

        ; 显示名可在 <安装包目录>\<目录>\package.ini 中自定义：[Package] DisplayName=xxx
        $sDisplay = IniRead($sIni, $INI_SEC_PACKAGE, $INI_KEY_DISPLAY, $sFolder)

        $g_aPackages[$i - 1][$PKG_COL_FOLDER]  = $sFolder
        $g_aPackages[$i - 1][$PKG_COL_DISPLAY] = $sDisplay
        $g_aPackages[$i - 1][$PKG_COL_PATH]    = $sPath
        $g_aPackages[$i - 1][$PKG_COL_ENABLED] = _
                Number(IniRead($g_sConfigFile, $INI_SEC_PACKAGES, $sFolder, $INI_DEFAULT_ON))
    Next

    $g_iPackageCount = $iCount
    Return $iCount
EndFunc

; 重新扫描安装包目录，并保留「仍然存在」的软件的当前勾选状态。
; 用于切换安装包目录后刷新列表 —— 免得用户刚勾好的选项被重置。
Func Config_RescanPackages()
    Local $iOld = $g_iPackageCount
    Local $aOld[$iOld + 1][2]        ; [i][0]=目录名  [i][1]=勾选状态

    For $i = 0 To $iOld - 1
        $aOld[$i][0] = $g_aPackages[$i][$PKG_COL_FOLDER]
        $aOld[$i][1] = $g_aPackages[$i][$PKG_COL_ENABLED]
    Next

    Config_ScanPackages()

    For $i = 0 To $g_iPackageCount - 1
        For $k = 0 To $iOld - 1
            If $g_aPackages[$i][$PKG_COL_FOLDER] = $aOld[$k][0] Then
                $g_aPackages[$i][$PKG_COL_ENABLED] = $aOld[$k][1]
                ExitLoop
            EndIf
        Next
    Next

    Return $g_iPackageCount
EndFunc

Func Config_PackageCount()
    Return $g_iPackageCount
EndFunc

Func Config_PackageFolder($i)
    Return $g_aPackages[$i][$PKG_COL_FOLDER]
EndFunc

Func Config_PackageDisplay($i)
    Return $g_aPackages[$i][$PKG_COL_DISPLAY]
EndFunc

Func Config_PackagePath($i)
    Return $g_aPackages[$i][$PKG_COL_PATH]
EndFunc

Func Config_PackageEnabled($i)
    Return ($g_aPackages[$i][$PKG_COL_ENABLED] = 1)
EndFunc

Func Config_SetPackageEnabled($i, $bEnabled)
    If $bEnabled Then
        $g_aPackages[$i][$PKG_COL_ENABLED] = 1
    Else
        $g_aPackages[$i][$PKG_COL_ENABLED] = 0
    EndIf
EndFunc

; 取出所有已勾选的软件
;   $aOut   ByRef，返回 2 维数组（至少 1 行，避免 0 长度数组）
;   返回值  实际条数
Func Config_GetSelected(ByRef $aOut)
    If $g_iPackageCount = 0 Then
        Local $aZero[1][$PKG_COL_COUNT]
        $aOut = $aZero
        Return 0
    EndIf

    Local $aRet[$g_iPackageCount][$PKG_COL_COUNT]
    Local $iSel = 0

    For $i = 0 To $g_iPackageCount - 1
        If $g_aPackages[$i][$PKG_COL_ENABLED] = 1 Then
            For $c = 0 To $PKG_COL_COUNT - 1
                $aRet[$iSel][$c] = $g_aPackages[$i][$c]
            Next
            $iSel += 1
        EndIf
    Next

    If $iSel = 0 Then
        Local $aEmpty[1][$PKG_COL_COUNT]
        $aOut = $aEmpty
        Return 0
    EndIf

    ReDim $aRet[$iSel][$PKG_COL_COUNT]
    $aOut = $aRet
    Return $iSel
EndFunc

; ==============================================================================
; 读写
; ==============================================================================

Func Config_Load()
    If Not FileExists($g_sConfigFile) Then
        Config_ScanPackages()
        Return False
    EndIf

    Local $sName = IniRead($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_NAME, $APP_NAME)
    Local $sRoot = IniRead($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_ROOT, "")

    Config_SetSoftwareName($sName)
    Config_SetInstallRoot($sRoot)

    Config_SetPackagesDir(IniRead($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_PKGDIR, $DIR_PACKAGES_DEF))
    Config_SetCopySource(IniRead($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_COPYSRC, ""))
    Config_SetCopyDest(IniRead($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_COPYDST, ""))

    Config_SetUserName(IniRead($g_sConfigFile, $INI_SEC_ACCOUNT, $INI_KEY_USER, $ACCT_DEF_USER))
    Config_SetPassword(IniRead($g_sConfigFile, $INI_SEC_ACCOUNT, $INI_KEY_PASS, $ACCT_DEF_PASS))

    Config_ScanPackages()
    Return True
EndFunc

Func Config_Save()
    Local $sDir = Common_FileDir($g_sConfigFile)
    If $sDir <> "" Then Common_EnsureDir($sDir)

    IniWrite($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_NAME, $g_sSoftwareName)
    IniWrite($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_ROOT, $g_sInstallRoot)
    IniWrite($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_PKGDIR, $g_sPackagesDir)
    IniWrite($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_COPYSRC, $g_sCopySource)
    IniWrite($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_COPYDST, $g_sCopyDest)

    IniWrite($g_sConfigFile, $INI_SEC_ACCOUNT, $INI_KEY_USER, $g_sUserName)
    IniWrite($g_sConfigFile, $INI_SEC_ACCOUNT, $INI_KEY_PASS, $g_sPassword)

    For $i = 0 To $g_iPackageCount - 1
        IniWrite($g_sConfigFile, $INI_SEC_PACKAGES, _
                $g_aPackages[$i][$PKG_COL_FOLDER], $g_aPackages[$i][$PKG_COL_ENABLED])
    Next

    Return FileExists($g_sConfigFile)
EndFunc
