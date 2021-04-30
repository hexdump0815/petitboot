#!/bin/bash
# based on https://github.com/Dmole/odroid_petitboot_script

set -e

# prep
C=$(id | grep -c "(root)" || true)
if [ "$C" != 1 ] ; then
    echo "please re-run as root" >&2
    exit 1
fi

nproc=4

mkdir -p make-petitboot-img
cd make-petitboot-img

if [ ! -d systemd ] ; then
    git clone --depth 1 -b v245 https://github.com/systemd/systemd.git
    (
    cd systemd
        mkdir build
	meson build -Dprefix=/usr -Dblkid=true -Dseccomp=false -Dlibcurl=false -Dpam=false -Dkmod=true
	ninja -j "$(nproc)" -C build
    )
fi

if [ ! -d kexec-tools ] ; then
    git clone --depth 1 -b v2.0.21 git://git.kernel.org/pub/scm/utils/kernel/kexec/kexec-tools.git
    (
        cd kexec-tools
        ./bootstrap
        ./configure --prefix=/usr
        make -j "$(nproc)"
    )
fi

if [ ! -d libtwin ] ; then
     git clone git://git.kernel.org/pub/scm/linux/kernel/git/geoff/libtwin.git
     (
         cd libtwin
	 git checkout 0de968c5618c2c49d976b725e1b1c1d7762651b8
         ./autogen.sh
         make
         make install
	 # to undo: rm -rf /usr/local/lib/libtwin.a /usr/local/lib/libtwin.la /usr/local/lib/libtwin.so.0* /usr/local/lib/pkgconfig/libtwin.pc /usr/local/include/libtwin
     )
fi


if [ ! -d petitboot ] ; then
    git clone --depth 1 -b v1.9.2 https://github.com/open-power/petitboot.git
    (
        cd petitboot
        ./bootstrap
        ./configure --prefix=/usr --with-twin-x11=no --with-twin-fbdev=no --with-signed-boot=no --disable-nls
        make -j "$(nproc)"
    )
fi

if [ ! -d busybox ] ; then
    git clone --depth 1 -b 1_33_0 git://git.busybox.net/busybox
    (
        cd busybox
        make defconfig
        LDFLAGS=--static make -j "$(nproc)"
    )
fi

