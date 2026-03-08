#!/bin/sh
# ============================================================================
#
#  ping2km - Ping with estimated distance based on the speed of light
#
#  Author  : DeuZa <deuza@deuza.net>
#  License : CC0 (https://creativecommons.org/publicdomain/zero/1.0/)
#            WTFPL (http://www.wtfpl.net/)
#  Version : see $VERSION below
#  Repo    : https://github.com/deuza/ping2km
#  README  : https://github.com/deuza/ping2km/blob/main/README.md
#
# ============================================================================

# --- Exit on error, unset variables, pipeline errors ------------------------

set -euo pipefail

# --- Configuration ----------------------------------------------------------

VERSION="1.0.0"
PROGNAME=$(basename "$0")

# Default medium: fiber optic (2/3 c)
# Conversion factor: (1/1000/2) * 199861 = 99.9305
MEDIUM="fiber"
LIGHT_FACTOR="99.9305"
MODEM_OVERHEAD=0

# Packet count: 0 = infinite (default)
COUNT=0

# Commands (no absolute paths for portability)
PING="ping -c 1"

# --- Global variables for statistics ----------------------------------------

CPT=0           # packets sent counter
RECV=0          # packets received counter
MIN=""          # minimum RTT observed
MAX=""          # maximum RTT observed
SUM=0           # sum of RTTs for average calculation
SUM_SQ=0        # sum of squared RTTs for mdev calculation
TARGET=""       # target host
RESOLVED_IP=""  # resolved IP address for display
START_MS=""     # start timestamp in milliseconds

# --- Functions ---------------------------------------------------------------

# Display full help
usage() {
    echo "$PROGNAME v$VERSION - Ping with estimated distance based on the speed of light"
    echo ""
    echo "Usage: $PROGNAME [--fiber|--copper|--theoretical|--dialup] [-4] [-c count] <host>"
    echo "       $PROGNAME [--help|--version]"
    echo ""
    echo "Arguments:"
    echo "  <host>        Hostname or IP address to ping"
    echo ""
    echo "Options:"
    echo "  --fiber       Use fiber optic model: 2/3 c ~ 199,861 km/s (default)"
    echo "  --copper      Use real copper twisted pair model: ~2/3 c ~ 197,863 km/s"
    echo "  --theoretical Use speed of light in vacuum: c ~ 299,792 km/s"
    echo "  --dialup      Simulate dial-up era: subtract ~120 ms modem overhead"
    echo "  -4            Force IPv4 (passed to ping)"
    echo "  -c count      Stop after sending count packets (like ping -c)"
    echo "  --help, -h    Display this help"
    echo "  --version, -V Display version"
    echo ""
    echo "How it works:"
    echo "  Four transmission models are available:"
    echo "    fiber:       distance = RTT_ms * 99.9305 km   (2/3 c ~ 199,861 km/s)"
    echo "    copper:      distance = RTT_ms * 98.93 km     (2/3 c ~ 197,863 km/s)"
    echo "    theoretical: distance = RTT_ms * 149.896 km   (c ~ 299,792 km/s)"
    echo "    dialup:      distance = (RTT_ms - 120) * 99.9305 km"
    echo "  Since RTT is a round trip: distance = (RTT_ms / 1000 / 2) * speed"
    echo ""
    echo "  Spoiler: fiber and copper give nearly identical results (~1%"
    echo "  difference), because signal propagation speed is about 2/3 c in"
    echo "  both media. The real difference between fiber and copper is"
    echo "  bandwidth and attenuation, not signal speed."
    echo ""
    echo "  The dialup mode subtracts the typical analog modem encoding/"
    echo "  decoding overhead (~120 ms round trip) before calculating the"
    echo "  distance. Back in the RTC days, the world was smaller."
    echo ""
    echo "Disclaimer:"
    echo "  This estimation is intentionally naive! It does not account for"
    echo "  router/switch/firewall latency, network topology detours, buffering,"
    echo "  or application-level processing. Meant for fun, not for calibrating"
    echo "  interferometers. ;-)"
    echo ""
    echo "Compatibility:"
    echo "  Tested on Debian GNU/Linux, FreeBSD 13.x/14.x, macOS (Darwin)."
    echo "  Strictly POSIX: sed, shell arithmetic, bc. No GNU-isms, no PCRE."
    echo ""
    echo "Examples:"
    echo "  $PROGNAME minig.deuza.bzh"
    echo "  $PROGNAME -c 5 minig.deuza.bzh"
    echo "  $PROGNAME --copper 1.1.1.1"
    echo "  $PROGNAME --theoretical www.kernel.org"
    echo "  $PROGNAME --dialup -4 -c 10 www.kernel.org"
    echo ""
    echo "Hit Ctrl+C to stop: a statistics summary will be displayed."
    exit 0
}

