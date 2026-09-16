#!/bin/sh
# dwmblocks 模块：内存占用率
# 依赖：awk（读取 /proc/meminfo）
#
# 输出「已用内存」占比：100 * (MemTotal - MemAvailable) / MemTotal

awk '
	/^MemTotal:/     { total = $2 }
	/^MemAvailable:/ { avail = $2 }
	END {
		if (total > 0) printf "%.0f%%\n", 100 * (total - avail) / total
		else print "—"
	}
' /proc/meminfo