if [ ! -d initramfs ] ; then
    mkdir -p initramfs/{\
bin,\
sbin,\
etc,\
lib/aarch64-linux-gnu,\
proc,\
sys,\
newroot,\
usr/bin,\
usr/sbin,\
usr/lib/aarch64-linux-gnu,\
usr/lib/udev/rules.d,\
usr/local/sbin,\
usr/share/udhcpc,\
var/log/petitboot,run,\
run/udev,\
tmp}
    touch initramfs/etc/mdev.conf
    cp -Rp /lib/terminfo initramfs/lib/
    cp -Rp busybox/busybox initramfs/bin/
    ln -s busybox initramfs/bin/sh
    cp -L /lib/aarch64-linux-gnu/{\
libc.so.*,\
libm.so.*,\
libdl.so.*,\
librt.so.*,\
libacl.so.*,\
libcap.so.*,\
libattr.so.*,\
libpthread.so.*,\
libncurses.so.*,\
libncursesw.so.*,\
libtinfo.so.*,\
libpcre*.so.*,\
libmount.so.*,\
libgcrypt.so.*,\
libcrypt.so.*,\
libresolv.so.*,\
libselinux.so.*,\
libreadline.so.*,\
libgcc_s.so.*,\
libblkid.so.*,\
libkmod.so.*,\
libuuid.so.*,\
libusb-1.0.so.*,\
libdevmapper.so.*,\
libz.so.*,\
liblzma.so.*,\
libbz2.so.*,\
libgpg-error.so.*,\
libnss_files.so.*} initramfs/lib/aarch64-linux-gnu/ 
    cp -L /lib/ld-linux-aarch64.so.* initramfs/lib/
    cp -L /usr/lib/aarch64-linux-gnu/{\
libform.so.*,\
libformw.so.*,\
libmenu.so.*,\
libmenuw.so.*,\
libelf.so.*,\
libdw.so.*,\
libgpgme.so.*,\
libassuan.so.*} initramfs/usr/lib/aarch64-linux-gnu/
    cp -Rp /usr/bin/gpg initramfs/usr/bin/
    cp systemd/build/src/udev/libudev.so.* initramfs/lib/aarch64-linux-gnu/
    cp -Rp systemd/build/{systemd-udevd,udevadm} initramfs/sbin/
    cp -Rp systemd/build/src/udev/*_id initramfs/usr/lib/udev/
    cp -Rp systemd/build/src/shared/libsystemd-shared-245.so initramfs/lib/aarch64-linux-gnu/
    cp -Rp kexec-tools/build/sbin/kexec initramfs/sbin/
    cp -Rp systemd/{rules.d/*,build/rules.d/*} initramfs/usr/lib/udev/rules.d/
    rm -f initramfs/usr/lib/udev/rules.d/*-drivers.rules
    cp -Rp busybox/examples/udhcp/simple.script initramfs/usr/share/udhcpc/simple.script
    chmod 755 initramfs/usr/share/udhcpc/simple.script
    sed -i '/should be called from udhcpc/d' initramfs/usr/share/udhcpc/simple.script
    mkdir -p initramfs/lib/modules
    cp -r /lib/modules/5.10.25-stb-av8+ initramfs/lib/modules
    cat << EOF > initramfs/usr/share/udhcpc/default.script
#!/bin/sh -x

/usr/share/udhcpc/simple.script "\$@"
/usr/sbin/pb-udhcpc "\$@"
EOF
    chmod 755 initramfs/usr/share/udhcpc/default.script
    cat << EOF > initramfs/etc/nsswitch.conf
passwd:                files
group:                files
shadow:                files
hosts:                files
networks:        files
protocols:        files
services:        files
ethers:                files
rpc:                files
netgroup:        files
EOF
    cat << EOF > initramfs/etc/group
root:x:0:
daemon:x:1:
tty:x:5:
disk:x:6:
lp:x:7:
kmem:x:15:
dialout:x:20:
cdrom:x:24:
tape:x:26:
audio:x:29:
video:x:44:
input:x:122:
EOF
    cat << EOF > initramfs/init
#!/bin/sh -x

/bin/busybox --install -s

CURRENT_TIMESTAMP=\$(date '+%s')
if [ \$CURRENT_TIMESTAMP -lt \$(date '+%s') ]; then
        date -s "@\$(date '+%s')"
fi

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs none /dev
 
echo 0 > /proc/sys/kernel/printk
clear
 
depmod -a
modprobe meson_dw_hdmi

systemd-udevd &
udevadm hwdb --update
udevadm trigger

pb-discover &
petitboot-nc
 
if [ -e /etc/pb-lockdown ] ; then
        echo "Failed to launch petitboot, rebooting!"
        echo 1 > /proc/sys/kernel/sysrq
        echo b > /proc/sysrq-trigger
else
        echo "Failed to launch petitboot, dropping to a shell"
        exec sh
fi
EOF
    chmod +x initramfs/init
    
fi

C=$(find initramfs/usr/sbin/ -type f | grep -c petitboot || true)
if [ "$C" -lt 1 ] ; then
    (
        cd petitboot
        make DESTDIR="$(realpath ../initramfs/)" install
    )
    strip initramfs/{sbin/*,lib/aarch64-linux-gnu/*,usr/lib/aarch64-linux-gnu/*,usr/lib/udev/*_id}
fi

if [ ! -f petitboot.img ] ; then
    (
        cd initramfs
        find . | cpio -H newc -o | lzma > ../petitboot.img
    )
    mkimage -A arm64 -O linux -T ramdisk -C lzma -a 0 -e 0 -n upetitboot.img -d petitboot.img upetitboot.img
fi

echo "Everything is OK."