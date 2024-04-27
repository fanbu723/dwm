#!/bin/bash
get_battery_combined_percent() {
    total_charge=$(expr $(acpi -b | awk '{print $4}' | grep -Eo "[0-9]+" | paste -sd+ | bc))
    battery_number=$(acpi -b | wc -l)
    percent=$(expr $total_charge / $battery_number)

    if [ "$percent" -le 33 ]; then
        if $(acpi -b | grep --quit Discharging); then
           printf " %s%%" "$percent"
        else
           printf " %s%%" "$percent"
        fi
    elif [ "$percent" -ge 33 ] && [ "$percent" -le 66 ]; then
        if $(acpi -b | grep --quit Discharging); then
            print " %s%%" "$percent"
        else
            printf " %s%%" "$percent"
        fi
    else
        if $(acpi -b | grep --quit Discharging); then
            printf " %s%%" "$percent"
        else
            printf " %s%%" "$percent"
        fi
    fi
}

get_battery_combined_percent