# Display version
version() {
    echo "$PROGNAME v$VERSION"
    exit 0
}

# Check that a binary is available in PATH
# Usage: check_bin <command_name>
check_bin() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo "ERROR: '$1' not found in \$PATH." >&2
        echo "       Install it before running $PROGNAME." >&2
        exit 1
    fi
}

# Check that the OS is supported (Linux, FreeBSD or macOS)
check_os() {
    OS=$(uname -s)
    case "$OS" in
        Linux|FreeBSD|Darwin)
            ;;
        *)
            echo "ERROR: unsupported OS ($OS)." >&2
            echo "       $PROGNAME supports Linux, FreeBSD and macOS." >&2
            exit 1
            ;;
    esac
}

# Return current timestamp in milliseconds
# Uses date +%s%N on Linux, perl fallback on FreeBSD/macOS
get_ms() {
    if date +%s%N > /dev/null 2>&1; then
        echo $(($(date +%s%N) / 1000000))
    else
        perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000'
    fi
}

# Calculate distance from RTT, accounting for modem overhead in dialup mode
# Usage: calc_distance <rtt_ms>
# Outputs distance in km (integer), or "0" if RTT < modem overhead
calc_distance() {
    _rtt="$1"
    if [ "$MODEM_OVERHEAD" -gt 0 ]; then
        _effective=$(echo "$_rtt - $MODEM_OVERHEAD" | bc)
        _positive=$(echo "$_effective > 0" | bc)
        if [ "$_positive" = "1" ]; then
            printf "%.0f" "$(echo "scale=2; $_effective * $LIGHT_FACTOR" | bc)"
        else
            echo "0"
        fi
    else
        printf "%.0f" "$(echo "scale=2; $_rtt * $LIGHT_FACTOR" | bc)"
    fi
}

# Statistics summary displayed on interrupt (Ctrl+C) or after -c count reached
# Output format matches ping(8) style
show_stats() {
    LOST=$((CPT - RECV))
    if [ "$CPT" -gt 0 ]; then
        LOSS_PCT=$((LOST * 100 / CPT))
    else
        LOSS_PCT=0
    fi

    # Total elapsed time in ms
    END_MS=$(get_ms)
    ELAPSED=$((END_MS - START_MS))

    echo ""
    echo "--- $TARGET $PROGNAME statistics ---"
    echo "$CPT packets transmitted, $RECV received, ${LOSS_PCT}% packet loss, time ${ELAPSED}ms"

    if [ "$RECV" -gt 0 ]; then
        AVG=$(echo "scale=3; $SUM / $RECV" | bc)

        # mdev = standard deviation = sqrt(mean of squares - square of mean)
        # With only 1 packet, mdev is always 0 (avoid floating point edge case)
        if [ "$RECV" -eq 1 ]; then
            MDEV="0.000"
        else
            MDEV=$(echo "scale=3; sqrt($SUM_SQ / $RECV - $AVG * $AVG)" | bc)
        fi

        # Corresponding distances
        AVG_KMS=$(calc_distance "$AVG")
        MIN_KMS=$(calc_distance "$MIN")
        MAX_KMS=$(calc_distance "$MAX")

        echo "rtt min/avg/max/mdev = ${MIN}/${AVG}/${MAX}/${MDEV} ms"
        echo "$MEDIUM min/avg/max = ${MIN_KMS}/${AVG_KMS}/${MAX_KMS} km"
    fi

    exit 0
}

# Compare two decimal numbers using bc
# Returns 0 (true in shell) if $1 < $2
is_less_than() {
    [ "$(echo "$1 < $2" | bc)" = "1" ]
}

# --- Entry point --------------------------------------------------------------

# Parse command line options
# Options and host can appear in any order
while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            usage
            ;;
        --version|-V)
            version
            ;;
        --fiber)
            MEDIUM="fiber"
            LIGHT_FACTOR="99.9305"
            MODEM_OVERHEAD=0
            shift
            ;;
        --copper)
            MEDIUM="copper"
            LIGHT_FACTOR="98.93"
            MODEM_OVERHEAD=0
            shift
            ;;
        --theoretical)
            MEDIUM="theoretical"
            LIGHT_FACTOR="149.896"
            MODEM_OVERHEAD=0
            shift
            ;;
        --dialup)
            MEDIUM="dialup"
            LIGHT_FACTOR="99.9305"
            MODEM_OVERHEAD=120
            shift
            ;;
        -4)
            PING="ping -4 -c 1"
            shift
            ;;
        -c)
            shift
            if [ -z "$1" ] || ! echo "$1" | grep -q '^[0-9]*$' || [ "$1" -lt 1 ]; then
                echo "ERROR: -c requires a positive integer argument." >&2
                exit 1
            fi
            COUNT="$1"
            shift
            ;;
        -*)
            echo "ERROR: unknown option '$1'" >&2
            echo "Try '$PROGNAME --help' for more information." >&2
            exit 1
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# No target provided
if [ -z "$TARGET" ]; then
    echo "Usage: $PROGNAME [--fiber|--copper|--theoretical|--dialup] [-4] [-c count] <host>" >&2
    echo "Try '$PROGNAME --help' for more information." >&2
    exit 1
