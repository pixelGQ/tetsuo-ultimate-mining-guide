#!/bin/bash
# TETSUO Mining Dashboard v2

CLI="/home/pixel/fullchain/tetsuo-core/build/bin/tetsuo-cli"
DATADIR="/home/pixel/.tetsuo"
CKPOOL_LOG="/home/pixel/ckpool/logs/ckpool.log"

# Colors
G='\033[1;32m'   # Green
Y='\033[1;33m'   # Yellow
C='\033[1;36m'   # Cyan
W='\033[1;37m'   # White
M='\033[1;35m'   # Magenta
D='\033[0;90m'   # Dark gray
R='\033[0m'      # Reset
RED='\033[1;31m' # Red

REFRESH=${1:-5}

while true; do
    clear

    # === BLOCKCHAIN DATA ===
    MINING_INFO=$($CLI -datadir=$DATADIR getmininginfo 2>/dev/null)
    BLOCKCHAIN_INFO=$($CLI -datadir=$DATADIR getblockchaininfo 2>/dev/null)
    NET_INFO=$($CLI -datadir=$DATADIR getnetworkinfo 2>/dev/null)
    MEMPOOL_INFO=$($CLI -datadir=$DATADIR getmempoolinfo 2>/dev/null)

    NET_HASH=$(echo "$MINING_INFO" | grep -oP '"networkhashps": \K[0-9.e+]+' 2>/dev/null || echo "0")
    DIFF=$(echo "$MINING_INFO" | grep -oP '"difficulty": \K[0-9.]+' 2>/dev/null | head -1)
    DIFF=${DIFF:-0}
    HEIGHT=$(echo "$BLOCKCHAIN_INFO" | grep -oP '"blocks": \K[0-9]+' 2>/dev/null || echo "0")
    CONNS=$(echo "$NET_INFO" | grep -oP '"connections": \K[0-9]+' 2>/dev/null || echo "0")
    CONNS_IN=$(echo "$NET_INFO" | grep -oP '"connections_in": \K[0-9]+' 2>/dev/null || echo "0")
    CONNS_OUT=$(echo "$NET_INFO" | grep -oP '"connections_out": \K[0-9]+' 2>/dev/null || echo "0")
    MEMPOOL_TX=$(echo "$MEMPOOL_INFO" | grep -oP '"size": \K[0-9]+' 2>/dev/null || echo "0")
    MEMPOOL_BYTES=$(echo "$MEMPOOL_INFO" | grep -oP '"bytes": \K[0-9]+' 2>/dev/null || echo "0")
    CHAIN=$(echo "$BLOCKCHAIN_INFO" | grep -oP '"chain": "\K[^"]+' 2>/dev/null || echo "main")

    # Last block time
    BEST_HASH=$(echo "$BLOCKCHAIN_INFO" | grep -oP '"bestblockhash": "\K[^"]+' 2>/dev/null)
    if [ -n "$BEST_HASH" ]; then
        BLOCK_INFO=$($CLI -datadir=$DATADIR getblock $BEST_HASH 2>/dev/null)
        BLOCK_TIME=$(echo "$BLOCK_INFO" | grep -oP '"time": \K[0-9]+' 2>/dev/null || echo "0")
        NOW=$(date +%s)
        AGO=$((NOW - BLOCK_TIME))
        if [ $AGO -lt 60 ]; then
            BLOCK_AGO="${AGO}s ago"
        elif [ $AGO -lt 3600 ]; then
            BLOCK_AGO="$((AGO / 60))m ago"
        else
            BLOCK_AGO="$((AGO / 3600))h ago"
        fi
    else
        BLOCK_AGO="--"
    fi

    # === CKPOOL DATA ===
    POOL_LINE=$(grep "Pool:{\"runtime" $CKPOOL_LOG 2>/dev/null | tail -1)
    HASH_LINE=$(grep '"hashrate1m"' $CKPOOL_LOG 2>/dev/null | grep "Pool:" | tail -1)
    USER_LINE=$(grep '"hashrate1m"' $CKPOOL_LOG 2>/dev/null | grep "User " | tail -1)
    DIFF_LINE=$(grep "Pool:{\"diff" $CKPOOL_LOG 2>/dev/null | tail -1)

    WORKERS=$(echo "$POOL_LINE" | grep -oP '"Workers": \K[0-9]+' 2>/dev/null || echo "0")
    USERS=$(echo "$POOL_LINE" | grep -oP '"Users": \K[0-9]+' 2>/dev/null || echo "0")
    IDLE=$(echo "$POOL_LINE" | grep -oP '"Idle": \K[0-9]+' 2>/dev/null || echo "0")

    MY_HASH_1M=$(echo "$HASH_LINE" | grep -oP '"hashrate1m": "\K[^"]+' 2>/dev/null || echo "0")
    MY_HASH_5M=$(echo "$HASH_LINE" | grep -oP '"hashrate5m": "\K[^"]+' 2>/dev/null || echo "0")
    MY_HASH_1H=$(echo "$HASH_LINE" | grep -oP '"hashrate1hr": "\K[^"]+' 2>/dev/null || echo "0")

    # Convert hashrate to number for calculations (support T/G/M/K)
    # Handle decimal values like "8.19T" properly
    if [[ "$MY_HASH_1M" == *T* ]]; then
        MY_HASH_NUM=$(echo "$MY_HASH_1M" | sed 's/T//' | awk '{printf "%.0f", $1 * 1000000000000}')
    elif [[ "$MY_HASH_1M" == *G* ]]; then
        MY_HASH_NUM=$(echo "$MY_HASH_1M" | sed 's/G//' | awk '{printf "%.0f", $1 * 1000000000}')
    elif [[ "$MY_HASH_1M" == *M* ]]; then
        MY_HASH_NUM=$(echo "$MY_HASH_1M" | sed 's/M//' | awk '{printf "%.0f", $1 * 1000000}')
    elif [[ "$MY_HASH_1M" == *K* ]]; then
        MY_HASH_NUM=$(echo "$MY_HASH_1M" | sed 's/K//' | awk '{printf "%.0f", $1 * 1000}')
    else
        MY_HASH_NUM=${MY_HASH_1M:-0}
    fi
    MY_HASH_NUM=${MY_HASH_NUM:-0}

    # Calculate total hashrate (others + ours)
    OTHERS_HASH=$NET_HASH
    if [ "$MY_HASH_NUM" != "0" ]; then
        TOTAL_HASH=$(echo "$OTHERS_HASH + $MY_HASH_NUM" | bc 2>/dev/null || echo "$OTHERS_HASH")
    else
        TOTAL_HASH=$OTHERS_HASH
    fi

    # Network share from TOTAL hashrate
    if [ "$TOTAL_HASH" != "0" ] && [ "$MY_HASH_NUM" != "0" ]; then
        PCT=$(echo "scale=2; $MY_HASH_NUM * 100 / $TOTAL_HASH" | bc 2>/dev/null || echo "0")
    else
        PCT="0"
    fi

    ACCEPTED=$(echo "$DIFF_LINE" | grep -oP '"accepted": \K[0-9]+' 2>/dev/null || echo "0")
    REJECTED=$(echo "$DIFF_LINE" | grep -oP '"rejected": \K[0-9]+' 2>/dev/null || echo "0")
    BEST_SHARE=$(echo "$USER_LINE" | grep -oP '"bestever":\K[0-9.]+' 2>/dev/null || echo "0")
    SHARES=$(echo "$USER_LINE" | grep -oP '"shares": \K[0-9]+' 2>/dev/null || echo "0")

    # Blocks found (from ckpool log)
    BLOCKS_FOUND=$(grep -c "Solved and confirmed block" $CKPOOL_LOG 2>/dev/null || echo "0")
    BLOCKS_REJECTED=$(grep -c "block.*REJECTED" $CKPOOL_LOG 2>/dev/null || echo "0")

    # Block acceptance rate
    TOTAL_BLOCKS=$((BLOCKS_FOUND + BLOCKS_REJECTED))
    if [ "$TOTAL_BLOCKS" -gt 0 ]; then
        ACCEPT_RATE=$(echo "scale=1; $BLOCKS_FOUND * 100 / $TOTAL_BLOCKS" | bc 2>/dev/null || echo "0")
    else
        ACCEPT_RATE="--"
    fi

    # Last block we found
    LAST_BLOCK_LINE=$(grep "Solved and confirmed block" $CKPOOL_LOG 2>/dev/null | tail -1)
    LAST_BLOCK=$(echo "$LAST_BLOCK_LINE" | grep -oP "block \K[0-9]+" 2>/dev/null || echo "--")

    # Average time per block (from last 10 blocks in log)
    BLOCK_TIMES=$(grep "Solved and confirmed block" $CKPOOL_LOG 2>/dev/null | tail -10 | while read line; do
        echo "$line" | grep -oP '^\[\K[0-9-]+ [0-9:.]+'
    done)
    BLOCK_COUNT=$(echo "$BLOCK_TIMES" | wc -l)
    if [ "$BLOCK_COUNT" -gt 1 ]; then
        FIRST_TIME=$(echo "$BLOCK_TIMES" | head -1)
        LAST_TIME=$(echo "$BLOCK_TIMES" | tail -1)
        FIRST_SEC=$(date -d "$FIRST_TIME" +%s 2>/dev/null || echo "0")
        LAST_SEC=$(date -d "$LAST_TIME" +%s 2>/dev/null || echo "0")
        TIME_DIFF=$((LAST_SEC - FIRST_SEC))
        if [ "$TIME_DIFF" -gt 0 ] && [ "$BLOCK_COUNT" -gt 1 ]; then
            AVG_BLOCK_TIME=$((TIME_DIFF / (BLOCK_COUNT - 1)))
            if [ "$AVG_BLOCK_TIME" -lt 60 ]; then
                AVG_BLOCK_STR="${AVG_BLOCK_TIME}s"
            else
                AVG_BLOCK_STR="$((AVG_BLOCK_TIME / 60))m $((AVG_BLOCK_TIME % 60))s"
            fi
        else
            AVG_BLOCK_STR="--"
        fi
    else
        AVG_BLOCK_STR="--"
    fi

    # Estimated time to next block (based on network share)
    if [ "$MY_HASH_NUM" != "0" ] && [ "$MY_HASH_NUM" != "" ] && [ "$TOTAL_HASH" != "0" ]; then
        # Time = 60 sec (block time) / (my_share)
        # my_share = MY_HASH_NUM / TOTAL_HASH
        EST_TIME=$(echo "scale=0; 60 * $TOTAL_HASH / $MY_HASH_NUM" | bc 2>/dev/null || echo "0")
        if [ -n "$EST_TIME" ] && [ "$EST_TIME" -gt 0 ] 2>/dev/null; then
            if [ "$EST_TIME" -lt 60 ]; then
                EST_TIME_STR="${EST_TIME}s"
            elif [ "$EST_TIME" -lt 3600 ]; then
                EST_TIME_STR="$((EST_TIME / 60))m $((EST_TIME % 60))s"
            else
                EST_TIME_STR="$((EST_TIME / 3600))h $((EST_TIME % 3600 / 60))m"
            fi
        else
            EST_TIME_STR="<1s"
        fi
    else
        EST_TIME_STR="--"
    fi

    # Network share calculation (already computed above for EST_TIME)

    # Format numbers - helper function
    format_hashrate() {
        local hash=$1
        local gh_raw=$(echo "scale=2; $hash / 1000000000" | bc -l 2>/dev/null || echo "0")
        local gh_int=${gh_raw%.*}
        gh_int=${gh_int:-0}
        if [ "$gh_int" -ge 1000 ] 2>/dev/null; then
            printf "%.2f TH/s" $(echo "$gh_raw / 1000" | bc -l)
        else
            printf "%.2f GH/s" "$gh_raw"
        fi
    }

    # Format hashrates
    OTHERS_HASH_STR=$(format_hashrate $OTHERS_HASH)
    TOTAL_HASH_STR=$(format_hashrate $TOTAL_HASH)
    DIFF_SHORT=$(printf "%.2f" "$DIFF" 2>/dev/null || echo "0")
    MEMPOOL_KB=$(echo "scale=1; $MEMPOOL_BYTES / 1024" | bc 2>/dev/null || echo "0")

    # Block reward (TETSUO = 10000)
    REWARD="10,000"

    # === DISPLAY ===
    echo ""
    echo -e "${W}═══════════════════════════════════════════════════════${R}"
    echo -e "${W}              TETSUO MINING DASHBOARD                   ${R}"
    echo -e "${W}═══════════════════════════════════════════════════════${R}"
    echo ""

    echo -e "${Y}[ NETWORK ]${R}"
    echo -e "  Chain:            ${C}${CHAIN}${R}"
    echo -e "  Block Height:     ${W}${HEIGHT}${R}  ${D}(${BLOCK_AGO})${R}"
    echo -e "  Difficulty:       ${W}${DIFF_SHORT}${R}"
    echo -e "  Others Hashrate:  ${D}${OTHERS_HASH_STR}${R}  ${D}(without us)${R}"
    echo -e "  Total Hashrate:   ${G}${TOTAL_HASH_STR}${R}  ${D}(others + ours)${R}"
    echo -e "  Block Reward:     ${G}${REWARD} TETSUO${R}"
    if [ "$MEMPOOL_TX" -eq 0 ]; then
        echo -e "  Mempool:          ${D}empty${R}  ${D}(no pending tx)${R}"
    else
        echo -e "  Mempool:          ${W}${MEMPOOL_TX} tx${R}  ${D}(${MEMPOOL_KB} KB)${R}"
    fi
    echo -e "  Peers:            ${W}${CONNS}${R}  ${D}(in: ${CONNS_IN}, out: ${CONNS_OUT})${R}"
    echo ""

    echo -e "${Y}[ MY MINING ]${R}"
    echo -e "  Hashrate (1m):    ${G}${MY_HASH_1M}${R}"
    echo -e "  Hashrate (5m):    ${G}${MY_HASH_5M}${R}"
    echo -e "  Hashrate (1hr):   ${G}${MY_HASH_1H}${R}"
    echo -e "  Network Share:    ${M}${PCT}%${R}  ${D}(of total hashrate)${R}"
    echo ""

    # Calculate confirmed blocks
    BLOCKS_CONFIRMED=$((BLOCKS_FOUND - BLOCKS_REJECTED))
    if [ "$BLOCKS_CONFIRMED" -lt 0 ]; then
        BLOCKS_CONFIRMED=0
    fi

    echo -e "${Y}[ BLOCKS FOUND ]${R}"
    echo -e "  Confirmed:        ${G}${BLOCKS_CONFIRMED}${R}  ${D}(found: ${BLOCKS_FOUND}, rejected: ${BLOCKS_REJECTED})${R}"
    echo -e "  Accept Rate:      ${G}${ACCEPT_RATE}%${R}"
    echo -e "  Last Block:       ${W}${LAST_BLOCK}${R}"
    echo -e "  Avg Block Time:   ${C}${AVG_BLOCK_STR}${R}  ${D}(last 10 blocks)${R}"
    echo -e "  Est. Next Block:  ${M}${EST_TIME_STR}${R}  ${D}(at current hashrate)${R}"
    echo ""

    echo -e "${D}═══════════════════════════════════════════════════════${R}"
    echo -e "${D}Updated: $(date '+%H:%M:%S')  |  Refresh: ${REFRESH}s  |  Ctrl+C exit${R}"

    sleep $REFRESH
done
