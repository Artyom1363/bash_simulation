#!/bin/bash

set -u

source utils.sh

WEAPON_TYPE="RLS"
WEAPON_NUM=$1
RADIUS=$(( $2 * 1000 ))
X=$(( $3 * 1000 ))
Y=$(( $4 * 1000 ))
DIRECTION_ANGLE=$5
VIEWING_ANGLE=$6
PRO_RADIUS=$(( $7 * 1000 ))
PRO_X=$(( $8 * 1000 ))
PRO_Y=$(( $9 * 1000 ))

TARGET=$BAL_BLOCK

half_sector=$(echo "$VIEWING_ANGLE / 2" | bc)
LOWER_BOUND=$(echo "($DIRECTION_ANGLE - $half_sector + 360) % 360" | bc)
UPPER_BOUND=$(echo "($DIRECTION_ANGLE + $half_sector) % 360" | bc)


echo "lower bound: $LOWER_BOUND"
echo "upper bound: $UPPER_BOUND"

if (( $(echo "$LOWER_BOUND > $UPPER_BOUND" | bc -l) )); then
    UPPER_BOUND=$(echo "$UPPER_BOUND + 360" | bc)
fi

echo "lower bound: $LOWER_BOUND"
echo "upper bound: $UPPER_BOUND"


FILE_STAGE1="./temp/${WEAPON_TYPE}${WEAPON_NUM}_state1.log"
FILE_STAGE2="./temp/${WEAPON_TYPE}${WEAPON_NUM}_state2.log"

> $FILE_STAGE1
> $FILE_STAGE2


# находится ли в зоне действия РЛС
function is_in_coverage_sector() {
    local x=$1
    local y=$2
    # echo "check coverage sector: x=$x X=$X y=$y Y=$Y"
    dx=$(echo "$x - $X" | bc)
    dy=$(echo "$y - $Y" | bc)
    distance=$(echo "sqrt($dx^2 + $dy^2)" | bc)
    
    angle_degree=$(awk -v dx="$dx" -v dy="$dy" 'BEGIN { 
        angle = atan2(dy, dx) * (180 / 3.141592653589793); 
        if (angle < 0) angle += 360; 
        print angle; 
    }')

    result=$(echo "$distance <= $RADIUS && $LOWER_BOUND <= $angle_degree && $angle_degree <= $UPPER_BOUND" | bc -l)
    
    if [ "$result" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}

# летит ли цель к ПРО 
function is_in_pro_direction() {
    local x1=$1
    local y1=$2
    local x2=$3
    local y2=$4
    local center_x=$PRO_X
    local center_y=$PRO_Y
    local radius=$PRO_RADIUS

    local k=$(echo "scale=10; ($y2 - $y1) / ($x2 - $x1)" | bc -l)
    local b=$(echo "scale=10; $y1 - $k * $x1" | bc -l)

    local x3=$(echo "scale=10; -($b - ($center_x / $k) - $center_y) / ($k + 1 / $k)" | bc -l)
    local y3=$(echo "scale=10; $k * $x3 + $b" | bc -l)

    # расстояние до центра окружности (center_x, center_y)
    local distance=$(echo "scale=10; sqrt(($x3 - $center_x)^2 + ($y3 - $center_y)^2)" | bc -l)

    if (( $(echo "$distance <= $radius" | bc) )); then
        echo 1
    else
        echo 0
    fi
}


function get_stage() {
    local target_id=$1

    if grep -q "$target_id" "$FILE_STAGE2"; then
        echo "detected"
    elif grep -q "$target_id" "$FILE_STAGE1"; then
        echo "discovered"
    else
        echo "init"
    fi
}


function solver_rls() {

    target_id=$1
    target_x=$2
    target_y=$3

    # echo "Debug in solver: target_id=$target_id x=$target_x y=$target_y"

    if [ "$(is_in_coverage_sector $target_x $target_y)" -eq 1 ]; then
        # echo "is in coverage sector"
        echo $(get_stage "$target_id")
        echo "Debug in coverage sector: target_id=$target_id x=$target_x y=$target_y, X=$X, Y=$Y"
        
        case $(get_stage "$target_id") in
            "discovered")
                previous_coordinates=$(grep "$target_id" "$FILE_STAGE1" | cut -d',' -f2-)
                previous_x=$(echo $previous_coordinates | cut -d',' -f1)
                previous_y=$(echo $previous_coordinates | cut -d',' -f2)

                target_type=$(get_target_type $target_id $target_x $target_y $FILE_STAGE1)

                send_to_kp "target_was_detected" "$target_id" "$target_x" "$target_y" "$target_type"

                echo "$target_id,$target_type,$previous_x,$previous_y,$target_x,$target_y" >> $FILE_STAGE2
                if [[ "$TARGET" == *"$target_type"* ]]; then
                    if [ "$(is_in_pro_direction $previous_x $previous_y $target_x $target_y)" -eq 1 ]; then
                        # echo "debug came"
                        send_to_kp "target_direction_is_in_PRO_zone" "$target_id" "$target_x" "$target_y" "$target_type"
                    fi
                fi
                ;;
            "init")
                echo "$target_id,$target_x,$target_y" >> $FILE_STAGE1
                ;;
        esac
    fi
}


main solver_rls send_alive_message "stub filename"
