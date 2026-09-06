# Foremost Recovery Toolkit — Advanced Recovery

Advanced Recovery is a safer and more controlled Foremost-based recovery workflow for Kali Linux.

The script creates a complete image of the selected source device, verifies that image with SHA256, and only then runs Foremost on the image.

It is designed to reduce the risk of writing to the source drive and to add extra checks before recovery begins.

---

## Features

- Interactive source drive selection
- SMART health check
- Physical source disk detection
- Separate destination drive selection
- Protection against using the same physical disk as both source and destination
- exFAT and NTFS destination support
- Automatic destination mounting
- Destination write test
- File type selection
- Free-space validation
- Final recovery overview before starting
- Mandatory `START` confirmation
- Full disk or partition image creation with `dd`
- SHA256 generation
- SHA256 verification
- Foremost recovery from the image
- Recovered file counting by type
- Recovery logging
- Emergency report reserve space
- Destination-full detection
- Final recovery summary

---

## Recovery Workflow

```text
Source selection
        ↓
SMART health check
        ↓
Destination selection
        ↓
Filesystem + mount + write checks
        ↓
Recovery name
        ↓
File type selection
        ↓
Free-space check
        ↓
Final overview
        ↓
START confirmation
        ↓
Create full image with dd
        ↓
Generate SHA256
        ↓
Verify SHA256
        ↓
Run Foremost on the image
        ↓
Count recovered files
        ↓
Create recovery report
```

Foremost never runs directly on the original source device.

The complete source image is created first.

Only after the image has been completed and verified does Foremost begin scanning it.

---

## Script Location

The Advanced Recovery script is stored at:

```text
/home/hacky/foremost_recovery_advanced.sh
```

---

## Start Advanced Recovery

Run:

```bash
sudo bash ~/foremost_recovery_advanced.sh
```

---

## Requirements

The script uses the following tools:

```text
lsblk
smartctl
foremost
sha256sum
findmnt
blockdev
numfmt
mount
mountpoint
dd
df
find
tee
```

Required packages include:

```text
util-linux
smartmontools
foremost
coreutils
exfatprogs
```

If a required command is missing, the script attempts to install the corresponding package automatically.

---

## Root Privileges

Advanced Recovery must be started with `sudo`.

Example:

```bash
sudo bash ~/foremost_recovery_advanced.sh
```

If the script is started without root privileges, it exits before recovery begins.

---

## Step 1 — Select Source Drive

The script displays connected drives and partitions using `lsblk`.

Example:

```text
NAME   SIZE   MODEL              TYPE   FSTYPE   LABEL   MOUNTPOINTS
sda    476G   Internal SSD       disk
sda1   512M                      part   vfat
sda2   475G                      part   ext4
sdb    119G   USB Flash Drive    disk
sdb1   119G                      part   exfat
```

You can select either a complete disk or a partition as the recovery source.

Examples:

```text
sdb
```

or:

```text
sdb1
```

The script automatically determines the physical disk behind the selected device.

---

## Step 2 — SMART Health Check

The script runs:

```bash
smartctl -a
```

against the physical source disk.

This can provide information about:

- SMART health status
- Reallocated sectors
- Pending sectors
- Device errors
- Drive temperature
- Power-on hours
- Other hardware health information

Some USB adapters and external enclosures do not expose SMART data correctly.

If SMART information cannot be fully read, Advanced Recovery displays a warning and allows the user to decide whether to continue.

---

## Step 3 — Select Destination

The destination must be a partition.

Example:

```text
sdc1
```

Do not select the complete physical disk:

```text
sdc
```

The script determines the physical destination disk and compares it with the physical source disk.

If both devices belong to the same physical disk, recovery is blocked.

Example:

```text
SOURCE AND DESTINATION ARE ON THE SAME PHYSICAL DRIVE.
```

This protection helps prevent recovery output from overwriting data on the source disk.

---

## Supported Destination Filesystems

### exFAT

```text
exFAT → Recommended
```

exFAT is the preferred filesystem for recovery storage because it is easily accessible from both Linux and Windows.

---

### NTFS

```text
NTFS → Supported
```

NTFS can also be used.

Advanced Recovery warns that exFAT remains the recommended option.

---

### FAT32 / VFAT

```text
FAT32 → Not supported
```

FAT32 has a maximum single-file size of approximately 4 GB.

Recovery images can easily exceed this limit.

---

### Linux-Only Filesystems

The following destination filesystems are rejected by this workflow:

