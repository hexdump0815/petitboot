# IMPORTANT: this is work in progress and not working yet ...

status:
- overall status so far: it does not work yet
- it builds for aarch64 on ubuntu 20.04
- used as initrd it gives a boot menu on the connected monitor on the tested systems
- some screen corruption, but ctrl-l helps
- the boot devices are detected and petitboot.conf seems to be parsed properly
- sometimes a device rescan seems to be required
- tested systems so far
  - allwinner s905w: hard reboots directly after kexec
  - rockchip rk3318: kernel crashes early on at kexec initiated reboot
- plans
  - test more systems: allwinner h6, mediatek mt8173 & mt8183 chromebooks
  - test it on 32bit armv7l - exynos 4412 - and add support for it
  - maybe find ways to make it actually work :)
  - cleanup the script: only add required kernel modules, add options for different systems etc.

# odroid petitboot script based approach - original script for reference: make_uInitrd.sh.org

apt-get install -y git autoconf automake autopoint libtool pkg-config libudev-dev libdevmapper-dev flex bison gettext intltool libgcrypt20-dev gperf libcap-dev libblkid-dev libmount-dev xsltproc docbook-xsl docbook-xml python-lxml libncurses5-dev libncursesw5-dev libdw-dev libgpgme-dev libkmod-dev

mkdir -p /compile/source/petitboot
cd /compile/source/petitboot

/compile/doc/petitboot/make-petitboot-img.sh


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
