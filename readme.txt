# IMPORTANT: this is work in progress and not working yet ...

status:
- overall status so far: it does not work yet
- it builds for aarch64 and armv7l on ubuntu 20.04
- used as initrd it gives a boot menu on the connected monitor on the tested systems
- some screen corruption, but ctrl-l helps
- the boot devices are detected and petitboot.conf seems to be parsed properly
- sometimes a device rescan seems to be required
- tested systems so far
  - allwinner s905w: hard reboots directly after kexec
  - rockchip rk3318: kernel crashes early on at kexec initiated reboot
  - allwinner h3: pb-discover failes with 'device-mapper: reload ioctl on pb-mmcblk0p1-origin  failed: Invalid argument'
                  if doing kexec by hand: 'syscall kexec_file_load not available' (seems to just inform about a fallback
                                          to kexec_load) and after systemctl kexec it seems to hang after 'Starting
                                          Reboot via kexec...'
  - mediatek mt8173: kexec seems to shutdown properly (tested by hand), but seems to hang then (black screen)
- plans
  - test more systems: allwinner h6, mediatek mt8183 chromebooks, exynos 4412
  - maybe find ways to make it actually work :)
  - cleanup the script: only add required kernel modules, add options for different systems etc.

# odroid petitboot script based approach - original script for reference: make_uInitrd.sh.org

apt-get install -y git autoconf automake autopoint libtool pkg-config libudev-dev libdevmapper-dev flex bison gettext intltool libgcrypt20-dev gperf libcap-dev libblkid-dev libmount-dev xsltproc docbook-xsl docbook-xml python-lxml libncurses5-dev libncursesw5-dev libdw-dev libgpgme-dev libkmod-dev meson ninja-build

mkdir -p /compile/source/petitboot
cd /compile/source/petitboot

/compile/doc/petitboot/make-petitboot-img.sh


# building a chromeos bootable kernel including the petitboot initrd

# elm hana - lenovo chromebook n23 with mediatek mt8173
cp /boot/Image-5.10.25-stb-mt7+ Image
lz4 -f Image Image.lz4
dd if=/dev/zero of=bootloader.bin bs=512 count=1
cp /compile/doc/petitboot/petitboot-cmdline.elm cmdline
mkimage -D "-I dts -O dtb -p 2048" -f auto -A arm64 -O linux -T kernel -C lz4 -a 0 -d Image.lz4 -b /boot/dtb-5.10.25-stb-mt7+/mt8173-elm.dtb -b /boot/dtb-5.10.25-stb-mt7+/mt8173-elm-hana.dtb -b /boot/dtb-5.10.25-stb-mt7+/mt8173-elm-hana-rev7.dtb -b /boot/dtb-5.10.25-stb-mt7+/mt8183-kukui-krane-sku176.dtb -b /boot/dtb-5.10.25-stb-mt7+/rk3399-gru-bob.dtb -b /boot/dtb-5.10.25-stb-mt7+/rk3399-gru-kevin.dtb -i /compile/source/petitboot/make-petitboot-img/petitboot.img kernel.itb
vbutil_kernel --pack vmlinux.kpart --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline --bootloader bootloader.bin --vmlinuz kernel.itb --arch arm
cp -v vmlinux.kpart /boot/petitboot-vmlinux.kpart-elm-5.10.25-stb-mt7+
rm -f Image Image.lz4 cmdline bootloader.bin kernel.itb vmlinux.kpart


# building petitboot from source - not needed as its part of the above script now

git clone http://git.ozlabs.org/petitboot
cd petitboot/
git checkout 7edc34c4ee8dc0913ea1a4ec64d3fbe6d64afc6d
apt-get install libdevmapper-dev
./bootstrap 
./configure --prefix=/opt/petitboot
make
make install


# interesting links
https://mirrors.edge.kernel.org/pub/linux/kernel/people/geoff/petitboot/petitboot.html
https://github.com/Dmole/odroid_petitboot_script
https://2018.osfc.io/uploads/talk/paper/9/petitboot.pdf
https://www.youtube.com/watch?v=4JbDb4bRBK4
https://github.com/ArthurHeymans/petitboot_for_coreboot
https://wiki.archlinux.org/index.php/kexec
https://github.com/linuxboot/linuxboot
https://wiki.debian.org/de/accessibility
https://github.com/alpernebbi/depthcharge-tools
https://lightofdawn.org/wiki/wiki.cgi/-wiki/KexecBootMenu
