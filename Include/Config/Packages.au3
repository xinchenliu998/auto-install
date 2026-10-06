; ==============================================================================
; Config\Packages.au3 —— 安装包目录 + 软件列表（扫描 / 访问器 / 勾选）
; ------------------------------------------------------------------------------
; 职责：
;   · 安装包目录本身（config.ini 的 [General] PackagesDir，可相对可绝对）；
;   · 扫描该目录下的子目录，生成软件列表；
;   · 列表的读取（显示名 / 路径 / 分组 / 是否必须安装 / 是否勾选）与勾选写入；
;   · 取出本次要装的软件（Config_GetSelected()）。
;
; 本文件负责的函数段：
;     Config_PackagesDir        Config_SetPackagesDir / Config_PackagesDirReal
;     Config_ScanPackages       Config_RescanPackages
;     Config_PackageCount       Config_PackageFolder  / Config_PackageDisplay
;     Config_PackagePath        Config_PackageCategory / Config_PackageRequired
;     Config_PackageEnabled     Config_SetPackageEnabled
;     Config_GetSelected
;
; 分组键的归一化与「必须安装」的强制勾选在 Config\Group.au3，
; 全局状态在 Config\Shared.au3，两者本文件都自己 #include。
; ==============================================================================

#include-once

#include <File.au3>
#include <FileConstants.au3>

#include "..\Constants.au3"
#include "..\Common.au3"
#include "Shared.au3"
#include "Group.au3"

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
        For $c = 0 To $PKG_COL_COUNT - 1      ; ReDim 会保留旧内容，这里清干净
            $g_aPackages[0][$c] = ""
        Next
        Return 0
    EndIf

    Local $iCount = $aFolders[0]
    ReDim $g_aPackages[$iCount][$PKG_COL_COUNT]

    Local $sFolder, $sPath, $sDisplay, $sIni, $sCategory

    For $i = 1 To $iCount
        $sFolder = $aFolders[$i]
        $sPath   = Common_JoinPath($sPkgDir, $sFolder)
        $sIni    = Common_JoinPath($sPath, $FILE_PACKAGE_INI)

        ; 显示名 / 分组 / 是否必须安装都可在 <安装包目录>\<目录>\package.ini 中自定义
        $sDisplay  = IniRead($sIni, $INI_SEC_PACKAGE, $INI_KEY_DISPLAY, $sFolder)
        $sCategory = IniRead($sIni, $INI_SEC_PACKAGE, $INI_KEY_CATEGORY, "")

        $g_aPackages[$i - 1][$PKG_COL_FOLDER]   = $sFolder
        $g_aPackages[$i - 1][$PKG_COL_DISPLAY]  = $sDisplay
        $g_aPackages[$i - 1][$PKG_COL_PATH]     = $sPath
        $g_aPackages[$i - 1][$PKG_COL_REQUIRED] = _
                Config_ParseBool(IniRead($sIni, $INI_SEC_PACKAGE, $INI_KEY_REQUIRED, "0"))

        ; 必须安装的软件一律归入「必须安装」组，不看它自己写的 Category；
        ; 没写 Category 的软件统一归入兜底分组（$PKG_CAT_DEFAULT，界面显示「未分组」）
        If $g_aPackages[$i - 1][$PKG_COL_REQUIRED] = 1 Then
            $g_aPackages[$i - 1][$PKG_COL_CATEGORY] = $PKG_CAT_REQUIRED
        Else
            $g_aPackages[$i - 1][$PKG_COL_CATEGORY] = Config_CategoryKey($sCategory)
        EndIf

        $g_aPackages[$i - 1][$PKG_COL_ENABLED] = _
                Number(IniRead($g_sConfigFile, $INI_SEC_PACKAGES, $sFolder, $INI_DEFAULT_ON))
    Next

    $g_iPackageCount = $iCount
    Config_ApplyRequired()

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

    Config_ApplyRequired()              ; 恢复的旧勾选状态不能把「必须安装」的取消掉

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

; 该软件的分组键（取值见 $PKG_CAT_ORDER），中文显示名用 Config_CategoryName()
Func Config_PackageCategory($i)
    Return $g_aPackages[$i][$PKG_COL_CATEGORY]
EndFunc

Func Config_PackageRequired($i)
    Return ($g_aPackages[$i][$PKG_COL_REQUIRED] = 1)
EndFunc

Func Config_PackageEnabled($i)
    Return ($g_aPackages[$i][$PKG_COL_ENABLED] = 1)
EndFunc

Func Config_SetPackageEnabled($i, $bEnabled)
    ; 「必须安装」的软件不允许取消勾选
    If $g_aPackages[$i][$PKG_COL_REQUIRED] = 1 Then
        $g_aPackages[$i][$PKG_COL_ENABLED] = 1
        Return
    EndIf

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
