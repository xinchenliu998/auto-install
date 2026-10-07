; ==============================================================================
; Constants.au3 —— 全局常量集中管理
; ------------------------------------------------------------------------------
; 本文件是项目**唯一**的框架级常量来源。其他模块统一 #include 本文件，
; 不要在各自脚本里散落硬编码的数字与字符串。
;
; 命名前缀约定：
;   $APP_    应用信息
;   $ENV_    环境变量
;   $DIR_    目录名
;   $FILE_   文件名
;   $INI_    配置文件段名 / 键名
;   $PKG_    软件列表数组列索引、分组键与分组顺序
;   $REG_    安装注册表数组列索引
;   $LOG_    日志级别、格式与界面颜色
;   $RUN_    外部命令执行返回码、轮询与超时
;   $TIMEOUT_ 各类操作超时
;   $SILENT_ 安装器静默参数
;   $PRECHK_ 前置检查（注册表键、防火墙规则名、内置组名等）
;   $ACCT_   开机账户默认值
;   $ROBOCOPY_ robocopy 相关
;   $MB_     消息框标志与返回值
;   $EXIT_   进程退出码
;   $CLI_    命令行开关
;   $MUTEX_  互斥体名称
;   $UI_     界面布局、字体、颜色
;
; 例外：与单个软件强相关的常量（安装包文件名、安装目录名等）留在各自的
;      Include\Install\*.au3 顶部（前缀取软件名，如 $ZIP7_ / $SQLITE_ / $WPS_），
;      避免本文件随软件数量无限膨胀。
; ==============================================================================

#include-once

; ------------------------------------------------------------------------------
; 应用信息
; ------------------------------------------------------------------------------
Global Const $APP_NAME      = "auto-install"
Global Const $APP_TITLE     = "auto-install 装机工具"
Global Const $APP_TITLE_RUN = "auto-install 装机工具 - 正在执行"
Global Const $APP_VERSION   = "1.0.0"
Global Const $APP_COMPANY   = "BJ"              ; 公司名称，用于生成默认安装根目录

; ------------------------------------------------------------------------------
; 环境变量 / 目录 / 文件名
; ------------------------------------------------------------------------------
; 安装根目录的基准位置。用 Local 而非 Roaming：安装文件不该随域账户漫游同步。
; 改这一行即可整体切换安装根目录的默认位置。
Global Const $ENV_INSTALL_BASE = "%LOCALAPPDATA%"

; 安装包目录的默认值：相对路径，相对本程序所在目录（即「启动程序同级」）。
; 实际值存在 config.ini 的 PackagesDir，可改成绝对路径指向仓库之外。
Global Const $DIR_PACKAGES_DEF = "packages"

Global Const $DIR_LOGS         = "logs"         ; 日志子目录（相对安装根目录）

Global Const $FILE_CONFIG      = "config.ini"   ; 运行配置
Global Const $FILE_PACKAGE_INI = "package.ini"  ; 单个软件的可选清单
Global Const $FILE_LOG_PREFIX  = "install_"     ; 日志文件名前缀
Global Const $FILE_LOG_EXT     = ".log"

; 解压绿色版软件包时依赖的外部工具（Common_Find7Zip() 用）
Global Const $FILE_7ZIP_EXE    = "7z.exe"

; ------------------------------------------------------------------------------
; 配置文件（config.ini）段名与键名
; ------------------------------------------------------------------------------
Global Const $INI_SEC_GENERAL  = "General"
Global Const $INI_SEC_PACKAGES = "Packages"
Global Const $INI_SEC_PACKAGE  = "Package"
Global Const $INI_SEC_ACCOUNT  = "Account"        ; 开机账户（前置检查用）

