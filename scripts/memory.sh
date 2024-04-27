memfree=$(($(grep -m1 'MemAvailable:' /proc/meminfo | awk '{print $2}')))
memtotal=$(($(grep -m1 'MemTotal:' /proc/meminfo | awk '{print $2}')))

useage=$(echo "scale=2;100 * ($memfree/$memtotal)" | bc)
echo -e "$useage%"
