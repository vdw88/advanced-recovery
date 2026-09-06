#!/usr/bin/env bash

set -o pipefail

# ============================================================
# FOREMOST RECOVERY TOOLKIT - ADVANCED RECOVERY
# Safe interactive recovery workflow for Kali Linux
# ============================================================

EXTENSIONS="jpg,jpeg,avi,mp4,pdf,doc"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

header() {
    clear
    echo "============================================================"
    echo "       FOREMOST RECOVERY TOOLKIT - ADVANCED RECOVERY"
    echo "============================================================"
    echo
}

step_header() {
    header
    echo "$1"
    echo "------------------------------------------------------------"
    echo
}

fatal() {
    echo
    echo "❌ ERROR: $1"
    echo
    exit 1
}

pause() {
    echo
    read -r -p "Press Enter to continue..." _
}

require_command() {
    local cmd="$1"
    local package="$2"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "⚙️  '$cmd' is not installed."
        echo "Installing package '$package'..."

        apt-get update ||
            fatal "apt update failed."

        apt-get install -y "$package" ||
            fatal "Installation of '$package' failed."
    fi
}

valid_block_device() {
    [[ -b "$1" ]]
}

parent_disk() {
    local dev="$1"
    local type pk

    type=$(lsblk -ndo TYPE "$dev" 2>/dev/null | head -n1)

    if [[ "$type" == "disk" ]]; then
        readlink -f "$dev"
        return
    fi

    pk=$(lsblk -ndo PKNAME "$dev" 2>/dev/null | head -n1)

    [[ -n "$pk" ]] || return 1

    readlink -f "/dev/$pk"
}

show_devices() {
    lsblk -e 7 -o NAME,SIZE,MODEL,TYPE,FSTYPE,LABEL,MOUNTPOINTS
}

human_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null ||
        echo "$1 bytes"
}

# ============================================================
# AUTOMATICALLY MOUNT DESTINATION
#
# For Windows + Linux:
#
# exFAT = recommended
# NTFS  = allowed
#
# FAT32 is rejected because of the 4 GB per-file limit.
# Linux-only filesystems are rejected for this workflow.
# ============================================================

auto_mount_destination() {

    local dev="$1"
    local fstype
    local mount_dir
    local uuid

    fstype=$(lsblk -ndo FSTYPE "$dev" 2>/dev/null | head -n1)
    uuid=$(lsblk -ndo UUID "$dev" 2>/dev/null | head -n1)

    case "${fstype,,}" in

        exfat)
            echo "✅ exFAT detected."
            echo "   Suitable for Windows + Linux."
            ;;

        ntfs|ntfs3)
            echo "⚠️  NTFS detected."
            echo "   Windows and Linux can use this filesystem."
            echo "   exFAT remains the recommended choice."
            ;;

        vfat|fat|fat32)
            echo
            echo "❌ FAT32/VFAT is not suitable."
            echo "Recovery images may be larger than 4 GB."
            echo
            echo "Use exFAT or NTFS."
            return 1
            ;;

        ext2|ext3|ext4|xfs|btrfs)
            echo
            echo "❌ Filesystem '$fstype' is not normally"
            echo "readable and writable under Windows."
            echo
            echo "Use exFAT or NTFS."
            return 1
            ;;

        "")
            echo
            echo "❌ No filesystem detected on $dev."
            echo
            echo "IMPORTANT:"
            echo "The recovery script NEVER formats automatically."
            echo "Automatic formatting could destroy existing data."
            echo
            echo "Prepare the destination drive as exFAT first."
            return 1
            ;;

        *)
            echo
            echo "❌ Filesystem '$fstype' is not used"
            echo "for this Windows + Linux recovery storage workflow."
            echo
            echo "Use exFAT or NTFS."
            return 1
            ;;
    esac

    DEST_MOUNT=$(findmnt -rn -S "$dev" -o TARGET | head -n1)

    if [[ -n "$DEST_MOUNT" && -d "$DEST_MOUNT" ]]; then

        echo
        echo "✅ Destination is already mounted:"
        echo "$DEST_MOUNT"

        return 0
    fi

    if [[ -n "$uuid" ]]; then

        mount_dir="/mnt/foremost_${uuid//[^[:alnum:]_-]/_}"

    else

        mount_dir="/mnt/foremost_$(basename "$dev")"

    fi

    mkdir -p "$mount_dir" || return 1

    echo
    echo "🔌 $dev is not mounted."
    echo "Automatically mounting at:"
    echo "$mount_dir"
    echo

    if [[ "${fstype,,}" == "exfat" ]]; then

        if ! mount \
            -t exfat \
            -o rw,uid="$(id -u "$REAL_USER")",gid="$(id -g "$REAL_USER")",umask=0022 \
            "$dev" "$mount_dir"
        then

            rmdir "$mount_dir" 2>/dev/null || true

            echo
            echo "❌ Automatic exFAT mount failed."
            echo
            echo "The filesystem will not be repaired or formatted automatically."
            echo
            echo "You can check it with:"
            echo
            echo "fsck.exfat -n $dev"
            echo

            return 1
        fi

    else

        if ! mount \
            -o rw,uid="$(id -u "$REAL_USER")",gid="$(id -g "$REAL_USER")",umask=0022 \
            "$dev" "$mount_dir"
        then

            rmdir "$mount_dir" 2>/dev/null || true

            echo
            echo "❌ Automatic NTFS mount failed."
            echo
            echo "The NTFS drive may:"
            echo "- not have been shut down correctly"
            echo "- be locked by Windows Fast Startup"
            echo "- contain filesystem errors"
            echo

            return 1
        fi

    fi

    DEST_MOUNT="$mount_dir"

    return 0
}

