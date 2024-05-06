set -u

function get_prev_2_min_filename {
    local time_format="%d_%H-%M"
    time=$(TZ=Europe/Moscow date -d '2 minutes ago' +"$time_format")
    echo "messages/alive/${time}.log"
}

DB_FILE="./db/journal.db"

LOGFILES=(
    "messages/RLS1.log"
    "messages/RLS2.log"
    "messages/RLS3.log"
    "messages/ZRDN1.log"
    "messages/ZRDN2.log"
    "messages/ZRDN3.log"
    "messages/PRO1.log"
)

ITER_TIMEOUT=3

rm -rf "$DB_FILE"
sqlite3 "$DB_FILE" <<Journal_DB_Create
CREATE TABLE IF NOT EXISTS messages (
    time TEXT,
    weapon TEXT,
    message TEXT,
    target_id TEXT,
    target_x TEXT,
    target_y TEXT,
    target_type TEXT
);
Journal_DB_Create

source utils.sh

processed_files="messages/processed_files.txt"
> $processed_files

echo "start handling"

counter=0

while true; do
    # Получаем имя файла 2 минуты назад
    input_file=$(get_prev_2_min_filename)

    if [ -f "$MESSAGE_FILE" ]; then
        while IFS= read -r line; do
            # Разбиваем строку на части по пробелам и присваиваем каждой части переменной
            # decrypted_data=$(echo "$line" | openssl enc -d -aes-256-cbc -pbkdf2 -a -salt -pass pass:"$PASSWD")

            # echo "decrypted_data: $decrypted_data"

            IFS=',' read -r time weapon message target_id target_x target_y target_type <<< "$line"

            # Теперь у вас есть переменные time, weapon, message, target_id, target_x, target_y, target_type, которые содержат значения из текущей строки
            # Далее можно использовать эти переменные для записи в базу данных SQLite3
            # sqlite3 "$DB_FILE" <<INSERT_DATA
            
            sqlite3 ./db/journal.db "insert into messages (time, weapon, message, target_id, target_x, target_y, target_type)
		        values ('$time','$weapon','$message','$target_id','$target_x','$target_y','$target_type');"

            echo "message to db: insert into messages (time, weapon, message, target_id, target_x, target_y, target_type) values ('$time','$weapon','$message','$target_id','$target_x','$target_y','$target_type');"
        done < "$MESSAGE_FILE"
        > $MESSAGE_FILE
    fi

    echo "searching for $input_file"

    if [ -f "$input_file" ]; then

        if ! grep -q "$input_file" "$processed_files"; then
            echo "$input_file" >> "$processed_files"

            declare -A alive_status
            alive_status["RLS1"]="0"
            alive_status["RLS2"]="0"
            alive_status["RLS3"]="0"
            alive_status["ZRDN1"]="0"
            alive_status["ZRDN2"]="0"
            alive_status["ZRDN3"]="0"
            alive_status["PRO1"]="0"

            while IFS= read -r line; do
                decrypted_data=$(echo "$line" | openssl enc -d -aes-256-cbc -pbkdf2 -a -salt -pass pass:"$PASSWD")
                weapon_name=$decrypted_data
                alive_status[$weapon_name]="1"
            done < "$input_file"

            result_message=""
            for weapon_name in "${!alive_status[@]}"; do
                result_message+="weapon name: $weapon_name, status: ${alive_status[$weapon_name]}; "
            done

            time=$(TZ=Europe/Moscow date -d '2 minutes ago' +"%d_%H-%M-%S")
            sqlite3 ./db/journal.db "insert into messages (time, weapon, message, target_id, target_x, target_y, target_type)
		        values ('$time','','$result_message','','','','');"

            echo "alive message to db: insert into messages (time, weapon, message, target_id, target_x, target_y, target_type) values ('$time','','$result_message','','','','');"
		    # echo "${alive[0]} $object_name ${alive[2]} ${alive[3]} ${alive[4]} ${alive[5]} ${alive[6]}"
		    # echo "${alive[0]} $object_name ${alive[2]} ${alive[3]} ${alive[4]} ${alive[5]} ${alive[6]}"


        fi
        # Если файл существует, выводим его содержимое
        # echo "Содержимое файла $input_file:"
        # cat "$input_file"
    else
        echo "File doesn't exists"
    fi

    if [ $counter -eq $ITER_TIMEOUT ]; then
        for logfile in ${LOGFILES[@]}; do
            echo "creating $logfile"
            > $logfile
        done
    fi
    # Задержка между итерациями
    sleep 5
    if [ $counter -eq $ITER_TIMEOUT ]; then
        counter=1
    fi
    ((counter += 1))
    # $counter=($counter+1)
done