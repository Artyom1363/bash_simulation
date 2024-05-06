#!/bin/bash

GEN_FILE="GenTargets.sh"
TARGETS_DIR="tmp/GenTargets"

RLS1_PARAMS="1 3000 9500 3000 315 120 1400 7500 3400"

RLS2_PARAMS="2 3000 8000 7000 90 120 1400 7500 3400"

RLS3_PARAMS="3 4000 11000 8000 45 200 1400 7500 3400"


ZRDN1_PARAMS="ZRDN 1 600 6200 3500"

ZRDN2_PARAMS="ZRDN 2 300 4400 3700"

ZRDN3_PARAMS="ZRDN 3 650 5500 3700"

PRO_PARAMS="PRO 1 1400 7500 3400"


RLS_LOG_FILE="rls_log"

ZRDN_LOG_FILE="zrdn_log"

PRO_LOG_FILE="pro_log"

KP_LOG_FILE='kp_log'

# get_pid_by_name = ps aux | grep "$(1)" | grep -v grep | head -n1 | tr -s ' ' | cut -d' ' -f 2
# stop_process = kill $(call get_pid_by_name,$(1))

./GenTargets.sh > logs/GenTargets.log 2>&1 &
echo $! >> pid.txt

sleep 1


# launch rls
./rls.sh $RLS1_PARAMS > logs/${RLS_LOG_FILE}.rls1.log 2>&1 &
echo $! >> pid.txt

./rls.sh $RLS2_PARAMS > logs/${RLS_LOG_FILE}.rls2.log 2>&1 &
echo $! >> pid.txt

./rls.sh $RLS3_PARAMS > logs/${RLS_LOG_FILE}.rls3.log 2>&1 &
echo $! >> pid.txt



# launch zrdn

./weapon.sh $ZRDN1_PARAMS > logs/${ZRDN_LOG_FILE}.zrdn1.log 2>&1 &
echo $! >> pid.txt

./weapon.sh $ZRDN2_PARAMS > logs/${ZRDN_LOG_FILE}.zrdn2.log 2>&1 &
echo $! >> pid.txt

./weapon.sh $ZRDN3_PARAMS > logs/${ZRDN_LOG_FILE}.zrdn3.log 2>&1 &
echo $! >> pid.txt

# launch pro

./weapon.sh $PRO_PARAMS > logs/${PRO_LOG_FILE}.pro.log 2>&1 &
echo $! >> pid.txt


# launch kp

./kp.sh > logs/${KP_LOG_FILE}.kp.log 2>&1 &
echo $! >> pid.txt