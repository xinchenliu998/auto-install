; ==============================================================================
; Config.au3 —— 配置管理模块（入口）
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
; 安装包目录下每个 <软件目录>\package.ini 可写（都可省略）：
;
;   [Package]
;   DisplayName=WPS Office   显示名，省略则用目录名
;   Category=office          分组键，省略归入「未分组」
;   Required=1               1 = 必须安装（归入「必须安装」组，且勾选不可取消）
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
;   * 列表按 package.ini 里的 Category 分组显示，见 Config_BuildGroups()；
;     package.ini 保持 ASCII（中文分组名由 Config_CategoryName() 映射，原因见 Constants.au3）。
;
; 段名 / 键名 / 目录名 / 数组列索引等一律取自 Constants.au3。
;
; 【本文件只放入口】
;   配置模块按「配置域」拆开，本文件只做两件需要横跨所有域的整批操作：
;   Config_Load() 与 Config_Save()。各域的实现见同目录下的子模块：
;
;     Config\Shared.au3     全局状态（$g_*）+ Config_Init() / Config_File() + 通用小工具
;     Config\General.au3    安装根目录 / 资源拷贝目录 / 开机账户
;     Config\Packages.au3   安装包目录 + 软件列表（扫描 / 访问器 / 勾选）
;     Config\Group.au3      分组（键 / 顺序 / 显示名）+「必须安装」
;
;   子模块一律沿用 `Config_` 前缀（它们是本模块**对外**的 API，被 Gui\*、
;   Installer.au3、auto-install.au3 调用，拆文件不该顺带改调用方）；
;   每个子模块头部都写明了自己负责哪一段函数。原因详见 Config\Shared.au3 的说明。
; ==============================================================================

#include-once

#include "Constants.au3"
#include "Common.au3"

; ------------------------------------------------------------------------------
; 子模块（共享声明与各子模块都自带 #include-once，顺序无关）
; ------------------------------------------------------------------------------
#include "Config\Shared.au3"
#include "Config\General.au3"
#include "Config\Group.au3"
#include "Config\Packages.au3"

; ==============================================================================
; 读写
; ==============================================================================

Func Config_Load()
    ; 这个开关先读：Config_ScanPackages() 要用它决定列不列「未适配」的目录
    $g_bShowUnsupported = Config_ParseBool( _
            IniRead($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_SHOW_UNSUP, $SHOW_UNSUP_DEF))

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

    ; 未适配目录的显示开关（一般保持 0；排障打开后也会被保存下来）
    IniWrite($g_sConfigFile, $INI_SEC_GENERAL, $INI_KEY_SHOW_UNSUP, _
            $g_bShowUnsupported ? "1" : "0")

    IniWrite($g_sConfigFile, $INI_SEC_ACCOUNT, $INI_KEY_USER, $g_sUserName)
    IniWrite($g_sConfigFile, $INI_SEC_ACCOUNT, $INI_KEY_PASS, $g_sPassword)

    For $i = 0 To $g_iPackageCount - 1
        ; 未适配的目录（没有安装脚本）不写进配置，免得 [Packages] 段里堆一堆没用的键
        If $g_aPackages[$i][$PKG_COL_CATEGORY] = $PKG_CAT_UNSUPPORTED Then ContinueLoop

        IniWrite($g_sConfigFile, $INI_SEC_PACKAGES, _
                $g_aPackages[$i][$PKG_COL_FOLDER], $g_aPackages[$i][$PKG_COL_ENABLED])
    Next

    Return FileExists($g_sConfigFile)
EndFunc
