#!/bin/bash

# Путь к файлу с PID
PID_FILE="pid.txt"


target_pids=$(cat $PID_FILE)

echo $target_pids
for target_file in $target_pids; do
    kill -9 $target_file
done
# Чтение каждой строки файла
# while IFS= read -r pid
# do
#     # Убедимся, что PID представляет собой число
#     if [[ "$pid" =~ ^[0-9]+$ ]]; then
#         echo "Завершение процесса с PID $pid"
#         kill -9 "$pid"
#     else
#         echo "Некорректный PID: '$pid'"
#     fi
# done < "$PID_FILE"

# Опционально: Очистить файл после завершения всех процессов
> $PID_FILE
