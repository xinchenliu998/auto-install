; ==============================================================================
; Gui\ConfigShared.au3 —— 配置界面的共享声明（控件 ID + 界面状态）
; ------------------------------------------------------------------------------
; 本文件只**声明变量**，不含任何逻辑。被配置界面相关的每个文件各自 include：
;
;     Gui\Config.au3         入口 + 消息循环
;     Gui\ConfigLayout.au3   界面构建
;     Gui\ConfigState.au3    状态同步 + 校验回写
;     Gui\PackageList.au3    软件列表控件
;
; 【为什么单独抽出来】
;   这些变量原本声明在 Gui\Config.au3 里，子模块靠「父文件先声明」才能用。
;   整体编译不报错，但**单独打开某个子模块（或在 SciTE 里编辑）就会报
;   `$g_idRoot: undeclared global variable`** —— 因为那个文件自己看不到声明。
;   抽成 ConfigShared.au3 后每个文件都能单独通过语法检查，整体编译也不受影响。
;
;   规则：**控件 ID 与界面状态只在这里声明一次**，其他文件一律
;   `#include "ConfigShared.au3"` 引入，不要在任何地方再声明一遍。
; ==============================================================================

#include-once

; ------------------------------------------------------------------------------
; 窗口与控件 ID（由 Gui\ConfigLayout.au3 / Gui\PackageList.au3 创建并赋值）
; ------------------------------------------------------------------------------
Global $g_hGuiCfg = 0

Global $g_idName, $g_idRoot, $g_idRootDefault, $g_idBrowse
Global $g_idPkgDir, $g_idPkgBrowse, $g_idPkgReload
Global $g_idCopySrc, $g_idCopySrcBrowse
Global $g_idCopyDst, $g_idCopyDstBrowse
Global $g_idAcctUser, $g_idAcctPass

Global $g_idRootHint, $g_idPkgHint, $g_idLogHint, $g_idConfigHint

Global $g_idGrp2, $g_idPkgList
Global $g_idSelectAll, $g_idSelectNone, $g_idSelectInvert, $g_idCount

Global $g_idStatus, $g_idStart, $g_idSave, $g_idExit

; ------------------------------------------------------------------------------
; 界面状态
; ------------------------------------------------------------------------------
Global $g_bRootAuto     = True      ; 安装根目录是否跟随软件名称自动变化
Global $g_sLastAutoRoot = ""
Global $g_sHintRoot     = ""
Global $g_sHintPkg      = ""
Global $g_sHintLog      = ""
Global $g_sStatusText   = ""