# ============================================================
# ROOT CHECK
# ============================================================

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then

    echo "❌ Start this script with sudo:"
    echo
    echo "sudo $0"
    echo

    exit 1
fi

REAL_USER="${SUDO_USER:-root}"

# ============================================================
# REQUIRED PROGRAMS
# ============================================================

require_command lsblk util-linux
require_command smartctl smartmontools
require_command foremost foremost
require_command sha256sum coreutils
require_command findmnt util-linux
require_command blockdev util-linux
require_command numfmt coreutils
require_command mkfs.exfat exfatprogs

# ============================================================
# STEP 1/6
# SELECT SOURCE DRIVE
# ============================================================

while true; do

    step_header "STEP 1/6 - SELECT SOURCE DRIVE"

    echo "Available drives and partitions:"
    echo

    show_devices

    echo

    read -r -p "💽 Enter source device (e.g. sdb or sdb1): " SRC_INPUT

    [[ -n "$SRC_INPUT" ]] || continue

    SOURCE_DEVICE="/dev/${SRC_INPUT#/dev/}"

    SOURCE_DEVICE=$(readlink -f "$SOURCE_DEVICE" 2>/dev/null || true)

    if ! valid_block_device "$SOURCE_DEVICE"; then

        echo
        echo "❌ '$SOURCE_DEVICE' is not a valid block device."

        pause

        continue
    fi

    SOURCE_DISK=$(parent_disk "$SOURCE_DEVICE") || {

        echo
        echo "❌ Unable to determine the physical source drive."

        pause

        continue
    }

    break
done

# ============================================================
# STEP 2/6
# SMART HEALTH CHECK
# ============================================================

step_header "STEP 2/6 - SMART HEALTH CHECK"

echo "Source device : $SOURCE_DEVICE"
echo "Physical drive: $SOURCE_DISK"
echo

SMART_TARGET="$SOURCE_DISK"

if ! smartctl -a "$SMART_TARGET"; then

    echo
    echo "⚠️  SMART information could not be read completely."
    echo
    echo "This can be normal with some USB adapters"
    echo "or external USB enclosures."

fi

echo

read -r -p "⚠️  Do you want to continue with this source drive? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then

    echo
    echo "🛑 Recovery aborted."

    exit 0
fi

# ============================================================
# STEP 3/6
# SELECT DESTINATION
# ============================================================

