# Foremost Recovery Toolkit — Advanced Recovery

Advanced Recovery is a safe and controlled data recovery workflow for Kali Linux built around Foremost.

The script creates a complete image of the selected source device, verifies the image using SHA256, and only then runs Foremost against the verified image.

The original source is therefore not used directly by Foremost.

> **Repository:**  
> https://github.com/vdw88/advanced-recovery

---

## Features

Advanced Recovery includes:

- Interactive source drive or partition selection
- Physical source disk detection
- SMART health information
- Separate destination selection
- Protection against selecting the same physical disk as source and destination
- exFAT and NTFS destination support
- Automatic destination mounting
- Real destination write test
- Destination free-space validation
- Recovery session naming
- Selectable Foremost file types
- Final recovery overview before imaging
- Mandatory `START` confirmation
- Full source imaging with `dd`
- SHA256 checksum generation
- Automatic SHA256 verification
- Foremost recovery from the verified image
- 10 MiB emergency report reserve
- Destination-full detection
- Recovered file counting by type
- Detailed recovery logging
- Final recovery summary

---

## Recovery Workflow

```text
Select source
      ↓
SMART health check
      ↓
Select destination
      ↓
Physical disk safety check
      ↓
Filesystem validation
      ↓
Mount + write test
      ↓
Recovery setup
      ↓
Select file types
      ↓
Free-space check
      ↓
Final overview
      ↓
Type START
      ↓
Create complete image with dd
      ↓
Generate SHA256
      ↓
Verify SHA256
      ↓
Run Foremost on verified image
      ↓
Count recovered files
      ↓
Generate recovery report
```

### Important

Foremost **never runs directly on the original source device**.

The recovery sequence is:

```text
SOURCE DEVICE
     │
     ▼
COMPLETE IMAGE
     │
     ▼
SHA256 CHECKSUM
     │
     ▼
SHA256 VERIFICATION
     │
     ▼
FOREMOST
     │
     ▼
RECOVERED FILES
```

Image creation and Foremost recovery are separate stages.

Foremost starts only after the image has been created and its SHA256 checksum has been successfully verified.

---

## Installation

Clone the repository:

```bash
git clone https://github.com/vdw88/advanced-recovery.git
```

Enter the repository:

```bash
cd advanced-recovery
```

Make the script executable:

```bash
chmod +x foremost_recovery_advanced.sh
```

---

## Starting Advanced Recovery

Run:

```bash
sudo bash ./foremost_recovery_advanced.sh
```

Alternatively, after making the script executable:

```bash
sudo ./foremost_recovery_advanced.sh
```

---

## Requirements

Advanced Recovery is designed for Linux and primarily developed for Kali Linux.

The script uses tools including:

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

If a required command is missing, the script attempts to install the corresponding package automatically using APT.

An active internet connection may therefore be required when dependencies are missing.

---

## Root Privileges

Advanced Recovery requires root privileges because direct block-device access and mounting operations are required.

Start it using:

```bash
sudo bash ./foremost_recovery_advanced.sh
```

If the script is started without root privileges, it exits before recovery begins.

---

# Recovery Process

## Step 1 — Select Source Drive

Advanced Recovery displays the currently detected disks and partitions using `lsblk`.

Example:

```text
NAME   SIZE   MODEL              TYPE   FSTYPE   LABEL      MOUNTPOINTS
sda    476G   Internal SSD       disk
├─sda1 512M                      part   vfat
└─sda2 475G                      part   ext4
sdb    119G   USB Flash Drive    disk
└─sdb1 119G                      part   exfat
```

The recovery source can be a complete disk:

```text
sdb
```

or a specific partition:

```text
sdb1
```

Advanced Recovery automatically determines the physical disk behind the selected device.

---

## Step 2 — SMART Health Check

The physical source disk is inspected using `smartctl`.

The SMART information can provide useful indicators such as:

- Overall SMART health
- Reallocated sectors
- Pending sectors
- Read errors
- Device errors
- Temperature
- Power-on hours
- Other available hardware health information

### USB Adapters

Some USB adapters and external drive enclosures do not expose SMART information correctly.

