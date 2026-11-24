# Undoing an update

Fiordland keeps snapshots of the system, so a bad update can be undone. The same page is on the website at [fiordlandlinux.org/docs/snapshots](https://fiordlandlinux.org/docs/snapshots/).

## What is saved

The installer puts Fiordland on Btrfs with these subvolumes:

| Subvolume | Mounted at |
| --- | --- |
| `@` | `/` |
| `@home` | `/home` |
| `@log` | `/var/log` |
| `@pkg` | `/var/cache/pacman/pkg` |
| `@snapshots` | `/.snapshots` |

[snapper](https://wiki.archlinux.org/title/Snapper) snapshots `/` through its `root` config. Because `/home`, the logs and the package cache are separate subvolumes, they are not part of a snapshot and a rollback never changes them. Snapshots are not backups of your files.

Snapshots are taken:

- Before and after every package change, as a pre and post pair (snap-pac).
- Every hour. snapper keeps 5 hourly, 7 daily, 2 weekly and 1 monthly snapshot, and no yearly ones.

List them:

```
snapper -c root list
```

`sudo fiordland-rollback --list` prints the same list.

## Undo an update while the system works

Find the pre and post numbers of the bad update in the list, then:

```
sudo snapper -c root undochange PRE..POST
```

Restart afterwards.

## Go back when the system does not boot

1. Restart. In the GRUB menu open **Fiordland snapshots** and pick one from before the problem. The menu lists at most the 20 newest snapshots, each with its date and what caused it.
2. The system starts from that snapshot. Changes you make now are kept in memory only and are lost at the next restart. Check that everything works.
3. To keep it, make it permanent:

   ```
   sudo fiordland-rollback
   ```

   It shows which snapshot it will use and asks to continue. Without a number it uses the snapshot the computer was started from.
4. Restart. Fiordland now starts from the restored system.
5. When everything works, free the space the old system uses:

   ```
   sudo fiordland-rollback --clean
   ```

Each snapshot includes its own kernel, so this also undoes a bad kernel update.

## fiordland-rollback

```
fiordland-rollback [-y] [SNAPSHOT]
fiordland-rollback --list
fiordland-rollback --clean
```

`SNAPSHOT` is a number from `--list`. The command makes that snapshot the running system from the next boot. It keeps the current system as `@rollback-backup-<date>` and does not change `/home`. If the snapshot cannot be put in place, the current system is restored and nothing changes. `-y` skips the questions. `--clean` deletes the kept `@rollback-backup-*` systems.

To restore a snapshot without booting it first, use its number:

```
sudo fiordland-rollback 42
```

The Kuaka update app has the same thing in its History tab: every snapshot taken before a change, with an Undo button.

## Installs from before 23 November 2026

Older installs use systemd-boot and keep the kernel on the boot partition, so the snapshot menu is not there. Boot the Fiordland USB stick, open a terminal and:

1. Find the Btrfs partition, for example `/dev/nvme0n1p2`:

   ```
   lsblk -f
   ```

2. Mount the top of the filesystem and pick a snapshot. `info.xml` in each snapshot folder has its date:

   ```
   sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt
   sudo ls /mnt/@snapshots
   sudo cat /mnt/@snapshots/N/info.xml
   ```

3. Move the broken system aside and restore the snapshot:

   ```
   sudo mv /mnt/@ /mnt/@broken
   sudo btrfs subvolume snapshot /mnt/@snapshots/N/snapshot /mnt/@
   sudo umount /mnt
   ```

4. Reboot. If a kernel update caused the problem, reinstall the kernels:

   ```
   sudo pacman -S linux-cachyos linux
   ```