Global Const $INI_KEY_NAME     = "SoftwareName"
Global Const $INI_KEY_ROOT     = "InstallRoot"
Global Const $INI_KEY_PKGDIR   = "PackagesDir"    ; 安装包所在目录
Global Const $INI_KEY_COPYSRC  = "CopySourceDir"  ; 资源拷贝源目录
Global Const $INI_KEY_COPYDST  = "CopyDestDir"    ; 资源拷贝目标目录
Global Const $INI_KEY_DISPLAY  = "DisplayName"
Global Const $INI_KEY_CATEGORY = "Category"       ; package.ini：分组键（取值见 $PKG_CAT_ORDER）
Global Const $INI_KEY_REQUIRED = "Required"       ; package.ini：是否必须安装（1 = 是）
Global Const $INI_KEY_USER     = "UserName"       ; 开机账户用户名
Global Const $INI_KEY_PASS     = "Password"       ; 开机账户密码（明文，config.ini 不入库）

; 开机账户默认值：首次运行 / 配置里未写时生效，确保每台机器都有一个确定的管理员账户。
; 前置检查会把该账户加入 Administrators 组（系统管理员）。
Global Const $ACCT_DEF_USER    = "admin"
Global Const $ACCT_DEF_PASS    = "BJ88888888"

Global Const $INI_DEFAULT_ON   = "1"            ; 新扫描到的软件默认勾选

; ------------------------------------------------------------------------------
; 软件列表数组列索引（Config_* 系列函数使用）
; ------------------------------------------------------------------------------
Global Const $PKG_COL_FOLDER   = 0              ; packages 下的目录名
Global Const $PKG_COL_DISPLAY  = 1              ; 显示名
Global Const $PKG_COL_ENABLED  = 2              ; 是否勾选（1/0）
Global Const $PKG_COL_PATH     = 3              ; 目录完整路径
Global Const $PKG_COL_CATEGORY = 4              ; 分组键
Global Const $PKG_COL_REQUIRED = 5              ; 是否必须安装（1/0）
Global Const $PKG_COL_COUNT    = 6

; ------------------------------------------------------------------------------
; 软件分组（配置界面的软件列表按分组显示）
; ------------------------------------------------------------------------------
; 分组与「必须安装」写在安装包目录下的 <软件目录>\package.ini：
;
;     [Package]
;     DisplayName=WPS Office
;     Category=office          ; 分组键，取值见 $PKG_CAT_ORDER
;     Required=0               ; 1 = 必须安装
;
; 【为什么 package.ini 里写 ASCII 键，而不是直接写中文分组名】
;   实测（AutoIt 的 IniRead 按 ANSI 代码页读无 BOM 的文件）：
;     · 存成 UTF-8 无 BOM —— 中文读出来是乱码；
;     · 存成 UTF-8 带 BOM —— 更糟，连 [Package] 段都读不到；
;     · 存成 ANSI/GBK    —— 正确。
;   所以 package.ini 一律保持 ASCII，中文显示名集中在本文件 + Config_CategoryName()。
;
; 【新增一个分组】三处各补一行：
;   1. 下面 $PKG_CAT_ORDER 里插好位置；
;   2. Config\Group.au3 的 Config_CategoryName() 里补上中文名；
;   3. 各软件的 package.ini 把 Category 改成新键。

Global Const $PKG_CAT_REQUIRED = "required"     ; 「必须安装」组的键：Required=1 的软件自动归入，且勾选被锁定
Global Const $PKG_CAT_DEFAULT  = "misc"         ; 兜底分组键：package.ini 里没写 Category 的软件都归到它，界面显示「未分组」
Global Const $PKG_CAT_UNSUPPORTED = "unsupported"   ; 「未适配」组的键：安装包目录里有、但还没写安装脚本的目录（仅在 ShowUnsupported=1 时出现）

; 未适配软件的显示名后缀，用于在列表里区分「有包但装不了」的条目
Global Const $PKG_TAG_UNSUPPORTED = "(未适配)"