while true; do

    step_header "STEP 3/6 - SELECT DESTINATION DRIVE"

    echo "Source device : $SOURCE_DEVICE"
    echo "Source drive  : $SOURCE_DISK"
    echo

    echo "Available drives and partitions:"
    echo

    show_devices

    echo
    echo "Select the PARTITION where the recovery will be stored."
    echo
    echo "Example:"
    echo
    echo "sdc1"
    echo
    echo "Not:"
    echo
    echo "sdc"
    echo

    read -r -p "📁 Destination device: " DST_INPUT

    [[ -n "$DST_INPUT" ]] || continue

    DEST_DEVICE="/dev/${DST_INPUT#/dev/}"

    DEST_DEVICE=$(readlink -f "$DEST_DEVICE" 2>/dev/null || true)

    if ! valid_block_device "$DEST_DEVICE"; then

        echo
        echo "❌ '$DEST_DEVICE' is not a valid block device."

        pause

        continue
    fi

    DEST_DISK=$(parent_disk "$DEST_DEVICE") || {

        echo
        echo "❌ Unable to determine the physical destination drive."

        pause

        continue
    }

    if [[ "$DEST_DISK" == "$SOURCE_DISK" ]]; then

        echo
        echo "❌ SOURCE AND DESTINATION ARE ON THE SAME PHYSICAL DRIVE."
        echo
        echo "Physical drive:"
        echo "$SOURCE_DISK"
        echo
        echo "This is not allowed during recovery."

        pause

        continue
    fi

    DEST_TYPE=$(lsblk -ndo TYPE "$DEST_DEVICE" 2>/dev/null | head -n1)

    if [[ "$DEST_TYPE" != "part" ]]; then

        echo
        echo "❌ Select a PARTITION as the destination."
        echo
        echo "For example:"
        echo "sdc1"
        echo
        echo "Do not select the entire drive:"
        echo "sdc"

        pause

        continue
    fi

    DEST_FSTYPE=$(lsblk -ndo FSTYPE "$DEST_DEVICE" 2>/dev/null | head -n1)

    echo
    echo "Destination filesystem:"
    echo "${DEST_FSTYPE:-unknown}"
    echo

    if ! auto_mount_destination "$DEST_DEVICE"; then

        pause

        continue
    fi

    if ! mountpoint -q "$DEST_MOUNT"; then

        echo
        echo "❌ '$DEST_MOUNT' is not a valid mountpoint."

        pause

        continue
    fi

    if [[ ! -w "$DEST_MOUNT" ]]; then

        echo
        echo "❌ Destination '$DEST_MOUNT' is not writable."

        pause

        continue
    fi

    WRITE_TEST="$DEST_MOUNT/.foremost_write_test_$$"

    if ! : > "$WRITE_TEST" 2>/dev/null; then

        echo
        echo "❌ Write test on '$DEST_MOUNT' failed."

        pause

        continue
    fi

    rm -f "$WRITE_TEST"

    echo
    echo "✅ Filesystem OK"
    echo "✅ Mount OK"
    echo "✅ Write test OK"

    pause

    break

done

# ============================================================
# STEP 4/6
# RECOVERY SETUP + CONFIRMATION
# ============================================================

step_header "STEP 4/6 - RECOVERY SETUP + CONFIRMATION"

read -r -p "📝 Name for this recovery: " RECNAME

[[ -n "$RECNAME" ]] || RECNAME="recovery"

SAFE_RECNAME=$(printf '%s' "$RECNAME" |
    tr ' /' '__' |
    tr -cd '[:alnum:]_.-')

[[ -n "$SAFE_RECNAME" ]] || SAFE_RECNAME="recovery"

# ============================================================
# SELECT FILE TYPES FOR FOREMOST
# ============================================================

echo
echo "============================================================"
echo "                  SELECT FILE TYPES"
echo "============================================================"
echo
echo "[1] JPG"
echo "[2] JPEG"
echo "[3] AVI"
echo "[4] MP4"
echo "[5] PDF"
echo "[6] DOC"
echo "[7] ALL"
echo
echo "Multiple selections may be separated by commas."
echo "Example: 1,4,5"
echo

