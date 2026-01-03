# Руководство по соло-майнингу TETSUO

Полное руководство по настройке соло-майнинга на блокчейне TETSUO с ASIC-оборудованием.

## Содержание

1. [Введение](#1-введение)
2. [Требования](#2-требования)
3. [Установка ноды TETSUO](#3-установка-ноды-tetsuo)
4. [Установка ckpool](#4-установка-ckpool)
5. [Настройка сети](#5-настройка-сети)
6. [Подключение ASIC-майнеров](#6-подключение-asic-майнеров)
7. [GPU-майнинг](#7-gpu-майнинг)
8. [Интеграция с MiningRigRentals](#8-интеграция-с-miningrigrentals)
9. [Настройка сложности](#9-настройка-сложности)
10. [Мониторинг](#10-мониторинг)
11. [Безопасность](#11-безопасность)
12. [Резервное копирование](#12-резервное-копирование)
13. [Решение проблем](#13-решение-проблем)

---

## 1. Введение

### Что такое TETSUO?

TETSUO — это блокчейн на базе SHA-256, форк Bitcoin, оптимизированный для быстрого времени блока и merge-майнинга.

| Параметр | Значение |
|----------|----------|
| Алгоритм | SHA-256 |
| Время блока | 60 секунд |
| Награда за блок | 10,000 TETSUO |
| Халвинг | Нет (бесконечная эмиссия) |
| Корректировка сложности | Каждые 1440 блоков (~24ч) |
| P2P порт | 8338 |
| RPC порт | 8337 |
| Stratum порт | 3333 |
| Префикс адреса | T |

### Архитектура

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ ASIC Майнер │────▶│   ckpool    │────▶│ Нода TETSUO │
│  (SHA-256)  │     │ (stratum)   │     │  (tetsuod)  │
└─────────────┘     └─────────────┘     └─────────────┘
    :3333              :3333               :8337 (RPC)
                                           :8338 (P2P)
```

- **ASIC Майнер**: Ваше оборудование (Antminer S19, S21 и т.д.)
- **ckpool**: Stratum-сервер, переводящий протокол пула в RPC-вызовы
- **Нода TETSUO**: Полная нода блокчейна для валидации и отправки блоков

---

## 2. Требования

### Железо

| Компонент | Минимум | Рекомендуется |
|-----------|---------|---------------|
| CPU | 2 vCPU | 4+ vCPU |
| RAM | 4 ГБ | 8+ ГБ |
| Диск | 50 ГБ SSD | 100+ ГБ SSD |
| Сеть | 10 Мбит/с | 100+ Мбит/с |

### Операционная система

- Ubuntu 22.04 LTS (рекомендуется)
- Ubuntu 24.04 LTS
- Debian 12

### Сеть

Нужен ОДИН из вариантов:
- **Белый IP** с возможностью проброса портов
- **VPS** для SSH-туннеля (если серый IP)
- **WSL** на Windows с пробросом портов (для разработки)

---

## 3. Установка ноды TETSUO

### 3.1 Установка зависимостей

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake pkgconf python3 \
    libssl-dev libboost-all-dev libevent-dev libsqlite3-dev \
    git automake libtool
```

### 3.2 Клонирование и сборка

```bash
# Клонируем репозиторий
cd ~
git clone https://github.com/Pavelevich/fullchain.git
cd fullchain/tetsuo-core

# Сборка (используйте -j2 если мало RAM)
cmake -B build -DENABLE_IPC=OFF -DWITH_ZMQ=OFF
cmake --build build -j$(nproc)

# Проверка бинарников
ls -la build/bin/
# Должны быть: tetsuod, tetsuo-cli, tetsuo-qt (опционально)
```

### 3.3 Настройка ноды

```bash
# Создаём директорию данных
mkdir -p ~/.tetsuo

# Создаём конфигурацию
cat > ~/.tetsuo/tetsuo.conf << 'EOF'
# Сеть
server=1
daemon=1
listen=1
txindex=1

# RPC (для ckpool)
rpcuser=ckpool
rpcpassword=ВАШ_НАДЁЖНЫЙ_ПАРОЛЬ
rpcport=8337
rpcallowip=127.0.0.1
rpcbind=127.0.0.1

# P2P
port=8338

# Логирование
debug=0
printtoconsole=0
EOF
```

**Важно**: Замените `ВАШ_НАДЁЖНЫЙ_ПАРОЛЬ` на надёжный пароль. Сгенерировать можно так:
```bash
openssl rand -base64 32
```

### 3.4 Запуск ноды

```bash
# Запуск демона
cd ~/fullchain/tetsuo-core
./build/bin/tetsuod -datadir=$HOME/.tetsuo

# Проверка статуса (ждём синхронизации)
./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo getblockchaininfo
```

Нода синхронизируется с сетью. Это может занять несколько часов.

### 3.5 Создание кошелька

```bash
CLI="./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo"

# Создаём кошелёк
$CLI createwallet "mining_wallet"

# Генерируем адрес для наград
$CLI -rpcwallet=mining_wallet getnewaddress

# Сохраните этот адрес! Пример: TApuot7dtebq7stqSrE3mo84ymKbgcC17s
```

---

## 4. Установка ckpool

ckpool — высокопроизводительный stratum-сервер для майнинг-пула.

### 4.1 Клонирование и сборка

```bash
cd ~
git clone https://bitbucket.org/ckolivas/ckpool.git
cd ckpool

# Сборка
./autogen.sh
./configure
make -j$(nproc)

# Проверка
ls -la src/ckpool
```

### 4.2 Настройка ckpool

Создаём конфигурационный файл:

```bash
cat > ~/ckpool/tetsuo.conf << 'EOF'
{
"btcd" : [
    {
        "url" : "127.0.0.1:8337",
        "auth" : "ckpool",
        "pass" : "ВАШ_НАДЁЖНЫЙ_ПАРОЛЬ",
        "notify" : true
    }
],
"btcaddress" : "ВАШ_АДРЕС_TETSUO",
"btcsig" : "/TETSUO Solo Miner/",
"serverurl" : [
    "0.0.0.0:3333"
],
"mindiff" : 50000,
"startdiff" : 100000,
"maxdiff" : 5000000,
"logdir" : "/home/ВАШЕ_ИМЯ_ПОЛЬЗОВАТЕЛЯ/ckpool/logs"
}
EOF
```

**Замените:**
- `ВАШ_НАДЁЖНЫЙ_ПАРОЛЬ` — тот же пароль, что в tetsuo.conf
- `ВАШ_АДРЕС_TETSUO` — адрес вашего майнинг-кошелька
- `ВАШЕ_ИМЯ_ПОЛЬЗОВАТЕЛЯ` — ваше имя пользователя в Linux

### 4.3 Создание директории логов

```bash
mkdir -p ~/ckpool/logs
```

### 4.4 Запуск ckpool

```bash
cd ~/ckpool
./src/ckpool -c tetsuo.conf
```

Для фоновой работы используйте tmux:
```bash
tmux new -s ckpool
cd ~/ckpool && ./src/ckpool -c tetsuo.conf
# Нажмите Ctrl+B, затем D для отсоединения
# Для переподключения: tmux attach -t ckpool
```

---

## 5. Настройка сети

Выберите ваш сценарий:

### 5.1 Белый IP (прямое подключение)

Если у вас белый IP-адрес:

**Шаг 1: Настройка роутера**
- Пробросьте внешний порт 3333 на внутренний IP сервера:3333
- Протокол: TCP

**Шаг 2: Проверка**
```bash
# С другой машины или через онлайн-проверку портов
nc -zv ВАШ_БЕЛЫЙ_IP 3333
```

**Шаг 3: Настройка майнеров**
```
Pool URL: stratum+tcp://ВАШ_БЕЛЫЙ_IP:3333
Worker: ВАШ_АДРЕС_TETSUO
Password: x
```

### 5.2 SSH-туннель (серый IP / за NAT)

Если у вас нет белого IP, используйте VPS как прокси.

**Шаг 1: Арендуйте VPS**
- Любой дешёвый VPS с белым IP (DigitalOcean, Vultr, Hetzner)
- Ubuntu 22.04, 1 vCPU, 1GB RAM достаточно

**Шаг 2: Настройка VPS**

Подключитесь к VPS и включите GatewayPorts:
```bash
sudo nano /etc/ssh/sshd_config
# Добавьте или измените:
GatewayPorts yes

sudo systemctl restart sshd
```

**Шаг 3: Создание туннеля (с вашего сервера майнинга)**

```bash
# Установка sshpass (опционально, для авторизации по паролю)
sudo apt install sshpass

# Создание туннеля
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 \
    -fN -R 0.0.0.0:3333:localhost:3333 user@IP_VPS
```

**Шаг 4: Автоматизация с autossh**

```bash
sudo apt install autossh

# Создание systemd-сервиса
sudo cat > /etc/systemd/system/tetsuo-tunnel.service << 'EOF'
[Unit]
Description=TETSUO Stratum Tunnel
After=network.target

[Service]
User=ВАШЕ_ИМЯ_ПОЛЬЗОВАТЕЛЯ
ExecStart=/usr/bin/autossh -M 0 -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" -o "StrictHostKeyChecking=no" -N -R 0.0.0.0:3333:localhost:3333 user@IP_VPS
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable tetsuo-tunnel
sudo systemctl start tetsuo-tunnel
```

**Шаг 5: Настройка майнеров**
```
Pool URL: stratum+tcp://IP_VPS:3333
Worker: ВАШ_АДРЕС_TETSUO
Password: x
```

### 5.3 WSL (Windows Subsystem for Linux)

Если работаете на Windows с WSL:

**Шаг 1: Получите IP WSL**
```bash
# В терминале WSL
hostname -I
# Пример: 172.26.50.209
```

**Шаг 2: Настройка проброса портов в Windows**

Откройте PowerShell от имени администратора:
```powershell
# Добавление правила проброса
netsh interface portproxy add v4tov4 listenport=3333 listenaddress=0.0.0.0 connectport=3333 connectaddress=IP_WSL

# Добавление правила файрвола
netsh advfirewall firewall add rule name="TETSUO Stratum" dir=in action=allow protocol=tcp localport=3333

# Проверка
netsh interface portproxy show all
```

**Шаг 3: Настройка роутера**
- Пробросьте внешний порт 3333 на IP Windows-ПК:3333

**Примечание**: IP WSL может меняться после перезагрузки. Придётся обновлять правило portproxy.

---

## 6. Подключение ASIC-майнеров

### Формат подключения

| Поле | Значение |
|------|----------|
| Pool URL | `stratum+tcp://ВАШ_IP:3333` |
| Worker | Ваш адрес TETSUO (например, `TApuot7...`) или любое имя |
| Password | `x` (любой) |

### Проверенное оборудование

| Майнер | Алгоритм | Работает |
|--------|----------|----------|
| Antminer S19 | SHA-256 | Да |
| Antminer S19 Pro | SHA-256 | Да |
| Antminer S21 | SHA-256 | Да |
| Whatsminer M30S | SHA-256 | Да |
| Любой SHA-256 ASIC | SHA-256 | Да |

### Пример подключения (Antminer)

1. Откройте веб-интерфейс майнера (обычно `http://IP_МАЙНЕРА`)
2. Перейдите в Miner Configuration
3. Добавьте пул:
   - URL: `stratum+tcp://ВАШ_БЕЛЫЙ_IP:3333`
   - Worker: `TApuot7dtebq7stqSrE3mo84ymKbgcC17s`
   - Password: `x`

---

## 7. GPU-майнинг

TETSUO поддерживает GPU-майнинг на видеокартах NVIDIA с использованием официального CUDA-майнера.

### 7.1 Требования

- **NVIDIA GPU**: Ampere (RTX 30xx), Ada (RTX 40xx), Hopper (H100), Blackwell (B100/B200)
- **CUDA Toolkit**: 12.0 или новее
- **ОС**: Linux (рекомендуется Ubuntu 22.04+)

### 7.2 Ожидаемый хешрейт

| GPU | Хешрейт |
|-----|---------|
| RTX 4090 | ~8 GH/s |
| RTX 4080 | ~6 GH/s |
| RTX 3090 | ~5 GH/s |
| RTX 3080 | ~4 GH/s |

**Примечание**: GPU-майнинг значительно медленнее ASIC. Один Antminer S19 (~100 TH/s) равен ~12,500 видеокартам RTX 4090.

### 7.3 Установка

```bash
# Установка CUDA Toolkit (если не установлен)
# См.: https://developer.nvidia.com/cuda-downloads

# Клонирование репозитория
cd ~
git clone https://github.com/7etsuo/tetsuo-gpu-miner.git
cd tetsuo-gpu-miner

# Сборка
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)

# Проверка
ls -la build/tetsuo-miner
```

### 7.4 Настройка

GPU-майнер подключается напрямую к ноде TETSUO (не к ckpool).

Убедитесь, что в `~/.tetsuo/tetsuo.conf` есть:
```ini
server=1
rpcuser=miner
rpcpassword=ВАШ_ПАРОЛЬ
rpcallowip=127.0.0.1
```

### 7.5 Запуск майнера

```bash
./build/tetsuo-miner \
    -a ВАШ_АДРЕС_TETSUO \
    -o http://127.0.0.1:8337 \
    -u miner \
    -p ВАШ_ПАРОЛЬ
```

**Параметры командной строки:**

| Опция | Описание |
|-------|----------|
| `-a, --address` | Адрес TETSUO для наград |
| `-o, --url` | RPC URL ноды (по умолчанию: http://127.0.0.1:8337) |
| `-u, --user` | Имя пользователя RPC |
| `-p, --pass` | Пароль RPC |
| `-d, --device` | ID GPU (по умолчанию: все GPU) |
| `-b, --block-size` | Размер CUDA-блока (по умолчанию: 256) |
| `-v, --verbose` | Подробный вывод |

### 7.6 Несколько GPU

```bash
# Использовать все GPU (по умолчанию)
./build/tetsuo-miner -a АДРЕС -o URL -u USER -p PASS

# Использовать конкретный GPU
./build/tetsuo-miner -a АДРЕС -o URL -u USER -p PASS -d 0

# Запуск отдельных процессов для каждого GPU (для мониторинга)
./build/tetsuo-miner -a АДРЕС -o URL -u USER -p PASS -d 0 &
./build/tetsuo-miner -a АДРЕС -o URL -u USER -p PASS -d 1 &
```

### 7.7 GPU-майнинг vs ckpool

| Особенность | GPU Miner | ckpool (ASIC) |
|-------------|-----------|---------------|
| Подключение | Напрямую к ноде | Через stratum |
| Протокол | JSON-RPC | Stratum |
| Оборудование | NVIDIA GPU | SHA-256 ASIC |
| Хешрейт | GH/s | TH/s |

---

## 8. Интеграция с MiningRigRentals

[MiningRigRentals](https://www.miningrigrentals.com) позволяет арендовать SHA-256 хешрейт.

### 8.1 Создание аккаунта

1. Зарегистрируйтесь на miningrigrentals.com
2. Пополните баланс (BTC, LTC или другие)

### 8.2 Добавление пула

1. Перейдите в **My Pools** → **Add Pool**
2. Настройте:
   - **Name**: TETSUO Solo
   - **Type**: SHA256
   - **Host**: `ВАШ_БЕЛЫЙ_IP` или `IP_VPS`
   - **Port**: `3333`
   - **Username**: Ваш адрес TETSUO
   - **Password**: `x`

3. Проверьте подключение к пулу

### 8.3 Аренда рига

1. Перейдите в **Rigs** → **SHA256**
2. Фильтруйте по хешрейту и цене
3. Проверьте диапазон **Optimal Difficulty** рига

**КРИТИЧЕСКИ ВАЖНО: Совместимость сложности**

У каждого рига есть диапазон "Optimal Difficulty" (например, "43k - 258k").

Ваш ckpool должен быть настроен для поддержки этого диапазона:
- `mindiff` должен быть ≤ минимальной оптимальной сложности рига
- `startdiff` должен быть в пределах оптимального диапазона рига

| Хешрейт рига | Оптим. сложность | Рекомендуемый startdiff |
|--------------|------------------|------------------------|
| 1-15 TH/s | 43k-258k | 50,000 - 100,000 |
| 15-50 TH/s | 100k-500k | 100,000 - 200,000 |
| 50-200 TH/s | 250k-1M | 200,000 - 500,000 |
| 200+ TH/s | 500k-7M | 500,000+ |

### 8.4 Важные замечания

- **Сетевая сложность имеет значение**: Если сетевая сложность TETSUO ниже минимальной оптимальной сложности рига, риг не сможет генерировать валидные шары
- Всегда проверяйте сетевую сложность перед арендой высокомощных ригов:
  ```bash
  ./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo getmininginfo
  # Смотрите поле "difficulty"
  ```

---

## 9. Настройка сложности

### Как работает Vardiff

ckpool использует переменную сложность (vardiff) для подстройки под каждого майнера:

- **mindiff**: Минимальная сложность (пол)
- **startdiff**: Начальная сложность для новых подключений
- **maxdiff**: Максимальная сложность (потолок)

### Примеры конфигурации

**Для малых майнеров (1-50 TH/s):**
```json
"mindiff" : 50000,
"startdiff" : 100000,
"maxdiff" : 1000000
```

**Для средних майнеров (50-200 TH/s):**
```json
"mindiff" : 100000,
"startdiff" : 300000,
"maxdiff" : 3000000
```

**Для больших майнеров (200+ TH/s):**
```json
"mindiff" : 500000,
"startdiff" : 500000,
"maxdiff" : 7000000
```

### Расчёт оптимальной сложности

Формула: `сложность ≈ хешрейт × целевое_время_шары / 2^32`

Для 1 шары в секунду при 100 TH/s:
```
100 × 10^12 × 1 / 2^32 ≈ 23,283
```

MiningRigRentals рекомендует ~10-60 секунд на шару, поэтому умножьте на 10-60.

### Частая проблема: "0 Hashrate" на мощных ригах

Если высокомощный риг подключается, но показывает 0 хешрейта:

1. Проверьте оптимальную сложность рига на MRR
2. Проверьте текущую сетевую сложность:
   ```bash
   ./build/bin/tetsuo-cli getmininginfo | grep difficulty
   ```
3. Если сетевая сложность < минимальной оптимальной рига → риг не может работать
4. Решение: Используйте менее мощные риги или дождитесь роста сетевой сложности

---

## 10. Мониторинг

### 10.1 Логи ckpool

```bash
# Живой лог
tail -f ~/ckpool/logs/ckpool.log

# Поиск найденных блоков
grep "Solved and confirmed block" ~/ckpool/logs/ckpool.log

# Проверка подключённых воркеров
grep "hashrate1m" ~/ckpool/logs/ckpool.log | tail -5
```

### 10.2 Статус ноды

```bash
CLI="./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo"

# Информация о блокчейне
$CLI getblockchaininfo

# Информация о майнинге
$CLI getmininginfo

# Информация о сети
$CLI getnetworkinfo

# Баланс кошелька
$CLI -rpcwallet=mining_wallet getbalance
```

### 10.3 Дашборд майнинга

Скрипт мониторинга включён в `scripts/tetsuo-stats.sh`.

**Установка:**
```bash
chmod +x ~/fullchain/scripts/tetsuo-stats.sh
```

**Использование:**
```bash
~/fullchain/scripts/tetsuo-stats.sh [секунды_обновления]
# По умолчанию: 5 секунд

# Запуск с обновлением каждые 10 секунд
~/fullchain/scripts/tetsuo-stats.sh 10
```

**Дашборд показывает:**
- Сеть: высота, сложность, хешрейт, пиры
- Ваш майнинг: хешрейт (1м/5м/1ч), доля в сети
- Блоки: найдено, отклонено, процент принятия
- Оценка времени до следующего блока

---

## 11. Безопасность

### 11.1 Безопасность RPC

- **Никогда не открывайте RPC порт (8337) в интернет**
- Используйте сильный уникальный пароль
- Привязывайте RPC только к localhost:
  ```ini
  rpcallowip=127.0.0.1
  rpcbind=127.0.0.1
  ```

### 11.2 Файрвол (ufw)

```bash
# Установка ufw
sudo apt install ufw

# Политики по умолчанию
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Разрешить SSH
sudo ufw allow ssh

# Разрешить P2P (для ноды)
sudo ufw allow 8338/tcp

# Разрешить Stratum (для майнеров)
sudo ufw allow 3333/tcp

# НЕ разрешайте RPC снаружи
# sudo ufw allow 8337/tcp  # НИКОГДА ТАК НЕ ДЕЛАЙТЕ

# Включение файрвола
sudo ufw enable
sudo ufw status
```

### 11.3 Безопасность SSH

```bash
# Генерация SSH-ключа (на вашей локальной машине)
ssh-keygen -t ed25519 -C "mining-server"

# Копирование на сервер
ssh-copy-id user@server

# Отключение авторизации по паролю
sudo nano /etc/ssh/sshd_config
# Установите:
# PasswordAuthentication no
# PermitRootLogin no

sudo systemctl restart sshd
```

### 11.4 Безопасность VPS-туннеля

Пробрасывайте только stratum-порт:
```bash
# Хорошо — только порт 3333
ssh -R 0.0.0.0:3333:localhost:3333 user@vps

# Плохо — проброс RPC
# ssh -R 0.0.0.0:8337:localhost:8337 user@vps  # НИКОГДА ТАК НЕ ДЕЛАЙТЕ
```

---

## 12. Резервное копирование

### 12.1 Что бэкапить

| Элемент | Путь | Приоритет |
|---------|------|-----------|
| Кошелёк | `~/.tetsuo/wallets/` | Критический |
| Конфиг ноды | `~/.tetsuo/tetsuo.conf` | Высокий |
| Конфиг пула | `~/ckpool/tetsuo.conf` | Высокий |

### 12.2 Бэкап кошелька

```bash
CLI="./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo"

# Бэкап в файл
$CLI -rpcwallet=mining_wallet backupwallet ~/wallet-backup.dat

# Копирование в безопасное место
scp ~/wallet-backup.dat user@backup-server:~/
```

### 12.3 Шифрование кошелька

```bash
# Шифрование паролем
$CLI -rpcwallet=mining_wallet encryptwallet "ВАШ_ПАРОЛЬ_КОШЕЛЬКА"

# После шифрования кошелёк автоматически блокируется
# Разблокировка для отправки:
$CLI -rpcwallet=mining_wallet walletpassphrase "ВАШ_ПАРОЛЬ_КОШЕЛЬКА" 300
# 300 = секунд разблокировки
```

### 12.4 Восстановление из бэкапа

```bash
# Остановка ноды
$CLI stop

# Копирование бэкапа в директорию кошельков
cp ~/wallet-backup.dat ~/.tetsuo/wallets/mining_wallet/wallet.dat

# Запуск ноды
./build/bin/tetsuod -datadir=$HOME/.tetsuo

# Загрузка кошелька
$CLI loadwallet mining_wallet
```

---

## 13. Решение проблем

### Туннель постоянно падает

**Симптомы**: Майнеры отключаются, порт VPS не слушает

**Решение 1**: Используйте autossh (см. раздел 5.2)

**Решение 2**: Проверьте зависшие процессы на VPS
```bash
# На VPS
pkill -f "sshd:.*3333"
ss -tlnp | grep 3333
```

**Решение 3**: Используйте прямой проброс портов, если есть белый IP (раздел 5.1)

### Майнеры не подключаются

**Проверка 1**: Работает ли ckpool?
```bash
pgrep -a ckpool
```

**Проверка 2**: Открыт ли порт?
```bash
# Локально
ss -tlnp | grep 3333

# Удалённо (с другой машины)
nc -zv ВАШ_IP 3333
```

**Проверка 3**: Файрвол?
```bash
sudo ufw status
sudo iptables -L -n | grep 3333
```

### 0 Hashrate в пуле

**Симптомы**: Воркеры подключаются, но показывают 0 хешрейта

**Причина 1**: Неправильная сложность
- Проверьте оптимальную сложность рига на MRR
- Подстройте `mindiff` и `startdiff` в конфиге ckpool

**Причина 2**: Сетевая сложность слишком низкая
```bash
./build/bin/tetsuo-cli getmininginfo | grep difficulty
# Если < минимальной оптимальной рига, риг не может работать
```

**Причина 3**: Проверьте логи ckpool
```bash
tail -100 ~/ckpool/logs/ckpool.log | grep -i error
```

### Блок отклонён

**Симптомы**: "REJECTED" в логах ckpool

**Причина 1**: Орфан-блок (другой майнер нашёл блок первым)
- Это нормально в майнинге, особенно при низком хешрейте

**Причина 2**: Нода не синхронизирована
```bash
./build/bin/tetsuo-cli getblockchaininfo
# Сравните "blocks" и "headers"
# Если blocks < headers, нода ещё синхронизируется
```

**Причина 3**: Проблемы с сетью
- Проверьте количество пиров: `./build/bin/tetsuo-cli getconnectioncount`
- Должно быть 8+ пиров

### Нода не запускается

**Проверьте логи:**
```bash
tail -100 ~/.tetsuo/debug.log
```

**Частые проблемы:**
- Порт занят: измените порт в конфиге или убейте существующий процесс
- Повреждённая база: попробуйте `-reindex`
- Диск заполнен: освободите место

### ckpool падает

**Проверьте:**
```bash
# Проблемы с памятью
free -h

# Логи
tail -50 ~/ckpool/logs/ckpool.log
```

**Решение**: Перезапустите ckpool
```bash
pkill ckpool
cd ~/ckpool && ./src/ckpool -c tetsuo.conf
```

### Высокомощный риг (500+ TH) не даёт хешрейт

**Реальный пример**: Арендовали 500 TH риг на MiningRigRentals, воркеры подключаются, но хешрейт = 0.

**Причина**: Оптимальная сложность рига (1,164k - 6,985k) выше текущей сетевой сложности TETSUO (~700k).

**Как это работает**: Риг физически не может генерировать шары с достаточно высокой сложностью, потому что сеть ещё молодая и сложность низкая.

**Решение**:
- Арендуйте риги с меньшей оптимальной сложностью (43k-258k подходит при сложности ~700k)
- Или дождитесь роста сетевой сложности выше 1M

**Как проверить совместимость**:
```bash
# Текущая сетевая сложность
./build/bin/tetsuo-cli getmininginfo | grep difficulty

# Сравните с "Optimal Difficulty" рига на MRR
# Сетевая сложность должна быть >= минимальной оптимальной
```

### Неправильный RPC порт в конфиге

**Симптомы**: ckpool не может подключиться к ноде

**Частая ошибка**: Использование порта 8332 (Bitcoin) вместо 8337 (TETSUO)

**Проверьте конфиги**:
```bash
# В ~/.tetsuo/tetsuo.conf должно быть:
rpcport=8337

# В ~/ckpool/tetsuo.conf должно быть:
"url" : "127.0.0.1:8337"
```

### WSL: IP меняется после перезагрузки

**Симптомы**: После перезагрузки Windows майнеры не подключаются

**Причина**: WSL получает новый IP при каждом запуске

**Решение**: Обновите правило portproxy в PowerShell (от администратора):
```powershell
# Удалить старое правило
netsh interface portproxy delete v4tov4 listenport=3333 listenaddress=0.0.0.0

# Получить новый IP WSL
wsl hostname -I

# Добавить новое правило с новым IP
netsh interface portproxy add v4tov4 listenport=3333 listenaddress=0.0.0.0 connectport=3333 connectaddress=НОВЫЙ_IP_WSL
```

### Туннель "зависает" на VPS

**Симптомы**: Порт 3333 на VPS слушает, но новые подключения не принимаются

**Причина**: Старый SSH процесс завис на VPS

**Решение**:
```bash
# На VPS — убить зависшие процессы
pkill -f "sshd:.*3333"
ss -tlnp | grep 3333 | grep -oP 'pid=\K[0-9]+' | xargs -r kill

# На локальной машине — пересоздать туннель
pkill -f "ssh.*3333"
ssh -fN -R 0.0.0.0:3333:localhost:3333 user@VPS_IP
```

---

## Краткая справка

### Запуск всего

```bash
# 1. Запуск ноды
cd ~/fullchain/tetsuo-core
./build/bin/tetsuod -datadir=$HOME/.tetsuo

# 2. Запуск ckpool
cd ~/ckpool && ./src/ckpool -c tetsuo.conf

# 3. (Если используете туннель) Запуск туннеля
ssh -fN -R 0.0.0.0:3333:localhost:3333 user@IP_VPS
```

### Проверка статуса

```bash
# Нода
./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo getblockchaininfo

# Пул
pgrep -a ckpool
tail -5 ~/ckpool/logs/ckpool.log

# Баланс
./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo -rpcwallet=mining_wallet getbalance
```

### Полезные команды

```bash
# Просмотр хешрейта в реальном времени
tail -f ~/ckpool/logs/ckpool.log | grep hashrate

# Подсчёт найденных блоков
grep -c "Solved and confirmed block" ~/ckpool/logs/ckpool.log

# Дашборд
~/fullchain/scripts/tetsuo-stats.sh
```

---

## Поддержка

- **GitHub**: https://github.com/Pavelevich/fullchain
- **Эксплорер**: https://tetsuoarena.com

---

*Удачного майнинга!*