```text
ext2
ext3
ext4
xfs
btrfs
```

The Advanced Recovery workflow is designed around storage that can be used on both Windows and Linux systems.

---

## Automatic Mounting

If the selected exFAT or NTFS destination partition is not mounted, Advanced Recovery attempts to mount it automatically.

The mount location is generated under:

```text
/mnt/
```

Example:

```text
/mnt/foremost_1234-5678
```

If mounting fails, the script does not attempt to repair or format the filesystem automatically.

This is intentional.

Automatic repair or formatting could damage existing data.

---

## Destination Write Test

After mounting the destination, Advanced Recovery performs a real write test.

A temporary file is created and removed.

The recovery continues only when all three checks succeed:

```text
Filesystem OK
Mount OK
Write test OK
```

---

## Step 4 — Recovery Setup

The user provides a name for the recovery.

Example:

```text
old_drive
```

Unsafe characters are filtered from the recovery name before it is used as part of a directory name.

---

## File Type Selection

Advanced Recovery allows the user to choose which file types Foremost should recover.

The menu is:

```text
[1] JPG
[2] JPEG
[3] AVI
[4] MP4
[5] PDF
[6] DOC
[7] ALL
```

Multiple selections can be entered using commas.

Example:

```text
1,4,5
```

This results in:

```text
jpg,mp4,pdf
```

being passed to Foremost.

---

## Default Supported File Types

The current Advanced Recovery configuration supports:

```text
jpg
jpeg
avi
mp4
pdf
doc
```

---

## Free-Space Check

Before recovery begins, the script determines the size of the selected source device using:

```bash
blockdev --getsize64
```

It then checks available space on the destination.

At minimum, the complete source image must fit on the destination.

Example:

```text
Source/image size : 120 GiB
Available space   : 200 GiB
Minimum required  : 120 GiB
```

Foremost uses the remaining free space after the image has been created.

---

## Final Recovery Overview

Before any imaging begins, Advanced Recovery displays a full summary.

Example:

```text
RECOVERY OVERVIEW

Recovery name:
old_drive

SOURCE
------------------------------------------------------------
Device              : /dev/sdb
Physical drive      : /dev/sdb
Size                : 120 GiB

DESTINATION
------------------------------------------------------------
Device              : /dev/sdc1
Filesystem          : exfat
Physical drive      : /dev/sdc
Mountpoint          : /mnt/foremost_xxxxx
Available space     : 400 GiB

OUTPUT
------------------------------------------------------------
Recovery directory  : /mnt/foremost_xxxxx/old_drive_20260906_200000
Image               : /mnt/foremost_xxxxx/old_drive_20260906_200000/image_sdb.img
Foremost types      : jpg,mp4,pdf
```

Nothing starts until the user types:

```text
START
```

Any other input aborts the recovery.

---

## Step 5 — Create Full Image

Advanced Recovery creates a complete image using `dd`.

The command is functionally equivalent to:

```bash
dd if=/dev/source of=image_source.img bs=4M status=progress conv=noerror,sync
```

The important recovery sequence is:

```text
Original source
      ↓
Complete image
```

Foremost does not start during this stage.

---

## Image Size Validation

After `dd` completes, Advanced Recovery compares the actual image size with the expected source size.

If they do not match, a warning is recorded.

---

## SHA256 Generation

After the full image has been created, the script generates a SHA256 hash.

Example:

```text
image_sdb.img
image_sdb.img.sha256
```

The SHA256 checksum can later be used to verify that the image has not changed.

---

## SHA256 Verification

Advanced Recovery immediately verifies the generated checksum.

Workflow:

```text
Image
  ↓
SHA256 calculation
  ↓
SHA256 verification
  ↓
Verified image
```

If verification fails, the script stops.

Foremost only begins after successful SHA256 verification.

---

## Step 6 — Foremost Recovery

Foremost runs on the image file.

Example:

```bash
foremost \
    -t jpg,mp4,pdf \
    -i image_sdb.img \
    -o resultaat
```

The original source disk is not scanned directly by Foremost.

---

## Emergency Report Reserve

Before Foremost starts, Advanced Recovery reserves:

```text
10 MiB
```

of emergency free space.

This reserve exists so that the final recovery report can still be written if Foremost fills the destination drive.

The temporary reserve file is removed after Foremost finishes.

---

## Destination Drive Full

If the destination becomes full during Foremost recovery, Advanced Recovery attempts to detect the condition.

The script reports:

```text
DESTINATION DRIVE FULL
```