while true; do

    read -r -p "Selection: " FILE_CHOICES

    SELECTED_EXTENSIONS=""

    IFS=',' read -r -a CHOICE_ARRAY <<< "$FILE_CHOICES"

    VALID_SELECTION=true

    for choice in "${CHOICE_ARRAY[@]}"; do

        choice="${choice//[[:space:]]/}"

        case "$choice" in

            1)
                SELECTED_EXTENSIONS+="${SELECTED_EXTENSIONS:+,}jpg"
                ;;

            2)
                SELECTED_EXTENSIONS+="${SELECTED_EXTENSIONS:+,}jpeg"
                ;;

            3)
                SELECTED_EXTENSIONS+="${SELECTED_EXTENSIONS:+,}avi"
                ;;

            4)
                SELECTED_EXTENSIONS+="${SELECTED_EXTENSIONS:+,}mp4"
                ;;

            5)
                SELECTED_EXTENSIONS+="${SELECTED_EXTENSIONS:+,}pdf"
                ;;

            6)
                SELECTED_EXTENSIONS+="${SELECTED_EXTENSIONS:+,}doc"
                ;;

            7)
                SELECTED_EXTENSIONS="jpg,jpeg,avi,mp4,pdf,doc"
                break
                ;;

            *)
                VALID_SELECTION=false
                ;;
        esac
    done

    if [[ "$VALID_SELECTION" == true && -n "$SELECTED_EXTENSIONS" ]]; then

        EXTENSIONS="$SELECTED_EXTENSIONS"

        break
    fi

    echo
    echo "❌ Invalid selection."
    echo "For example, use: 1,4,5"
    echo

done

echo
echo "✅ Foremost will search for:"
echo "$EXTENSIONS"
echo

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

RECOVERY_DIR="$DEST_MOUNT/${SAFE_RECNAME}_${TIMESTAMP}"

LOGFILE="$RECOVERY_DIR/verslag_foremost.txt"

IMAGE_FILE="$RECOVERY_DIR/image_$(basename "$SOURCE_DEVICE").img"

RESULT_DIR="$RECOVERY_DIR/resultaat"

# ============================================================
# DETERMINE SOURCE SIZE
# ============================================================

SOURCE_SIZE=$(blockdev --getsize64 "$SOURCE_DEVICE" 2>/dev/null) ||
    fatal "Unable to determine source size."

# ============================================================
# DESTINATION FREE SPACE
# ============================================================

AVAILABLE_BYTES=$(df -PB1 "$DEST_MOUNT" |
    awk 'NR==2 {print $4}')

[[ "$AVAILABLE_BYTES" =~ ^[0-9]+$ ]] ||
    fatal "Unable to determine available space on destination."

# ============================================================
# MINIMUM SPACE
#
# The complete image must fit.
# Foremost can use the remaining free space afterwards.
# ============================================================

MIN_REQUIRED=$SOURCE_SIZE

if (( AVAILABLE_BYTES < MIN_REQUIRED )); then

    echo
    echo "❌ INSUFFICIENT FREE SPACE"
    echo
    echo "Source/image size : $(human_bytes "$SOURCE_SIZE")"
    echo "Available space   : $(human_bytes "$AVAILABLE_BYTES")"
    echo "Minimum required  : $(human_bytes "$MIN_REQUIRED")"
    echo

    exit 1
fi

# ============================================================
# FINAL OVERVIEW
# ============================================================

echo "============================================================"
echo "                   RECOVERY OVERVIEW"
echo "============================================================"
echo

echo "Recovery name:"
echo "$SAFE_RECNAME"
echo

echo "SOURCE"
echo "------------------------------------------------------------"
echo "Device              : $SOURCE_DEVICE"
echo "Physical drive      : $SOURCE_DISK"
echo "Size                : $(human_bytes "$SOURCE_SIZE")"
echo

echo "DESTINATION"
echo "------------------------------------------------------------"
echo "Device              : $DEST_DEVICE"
echo "Filesystem          : $DEST_FSTYPE"
echo "Physical drive      : $DEST_DISK"
echo "Mountpoint          : $DEST_MOUNT"
echo "Available space     : $(human_bytes "$AVAILABLE_BYTES")"
echo

echo "OUTPUT"
echo "------------------------------------------------------------"
echo "Recovery directory  : $RECOVERY_DIR"
echo "Image               : $IMAGE_FILE"
echo "Foremost types      : $EXTENSIONS"
echo

