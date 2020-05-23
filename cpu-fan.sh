#!/bin/sh

#设置运行状态文件
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

if [ -n "$1" ]; then
  CONF=$1
else
  CONF=/home/pi/.cpu-fan.conf
fi
if [ -n "$2" ]; then
  LOG=$2
else
  LOG=/var/log/cpu-fan/cpu-fan.log
fi

#开机风扇全速运行
#默认的pwm值范围是0~1023
gpio mode 15 out

#初始化参数
fan=0
pwm=0
while true; do
  #获取cpu温度
  tmp=$(cat /sys/class/thermal/thermal_zone0/temp)
  load=$(cat /proc/loadavg | awk '{print $1}')

  #读取配置
  while read line; do
    name=$(echo $line | awk -F '=' '{print $1}')
    value=$(echo $line | awk -F '=' '{print $2}')
    case $name in
    "MODE")
      MODE=$value
      ;;
    "set_temp_min")
      set_temp_min=$value
      ;;
    "shutdown_temp")
      shutdown_temp=$value
      ;;
    "set_temp_max")
      set_temp_max=$value
      ;;
    *) ;;

    esac
  done <$CONF

  if [ $tmp -gt $set_temp_min ] && [ $fan -eq 0 ] && [ $MODE -eq 2 ]; then
    gpio write 15 1
    fan=1
    pwm=1
    echo "$(date) temp=$tmp MODE=$MODE CPU load=$load 超过设置温度开启风扇" #>>$LOG
    sleep 1
  fi

  if [ $tmp -le $shutdown_temp ] && [ $MODE -eq 2 ] && [ $pwm -eq 1 ]; then
    pwm=0
    fan=0
    gpio write 15 $pwm
    sleep 5
    echo "$(date) temp=$tmp MODE=$MODE CPU load=$load 小于设置温度关闭风扇 " #>>$LOG
  else

    #检查MODE，为0时关闭风扇
    if [ $MODE -eq 0 ]; then
      pwm=0
      fan=0
    else
      #检查MODE，为1时持续开启风扇最高转速
      if [ $MODE -eq 1 ]; then
        pwm=1
        fan=1
      fi
    fi

    gpio write 15 $pwm

    loadavg=$(cat /proc/loadavg)
    awk=$(cat /proc/loadavg | awk '{print $0}')
    echo "$(date) temp=$tmp $loadavg $awk load=$load "
    #每5秒钟检查一次温度
    sleep 5
  fi

done
