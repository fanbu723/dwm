#!/bin/sh
# dwmblocks 模块：内存占用率
# 依赖：awk（读取 /proc/meminfo）
#
# 输出「已用内存」占比：100 * (MemTotal - MemAvailable) / MemTotal

# 70% 以上标琥珀、85% 以上标红（和 CPU 块一个思路）
awk '
	/^MemTotal:/     { total = $2 }
	/^MemAvailable:/ { avail = $2 }
	END {
		if (total <= 0) { print "—"; exit }
		pct = 100 * (total - avail) / total
		if (pct >= 85)      printf "^c#f7768e^%.0f%%^d^\n", pct
		else if (pct >= 70) printf "^c#e0af68^%.0f%%^d^\n", pct
		else                printf "%.0f%%\n", pct
	}
' /proc/meminfo