; 是否在软件列表里显示「未适配」的目录。默认 0 = 只显示已适配（能真正安装）的软件。
; 写在 config.ini 的 [General] 段：ShowUnsupported=1 打开，用于排查「包放进去了却没出现在列表里」。
Global Const $INI_KEY_SHOW_UNSUP = "ShowUnsupported"
Global Const $SHOW_UNSUP_DEF     = "0"

; 分组的显示顺序（键名，逗号分隔）：按此表从上到下排列；表里没有的分组接在后面（按扫描顺序）。
; 「必须安装」组无论写在哪，都固定排第一；「未适配」组固定排最后。
;   debug  —— 调试 / 排障工具
;   vision —— 机器视觉（Machine Vision）专用软件
Global Const $PKG_CAT_ORDER = "required,base,dev,debug,vision,office,misc"

; ------------------------------------------------------------------------------
; 安装函数注册表数组列索引（Installer_* 系列函数使用）
; ------------------------------------------------------------------------------
Global Const $REG_COL_FOLDER = 0                ; packages 下的目录名
Global Const $REG_COL_FUNC   = 1                ; 安装函数名
Global Const $REG_COL_COUNT  = 2

; ------------------------------------------------------------------------------
; 日志
; ------------------------------------------------------------------------------
Global Const $LOG_LEVEL_INFO  = "INFO"
Global Const $LOG_LEVEL_OK    = "OK"
Global Const $LOG_LEVEL_WARN  = "WARN"
Global Const $LOG_LEVEL_ERROR = "ERROR"
Global Const $LOG_LEVEL_STEP  = "STEP"
Global Const $LOG_LEVEL_WIDTH = 5               ; 级别字段对齐宽度

; 日志级别对应的界面文字颜色（**RGB 写法**，与 $UI_COLOR_* 同一套）。
; 执行界面的日志框是 RichEdit 控件，写入前由 Logger_RgbToColorRef() 转成 COLORREF(BGR)
; —— RichEdit 的 _GUICtrlRichEdit_SetCharColor 收的是 COLORREF，不是 AutoIt GUI 用的 RGB。
Global Const $LOG_COLOR_DEFAULT = 0x333333      ; 无级别的普通行（分隔线等）
Global Const $LOG_COLOR_INFO    = 0x333333      ; 常规信息：深灰
Global Const $LOG_COLOR_OK      = 0x1E8449      ; 成功：绿
Global Const $LOG_COLOR_WARN    = 0xB9770E      ; 警告：橙
Global Const $LOG_COLOR_ERROR   = 0xC0392B      ; 错误：红（与 $UI_COLOR_ERROR 一致）
Global Const $LOG_COLOR_STEP    = 0x1F618D      ; 阶段标题：蓝

; ------------------------------------------------------------------------------
; 外部命令执行
; ------------------------------------------------------------------------------
Global Const $RUN_ERR_START      = -1           ; 命令启动失败
Global Const $RUN_ERR_TIMEOUT    = -2           ; 等待超时被强制结束
Global Const $RUN_EXITED_BEFORE  = 0xCCCCCCCC   ; ProcessWaitClose 对已退出进程的 @extended
Global Const $RUN_POLL_MS        = 1000         ; 分片等待步长（毫秒）
Global Const $RUN_PUMP_MS        = 100          ; Adlib 消息泵间隔（毫秒）

; 等待心跳：安装 / 解压 / 拷贝可能持续很久，等待期间定期输出「仍在进行」，
; 避免界面长时间没有新日志而被误认为卡死（实现见 Installer_WaitTick）。
Global Const $RUN_HEARTBEAT_MS      = 1000      ; 界面「已等待」计时刷新间隔（毫秒）
Global Const $RUN_HEARTBEAT_LOG_SEC = 10        ; 写一条心跳日志的间隔（秒）

Global Const $TIMEOUT_INSTALL      = 600000     ; 单个软件安装超时（10 分钟）
Global Const $TIMEOUT_INSTALL_LONG = 1800000    ; 大体积软件安装超时（30 分钟，如 WPS）
Global Const $TIMEOUT_UNZIP        = 600000     ; 解压超时（10 分钟）
Global Const $TIMEOUT_COPY         = 1800000    ; 资源拷贝超时（30 分钟）
Global Const $TIMEOUT_PRECHECK     = 120000     ; 单项前置检查命令超时（2 分钟）

