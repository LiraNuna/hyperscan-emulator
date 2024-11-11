set -e
mkdir -p working-dir

export NAME=hyperscan-toolchain
export THREADS=$(nproc --all)
export WORKING_DIR=$(pwd)/working-dir

export TARGET=score-elf
export PREFIX=$(pwd)/$NAME
export PATH=$PREFIX/bin:$PATH

export BINUTILS_VERSION=14.2.0
export GCC_VERSION=4.9.4
# export NEWLIB_VERSION=1.20.0

mkdir -p "$WORKING_DIR"
cd "$WORKING_DIR"

echo "Downloading binutils $BINUTILS_VERSION..."
curl -C - --progress-bar "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz" -o "binutils-$BINUTILS_VERSION.tar.xz"

echo "Downloading gcc $GCC_VERSION..."
curl -C - --progress-bar "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" -o "gcc-$GCC_VERSION.tar.xz"

# echo "Downloading newlib $NEWLIB_VERSION..."
# curl --progress-bar "ftp://sourceware.org/pub/newlib/newlib-$NEWLIB_VERSION.tar.gz" -o "newlib-$NEWLIB_VERSION.tar.gz"

echo "Unpacking binutils $BINUTILS_VERSION..."
tar xf "binutils-$BINUTILS_VERSION.tar.xz"

echo "Unpacking gcc $GCC_VERSION..."
tar xf "gcc-$GCC_VERSION.tar.xz"

# echo "Unpacking newlib $NEWLIB_VERSION..."
# tar xf "newlib-$NEWLIB_VERSION.tar.gz"
# rm -rf "newlib-$NEWLIB_VERSION.tar.gz"

# patch binutils for R_SCORE_24 problem
cd "$WORKING_DIR/binutils-$BINUTILS_VERSION" && patch -p0 << binutils-patch.diff
cd "$WORKING_DIR/gcc" && patch -p0 << gcc-patch.diff

# compile binutils
mkdir -p "$WORKING_DIR/build-binutils" && cd "$WORKING_DIR/build-binutils"
$WORKING_DIR/binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix=$PREFIX --disable-nls --disable-multilib --disable-static  -v
make -j$THREADS all
make install
cd $WORKING_DIR

# compile first stage gcc
(cd "$WORKING_DIR/gcc-$GCC_VERSION"; ./contrib/download_prerequisites)
mkdir -p "$WORKING_DIR/build-gcc" && cd "$WORKING_DIR/build-gcc"
$WORKING_DIR/gcc-$GCC_VERSION/configure --target=$TARGET --prefix=$PREFIX --without-headers --with-newlib --enable-obsolete \
    --disable-libgomp --disable-libmudflap --disable-libssp --disable-libatomic --disable-libitm --disable-libsanitizer \
    --disable-libmpc --disable-libquadmath --disable-threads --disable-multilib --disable-target-zlib --with-system-zlib \
    --disable-shared --disable-nls --disable-lto --disable-libstdcxx --enable-languages=c --with-gnu-as --with-gnu-ld -v
make -j$THREADS all-gcc all-target-libgcc
make install-gcc install-target-libgcc
cd $WORKING_DIR

# compile newlib
# mkdir -p "$WORKING_DIR/build-newlib" && cd "$WORKING_DIR/build-newlib"
# $WORKING_DIR/newlib-$NEWLIB_VERSION/configure --target=$TARGET --prefix=$PREFIX --with-gnu-as --with-gnu-ld --disable-nls
# make all -j$THREADS
# make install