In that situation, Advanced Recovery displays a warning.

The user can then decide whether to continue.

Failure to retrieve SMART information does not automatically mean that the drive is defective.

---

## Step 3 — Select Destination

The destination must be a **partition**.

Correct example:

```text
sdc1
```

Incorrect example:

```text
sdc
```

Advanced Recovery determines the physical disk containing the selected destination partition.

It then compares the physical source and destination disks.

If both belong to the same physical disk, recovery is blocked.

```text
SOURCE AND DESTINATION ARE ON THE SAME PHYSICAL DRIVE.
```

This is an important protection against accidentally storing the recovery image or recovered files on the source disk.

---

# Destination Filesystems

Advanced Recovery is designed to create recovery storage that can be accessed from both Linux and Windows.

## exFAT

**Recommended**

exFAT provides good compatibility between Linux and Windows and supports files larger than 4 GB.

For this workflow, exFAT is the preferred destination filesystem.

---

## NTFS

**Supported**

NTFS can also be used as the recovery destination.

If an NTFS partition cannot be mounted, possible causes include:

- Windows Fast Startup
- Windows hibernation
- An unclean filesystem
- Filesystem errors
- Incorrect previous disconnection

Advanced Recovery does not automatically repair the filesystem.

---

## FAT32 / VFAT

**Rejected**

FAT32 has a maximum individual file size of approximately 4 GB.

A recovery image can easily exceed this limit.

For that reason, FAT32/VFAT is not accepted as a recovery destination.

---

## Linux-Only Filesystems

The following filesystems are rejected for this Windows + Linux recovery workflow:

```text
ext2
ext3
ext4
xfs
btrfs
```

This restriction is intentional because the current workflow is designed around recovery storage that can be easily accessed from both Windows and Linux.

---

# Automatic Mounting

If a suitable exFAT or NTFS destination partition is not already mounted, Advanced Recovery attempts to mount it automatically.

Mount directories are created under:

```text
/mnt/
```

For example:

```text
/mnt/foremost_1234-5678
```

The script does **not** automatically format the destination.

It also does not automatically repair a filesystem when mounting fails.

This is intentional because automated formatting or repair could destroy existing data.

---

# Destination Write Test

Before recovery begins, Advanced Recovery performs an actual write test on the destination.

A temporary file is created and then removed.

Recovery continues only after the destination passes the required checks:

```text
Filesystem OK
Mount OK
Write test OK
```

This confirms that the selected destination is actually writable before a potentially long imaging operation begins.

---

## Step 4 — Recovery Setup

The user provides a name for the recovery session.

Example:

```text
old_drive
```

The recovery name is sanitized before being used as part of the output directory name.

Spaces and unsafe characters are filtered or replaced.

---

# File Type Selection

Advanced Recovery allows the user to select which file types Foremost should search for.

The current menu is:

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

This produces:

```text
jpg,mp4,pdf
```

for the Foremost recovery operation.

Selecting:

```text
7
```

enables all currently configured types:

```text
jpg,jpeg,avi,mp4,pdf,doc
```

---

# Free-Space Validation

Before imaging begins, Advanced Recovery determines the exact size of the selected source device.

It also determines the available space on the destination.

At minimum, the destination must have enough free space to contain the complete source image.

Example:

```text
Source/image size : 120 GiB
Available space   : 500 GiB
Minimum required  : 120 GiB
```

If the complete image cannot fit, Advanced Recovery stops before imaging begins.

### Important

The minimum check guarantees space for the **image only**.

Foremost recovery results require additional free space.

For example, a 500 GB source should not automatically be paired with a destination containing only 500 GB of free space if significant file recovery is expected.

---

# Final Safety Overview

Before anything begins, Advanced Recovery displays a final overview.

Example:

```text
============================================================
                   RECOVERY OVERVIEW
============================================================

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
Available space     : 500 GiB

OUTPUT
------------------------------------------------------------
Recovery directory  : /mnt/foremost_xxxxx/old_drive_20260906_200000
Image               : /mnt/foremost_xxxxx/old_drive_20260906_200000/image_sdb.img
Foremost types      : jpg,mp4,pdf
```

