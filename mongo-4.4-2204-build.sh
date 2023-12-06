#!/bin/bash

echo "this is not a script! just a collection of notes to copy-paste"
exit 1




# Arm-Specific Cross-Compilation Instructions
# * build on vagrant+libvirt for max speed (big desktop pc, lots of ram - or just use EC2)
# * box: generic/ubuntu2004
# * build as root
# * run inside screen to avoid disconnects

apt update
apt upgrade -y
# reboot!
apt install -y python3-all python3-pip build-essential python3-venv libcurl4-openssl-dev screen


cat  > /etc/apt/sources.list <<DEV
deb [arch=amd64,arm64] http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse

deb [arch=amd64,arm64] http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse

deb [arch=amd64,arm64] http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

deb [arch=amd64,arm64] http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse

deb [arch=amd64,arm64] http://archive.canonical.com/ubuntu/ jammy partner
# deb-src http://archive.canonical.com/ubuntu/ jammy partner


deb [arch=arm64] http://ports.ubuntu.com jammy main multiverse universe
deb [arch=arm64] http://ports.ubuntu.com jammy-security main multiverse universe
deb [arch=arm64] http://ports.ubuntu.com jammy-backports main multiverse universe
deb [arch=arm64] http://ports.ubuntu.com jammy-updates main multiverse universe
DEV

dpkg --add-architecture arm64
apt-get update || echo "continuing after 'apt-get update'"
compiler_version=11
apt-get install -y gcc-${compiler_version}-aarch64-linux-gnu g++-${compiler_version}-aarch64-linux-gnu python3-venv
apt-get install -y libssl-dev:arm64 libcurl4-openssl-dev:arm64 liblzma-dev:arm64 libssl-dev:arm64 lzma:arm64

# MongoDB Instructions

git clone -b r4.4.26 https://github.com/mongodb/mongo r4.4.26
cd r4.4.26
python3 -m venv python3-venv
source python3-venv/bin/activate
python -m pip install "pip==21.0.1"
python -m pip install -r etc/pip/compile-requirements.txt
python -m pip install keyring jsonschema memory_profiler puremagic networkx cxxfilt

# Lowered -j to 1 below the number of cores available in order to not over-saturate build machine.
# This helps keep the system responsive to user input during the compile.

# The important part for cross-compilation is to specify the arm toolchain for the following three tools:
#  AR: Archive tool
#  CC: C compiler
# CXX: C++ compiler

# Should take less than a minute.
CORES=$(lscpu | awk '/^CPU\(s\)/ {print $2}')
# =============== does not work - includes CASA instruction from armv8.1
#time python3 buildscripts/scons.py -j${CORES} AR=/usr/bin/aarch64-linux-gnu-ar CC=/usr/bin/aarch64-linux-gnu-gcc-${compiler_version} CXX=/usr/bin/aarch64-linux-gnu-g++-${compiler_version} CCFLAGS="-march=armv8-a+crc -moutline-atomics -mtune=cortex-a72" --dbg=off --opt=on --link-model=static --disable-warnings-as-errors --ninja generate-ninja NINJA_PREFIX=aarch64_gcc_s VARIANT_DIR=aarch64_gcc_s DESTDIR=aarch64_gcc_s


# takes about 1.5 hrs on big desktop or 4+ on a laptop
#time CCFLAGS="-march=armv8-a+crc -moutline-atomics -mtune=cortex-a72" ninja -f aarch64_gcc_s.ninja -j${CORES} install-devcore # For MongoDB 4.x+
# ===============

# install objcopy for arm64
# see https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
# I picked AArch64 GNU/Linux target (aarch64-none-linux-gnu)
cd /home/vagrant
wget "https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz?rev=22c39fc25e5541818967b4ff5a09ef3e&hash=B9FEDC2947EB21151985C2DC534ECCEC"
tar -xf 'arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz?rev=22c39fc25e5541818967b4ff5a09ef3e&hash=B9FEDC2947EB21151985C2DC534ECCEC'
cd r4.4.26

export OBJCOPY=/home/vagrant/arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-linux-gnu/aarch64-none-linux-gnu/bin/objcopy

# theres probably a correct way to do this but at this point I dont care and $OBJCOPY specififed in SConstruct seems ignored
mv /usr/bin/objcopy /usr/bin/objcopy.orig
cp /home/vagrant/arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-linux-gnu/aarch64-none-linux-gnu/bin/objcopy /usr/bin/objcopy


# https://andyfelong.com/2021/08/mongodb-4-4-under-raspberry-pi-os-64-bit-raspbian64/

#
# APPLY PATCH disable-armv-8.2.patch now!
#


# still illegal instruction!
time python buildscripts/scons.py -j${CORES} \
    --disable-warnings-as-errors --ssl CC=/usr/bin/aarch64-linux-gnu-gcc-${compiler_version} \
    CXX=/usr/bin/aarch64-linux-gnu-g++-${compiler_version} \
    CCFLAGS="-march=armv8-a+crc -mtune=cortex-a72" \
    CXXFLAGS="-std=c++17" \
    --install-mode=hygienic --install-action=hardlink --separate-debug archive-core{,-debug}
# https://www.mongodb.com/community/forums/t/core-dump-on-mongodb-5-0-on-rpi-4/115291/13



# Minimize size of executables for embedded use by removing symbols
#pushd aarch64_gcc_s/bin
#mv mongo mongo.debug
#mv mongod mongod.debug
#mv mongos mongos.debug
#aarch64-linux-gnu-strip mongo.debug -o mongo
#aarch64-linux-gnu-strip mongod.debug -o mongod
#aarch64-linux-gnu-strip mongos.debug -o mongos
#popd

# Generate release (on Mac OS)
#$ tar --gname root --uname root -czvf mongodb.ce.pi.r7.0.3.tar.gz LICENSE-Community.txt README.md mongo{d,,s}
# Generate release (on Linux)

# do things the easy way
#mkdir mongodb.ce.pi.r4.4.26
#cp aarch64_gcc_s/bin/mongo mongodb.ce.pi.r4.4.26
#cp aarch64_gcc_s/bin/mongod mongodb.ce.pi.r4.4.26
#cp aarch64_gcc_s/bin/mongos mongodb.ce.pi.r4.4.26
#cp LICENSE-Community.txt mongodb.cd.pi.r4.4.26
#cp README mongodb.cd.pi.r4.4.26

cp -r build/install/ mongodb.ce.pi.r4.4.26
rm mongodb.ce.pi.r4.4.26/install/bin/*.debug
tar -czvf mongodb.ce.pi.r4.4.26.tar.gz mongodb.ce.pi.r4.4.26