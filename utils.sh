#!/bin/bash

BAL_BLOCK=1
PLANE=2
WINGED_ROCKET=3
TARGETS_DIR="/tmp/GenTargets/Targets"
PASSWD=artvolkov

# для рассчета скорости между двумя засечками (distance / 1 sec)
CONST=1

MESSAGE_FILE='messages/journal.log'


function get_current_filename() {
    local time_format="%d_%H-%M"
    local cur_time=$(date +"$time_format")
    echo "messages/alive/$cur_time.log"
}


function send_alive_message {
    local hello_filename="messages/${WEAPON_TYPE}${WEAPON_NUM}.log"
    if [ -f $hello_filename ]; then
        local output_file=$(get_current_filename)
        echo "${WEAPON_TYPE}${WEAPON_NUM}" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$PASSWD >> "$output_file"
        rm $hello_filename
    fi
}

function send_to_kp {
    time=$(TZ=Europe/Moscow date -d '2 minutes ago' +"%d_%H-%M-%S")
    weapon="${WEAPON_TYPE}${WEAPON_NUM}"
    message=$1
    target_id=$2
    target_x=$3
    target_y=$4
    target_type=$5
    # time="1"
    # weapon="weapon"
    # message="2"
    # target_id="3"
    # target_x="4"
    # target_y="5"
    # target_type="6"
    #  
    echo "${time},${weapon},${message},${target_id},${target_x},${target_y},${target_type}" >> "logs/debug.log"
    #  | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$PASSWD 
    echo "${time},${weapon},${message},${target_id},${target_x},${target_y},${target_type}" >> "$MESSAGE_FILE"
}

function calc_dist {
    local x1=$1
    local y1=$2
    local x2=$3
    local y2=$4
    echo "sqrt((${x1}-${x2})^2 + (${y1}-${y2})^2)" | bc -l
}

function detect_target_type {
    local speed=$1
    is_BAL_BLOCK=$(echo "$speed >= 8000 && $speed <= 10000" | bc)
    is_WINGED_ROCKET=$(echo "$speed >= 250 && $speed <= 1000" | bc)
    is_PLANE=$(echo "$speed >= 50 && $speed <= 249" | bc)
    
    
    if [ "$is_BAL_BLOCK" -eq 1 ]; then
        echo $BAL_BLOCK
    elif [ "$is_WINGED_ROCKET" -eq 1 ]; then
        echo $WINGED_ROCKET
    elif [ "$is_PLANE" -eq 1 ]; then
        echo $PLANE
    else
        echo "garbage"
    fi
}

function get_target_type {
    local target_id=$1
    local target_x=$2
    local target_y=$3
    local FILE_STAGE=$4

    previous_coordinates=$(grep "$target_id" "$FILE_STAGE" | cut -d',' -f2-)
    previous_x=$(echo $previous_coordinates | cut -d',' -f1)
    previous_y=$(echo $previous_coordinates | cut -d',' -f2)
    # echo "in get_target_type: target_x: $target_x target_y: $target_y" 
    distance_between_clocks=$(calc_dist $previous_x $previous_y $target_x $target_y)
    speed=$(echo "$distance_between_clocks / $CONST" | bc -l)
    # echo "detected speed: $speed"
    current_target_type=$(detect_target_type $speed)
    echo $current_target_type
}


function main() {
    local solver=$1
    local cleaner=$2
    local FILE_STAGE_FOR_CLEANER=$3

    while true; do
        TARGET_FILES=$(ls -t $TARGETS_DIR | head -n 100 | tac)
        for target_file in $TARGET_FILES; do
            # echo "target file: $target_file"
            target_id=${target_file:12:6}
            target_coordinates=$(cat "$TARGETS_DIR/$target_file")
            # echo 
            target_x=$(echo $target_coordinates | cut -d',' -f1 | tr -d 'X')
            target_y=$(echo $target_coordinates | cut -d',' -f2 | tr -d 'Y')
            
            if [ -z "$target_x" ]; then
                echo "empty coordinates"
                continue
            fi
            # echo "Debug: ID=$target_id X=$target_x Y=$target_y"
            $solver "$target_id" "$target_x" "$target_y"
            # $solver $target_id $target_x $target_y

        done
        $cleaner $FILE_STAGE_FOR_CLEANER
        sleep 1
    done
}
