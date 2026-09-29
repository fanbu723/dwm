//Modify this file to change what commands output to your statusbar, and recompile using the make command.

/* 状态栏配色。dwm 认识两种颜色标记（dwm.c 里的 statusparse()）：
 *   ^c#RRGGBB^  后面这段文字用这个前景色
 *   ^d^         还原成默认前景色（config.h 里 SchemeNorm 的 col_gray3）
 * 标记本身不显示也不占宽度，所以状态栏的宽度与点击区间不受影响。
 *
 * 图标也写在这一列：dwmblocks 会把 icon 拼在脚本输出前面，
 * 所以「图标 + 图标颜色」都归这里管，脚本只负责输出数值
 * （电量低 / 静音这类需要临时改色的，由脚本自己带标记）。
 * 图标是 Nerd Font 字形，写成 \uXXXX（C99 通用字符名）是为了不受文件编码影响。 */
#define CLR_NET         "#7dcfff"       /* 网速：青 */
#define CLR_CPU         "#e0af68"       /* CPU：琥珀 */
#define CLR_MEM         "#bb9af7"       /* 内存：紫 */
#define CLR_VOL         "#9ece6a"       /* 音量：绿 */
#define CLR_BRI         "#ff9e64"       /* 亮度：橙 */
#define CLR_BAT         "#9ece6a"       /* 电量：绿（低电量时脚本会改琥珀 / 红） */
#define CLR_DATE        "#a9b1d6"       /* 时间：灰蓝 */

static const Block blocks[] = {
        /*Icon*/        /*Command*/             /*Update Interval*/     /*Update Signal*/
        // 图标前后的空格就是块与块之间的间隔（本配置 delim 为空，不用分隔符）
        {" ^c" CLR_NET "^\uf1eb^d^ ",   "~/.dwm/scripts/wlan.sh",       1,      0}, //网速
        {" ^c" CLR_CPU "^\uf2db^d^ ",   "~/.dwm/scripts/cpu.sh",        5,      0}, //cpu占用率
        {" ^c" CLR_MEM "^\uf1c0^d^ ",   "~/.dwm/scripts/memory.sh",     3,      0}, //内存占用率
        {" ^c" CLR_VOL "^\uf028^d^ ",   "~/.dwm/scripts/volume.sh",     0,      11}, //音量
        {" ^c" CLR_BRI "^\uf185^d^ ",   "~/.dwm/scripts/backlight.sh",  0,      11}, //亮度
        {" ^c" CLR_BAT "^\uf242^d^ ",   "~/.dwm/scripts/battery.sh",    2,      0}, //电量
        {" ^c" CLR_DATE "^\uf017^d^ ",  "~/.dwm/scripts/date.sh",       1,      0}, //时间
};

//sets delimeter between status commands. NULL character ('\0') means no delimeter.
// 本配置不用分隔符：块之间靠上面 icon 字段里的空格 + 各自的颜色区分。
static char delim[] = "";
static int delimLen = 0;
