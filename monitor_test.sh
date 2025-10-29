#!/bin/bash

# Пути и настройки
LOG_FILE="/var/log/monitoring.log"
PID_FILE="/var/run/monitor-test.pid"
API_URL="https://test.com/monitoring/test/api"
PROCESS_NAME="test"

# Создаём лог-файл, если не существует
touch "$LOG_FILE" 2>/dev/null || {
    echo "[$(date)] ERROR: Cannot create log file $LOG_FILE. Exiting." >&2
    exit 1
}

# Функция логгирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Получаем PID текущего процесса 'test' (первый найденный)
get_test_pid() {
    pgrep -f "^$PROCESS_NAME$" 2>/dev/null | head -n1
}

# Основная логика
current_pid=$(get_test_pid)

if [ -z "$current_pid" ]; then
    # Процесс не запущен — ничего не делаем
    exit 0
fi

# Читаем предыдущий PID из временного файла
prev_pid_file="/tmp/monitor-test.lastpid"
if [ -f "$prev_pid_file" ]; then
    prev_pid=$(cat "$prev_pid_file")
else
    prev_pid=""
fi

# Сохраняем текущий PID для следующего запуска
echo "$current_pid" > "$prev_pid_file"

# Проверяем, был ли перезапуск
if [ "$current_pid" != "$prev_pid" ] && [ -n "$prev_pid" ]; then
    log "Process '$PROCESS_NAME' was restarted (old PID: $prev_pid, new PID: $current_pid)"
fi

# Делаем HTTPS-запрос
response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$API_URL" 2>/dev/null)

if [ "$response" = "000" ] || [ -z "$response" ]; then
    # curl не смог подключиться (таймаут, DNS, TLS и т.д.)
    log "Monitoring server $API_URL is unreachable"
elif [ "$response" -ge 400 ]; then
    # HTTP ошибка
    log "Monitoring server returned HTTP error: $response"
fi