; robocopy 退出码：0~7 都表示成功（0=无需拷贝，1=有文件被拷贝…），8 及以上才是错误
Global Const $ROBOCOPY_OK_MAX      = 7

; ------------------------------------------------------------------------------
; 前置检查（Precheck.au3）
; ------------------------------------------------------------------------------
Global Const $PRECHK_WIN_KEY     = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
Global Const $PRECHK_RDP_KEY     = "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"
Global Const $PRECHK_RDP_VAL     = "fDenyTSConnections"        ; 0 = 允许远程桌面

; 防火墙规则名用自建名称，不用系统内置规则的名称 —— 内置规则名（组名）随系统语言变化。
Global Const $PRECHK_FW_ICMP     = "auto-install ICMPv4-In"    ; 放通 ping
Global Const $PRECHK_FW_RDP      = "auto-install RDP-TCP-In"   ; 放通远程桌面 3389

; 内置管理员组的 SAM 名不随系统语言变化（中文系统下同样是 Administrators）
Global Const $PRECHK_ADMIN_GROUP = "Administrators"

; 设备管理器错误码 45 = 设备当前未连接（如拔掉的 U 盘），属正常状态，不计入驱动异常
Global Const $PRECHK_DEV_SKIP    = 45

; ------------------------------------------------------------------------------
; 安装器静默参数（按安装包打包工具区分，供各 Install 模块复用）
;   注意：不同渠道 / 版本的安装包参数可能不同，批量使用前务必实测确认。
; ------------------------------------------------------------------------------
Global Const $SILENT_NSIS = "/S"                                            ; NSIS
Global Const $SILENT_INNO = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" ; Inno Setup

; ------------------------------------------------------------------------------
; 消息框
; ------------------------------------------------------------------------------
Global Const $MB_WARN       = 0x30              ; 警告图标
Global Const $MB_ERROR      = 0x10              ; 错误图标
Global Const $MB_INFO       = 0x40              ; 信息图标
Global Const $MB_YESNO_WARN = 0x134             ; 是/否 + 警告图标 + 默认「否」
Global Const $MB_RET_YES    = 6                 ; 上面对话框点击「是」的返回值

; ------------------------------------------------------------------------------
; 进程退出码
; ------------------------------------------------------------------------------
Global Const $EXIT_OK   = 0
Global Const $EXIT_FAIL = 1

; ------------------------------------------------------------------------------
; 命令行开关
; ------------------------------------------------------------------------------
Global Const $CLI_RUN        = "--run"
Global Const $CLI_AUTO_CLOSE = "--auto-close"
Global Const $CLI_HELP       = "--help"

; ------------------------------------------------------------------------------
; 互斥体名称（单实例保护）
; ------------------------------------------------------------------------------
Global Const $MUTEX_GUI = "auto-install-gui"

; ------------------------------------------------------------------------------
; 界面：通用字体与颜色
; ------------------------------------------------------------------------------
Global Const $UI_FONT_UI      = "Microsoft YaHei"
Global Const $UI_FONT_MONO    = "Consolas"
Global Const $UI_FONT_SIZE    = 9
Global Const $UI_FONT_SIZE_H  = 14              ; 主标题
Global Const $UI_FONT_SIZE_S  = 12              ; 次级标题

Global Const $UI_COLOR_BG      = 0xFFFFFF       ; 窗口背景
Global Const $UI_COLOR_HINT    = 0x9E9E9E       ; 灰色提示文字
Global Const $UI_COLOR_TEXT    = 0x666666       ; 次级文字
Global Const $UI_COLOR_SUBTEXT = 0x8C8C8C       ; 副标题
Global Const $UI_COLOR_ERROR   = 0xC0392B       ; 错误提示

