#!/usr/bin/env python

import time
import json
import requests
import time
from datetime import datetime

WEATHER_CODES = {
    '113': '☀️ ',
    '116': '⛅ ',
    '119': '☁️ ',
    '122': '☁️ ',
    '143': '☁️ ',
    '176': '🌧️',
    '179': '🌧️',
    '182': '🌧️',
    '185': '🌧️',
    '200': '⛈️ ',
    '227': '🌨️',
    '230': '🌨️',
    '248': '☁️ ',
    '260': '☁️ ',
    '263': '🌧️',
    '266': '🌧️',
    '281': '🌧️',
    '284': '🌧️',
    '293': '🌧️',
    '296': '🌧️',
    '299': '🌧️',
    '302': '🌧️',
    '305': '🌧️',
    '308': '🌧️',
    '311': '🌧️',
    '314': '🌧️',
    '317': '🌧️',
    '320': '🌨️',
    '323': '🌨️',
    '326': '🌨️',
    '329': '❄️ ',
    '332': '❄️ ',
    '335': '❄️ ',
    '338': '❄️ ',
    '350': '🌧️',
    '353': '🌧️',
    '356': '🌧️',
    '359': '🌧️',
    '362': '🌧️',
    '365': '🌧️',
    '368': '🌧️',
    '371': '❄️',
    '374': '🌨️',
    '377': '🌨️',
    '386': '🌨️',
    '389': '🌨️',
    '392': '🌧️',
    '395': '❄️ '
}

data = {}

# https://wttr.in/?format=j1
weather = requests.get("https://wttr.in/NingBo?m&lang=zh&format=j1").json()


def format_time(time):
    return time.replace("00", "").zfill(2)


def format_temp(temp):
    return (hour['FeelsLikeC']+"°C").ljust(3)


def format_chances(hour):
    chances = {
        "chanceoffog": "雾",#Fog
        "chanceoffrost": "霜",#Frost
        "chanceofovercast": "阴",#Overcast
        "chanceofrain": "雨",#Rain
        "chanceofsnow": "雪",#Snow
        "chanceofsunshine": "晴",#Sunshine
        "chanceofthunder": "雷",#Thunder
        "chanceofwindy": "风"#Wind
    }

    conditions = []
    for event in chances.keys():
        if int(hour[event]) > 0:
            conditions.append(chances[event]+" "+hour[event]+"%")
    return ", ".join(conditions)

tempint = int(weather['current_condition'][0]['FeelsLikeC'])
extrachar = ''
if tempint > 0 and tempint < 10:
    extrachar = '+'


data['text'] = ' '+WEATHER_CODES[weather['current_condition'][0]['weatherCode']] + \
    " "+extrachar+weather['current_condition'][0]['FeelsLikeC']+"°C"

data['tooltip'] = f"<b>{weather['current_condition'][0]['lang_zh'][0]['value']} {weather['current_condition'][0]['temp_C']}°C</b>\n"
data['tooltip'] += f"体表温度: {weather['current_condition'][0]['FeelsLikeC']}°C\n"#Feels like
data['tooltip'] += f"风速: {weather['current_condition'][0]['windspeedKmph']}Km/h\n"#Wind
data['tooltip'] += f"湿度: {weather['current_condition'][0]['humidity']}%\n"#Humidity
for i, day in enumerate(weather['weather']):
    data['tooltip'] += f"\n<b>"
    if i == 0:
        data['tooltip'] += "今天, "#Today
    if i == 1:
        data['tooltip'] += "明天, "#Tomorrow
    data['tooltip'] += f"{day['date']}</b>\n"
    data['tooltip'] += f"⬆️ {day['maxtempC']}°C ⬇️ {day['mintempC']}°C "
    data['tooltip'] += f"🌅 {day['astronomy'][0]['sunrise']} 🌇 {day['astronomy'][0]['sunset']}\n"
    for hour in day['hourly']:
        if i == 0:
            if int(format_time(hour['time'])) < datetime.now().hour-2:
                continue
        data['tooltip'] += f"{format_time(hour['time'])} {WEATHER_CODES[hour['weatherCode']]} {format_temp(hour['FeelsLikeC'])} {hour['lang_zh'][0]['value']}, {format_chances(hour)}\n"


print(json.dumps(data))
time.sleep(600)