echo "ACTIONS"
echo "------------------------------------------------------------"
echo "1. Create a complete image of the source"
echo "2. Calculate SHA256 hash"
echo "3. Verify SHA256 hash"
echo "4. Run Foremost on the image"
echo "5. Count recovered files"
echo "6. Save recovery report"
echo

echo "============================================================"
echo "⚠️  CHECK SOURCE AND DESTINATION VERY CAREFULLY."
echo "============================================================"
echo

read -r -p "Type START to begin recovery: " FINAL_CONFIRM

if [[ "$FINAL_CONFIRM" != "START" ]]; then

    echo
    echo "🛑 Recovery aborted."

    exit 0
fi

# ============================================================
# CREATE RECOVERY DIRECTORY
# ============================================================

mkdir -p "$RECOVERY_DIR" ||
    fatal "Unable to create recovery directory."

# ============================================================
# LOG EVERYTHING FROM THIS POINT
# ============================================================

exec > >(tee -a "$LOGFILE") 2>&1

START_TIME=$(date +%s)

# ============================================================
# RECOVERY REPORT
# ============================================================

echo
echo "🧾 FOREMOST RECOVERY REPORT"
echo "============================================================"
echo "Date                : $(date --iso-8601=seconds)"
echo "User                : $REAL_USER"
echo "Source device       : $SOURCE_DEVICE"
echo "Physical source     : $SOURCE_DISK"
echo "Destination device  : $DEST_DEVICE"
echo "Filesystem          : $DEST_FSTYPE"
echo "Destination drive   : $DEST_DISK"
echo "Destination mount   : $DEST_MOUNT"
echo "Recovery directory  : $RECOVERY_DIR"
echo "Image               : $IMAGE_FILE"
echo "Foremost types      : $EXTENSIONS"
echo "============================================================"

# ============================================================
# STEP 5/6
# CREATE IMAGE
# ============================================================

echo
echo "============================================================"
echo "STEP 5/6 - IMAGE + SHA256"
echo "============================================================"
echo

echo "💽 Creating image..."
echo

if ! dd \
    if="$SOURCE_DEVICE" \
    of="$IMAGE_FILE" \
    bs=4M \
    status=progress \
    conv=noerror,sync
then

    fatal "dd failed. Check the source, destination and log file."
fi

# ============================================================
# FLUSH DATA TO DISK
# ============================================================

sync

# ============================================================
# CHECK IMAGE SIZE
# ============================================================

ACTUAL_IMAGE_SIZE=$(stat -c %s "$IMAGE_FILE" 2>/dev/null || echo 0)

if [[ "$ACTUAL_IMAGE_SIZE" -ne "$SOURCE_SIZE" ]]; then

    echo
    echo "⚠️  WARNING:"
    echo "The created image does not exactly match the expected size."
    echo
    echo "Expected:"
    echo "$SOURCE_SIZE bytes"
    echo
    echo "Actual:"
    echo "$ACTUAL_IMAGE_SIZE bytes"

fi

# ============================================================
# CREATE SHA256
# ============================================================

echo
echo "🔐 Calculating SHA256 hash..."
echo

if ! sha256sum "$IMAGE_FILE" |
    tee "$IMAGE_FILE.sha256"
then

    fatal "SHA256 calculation failed."
fi

# ============================================================
# VERIFY SHA256
# ============================================================

echo
echo "🔎 Verifying SHA256..."
echo

if ! (
    cd "$RECOVERY_DIR" &&
    sha256sum -c "$(basename "$IMAGE_FILE").sha256"
); then

    fatal "SHA256 verification failed."
fi

echo
echo "✅ SHA256 verification successful."

# ============================================================
# STEP 6/6
# FOREMOST
# ============================================================

echo
echo "============================================================"
echo "STEP 6/6 - FOREMOST + REPORT"
echo "============================================================"
echo

# ============================================================
# 10 MiB EMERGENCY SPACE FOR FINAL REPORT
# ============================================================

REPORT_RESERVE="$RECOVERY_DIR/.foremost_report_reserve.bin"

echo
echo "🛡️  Reserving 10 MiB emergency space for the final report..."

