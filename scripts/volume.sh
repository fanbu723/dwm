#!/bin/bash
VOL=$(amixer get Master | tail -n1 | sed -r "s/.*\[(.*)%\].*/\1/")

if [ -n "$VOL" ] && [ "$VOL" -eq "$VOL" ] 2>/dev/null; then
    if [ "$VOL" -eq 0 ]; then
        echo -e "ﱝ  "
    elif [ "$VOL" -gt 0 ] && [ "$VOL" -le 33 ]; then
        echo -e " $VOL%"
    elif [ "$VOL" -gt 33 ] && [ "$VOL" -le 66 ]; then
        echo -e "墳 $VOL%"
    else
        echo -e " $VOL%"
    fi
else
    echo -e "Error: Unable to get volume"
fi