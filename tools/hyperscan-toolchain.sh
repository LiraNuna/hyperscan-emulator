set -e

export CFLAGS="-std=c++11"

export NAME=hyperscan-toolchain
export THREADS=$(nproc --all)
export WORKING_DIR=$(mktemp -d -t hs-XXXXXXXXXX)

export TARGET=score-elf
export PREFIX=$(pwd)/$NAME
export PATH=$PREFIX/bin:$PATH

export BINUTILS_VERSION=2.35.2
export GCC_VERSION=4.9.4
# export NEWLIB_VERSION=1.20.0

mkdir -p "$WORKING_DIR"
cd "$WORKING_DIR"

echo "Downloading binutils $BINUTILS_VERSION..."
curl -C - --progress-bar "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2" -o "binutils-$BINUTILS_VERSION.tar.bz2"

echo "Downloading gcc $GCC_VERSION..."
curl -C - --progress-bar "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2" -o "gcc-$GCC_VERSION.tar.bz2"

# echo "Downloading newlib $NEWLIB_VERSION..."
# curl --progress-bar "ftp://sourceware.org/pub/newlib/newlib-$NEWLIB_VERSION.tar.gz" -o "newlib-$NEWLIB_VERSION.tar.gz"

echo "Unpacking binutils $BINUTILS_VERSION..."
tar xf "binutils-$BINUTILS_VERSION.tar.bz2"

echo "Unpacking gcc $GCC_VERSION..."
tar xf "gcc-$GCC_VERSION.tar.bz2"

# echo "Unpacking newlib $NEWLIB_VERSION..."
# tar xf "newlib-$NEWLIB_VERSION.tar.gz"
# rm -rf "newlib-$NEWLIB_VERSION.tar.gz"

# patch binutils for R_SCORE_24 problem
(cd "$WORKING_DIR/binutils-$BINUTILS_VERSION" && patch -p0 << 'EOF'
diff --git a/bfd/elf32-score.c b/bfd/elf32-score.c
index d1a910f279..eb93c7cfa1 100644
--- bfd/elf32-score.c
+++ bfd/elf32-score.c
@@ -2165,7 +2165,7 @@ score_elf_final_link_relocate (reloc_howto_type *howto,
       if ((offset & 0x1000000) != 0)
 	offset |= 0xfe000000;
       value += offset;
-      abs_value = value - rel_addr;
+      abs_value = (value < rel_addr) ? rel_addr - value : value - rel_addr;
       if ((abs_value & 0xfe000000) != 0)
 	return bfd_reloc_overflow;
       addend = (addend & ~howto->src_mask)
@@ -2241,7 +2241,7 @@ score_elf_final_link_relocate (reloc_howto_type *howto,
       if ((offset & 0x800) != 0)	/* Offset is negative.  */
 	offset |= 0xfffff000;
       value += offset;
-      abs_value = value - rel_addr;
+      abs_value = (value < rel_addr) ? rel_addr - value : value - rel_addr;
       if ((abs_value & 0xfffff000) != 0)
 	return bfd_reloc_overflow;
       addend = (addend & ~howto->src_mask) | (value & howto->src_mask);
diff --git a/bfd/elf32-score7.c b/bfd/elf32-score7.c
index ab5e32a29a..3bf4c30465 100644
--- bfd/elf32-score7.c
+++ bfd/elf32-score7.c
@@ -2066,7 +2066,7 @@ score_elf_final_link_relocate (reloc_howto_type *howto,
       if ((offset & 0x1000000) != 0)
 	offset |= 0xfe000000;
       value += offset;
-      abs_value = value - rel_addr;
+      abs_value = (value < rel_addr) ? rel_addr - value : value - rel_addr;
       if ((abs_value & 0xfe000000) != 0)
 	return bfd_reloc_overflow;
       addend = (addend & ~howto->src_mask)
@@ -2096,7 +2096,7 @@ score_elf_final_link_relocate (reloc_howto_type *howto,
       if ((offset & 0x800) != 0)	/* Offset is negative.  */
 	offset |= 0xfffff000;
       value += offset;
-      abs_value = value - rel_addr;
+      abs_value = (value < rel_addr) ? rel_addr - value : value - rel_addr;
       if ((abs_value & 0xfffff000) != 0)
 	return bfd_reloc_overflow;
       addend = (addend & ~howto->src_mask) | (value & howto->src_mask);
EOF
)

# compile binutils
mkdir -p "$WORKING_DIR/build-binutils" && cd "$WORKING_DIR/build-binutils"
$WORKING_DIR/binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix=$PREFIX --disable-nls --disable-multilib --disable-static  -v
make -j$THREADS all
make install
cd $WORKING_DIR

# compile first stage gcc
(cd "$WORKING_DIR/gcc-$GCC_VERSION"; ./contrib/download_prerequisites)
mkdir -p "$WORKING_DIR/build-gcc" && cd "$WORKING_DIR/build-gcc"
$WORKING_DIR/gcc-$GCC_VERSION/configure CXXFLAGS="--std=c++03" --target=$TARGET --prefix=$PREFIX --without-headers --with-newlib --enable-obsolete \
    --disable-libgomp --disable-libmudflap --disable-libssp --disable-libatomic --disable-libitm --disable-libsanitizer \
    --disable-libmpc --disable-libquadmath --disable-threads --disable-multilib --disable-target-zlib --with-system-zlib \
    --disable-shared --disable-nls --enable-languages=c --with-gnu-as --with-gnu-ld -v
make -j$THREADS all-gcc all-target-libgcc
make install-gcc install-target-libgcc
cd $WORKING_DIR

# compile newlib
# mkdir -p "$WORKING_DIR/build-newlib" && cd "$WORKING_DIR/build-newlib"
# $WORKING_DIR/newlib-$NEWLIB_VERSION/configure --target=$TARGET --prefix=$PREFIX --with-gnu-as --with-gnu-ld --disable-nls
# make all -j$THREADS
# make install
