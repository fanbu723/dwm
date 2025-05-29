#!/bin/bash

get_battery_combined_percent() {
    # 获取电池电量和数量
    total_charge=$(acpi -b | grep -o '[0-9]\+%' | tr -d '%')
    battery_number=$(echo "$total_charge" | wc -l)

    if [ "$battery_number" -eq 0 ]; then
        echo "没有检测到电池。"
        return 1
    fi

    # 计算总电量和平均电量
    total_charge=$(echo "$total_charge" | paste -sd+ | bc)
    percent=$((total_charge / battery_number))

    # 检查充电状态
    charging=$(acpi -b | grep -m 1 -E 'Discharging|Charging')

    # 确定图标
    case $percent in
        [0-3][0-9]) icon="" ;;  # 0-33%
        [4-6][0-9]) icon="" ;;  # 34-66%
        *) icon="" ;;            # 67-100%
    esac

    # 充电状态下调整图标
    [[ $charging == *"Charging"* ]] && {
        case $icon in
            "") icon="" ;;  # 充电时低电量
            "") icon="" ;;  # 充电时中电量
            "") icon="" ;;  # 充电时高电量
        esac
    }

    printf "%s %s%%\n" "$icon" "$percent"
}

get_battery_combined_percent
