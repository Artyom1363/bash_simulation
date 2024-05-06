#!/bin/bash

# детектирование обращения к необъявленным переменным
set -u

source utils.sh

SHOOTS=0

WEAPON_TYPE=$1
WEAPON_NUM=$2
# перевод в метры
RADIUS=$(( $3 * 1000 ))
X=$(( $4 * 1000 ))
Y=$(( $5 * 1000 ))

if [ "$WEAPON_TYPE" == "PRO" ]; then
    TARGET=$BAL_BLOCK
    SHOOTS=20
elif [ "$WEAPON_TYPE" == "ZRDN" ]; then
    TARGET="$PLANE,$WINGED_ROCKET"
    SHOOTS=10
fi


FILE_STAGE1="./temp/${WEAPON_TYPE}${WEAPON_NUM}_state1.log"
FILE_STAGE2="./temp/${WEAPON_TYPE}${WEAPON_NUM}_state2.log"
FILE_STAGE3="./temp/${WEAPON_TYPE}${WEAPON_NUM}_state3.log"


FILE_STAGE3_TEMP="./temp/${WEAPON_TYPE}${WEAPON_NUM}_state3_temp.log"
DESTROY_DIR="/tmp/GenTargets/Destroy"

> $FILE_STAGE1
> $FILE_STAGE2
> $FILE_STAGE3


# ''
function get_stage() {
    local target_id="$1"
    if grep -q "$target_id" "$FILE_STAGE3"; then
        echo "shot"
    elif grep -q "$target_id" "$FILE_STAGE2"; then
        echo "detected"
    elif grep -q "$target_id" "$FILE_STAGE1"; then
        echo "discovered"
    else
        echo "init"
    fi
}


function filter_targets() {
    local log_file=$1
    # echo "start filtering targets:"
    while IFS=',' read -r target_id target_type target_x target_y status; do
        if [ "$status" -eq 1 ]; then
            echo "target killed $target_id $target_type"
        fi
    done < "$log_file"

    sed -i '/,1$/d' "$log_file"

    # Замена 0 на 1 для записей, оканчивающихся на 0
    sed -i '/,0$/s/0$/1/' "$log_file"

    send_alive_message
}

function handle_shoot() {
    local target_id=$1
    local target_type=$2
    local target_x=$3
    local target_y=$4
    local stage=$5
    

    if [ $stage == "3" ]; then
        # на стадии 3 цели, в которые уже хотя бы раз стреляли
        send_to_kp "miss_target" "$target_id" "$target_type" "$target_x" "$target_y"
    fi

    if [ $SHOOTS -gt 0 ]; then
        ((SHOOTS--))
        echo "$target_id" > "$DESTROY_DIR/$target_id"
        # модифицируем уже существующую запись, меня флаг
        if [ $stage == "3" ]; then
            # echo ""
            if ! grep -q "^$target_id," "$FILE_STAGE3"; then
                echo "Запись с id $target_id не найдена в файле."
            fi

            # 2. Изменение последнего числа на 0 для записи с id, равным target_id
            sed -i "/^$target_id,/ s/,[01]$/,0/" "$FILE_STAGE3"

        else
            echo "$target_id,$target_type,$target_x,$target_y,0" >> $FILE_STAGE3
            # echo "debug echo log " "$target_id" "$target_type" "$target_x" "$target_y 0"
        fi
        send_to_kp "shot_at_target" "$target_id" "$target_type" "$target_x" "$target_y"
    else 
        send_to_kp "shot_is_not_possible_on_target" "$target_id" "$target_type" "$target_x" "$target_y"
    fi
}


function weapon_solver() {

    target_id=$1
    target_x=$2
    target_y=$3

    # echo "in main iteration: target_x: $target_x target_y: $target_y"
    distance_to_target=$(calc_dist $X $Y $target_x $target_y)

    if (( $(echo "$distance_to_target <= $RADIUS" | bc -l) )); then

        echo "see aim! target_x: $target_x target_y: $target_y"

        case $(get_stage "$target_id") in
            "shot")
                target_type=$(grep "$target_id" "$FILE_STAGE3" | cut -d',' -f2)
                handle_shoot "$target_id" "$target_type" "$target_x" "$target_y" "3"
                ;;
            "discovered")
                target_type=$(get_target_type $target_id $target_x $target_y $FILE_STAGE1)
                
                send_to_kp "target_detected" "$target_id" "$target_type" "$target_x" "$target_y"
                echo "$target_id,$target_type" >> $FILE_STAGE2
                if [[ "$TARGET" == *"$target_type"* ]]; then
                    handle_shoot "$target_id" "$target_type" "$target_x" "$target_y" "1"
                fi
                ;;
            "init")
                echo "$target_id,$target_x,$target_y" >> $FILE_STAGE1
                ;;
        esac
    fi
}


main weapon_solver filter_targets $FILE_STAGE3