The script also displays the planned operations:

```text
1. Create a complete image of the source
2. Calculate SHA256 hash
3. Verify SHA256 hash
4. Run Foremost on the image
5. Count recovered files
6. Save recovery report
```

Recovery does not start until the user explicitly enters:

```text
START
```

Any other input aborts the operation.

---

## Step 5 — Create Source Image

Advanced Recovery creates a complete image of the selected source using `dd`.

The imaging operation uses:

```bash
dd if="$SOURCE_DEVICE" \
   of="$IMAGE_FILE" \
   bs=4M \
   status=progress \
   conv=noerror,sync
```

The process is:

```text
Original source
      ↓
Complete image
```

Foremost is **not** running during this stage.

---

# Image Size Validation

After `dd` finishes, Advanced Recovery checks the size of the generated image against the expected source size.

If the sizes do not match, the script records a warning.

---

# SHA256 Checksum

After imaging has completed, Advanced Recovery calculates a SHA256 checksum for the image.

This produces:

```text
image_sdb.img
image_sdb.img.sha256
```

The checksum provides a way to verify the integrity of the recovery image.

---

# Automatic SHA256 Verification

Advanced Recovery does not simply create the checksum.

It immediately verifies it.

```text
IMAGE
  ↓
SHA256 calculation
  ↓
SHA256 verification
  ↓
VERIFIED IMAGE
```

If SHA256 verification fails, recovery stops.

Foremost is not started against an image that fails this verification stage.

---

## Step 6 — Foremost Recovery

After successful SHA256 verification, Foremost is executed against the image.

Conceptually:

```bash
foremost \
    -t jpg,mp4,pdf \
    -i image_sdb.img \
    -o result_directory
```

The important distinction is:

```text
WRONG:

Source disk → Foremost


ADVANCED RECOVERY:

Source disk
     ↓
Image
     ↓
SHA256 verification
     ↓
Foremost
```

This keeps the carving stage separated from the original source device.

---

# Emergency Report Reserve

Before Foremost begins, Advanced Recovery reserves:

```text
10 MiB
```

of destination space.

The reserve exists so that a small amount of space can be released if Foremost fills the destination.

This helps preserve enough room for the script to write its final recovery information.

After Foremost finishes, the emergency reserve is removed.

---

# Destination Full Detection

Advanced Recovery checks the remaining destination space after Foremost runs.

If the destination becomes full, the script reports:

```text
DESTINATION DRIVE FULL
```

It also reports the number of files that were successfully stored.

Example:

```text
Successfully saved files:
284

Files not saved:
UNKNOWN
```

`UNKNOWN` is intentional.

If the destination fills during carving, the script cannot reliably know how many additional recoverable files may still exist inside the image.

The image itself remains available for another recovery attempt if it was successfully created.

---

# Recovered File Counting

Advanced Recovery counts recovered files for each selected type.

Example:

```text
jpg    : 245 files
mp4    : 12 files
pdf    : 34 files
------------------------------------------------------------
Total  : 291 files
```

This information is included in the recovery output and report.

---

# Recovery Output

A typical recovery session produces a directory similar to:

```text
old_drive_20260906_200000/
├── image_sdb.img
├── image_sdb.img.sha256
├── verslag_foremost.txt
└── resultaat/
    ├── jpg/
    ├── mp4/
    └── pdf/
```

The exact Foremost directories depend on the selected file types and the files recovered.

---

## Recovery Image

Example:

```text
image_sdb.img
```

This contains the image created from the selected source device.

---

## SHA256 Checksum

Example:

```text
image_sdb.img.sha256
```

This contains the SHA256 checksum used to verify the image.

---

## Foremost Results

Recovered files are stored inside:

```text
resultaat/
```

Foremost organizes recovered data according to the file types being carved.

---

## Recovery Report

Advanced Recovery writes its recovery log to:

```text
verslag_foremost.txt
```

The report includes information such as:

