set -e
mkdir -p working-dir

export ROOT_DIR=$(pwd)
export NAME=hyperscan-toolchain
export THREADS=$(nproc --all)
export WORKING_DIR=$ROOT_DIR/working-dir

export TARGET=score-elf
export PREFIX=$ROOT_DIR/$NAME
export PATH=$PREFIX/bin:$PATH
export BINUTILS_VERSION=2.35.2
export GCC_VERSION=14.3.0
export NEWLIB_VERSION=4.6.0.20260123

mkdir -p "$WORKING_DIR"
cd "$WORKING_DIR"

echo "Downloading binutils $BINUTILS_VERSION..."
curl -C - --progress-bar "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2" -o "binutils-$BINUTILS_VERSION.tar.bz2"

echo "Downloading gcc $GCC_VERSION..."
curl -C - --progress-bar "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" -o "gcc-$GCC_VERSION.tar.xz"

echo "Downloading newlib $NEWLIB_VERSION..."
curl -C - --progress-bar "ftp://sourceware.org/pub/newlib/newlib-$NEWLIB_VERSION.tar.gz" -o "newlib-$NEWLIB_VERSION.tar.gz"

echo "Unpacking binutils $BINUTILS_VERSION..."
tar xf "binutils-$BINUTILS_VERSION.tar.bz2"

echo "Unpacking gcc $GCC_VERSION..."
tar xf "gcc-$GCC_VERSION.tar.xz"

echo "Unpacking newlib $NEWLIB_VERSION..."
tar xf "newlib-$NEWLIB_VERSION.tar.gz"

echo "Patching toolchain components..."
cd "$WORKING_DIR/binutils-$BINUTILS_VERSION" && patch -l -p0 < $ROOT_DIR/binutils-patch.diff
cd "$WORKING_DIR/gcc-$GCC_VERSION" && patch -l -p0 < $ROOT_DIR/gcc-patch.diff
cd "$WORKING_DIR/newlib-$NEWLIB_VERSION" && patch -l -p0 < $ROOT_DIR/newlib-patch.diff
cd "$WORKING_DIR"

echo "Compiling binutils..."
mkdir -p "$WORKING_DIR/build-binutils" && cd "$WORKING_DIR/build-binutils"
$WORKING_DIR/binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix=$PREFIX --disable-nls --disable-multilib --disable-static -v
make -j$THREADS all
make install
cd "$WORKING_DIR"

echo "Compiling first stage GCC..."
(cd "$WORKING_DIR/gcc-$GCC_VERSION"; ./contrib/download_prerequisites)
mkdir -p "$WORKING_DIR/build-gcc" && cd "$WORKING_DIR/build-gcc"
$WORKING_DIR/gcc-$GCC_VERSION/configure --target=$TARGET --prefix=$PREFIX --without-headers --with-newlib --enable-obsolete \
    --disable-libgomp --disable-libmudflap --disable-libssp --disable-libatomic --disable-libitm --disable-libsanitizer \
    --disable-libmpc --disable-libquadmath --disable-threads --disable-multilib --disable-target-zlib --with-system-zlib \
    --disable-shared --disable-nls --disable-lto --disable-libstdcxx --enable-languages=c --with-gnu-as --with-gnu-ld -v
make -j$THREADS all-gcc all-target-libgcc
make install-gcc install-target-libgcc
cd "$WORKING_DIR"

echo "Compiling Newlib..."
mkdir -p "$WORKING_DIR/build-newlib" && cd "$WORKING_DIR/build-newlib"
$WORKING_DIR/newlib-$NEWLIB_VERSION/configure --target=$TARGET --prefix=$PREFIX \
    --with-gnu-as --with-gnu-ld --disable-nls --disable-multilib --disable-newlib-supplied-syscalls
make all -j$THREADS
make install
cd "$WORKING_DIR"

echo "Compiling second stage GCC (C++)..."
mkdir -p "$WORKING_DIR/build-gcc-stage2" && cd "$WORKING_DIR/build-gcc-stage2"
$WORKING_DIR/gcc-$GCC_VERSION/configure --target=$TARGET --prefix=$PREFIX --with-newlib --enable-obsolete \
    --disable-libgomp --disable-libmudflap --disable-libssp --disable-libatomic --disable-libitm --disable-libsanitizer \
    --disable-libmpc --disable-libquadmath --disable-threads --disable-multilib --disable-target-zlib --with-system-zlib \
    --disable-shared --disable-nls --disable-lto --enable-languages=c,c++ --with-gnu-as --with-gnu-ld -v
make -j$THREADS all
make install
cd "$WORKING_DIR"

echo "Build complete."