and records how many files were successfully written.

The number of additional files that may still exist in the image is reported as:

```text
UNKNOWN
```

This is intentional because Foremost cannot reliably determine how many additional files could have been saved if more storage had been available.

---

## Recovered File Counting

Advanced Recovery counts recovered files for every selected file type.

Example:

```text
jpg    : 245 files
mp4    : 12 files
pdf    : 34 files
------------------------------------------------------------
Total  : 291 files
```

---

## Recovery Output

A recovery session creates a directory similar to:

```text
old_drive_20260906_200000/
├── image_sdb.img
├── image_sdb.img.sha256
├── verslag_foremost.txt
└── resultaat/
```

---

## Recovery Image

Example:

```text
image_sdb.img
```

This is the complete image created from the selected source device.

---

## SHA256 File

Example:

```text
image_sdb.img.sha256
```

This contains the SHA256 checksum of the image.

---

## Foremost Results

Recovered files are stored inside:

```text
resultaat/
```

Foremost creates subdirectories based on recovered file types.

Example:

```text
resultaat/
├── jpg/
├── mp4/
└── pdf/
```

---

## Recovery Report

The recovery report is stored as:

```text
verslag_foremost.txt
```

The report contains information such as:

- Date and time
- User
- Source device
- Physical source drive
- Destination device
- Destination filesystem
- Physical destination drive
- Destination mountpoint
- Recovery directory
- Image location
- Selected Foremost file types
- SHA256 status
- Foremost status
- File counts
- Total recovery duration

---

## Important Safety Rules

### Never recover files back onto the source disk

Recovered files and the recovery image must be stored on a separate physical drive.

Advanced Recovery contains a physical-disk comparison to help enforce this.

---

### Avoid mounting the source filesystem

For recovery work, the source should preferably remain unmounted.

This helps reduce unnecessary filesystem activity.

---

### Do not format the source

Advanced Recovery never automatically formats the source or destination.

Formatting can permanently destroy recoverable data.

---

### Use a sufficiently large destination

The destination must first contain enough space for the complete image.

Additional free space is then required for recovered files.

For example:

```text
500 GB source
```

may require significantly more than:

```text
500 GB destination
```

if a large number of files are recovered.

---

## Important Limitation of `dd`

Advanced Recovery currently creates the image using:

```text
dd
```

with:

```text
conv=noerror,sync
```

This can continue past some read errors.

However, heavily damaged or unstable drives may be better handled with a dedicated recovery imaging tool such as GNU ddrescue.

Do not repeatedly scan a mechanically failing drive if the data is important.

---

## Advanced Recovery vs Basic Recovery

### Basic Recovery

Basic Recovery uses a simpler workflow:

```text
Source
  ↓
SMART
  ↓
Recovery name
  ↓
dd image
  ↓
SHA256
  ↓
Foremost
  ↓
Report
```

Basic Recovery does not include all of the additional destination and workflow checks used by Advanced Recovery.

---

### Advanced Recovery

Advanced Recovery adds:

```text
Source
  ↓
SMART
  ↓
Separate destination selection
  ↓
Physical disk protection
  ↓
Filesystem validation
  ↓
Automatic mounting
  ↓
Write test
  ↓
File type selection
  ↓
Free-space check
  ↓
Final START confirmation
  ↓
Complete image
  ↓
SHA256
  ↓
SHA256 verification
  ↓
Foremost
  ↓
Recovered file counts
  ↓
Detailed report
```

---

## Recommended Usage

Before starting Advanced Recovery, inspect the connected devices carefully.

You can run:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS
```

Then start Advanced Recovery:

```bash
sudo bash ~/foremost_recovery_advanced.sh
```

Always verify the source and destination before typing:

```text
START
```

---

## Project Files

Current Advanced Recovery script:

```text
/home/hacky/foremost_recovery_advanced.sh
```

An older Script 2 copy is intentionally retained at:

```text
/home/hacky/Documents/nano/foremost_recovery_script2.sh
```

This older copy should not be deleted or overwritten unintentionally.

---

## Disclaimer

This toolkit is intended for legitimate data recovery on devices you own or are authorized to access.

Data recovery always carries risk, especially when storage hardware is damaged.

Important or irreplaceable data should be handled conservatively, and severely damaged storage may require professional recovery equipment or services.

---

## Foremost Recovery Toolkit

```text
Advanced Recovery
```

Safe source imaging, checksum verification, controlled Foremost recovery, and detailed reporting for Kali Linux.