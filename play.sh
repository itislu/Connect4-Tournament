#!/bin/bash

export READ_SLOWDOWN=5

ROWS=6
COLS=7

OUTPUT_FD=42
LIB_INTERCEPT=connect4_intercept/connect4_intercept.so
PLAYER1_PIPE=/tmp/player1.pipe
PLAYER2_PIPE=/tmp/player2.pipe
SYNC_PIPE=/tmp/sync.pipe

# Create named pipes
mkfifo $PLAYER1_PIPE $PLAYER2_PIPE $SYNC_PIPE 2>/dev/null

# Check for correct arguments
if [[ $# -lt 2 || $# -gt 3 ]] || [[ "$2" != "1" && "$2" != "2" ]]; then
	echo "Usage: $0 <executable name> <1|2> [slowdown in s]"
	exit 1
fi
PLAYER="$1"
PLAYER_CONFIG="$(basename "$1").config"
PLAYER_NUM="$2"
if [[ -n "$3" ]] && [[ "$3" =~ ^[0-9]+$ ]]; then
	READ_SLOWDOWN="$3"
fi

# Read config file
if [[ ! -x "$PLAYER" ]]; then
	echo "Executable $PLAYER does not exist."
	exit 1
fi
if [[ ! -r "$PLAYER_CONFIG" ]]; then
	echo "Config file $PLAYER_CONFIG does not exist."
	exit 1
fi
source "$PLAYER_CONFIG"

# Check if mandatory variables are set
if [[ ! -v START_PROMPTS || ! -v FIRST_COL_INDEX || ! -v RAND_AI_FIRST || ! -v RAND_PLAYER_FIRST ]]; then
	echo "Mandatory variables not set in $PLAYER_CONFIG."
	echo "The following variables must be set:"
	echo "  - START_PROMPTS"
	echo "  - FIRST_COL_INDEX"
	echo "  - RAND_AI_FIRST"
	echo "  - RAND_PLAYER_FIRST"
	exit 1
fi

# Player config
if [[ "$PLAYER_NUM" = "1" ]]; then
	export RAND_NUMBER="$RAND_AI_FIRST"
	INPUT_PIPE=$PLAYER2_PIPE
	OUTPUT_PIPE=$PLAYER1_PIPE
elif [[ "$PLAYER_NUM" = "2" ]]; then
	export RAND_NUMBER="$RAND_PLAYER_FIRST"
	INPUT_PIPE=$PLAYER1_PIPE
	OUTPUT_PIPE=$PLAYER2_PIPE
fi
export FIRST_COL_INDEX

# Compile intercept library
cc -O3 -shared -fPIC "$(dirname $LIB_INTERCEPT)"/*.c -ldl -o $LIB_INTERCEPT
if [[ ! -f $LIB_INTERCEPT ]]; then
	echo "Failed to compile $LIB_INTERCEPT."
	exit 1
fi

# Synchronization
if [[ "$PLAYER_NUM" = "1" ]]; then
	echo "$PLAYER (Player 1) ready?"
	read -p "Press enter..."
	echo "Waiting for Player 2..."
	echo >$SYNC_PIPE
	read <$SYNC_PIPE
elif [[ "$PLAYER_NUM" = "2" ]]; then
	echo "$PLAYER (Player 2) ready?"
	read -p "Press enter..."
	echo "Waiting for Player 1..."
	read <$SYNC_PIPE
	echo >$SYNC_PIPE
fi

echo "Starting game..."
echo

if [[ -n "$START_PROMPTS" ]]; then
	echo -e "$START_PROMPTS" > "$INPUT_PIPE" &
fi

eval "LD_PRELOAD=$LIB_INTERCEPT $(realpath "$PLAYER") $ROWS $COLS <$INPUT_PIPE $OUTPUT_FD>$OUTPUT_PIPE"