; ------------------------------------------------------------------------------
; 界面：配置窗口布局
; ------------------------------------------------------------------------------
Global Const $UI_CFG_W          = 620
Global Const $UI_CFG_MARGIN     = 16            ; 窗口左右外边距
Global Const $UI_CFG_GRP1_Y     = 72

; 「基本配置」组内的行布局（6 行输入 + 4 行灰色提示）
;   行 0 软件名称 / 1 安装根目录 / 2 安装包目录 / 3 拷贝源目录 / 4 拷贝目标目录
;   行 5 开机账户（用户名 + 密码并排，占一行）
Global Const $UI_CFG_LABEL_W    = 76            ; 输入框左侧标签宽度
Global Const $UI_CFG_INPUT_X    = 114
Global Const $UI_CFG_INPUT_W    = 346
Global Const $UI_CFG_INPUT_H    = 25
Global Const $UI_CFG_ROW_TOP    = 30            ; 第一行输入相对组顶的偏移
Global Const $UI_CFG_ROW_PITCH  = 34            ; 行间距
Global Const $UI_CFG_BTN_X      = 466           ; 组内小按钮左边缘
Global Const $UI_CFG_BTN_X2     = 532
Global Const $UI_CFG_BTN_SM_H   = 27
Global Const $UI_CFG_ACCT_INPUT_W = 168         ; 开机账户：用户名 / 密码输入框宽度（并排两个）
Global Const $UI_CFG_ACCT_GAP     = 8           ; 开机账户：两个输入框之间的间距
Global Const $UI_CFG_HINT_TOP   = 234           ; 第一行灰色提示相对组顶的偏移
Global Const $UI_CFG_HINT_PITCH = 22
Global Const $UI_CFG_HINT_H     = 18
Global Const $UI_CFG_GRP1_H     = 332           ; = HINT_TOP + 4*HINT_PITCH + HINT_H + 14

Global Const $UI_CFG_PAD        = 34            ; 组内左边距
Global Const $UI_CFG_INNER_PAD  = 18            ; 组内右边距
Global Const $UI_CFG_BTN_H      = 32

; 「选择要安装的软件」组 —— 固定尺寸，软件多了由列表控件自带滚动条，窗口不随之变化
Global Const $UI_CFG_GRP2_Y     = 418           ; = GRP1_Y + GRP1_H + GRP2_BOT
Global Const $UI_CFG_GRP2_BAR   = 58            ; 组内工具条高度
Global Const $UI_CFG_GRP2_BOT   = 14            ; 组底部留白
Global Const $UI_CFG_LIST_H     = 142           ; 列表高度，约 6 行
Global Const $UI_CFG_GRP2_H     = 214           ; = GRP2_BAR + LIST_H + GRP2_BOT
Global Const $UI_CFG_BOTTOM_Y   = 646           ; = GRP2_Y + GRP2_H + GRP2_BOT
Global Const $UI_CFG_BOTTOM_GAP = 18            ; 底部按钮与窗口下沿间距
Global Const $UI_CFG_WIN_H      = 696           ; = BOTTOM_Y + BTN_H + BOTTOM_GAP

; ------------------------------------------------------------------------------
; 界面：执行窗口布局
; ------------------------------------------------------------------------------
Global Const $UI_RUN_W              = 640
Global Const $UI_RUN_H              = 480
Global Const $UI_RUN_PAD            = 22
Global Const $UI_RUN_PROGRESS_H     = 18
Global Const $UI_RUN_LOG_Y          = 122
Global Const $UI_RUN_LOG_H          = 300
Global Const $UI_RUN_BTN_Y          = 434
Global Const $UI_RUN_BTN_W          = 120
Global Const $UI_RUN_BTN_H          = 30
Global Const $UI_RUN_AUTOCLOSE_WAIT = 1500      ; 无人值守模式下结果窗口停留时间（毫秒）
