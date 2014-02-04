#!/bin/bash

# Useful: 
# http://blogs.citrix.com/2010/10/18/how-to-install-citrix-xenserver-from-a-usb-key-usb-built-from-windows-os/
# http://scnr.net/blog/index.php/archives/177
# http://www.ithastobecool.com/tag/xenclient/
# http://forums.citrix.com/message.jspa?messageID=1479624
# http://blogs.citrix.com/2012/07/13/xs-unattended-install/

set -eu

function print_usage_and_quit
{
cat << USAGE >&2
usage: $(basename "$0") ISOFILE TARGET ANSWERFILE

Re-master a XS/XCP iso file for unattended operation.

Positional arguments:
 ISOFILE - XS/XCP iso file
 TARGET  - The target iso file to produce
 ANSWERFILE - Answerfile to use
USAGE
exit 1
}

ORIGINAL_ISO="${1-$(print_usage_and_quit)}"
TARGET_ISO="${2-$(print_usage_and_quit)}"
ANSWERFILE="${3-$(print_usage_and_quit)}"

ANSWERFILE=$(readlink -f "$ANSWERFILE")

[ -e "$ORIGINAL_ISO" ]

TOP_DIR=$(cd $(dirname "$0") && cd .. && pwd)
ISOROOT=`mktemp -d`

# extract iso
echo "Extracting $ORIGINAL_ISO to $ISOROOT"
7z x "$ORIGINAL_ISO" "-o${ISOROOT}" > /dev/null

INITRDROOT=`mktemp -d`

echo "Remastering $ISOROOT/install.img"
cat << FAKEROOT | fakeroot bash
cd "$INITRDROOT"
zcat "$ISOROOT/install.img" | cpio -idum --quiet

# Do the remastering
cat "$ANSWERFILE" > "./answerfile.xml"
cp "$TOP_DIR/data/postinst.sh" ./
cp "$TOP_DIR/data/firstboot.sh" ./

# Re-pack initrd
find . -print | cpio -o --quiet -H newc | xz --format=lzma > "${ISOROOT}/install.img"
FAKEROOT

echo "Removing $INITRDROOT"
rm -rf "$INITRDROOT"

cp "$TOP_DIR/data/isolinux.cfg" "${ISOROOT}/boot/isolinux/isolinux.cfg"

echo "Create new iso: $TARGET_ISO"
echo '/boot 1000' > sortlist
isocmd="mkisofs"
command -v "$isocmd" >/dev/null 2>&1 || isocmd="genisoimage"
$isocmd -quiet -joliet -joliet-long -r -b boot/isolinux/isolinux.bin \
-c boot/isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
-boot-info-table -sort sortlist -V "My Custom XenServer ISO" -o "$TARGET_ISO" "$ISOROOT"

echo "Removing $ISOROOT"
rm -rf "$ISOROOT"