if ! dd \
    if=/dev/zero \
    of="$REPORT_RESERVE" \
    bs=1M \
    count=10 \
    status=none
then

    fatal "Unable to reserve 10 MiB emergency space for the report."
fi

sync

echo "✅ Emergency space reserved."
echo

echo "🧠 Foremost started..."
echo

foremost \
    -t "$EXTENSIONS" \
    -i "$IMAGE_FILE" \
    -o "$RESULT_DIR"

FOREMOST_RC=$?

# ============================================================
# CHECK FREE SPACE
# ============================================================

FREE_AFTER_FOREMOST=$(df -PB1 "$DEST_MOUNT" |
    awk 'NR==2 {print $4}')

# Release emergency space so the report can still be written.
rm -f "$REPORT_RESERVE"

sync

FOREMOST_DISK_FULL=false

if [[ "$FREE_AFTER_FOREMOST" =~ ^[0-9]+$ ]] &&
   (( FREE_AFTER_FOREMOST < 1048576 )); then

    FOREMOST_DISK_FULL=true
fi

if [[ "$FOREMOST_RC" -ne 0 && "$FOREMOST_DISK_FULL" != true ]]; then

    fatal "Foremost failed for a reason other than insufficient disk space."
fi

if [[ "$FOREMOST_DISK_FULL" == true ]]; then

    echo
    echo "============================================================"
    echo "⚠️  DESTINATION DRIVE FULL"
    echo "============================================================"
    echo
    echo "Foremost could not save all possible recovery results."
    echo
    echo "The reserved 10 MiB emergency space has been released"
    echo "so the final report can still be written."
    echo

fi

# ============================================================
# COUNT RESULTS
# ============================================================

echo
echo "📊 Counting files by type:"
echo "------------------------------------------------------------"

TOTAL=0

IFS=',' read -r -a EXT_ARRAY <<< "$EXTENSIONS"

for ext in "${EXT_ARRAY[@]}"; do

    COUNT=$(find "$RESULT_DIR/$ext" \
        -type f \
        2>/dev/null |
        wc -l)

    COUNT=${COUNT//[[:space:]]/}

    [[ "$COUNT" =~ ^[0-9]+$ ]] || COUNT=0

    TOTAL=$((TOTAL + COUNT))

    printf "%-6s : %s files\n" "$ext" "$COUNT"

done

echo "------------------------------------------------------------"
echo "Total : $TOTAL files"

# ============================================================
# RECOVERY STATUS
# ============================================================

if [[ "$FOREMOST_DISK_FULL" == true ]]; then

    echo
    echo "============================================================"
    echo "RECOVERY STATUS"
    echo "============================================================"
    echo
    echo "Status:"
    echo "DESTINATION DRIVE FULL"
    echo
    echo "Successfully saved files:"
    echo "$TOTAL"
    echo
    echo "Files not saved:"
    echo "UNKNOWN"
    echo
    echo "Reason:"
    echo "Foremost could not save the complete recovery"
    echo "because the destination drive became full."
    echo
    echo "Additional files may still exist in the image"
    echo "that could not be saved."
    echo

else

    echo
    echo "Recovery status:"
    echo "Foremost completed successfully."

fi

# ============================================================
# TOTAL TIME
# ============================================================

END_TIME=$(date +%s)

DURATION=$((END_TIME - START_TIME))

HOURS=$((DURATION / 3600))

MINUTES=$(((DURATION % 3600) / 60))

SECONDS=$((DURATION % 60))

# ============================================================
# FINAL SCREEN
# ============================================================

echo
echo "============================================================"
echo "                 ✅ RECOVERY COMPLETED"
echo "============================================================"
echo
echo "Total time:"
echo "${HOURS}h ${MINUTES}m ${SECONDS}s"
echo
echo "Recovery directory:"
echo "$RECOVERY_DIR"
echo
echo "Image:"
echo "$IMAGE_FILE"
echo
echo "SHA256:"
echo "$IMAGE_FILE.sha256"
echo
echo "Foremost results:"
echo "$RESULT_DIR"
echo
echo "Report:"
echo "$LOGFILE"
echo
echo "============================================================"
echo "      FOREMOST RECOVERY TOOLKIT - FINISHED"
echo "============================================================"