- Recovery date and time
- User
- Source device
- Physical source disk
- Destination device
- Destination filesystem
- Physical destination disk
- Destination mountpoint
- Recovery directory
- Image location
- Selected Foremost file types
- Imaging status
- SHA256 information
- SHA256 verification status
- Foremost status
- Recovered file counts
- Recovery duration

---

# Safety Principles

## Never Recover Onto the Source Disk

The recovery image and recovered files must be written to a separate physical drive.

Advanced Recovery checks the physical source and destination disks and blocks a destination located on the same physical disk.

---

## Keep the Source Unmounted When Possible

For recovery work, the source filesystem should preferably remain unmounted.

Reducing unnecessary access to the source helps preserve its current state.

---

## Never Format the Source

Do not format a device containing data you are attempting to recover.

Formatting changes filesystem structures and can reduce the chance of successful recovery.

---

## Destination Formatting Is Never Automatic

Advanced Recovery does not automatically format an unsupported or unformatted destination.

If the destination is unsuitable, the script stops and allows the user to prepare the storage manually.

---

## Verify Device Names Carefully

Linux device names such as:

```text
/dev/sdb
/dev/sdc
/dev/sdd
```

can change when devices are disconnected, reconnected, or the system is rebooted.

Never rely only on a device name remembered from a previous session.

Check the model, size, serial number and filesystem before starting recovery.

A useful command is:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS
```

---

# Damaged Drives and `dd`

Advanced Recovery currently uses `dd` with:

```text
conv=noerror,sync
```

This allows imaging to continue past certain read errors while maintaining output alignment.

However, `dd` is not always the best tool for physically damaged, unstable or rapidly deteriorating storage.

For severely damaged media, a specialized imaging tool such as GNU ddrescue may be more appropriate because it supports techniques such as:

- Mapfiles
- Resume
- Controlled retries
- Skipping damaged areas
- Multi-pass recovery

Repeatedly reading a mechanically failing drive can make its condition worse.

If the data is irreplaceable and the hardware is physically failing, professional data recovery should be considered before performing repeated software recovery attempts.

---

# Advanced Recovery vs Basic Recovery

The Foremost Recovery Toolkit separates simpler recovery from the more controlled Advanced workflow.

## Basic Recovery

Conceptually:

```text
Source
  ↓
SMART
  ↓
Recovery setup
  ↓
Image
  ↓
SHA256
  ↓
Foremost
  ↓
Report
```

Basic Recovery is intended to provide a simpler workflow.

---

## Advanced Recovery

Advanced Recovery adds additional safety and control:

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
Recovery setup
  ↓
File type selection
  ↓
Free-space validation
  ↓
Final START confirmation
  ↓
Complete image
  ↓
SHA256 generation
  ↓
SHA256 verification
  ↓
Foremost
  ↓
Recovered file counting
  ↓
Detailed report
```

---

# Recommended Start Procedure

Before starting a recovery, inspect all connected storage devices:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS
```

Then start Advanced Recovery:

```bash
sudo bash ./foremost_recovery_advanced.sh
```

Carefully verify the source and destination shown in the final overview.

Only enter:

```text
START
```

after confirming that the correct devices have been selected.

---

# Repository

GitHub repository:

https://github.com/vdw88/advanced-recovery

Clone:

```bash
git clone https://github.com/vdw88/advanced-recovery.git
```

Enter the repository:

```bash
cd advanced-recovery
```

Make the script executable:

```bash
chmod +x foremost_recovery_advanced.sh
```

Run:

```bash
sudo ./foremost_recovery_advanced.sh
```

---

# Disclaimer

This project is intended for legitimate data recovery on storage devices that you own or are authorized to access.

Data recovery always involves risk.

The author cannot guarantee that damaged, deleted or lost files can be recovered successfully.

The user is responsible for:

- Selecting the correct source device
- Selecting the correct destination device
- Ensuring sufficient destination capacity
- Evaluating the physical condition of the source
- Maintaining backups where possible
- Using the software only on devices they are authorized to access

For important or irreplaceable data stored on physically damaged hardware, professional data recovery services should be considered.

---

# Foremost Recovery Toolkit

**Advanced Recovery**

Image first. Verify the image. Recover from the image.