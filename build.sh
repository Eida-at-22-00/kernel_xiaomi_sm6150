#!/bin/bash
#
# Kernel compilation script

set -e
SECONDS=0

# Allowed device codenames
ALLOWED_CODENAMES=("sweet" "tucana" "toco" "phoenix" "davinci")

# Ask for device codename
read -p "Enter device codename: " DEVICE

# Validate codename
if [[ ! " ${ALLOWED_CODENAMES[@]} " =~ " ${DEVICE} " ]]; then
    echo "❌ Error: Invalid codename. Allowed: ${ALLOWED_CODENAMES[*]}"
    exit 1
fi

# Clang setup
CLANG_DIR="/axion/prebuilts/clang/host/linux-x86/clang-r547379"
CLANG_BIN="$CLANG_DIR/bin"
export PATH="$CLANG_BIN:$PATH"

CLANG_VER=$("$CLANG_BIN/clang" --version | head -n1)
CLANG_SHORT=$(basename "$CLANG_DIR")

ZIPNAME="VantomKernel-KSU-${DEVICE}-$(date '+%Y%m%d-%H%M').zip"

export ARCH=arm64
export KBUILD_BUILD_USER=eidawon
export KBUILD_BUILD_HOST=nekonote

# Clean output directory if requested
if [[ $1 == "-c" || $1 == "--clean" ]]; then
    rm -rf out
    echo "🧹 Cleaned output folder"
fi

# Confirm compiler
echo -e "\n🚀 Starting compilation for ${DEVICE} using ${CLANG_VER}...\n"
echo "🔧 Using Clang from: $(which clang)"

# Kernel compilation
make O=out ARCH=arm64 "${DEVICE}_defconfig"
make -j$(nproc) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-

# Output paths
kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

# Check build success
if [[ ! -f $kernel || ! -f $dtbo || ! -f $dtb ]]; then
    echo -e "\n❌ Compilation failed!"
    exit 1
fi

echo -e "\n✅ Kernel compiled successfully! Creating flashable zip...\n"

# Handle AnyKernel3
AK3_DIR=${AK3_DIR:-"AnyKernel3"}

if [[ -d "$AK3_DIR" ]]; then
    cp -r "$AK3_DIR" AnyKernel3
else
    echo "📦 Cloning AnyKernel3..."
    if ! git clone -q https://github.com/basamaryan/AnyKernel3 -b master AnyKernel3; then
        echo -e "\n❌ Failed to get AnyKernel3! Aborting..."
        exit 1
    fi
fi

# Configure anykernel.sh
sed -i "s/device\.name1=.*/device.name1=${DEVICE}/" AnyKernel3/anykernel.sh
sed -i "s/device\.name2=.*/device.name2=${DEVICE}in/" AnyKernel3/anykernel.sh

# Copy built files
cp "$kernel" "$dtbo" "$dtb" AnyKernel3

# Create flashable zip
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git
cd ..
rm -rf AnyKernel3

echo -e "\n🎉 Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)"
echo "📦 Output: $ZIPNAME"

# Show git commit hash (if inside repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
    HASH=$(git rev-parse --short HEAD)
    echo "🔧 Commit: $HASH"
fi

# Send via Telegram (if available)
if command -v telegram &> /dev/null && [[ -f $ZIPNAME ]]; then
    telegram -f "$ZIPNAME" -M "✅ Kernel built for $DEVICE using $CLANG_SHORT\nLatest commit: $HASH\n⏱️ Time: $((SECONDS / 60))m $((SECONDS % 60))s"
else
    echo "📭 Skipping Telegram upload (telegram command not found or zip missing)"
fi
