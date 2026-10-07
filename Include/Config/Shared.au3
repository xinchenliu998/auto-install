; ==============================================================================
; Config\Shared.au3 —— 配置模块的共享底座（全局状态 + 通用小工具）
; ------------------------------------------------------------------------------
; 配置模块按「配置域」拆成多个文件，本文件放它们都要用的全局状态：
;
;     Config.au3             入口：Config_Load() / Config_Save()
;     Config\General.au3     通用配置项：安装根目录 / 资源拷贝目录 / 开机账户
;     Config\Packages.au3    安装包目录 + 软件列表（扫描 / 访问器 / 勾选）
;     Config\Group.au3       分组（键 / 顺序 / 显示名）+「必须安装」
;
; 【为什么单独抽出来】
;   这些全局变量原本声明在 Config.au3 里，子模块靠「父文件先声明」才能用。
;   整体编译不报错，但**单独打开某个子模块（或在 SciTE 里编辑）就会报
;   `$g_aPackages: undeclared global variable`** —— 因为那个文件自己看不到声明。
;   抽成 Shared.au3 后每个文件都能单独通过语法检查（tools/check_syntax.py 第 3 项）。
;
; 【为什么子模块的函数仍然用 Config_ 前缀】
;   这里的函数是配置模块**对外**的 API（Gui\*、Installer.au3、auto-install.au3 都在调），
;   不是各子模块内部的私有函数 —— 拆文件不该顺带改调用方。
;   所以沿用 AGENTS.md 里登记的模块前缀 `Config_`，按「函数管哪个配置域」划分，
;   每个文件头部都写明了自己负责哪一段（见上面那张表）。
;
; 分层：Shared（本文件，只依赖 Constants / Common）→ General / Group → Packages
;       → Config（入口）。基础层不要反过来依赖上层。
; ==============================================================================

#include-once

#include "..\Constants.au3"
#include "..\Common.au3"

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

; 是否在软件列表里显示「未适配」（安装包目录里有、但没写安装脚本）的目录。
; 默认关闭 —— 列表只放能真正安装的软件；排障时把 config.ini 的
; [General] ShowUnsupported 设成 1，这些目录才会以「(未适配)」形式露出来。
Global $g_bShowUnsupported = False

; 软件列表：[i][$PKG_COL_*]
Global $g_aPackages[1][$PKG_COL_COUNT]
Global $g_iPackageCount = 0

; ------------------------------------------------------------------------------
; 初始化
; ------------------------------------------------------------------------------

Func Config_Init()
    $g_sConfigFile  = Common_JoinPath(@ScriptDir, $FILE_CONFIG)
    $g_sLogFileName = $FILE_LOG_PREFIX & Common_TimeStamp() & $FILE_LOG_EXT
    $g_sInstallRoot = Config_DefaultRoot($g_sSoftwareName)
    $g_sPackagesDir = $DIR_PACKAGES_DEF
    $g_sUserName    = $ACCT_DEF_USER        ; 开机账户默认值，见 Constants.au3
    $g_sPassword    = $ACCT_DEF_PASS
EndFunc

; 默认安装根目录：%LOCALAPPDATA%\<公司名>\<软件名>
;
; 放在底座而不是 General.au3 —— Config_Init() 要用它，子模块又要能各自单独通过
; Au3Check（tools/check_syntax.py 第 3 项），所以它必须比 Init() 更靠下。
; Config_SetInstallRoot()（General.au3）也复用它。
Func Config_DefaultRoot($sSoftwareName)
    Local $sName = StringStripWS($sSoftwareName, 3)
    If $sName = "" Then $sName = $APP_NAME

    Return Common_JoinPath(Common_JoinPath($ENV_INSTALL_BASE, $APP_COMPANY), $sName)
EndFunc

Func Config_File()
    Return $g_sConfigFile
EndFunc

; ------------------------------------------------------------------------------
; 通用小工具
; ------------------------------------------------------------------------------

; ini 里的布尔写法：1 / true / yes / on（大小写不限）都算真
Func Config_ParseBool($sValue)
    Switch StringLower(StringStripWS($sValue, 3))
        Case "1", "true", "yes", "on"
            Return 1
        Case Else
            Return 0
    EndSwitch
EndFunc

; 在数组的前 $iCount 项里查找，返回下标；未找到返回 -1。
; 只读，按值传即可（AutoIt 数组默认按值传，函数里改不到外层）。
Func Config_ArrayFind($aArray, $iCount, $sValue)
    For $i = 0 To $iCount - 1
        If $aArray[$i] = $sValue Then Return $i
    Next
    Return -1
EndFunc

; 去重追加，返回追加后的条数。$aArray 必须 ByRef，否则改动带不回去。
Func Config_ArrayAppendUnique(ByRef $aArray, $iCount, $sValue)
    If Config_ArrayFind($aArray, $iCount, $sValue) >= 0 Then Return $iCount
    $aArray[$iCount] = $sValue
    Return $iCount + 1
EndFunc
