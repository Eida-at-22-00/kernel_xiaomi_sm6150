#!/bin/bash

set -e
SECONDS=0

CLANG_DIR="$1"
ANDROID_VERSION="$2"

DEVICE="sweet"
ZIPNAME="galadriel-Main-$(date '+%Y%m%d-%H%M').zip"

step() {
  echo -e "\n==> $1"
}

if [[ ! -f "$CLANG_DIR/bin/clang" ]]; then
    echo "Clang not found at $CLANG_DIR"
    exit 1
fi

step "Cleaning previous build outputs..."
rm -rf out galadriel-*.zip AK3_tmp

export PATH="$CLANG_DIR/bin:$PATH"
CLANG_VER=$("$CLANG_DIR/bin/clang" --version | head -n1)

export ARCH=arm64
export KBUILD_BUILD_USER=galadriel
export KBUILD_BUILD_HOST=lotr

step "Starting compilation for $DEVICE"
echo "Android Version: $ANDROID_VERSION"
echo "Using Clang: $CLANG_VER"

make O=out ARCH=arm64 "${DEVICE}_defconfig"
make -j$(nproc) \
  O=out \
  ARCH=arm64 \
  LLVM=1 \
  LLVM_IAS=1 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

if [[ ! -f $kernel || ! -f $dtbo || ! -f $dtb ]]; then
  echo "Missing output files!"
  exit 1
fi

step "Creating flashable zip with AnyKernel3..."
git clone -q https://github.com/galadriel1402/AnyKernel3 -b master AK3_tmp
sed -i "s/device\.name1=.*/device.name1=${DEVICE}/" AK3_tmp/anykernel.sh
sed -i "s/device\.name2=.*/device.name2=${DEVICE}in/" AK3_tmp/anykernel.sh

cp $kernel $dtbo $dtb AK3_tmp/
cd AK3_tmp && zip -r9 "../$ZIPNAME" * -x .git && cd ..
rm -rf AK3_tmp out

step "Build finished in $((SECONDS / 60)) minutes and $((SECONDS % 60)) seconds"
echo "Output file: $ZIPNAME"