fi

# Pre-flight checks
check_os
check_bin ping
check_bin grep
check_bin sed
check_bin bc
check_bin printf

# DNS check: if the host does not resolve, exit like ping(8)
PING_ERR=$($PING -W 2 "$TARGET" 2>&1)
case "$PING_ERR" in
    *"not known"*|*"not found"*|*"failure in name"*|*"cannot resolve"*)
        echo "$PROGNAME: $TARGET: Name or service not known" >&2
        exit 2
        ;;
esac

# Trap INT (Ctrl+C) and TERM to display stats before exiting
trap show_stats INT TERM

# Start timestamp for total elapsed time calculation
START_MS=$(get_ms)

# --- Main loop ----------------------------------------------------------------
# Sends one ping per second and displays RTT with estimated distance.
# Lost packets increment the counter silently.
# Counter starts at 1 to match ping(8) behavior.

while true; do
    # Increment counter BEFORE ping (like ping(8): seq starts at 1)
    CPT=$((CPT + 1))

    # Send a single ping (-c 1) and capture the response line
    # 2>/dev/null hides errors (host unreachable, etc.)
    LINE=$($PING "$TARGET" 2>/dev/null | grep "bytes from")
    RETURN=$?

    if [ "$RETURN" = "0" ]; then
        # Extract RTT and TTL using POSIX sed
        # Compatible with Linux (GNU), FreeBSD (BSD) and macOS (BSD)
        # Expected format: "XX bytes from host (IP): ... ttl=NN ... time=NN.N ms"
        TIME=$(echo "$LINE" | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
        TTL=$(echo "$LINE" | sed -n 's/.*ttl=\([0-9]*\).*/\1/p')

        # Extract source IP on first successful ping
        # Two cases: "from hostname (IP)" or "from IP" (direct IP ping)
        if [ -z "$RESOLVED_IP" ]; then
            RESOLVED_IP=$(echo "$LINE" | sed -n 's/.*from [^(]*(\([^)]*\)).*/\1/p')
            if [ -z "$RESOLVED_IP" ]; then
                RESOLVED_IP=$(echo "$LINE" | sed -n 's/.*from \([0-9.]*\).*/\1/p')
            fi
            # Banner in ping(8) format
            if [ -n "$RESOLVED_IP" ]; then
                echo "PING $TARGET ($RESOLVED_IP) 56 data bytes"
            fi
        fi

        if [ -n "$TIME" ]; then
            # Estimate distance based on selected medium
            KMS=$(calc_distance "$TIME")

            # Dialup: show hint when RTT < modem overhead
            if [ "$MODEM_OVERHEAD" -gt 0 ] && [ "$KMS" = "0" ]; then
                DIST_DISPLAY="0 km [too close for dial-up]"
            else
                DIST_DISPLAY="${KMS} km"
            fi

            # Ping line: show (IP) only if TARGET is a FQDN
            if [ "$TARGET" != "$RESOLVED_IP" ]; then
                echo "64 bytes from $TARGET ($RESOLVED_IP): icmp_seq=$CPT ttl=$TTL time=$TIME ms distance=$DIST_DISPLAY"
            else
                echo "64 bytes from $TARGET: icmp_seq=$CPT ttl=$TTL time=$TIME ms distance=$DIST_DISPLAY"
            fi

            # Update cumulative statistics
            RECV=$((RECV + 1))
            SUM=$(echo "$SUM + $TIME" | bc)
            SUM_SQ=$(echo "$SUM_SQ + $TIME * $TIME" | bc)

            # Update min/max RTT
            if [ -z "$MIN" ] || is_less_than "$TIME" "$MIN"; then
                MIN="$TIME"
            fi
            if [ -z "$MAX" ] || is_less_than "$MAX" "$TIME"; then
                MAX="$TIME"
            fi
        fi

        sleep 1
    else
        # Lost packet or unreachable host: counter already incremented,
        # no output (consistent with ping behavior)
        sleep 1
    fi

    # If -c was specified, stop after COUNT packets sent
    if [ "$COUNT" -gt 0 ] && [ "$CPT" -ge "$COUNT" ]; then
        show_stats
    fi
done
