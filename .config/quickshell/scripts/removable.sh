#!/bin/sh
# List removable USB/SD/external drives as JSON for the NotifCenter.
# Output: [{"dev":"/dev/sdb","vendor":"...","model":"...","sizeGB":"14.4",
#            "volumes":[{"path":"/dev/sdb1","fstype":"exfat","label":"STICK",
#                        "mount":"/run/media/u/STICK","freeGB":"3.1","totalGB":"14.4"}]}]
# System disks (holding /, /boot, /home) are never listed.
lsblk -J -b \
  -o NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT,HOTPLUG,RM,TRAN,VENDOR,MODEL,SERIAL \
  2>/dev/null | jq -c '
  def sysmount: ["", "/init", "/boot", "/boot/efi", "/home", "/nix/store", "/nix", "[SWAP]"];
  def is_system(children):
    ([children[]? | .mountpoint // ""] | map(select(
      . == "/" or (startswith("/boot")) or . == "/home" or (startswith("/home/"))
      or . == "/nix" or (startswith("/nix/")) or . == "[SWAP]")) | length) > 0;
  [.blockdevices[]?
   | select(.type == "disk")
   | select(.name | test("^(loop|ram|zram|dm-|md|sr)") | not)
   | select(.rm == true or .hotplug == true or .tran == "usb")
   | select(is_system(.children) | not)
   | {
       dev: .path,
       vendor: ((.vendor // "") | gsub("\\s+"; " ") | gsub("^ | $"; "")),
       model: ((.model // "") | gsub("\\s+"; " ") | gsub("^ | $"; "")),
       serial: (.serial // ""),
       sizeGB: ((.size // 0) / 1073741824),
       volumes: [.children[]?
         | select(.type == "part" or .type == "disk")
         | select(.fstype != "swap" and .fstype != "LVM2_member"
                  and .fstype != "linux_raid_member" and .fstype != "crypto_LUKS"
                  or (.mountpoint != null and .mountpoint != ""))
         | {
             path: .path,
             fstype: (.fstype // ""),
             label: (.label // ""),
             uuid: (.uuid // ""),
             mount: (.mountpoint // "")
           }]
     }
  ]'
