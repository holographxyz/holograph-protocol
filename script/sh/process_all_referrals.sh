#!/bin/bash

# Automated script to process entire CSV in manageable chunks
# Usage: ./process_all_referrals.sh

set -e

# Configuration
CHUNK_SIZE=500
CSV_PATH="./script/csv/rewards-allocation-clean.csv"

# Dynamically count users in CSV (subtract 1 for header row)
if [ ! -f "$CSV_PATH" ]; then
    echo "❌ Error: CSV file not found at $CSV_PATH"
    exit 1
fi

TOTAL_LINES=$(wc -l < "$CSV_PATH")
TOTAL_USERS=$((TOTAL_LINES - 1))  # Subtract header row

echo "CSV file: $CSV_PATH"
echo "Total lines in CSV: $TOTAL_LINES"
echo "Total users (excluding header): $TOTAL_USERS"

# Environment variables (set these before running)
PRIVATE_KEY="${PRIVATE_KEY:-0x1234567890123456789012345678901234567890123456789012345678901234}"
STAKING_REWARDS="${STAKING_REWARDS:-0xff5CEBc016f50d40D4C1eCaDB7427c5F3E3c3f97}"
HLG_TOKEN="${HLG_TOKEN:-0x5Ff07042d14E60EC1de7a860BBE968344431BaA1}"
DRY_RUN="${DRY_RUN:-true}"

echo ""
echo "Starting automated referral CSV processing"
echo "Chunk size: $CHUNK_SIZE users"
echo "Mode: $([ "$DRY_RUN" = "true" ] && echo "DRY RUN" || echo "LIVE EXECUTION")"
echo ""

# Run validation-only function to verify CSV is valid
echo "Validating CSV structure and content..."
VALIDATION_OUTPUT=$(REFERRAL_CSV_PATH="$CSV_PATH" \
   forge script script/admin/ProcessReferralCSV.s.sol \
   --tc ProcessReferralCSV \
   --sig "validateOnly(uint256,uint256)" \
   0 1 \
   --no-storage-caching 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ CSV validation passed"

    # Extract and display key validation info
    echo "$VALIDATION_OUTPUT" | grep -E "(Total users found|Total allocation|Allocation utilization)" | while read line; do
        echo "  $line"
    done

    echo "✅ Proceeding with all chunks"
else
    echo "❌ CSV validation failed! Check the CSV file and try again."
    echo "$VALIDATION_OUTPUT"
    exit 1
fi
echo ""

# Track execution time and gas
START_TIME=$(date +%s)
TOTAL_GAS=0

# Calculate total chunks needed
TOTAL_CHUNKS=$(( (TOTAL_USERS + CHUNK_SIZE - 1) / CHUNK_SIZE ))

for ((chunk=0; chunk<TOTAL_CHUNKS; chunk++)); do
    start_index=$((chunk * CHUNK_SIZE))
    remaining_users=$((TOTAL_USERS - start_index))
    users_in_chunk=$(( remaining_users < CHUNK_SIZE ? remaining_users : CHUNK_SIZE ))
    end_index=$((start_index + users_in_chunk))

    processed_so_far=$((start_index + users_in_chunk))
    progress_pct=$(( (processed_so_far * 100) / TOTAL_USERS ))

    echo "Processing chunk $((chunk + 1))/$TOTAL_CHUNKS"
    echo "Users $start_index to $((end_index - 1)) ($users_in_chunk users) - $progress_pct% complete"

    # Run the forge script with current chunk
    FORGE_OUTPUT=$(PRIVATE_KEY="$PRIVATE_KEY" \
       STAKING_REWARDS="$STAKING_REWARDS" \
       HLG_TOKEN="$HLG_TOKEN" \
       REFERRAL_CSV_PATH="$CSV_PATH" \
       REFERRAL_RESUME_INDEX="$start_index" \
       BATCH_SIZE="50" \
       DRY_RUN="$DRY_RUN" \
       forge script script/admin/ProcessReferralCSV.s.sol \
       --tc ProcessReferralCSV \
       --sig "runRange(uint256,uint256)" \
       $start_index $users_in_chunk \
       --no-storage-caching \
       --gas-limit 600000000 2>&1 | grep -v "Compiling\|⠊\|⠒\|⠘\|⠑\|⠸\|⠼\|⠴\|⠦\|⠧\|⠇\|⠏")

    if [ $? -eq 0 ]; then
        # Extract gas used from output
        GAS_USED=$(echo "$FORGE_OUTPUT" | grep "Gas used:" | tail -1 | sed 's/.*Gas used: //' | sed 's/[^0-9]//g')
        if [ -n "$GAS_USED" ] && [ "$GAS_USED" != "" ]; then
            TOTAL_GAS=$((TOTAL_GAS + GAS_USED))
            GAS_DISPLAY=$(printf "%'d" $GAS_USED)
        else
            GAS_DISPLAY="Unknown"
        fi

        echo "✅ Chunk $((chunk + 1)) completed (Gas: ${GAS_DISPLAY})"
        echo ""
    else
        echo "❌ Chunk $((chunk + 1)) failed!"
        echo "To resume from this point, run:"
        echo "   REFERRAL_RESUME_INDEX=$start_index ./process_all_referrals.sh"
        exit 1
    fi
done

# Calculate execution time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo "✅ All chunks completed successfully!"
echo "Processed $TOTAL_USERS users total"
echo "Total gas used: $(printf "%'d" $TOTAL_GAS)"
echo "Execution time: ${MINUTES}m ${SECONDS}s"
echo "$([ "$DRY_RUN" = "true" ] && echo "This was a DRY RUN. Use 'make process-referrals-mainnet' for real execution." || echo "✅ MAINNET EXECUTION completed.")"