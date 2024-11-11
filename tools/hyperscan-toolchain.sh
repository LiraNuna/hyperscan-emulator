set -e
mkdir -p working-dir

export CFLAGS="-std=c++11"

export NAME=hyperscan-toolchain
export THREADS=$(nproc --all)
export WORKING_DIR=$(pwd)/working-dir

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
git clone --depth=1 git://gcc.gnu.org/git/gcc.git gcc
cd gcc
git checkout 7b5c974dfc83edfb534dc0550dee8b0e8fd32d96
cd ..

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

(cd "$WORKING_DIR/gcc" && patch -p0 << 'EOF'
diff --git a/config.sub b/config.sub
index 38f3d037a..800d4e50c 100755
--- a/config.sub
+++ b/config.sub
@@ -1261,6 +1261,7 @@ case $cpu-$vendor in
 			| sparc | sparc64 | sparc64b | sparc64v | sparc86x | sparclet \
 			| sparclite \
 			| sparcv8 | sparcv9 | sparcv9b | sparcv9v | sv1 | sx* \
+			| score \
 			| spu \
 			| tahoe \
 			| thumbv7* \
diff --git a/gcc/config.gcc b/gcc/config.gcc
index 9b616bd6e..db5aa6913 100644
--- a/gcc/config.gcc
+++ b/gcc/config.gcc
@@ -274,6 +274,7 @@ esac
 case ${target} in
      ia64*-*-hpux* | ia64*-*-*vms* | ia64*-*-elf*	\
    | nios2*-*-*				\
+   | score-*				\
  )
     if test "x$enable_obsolete" != xyes; then
       echo "*** Configuration ${target} is obsolete." >&2
@@ -578,6 +579,10 @@ sparc*-*-*)
 	d_target_objs="sparc-d.o"
 	extra_headers="visintrin.h"
 	;;
+score*-*-*)
+	cpu_type=score
+	extra_options="${extra_options} g.opt"
+	;;
 s390*-*-*)
 	cpu_type=s390
 	d_target_objs="s390-d.o"
@@ -3306,6 +3311,16 @@ s390x-ibm-tpf*)
 	extra_options="${extra_options} s390/tpf.opt"
 	tmake_file="${tmake_file} s390/t-s390"
 	;;
+score-*-elf)
+	gas=yes
+	gnu_ld=yes
+        tm_file="elfos.h score/elf.h score/score.h newlib-stdint.h"
+        tm_p_file=score/score-protos.h
+        md_file=score/score.md
+        extra_modes=score/score-modes.def
+		out_file=score/score.cc
+		common_out_file="default-common.cc"
+        ;;
 sh-*-elf* | sh[12346l]*-*-elf* | \
   sh-*-linux* | sh[2346lbe]*-*-linux* | \
   sh-*-netbsdelf* | shl*-*-netbsdelf*)
diff --git a/gcc/config/rx/rx.cc b/gcc/config/rx/rx.cc
index 00242e8a1..5985b75ab 100644
--- a/gcc/config/rx/rx.cc
+++ b/gcc/config/rx/rx.cc
@@ -3637,8 +3637,11 @@ rx_hard_regno_mode_ok (unsigned int regno, machine_mode)
   return REGNO_REG_CLASS (regno) == GR_REGS;
 }

-/* Implement TARGET_MODES_TIEABLE_P.  */
-
+/* Implement TARGET_MODES_TIEABLE_P.
+   Value is 1 if it is a good idea to tie two pseudo registers
+   when one has mode MODE1 and one has mode MODE2.
+   If HARD_REGNO_MODE_OK could produce different values for MODE1 and MODE2,
+   for any hard reg, then this must be 0 for correct output.  */
 static bool
 rx_modes_tieable_p (machine_mode mode1, machine_mode mode2)
 {
diff --git a/gcc/config/score/constraints.md b/gcc/config/score/constraints.md
new file mode 100644
index 000000000..50b0ebfda
--- /dev/null
+++ b/gcc/config/score/constraints.md
@@ -0,0 +1,93 @@
+;; Constraint definitions for S+CORE
+;; Copyright (C) 2005-2014 Free Software Foundation, Inc.
+;; Contributed by Sunnorth.
+
+;; This file is part of GCC.
+
+;; GCC is free software; you can redistribute it and/or modify it
+;; under the terms of the GNU General Public License as published
+;; by the Free Software Foundation; either version 3, or (at your
+;; option) any later version.
+
+;; GCC is distributed in the hope that it will be useful, but WITHOUT
+;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
+;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
+;; License for more details.
+
+;; You should have received a copy of the GNU General Public License
+;; along with GCC; see the file COPYING3.  If not see
+;; <http://www.gnu.org/licenses/>.  */
+
+;; -------------------------------------------------------------------------
+;; Constraints
+;; -------------------------------------------------------------------------
+
+;; Register constraints.
+(define_register_constraint "d" "G32_REGS"
+  "r0 to r31")
+
+(define_register_constraint "e" "G16_REGS"
+  "r0 to r15")
+
+(define_register_constraint "t" "T32_REGS"
+  "r8 to r11 | r22 to r27")
+
+(define_register_constraint "h" "HI_REG"
+  "hi")
+
+(define_register_constraint "l" "LO_REG"
+  "lo")
+
+(define_register_constraint "x" "CE_REGS"
+  "hi + lo")
+
+(define_register_constraint "q" "CN_REG"
+  "cnt")
+
+(define_register_constraint "y" "LC_REG"
+  "lcb")
+
+(define_register_constraint "z" "SC_REG"
+  "scb")
+
+(define_register_constraint "a" "SP_REGS"
+  "cnt + lcb + scb")
+
+(define_register_constraint "c" "CR_REGS"
+  "cr0 to cr15")
+
+;; Integer constant constraints.
+(define_constraint "I"
+  "High 16-bit constant (32-bit constant with 16 LSBs zero)."
+  (and (match_code "const_int")
+       (match_test "(ival & 0xffff) == 0")))
+
+(define_constraint "J"
+  "Unsigned 5 bit integer (in the range 0 to 31)."
+  (and (match_code "const_int")
+       (match_test "ival >= 0 && ival <= 31")))
+
+(define_constraint "K"
+  "Unsigned 16 bit integer (in the range 0 to 65535)."
+  (and (match_code "const_int")
+       (match_test "ival >= 0 && ival <= 65535")))
+
+(define_constraint "L"
+  "Signed 16 bit integer (in the range −32768 to 32767)."
+  (and (match_code "const_int")
+       (match_test "ival >= -32768 && ival <= 32767")))
+
+(define_constraint "M"
+  "Unsigned 14 bit integer (in the range 0 to 16383)."
+  (and (match_code "const_int")
+       (match_test "ival >= 0 && ival <= 16383")))
+
+(define_constraint "N"
+  "Signed 14 bit integer (in the range −8192 to 8191)."
+  (and (match_code "const_int")
+       (match_test "ival >= -8192 && ival <= 8191")))
+
+(define_constraint "Z"
+  "Any SYMBOL_REF."
+  (and (match_code "symbol_ref")
+       (match_test "GET_CODE (op) == SYMBOL_REF")))
diff --git a/gcc/config/score/elf.h b/gcc/config/score/elf.h
new file mode 100644
index 000000000..a3fb8a930
--- /dev/null
+++ b/gcc/config/score/elf.h
@@ -0,0 +1,97 @@
+/* elf.h for Sunplus S+CORE processor
+   Copyright (C) 2005-2014 Free Software Foundation, Inc.
+
+   This file is part of GCC.
+
+   GCC is free software; you can redistribute it and/or modify it
+   under the terms of the GNU General Public License as published
+   by the Free Software Foundation; either version 3, or (at your
+   option) any later version.
+
+   GCC is distributed in the hope that it will be useful, but WITHOUT
+   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
+   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
+   License for more details.
+
+   You should have received a copy of the GNU General Public License
+   along with GCC; see the file COPYING3.  If not see
+   <http://www.gnu.org/licenses/>.  */
+
+#define OBJECT_FORMAT_ELF
+
+/* Biggest alignment supported by the object file format of this machine.  */
+#undef  MAX_OFILE_ALIGNMENT
+#define MAX_OFILE_ALIGNMENT        (32768 * 8)
+
+/* Switch into a generic section.  */
+#undef  TARGET_ASM_NAMED_SECTION
+#define TARGET_ASM_NAMED_SECTION  default_elf_asm_named_section
+
+/* The following macro defines the format used to output the second
+   operand of the .type assembler directive.  */
+#define TYPE_OPERAND_FMT        "@%s"
+
+#undef TYPE_ASM_OP
+#define TYPE_ASM_OP             "\t.type\t"
+
+#undef SIZE_ASM_OP
+#define SIZE_ASM_OP             "\t.size\t"
+
+/* A c expression whose value is a string containing the
+   assembler operation to identify the following data as
+   uninitialized global data.  */
+#ifndef BSS_SECTION_ASM_OP
+#define BSS_SECTION_ASM_OP      "\t.section\t.bss"
+#endif
+
+#ifndef ASM_OUTPUT_ALIGNED_BSS
+#define ASM_OUTPUT_ALIGNED_BSS asm_output_aligned_bss
+#endif
+
+#define ASM_OUTPUT_DEF(FILE, LABEL1, LABEL2)                       \
+  do {                                                             \
+    fputc ('\t', FILE);                                            \
+    assemble_name (FILE, LABEL1);                                  \
+    fputs (" = ", FILE);                                           \
+    assemble_name (FILE, LABEL2);                                  \
+    fputc ('\n', FILE);                                            \
+ } while (0)
+
+
+/* This is how we tell the assembler that a symbol is weak.  */
+#undef  ASM_WEAKEN_LABEL
+#define ASM_WEAKEN_LABEL(FILE, NAME) ASM_OUTPUT_WEAK_ALIAS (FILE, NAME, 0)
+
+#define ASM_OUTPUT_WEAK_ALIAS(FILE, NAME, VALUE)      \
+  do {                                                \
+    fputs ("\t.weak\t", FILE);                        \
+    assemble_name (FILE, NAME);                       \
+    if (VALUE)                                        \
+      {                                               \
+        fputc (' ', FILE);                            \
+        assemble_name (FILE, VALUE);                  \
+      }                                               \
+    fputc ('\n', FILE);                               \
+ } while (0)
+
+#define MAKE_DECL_ONE_ONLY(DECL) (DECL_WEAK (DECL) = 1)
+
+/* On elf, we *do* have support for the .init and .fini sections, and we
+   can put stuff in there to be executed before and after `main'.  We let
+   crtstuff.c and other files know this by defining the following symbols.
+   The definitions say how to change sections to the .init and .fini
+   sections.  This is the same for all known elf assemblers.  */
+#undef  INIT_SECTION_ASM_OP
+#define INIT_SECTION_ASM_OP     "\t.section\t.init"
+#undef  FINI_SECTION_ASM_OP
+#define FINI_SECTION_ASM_OP     "\t.section\t.fini"
+
+/* Don't set the target flags, this is done by the linker script */
+#undef  LIB_SPEC
+#define LIB_SPEC ""
+
+#undef  STARTFILE_SPEC
+#define STARTFILE_SPEC          "crti%O%s crtbegin%O%s"
+
+#undef  ENDFILE_SPEC
+#define ENDFILE_SPEC            "crtend%O%s crtn%O%s"
diff --git a/gcc/config/score/predicates.md b/gcc/config/score/predicates.md
new file mode 100644
index 000000000..543be7260
--- /dev/null
+++ b/gcc/config/score/predicates.md
@@ -0,0 +1,152 @@
+;; Predicate definitions for Sunplus S+CORE.
+;; Copyright (C) 2005-2014 Free Software Foundation, Inc.
+;;
+;; This file is part of GCC.
+;;
+;; GCC is free software; you can redistribute it and/or modify
+;; it under the terms of the GNU General Public License as published by
+;; the Free Software Foundation; either version 3, or (at your option)
+;; any later version.
+;;
+;; GCC is distributed in the hope that it will be useful,
+;; but WITHOUT ANY WARRANTY; without even the implied warranty of
+;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+;; GNU General Public License for more details.
+;;
+;; You should have received a copy of the GNU General Public License
+;; along with GCC; see the file COPYING3.  If not see
+;; <http://www.gnu.org/licenses/>.
+
+(define_predicate "const_uimm5"
+  (match_code "const_int")
+{
+  return IMM_IN_RANGE (INTVAL (op), 5, 0);
+})
+
+(define_predicate "const_simm12"
+  (match_code "const_int")
+{
+  return IMM_IN_RANGE (INTVAL (op), 12, 1);
+})
+
+(define_predicate "const_simm15"
+  (match_code "const_int")
+{
+  return IMM_IN_RANGE (INTVAL (op), 15, 1);
+})
+
+(define_predicate "arith_operand"
+  (ior (match_code "const_int")
+       (match_operand 0 "register_operand")))
+
+(define_predicate "score_register_operand"
+  (match_code "reg,subreg")
+{
+  if (GET_CODE (op) == SUBREG)
+    op = SUBREG_REG (op);
+
+  return (GET_CODE (op) == REG)
+          && (REGNO (op) != CC_REGNUM);
+})
+
+(define_predicate "const_call_insn_operand"
+  (match_code "const,symbol_ref,label_ref")
+{
+  enum score_symbol_type symbol_type;
+
+  return (score_symbolic_constant_p (op, &symbol_type)
+          && (symbol_type == SYMBOL_GENERAL));
+})
+
+(define_predicate "call_insn_operand"
+  (ior (match_operand 0 "const_call_insn_operand")
+       (match_operand 0 "register_operand")))
+
+(define_predicate "hireg_operand"
+  (and (match_code "reg")
+       (match_test "REGNO (op) == HI_REGNUM")))
+
+(define_predicate "loreg_operand"
+  (and (match_code "reg")
+       (match_test "REGNO (op) == LO_REGNUM")))
+
+(define_predicate "sr0_operand"
+  (and (match_code "reg")
+       (match_test "REGNO (op) == CN_REGNUM")))
+
+(define_predicate "g32reg_operand"
+  (and (match_code "reg")
+       (match_test "GP_REG_P (REGNO (op))")))
+
+(define_predicate "branch_n_operator"
+  (match_code "lt,ge"))
+
+(define_predicate "branch_nz_operator"
+  (match_code "eq,ne,lt,ge"))
+
+(define_predicate "score_load_multiple_operation"
+  (match_code "parallel")
+{
+  int count = XVECLEN (op, 0);
+  int dest_regno;
+  int i;
+
+  /* Perform a quick check so we don't blow up below.  */
+  if (count <= 1
+      || GET_CODE (XVECEXP (op, 0, 0)) != SET
+      || GET_CODE (SET_DEST (XVECEXP (op, 0, 0))) != REG
+      || GET_CODE (SET_SRC (XVECEXP (op, 0, 0))) != MEM)
+    return 0;
+
+  dest_regno = REGNO (SET_DEST (XVECEXP (op, 0, 0)));
+
+  for (i = 1; i < count; i++)
+    {
+      rtx elt = XVECEXP (op, 0, i);
+
+      if (GET_CODE (elt) != SET
+          || GET_CODE (SET_DEST (elt)) != REG
+          || GET_MODE (SET_DEST (elt)) != SImode
+          || REGNO (SET_DEST (elt)) != (unsigned) (dest_regno + i)
+          || GET_CODE (SET_SRC (elt)) != MEM
+          || GET_MODE (SET_SRC (elt)) != SImode
+          || GET_CODE (XEXP (SET_SRC (elt), 0)) != POST_INC)
+        return 0;
+    }
+
+  return 1;
+})
+
+(define_predicate "score_store_multiple_operation"
+  (match_code "parallel")
+{
+  int count = XVECLEN (op, 0);
+  int src_regno;
+  int i;
+
+  /* Perform a quick check so we don't blow up below.  */
+  if (count <= 1
+      || GET_CODE (XVECEXP (op, 0, 0)) != SET
+      || GET_CODE (SET_DEST (XVECEXP (op, 0, 0))) != MEM
+      || GET_CODE (SET_SRC (XVECEXP (op, 0, 0))) != REG)
+    return 0;
+
+  src_regno = REGNO (SET_SRC (XVECEXP (op, 0, 0)));
+
+  for (i = 1; i < count; i++)
+    {
+      rtx elt = XVECEXP (op, 0, i);
+
+      if (GET_CODE (elt) != SET
+          || GET_CODE (SET_SRC (elt)) != REG
+          || GET_MODE (SET_SRC (elt)) != SImode
+          || REGNO (SET_SRC (elt)) != (unsigned) (src_regno + i)
+          || GET_CODE (SET_DEST (elt)) != MEM
+          || GET_MODE (SET_DEST (elt)) != SImode
+          || GET_CODE (XEXP (SET_DEST (elt), 0)) != PRE_DEC)
+        return 0;
+    }
+
+  return 1;
+})
+
diff --git a/gcc/config/score/score-conv.h b/gcc/config/score/score-conv.h
new file mode 100644
index 000000000..c362d9f2d
--- /dev/null
+++ b/gcc/config/score/score-conv.h
@@ -0,0 +1,78 @@
+/* score-conv.h for Sunplus S+CORE processor
+   Copyright (C) 2005-2014 Free Software Foundation, Inc.
+
+   This file is part of GCC.
+
+   GCC is free software; you can redistribute it and/or modify it
+   under the terms of the GNU General Public License as published
+   by the Free Software Foundation; either version 3, or (at your
+   option) any later version.
+
+   GCC is distributed in the hope that it will be useful, but WITHOUT
+   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
+   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
+   License for more details.
+
+   You should have received a copy of the GNU General Public License
+   along with GCC; see the file COPYING3.  If not see
+   <http://www.gnu.org/licenses/>.  */
+
+#ifndef GCC_SCORE_CONV_H
+#define GCC_SCORE_CONV_H
+
+#define GP_REG_FIRST                    0U
+#define GP_REG_LAST                     31U
+#define GP_REG_NUM                      (GP_REG_LAST - GP_REG_FIRST + 1U)
+#define GP_DBX_FIRST                    0U
+
+#define CE_REG_FIRST                    48U
+#define CE_REG_LAST                     49U
+#define CE_REG_NUM                      (CE_REG_LAST - CE_REG_FIRST + 1U)
+
+#define ARG_REG_FIRST                   4U
+#define ARG_REG_LAST                    7U
+#define ARG_REG_NUM                     (ARG_REG_LAST - ARG_REG_FIRST + 1U)
+
+#define REG_CONTAIN(REGNO, FIRST, NUM) \
+  ((unsigned int)((int) (REGNO) - (FIRST)) < (NUM))
+
+#define GP_REG_P(REGNO)        REG_CONTAIN (REGNO, GP_REG_FIRST, GP_REG_NUM)
+
+#define G8_REG_P(REGNO)        REG_CONTAIN (REGNO, GP_REG_FIRST, 8)
+
+#define G16_REG_P(REGNO)       REG_CONTAIN (REGNO, GP_REG_FIRST, 16)
+
+#define CE_REG_P(REGNO)        REG_CONTAIN (REGNO, CE_REG_FIRST, CE_REG_NUM)
+
+#define GR_REG_CLASS_P(C)        ((C) == G16_REGS || (C) == G32_REGS)
+#define SP_REG_CLASS_P(C) \
+  ((C) == CN_REG || (C) == LC_REG || (C) == SC_REG || (C) == SP_REGS)
+#define CP_REG_CLASS_P(C) \
+  ((C) == CP1_REGS || (C) == CP2_REGS || (C) == CP3_REGS || (C) == CPA_REGS)
+#define CE_REG_CLASS_P(C) \
+  ((C) == HI_REG || (C) == LO_REG || (C) == CE_REGS)
+
+#define UIMM_IN_RANGE(V, W) \
+  ((V) >= 0 \
+   && ((unsigned HOST_WIDE_INT) (V) \
+       <= (((unsigned HOST_WIDE_INT) 2 << ((W) - 1)) - 1)))
+
+#define SIMM_IN_RANGE(V, W)                            \
+  ((V) >= ((HOST_WIDE_INT) -1 << ((W) - 1))      \
+   && (V) <= (((HOST_WIDE_INT) 1 << ((W) - 1)) - 1))
+
+#define IMM_IN_RANGE(V, W, S)  \
+  ((S) ? SIMM_IN_RANGE (V, W) : UIMM_IN_RANGE (V, W))
+
+#define IMM_IS_POW_OF_2(V, E1, E2)                 \
+  ((V) >= ((unsigned HOST_WIDE_INT) 1 << (E1))     \
+   && (V) <= ((unsigned HOST_WIDE_INT) 1 << (E2))  \
+   && ((V) & ((V) - 1)) == 0)
+
+enum score_symbol_type
+{
+  SYMBOL_GENERAL,
+  SYMBOL_SMALL_DATA  /* The symbol refers to something in a small data section  */
+};
+
+#endif
diff --git a/gcc/config/score/score-generic.md b/gcc/config/score/score-generic.md
new file mode 100644
index 000000000..4f155f9f4
--- /dev/null
+++ b/gcc/config/score/score-generic.md
@@ -0,0 +1,44 @@
+;;  Machine description for Sunplus S+CORE
+;;  Sunplus S+CORE Pipeline Description
+;;  Copyright (C) 2005-2014 Free Software Foundation, Inc.
+;;  Contributed by Sunnorth.
+
+;; This file is part of GCC.
+
+;; GCC is free software; you can redistribute it and/or modify
+;; it under the terms of the GNU General Public License as published by
+;; the Free Software Foundation; either version 3, or (at your option)
+;; any later version.
+
+;; GCC is distributed in the hope that it will be useful,
+;; but WITHOUT ANY WARRANTY; without even the implied warranty of
+;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+;; GNU General Public License for more details.
+
+;; You should have received a copy of the GNU General Public License
+;; along with GCC; see the file COPYING3.  If not see
+;; <http://www.gnu.org/licenses/>.
+
+(define_automaton "score")
+
+(define_cpu_unit "core" "score")
+
+(define_insn_reservation "memory" 3
+                         (eq_attr "type" "load")
+                         "core")
+
+(define_insn_reservation "mul" 3
+                         (eq_attr "type" "mul,div")
+                         "core")
+
+(define_insn_reservation "fce" 1
+                         (eq_attr "type" "fce")
+                         "core")
+
+(define_insn_reservation "tsr" 1
+                         (eq_attr "type" "tsr,fsr")
+                         "core")
+
+(define_insn_reservation "up_c" 1
+                         (eq_attr "up_c" "yes")
+                         "core")
diff --git a/gcc/config/score/score-modes.def b/gcc/config/score/score-modes.def
new file mode 100644
index 000000000..dc1b38661
--- /dev/null
+++ b/gcc/config/score/score-modes.def
@@ -0,0 +1,24 @@
+/* score-modes.def for Sunplus S+CORE processor
+   Copyright (C) 2005-2014 Free Software Foundation, Inc.
+
+   This file is part of GCC.
+
+   GCC is free software; you can redistribute it and/or modify it
+   under the terms of the GNU General Public License as published
+   by the Free Software Foundation; either version 3, or (at your
+   option) any later version.
+
+   GCC is distributed in the hope that it will be useful, but WITHOUT
+   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
+   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
+   License for more details.
+
+   You should have received a copy of the GNU General Public License
+   along with GCC; see the file COPYING3.  If not see
+   <http://www.gnu.org/licenses/>.  */
+
+/* CC_NZmode should be used if the N (sign) and Z (zero) flag is set correctly.
+   CC_Nmode should be used if only the N flag is set correctly.  */
+
+CC_MODE (CC_N);
+CC_MODE (CC_NZ);
diff --git a/gcc/config/score/score-protos.h b/gcc/config/score/score-protos.h
new file mode 100644
index 000000000..2141fb71a
--- /dev/null
+++ b/gcc/config/score/score-protos.h
@@ -0,0 +1,79 @@
+/* score-protos.h for Sunplus S+CORE processor
+   Copyright (C) 2005-2014 Free Software Foundation, Inc.
+
+   This file is part of GCC.
+
+   GCC is free software; you can redistribute it and/or modify it
+   under the terms of the GNU General Public License as published
+   by the Free Software Foundation; either version 3, or (at your
+   option) any later version.
+
+   GCC is distributed in the hope that it will be useful, but WITHOUT
+   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
+   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
+   License for more details.
+
+   You should have received a copy of the GNU General Public License
+   along with GCC; see the file COPYING3.  If not see
+   <http://www.gnu.org/licenses/>.  */
+
+#ifndef GCC_SCORE_PROTOS_H
+#define GCC_SCORE_PROTOS_H
+
+/* Machine Print.  */
+enum score_mem_unit {SCORE_BYTE = 0, SCORE_HWORD = 1, SCORE_WORD = 2};
+
+#define SCORE_ALIGN_UNIT(V, UNIT)   !(V & ((1 << UNIT) - 1))
+
+extern void score_prologue (void);
+extern void score_epilogue (int sibcall_p);
+extern void score_call (rtx *ops, bool sib);
+extern void score_call_value (rtx *ops, bool sib);
+extern void score_movdi (rtx *ops);
+extern void score_zero_extract_andi (rtx *ops);
+extern const char * score_linsn (rtx *ops, enum score_mem_unit unit, bool sign);
+extern const char * score_sinsn (rtx *ops, enum score_mem_unit unit);
+extern const char * score_limm (rtx *ops);
+extern const char * score_move (rtx *ops);
+extern bool score_unaligned_load (rtx* ops);
+extern bool score_unaligned_store (rtx* ops);
+extern bool score_block_move (rtx* ops);
+extern int score_address_cost (rtx addr, enum machine_mode mode,
+			       addr_space_t as, bool speed);
+extern int score_address_p (enum machine_mode mode, rtx x, int strict);
+extern int score_reg_class (int regno);
+extern bool score_hard_regno_mode_ok (unsigned int, enum machine_mode);
+extern rtx score_return_addr (int count, rtx frame);
+extern int score_regno_mode_ok_for_base_p (int regno, int strict);
+extern void score_init_cumulative_args (CUMULATIVE_ARGS *cum,
+                                        tree fntype, rtx libname);
+extern void score_declare_object (FILE *stream, const char *name,
+                                  const char *directive, const char *fmt, ...);
+extern int score_output_external (FILE *file, tree decl, const char *name);
+extern enum reg_class score_secondary_reload_class (enum reg_class rclass,
+                                                    enum machine_mode mode,
+                                                    rtx x);
+extern rtx score_function_value (const_tree valtype, const_tree func,
+                                 enum machine_mode mode);
+extern enum reg_class score_preferred_reload_class (rtx x,
+                                                    enum reg_class rclass);
+extern HOST_WIDE_INT score_initial_elimination_offset (int from, int to);
+extern void score_print_operand (FILE *file, rtx op, int letter);
+extern void score_print_operand_address (FILE *file, rtx addr);
+extern int score_symbolic_constant_p (rtx x,
+                                      enum score_symbol_type *symbol_type);
+extern void score_movsicc (rtx *ops);
+extern const char * score_select_add_imm (rtx *ops, bool set_cc);
+extern const char * score_select (rtx *ops, const char *inst_pre, bool commu,
+                                  const char *letter, bool set_cc);
+extern const char * score_output_casesi (rtx *operands);
+extern const char * score_rpush (rtx *ops);
+extern const char * score_rpop (rtx *ops);
+extern bool score_rtx_costs (rtx x, int code, int outer_code, int opno,
+			     int *total, bool speed);
+
+#ifdef RTX_CODE
+extern enum machine_mode score_select_cc_mode (enum rtx_code op, rtx x, rtx y);
+#endif
+
+#endif /* GCC_SCORE_PROTOS_H  */
diff --git a/gcc/config/score/score.cc b/gcc/config/score/score.cc
new file mode 100644
index 000000000..bcbb68f2f
--- /dev/null
+++ b/gcc/config/score/score.cc
@@ -0,0 +1,2055 @@
+/* Output routines for Sunplus S+CORE processor
+   Copyright (C) 2005-2014 Free Software Foundation, Inc.
+   Contributed by Sunnorth.
+
+   This file is part of GCC.
+
+   GCC is free software; you can redistribute it and/or modify it
+   under the terms of the GNU General Public License as published
+   by the Free Software Foundation; either version 3, or (at your
+   option) any later version.
+
+   GCC is distributed in the hope that it will be useful, but WITHOUT
+   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
+   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
+   License for more details.
+
+   You should have received a copy of the GNU General Public License
+   along with GCC; see the file COPYING3.  If not see
+   <http://www.gnu.org/licenses/>.  */
+
+#define IN_TARGET_CODE 1
+
+#include "config.h"
+#include "system.h"
+#include "coretypes.h"
+#include "tm.h"
+#include "rtl.h"
+#include "regs.h"
+#include "hard-reg-set.h"
+#include "insn-config.h"
+#include "conditions.h"
+#include "insn-attr.h"
+#include "recog.h"
+#include "diagnostic-core.h"
+#include "output.h"
+#include "tree.h"
+#include "stringpool.h"
+#include "calls.h"
+#include "varasm.h"
+#include "stor-layout.h"
+#include "function.h"
+#include "expr.h"
+#include "memmodel.h"
+#include "optabs.h"
+#include "flags.h"
+#include "reload.h"
+#include "tm_p.h"
+#include "ggc.h"
+/*#include "gstab.h"*/
+#include "hashtab.h"
+#include "emit-rtl.h"
+#include "debug.h"
+#include "target.h"
+#include "target-def.h"
+#include "langhooks.h"
+#include "bitmap.h"
+#include "basic-block.h"
+#include "rtl.h"
+#include "df.h"
+#include "opts.h"
+#include "builtins.h"
+#include "attribs.h"
+#include "output.h"
+#include "rtx-vector-builder.h"
+
+/* This file should be included last.  */
+#include "target-def.h"
+
+#define SCORE_SDATA_MAX                score_sdata_max
+#define SCORE_STACK_ALIGN(LOC)         (((LOC) + 3) & ~3)
+#define SCORE_PROLOGUE_TEMP_REGNUM     (GP_REG_FIRST + 8)
+#define SCORE_EPILOGUE_TEMP_REGNUM     (GP_REG_FIRST + 8)
+#define SCORE_DEFAULT_SDATA_MAX        8
+
+#define BITSET_P(VALUE, BIT)           (((VALUE) & (1L << (BIT))) != 0)
+#define INS_BUF_SZ                     128
+
+enum score_address_type
+{
+  SCORE_ADD_REG,
+  SCORE_ADD_CONST_INT,
+  SCORE_ADD_SYMBOLIC
+};
+
+struct score_frame_info
+{
+  HOST_WIDE_INT total_size;       /* bytes that the entire frame takes up  */
+  HOST_WIDE_INT var_size;         /* bytes that variables take up  */
+  HOST_WIDE_INT args_size;        /* bytes that outgoing arguments take up  */
+  HOST_WIDE_INT gp_reg_size;      /* bytes needed to store gp regs  */
+  HOST_WIDE_INT gp_sp_offset;     /* offset from new sp to store gp registers  */
+  HOST_WIDE_INT cprestore_size;   /* # bytes that the .cprestore slot takes up  */
+  unsigned int  mask;             /* mask of saved gp registers  */
+  int num_gp;                     /* number of gp registers saved  */
+};
+
+struct score_arg_info
+{
+  unsigned int num_bytes;     /* The argument's size in bytes  */
+  unsigned int reg_words;     /* The number of words passed in registers  */
+  unsigned int reg_offset;    /* The offset of the first register from  */
+                              /* GP_ARG_FIRST or FP_ARG_FIRST etc  */
+  unsigned int stack_words;   /* The number of words that must be passed  */
+                              /* on the stack  */
+  unsigned int stack_offset;  /* The offset from the start of the stack  */
+                              /* overflow area  */
+};
+
+#ifdef RTX_CODE
+struct score_address_info
+{
+  enum score_address_type type;
+  rtx reg;
+  rtx offset;
+  enum rtx_code code;
+  enum score_symbol_type symbol_type;
+};
+#endif
+
+static int score_sdata_max;
+static char score_ins[INS_BUF_SZ + 8];
+
+/* Keep a list of external functions.  */
+struct  GTY ((chain_next ("%h.next"))) extern_list
+{
+  struct extern_list *next;
+  tree decl;
+  const char *name;
+  int size;
+};
+static GTY(()) struct extern_list *extern_head;
+
+#undef  TARGET_ASM_FILE_START
+#define TARGET_ASM_FILE_START           score_asm_file_start
+
+#undef  TARGET_ASM_FILE_END
+#define TARGET_ASM_FILE_END             score_asm_file_end
+
+#undef  TARGET_ASM_FUNCTION_PROLOGUE
+#define TARGET_ASM_FUNCTION_PROLOGUE    score_function_prologue
+
+#undef  TARGET_ASM_FUNCTION_EPILOGUE
+#define TARGET_ASM_FUNCTION_EPILOGUE    score_function_epilogue
+
+#undef TARGET_OPTION_OVERRIDE
+#define TARGET_OPTION_OVERRIDE          score_option_override
+
+#undef  TARGET_SCHED_ISSUE_RATE
+#define TARGET_SCHED_ISSUE_RATE         score_issue_rate
+
+#undef TARGET_ASM_SELECT_RTX_SECTION
+#define TARGET_ASM_SELECT_RTX_SECTION   score_select_rtx_section
+
+#undef  TARGET_IN_SMALL_DATA_P
+#define TARGET_IN_SMALL_DATA_P          score_in_small_data_p
+
+#undef  TARGET_FUNCTION_OK_FOR_SIBCALL
+#define TARGET_FUNCTION_OK_FOR_SIBCALL  score_function_ok_for_sibcall
+
+#undef TARGET_STRICT_ARGUMENT_NAMING
+#define TARGET_STRICT_ARGUMENT_NAMING   hook_bool_CUMULATIVE_ARGS_true
+
+#undef TARGET_ASM_OUTPUT_MI_THUNK
+#define TARGET_ASM_OUTPUT_MI_THUNK      score_output_mi_thunk
+
+#undef TARGET_PROMOTE_FUNCTION_MODE
+#define TARGET_PROMOTE_FUNCTION_MODE    default_promote_function_mode_always_promote
+
+#undef TARGET_PROMOTE_PROTOTYPES
+#define TARGET_PROMOTE_PROTOTYPES       hook_bool_const_tree_true
+
+#undef TARGET_MUST_PASS_IN_STACK
+#define TARGET_MUST_PASS_IN_STACK       must_pass_in_stack_var_size
+
+#undef TARGET_ARG_PARTIAL_BYTES
+#define TARGET_ARG_PARTIAL_BYTES        score_arg_partial_bytes
+
+#undef TARGET_FUNCTION_ARG
+#define TARGET_FUNCTION_ARG             score_function_arg
+
+#undef TARGET_FUNCTION_ARG_ADVANCE
+#define TARGET_FUNCTION_ARG_ADVANCE     score_function_arg_advance
+
+#undef TARGET_PASS_BY_REFERENCE
+#define TARGET_PASS_BY_REFERENCE        score_pass_by_reference
+
+#undef TARGET_RETURN_IN_MEMORY
+#define TARGET_RETURN_IN_MEMORY         score_return_in_memory
+
+#undef TARGET_RTX_COSTS
+#define TARGET_RTX_COSTS                score_rtx_costs
+
+#undef TARGET_ADDRESS_COST
+#define TARGET_ADDRESS_COST             score_address_cost
+
+#undef TARGET_LEGITIMATE_ADDRESS_P
+#define TARGET_LEGITIMATE_ADDRESS_P	score_legitimate_address_p
+
+#undef TARGET_CAN_ELIMINATE
+#define TARGET_CAN_ELIMINATE            score_can_eliminate
+
+#undef TARGET_CONDITIONAL_REGISTER_USAGE
+#define TARGET_CONDITIONAL_REGISTER_USAGE score_conditional_register_usage
+
+#undef TARGET_ASM_TRAMPOLINE_TEMPLATE
+#define TARGET_ASM_TRAMPOLINE_TEMPLATE	score_asm_trampoline_template
+#undef TARGET_TRAMPOLINE_INIT
+#define TARGET_TRAMPOLINE_INIT		score_trampoline_init
+
+#undef TARGET_REGISTER_MOVE_COST
+#define TARGET_REGISTER_MOVE_COST	score_register_move_cost
+
+#undef TARGET_STRUCT_VALUE_RTX
+#define TARGET_STRUCT_VALUE_RTX     score_struct_value_rtx
+
+#undef  TARGET_HARD_REGNO_NREGS
+#define TARGET_HARD_REGNO_NREGS		score_hard_regno_nregs
+
+#undef TARGET_C_MODE_FOR_FLOATING_TYPE
+#define TARGET_C_MODE_FOR_FLOATING_TYPE score_c_mode_for_floating_type
+
+#undef  TARGET_MODES_TIEABLE_P
+#define TARGET_MODES_TIEABLE_P			score_modes_tieable_p
+
+#undef TARGET_STARTING_FRAME_OFFSET
+#define TARGET_STARTING_FRAME_OFFSET score_starting_frame_offset
+
+#undef TARGET_HARD_REGNO_MODE_OK
+#define TARGET_HARD_REGNO_MODE_OK score_hard_regno_mode_ok
+
+#undef TARGET_CONSTANT_ALIGNMENT
+#define TARGET_CONSTANT_ALIGNMENT score_constant_alignment
+
+#undef  TARGET_CAN_CHANGE_MODE_CLASS
+#define TARGET_CAN_CHANGE_MODE_CLASS score_can_change_mode_class
+
+#undef TARGET_TRULY_NOOP_TRUNCATION
+#define TARGET_TRULY_NOOP_TRUNCATION score_truly_noop_truncation
+
+/* Return true if SYMBOL is a SYMBOL_REF and OFFSET + SYMBOL points
+   to the same object as SYMBOL.  */
+static int
+score_offset_within_object_p (rtx symbol, HOST_WIDE_INT offset)
+{
+  if (GET_CODE (symbol) != SYMBOL_REF)
+    return 0;
+
+  if (CONSTANT_POOL_ADDRESS_P (symbol)
+      && offset >= 0
+      && offset < (int)GET_MODE_SIZE (get_pool_mode (symbol)))
+    return 1;
+
+  if (SYMBOL_REF_DECL (symbol) != 0
+      && offset >= 0
+      && offset < int_size_in_bytes (TREE_TYPE (SYMBOL_REF_DECL (symbol))))
+    return 1;
+
+  return 0;
+}
+
+/* Split X into a base and a constant offset, storing them in *BASE
+   and *OFFSET respectively.  */
+static void
+score_split_const (rtx x, rtx *base, HOST_WIDE_INT *offset)
+{
+  *offset = 0;
+
+  if (GET_CODE (x) == CONST)
+    x = XEXP (x, 0);
+
+  if (GET_CODE (x) == PLUS && GET_CODE (XEXP (x, 1)) == CONST_INT)
+    {
+      *offset += INTVAL (XEXP (x, 1));
+      x = XEXP (x, 0);
+    }
+
+  *base = x;
+}
+
+/* Classify symbol X, which must be a SYMBOL_REF or a LABEL_REF.  */
+static enum score_symbol_type
+score_classify_symbol (rtx x)
+{
+  if (GET_CODE (x) == LABEL_REF)
+    return SYMBOL_GENERAL;
+
+  gcc_assert (GET_CODE (x) == SYMBOL_REF);
+
+  if (CONSTANT_POOL_ADDRESS_P (x))
+    {
+      if (GET_MODE_SIZE (get_pool_mode (x)) <= SCORE_SDATA_MAX)
+        return SYMBOL_SMALL_DATA;
+      return SYMBOL_GENERAL;
+    }
+  if (SYMBOL_REF_SMALL_P (x))
+    return SYMBOL_SMALL_DATA;
+  return SYMBOL_GENERAL;
+}
+
+/* Return true if the current function must save REGNO.  */
+static int
+score_save_reg_p (unsigned int regno)
+{
+  /* Check call-saved registers.  */
+  if (df_regs_ever_live_p (regno) && !call_used_regs[regno])
+    return 1;
+
+  /* We need to save the old frame pointer before setting up a new one.  */
+  if (regno == HARD_FRAME_POINTER_REGNUM && frame_pointer_needed)
+    return 1;
+
+  /* We need to save the incoming return address if it is ever clobbered
+     within the function.  */
+  if (regno == RA_REGNUM && df_regs_ever_live_p (regno))
+    return 1;
+
+  return 0;
+}
+
+/* Return one word of double-word value OP, taking into account the fixed
+   endianness of certain registers.  HIGH_P is true to select the high part,
+   false to select the low part.  */
+static rtx
+score_subw (rtx op, int high_p)
+{
+  unsigned int byte;
+  enum machine_mode mode = GET_MODE (op);
+
+  if (mode == VOIDmode)
+    mode = DImode;
+
+  byte = (TARGET_LITTLE_ENDIAN ? high_p : !high_p) ? UNITS_PER_WORD : 0;
+
+  if (GET_CODE (op) == REG && REGNO (op) == HI_REGNUM)
+    return gen_rtx_REG (SImode, high_p ? HI_REGNUM : LO_REGNUM);
+
+  if (GET_CODE (op) == MEM)
+    return adjust_address (op, SImode, byte);
+
+  return simplify_gen_subreg (SImode, op, mode, byte);
+}
+
+static struct score_frame_info *
+score_cached_frame (void)
+{
+  static struct score_frame_info _frame_info;
+  return &_frame_info;
+}
+
+/* Return the bytes needed to compute the frame pointer from the current
+   stack pointer.  SIZE is the size (in bytes) of the local variables.  */
+static struct score_frame_info *
+score_compute_frame_size (HOST_WIDE_INT size)
+{
+  unsigned int regno;
+  struct score_frame_info *f = score_cached_frame ();
+
+  memset (f, 0, sizeof (struct score_frame_info));
+  f->gp_reg_size = 0;
+  f->mask = 0;
+  f->var_size = SCORE_STACK_ALIGN (size);
+  f->args_size = crtl->outgoing_args_size;
+  f->cprestore_size = flag_pic ? UNITS_PER_WORD : 0;
+  if (f->var_size == 0 && crtl->is_leaf)
+    f->args_size = f->cprestore_size = 0;
+
+  if (f->args_size == 0 && cfun->calls_alloca)
+    f->args_size = UNITS_PER_WORD;
+
+  f->total_size = f->var_size + f->args_size + f->cprestore_size;
+  for (regno = GP_REG_FIRST; regno <= GP_REG_LAST; regno++)
+    {
+      if (score_save_reg_p (regno))
+        {
+          f->gp_reg_size += GET_MODE_SIZE (SImode);
+          f->mask |= 1 << (regno - GP_REG_FIRST);
+        }
+    }
+
+  if (crtl->calls_eh_return)
+    {
+      unsigned int i;
+      for (i = 0;; ++i)
+        {
+          regno = EH_RETURN_DATA_REGNO (i);
+          if (regno == INVALID_REGNUM)
+            break;
+          f->gp_reg_size += GET_MODE_SIZE (SImode);
+          f->mask |= 1 << (regno - GP_REG_FIRST);
+        }
+    }
+
+  f->total_size += f->gp_reg_size;
+  f->num_gp = f->gp_reg_size / UNITS_PER_WORD;
+
+  if (f->mask)
+    {
+      HOST_WIDE_INT offset;
+      offset = (f->args_size + f->cprestore_size + f->var_size
+                + f->gp_reg_size - GET_MODE_SIZE (SImode));
+      f->gp_sp_offset = offset;
+    }
+  else
+    f->gp_sp_offset = 0;
+
+  return f;
+}
+
+/* Return true if X is a valid base register for the given mode.
+   Allow only hard registers if STRICT.  */
+static int
+score_valid_base_register_p (rtx x, int strict)
+{
+  if (!strict && GET_CODE (x) == SUBREG)
+    x = SUBREG_REG (x);
+
+  return (GET_CODE (x) == REG
+          && score_regno_mode_ok_for_base_p (REGNO (x), strict));
+}
+
+/* Return true if X is a valid address for machine mode MODE.  If it is,
+   fill in INFO appropriately.  STRICT is true if we should only accept
+   hard base registers.  */
+static int
+score_classify_address (struct score_address_info *info,
+                        enum machine_mode mode, rtx x, int strict)
+{
+  info->code = GET_CODE (x);
+
+  switch (info->code)
+    {
+    case REG:
+    case SUBREG:
+      info->type = SCORE_ADD_REG;
+      info->reg = x;
+      info->offset = const0_rtx;
+      return score_valid_base_register_p (info->reg, strict);
+    case PLUS:
+      info->type = SCORE_ADD_REG;
+      info->reg = XEXP (x, 0);
+      info->offset = XEXP (x, 1);
+      return (score_valid_base_register_p (info->reg, strict)
+              && GET_CODE (info->offset) == CONST_INT
+              && IMM_IN_RANGE (INTVAL (info->offset), 15, 1));
+    case PRE_DEC:
+    case POST_DEC:
+    case PRE_INC:
+    case POST_INC:
+      if (GET_MODE_SIZE (mode) > GET_MODE_SIZE (SImode))
+        return false;
+      info->type = SCORE_ADD_REG;
+      info->reg = XEXP (x, 0);
+      info->offset = GEN_INT (GET_MODE_SIZE (mode));
+      return score_valid_base_register_p (info->reg, strict);
+    case CONST_INT:
+      info->type = SCORE_ADD_CONST_INT;
+      return IMM_IN_RANGE (INTVAL (x), 15, 1);
+    case CONST:
+    case LABEL_REF:
+    case SYMBOL_REF:
+      info->type = SCORE_ADD_SYMBOLIC;
+      return (score_symbolic_constant_p (x, &info->symbol_type)
+              && (info->symbol_type == SYMBOL_GENERAL
+                  || info->symbol_type == SYMBOL_SMALL_DATA));
+    default:
+      return 0;
+    }
+}
+
+/* Implement TARGET_RETURN_IN_MEMORY.  In S+core,
+   small structures are returned in a register.
+   Objects with varying size must still be returned in memory.  */
+static bool
+score_return_in_memory (const_tree type, const_tree fndecl ATTRIBUTE_UNUSED)
+{
+    return ((TYPE_MODE (type) == BLKmode)
+            || (int_size_in_bytes (type) > 2 * UNITS_PER_WORD)
+            || (int_size_in_bytes (type) == -1));
+}
+
+/* Return a legitimate address for REG + OFFSET.  */
+static rtx
+score_add_offset (rtx reg, HOST_WIDE_INT offset)
+{
+  if (!IMM_IN_RANGE (offset, 15, 1))
+    {
+      reg = expand_simple_binop (GET_MODE (reg), PLUS,
+                                 gen_int_mode (offset & 0xffffc000,
+                                               GET_MODE (reg)),
+                                 reg, NULL, 0, OPTAB_WIDEN);
+      offset &= 0x3fff;
+    }
+
+  return plus_constant (GET_MODE (reg), reg, offset);
+}
+
+/* Implement TARGET_ASM_OUTPUT_MI_THUNK.  Generate rtl rather than asm text
+   in order to avoid duplicating too much logic from elsewhere.  */
+static void
+score_output_mi_thunk (FILE *file, tree thunk_fndecl ATTRIBUTE_UNUSED,
+                       HOST_WIDE_INT delta, HOST_WIDE_INT vcall_offset,
+                       tree function)
+{
+  rtx this_rtx;
+  rtx temp1;
+  rtx fnaddr;
+  rtx_insn *insn;
+
+  /* Pretend to be a post-reload pass while generating rtl.  */
+  reload_completed = 1;
+
+  /* Mark the end of the (empty) prologue.  */
+  emit_note (NOTE_INSN_PROLOGUE_END);
+
+  /* We need two temporary registers in some cases.  */
+  temp1 = gen_rtx_REG (Pmode, 8);
+
+  /* Find out which register contains the "this" pointer.  */
+  if (aggregate_value_p (TREE_TYPE (TREE_TYPE (function)), function))
+    this_rtx = gen_rtx_REG (Pmode, ARG_REG_FIRST + 1);
+  else
+    this_rtx = gen_rtx_REG (Pmode, ARG_REG_FIRST);
+
+  /* Add DELTA to THIS_RTX.  */
+  if (delta != 0)
+    {
+      rtx offset = GEN_INT (delta);
+      if (!(delta >= -32768 && delta <= 32767))
+        {
+          emit_move_insn (temp1, offset);
+          offset = temp1;
+        }
+      emit_insn (gen_add3_insn (this_rtx, this_rtx, offset));
+    }
+
+  /* If needed, add *(*THIS_RTX + VCALL_OFFSET) to THIS_RTX.  */
+  if (vcall_offset != 0)
+    {
+      rtx addr;
+
+      /* Set TEMP1 to *THIS_RTX.  */
+      emit_move_insn (temp1, gen_rtx_MEM (Pmode, this_rtx));
+
+      /* Set ADDR to a legitimate address for *THIS_RTX + VCALL_OFFSET.  */
+      addr = score_add_offset (temp1, vcall_offset);
+
+      /* Load the offset and add it to THIS_RTX.  */
+      emit_move_insn (temp1, gen_rtx_MEM (Pmode, addr));
+      emit_insn (gen_add3_insn (this_rtx, this_rtx, temp1));
+    }
+
+  /* Jump to the target function.  */
+  fnaddr = XEXP (DECL_RTL (function), 0);
+  insn = emit_call_insn (gen_sibcall_internal_score7 (fnaddr, const0_rtx));
+  SIBLING_CALL_P (insn) = 1;
+
+  /* Run just enough of rest_of_compilation.  This sequence was
+     "borrowed" from alpha.c.  */
+  insn = get_insns ();
+  split_all_insns_noflow ();
+  shorten_branches (insn);
+  final_start_function (insn, file, 1);
+  final (insn, file, 1);
+  final_end_function ();
+
+  /* Clean up the vars set above.  Note that final_end_function resets
+     the global pointer for us.  */
+  reload_completed = 0;
+}
+
+/* Fill INFO with information about a single argument.  CUM is the
+   cumulative state for earlier arguments.  MODE is the mode of this
+   argument and TYPE is its type (if known).  NAMED is true if this
+   is a named (fixed) argument rather than a variable one.  */
+static void
+score_classify_arg (const CUMULATIVE_ARGS *cum, const function_arg_info &arg, struct score_arg_info *info)
+{
+  int even_reg_p;
+  unsigned int num_words, max_regs;
+
+  even_reg_p = 0;
+  if (GET_MODE_CLASS (arg.mode) == MODE_INT
+      || GET_MODE_CLASS (arg.mode) == MODE_FLOAT)
+    even_reg_p = (GET_MODE_SIZE (arg.mode) > UNITS_PER_WORD);
+  else
+    if (arg.type != NULL_TREE && TYPE_ALIGN (arg.type) > BITS_PER_WORD && arg.named)
+      even_reg_p = 1;
+
+  if (TARGET_MUST_PASS_IN_STACK (arg))
+    info->reg_offset = ARG_REG_NUM;
+  else
+    {
+      info->reg_offset = cum->num_gprs;
+      if (even_reg_p)
+        info->reg_offset += info->reg_offset & 1;
+    }
+
+  if (arg.mode == BLKmode)
+    info->num_bytes = int_size_in_bytes (arg.type);
+  else
+    info->num_bytes = GET_MODE_SIZE (arg.mode);
+
+  num_words = (info->num_bytes + UNITS_PER_WORD - 1) / UNITS_PER_WORD;
+  max_regs = ARG_REG_NUM - info->reg_offset;
+
+  /* Partition the argument between registers and stack.  */
+  info->reg_words = MIN (num_words, max_regs);
+  info->stack_words = num_words - info->reg_words;
+
+  /* The alignment applied to registers is also applied to stack arguments.  */
+  if (info->stack_words)
+    {
+      info->stack_offset = cum->stack_words;
+      if (even_reg_p)
+        info->stack_offset += info->stack_offset & 1;
+    }
+}
+
+/* Set up the stack and frame (if desired) for the function.  */
+static void
+score_function_prologue (FILE *file)
+{
+  const char *fnname;
+  struct score_frame_info *f = score_cached_frame ();
+  HOST_WIDE_INT tsize = f->total_size;
+
+  fnname = XSTR (XEXP (DECL_RTL (current_function_decl), 0), 0);
+  if (!flag_inhibit_size_directive)
+    {
+      fputs ("\t.ent\t", file);
+      assemble_name (file, fnname);
+      fputs ("\n", file);
+    }
+  assemble_name (file, fnname);
+  fputs (":\n", file);
+
+  if (!flag_inhibit_size_directive)
+    {
+      fprintf (file,
+               "\t.frame\t%s," HOST_WIDE_INT_PRINT_DEC ",%s, %d\t\t"
+               "# vars= " HOST_WIDE_INT_PRINT_DEC ", regs= %d"
+               ", args= " HOST_WIDE_INT_PRINT_DEC
+               ", gp= " HOST_WIDE_INT_PRINT_DEC "\n",
+               (reg_names[(frame_pointer_needed)
+                ? HARD_FRAME_POINTER_REGNUM : STACK_POINTER_REGNUM]),
+               tsize,
+               reg_names[RA_REGNUM],
+               crtl->is_leaf ? 1 : 0,
+               f->var_size,
+               f->num_gp,
+               f->args_size,
+               f->cprestore_size);
+
+      fprintf(file, "\t.mask\t0x%08x," HOST_WIDE_INT_PRINT_DEC "\n",
+              f->mask,
+              (f->gp_sp_offset - f->total_size));
+    }
+}
+
+/* Do any necessary cleanup after a function to restore stack, frame,
+   and regs.  */
+static void
+score_function_epilogue (FILE *file)
+{
+  if (!flag_inhibit_size_directive)
+    {
+      const char *fnname;
+      fnname = XSTR (XEXP (DECL_RTL (current_function_decl), 0), 0);
+      fputs ("\t.end\t", file);
+      assemble_name (file, fnname);
+      fputs ("\n", file);
+    }
+}
+
+/* Returns true if X contains a SYMBOL_REF.  */
+static bool
+score_symbolic_expression_p (rtx x)
+{
+  if (GET_CODE (x) == SYMBOL_REF)
+    return true;
+
+  if (GET_CODE (x) == CONST)
+    return score_symbolic_expression_p (XEXP (x, 0));
+
+  if (UNARY_P (x))
+    return score_symbolic_expression_p (XEXP (x, 0));
+
+  if (ARITHMETIC_P (x))
+    return (score_symbolic_expression_p (XEXP (x, 0))
+            || score_symbolic_expression_p (XEXP (x, 1)));
+
+  return false;
+}
+
+/* Choose the section to use for the constant rtx expression X that has
+   mode MODE.  */
+static section *
+score_select_rtx_section (enum machine_mode mode, rtx x, unsigned HOST_WIDE_INT align)
+{
+  if (GET_MODE_SIZE (mode) <= SCORE_SDATA_MAX)
+    return get_named_section (0, ".sdata", 0);
+  else if (flag_pic && score_symbolic_expression_p (x))
+    return get_named_section (0, ".data.rel.ro", 3);
+  else
+    return mergeable_constant_section (mode, align, 0);
+}
+
+/* Implement TARGET_IN_SMALL_DATA_P.  */
+static bool
+score_in_small_data_p (const_tree decl)
+{
+  HOST_WIDE_INT size;
+
+  if (TREE_CODE (decl) == STRING_CST
+      || TREE_CODE (decl) == FUNCTION_DECL)
+    return false;
+
+  if (TREE_CODE (decl) == VAR_DECL && DECL_SECTION_NAME (decl) != 0)
+    {
+      const char *section = DECL_SECTION_NAME (decl);
+      if (strcmp (section, ".sdata") != 0
+          && strcmp (section, ".sbss") != 0)
+        return true;
+      if (!DECL_EXTERNAL (decl))
+        return false;
+    }
+  size = int_size_in_bytes (TREE_TYPE (decl));
+  return (size > 0 && size <= SCORE_SDATA_MAX);
+}
+
+/* Implement TARGET_ASM_FILE_START.  */
+static void
+score_asm_file_start (void)
+{
+  default_file_start ();
+  fprintf (asm_out_file, ASM_COMMENT_START
+           "GCC for S+core %s \n", SCORE_GCC_VERSION);
+
+  if (flag_pic)
+    fprintf (asm_out_file, "\t.set pic\n");
+}
+
+/* Implement TARGET_ASM_FILE_END.  When using assembler macros, emit
+   .externs for any small-data variables that turned out to be external.  */
+static void
+score_asm_file_end (void)
+{
+  tree name_tree;
+  struct extern_list *p;
+  if (extern_head)
+    {
+      fputs ("\n", asm_out_file);
+      for (p = extern_head; p != 0; p = p->next)
+        {
+          name_tree = get_identifier (p->name);
+          if (!TREE_ASM_WRITTEN (name_tree)
+              && TREE_SYMBOL_REFERENCED (name_tree))
+            {
+              TREE_ASM_WRITTEN (name_tree) = 1;
+              fputs ("\t.extern\t", asm_out_file);
+              assemble_name (asm_out_file, p->name);
+              fprintf (asm_out_file, ", %d\n", p->size);
+            }
+        }
+    }
+}
+
+/* Implement TARGET_OPTION_OVERRIDE hook.  */
+static void
+score_option_override (void)
+{
+  flag_pic = false;
+  score_sdata_max = SCORE_DEFAULT_SDATA_MAX;
+
+}
+
+/* Implement REGNO_REG_CLASS macro.  */
+int
+score_reg_class (int regno)
+{
+  int c;
+  gcc_assert (regno >= 0 && regno < FIRST_PSEUDO_REGISTER);
+
+  if (regno == FRAME_POINTER_REGNUM
+      || regno == ARG_POINTER_REGNUM)
+    return ALL_REGS;
+
+  for (c = 0; c < N_REG_CLASSES; c++)
+    if (TEST_HARD_REG_BIT (reg_class_contents[c], regno))
+      return c;
+
+  return NO_REGS;
+}
+
+/* Implement PREFERRED_RELOAD_CLASS macro.  */
+enum reg_class
+score_preferred_reload_class (rtx x ATTRIBUTE_UNUSED, enum reg_class rclass)
+{
+  if (reg_class_subset_p (G16_REGS, rclass))
+    return G16_REGS;
+  if (reg_class_subset_p (G32_REGS, rclass))
+    return G32_REGS;
+  return rclass;
+}
+
+/* Implement SECONDARY_INPUT_RELOAD_CLASS
+   and SECONDARY_OUTPUT_RELOAD_CLASS macro.  */
+enum reg_class
+score_secondary_reload_class (enum reg_class rclass,
+                              enum machine_mode mode ATTRIBUTE_UNUSED,
+                              rtx x)
+{
+  int regno = -1;
+  if (GET_CODE (x) == REG || GET_CODE(x) == SUBREG)
+    regno = true_regnum (x);
+
+  if (!GR_REG_CLASS_P (rclass))
+    return GP_REG_P (regno) ? NO_REGS : G32_REGS;
+  return NO_REGS;
+}
+
+/* Return true if REGNO is suitable for holding a quantity of type MODE.
+   Return truth value on whether or not a given hard register
+   can support a given mode.  */
+bool
+score_hard_regno_mode_ok (unsigned int regno, enum machine_mode mode)
+{
+  int size = GET_MODE_SIZE (mode);
+  enum mode_class mclass = GET_MODE_CLASS (mode);
+
+  if (mclass == MODE_CC)
+    return regno == CC_REGNUM;
+  else if (regno == FRAME_POINTER_REGNUM
+           || regno == ARG_POINTER_REGNUM)
+    return mclass == MODE_INT;
+  else if (GP_REG_P (regno))
+    /* ((regno <= (GP_REG_LAST- HARD_REGNO_NREGS (dummy, mode)) + 1)  */
+    return !(regno & 1) || (size <= UNITS_PER_WORD);
+  else if (CE_REG_P (regno))
+    return (mclass == MODE_INT
+            && ((size <= UNITS_PER_WORD)
+                || (regno == CE_REG_FIRST && size == 2 * UNITS_PER_WORD)));
+  else
+    return (mclass == MODE_INT) && (size <= UNITS_PER_WORD);
+}
+
+/* Implement INITIAL_ELIMINATION_OFFSET.  FROM is either the frame
+   pointer or argument pointer.  TO is either the stack pointer or
+   hard frame pointer.  */
+HOST_WIDE_INT
+score_initial_elimination_offset (int from,
+                                  int to ATTRIBUTE_UNUSED)
+{
+  struct score_frame_info *f = score_compute_frame_size (get_frame_size ());
+  switch (from)
+    {
+    case ARG_POINTER_REGNUM:
+      return f->total_size;
+    case FRAME_POINTER_REGNUM:
+      return 0;
+    default:
+      gcc_unreachable ();
+    }
+}
+
+/* Implement TARGET_FUNCTION_ARG_ADVANCE hook.  */
+static void
+score_function_arg_advance (cumulative_args_t cum_args, const function_arg_info &arg)
+{
+  struct score_arg_info info;
+  CUMULATIVE_ARGS *cum = get_cumulative_args (cum_args);
+  score_classify_arg (cum, arg, &info);
+  cum->num_gprs = info.reg_offset + info.reg_words;
+  if (info.stack_words > 0)
+    cum->stack_words = info.stack_offset + info.stack_words;
+  cum->arg_number++;
+}
+
+/* Implement TARGET_ARG_PARTIAL_BYTES macro.  */
+int
+score_arg_partial_bytes (cumulative_args_t cum_args, const function_arg_info &arg)
+{
+  struct score_arg_info info;
+  CUMULATIVE_ARGS *cum = get_cumulative_args (cum_args);
+  score_classify_arg (cum, arg, &info);
+  return info.stack_words > 0 ? info.reg_words * UNITS_PER_WORD : 0;
+}
+
+/* Implement TARGET_FUNCTION_ARG hook.  */
+static rtx
+score_function_arg (cumulative_args_t cum_args, const function_arg_info &arg)
+{
+  struct score_arg_info info;
+  CUMULATIVE_ARGS *cum = get_cumulative_args (cum_args);
+
+  if (arg.mode == VOIDmode || !arg.named)
+    return 0;
+
+  score_classify_arg (cum, arg, &info);
+
+  if (info.reg_offset == ARG_REG_NUM)
+    return 0;
+
+  if (!info.stack_words)
+    return gen_rtx_REG (arg.mode, ARG_REG_FIRST + info.reg_offset);
+  else
+    {
+      rtx ret = gen_rtx_PARALLEL (arg.mode, rtvec_alloc (info.reg_words));
+      unsigned int i, part_offset = 0;
+      for (i = 0; i < info.reg_words; i++)
+        {
+          rtx reg;
+          reg = gen_rtx_REG (SImode, ARG_REG_FIRST + info.reg_offset + i);
+          XVECEXP (ret, 0, i) = gen_rtx_EXPR_LIST (SImode, reg,
+                                                   GEN_INT (part_offset));
+          part_offset += UNITS_PER_WORD;
+        }
+      return ret;
+    }
+}
+
+/* Implement FUNCTION_VALUE and LIBCALL_VALUE.  For normal calls,
+   VALTYPE is the return type and MODE is VOIDmode.  For libcalls,
+   VALTYPE is null and MODE is the mode of the return value.  */
+rtx
+score_function_value (const_tree valtype, const_tree func, enum machine_mode mode)
+{
+  if (valtype)
+    {
+      int unsignedp;
+      mode = TYPE_MODE (valtype);
+      unsignedp = TYPE_UNSIGNED (valtype);
+      mode = default_promote_function_mode (valtype, mode, &unsignedp, func, 1);
+    }
+  return gen_rtx_REG (mode, RT_REGNUM);
+}
+
+/* Implement TARGET_ASM_TRAMPOLINE_TEMPLATE.  */
+
+static void
+score_asm_trampoline_template (FILE *f)
+{
+  fprintf (f, "\t.set r1\n");
+  fprintf (f, "\tmv r31, r3\n");
+  fprintf (f, "\tbl nextinsn\n");
+  fprintf (f, "nextinsn:\n");
+  fprintf (f, "\tlw r1, [r3, 6*4-8]\n");
+  fprintf (f, "\tlw r23, [r3, 6*4-4]\n");
+  fprintf (f, "\tmv r3, r31\n");
+  fprintf (f, "\tbr! r1\n");
+  fprintf (f, "\tnop!\n");
+  fprintf (f, "\t.set nor1\n");
+}
+
+/* Implement TARGET_TRAMPOLINE_INIT.  */
+static void
+score_trampoline_init (rtx m_tramp, tree fndecl, rtx chain_value)
+{
+#define CODE_SIZE        (TRAMPOLINE_INSNS * UNITS_PER_WORD)
+
+  rtx fnaddr = XEXP (DECL_RTL (fndecl), 0);
+  rtx mem;
+
+  emit_block_move (m_tramp, assemble_trampoline_template (),
+		   GEN_INT (TRAMPOLINE_SIZE), BLOCK_OP_NORMAL);
+
+  mem = adjust_address (m_tramp, SImode, CODE_SIZE);
+  emit_move_insn (mem, fnaddr);
+  mem = adjust_address (m_tramp, SImode, CODE_SIZE + GET_MODE_SIZE (SImode));
+  emit_move_insn (mem, chain_value);
+
+#undef CODE_SIZE
+}
+
+/* This function is used to implement REG_MODE_OK_FOR_BASE_P macro.  */
+int
+score_regno_mode_ok_for_base_p (int regno, int strict)
+{
+  if (regno >= FIRST_PSEUDO_REGISTER)
+    {
+      if (!strict)
+        return 1;
+      regno = reg_renumber[regno];
+    }
+  if (regno == ARG_POINTER_REGNUM
+      || regno == FRAME_POINTER_REGNUM)
+    return 1;
+  return GP_REG_P (regno);
+}
+
+/* Implement TARGET_LEGITIMATE_ADDRESS_P macro.  */
+static bool
+score_legitimate_address_p (enum machine_mode mode, rtx x, bool strict, code_helper)
+{
+  struct score_address_info addr;
+
+  return score_classify_address (&addr, mode, x, strict);
+}
+
+/* Implement TARGET_REGISTER_MOVE_COST.
+
+   Return a number assessing the cost of moving a register in class
+   FROM to class TO. */
+static int
+score_register_move_cost (enum machine_mode mode ATTRIBUTE_UNUSED,
+                          reg_class_t from, reg_class_t to)
+{
+  if (GR_REG_CLASS_P (from))
+    {
+      if (GR_REG_CLASS_P (to))
+        return 2;
+      else if (SP_REG_CLASS_P (to))
+        return 4;
+      else if (CP_REG_CLASS_P (to))
+        return 5;
+      else if (CE_REG_CLASS_P (to))
+        return 6;
+    }
+  if (GR_REG_CLASS_P (to))
+    {
+      if (GR_REG_CLASS_P (from))
+        return 2;
+      else if (SP_REG_CLASS_P (from))
+        return 4;
+      else if (CP_REG_CLASS_P (from))
+        return 5;
+      else if (CE_REG_CLASS_P (from))
+        return 6;
+    }
+  return 12;
+}
+
+/* Return the number of instructions needed to load a symbol of the
+   given type into a register.  */
+static int
+score_symbol_insns (enum score_symbol_type type)
+{
+  switch (type)
+    {
+    case SYMBOL_GENERAL:
+      return 2;
+
+    case SYMBOL_SMALL_DATA:
+      return 1;
+    }
+
+  gcc_unreachable ();
+}
+
+/* Return the number of instructions needed to load or store a value
+   of mode MODE at X.  Return 0 if X isn't valid for MODE.  */
+static int
+score_address_insns (rtx x, enum machine_mode mode)
+{
+  struct score_address_info addr;
+  int factor;
+
+  if (mode == BLKmode)
+    factor = 1;
+  else
+    factor = (GET_MODE_SIZE (mode) + UNITS_PER_WORD - 1) / UNITS_PER_WORD;
+
+  if (score_classify_address (&addr, mode, x, false))
+    switch (addr.type)
+      {
+      case SCORE_ADD_REG:
+      case SCORE_ADD_CONST_INT:
+        return factor;
+
+      case SCORE_ADD_SYMBOLIC:
+        return factor * score_symbol_insns (addr.symbol_type);
+      }
+  return 0;
+}
+
+/* Implement TARGET_RTX_COSTS macro.  */
+bool
+score_rtx_costs (rtx x, machine_mode mode, int outer_code, int opno ATTRIBUTE_UNUSED,
+		 int *total, bool speed ATTRIBUTE_UNUSED)
+{
+  int code = GET_CODE (x);
+  switch (code)
+    {
+    case CONST_INT:
+      if (outer_code == SET)
+        {
+          if (((INTVAL (x) & 0xffff) == 0)
+              || (INTVAL (x) >= -32768 && INTVAL (x) <= 32767))
+            *total = COSTS_N_INSNS (1);
+          else
+            *total = COSTS_N_INSNS (2);
+        }
+      else if (outer_code == PLUS || outer_code == MINUS)
+        {
+          if (INTVAL (x) >= -8192 && INTVAL (x) <= 8191)
+            *total = 0;
+          else if (((INTVAL (x) & 0xffff) == 0)
+                   || (INTVAL (x) >= -32768 && INTVAL (x) <= 32767))
+            *total = 1;
+          else
+            *total = COSTS_N_INSNS (2);
+        }
+      else if (outer_code == AND || outer_code == IOR)
+        {
+          if (INTVAL (x) >= 0 && INTVAL (x) <= 16383)
+            *total = 0;
+          else if (((INTVAL (x) & 0xffff) == 0)
+                   || (INTVAL (x) >= 0 && INTVAL (x) <= 65535))
+            *total = 1;
+          else
+            *total = COSTS_N_INSNS (2);
+        }
+      else
+        {
+          *total = 0;
+        }
+      return true;
+
+    case CONST:
+    case SYMBOL_REF:
+    case LABEL_REF:
+    case CONST_DOUBLE:
+      *total = COSTS_N_INSNS (2);
+      return true;
+
+    case MEM:
+      {
+        /* If the address is legitimate, return the number of
+           instructions it needs, otherwise use the default handling.  */
+        int n = score_address_insns (XEXP (x, 0), GET_MODE (x));
+        if (n > 0)
+          {
+            *total = COSTS_N_INSNS (n + 1);
+            return true;
+          }
+        return false;
+      }
+
+    case FFS:
+      *total = COSTS_N_INSNS (6);
+      return true;
+
+    case NOT:
+      *total = COSTS_N_INSNS (1);
+      return true;
+
+    case AND:
+    case IOR:
+    case XOR:
+      if (mode == DImode)
+        {
+          *total = COSTS_N_INSNS (2);
+          return true;
+        }
+      return false;
+
+    case ASHIFT:
+    case ASHIFTRT:
+    case LSHIFTRT:
+      if (mode == DImode)
+        {
+          *total = COSTS_N_INSNS ((GET_CODE (XEXP (x, 1)) == CONST_INT)
+                                  ? 4 : 12);
+          return true;
+        }
+      return false;
+
+    case ABS:
+      *total = COSTS_N_INSNS (4);
+      return true;
+
+    case PLUS:
+    case MINUS:
+      if (mode == DImode)
+        {
+          *total = COSTS_N_INSNS (4);
+          return true;
+        }
+      *total = COSTS_N_INSNS (1);
+      return true;
+
+    case NEG:
+      if (mode == DImode)
+        {
+          *total = COSTS_N_INSNS (4);
+          return true;
+        }
+      return false;
+
+    case MULT:
+      *total = optimize_size ? COSTS_N_INSNS (2) : COSTS_N_INSNS (12);
+      return true;
+
+    case DIV:
+    case MOD:
+    case UDIV:
+    case UMOD:
+      *total = optimize_size ? COSTS_N_INSNS (2) : COSTS_N_INSNS (33);
+      return true;
+
+    case SIGN_EXTEND:
+    case ZERO_EXTEND:
+      switch (GET_MODE (XEXP (x, 0)))
+        {
+        case QImode:
+        case HImode:
+          if (GET_CODE (XEXP (x, 0)) == MEM)
+            {
+              *total = COSTS_N_INSNS (2);
+
+              if (!TARGET_LITTLE_ENDIAN &&
+                  side_effects_p (XEXP (XEXP (x, 0), 0)))
+                *total = 100;
+            }
+          else
+            *total = COSTS_N_INSNS (1);
+          break;
+
+        default:
+          *total = COSTS_N_INSNS (1);
+          break;
+        }
+      return true;
+
+    default:
+      return false;
+    }
+}
+
+/* Implement TARGET_ADDRESS_COST macro.  */
+int
+score_address_cost (rtx addr, enum machine_mode mode ATTRIBUTE_UNUSED,
+		    addr_space_t as ATTRIBUTE_UNUSED,
+		    bool speed ATTRIBUTE_UNUSED)
+{
+  return score_address_insns (addr, SImode);
+}
+
+/* Implement ASM_OUTPUT_EXTERNAL macro.  */
+int
+score_output_external (FILE *file ATTRIBUTE_UNUSED,
+                       tree decl, const char *name)
+{
+  struct extern_list *p;
+  if (score_in_small_data_p (decl))
+    {
+      p = ggc_alloc<extern_list> ();
+      p->next = extern_head;
+      p->name = name;
+      p->size = int_size_in_bytes (TREE_TYPE (decl));
+      extern_head = p;
+    }
+  return 0;
+}
+
+/* Implement RETURN_ADDR_RTX.  Note, we do not support moving
+   back to a previous frame.  */
+rtx
+score_return_addr (int count, rtx frame ATTRIBUTE_UNUSED)
+{
+  if (count != 0)
+    return const0_rtx;
+  return get_hard_reg_initial_val (Pmode, RA_REGNUM);
+}
+
+/* Implement PRINT_OPERAND macro.  */
+/* Score-specific operand codes:
+   '['        print .set nor1 directive
+   ']'        print .set r1 directive
+   'U'        print hi part of a CONST_INT rtx
+   'E'        print log2(v)
+   'F'        print log2(~v)
+   'D'        print SFmode const double
+   'S'        selectively print "!" if operand is 15bit instruction accessible
+   'V'        print "v!" if operand is 15bit instruction accessible, or "lfh!"
+   'L'        low  part of DImode reg operand
+   'H'        high part of DImode reg operand
+   'C'        print part of opcode for a branch condition.  */
+void
+score_print_operand (FILE *file, rtx op, int c)
+{
+  enum rtx_code code = UNKNOWN;
+  if (!PRINT_OPERAND_PUNCT_VALID_P (c))
+    code = GET_CODE (op);
+
+  if (c == '[')
+    {
+      fprintf (file, ".set r1\n");
+    }
+  else if (c == ']')
+    {
+      fprintf (file, "\n\t.set nor1");
+    }
+  else if (c == 'U')
+    {
+      gcc_assert (code == CONST_INT);
+      fprintf (file, HOST_WIDE_INT_PRINT_HEX,
+               (INTVAL (op) >> 16) & 0xffff);
+    }
+  else if (c == 'D')
+    {
+      if (GET_CODE (op) == CONST_DOUBLE)
+        {
+          rtx temp = gen_lowpart (SImode, op);
+          gcc_assert (GET_MODE (op) == SFmode);
+          fprintf (file, HOST_WIDE_INT_PRINT_HEX, INTVAL (temp) & 0xffffffff);
+        }
+      else
+        output_addr_const (file, op);
+    }
+  else if (c == 'S')
+    {
+      gcc_assert (code == REG);
+      if (G16_REG_P (REGNO (op)))
+        fprintf (file, "!");
+    }
+  else if (c == 'V')
+    {
+      gcc_assert (code == REG);
+      fprintf (file, G16_REG_P (REGNO (op)) ? "v!" : "lfh!");
+    }
+  else if (c == 'C')
+    {
+      enum machine_mode mode = GET_MODE (XEXP (op, 0));
+
+      switch (code)
+        {
+        case EQ: fputs ("eq", file); break;
+        case NE: fputs ("ne", file); break;
+        case GT: fputs ("gt", file); break;
+        case GE: fputs (mode != CCmode ? "pl" : "ge", file); break;
+        case LT: fputs (mode != CCmode ? "mi" : "lt", file); break;
+        case LE: fputs ("le", file); break;
+        case GTU: fputs ("gtu", file); break;
+        case GEU: fputs ("cs", file); break;
+        case LTU: fputs ("cc", file); break;
+        case LEU: fputs ("leu", file); break;
+        default:
+          output_operand_lossage ("invalid operand for code: '%c'", code);
+        }
+    }
+  else if (c == 'E')
+    {
+      unsigned HOST_WIDE_INT i;
+      unsigned HOST_WIDE_INT pow2mask = 1;
+      unsigned HOST_WIDE_INT val;
+
+      val = INTVAL (op);
+      for (i = 0; i < 32; i++)
+        {
+          if (val == pow2mask)
+            break;
+          pow2mask <<= 1;
+        }
+      gcc_assert (i < 32);
+      fprintf (file, HOST_WIDE_INT_PRINT_HEX, i);
+    }
+  else if (c == 'F')
+    {
+      unsigned HOST_WIDE_INT i;
+      unsigned HOST_WIDE_INT pow2mask = 1;
+      unsigned HOST_WIDE_INT val;
+
+      val = ~INTVAL (op);
+      for (i = 0; i < 32; i++)
+        {
+          if (val == pow2mask)
+            break;
+          pow2mask <<= 1;
+        }
+      gcc_assert (i < 32);
+      fprintf (file, HOST_WIDE_INT_PRINT_HEX, i);
+    }
+  else if (code == REG)
+    {
+      int regnum = REGNO (op);
+      if ((c == 'H' && !WORDS_BIG_ENDIAN)
+          || (c == 'L' && WORDS_BIG_ENDIAN))
+        regnum ++;
+      fprintf (file, "%s", reg_names[regnum]);
+    }
+  else
+    {
+      switch (code)
+        {
+        case MEM:
+          score_print_operand_address (file, op);
+          break;
+        default:
+          output_addr_const (file, op);
+        }
+    }
+}
+
+/* Implement PRINT_OPERAND_ADDRESS macro.  */
+void
+score_print_operand_address (FILE *file, rtx x)
+{
+  struct score_address_info addr;
+  enum rtx_code code = GET_CODE (x);
+  enum machine_mode mode = GET_MODE (x);
+
+  if (code == MEM)
+    x = XEXP (x, 0);
+
+  if (score_classify_address (&addr, mode, x, true))
+    {
+      switch (addr.type)
+        {
+        case SCORE_ADD_REG:
+          {
+            switch (addr.code)
+              {
+              case PRE_DEC:
+                fprintf (file, "[%s,-%ld]+", reg_names[REGNO (addr.reg)],
+                         INTVAL (addr.offset));
+                break;
+              case POST_DEC:
+                fprintf (file, "[%s]+,-%ld", reg_names[REGNO (addr.reg)],
+                         INTVAL (addr.offset));
+                break;
+              case PRE_INC:
+                fprintf (file, "[%s, %ld]+", reg_names[REGNO (addr.reg)],
+                         INTVAL (addr.offset));
+                break;
+              case POST_INC:
+                fprintf (file, "[%s]+, %ld", reg_names[REGNO (addr.reg)],
+                         INTVAL (addr.offset));
+                break;
+              default:
+                if (INTVAL(addr.offset) == 0)
+                  fprintf(file, "[%s]", reg_names[REGNO (addr.reg)]);
+                else
+                  fprintf(file, "[%s, %ld]", reg_names[REGNO (addr.reg)],
+                          INTVAL(addr.offset));
+                break;
+              }
+          }
+          return;
+        case SCORE_ADD_CONST_INT:
+        case SCORE_ADD_SYMBOLIC:
+          output_addr_const (file, x);
+          return;
+        }
+    }
+  print_rtl (stderr, x);
+  gcc_unreachable ();
+}
+
+/* Implement SELECT_CC_MODE macro.  */
+enum machine_mode
+score_select_cc_mode (enum rtx_code op, rtx x, rtx y)
+{
+  if ((op == EQ || op == NE || op == LT || op == GE)
+      && y == const0_rtx
+      && GET_MODE (x) == SImode)
+    {
+      switch (GET_CODE (x))
+        {
+        case PLUS:
+        case MINUS:
+        case NEG:
+        case AND:
+        case IOR:
+        case XOR:
+        case NOT:
+        case ASHIFT:
+        case LSHIFTRT:
+        case ASHIFTRT:
+          return CC_NZmode;
+
+        case SIGN_EXTEND:
+        case ZERO_EXTEND:
+        case ROTATE:
+        case ROTATERT:
+          return (op == LT || op == GE) ? CC_Nmode : CCmode;
+
+        default:
+          return CCmode;
+        }
+    }
+
+  if ((op == EQ || op == NE)
+      && (GET_CODE (y) == NEG)
+      && register_operand (XEXP (y, 0), SImode)
+      && register_operand (x, SImode))
+    {
+      return CC_NZmode;
+    }
+
+  return CCmode;
+}
+
+/* Generate the prologue instructions for entry into a S+core function.  */
+void
+score_prologue (void)
+{
+#define EMIT_PL(_rtx)        RTX_FRAME_RELATED_P (_rtx) = 1
+
+  struct score_frame_info *f = score_compute_frame_size (get_frame_size ());
+  HOST_WIDE_INT size;
+  int regno;
+
+  size = f->total_size - f->gp_reg_size;
+
+  if (flag_pic)
+    emit_insn (gen_cpload_score7 ());
+
+  for (regno = (int) GP_REG_LAST; regno >= (int) GP_REG_FIRST; regno--)
+    {
+      if (BITSET_P (f->mask, regno - GP_REG_FIRST))
+        {
+          rtx mem = gen_rtx_MEM (SImode,
+                                 gen_rtx_PRE_DEC (SImode, stack_pointer_rtx));
+          rtx reg = gen_rtx_REG (SImode, regno);
+          if (!crtl->calls_eh_return)
+            MEM_READONLY_P (mem) = 1;
+          EMIT_PL (emit_insn (gen_pushsi_score7 (mem, reg)));
+        }
+    }
+
+  if (size > 0)
+    {
+      rtx insn;
+
+      if (size >= -32768 && size <= 32767)
+        EMIT_PL (emit_insn (gen_add3_insn (stack_pointer_rtx,
+                                           stack_pointer_rtx,
+                                           GEN_INT (-size))));
+      else
+        {
+          EMIT_PL (emit_move_insn (gen_rtx_REG (Pmode, SCORE_PROLOGUE_TEMP_REGNUM),
+                                   GEN_INT (size)));
+          EMIT_PL (emit_insn
+                   (gen_sub3_insn (stack_pointer_rtx,
+                                   stack_pointer_rtx,
+                                   gen_rtx_REG (Pmode,
+                                                SCORE_PROLOGUE_TEMP_REGNUM))));
+        }
+      insn = get_last_insn ();
+      REG_NOTES (insn) =
+        alloc_EXPR_LIST (REG_FRAME_RELATED_EXPR,
+                         gen_rtx_SET (stack_pointer_rtx,
+                                      plus_constant (Pmode, stack_pointer_rtx,
+						     -size)),
+                                      REG_NOTES (insn));
+    }
+
+  if (frame_pointer_needed)
+    EMIT_PL (emit_move_insn (hard_frame_pointer_rtx, stack_pointer_rtx));
+
+  if (flag_pic && f->cprestore_size)
+    {
+      if (frame_pointer_needed)
+        emit_insn (gen_cprestore_use_fp_score7 (GEN_INT (size - f->cprestore_size)));
+      else
+        emit_insn (gen_cprestore_use_sp_score7 (GEN_INT (size - f->cprestore_size)));
+    }
+
+#undef EMIT_PL
+}
+
+/* Generate the epilogue instructions in a S+core function.  */
+void
+score_epilogue (int sibcall_p)
+{
+  struct score_frame_info *f = score_compute_frame_size (get_frame_size ());
+  HOST_WIDE_INT size;
+  int regno;
+  rtx base;
+
+  size = f->total_size - f->gp_reg_size;
+
+  if (!frame_pointer_needed)
+    base = stack_pointer_rtx;
+  else
+    base = hard_frame_pointer_rtx;
+
+  if (size)
+    {
+      if (size >= -32768 && size <= 32767)
+        emit_insn (gen_add3_insn (base, base, GEN_INT (size)));
+      else
+        {
+          emit_move_insn (gen_rtx_REG (Pmode, SCORE_EPILOGUE_TEMP_REGNUM),
+                          GEN_INT (size));
+          emit_insn (gen_add3_insn (base, base,
+                                    gen_rtx_REG (Pmode,
+                                                 SCORE_EPILOGUE_TEMP_REGNUM)));
+        }
+    }
+
+  if (base != stack_pointer_rtx)
+    emit_move_insn (stack_pointer_rtx, base);
+
+  if (crtl->calls_eh_return)
+    emit_insn (gen_add3_insn (stack_pointer_rtx,
+                              stack_pointer_rtx,
+                              EH_RETURN_STACKADJ_RTX));
+
+  for (regno = (int) GP_REG_FIRST; regno <= (int) GP_REG_LAST; regno++)
+    {
+      if (BITSET_P (f->mask, regno - GP_REG_FIRST))
+        {
+          rtx mem = gen_rtx_MEM (SImode,
+                                 gen_rtx_POST_INC (SImode, stack_pointer_rtx));
+          rtx reg = gen_rtx_REG (SImode, regno);
+
+          if (!crtl->calls_eh_return)
+            MEM_READONLY_P (mem) = 1;
+
+          emit_insn (gen_popsi_score7 (reg, mem));
+        }
+    }
+
+  if (!sibcall_p)
+    emit_jump_insn (gen_return_internal_score7 (gen_rtx_REG (Pmode, RA_REGNUM)));
+}
+
+/* Return true if X is a symbolic constant that can be calculated in
+   the same way as a bare symbol.  If it is, store the type of the
+   symbol in *SYMBOL_TYPE.  */
+int
+score_symbolic_constant_p (rtx x, enum score_symbol_type *symbol_type)
+{
+  HOST_WIDE_INT offset;
+
+  score_split_const (x, &x, &offset);
+  if (GET_CODE (x) == SYMBOL_REF || GET_CODE (x) == LABEL_REF)
+    *symbol_type = score_classify_symbol (x);
+  else
+    return 0;
+
+  if (offset == 0)
+    return 1;
+
+  /* if offset > 15bit, must reload  */
+  if (!IMM_IN_RANGE (offset, 15, 1))
+    return 0;
+
+  switch (*symbol_type)
+    {
+    case SYMBOL_GENERAL:
+      return 1;
+    case SYMBOL_SMALL_DATA:
+      return score_offset_within_object_p (x, offset);
+    }
+  gcc_unreachable ();
+}
+
+void
+score_movsicc (rtx *ops)
+{
+  enum machine_mode mode;
+
+  mode = score_select_cc_mode (GET_CODE (ops[1]), ops[2], ops[3]);
+  emit_insn (gen_rtx_SET (gen_rtx_REG (mode, CC_REGNUM),
+                          gen_rtx_COMPARE (mode, XEXP (ops[1], 0),
+					   XEXP (ops[1], 1))));
+}
+
+/* Call and sibcall pattern all need call this function.  */
+void
+score_call (rtx *ops, bool sib)
+{
+  rtx addr = XEXP (ops[0], 0);
+  if (!call_insn_operand (addr, VOIDmode))
+    {
+      rtx oaddr = addr;
+      addr = gen_reg_rtx (Pmode);
+      gen_move_insn (addr, oaddr);
+    }
+
+  if (sib)
+    emit_call_insn (gen_sibcall_internal_score7 (addr, ops[1]));
+  else
+    emit_call_insn (gen_call_internal_score7 (addr, ops[1]));
+}
+
+/* Call value and sibcall value pattern all need call this function.  */
+void
+score_call_value (rtx *ops, bool sib)
+{
+  rtx result = ops[0];
+  rtx addr = XEXP (ops[1], 0);
+  rtx arg = ops[2];
+
+  if (!call_insn_operand (addr, VOIDmode))
+    {
+      rtx oaddr = addr;
+      addr = gen_reg_rtx (Pmode);
+      gen_move_insn (addr, oaddr);
+    }
+
+  if (sib)
+    emit_call_insn (gen_sibcall_value_internal_score7 (result, addr, arg));
+  else
+    emit_call_insn (gen_call_value_internal_score7 (result, addr, arg));
+}
+
+/* Machine Split  */
+void
+score_movdi (rtx *ops)
+{
+  rtx dst = ops[0];
+  rtx src = ops[1];
+  rtx dst0 = score_subw (dst, 0);
+  rtx dst1 = score_subw (dst, 1);
+  rtx src0 = score_subw (src, 0);
+  rtx src1 = score_subw (src, 1);
+
+  if (GET_CODE (dst0) == REG && reg_overlap_mentioned_p (dst0, src))
+    {
+      emit_move_insn (dst1, src1);
+      emit_move_insn (dst0, src0);
+    }
+  else
+    {
+      emit_move_insn (dst0, src0);
+      emit_move_insn (dst1, src1);
+    }
+}
+
+void
+score_zero_extract_andi (rtx *ops)
+{
+  if (INTVAL (ops[1]) == 1 && const_uimm5 (ops[2], SImode))
+    emit_insn (gen_zero_extract_bittst_score7 (ops[0], ops[2]));
+  else
+    {
+      unsigned HOST_WIDE_INT mask;
+      mask = (0xffffffffU & ((1U << INTVAL (ops[1])) - 1U));
+      mask = mask << INTVAL (ops[2]);
+      emit_insn (gen_andsi3_cmp_score7 (ops[3], ops[0],
+                                 gen_int_mode (mask, SImode)));
+    }
+}
+
+/* Check addr could be present as PRE/POST mode.  */
+static bool
+score_pindex_mem (rtx addr)
+{
+  if (GET_CODE (addr) == MEM)
+    {
+      switch (GET_CODE (XEXP (addr, 0)))
+        {
+        case PRE_DEC:
+        case POST_DEC:
+        case PRE_INC:
+        case POST_INC:
+          return true;
+        default:
+          break;
+        }
+    }
+  return false;
+}
+
+/* Output asm code for ld/sw insn.  */
+static int
+score_pr_addr_post (rtx *ops, int idata, int iaddr, char *ip, enum score_mem_unit unit)
+{
+  struct score_address_info ai;
+
+  gcc_assert (GET_CODE (ops[idata]) == REG);
+  gcc_assert (score_classify_address (&ai, SImode, XEXP (ops[iaddr], 0), true));
+
+  if (!score_pindex_mem (ops[iaddr])
+      && ai.type == SCORE_ADD_REG
+      && GET_CODE (ai.offset) == CONST_INT
+      && G16_REG_P (REGNO (ops[idata]))
+      && G16_REG_P (REGNO (ai.reg)))
+    {
+      if (INTVAL (ai.offset) == 0)
+        {
+          ops[iaddr] = ai.reg;
+          return snprintf (ip, INS_BUF_SZ,
+                           "!\t%%%d, [%%%d]", idata, iaddr);
+        }
+      if (REGNO (ai.reg) == HARD_FRAME_POINTER_REGNUM)
+        {
+          HOST_WIDE_INT offset = INTVAL (ai.offset);
+          if (SCORE_ALIGN_UNIT (offset, unit)
+              && (((offset >> unit) >= 0) && ((offset >> unit) <= 31)))
+            {
+              ops[iaddr] = ai.offset;
+              return snprintf (ip, INS_BUF_SZ,
+                               "p!\t%%%d, %%c%d", idata, iaddr);
+            }
+        }
+    }
+  return snprintf (ip, INS_BUF_SZ, "\t%%%d, %%a%d", idata, iaddr);
+}
+
+/* Output asm insn for load.  */
+const char *
+score_linsn (rtx *ops, enum score_mem_unit unit, bool sign)
+{
+  const char *pre_ins[] =
+    {"lbu", "lhu", "lw", "??", "lb", "lh", "lw", "??"};
+  char *ip;
+
+  strcpy (score_ins, pre_ins[(sign ? 4 : 0) + unit]);
+  ip = score_ins + strlen (score_ins);
+
+  if ((!sign && unit != SCORE_HWORD)
+      || (sign && unit != SCORE_BYTE))
+    score_pr_addr_post (ops, 0, 1, ip, unit);
+  else
+    snprintf (ip, INS_BUF_SZ, "\t%%0, %%a1");
+
+  return score_ins;
+}
+
+/* Output asm insn for store.  */
+const char *
+score_sinsn (rtx *ops, enum score_mem_unit unit)
+{
+  const char *pre_ins[] = {"sb", "sh", "sw"};
+  char *ip;
+
+  strcpy (score_ins, pre_ins[unit]);
+  ip = score_ins + strlen (score_ins);
+  score_pr_addr_post (ops, 1, 0, ip, unit);
+  return score_ins;
+}
+
+/* Output asm insn for load immediate.  */
+const char *
+score_limm (rtx *ops)
+{
+  HOST_WIDE_INT v;
+
+  gcc_assert (GET_CODE (ops[0]) == REG);
+  gcc_assert (GET_CODE (ops[1]) == CONST_INT);
+
+  v = INTVAL (ops[1]);
+  if (G16_REG_P (REGNO (ops[0])) && IMM_IN_RANGE (v, 8, 0))
+    return "ldiu!\t%0, %c1";
+  else if (IMM_IN_RANGE (v, 16, 1))
+    return "ldi\t%0, %c1";
+  else if ((v & 0xffff) == 0)
+    return "ldis\t%0, %U1";
+  else
+    return "li\t%0, %c1";
+}
+
+/* Output asm insn for move.  */
+const char *
+score_move (rtx *ops)
+{
+  gcc_assert (GET_CODE (ops[0]) == REG);
+  gcc_assert (GET_CODE (ops[1]) == REG);
+
+  if (G16_REG_P (REGNO (ops[0])))
+    {
+      if (G16_REG_P (REGNO (ops[1])))
+        return "mv!\t%0, %1";
+      else
+        return "mlfh!\t%0, %1";
+    }
+  else if (G16_REG_P (REGNO (ops[1])))
+    return "mhfl!\t%0, %1";
+  else
+    return "mv\t%0, %1";
+}
+
+/* Generate add insn.  */
+const char *
+score_select_add_imm (rtx *ops, bool set_cc)
+{
+  HOST_WIDE_INT v = INTVAL (ops[2]);
+
+  gcc_assert (GET_CODE (ops[2]) == CONST_INT);
+  gcc_assert (REGNO (ops[0]) == REGNO (ops[1]));
+
+  if (set_cc && G16_REG_P (REGNO (ops[0])))
+    {
+      if (v > 0 && IMM_IS_POW_OF_2 ((unsigned HOST_WIDE_INT) v, 0, 15))
+        {
+          ops[2] = GEN_INT (ffs (v) - 1);
+          return "addei!\t%0, %c2";
+        }
+
+      if (v < 0 && IMM_IS_POW_OF_2 ((unsigned HOST_WIDE_INT) (-v), 0, 15))
+        {
+          ops[2] = GEN_INT (ffs (-v) - 1);
+          return "subei!\t%0, %c2";
+        }
+    }
+
+  if (set_cc)
+    return "addi.c\t%0, %c2";
+  else
+    return "addi\t%0, %c2";
+}
+
+/* Output arith insn.  */
+const char *
+score_select (rtx *ops, const char *inst_pre,
+              bool commu, const char *letter, bool set_cc)
+{
+  gcc_assert (GET_CODE (ops[0]) == REG);
+  gcc_assert (GET_CODE (ops[1]) == REG);
+
+  if (set_cc && G16_REG_P (REGNO (ops[0]))
+      && (GET_CODE (ops[2]) == REG ? G16_REG_P (REGNO (ops[2])) : 1)
+      && REGNO (ops[0]) == REGNO (ops[1]))
+    {
+      snprintf (score_ins, INS_BUF_SZ, "%s!\t%%0, %%%s2", inst_pre, letter);
+      return score_ins;
+    }
+
+  if (commu && set_cc && G16_REG_P (REGNO (ops[0]))
+      && G16_REG_P (REGNO (ops[1]))
+      && REGNO (ops[0]) == REGNO (ops[2]))
+    {
+      gcc_assert (GET_CODE (ops[2]) == REG);
+      snprintf (score_ins, INS_BUF_SZ, "%s!\t%%0, %%%s1", inst_pre, letter);
+      return score_ins;
+    }
+
+  if (set_cc)
+    snprintf (score_ins, INS_BUF_SZ, "%s.c\t%%0, %%1, %%%s2", inst_pre, letter);
+  else
+    snprintf (score_ins, INS_BUF_SZ, "%s\t%%0, %%1, %%%s2", inst_pre, letter);
+  return score_ins;
+}
+
+/* Return nonzero when an argument must be passed by reference.  */
+static bool
+score_pass_by_reference (cumulative_args_t, const function_arg_info &arg)
+{
+  /* If we have a variable-sized parameter, we have no choice.  */
+  return targetm.calls.must_pass_in_stack (arg);
+}
+
+/* Implement TARGET_FUNCTION_OK_FOR_SIBCALL.  */
+static bool
+score_function_ok_for_sibcall (ATTRIBUTE_UNUSED tree decl,
+                               ATTRIBUTE_UNUSED tree exp)
+{
+  return true;
+}
+
+/* Implement TARGET_SCHED_ISSUE_RATE.  */
+static int
+score_issue_rate (void)
+{
+  return 1;
+}
+
+/* We can always eliminate to the hard frame pointer.  We can eliminate
+   to the stack pointer unless a frame pointer is needed.  */
+
+static bool
+score_can_eliminate (const int from ATTRIBUTE_UNUSED, const int to)
+{
+  return (to == HARD_FRAME_POINTER_REGNUM
+          || (to  == STACK_POINTER_REGNUM && !frame_pointer_needed));
+}
+
+/* Argument support functions.  */
+
+/* Initialize CUMULATIVE_ARGS for a function.  */
+void
+score_init_cumulative_args (CUMULATIVE_ARGS *cum,
+                            tree fntype ATTRIBUTE_UNUSED,
+                            rtx libname ATTRIBUTE_UNUSED)
+{
+  memset (cum, 0, sizeof (CUMULATIVE_ARGS));
+}
+
+/* Implement TARGET_STRUCT_VALUE_RTX  */
+static rtx
+score_struct_value_rtx (tree fntype ATTRIBUTE_UNUSED,
+		      int incoming ATTRIBUTE_UNUSED)
+{
+  return gen_rtx_REG (Pmode, 0);
+}
+
+/* Implement TARGET_HARD_REGNO_NREGS.  */
+static unsigned int
+score_hard_regno_nregs (unsigned int regno ATTRIBUTE_UNUSED, machine_mode mode)
+{
+  return (GET_MODE_SIZE (mode) + UNITS_PER_WORD - 1) / UNITS_PER_WORD;
+}
+
+/* Implement TARGET_C_MODE_FOR_FLOATING_TYPE.  */
+static machine_mode
+score_c_mode_for_floating_type (enum tree_index ti)
+{
+  return default_mode_for_floating_type (ti);
+}
+
+/* Implement TARGET_MODES_TIEABLE_P.  */
+static bool
+score_modes_tieable_p (machine_mode mode1, machine_mode mode2)
+{
+	return((GET_MODE_CLASS (mode1) == MODE_FLOAT
+    || GET_MODE_CLASS (mode1) == MODE_COMPLEX_FLOAT)
+    == (GET_MODE_CLASS (mode2) == MODE_FLOAT
+       || GET_MODE_CLASS (mode2) == MODE_COMPLEX_FLOAT));
+}
+
+/* Implement TARGET_CONSTANT_ALIGNMENT.  Align string constants and
+   constructors to at least a word boundary.  The typical use of this
+   macro is to increase alignment for string constants to be word
+   aligned so that 'strcpy' calls that copy constants can be done
+   inline.  */
+static HOST_WIDE_INT
+score_constant_alignment (const_tree exp, HOST_WIDE_INT align)
+{
+  return ((TREE_CODE (exp) == STRING_CST  || TREE_CODE (exp) == CONSTRUCTOR)   \
+    && (align) < BITS_PER_WORD ? BITS_PER_WORD : (align));
+}
+
+/* Implement TARGET_STARTING_FRAME_OFFSET.  */
+static HOST_WIDE_INT
+score_starting_frame_offset (void)
+{
+  return crtl->outgoing_args_size;
+}
+
+/* Implement TARGET_CAN_CHANGE_MODE_CLASS. This code is ported from the
+  definition of a CANNOT_CHANGE_MODE_CLASS macro, so it is inverted.
+  Or should it be? My gut feeling says yes */
+static bool
+score_can_change_mode_class (machine_mode from, machine_mode to,
+			      reg_class_t rclass)
+{
+  return !((GET_MODE_SIZE (from) != GET_MODE_SIZE (to)
+    ? reg_classes_intersect_p (HI_REG, (rclass)) : 0));
+}
+
+/* Implement TARGET_TRULY_NOOP_TRUNCATION.
+   Value is 1 if truncating an integer of INPREC bits to OUTPREC bits
+   is done just by pretending it is already truncated.  */
+static bool
+score_truly_noop_truncation (poly_uint64, poly_uint64)
+{
+  return 1;
+}
+
+static void
+score_conditional_register_usage (void)
+{
+   if (!flag_pic)
+     fixed_regs[PIC_OFFSET_TABLE_REGNUM] =
+     call_used_regs[PIC_OFFSET_TABLE_REGNUM] = 0;
+}
+
+struct gcc_target targetm = TARGET_INITIALIZER;
+
+#include "gt-score.h"
diff --git a/gcc/config/score/score.h b/gcc/config/score/score.h
new file mode 100644
index 000000000..fa924a74b
--- /dev/null
+++ b/gcc/config/score/score.h
@@ -0,0 +1,808 @@
+/* score.h for Sunplus S+CORE processor
+   Copyright (C) 2005-2014 Free Software Foundation, Inc.
+   Contributed by Sunnorth.
+
+   This file is part of GCC.
+
+   GCC is free software; you can redistribute it and/or modify it
+   under the terms of the GNU General Public License as published
+   by the Free Software Foundation; either version 3, or (at your
+   option) any later version.
+
+   GCC is distributed in the hope that it will be useful, but WITHOUT
+   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
+   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
+   License for more details.
+
+   You should have received a copy of the GNU General Public License
+   along with GCC; see the file COPYING3.  If not see
+   <http://www.gnu.org/licenses/>.  */
+
+#include "score-conv.h"
+
+#undef CC1_SPEC
+#define CC1_SPEC                 "%{!mel:-meb} %{mel:-mel } \
+%{!mscore*:-mscore7}    \
+%{mscore7:-mscore7}     \
+%{mscore7d:-mscore7d}   \
+%{G*}"
+
+#undef ASM_SPEC
+#define ASM_SPEC                 "%{!mel:-EB} %{mel:-EL} \
+%{!mscore*:-march=score7}         \
+%{mscore7:-march=score7}          \
+%{mscore7d:-march=score7}         \
+%{march=score7:-march=score7}     \
+%{march=score7d:-march=score7}    \
+%{G*}"
+
+#undef LINK_SPEC
+#define LINK_SPEC                "%{!mel:-EB} %{mel:-EL} \
+%{!mscore*:-mscore7_elf}          \
+%{mscore7:-mscore7_elf}           \
+%{mscore7d:-mscore7_elf}          \
+%{march=score7:-mscore7_elf}      \
+%{march=score7d:-mscore7_elf}     \
+%{G*}"
+
+/* Run-time Target Specification.  */
+#define TARGET_CPU_CPP_BUILTINS()               \
+  do {                                          \
+    builtin_define ("SUNPLUS");                 \
+    builtin_define ("__SCORE__");               \
+    builtin_define ("__score__");               \
+    if (TARGET_LITTLE_ENDIAN)                   \
+      builtin_define ("__scorele__");           \
+    else                                        \
+      builtin_define ("__scorebe__");           \
+    if (TARGET_SCORE7)                          \
+      builtin_define ("__score7__");            \
+    if (TARGET_SCORE7D)                         \
+      builtin_define ("__score7d__");           \
+  } while (0)
+
+#define TARGET_DEFAULT         0
+
+#define SCORE_GCC_VERSION      "1.6"
+
+/* Target machine storage layout.  */
+#define BITS_BIG_ENDIAN        0
+#define BYTES_BIG_ENDIAN       (TARGET_LITTLE_ENDIAN == 0)
+#define WORDS_BIG_ENDIAN       (TARGET_LITTLE_ENDIAN == 0)
+
+/* Width of a word, in units (bytes).  */
+#define UNITS_PER_WORD                 4
+
+/* Define this macro if it is advisable to hold scalars in registers
+   in a wider mode than that declared by the program.  In such cases,
+   the value is constrained to be within the bounds of the declared
+   type, but kept valid in the wider mode.  The signedness of the
+   extension may differ from that of the type.  */
+#define PROMOTE_MODE(MODE, UNSIGNEDP, TYPE)     \
+  if (GET_MODE_CLASS (MODE) == MODE_INT         \
+      && GET_MODE_SIZE (MODE) < UNITS_PER_WORD) \
+    (MODE) = SImode;
+
+/* Allocation boundary (in *bits*) for storing arguments in argument list.  */
+#define PARM_BOUNDARY                  BITS_PER_WORD
+#define STACK_BOUNDARY                 BITS_PER_WORD
+
+/* Allocation boundary (in *bits*) for the code of a function.  */
+#define FUNCTION_BOUNDARY              BITS_PER_WORD
+
+/* There is no point aligning anything to a rounder boundary than this.  */
+#define BIGGEST_ALIGNMENT              64
+
+/* If defined, a C expression to compute the alignment for a static
+   variable.  TYPE is the data type, and ALIGN is the alignment that
+   the object would ordinarily have.  The value of this macro is used
+   instead of that alignment to align the object.
+
+   If this macro is not defined, then ALIGN is used.
+
+   One use of this macro is to increase alignment of medium-size
+   data to make it all fit in fewer cache lines.  Another is to
+   cause character arrays to be word-aligned so that `strcpy' calls
+   that copy constants to character arrays can be done inline.  */
+#define DATA_ALIGNMENT(TYPE, ALIGN)                                      \
+  ((((ALIGN) < BITS_PER_WORD)                                            \
+    && (TREE_CODE (TYPE) == ARRAY_TYPE                                   \
+        || TREE_CODE (TYPE) == UNION_TYPE                                \
+        || TREE_CODE (TYPE) == RECORD_TYPE)) ? BITS_PER_WORD : (ALIGN))
+
+/* If defined, a C expression to compute the alignment for a local
+   variable.  TYPE is the data type, and ALIGN is the alignment that
+   the object would ordinarily have.  The value of this macro is used
+   instead of that alignment to align the object.
+
+   If this macro is not defined, then ALIGN is used.
+
+   One use of this macro is to increase alignment of medium-size
+   data to make it all fit in fewer cache lines.  */
+#define LOCAL_ALIGNMENT(TYPE, ALIGN)                                    \
+  ((TREE_CODE (TYPE) == ARRAY_TYPE                                      \
+    && TYPE_MODE (TREE_TYPE (TYPE)) == QImode                           \
+    && (ALIGN) < BITS_PER_WORD) ? BITS_PER_WORD : (ALIGN))
+
+/* Alignment of field after `int : 0' in a structure.  */
+#define EMPTY_FIELD_BOUNDARY           32
+
+/* All accesses must be aligned.  */
+#define STRICT_ALIGNMENT               1
+
+/* Score requires that structure alignment is affected by bitfields.  */
+#define PCC_BITFIELD_TYPE_MATTERS      1
+
+/* long double is not a fixed mode, but the idea is that, if we
+   support long double, we also want a 128-bit integer type.  */
+#define MAX_FIXED_MODE_SIZE            64
+
+/* Layout of Data Type.  */
+/* Set the sizes of the core types.  */
+#define INT_TYPE_SIZE                   32
+#define SHORT_TYPE_SIZE                 16
+#define LONG_TYPE_SIZE                  32
+#define LONG_LONG_TYPE_SIZE             64
+#define CHAR_TYPE_SIZE                  8
+
+/* Define this as 1 if `char' should by default be signed; else as 0.  */
+#undef DEFAULT_SIGNED_CHAR
+#define DEFAULT_SIGNED_CHAR             1
+
+/* Default definitions for size_t and ptrdiff_t.  */
+#define SIZE_TYPE                       "unsigned int"
+
+#define UINTPTR_TYPE			"long unsigned int"
+
+/* Register Usage
+
+   S+core have:
+   - 32 integer registers
+   - 16 control registers (cond)
+   - 16 special registers (ceh/cel/cnt/lcr/scr/arg/fp)
+   - 32 coprocessors 1 registers
+   - 32 coprocessors 2 registers
+   - 32 coprocessors 3 registers.  */
+#define FIRST_PSEUDO_REGISTER           160
+
+/* By default, fix the kernel registers (r30 and r31), the global
+   pointer (r28) and the stack pointer (r0).  This can change
+   depending on the command-line options.
+
+   Regarding coprocessor registers: without evidence to the contrary,
+   it's best to assume that each coprocessor register has a unique
+   use.  This can be overridden, in, e.g., TARGET_OPTION_OVERRIDE or
+   TARGET_CONDITIONAL_REGISTER_USAGE should the assumption be inappropriate
+   for a particular target.  */
+
+/* Control Registers, use mfcr/mtcr insn
+    32        cr0         PSR
+    33        cr1         Condition
+    34        cr2         ECR
+    35        cr3         EXCPVec
+    36        cr4         CCR
+    37        cr5         EPC
+    38        cr6         EMA
+    39        cr7         TLBLock
+    40        cr8         TLBPT
+    41        cr8         PEADDR
+    42        cr10        TLBRPT
+    43        cr11        PEVN
+    44        cr12        PECTX
+    45        cr13
+    46        cr14
+    47        cr15
+
+    Custom Engine Register, use mfce/mtce
+    48        CEH        CEH
+    49        CEL        CEL
+
+    Special-Purpose Register, use mfsr/mtsr
+    50        sr0        CNT
+    51        sr1        LCR
+    52        sr2        SCR
+
+    53        ARG_POINTER_REGNUM
+    54        FRAME_POINTER_REGNUM
+    but Control register have 32 registers, cr16-cr31.  */
+#define FIXED_REGISTERS                                  \
+{                                                        \
+  /* General Purpose Registers  */                       \
+  1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        \
+  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,        \
+  /* Control Registers  */                               \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* CEH/ CEL/ CNT/ LCR/ SCR / ARG_POINTER_REGNUM/ FRAME_POINTER_REGNUM */\
+  0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* CP 1 Registers  */                                  \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* CP 2 Registers  */                                  \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* CP 3 Registers  */                                  \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+}
+
+#define CALL_USED_REGISTERS                              \
+{                                                        \
+  /* General purpose register  */                        \
+  1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,        \
+  0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* Control Registers  */                               \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* CP 1 Registers  */                                  \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* CP 2 Registers  */                                  \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  /* CP 3 Registers  */                                  \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,        \
+}
+
+#define REG_ALLOC_ORDER                                                   \
+{   0,  1,  6,  7,  8,  9, 10, 11,  4,  5, 22, 23, 24, 25, 26, 27,        \
+   12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 28, 29, 30, 31,  2,  3,        \
+   32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,        \
+   48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,        \
+   64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,        \
+   80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95,        \
+   96, 97, 98, 99,100,101,102,103,104,105,106,107,108,109,110,111,        \
+  112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,        \
+  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,        \
+  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159        }
+
+/* Macro to conditionally modify fixed_regs/call_used_regs.  */
+#define PIC_OFFSET_TABLE_REGNUM          29
+
+/* Register Classes.  */
+/* Define the classes of registers for register constraints in the
+   machine description.  Also define ranges of constants.  */
+enum reg_class
+{
+  NO_REGS,
+  G16_REGS,    /* r0 ~ r15 */
+  G32_REGS,    /* r0 ~ r31 */
+  T32_REGS,    /* r8 ~ r11 | r22 ~ r27 */
+
+  HI_REG,      /* hi                 */
+  LO_REG,      /* lo                 */
+  CE_REGS,     /* hi + lo            */
+
+  CN_REG,      /* cnt                */
+  LC_REG,      /* lcb                */
+  SC_REG,      /* scb                */
+  SP_REGS,     /* cnt + lcb + scb    */
+
+  CR_REGS,     /* cr0 - cr15         */
+
+  CP1_REGS,    /* cp1                */
+  CP2_REGS,    /* cp2                */
+  CP3_REGS,    /* cp3                */
+  CPA_REGS,    /* cp1 + cp2 + cp3    */
+
+  ALL_REGS,
+  LIM_REG_CLASSES
+};
+
+#define N_REG_CLASSES                  ((int) LIM_REG_CLASSES)
+
+#define GENERAL_REGS                   G32_REGS
+
+/* Give names of register classes as strings for dump file.  */
+#define REG_CLASS_NAMES           \
+{                                 \
+  "NO_REGS",                      \
+  "G16_REGS",                     \
+  "G32_REGS",                     \
+  "T32_REGS",                     \
+                                  \
+  "HI_REG",                       \
+  "LO_REG",                       \
+  "CE_REGS",                      \
+                                  \
+  "CN_REG",                       \
+  "LC_REG",                       \
+  "SC_REG",                       \
+  "SP_REGS",                      \
+                                  \
+  "CR_REGS",                      \
+                                  \
+  "CP1_REGS",                     \
+  "CP2_REGS",                     \
+  "CP3_REGS",                     \
+  "CPA_REGS",                     \
+                                  \
+  "ALL_REGS",                     \
+}
+
+/* Define which registers fit in which classes.  */
+#define REG_CLASS_CONTENTS                                        \
+{                                                                 \
+  /* NO_REGS/G16/G32/T32  */                                      \
+  { 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x0000ffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0xffffffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x0fc00f00, 0x00000000, 0x00000000, 0x00000000, 0x00000000},  \
+  /* HI/LO/CE  */                                                 \
+  { 0x00000000, 0x00010000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x00000000, 0x00020000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x00000000, 0x00030000, 0x00000000, 0x00000000, 0x00000000},  \
+  /* CN/LC/SC/SP/CR  */                                           \
+  { 0x00000000, 0x00040000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x00000000, 0x00080000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x00000000, 0x00100000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x00000000, 0x001c0000, 0x00000000, 0x00000000, 0x00000000},  \
+  { 0x00000000, 0x0000ffff, 0x00000000, 0x00000000, 0x00000000},  \
+  /* CP1/CP2/CP3/CPA  */                                          \
+  { 0x00000000, 0x00000000, 0xffffffff, 0x00000000, 0x00000000},  \
+  { 0x00000000, 0x00000000, 0x00000000, 0xffffffff, 0x00000000},  \
+  { 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xffffffff},  \
+  { 0x00000000, 0x00000000, 0xffffffff, 0xffffffff, 0xffffffff},  \
+  /* ALL_REGS  */                                                 \
+  { 0xffffffff, 0x001fffff, 0xffffffff, 0xffffffff, 0xffffffff},  \
+}
+
+/* A C expression whose value is a register class containing hard
+   register REGNO.  In general there is more that one such class;
+   choose a class which is "minimal", meaning that no smaller class
+   also contains the register.  */
+#define REGNO_REG_CLASS(REGNO) (enum reg_class) score_reg_class (REGNO)
+
+/* A macro whose definition is the name of the class to which a
+   valid base register must belong.  A base register is one used in
+   an address which is the register value plus a displacement.  */
+#define BASE_REG_CLASS                 G16_REGS
+
+/* The class value for index registers.  */
+#define INDEX_REG_CLASS                NO_REGS
+
+/* Addressing modes, and classification of registers for them.  */
+#define REGNO_MODE_OK_FOR_BASE_P(REGNO, MODE) \
+  score_regno_mode_ok_for_base_p (REGNO, 1)
+
+#define REGNO_OK_FOR_INDEX_P(NUM)       0
+
+#define PREFERRED_RELOAD_CLASS(X, CLASS) \
+  score_preferred_reload_class (X, CLASS)
+
+/* If we need to load shorts byte-at-a-time, then we need a scratch.  */
+#define SECONDARY_INPUT_RELOAD_CLASS(CLASS, MODE, X) \
+  score_secondary_reload_class (CLASS, MODE, X)
+
+/* Return the register class of a scratch register needed to copy IN into
+   or out of a register in CLASS in MODE.  If it can be done directly,
+   NO_REGS is returned.  */
+#define SECONDARY_OUTPUT_RELOAD_CLASS(CLASS, MODE, X) \
+  score_secondary_reload_class (CLASS, MODE, X)
+
+/* Basic Stack Layout.  */
+/* Stack layout; function entry, exit and calling.  */
+#define STACK_GROWS_DOWNWARD			1
+
+#define STACK_PUSH_CODE                 PRE_DEC
+#define STACK_POP_CODE                  POST_INC
+
+/* The argument pointer always points to the first argument.  */
+#define FIRST_PARM_OFFSET(FUNDECL)      0
+
+/* A C expression whose value is RTL representing the value of the return
+   address for the frame COUNT steps up from the current frame.  */
+#define RETURN_ADDR_RTX(count, frame)   score_return_addr (count, frame)
+
+/* Pick up the return address upon entry to a procedure.  */
+#define INCOMING_RETURN_ADDR_RTX        gen_rtx_REG (VOIDmode, RA_REGNUM)
+
+/* Exception handling Support.  */
+/* Use r0 to r3 to pass exception handling information.  */
+#define EH_RETURN_DATA_REGNO(N) \
+  ((N) < 4 ? (N) + ARG_REG_FIRST : INVALID_REGNUM)
+
+/* The register that holds the return address in exception handlers.  */
+#define EH_RETURN_STACKADJ_RTX          gen_rtx_REG (Pmode, EH_REGNUM)
+#define EH_RETURN_HANDLER_RTX  		gen_rtx_REG (SImode, 30)
+
+/* Registers That Address the Stack Frame.  */
+/* Register to use for pushing function arguments.  */
+#define STACK_POINTER_REGNUM            SP_REGNUM
+
+/* These two registers don't really exist: they get eliminated to either
+   the stack or hard frame pointer.  */
+#define FRAME_POINTER_REGNUM            53
+
+/*  we use r2 as the frame pointer.  */
+#define HARD_FRAME_POINTER_REGNUM       FP_REGNUM
+
+#define ARG_POINTER_REGNUM              54
+
+/* Register in which static-chain is passed to a function.  */
+#define STATIC_CHAIN_REGNUM             23
+
+/* Elimination Frame Pointer and Arg Pointer  */
+
+#define ELIMINABLE_REGS                                \
+  {{ ARG_POINTER_REGNUM, STACK_POINTER_REGNUM},        \
+   { ARG_POINTER_REGNUM, HARD_FRAME_POINTER_REGNUM},   \
+   { FRAME_POINTER_REGNUM, STACK_POINTER_REGNUM},      \
+   { FRAME_POINTER_REGNUM, HARD_FRAME_POINTER_REGNUM}}
+
+#define INITIAL_ELIMINATION_OFFSET(FROM, TO, OFFSET) \
+  (OFFSET) = score_initial_elimination_offset ((FROM), (TO))
+
+/* Passing Function Arguments on the Stack.  */
+/* Allocate stack space for arguments at the beginning of each function.  */
+#define ACCUMULATE_OUTGOING_ARGS        1
+
+/* reserve stack space for all argument registers.  */
+#define REG_PARM_STACK_SPACE(FNDECL)    UNITS_PER_WORD
+
+/* Define this if it is the responsibility of the caller to
+   allocate the area reserved for arguments passed in registers.
+   If `ACCUMULATE_OUTGOING_ARGS' is also defined, the only effect
+   of this macro is to determine whether the space is included in
+   `crtl->outgoing_args_size'.  */
+#define OUTGOING_REG_PARM_STACK_SPACE(FNTYPE) 1
+
+/* Passing Arguments in Registers  */
+/* A C type for declaring a variable that is used as the first argument of
+   `FUNCTION_ARG' and other related values.  For some target machines, the
+   type `int' suffices and can hold the number of bytes of argument so far.  */
+typedef struct score_args
+{
+  unsigned int arg_number;             /* how many arguments have been seen  */
+  unsigned int num_gprs;               /* number of gprs in use  */
+  unsigned int stack_words;            /* number of words in stack  */
+} score_args_t;
+
+#define CUMULATIVE_ARGS                score_args_t
+
+/* Initialize a variable CUM of type CUMULATIVE_ARGS
+   for a call to a function whose data type is FNTYPE.
+   For a library call, FNTYPE is 0.  */
+#define INIT_CUMULATIVE_ARGS(CUM, FNTYPE, LIBNAME, INDIRECT, n_named_args) \
+  score_init_cumulative_args (&CUM, FNTYPE, LIBNAME)
+
+/* 1 if N is a possible register number for function argument passing.
+   We have no FP argument registers when soft-float.  When FP registers
+   are 32 bits, we can't directly reference the odd numbered ones.  */
+#define FUNCTION_ARG_REGNO_P(REGNO) \
+  REG_CONTAIN (REGNO, ARG_REG_FIRST, ARG_REG_NUM)
+
+/* How Scalar Function Values Are Returned.  */
+#define FUNCTION_VALUE(VALTYPE, FUNC) \
+  score_function_value ((VALTYPE), (FUNC), VOIDmode)
+
+#define LIBCALL_VALUE(MODE)  score_function_value (NULL_TREE, NULL, (MODE))
+
+/* 1 if N is a possible register number for a function value.  */
+#define FUNCTION_VALUE_REGNO_P(REGNO)   ((REGNO) == (ARG_REG_FIRST))
+
+#define PIC_FUNCTION_ADDR_REGNUM        (GP_REG_FIRST + 25)
+
+/* Function Entry and Exit  */
+/* EXIT_IGNORE_STACK should be nonzero if, when returning from a function,
+   the stack pointer does not matter.  The value is tested only in
+   functions that have frame pointers.
+   No definition is equivalent to always zero.  */
+#define EXIT_IGNORE_STACK               1
+
+/* Generating Code for Profiling  */
+/* Output assembler code to FILE to increment profiler label # LABELNO
+   for profiling a function entry.  */
+#define FUNCTION_PROFILER(FILE, LABELNO)                              \
+  do {                                                                \
+    if (TARGET_SCORE7)                                                \
+      {                                                               \
+        fprintf (FILE, " .set r1  \n");                               \
+        fprintf (FILE, " mv   r%d,r%d \n", AT_REGNUM, RA_REGNUM);     \
+        fprintf (FILE, " subi r%d, %d \n", STACK_POINTER_REGNUM, 8);  \
+        fprintf (FILE, " jl   _mcount \n");                           \
+        fprintf (FILE, " .set nor1 \n");                              \
+      }                                                               \
+  } while (0)
+
+/* Trampolines for Nested Functions.  */
+#define TRAMPOLINE_INSNS                6
+
+/* A C expression for the size in bytes of the trampoline, as an integer.  */
+#define TRAMPOLINE_SIZE                (24 + GET_MODE_SIZE (ptr_mode) * 2)
+
+#define HAVE_PRE_INCREMENT              1
+#define HAVE_PRE_DECREMENT              1
+#define HAVE_POST_INCREMENT             1
+#define HAVE_POST_DECREMENT             1
+#define HAVE_PRE_MODIFY_DISP            1
+#define HAVE_POST_MODIFY_DISP           1
+#define HAVE_PRE_MODIFY_REG             0
+#define HAVE_POST_MODIFY_REG            0
+
+/* Maximum number of registers that can appear in a valid memory address.  */
+#define MAX_REGS_PER_ADDRESS            1
+
+/* The macros REG_OK_FOR..._P assume that the arg is a REG rtx
+   and check its validity for a certain class.
+   We have two alternate definitions for each of them.
+   The usual definition accepts all pseudo regs; the other rejects them all.
+   The symbol REG_OK_STRICT causes the latter definition to be used.
+
+   Most source files want to accept pseudo regs in the hope that
+   they will get allocated to the class that the insn wants them to be in.
+   Some source files that are used after register allocation
+   need to be strict.  */
+#ifndef REG_OK_STRICT
+#define REG_MODE_OK_FOR_BASE_P(X, MODE) \
+  score_regno_mode_ok_for_base_p (REGNO (X), 0)
+#else
+#define REG_MODE_OK_FOR_BASE_P(X, MODE) \
+  score_regno_mode_ok_for_base_p (REGNO (X), 1)
+#endif
+
+#define REG_OK_FOR_INDEX_P(X) 0
+
+/* Condition Code Status.  */
+#define SELECT_CC_MODE(OP, X, Y)        score_select_cc_mode (OP, X, Y)
+
+/* Return nonzero if SELECT_CC_MODE will never return MODE for a
+   floating point inequality comparison.  */
+#define REVERSIBLE_CC_MODE(MODE)        1
+
+/* Describing Relative Costs of Operations  */
+/* Try to generate sequences that don't involve branches.  */
+#define BRANCH_COST(speed_p, predictable_p) 2
+
+/* Nonzero if access to memory by bytes is slow and undesirable.  */
+#define SLOW_BYTE_ACCESS                1
+
+/* Define this macro if it is as good or better to call a constant
+   function address than to call an address kept in a register.  */
+#define NO_FUNCTION_CSE                 1
+
+/* Dividing the Output into Sections (Texts, Data, ...).  */
+/* Define the strings to put out for each section in the object file.  */
+#define TEXT_SECTION_ASM_OP             "\t.text"
+#define DATA_SECTION_ASM_OP             "\t.data"
+#define SDATA_SECTION_ASM_OP            "\t.sdata"
+
+#undef  READONLY_DATA_SECTION_ASM_OP
+#define READONLY_DATA_SECTION_ASM_OP    "\t.rdata"
+
+/* The Overall Framework of an Assembler File  */
+/* How to start an assembler comment.
+   The leading space is important.  */
+#define ASM_COMMENT_START               "#"
+
+/* Output to assembler file text saying following lines
+   may contain character constants, extra white space, comments, etc.  */
+#define ASM_APP_ON                     "#APP\n\t.set volatile\n"
+
+/* Output to assembler file text saying following lines
+   no longer contain unusual constructs.  */
+#define ASM_APP_OFF                     "#NO_APP\n\t.set optimize\n"
+
+/* Output of Uninitialized Variables.  */
+/* This says how to define a global common symbol.  */
+#define ASM_OUTPUT_ALIGNED_DECL_COMMON(STREAM, DECL, NAME, SIZE, ALIGN)     \
+  do {                                                                      \
+    fputs ("\n\t.comm\t", STREAM);                                          \
+    assemble_name (STREAM, NAME);                                           \
+    fprintf (STREAM, " , " HOST_WIDE_INT_PRINT_UNSIGNED ", %u\n",           \
+             SIZE, ALIGN / BITS_PER_UNIT);                                  \
+  } while (0)
+
+/* This says how to define a local common symbol (i.e., not visible to
+   linker).  */
+#undef ASM_OUTPUT_ALIGNED_LOCAL
+#define ASM_OUTPUT_ALIGNED_LOCAL(STREAM, NAME, SIZE, ALIGN)                 \
+  do {                                                                      \
+    fputs ("\n\t.lcomm\t", STREAM);                                         \
+    assemble_name (STREAM, NAME);                                           \
+    fprintf (STREAM, " , " HOST_WIDE_INT_PRINT_UNSIGNED ", %u\n",           \
+             SIZE, ALIGN / BITS_PER_UNIT);                                  \
+  } while (0)
+
+/* Globalizing directive for a label.  */
+#define GLOBAL_ASM_OP                   "\t.globl\t"
+
+/* Output and Generation of Labels  */
+/* This is how to declare a function name.  The actual work of
+   emitting the label is moved to function_prologue, so that we can
+   get the line number correctly emitted before the .ent directive,
+   and after any .file directives.  Define as empty so that the function
+   is not declared before the .ent directive elsewhere.  */
+#undef ASM_DECLARE_FUNCTION_NAME
+#define ASM_DECLARE_FUNCTION_NAME(FILE, NAME, DECL)
+
+#undef ASM_DECLARE_OBJECT_NAME
+#define ASM_DECLARE_OBJECT_NAME(STREAM, NAME, DECL)   \
+  do {                                                \
+    assemble_name (STREAM, NAME);                     \
+    fprintf (STREAM, ":\n");                          \
+  } while (0)
+
+/* This says how to output an external.  It would be possible not to
+   output anything and let undefined symbol become external. However
+   the assembler uses length information on externals to allocate in
+   data/sdata bss/sbss, thereby saving exec time.  */
+#undef ASM_OUTPUT_EXTERNAL
+#define ASM_OUTPUT_EXTERNAL(STREAM, DECL, NAME) \
+  score_output_external (STREAM, DECL, NAME)
+
+/* This handles the magic '..CURRENT_FUNCTION' symbol, which means
+   'the start of the function that this code is output in'.  */
+#define ASM_OUTPUT_LABELREF(STREAM, NAME) \
+  fprintf ((STREAM), "%s", (NAME))
+
+/* Local compiler-generated symbols must have a prefix that the assembler
+   understands.  */
+#define LOCAL_LABEL_PREFIX              (TARGET_SCORE7 ? "." : "$")
+
+#undef ASM_GENERATE_INTERNAL_LABEL
+#define ASM_GENERATE_INTERNAL_LABEL(LABEL, PREFIX, NUM) \
+  sprintf ((LABEL), "*%s%s%ld", (LOCAL_LABEL_PREFIX), (PREFIX), (long) (NUM))
+
+/* Output of Assembler Instructions.  */
+#define REGISTER_NAMES                                                    \
+{ "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7",                         \
+  "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15",                   \
+  "r16", "r17", "r18", "r19", "r20", "r21", "r22", "r23",                 \
+  "r24", "r25", "r26", "r27", "r28", "r29", "r30", "r31",                 \
+                                                                          \
+  "cr0", "cr1", "cr2", "cr3", "cr4", "cr5", "cr6", "cr7",                 \
+  "cr8", "cr9", "cr10", "cr11", "cr12", "cr13", "cr14", "cr15",           \
+                                                                          \
+  "ceh", "cel", "sr0", "sr1", "sr2", "_arg", "_frame", "",                \
+  "cr24", "cr25", "cr26", "cr27", "cr28", "cr29", "cr30", "cr31",         \
+                                                                          \
+  "c1r0", "c1r1", "c1r2", "c1r3", "c1r4", "c1r5", "c1r6", "c1r7",         \
+  "c1r8", "c1r9", "c1r10", "c1r11", "c1r12", "c1r13", "c1r14", "c1r15",   \
+  "c1r16", "c1r17", "c1r18", "c1r19", "c1r20", "c1r21", "c1r22", "c1r23", \
+  "c1r24", "c1r25", "c1r26", "c1r27", "c1r28", "c1r29", "c1r30", "c1r31", \
+                                                                          \
+  "c2r0", "c2r1", "c2r2", "c2r3", "c2r4", "c2r5", "c2r6", "c2r7",         \
+  "c2r8", "c2r9", "c2r10", "c2r11", "c2r12", "c2r13", "c2r14", "c2r15",   \
+  "c2r16", "c2r17", "c2r18", "c2r19", "c2r20", "c2r21", "c2r22", "c2r23", \
+  "c2r24", "c2r25", "c2r26", "c2r27", "c2r28", "c2r29", "c2r30", "c2r31", \
+                                                                          \
+  "c3r0", "c3r1", "c3r2", "c3r3", "c3r4", "c3r5", "c3r6", "c3r7",         \
+  "c3r8", "c3r9", "c3r10", "c3r11", "c3r12", "c3r13", "c3r14", "c3r15",   \
+  "c3r16", "c3r17", "c3r18", "c3r19", "c3r20", "c3r21", "c3r22", "c3r23", \
+  "c3r24", "c3r25", "c3r26", "c3r27", "c3r28", "c3r29", "c3r30", "c3r31", \
+}
+
+/* Print operand X (an rtx) in assembler syntax to file FILE.  */
+#define PRINT_OPERAND(STREAM, X, CODE)  score_print_operand (STREAM, X, CODE)
+
+/* A C expression which evaluates to true if CODE is a valid
+   punctuation character for use in the `PRINT_OPERAND' macro.  */
+#define PRINT_OPERAND_PUNCT_VALID_P(C)  ((C) == '[' || (C) == ']')
+
+/* Print a memory address as an operand to reference that memory location.  */
+#define PRINT_OPERAND_ADDRESS(STREAM, X) \
+  score_print_operand_address (STREAM, X)
+
+/* By default on the S+core, external symbols do not have an underscore
+   prepended.  */
+#define USER_LABEL_PREFIX        ""
+
+/* This is how to output an insn to push a register on the stack.  */
+#define ASM_OUTPUT_REG_PUSH(STREAM, REGNO)           \
+  do {                                               \
+    if (TARGET_SCORE7)                               \
+        fprintf (STREAM, "\tpush! %s,[%s]\n",        \
+                 reg_names[REGNO],                   \
+                 reg_names[STACK_POINTER_REGNUM]);   \
+  } while (0)
+
+/* This is how to output an insn to pop a register from the stack.  */
+#define ASM_OUTPUT_REG_POP(STREAM, REGNO)            \
+  do {                                               \
+    if (TARGET_SCORE7)                               \
+      fprintf (STREAM, "\tpop! %s,[%s]\n",           \
+               reg_names[REGNO],                     \
+               reg_names[STACK_POINTER_REGNUM]);     \
+  } while (0)
+
+/* Output of Dispatch Tables.  */
+/* This is how to output an element of a case-vector.  We can make the
+   entries PC-relative in GP-relative when .gp(d)word is supported.  */
+#define ASM_OUTPUT_ADDR_DIFF_ELT(STREAM, BODY, VALUE, REL)			\
+  do {										\
+    if (TARGET_SCORE7)								\
+      {										\
+	if (flag_pic)								\
+	  fprintf (STREAM, "\t.gpword %sL%d\n", LOCAL_LABEL_PREFIX, VALUE);	\
+	else									\
+	  fprintf (STREAM, "\t.word %sL%d\n", LOCAL_LABEL_PREFIX, VALUE);	\
+      }										\
+  } while (0)
+
+/* Jump table alignment is explicit in ASM_OUTPUT_CASE_LABEL.  */
+#define ADDR_VEC_ALIGN(JUMPTABLE) (GET_MODE (PATTERN (JUMPTABLE)) == SImode ? 2 \
+                                   : GET_MODE (PATTERN (JUMPTABLE)) == HImode ? 1 : 0)
+
+/* This is how to output a label which precedes a jumptable.  Since
+   Score3 instructions are 2 bytes, we may need explicit alignment here.  */
+#undef  ASM_OUTPUT_CASE_LABEL
+#define ASM_OUTPUT_CASE_LABEL(FILE, PREFIX, NUM, JUMPTABLE)             \
+  do {                                                                  \
+      if ((TARGET_SCORE7) && GET_MODE (PATTERN (JUMPTABLE)) == SImode)  \
+        ASM_OUTPUT_ALIGN (FILE, 2);                                     \
+      (*targetm.asm_out.internal_label) (FILE, PREFIX, NUM);            \
+  } while (0)
+
+/* Specify the machine mode that this machine uses
+   for the index in the tablejump instruction.  */
+#define CASE_VECTOR_MODE                SImode
+
+/* This is how to output an element of a case-vector that is absolute.  */
+#define ASM_OUTPUT_ADDR_VEC_ELT(STREAM, VALUE) \
+  fprintf (STREAM, "\t.word %sL%d\n", LOCAL_LABEL_PREFIX, VALUE)
+
+/* Assembler Commands for Exception Regions  */
+/* Since the S+core is encoded in the least-significant bit
+   of the address, mask it off return addresses for purposes of
+   finding exception handling regions.  */
+#define MASK_RETURN_ADDR               constm1_rtx
+
+/* Assembler Commands for Alignment  */
+/* This is how to output an assembler line to advance the location
+   counter by SIZE bytes.  */
+#undef ASM_OUTPUT_SKIP
+#define ASM_OUTPUT_SKIP(STREAM, SIZE) \
+  fprintf (STREAM, "\t.space\t" HOST_WIDE_INT_PRINT_UNSIGNED "\n", (SIZE))
+
+/* This is how to output an assembler line
+   that says to advance the location counter
+   to a multiple of 2**LOG bytes.  */
+#define ASM_OUTPUT_ALIGN(STREAM, LOG) \
+  fprintf (STREAM, "\t.align\t%d\n", (LOG))
+
+/* Macros Affecting All Debugging Formats.  */
+#ifndef PREFERRED_DEBUGGING_TYPE
+#define PREFERRED_DEBUGGING_TYPE         DWARF2_DEBUG
+#endif
+
+/* Specific Options for DBX Output.  */
+#define DBX_DEBUGGING_INFO              1
+
+/* By default, turn on GDB extensions.  */
+#define DEFAULT_GDB_EXTENSIONS          1
+
+#define DBX_CONTIN_LENGTH               0
+
+/* File Names in DBX Format.  */
+#define DWARF2_DEBUGGING_INFO           1
+
+/* The DWARF 2 CFA column which tracks the return address.  */
+#define DWARF_FRAME_RETURN_COLUMN       3
+
+/* Define if operations between registers always perform the operation
+   on the full register even if a narrower mode is specified.  */
+#define WORD_REGISTER_OPERATIONS		1
+
+/*  All references are zero extended.  */
+#define LOAD_EXTEND_OP(MODE)            ZERO_EXTEND
+
+/* Define if loading short immediate values into registers sign extends.  */
+#define SHORT_IMMEDIATES_SIGN_EXTEND	1
+
+/* Max number of bytes we can move from memory to memory
+   in one reasonably fast instruction.  */
+#define MOVE_MAX                        4
+
+/* Define this to be nonzero if shift instructions ignore all but the low-order
+   few bits.  */
+#define SHIFT_COUNT_TRUNCATED           1
+
+/* Specify the machine mode that pointers have.
+   After generation of rtl, the compiler makes no further distinction
+   between pointers and any other objects of this machine mode.  */
+#define Pmode                           SImode
+
+/* Give call MEMs SImode since it is the "most permissive" mode
+   for 32-bit targets.  */
+#define FUNCTION_MODE                   Pmode
diff --git a/gcc/config/score/score.md b/gcc/config/score/score.md
new file mode 100644
index 000000000..f13d76902
--- /dev/null
+++ b/gcc/config/score/score.md
@@ -0,0 +1,1879 @@
+;;  Machine description for Sunplus S+CORE
+;;  Copyright (C) 2005-2014 Free Software Foundation, Inc.
+;;  Contributed by Sunnorth.
+
+;; This file is part of GCC.
+
+;; GCC is free software; you can redistribute it and/or modify
+;; it under the terms of the GNU General Public License as published by
+;; the Free Software Foundation; either version 3, or (at your option)
+;; any later version.
+
+;; GCC is distributed in the hope that it will be useful,
+;; but WITHOUT ANY WARRANTY; without even the implied warranty of
+;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+;; GNU General Public License for more details.
+
+;; You should have received a copy of the GNU General Public License
+;; along with GCC; see the file COPYING3.  If not see
+;; <http://www.gnu.org/licenses/>.
+
+;;- See file "rtl.def" for documentation on define_insn, match_*, et. al.
+
+; branch        conditional branch
+; jump          unconditional jump
+; call          unconditional call
+; load          load instruction(s)
+; store         store instruction(s)
+; cmp           integer compare
+; arith         integer arithmetic instruction
+; move          data movement within same register set
+; const         load constant
+; nop           no operation
+; mul           integer multiply
+; div           integer divide
+; cndmv         conditional moves
+; fce           transfer from hi/lo registers
+; tce           transfer to   hi/lo registers
+; fsr           transfer from special registers
+; tsr           transfer to   special registers
+
+(define_constants
+  [(CC_REGNUM       33)
+   (T_REGNUM        34)
+   (RA_REGNUM       3)
+   (SP_REGNUM       0)
+   (AT_REGNUM       1)
+   (FP_REGNUM       2)
+   (RT_REGNUM       4)
+   (GP_REGNUM       28)
+   (EH_REGNUM       29)
+   (HI_REGNUM       48)
+   (LO_REGNUM       49)
+   (CN_REGNUM       50)
+   (LC_REGNUM       51)
+   (SC_REGNUM       52)])
+
+(define_constants
+   [(BITTST         0)
+    (CPLOAD         1)
+    (CPRESTORE      2)
+
+    (SCB            3)
+    (SCW            4)
+    (SCE            5)
+    (SCLC           6)
+
+    (LCB            7)
+    (LCW            8)
+    (LCE            9)
+
+    (SFFS           10)])
+
+(define_attr "type"
+  "unknown,branch,jump,call,load,store,cmp,arith,move,const,nop,mul,div,cndmv,fce,tce,fsr,tsr,fcr,tcr"
+  (const_string "unknown"))
+
+(define_attr "mode" "unknown,QI,HI,SI,DI"
+  (const_string "unknown"))
+
+(define_attr "length" "" (const_int 4))
+
+(define_attr "up_c" "yes,no"
+  (const_string "no"))
+
+(include "constraints.md")
+(include "score-generic.md")
+(include "predicates.md")
+
+(define_expand "movqi"
+  [(set (match_operand:QI 0 "nonimmediate_operand")
+        (match_operand:QI 1 "general_operand"))]
+  ""
+{
+  if (MEM_P (operands[0])
+      && !register_operand (operands[1], QImode))
+    {
+      operands[1] = force_reg (QImode, operands[1]);
+    }
+})
+
+(define_insn "*movqi_insns_score7"
+  [(set (match_operand:QI 0 "nonimmediate_operand" "=d,d,d,m,d,*x,d,*a")
+        (match_operand:QI 1 "general_operand" "i,d,m,d,*x,d,*a,d"))]
+  "(!MEM_P (operands[0]) || register_operand (operands[1], QImode))
+   && (TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return score_limm (operands);
+    case 1: return score_move (operands);
+    case 2: return score_linsn (operands, SCORE_BYTE, false);
+    case 3: return score_sinsn (operands, SCORE_BYTE);
+    case 4: return TARGET_SCORE7D ? \"mf%1%S0 %0\" : \"mf%1    %0\";
+    case 5: return TARGET_SCORE7D ? \"mt%0%S1 %1\" : \"mt%0    %1\";
+    case 6: return \"mfsr\t%0, %1\";
+    case 7: return \"mtsr\t%1, %0\";
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith,move,load,store,fce,tce,fsr,tsr")
+   (set_attr "mode" "QI")])
+
+(define_expand "movhi"
+  [(set (match_operand:HI 0 "nonimmediate_operand")
+        (match_operand:HI 1 "general_operand"))]
+  ""
+{
+  if (MEM_P (operands[0])
+      && !register_operand (operands[1], HImode))
+    {
+      operands[1] = force_reg (HImode, operands[1]);
+    }
+})
+
+(define_insn "*movhi_insns_score7"
+  [(set (match_operand:HI 0 "nonimmediate_operand" "=d,d,d,m,d,*x,d,*a")
+        (match_operand:HI 1 "general_operand" "i,d,m,d,*x,d,*a,d"))]
+  "(!MEM_P (operands[0]) || register_operand (operands[1], HImode))
+   && (TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return score_limm (operands);
+    case 1: return score_move (operands);
+    case 2: return score_linsn (operands, SCORE_HWORD, false);
+    case 3: return score_sinsn (operands, SCORE_HWORD);
+    case 4: return TARGET_SCORE7D ? \"mf%1%S0 %0\" : \"mf%1    %0\";
+    case 5: return TARGET_SCORE7D ? \"mt%0%S1 %1\" : \"mt%0    %1\";
+    case 6: return \"mfsr\t%0, %1\";
+    case 7: return \"mtsr\t%1, %0\";
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith,move,load,store,fce,tce,fsr,tsr")
+   (set_attr "mode" "HI")])
+
+(define_expand "movsi"
+  [(set (match_operand:SI 0 "nonimmediate_operand")
+        (match_operand:SI 1 "general_operand"))]
+  ""
+{
+  if (MEM_P (operands[0])
+      && !register_operand (operands[1], SImode))
+    {
+      operands[1] = force_reg (SImode, operands[1]);
+    }
+})
+
+(define_insn "*movsi_insns_score7"
+  [(set (match_operand:SI 0 "nonimmediate_operand" "=d,d,d,m,d,*x,d,*a,d,*c")
+        (match_operand:SI 1 "general_operand" "i,d,m,d,*x,d,*a,d,*c,d"))]
+  "(!MEM_P (operands[0]) || register_operand (operands[1], SImode))
+   && (TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0:
+      if (GET_CODE (operands[1]) != CONST_INT)
+        return \"la\t%0, %1\";
+      else
+        return score_limm (operands);
+    case 1: return score_move (operands);
+    case 2: return score_linsn (operands, SCORE_WORD, false);
+    case 3: return score_sinsn (operands, SCORE_WORD);
+    case 4: return TARGET_SCORE7D ? \"mf%1%S0 %0\" : \"mf%1    %0\";
+    case 5: return TARGET_SCORE7D ? \"mt%0%S1 %1\" : \"mt%0    %1\";
+    case 6: return \"mfsr\t%0, %1\";
+    case 7: return \"mtsr\t%1, %0\";
+    case 8: return \"mfcr\t%0, %1\";
+    case 9: return \"mtcr\t%1, %0\";
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith,move,load,store,fce,tce,fsr,tsr,fcr,tcr")
+   (set_attr "mode" "SI")])
+
+(define_insn_and_split "movdi"
+  [(set (match_operand:DI 0 "nonimmediate_operand" "=d,d,d,m,d,*x")
+        (match_operand:DI 1 "general_operand" "i,d,m,d,*x,d"))]
+  ""
+  "#"
+  "reload_completed"
+  [(const_int 0)]
+{
+  score_movdi (operands);
+  DONE;
+})
+
+(define_expand "movsf"
+  [(set (match_operand:SF 0 "nonimmediate_operand")
+        (match_operand:SF 1 "general_operand"))]
+  ""
+{
+  if (MEM_P (operands[0])
+      && !register_operand (operands[1], SFmode))
+    {
+      operands[1] = force_reg (SFmode, operands[1]);
+    }
+})
+
+(define_insn "*movsf_insns_score7"
+  [(set (match_operand:SF 0 "nonimmediate_operand" "=d,d,d,m")
+        (match_operand:SF 1 "general_operand" "i,d,m,d"))]
+  "(!MEM_P (operands[0]) || register_operand (operands[1], SFmode))
+   && (TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"li\t%0, %D1\";;
+    case 1: return score_move (operands);
+    case 2: return score_linsn (operands, SCORE_WORD, false);
+    case 3: return score_sinsn (operands, SCORE_WORD);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith,move,load,store")
+   (set_attr "mode" "SI")])
+
+(define_insn_and_split "movdf"
+  [(set (match_operand:DF 0 "nonimmediate_operand" "=d,d,d,m")
+        (match_operand:DF 1 "general_operand" "i,d,m,d"))]
+  ""
+  "#"
+  "reload_completed"
+  [(const_int 0)]
+{
+  score_movdi (operands);
+  DONE;
+})
+
+(define_expand "addsi3"
+  [(set (match_operand:SI 0 "score_register_operand" )
+        (plus:SI (match_operand:SI 1 "score_register_operand")
+                 (match_operand:SI 2 "arith_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*addsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d,d,d")
+        (plus:SI (match_operand:SI 1 "register_operand" "0,0,d,d")
+                 (match_operand:SI 2 "arith_operand" "I,L,N,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"addis\t%0, %U2\";
+    case 1: return score_select_add_imm (operands, false);
+    case 2: return \"addri\t%0, %1, %c2\";
+    case 3: return score_select (operands, "add", true, "", false);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*addsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (plus:SI
+                        (match_operand:SI 1 "register_operand" "0,0,d,d")
+                        (match_operand:SI 2 "arith_operand" "I,L,N,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d,d,d,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"addis.c\t%0, %U2\";
+    case 1: return score_select_add_imm (operands, true);
+    case 2: return \"addri.c\t%0, %1, %c2\";
+    case 3: return score_select (operands, "add", true, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*addsi3_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (plus:SI
+                        (match_operand:SI 1 "register_operand" "0,0,d,d")
+                        (match_operand:SI 2 "arith_operand" "I,L,N,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d,d,d,d")
+        (plus:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"addis.c\t%0, %U2\";
+    case 1: return score_select_add_imm (operands, true);
+    case 2: return \"addri.c\t%0, %1, %c2\";
+    case 3: return score_select (operands, "add", true, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "adddi3"
+  [(parallel
+    [(set (match_operand:DI 0 "score_register_operand")
+          (plus:DI (match_operand:DI 1 "score_register_operand")
+                   (match_operand:DI 2 "score_register_operand")))
+    (clobber (reg:CC CC_REGNUM))])]
+  ""
+  ""
+)
+
+(define_insn "*adddi3_score7"
+  [(set (match_operand:DI 0 "register_operand" "=e,d")
+        (plus:DI (match_operand:DI 1 "register_operand" "0,d")
+                 (match_operand:DI 2 "register_operand" "e,d")))
+  (clobber (reg:CC CC_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   add!    %L0, %L2\;addc!   %H0, %H2
+   add.c   %L0, %L1, %L2\;addc    %H0, %H1, %H2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "DI")])
+
+(define_expand "subsi3"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (minus:SI (match_operand:SI 1 "score_register_operand")
+                  (match_operand:SI 2 "score_register_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*subsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (minus:SI (match_operand:SI 1 "register_operand" "d")
+                  (match_operand:SI 2 "register_operand" "d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  return score_select (operands, "sub", false, "", false);
+}
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*subsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (minus:SI (match_operand:SI 1 "register_operand" "d")
+                                 (match_operand:SI 2 "register_operand" "d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  return score_select (operands, "sub", false, "", true);
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_peephole2
+  [(set (match_operand:SI 0 "g32reg_operand" "")
+        (minus:SI (match_operand:SI 1 "g32reg_operand" "")
+                  (match_operand:SI 2 "g32reg_operand" "")))
+   (set (reg:CC CC_REGNUM)
+        (compare:CC (match_dup 1) (match_dup 2)))]
+  ""
+  [(set (reg:CC CC_REGNUM)
+        (compare:CC (match_dup 1) (match_dup 2)))
+   (set (match_dup 0)
+        (minus:SI (match_dup 1) (match_dup 2)))])
+
+(define_insn "subsi3_ucc_pcmp"
+  [(parallel
+    [(set (reg:CC CC_REGNUM)
+          (compare:CC (match_operand:SI 1 "score_register_operand" "d")
+                      (match_operand:SI 2 "score_register_operand" "d")))
+     (set (match_operand:SI 0 "score_register_operand" "=d")
+          (minus:SI (match_dup 1) (match_dup 2)))])]
+  ""
+{
+  return score_select (operands, "sub", false, "", true);
+}
+  [(set_attr "type" "arith")
+   (set_attr "length" "4")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "subsi3_ucc"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (minus:SI (match_operand:SI 1 "score_register_operand" "d")
+                                 (match_operand:SI 2 "score_register_operand" "d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "score_register_operand" "=d")
+        (minus:SI (match_dup 1) (match_dup 2)))]
+  ""
+{
+  return score_select (operands, "sub", false, "", true);
+}
+  [(set_attr "type" "arith")
+   (set_attr "length" "4")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "subdi3"
+  [(parallel
+    [(set (match_operand:DI 0 "score_register_operand")
+          (minus:DI (match_operand:DI 1 "score_register_operand")
+                    (match_operand:DI 2 "score_register_operand")))
+     (clobber (reg:CC CC_REGNUM))])]
+  ""
+  ""
+)
+
+(define_insn "*subdi3_score7"
+  [(set (match_operand:DI 0 "register_operand" "=e,d")
+        (minus:DI (match_operand:DI 1 "register_operand" "0,d")
+                  (match_operand:DI 2 "register_operand" "e,d")))
+   (clobber (reg:CC CC_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   sub!    %L0, %L2\;subc    %H0, %H1, %H2
+   sub.c   %L0, %L1, %L2\;subc    %H0, %H1, %H2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "DI")])
+
+(define_expand "andsi3"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (and:SI (match_operand:SI 1 "score_register_operand")
+                (match_operand:SI 2 "arith_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*andsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d,d,d")
+        (and:SI (match_operand:SI 1 "register_operand" "0,0,d,d")
+                (match_operand:SI 2 "arith_operand" "I,K,M,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"andis\t%0, %U2\";
+    case 1: return \"andi\t%0, %c2";
+    case 2: return \"andri\t%0, %1, %c2\";
+    case 3: return score_select (operands, "and", true, "", false);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "andsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (and:SI (match_operand:SI 1 "register_operand" "0,0,0,d")
+                               (match_operand:SI 2 "arith_operand" "I,K,M,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d,d,d,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"andis.c\t%0, %U2\";
+    case 1: return \"andi.c\t%0, %c2";
+    case 2: return \"andri.c\t%0, %1, %c2\";
+    case 3: return score_select (operands, "and", true, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*andsi3_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (and:SI
+                        (match_operand:SI 1 "register_operand" "0,0,d,d")
+                        (match_operand:SI 2 "arith_operand" "I,K,M,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d,d,d,d")
+        (and:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"andis.c\t%0, %U2\";
+    case 1: return \"andi.c\t%0, %c2";
+    case 2: return \"andri.c\t%0, %1, %c2\";
+    case 3: return score_select (operands, "and", true, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn_and_split "*zero_extract_andi"
+  [(set (reg:CC CC_REGNUM)
+        (compare:CC (zero_extract:SI
+                     (match_operand:SI 0 "score_register_operand" "d")
+                     (match_operand:SI 1 "const_uimm5" "")
+                     (match_operand:SI 2 "const_uimm5" ""))
+                    (const_int 0)))]
+  ""
+  "#"
+  ""
+  [(const_int 1)]
+{
+  score_zero_extract_andi (operands);
+  DONE;
+})
+
+(define_expand "iorsi3"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (ior:SI (match_operand:SI 1 "score_register_operand")
+                (match_operand:SI 2 "arith_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*iorsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d,d,d")
+        (ior:SI (match_operand:SI 1 "register_operand" "0,0,d,d")
+                (match_operand:SI 2 "arith_operand" "I,K,M,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"oris\t%0, %U2\";
+    case 1: return \"ori\t%0, %c2\";
+    case 2: return \"orri\t%0, %1, %c2\";
+    case 3: return score_select (operands, "or", true, "", false);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*iorsi3_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (ior:SI
+                        (match_operand:SI 1 "register_operand" "0,0,d,d")
+                        (match_operand:SI 2 "arith_operand" "I,K,M,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d,d,d,d")
+        (ior:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"oris.c\t%0, %U2\";
+    case 1: return \"ori.c\t%0, %c2\";
+    case 2: return \"orri.c\t%0, %1, %c2\";
+    case 3: return score_select (operands, "or", true, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*iorsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (ior:SI
+                        (match_operand:SI 1 "register_operand" "0,0,d,d")
+                        (match_operand:SI 2 "arith_operand" "I,K,M,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d,d,d,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"oris.c\t%0, %U2\";
+    case 1: return \"ori.c\t%0, %c2\";
+    case 2: return \"orri.c\t%0, %1, %c2\";
+    case 3: return score_select (operands, "or", true, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "xorsi3"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (xor:SI (match_operand:SI 1 "score_register_operand")
+                (match_operand:SI 2 "score_register_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*xorsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (xor:SI (match_operand:SI 1 "register_operand" "d")
+                (match_operand:SI 2 "register_operand" "d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  return score_select (operands, "xor", true, "", false);
+}
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*xorsi3_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (xor:SI (match_operand:SI 1 "register_operand" "d")
+                               (match_operand:SI 2 "register_operand" "d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d")
+        (xor:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  return score_select (operands, "xor", true, "", true);
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*xorsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (xor:SI (match_operand:SI 1 "register_operand" "d")
+                               (match_operand:SI 2 "register_operand" "d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d"))]
+  ""
+{
+  return score_select (operands, "xor", true, "", true);
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "extendqisi2"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (sign_extend:SI (match_operand:QI 1 "nonimmediate_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*extendqisi2_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (sign_extend:SI (match_operand:QI 1 "nonimmediate_operand" "d,m")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"extsb\t%0, %1\";
+    case 1: return score_linsn (operands, SCORE_BYTE, true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith,load")
+   (set_attr "mode" "SI")])
+
+(define_insn "*extendqisi2_ucc_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (ashiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 24))
+                       (const_int 24))
+                      (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d")
+        (sign_extend:SI (match_operand:QI 2 "register_operand" "0")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extsb.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*extendqisi2_cmp_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (ashiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 24))
+                       (const_int 24))
+                      (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extsb.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "extendhisi2"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (sign_extend:SI (match_operand:HI 1 "nonimmediate_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*extendhisi2_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (sign_extend:SI (match_operand:HI 1 "nonimmediate_operand" "d,m")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"extsh\t%0, %1\";
+    case 1: return score_linsn (operands, SCORE_HWORD, true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith, load")
+   (set_attr "mode" "SI")])
+
+(define_insn "*extendhisi2_ucc_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (ashiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 16))
+                       (const_int 16))
+                      (const_int 0)))
+  (set (match_operand:SI 0 "register_operand" "=d")
+       (sign_extend:SI (match_operand:HI 2 "register_operand" "0")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extsh.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*extendhisi2_cmp_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (ashiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 16))
+                       (const_int 16))
+                      (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extsh.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "zero_extendqisi2"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (zero_extend:SI (match_operand:QI 1 "nonimmediate_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*zero_extendqisi2_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (zero_extend:SI (match_operand:QI 1 "nonimmediate_operand" "d,m")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"extzb\t%0, %1\";
+    case 1: return score_linsn (operands, SCORE_BYTE, false);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith, load")
+   (set_attr "mode" "SI")])
+
+(define_insn "*zero_extendqisi2_ucc_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (lshiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 24))
+                       (const_int 24))
+                      (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d")
+        (zero_extend:SI (match_operand:QI 2 "register_operand" "0")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extzb.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*zero_extendqisi2_cmp_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (lshiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 24))
+                       (const_int 24))
+                      (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extzb.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "zero_extendhisi2"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (zero_extend:SI (match_operand:HI 1 "nonimmediate_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*zero_extendhisi2_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (zero_extend:SI (match_operand:HI 1 "nonimmediate_operand" "d,m")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"extzh\t%0, %1\";
+    case 1: return score_linsn (operands, SCORE_HWORD, false);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith, load")
+   (set_attr "mode" "SI")])
+
+(define_insn "*zero_extendhisi2_ucc_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (lshiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 16))
+                       (const_int 16))
+                      (const_int 0)))
+  (set (match_operand:SI 0 "register_operand" "=d")
+       (zero_extend:SI (match_operand:HI 2 "register_operand" "0")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extzh.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*zero_extendhisi2_cmp_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (lshiftrt:SI
+                       (ashift:SI (match_operand:SI 1 "register_operand" "d")
+                                  (const_int 16))
+                       (const_int 16))
+                      (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "extzh.c %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "mulsi3"
+    [(set (match_operand:SI 0 "score_register_operand")
+          (mult:SI (match_operand:SI 1 "score_register_operand")
+                   (match_operand:SI 2 "score_register_operand")))]
+  ""
+{
+  if (TARGET_SCORE7 || TARGET_SCORE7D)
+    emit_insn (gen_mulsi3_score7 (operands[0], operands[1], operands[2]));
+  DONE;
+})
+
+(define_insn "mulsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=l")
+        (mult:SI (match_operand:SI 1 "register_operand" "d")
+                 (match_operand:SI 2 "register_operand" "d")))
+   (clobber (reg:SI HI_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "mul     %1, %2"
+  [(set_attr "type" "mul")
+   (set_attr "mode" "SI")])
+
+(define_expand "mulsidi3"
+    [(set (match_operand:DI 0 "score_register_operand")
+          (mult:DI (sign_extend:DI
+                    (match_operand:SI 1 "score_register_operand"))
+                   (sign_extend:DI
+                    (match_operand:SI 2 "score_register_operand"))))]
+  ""
+{
+  if (TARGET_SCORE7 || TARGET_SCORE7D)
+    emit_insn (gen_mulsidi3_score7 (operands[0], operands[1], operands[2]));
+  DONE;
+})
+
+(define_insn "mulsidi3_score7"
+  [(set (match_operand:DI 0 "register_operand" "=x")
+        (mult:DI (sign_extend:DI
+                  (match_operand:SI 1 "register_operand" "d"))
+                 (sign_extend:DI
+                  (match_operand:SI 2 "register_operand" "d"))))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "mul     %1, %2"
+  [(set_attr "type" "mul")
+   (set_attr "mode" "DI")])
+
+(define_expand "umulsidi3"
+  [(set (match_operand:DI 0 "score_register_operand")
+        (mult:DI (zero_extend:DI
+                  (match_operand:SI 1 "score_register_operand"))
+                 (zero_extend:DI
+                  (match_operand:SI 2 "score_register_operand"))))]
+  ""
+{
+  if (TARGET_SCORE7 || TARGET_SCORE7D)
+    emit_insn (gen_umulsidi3_score7 (operands[0], operands[1], operands[2]));
+  DONE;
+})
+
+(define_insn "umulsidi3_score7"
+  [(set (match_operand:DI 0 "register_operand" "=x")
+        (mult:DI (zero_extend:DI
+                  (match_operand:SI 1 "register_operand" "d"))
+                 (zero_extend:DI
+                  (match_operand:SI 2 "register_operand" "d"))))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "mulu    %1, %2"
+  [(set_attr "type" "mul")
+   (set_attr "mode" "DI")])
+
+(define_expand "divmodsi4"
+  [(parallel
+    [(set (match_operand:SI 0 "score_register_operand")
+          (div:SI (match_operand:SI 1 "score_register_operand")
+                  (match_operand:SI 2 "score_register_operand")))
+     (set (match_operand:SI 3 "score_register_operand")
+          (mod:SI (match_dup 1) (match_dup 2)))])]
+  ""
+  ""
+)
+
+(define_insn "*divmodsi4_score7"
+  [(set (match_operand:SI 0 "register_operand" "=l")
+        (div:SI (match_operand:SI 1 "register_operand" "d")
+                (match_operand:SI 2 "register_operand" "d")))
+   (set (match_operand:SI 3 "register_operand" "=h")
+        (mod:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "div     %1, %2"
+  [(set_attr "type" "div")
+   (set_attr "mode" "SI")])
+
+(define_expand "udivmodsi4"
+  [(parallel
+    [(set (match_operand:SI 0 "score_register_operand")
+          (udiv:SI (match_operand:SI 1 "score_register_operand")
+                   (match_operand:SI 2 "score_register_operand")))
+     (set (match_operand:SI 3 "score_register_operand")
+          (umod:SI (match_dup 1) (match_dup 2)))])]
+  ""
+  ""
+)
+
+(define_insn "*udivmodsi4_score7"
+  [(set (match_operand:SI 0 "register_operand" "=l")
+        (udiv:SI (match_operand:SI 1 "register_operand" "d")
+                 (match_operand:SI 2 "register_operand" "d")))
+   (set (match_operand:SI 3 "register_operand" "=h")
+        (umod:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "divu    %1, %2"
+  [(set_attr "type" "div")
+   (set_attr "mode" "SI")])
+
+(define_expand "ashlsi3"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (ashift:SI (match_operand:SI 1 "score_register_operand")
+                   (match_operand:SI 2 "arith_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*ashlsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (ashift:SI (match_operand:SI 1 "register_operand" "d,d")
+                   (match_operand:SI 2 "arith_operand" "J,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   slli    %0, %1, %c2
+   sll     %0, %1, %2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*ashlsi3_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (ashift:SI
+                        (match_operand:SI 1 "register_operand" "d,d")
+                        (match_operand:SI 2 "arith_operand" "J,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d,d")
+        (ashift:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return score_select (operands, "slli", false, "c", true);
+    case 1: return score_select (operands, "sll", false, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*ashlsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (ashift:SI
+                        (match_operand:SI 1 "register_operand" "d,d")
+                        (match_operand:SI 2 "arith_operand" "J,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return score_select (operands, "slli", false, "c", true);
+    case 1: return score_select (operands, "sll", false, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "ashrsi3"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (ashiftrt:SI (match_operand:SI 1 "score_register_operand")
+                     (match_operand:SI 2 "arith_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*ashrsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (ashiftrt:SI (match_operand:SI 1 "register_operand" "d,d")
+                     (match_operand:SI 2 "arith_operand" "J,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   srai    %0, %1, %c2
+   sra     %0, %1, %2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*ashrsi3_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (ashiftrt:SI
+                        (match_operand:SI 1 "register_operand" "d,d")
+                        (match_operand:SI 2 "arith_operand" "J,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d,d")
+        (ashiftrt:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"srai.c\t%0, %1, %c2\";
+    case 1: return score_select (operands, "sra", false, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*ashrsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (ashiftrt:SI
+                        (match_operand:SI 1 "register_operand" "d,d")
+                        (match_operand:SI 2 "arith_operand" "J,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return \"srai.c\t%0, %1, %c2\";
+    case 1: return score_select (operands, "sra", false, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "lshrsi3"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (lshiftrt:SI (match_operand:SI 1 "score_register_operand")
+                     (match_operand:SI 2 "arith_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*lshrsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (lshiftrt:SI (match_operand:SI 1 "register_operand" "d,d")
+                     (match_operand:SI 2 "arith_operand" "J,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   srli    %0, %1, %c2
+   srl     %0, %1, %2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*lshrsi3_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (lshiftrt:SI
+                        (match_operand:SI 1 "register_operand" "d,d")
+                        (match_operand:SI 2 "arith_operand" "J,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=d,d")
+        (lshiftrt:SI (match_dup 1) (match_dup 2)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return score_select (operands, "srli", false, "c", true);
+    case 1: return score_select (operands, "srl", false, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*lshrsi3_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (lshiftrt:SI
+                        (match_operand:SI 1 "register_operand" "d,d")
+                        (match_operand:SI 2 "arith_operand" "J,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=d,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  switch (which_alternative)
+    {
+    case 0: return score_select (operands, "srli", false, "c", true);
+    case 1: return score_select (operands, "srl", false, "", true);
+    default: gcc_unreachable ();
+    }
+}
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "negsi2"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (neg:SI (match_operand:SI 1 "score_register_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*negsi2_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (neg:SI (match_operand:SI 1 "register_operand" "d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "neg     %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*negsi2_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (neg:SI (match_operand:SI 1 "register_operand" "e,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=e,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   neg!    %0, %1
+   neg.c   %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*negsi2_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (neg:SI (match_operand:SI 1 "register_operand" "e,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=e,d")
+        (neg:SI (match_dup 1)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   neg!    %0, %1
+   neg.c   %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "one_cmplsi2"
+  [(set (match_operand:SI 0 "score_register_operand")
+        (not:SI (match_operand:SI 1 "score_register_operand")))]
+  ""
+  ""
+)
+
+(define_insn "*one_cmplsi2_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (not:SI (match_operand:SI 1 "register_operand" "d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "not\t%0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "*one_cmplsi2_ucc_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (not:SI (match_operand:SI 1 "register_operand" "e,d"))
+                       (const_int 0)))
+   (set (match_operand:SI 0 "register_operand" "=e,d")
+        (not:SI (match_dup 1)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   not!    %0, %1
+   not.c   %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*one_cmplsi2_cmp_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (not:SI (match_operand:SI 1 "register_operand" "e,d"))
+                       (const_int 0)))
+   (clobber (match_scratch:SI 0 "=e,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   not!    %0, %1
+   not.c   %0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_expand "rotlsi3"
+  [(parallel
+    [(set (match_operand:SI 0 "score_register_operand")
+          (rotate:SI (match_operand:SI 1 "score_register_operand")
+                     (match_operand:SI 2 "arith_operand")))
+     (clobber (reg:CC CC_REGNUM))])]
+  ""
+  ""
+)
+
+(define_insn "*rotlsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (rotate:SI (match_operand:SI 1 "register_operand" "d,d")
+                   (match_operand:SI 2 "arith_operand" "J,d")))
+   (clobber (reg:CC CC_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   roli.c  %0, %1, %c2
+   rol.c   %0, %1, %2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_expand "rotrsi3"
+  [(parallel
+    [(set (match_operand:SI 0 "score_register_operand")
+          (rotatert:SI (match_operand:SI 1 "score_register_operand")
+                       (match_operand:SI 2 "arith_operand")))
+     (clobber (reg:CC CC_REGNUM))])]
+  ""
+  ""
+)
+
+(define_insn "*rotrsi3_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d,d")
+        (rotatert:SI (match_operand:SI 1 "register_operand" "d,d")
+                     (match_operand:SI 2 "arith_operand" "J,d")))
+   (clobber (reg:CC CC_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   rori.c  %0, %1, %c2
+   ror.c   %0, %1, %2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_expand "cbranchsi4"
+  [(set (reg:CC CC_REGNUM)
+        (compare:CC (match_operand:SI 1 "score_register_operand" "")
+                    (match_operand:SI 2 "arith_operand" "")))
+   (set (pc)
+        (if_then_else
+	 (match_operator 0 "ordered_comparison_operator"
+			 [(reg:CC CC_REGNUM)
+		 	  (const_int 0)])
+         (label_ref (match_operand 3 "" ""))
+         (pc)))]
+  ""
+  "")
+
+(define_insn "cmpsi_nz_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (match_operand:SI 0 "register_operand" "d,e,d")
+                       (match_operand:SI 1 "arith_operand" "L,e,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   cmpi.c  %0, %c1
+   cmp!    %0, %1
+   cmp.c   %0, %1"
+   [(set_attr "type" "cmp")
+    (set_attr "up_c" "yes")
+    (set_attr "mode" "SI")])
+
+(define_insn "cmpsi_n_score7"
+  [(set (reg:CC_N CC_REGNUM)
+        (compare:CC_N (match_operand:SI 0 "register_operand" "d,e,d")
+                      (match_operand:SI 1 "arith_operand" "L,e,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   cmpi.c  %0, %c1
+   cmp!    %0, %1
+   cmp.c   %0, %1"
+   [(set_attr "type" "cmp")
+    (set_attr "up_c" "yes")
+    (set_attr "mode" "SI")])
+
+(define_insn "*cmpsi_to_addsi_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (match_operand:SI 1 "register_operand" "0,d")
+                       (neg:SI (match_operand:SI 2 "register_operand" "e,d"))))
+   (clobber (match_scratch:SI 0 "=e,d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   add!    %0, %2
+   add.c   %0, %1, %2"
+   [(set_attr "type" "cmp")
+    (set_attr "up_c" "yes")
+    (set_attr "mode" "SI")])
+
+(define_insn "cmpsi_cc_score7"
+  [(set (reg:CC CC_REGNUM)
+        (compare:CC (match_operand:SI 0 "register_operand" "d,e,d")
+                    (match_operand:SI 1 "arith_operand" "L,e,d")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   cmpi.c  %0, %c1
+   cmp!    %0, %1
+   cmp.c   %0, %1"
+  [(set_attr "type" "cmp")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "*branch_n_score7"
+  [(set (pc)
+        (if_then_else
+         (match_operator 0 "branch_n_operator"
+                         [(reg:CC_N CC_REGNUM)
+                          (const_int 0)])
+         (label_ref (match_operand 1 "" ""))
+         (pc)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "b%C0    %1"
+  [(set_attr "type" "branch")])
+
+(define_insn "*branch_nz_score7"
+  [(set (pc)
+        (if_then_else
+         (match_operator 0 "branch_nz_operator"
+                         [(reg:CC_NZ CC_REGNUM)
+                          (const_int 0)])
+         (label_ref (match_operand 1 "" ""))
+         (pc)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "b%C0    %1"
+  [(set_attr "type" "branch")])
+
+(define_insn "*branch_cc_score7"
+  [(set (pc)
+        (if_then_else
+         (match_operator 0 "comparison_operator"
+                         [(reg:CC CC_REGNUM)
+                          (const_int 0)])
+         (label_ref (match_operand 1 "" ""))
+         (pc)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "b%C0    %1"
+  [(set_attr "type" "branch")])
+
+(define_insn "jump"
+  [(set (pc)
+        (label_ref (match_operand 0 "" "")))]
+  ""
+{
+  if (!flag_pic)
+    return \"j\t%0\";
+  else
+    return \"b\t%0\";
+}
+  [(set_attr "type" "jump")
+   (set_attr "length" "4")])
+
+(define_expand "sibcall"
+  [(parallel [(call (match_operand 0 "" "")
+                    (match_operand 1 "" ""))
+              (use (match_operand 2 "" ""))])]
+  ""
+{
+  score_call (operands, true);
+  DONE;
+})
+
+(define_insn "sibcall_internal_score7"
+  [(call (mem:SI (match_operand:SI 0 "call_insn_operand" "t,Z"))
+         (match_operand 1 "" ""))
+   (clobber (reg:SI RT_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)
+   && SIBLING_CALL_P (insn)"
+{
+  if (!flag_pic)
+    switch (which_alternative)
+      {
+      case 0: return \"br%S0\t%0\";
+      case 1: return \"j\t%0\";
+      default: gcc_unreachable ();
+      }
+  else
+    switch (which_alternative)
+      {
+      case 0: return \"mv\tr29, %0\;br\tr29\";
+      case 1: return \"la\tr29, %0\;br\tr29\";
+      default: gcc_unreachable ();
+      }
+}
+  [(set_attr "type" "call")])
+
+(define_expand "sibcall_value"
+  [(parallel [(set (match_operand 0 "" "")
+              (call (match_operand 1 "" "") (match_operand 2 "" "")))
+              (use (match_operand 3 "" ""))])]
+  ""
+{
+  score_call_value (operands, true);
+  DONE;
+})
+
+(define_insn "sibcall_value_internal_score7"
+  [(set (match_operand 0 "register_operand" "=d,d")
+        (call (mem:SI (match_operand:SI 1 "call_insn_operand" "t,Z"))
+              (match_operand 2 "" "")))
+   (clobber (reg:SI RT_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)
+   && SIBLING_CALL_P (insn)"
+{
+  if (!flag_pic)
+    switch (which_alternative)
+      {
+      case 0: return \"br%S1\t%1\";
+      case 1: return \"j\t%1\";
+      default: gcc_unreachable ();
+      }
+  else
+    switch (which_alternative)
+      {
+      case 0: return \"mv\tr29, %1\;br\tr29\";
+      case 1: return \"la\tr29, %1\;br\tr29\";
+      default: gcc_unreachable ();
+      }
+}
+  [(set_attr "type" "call")])
+
+(define_expand "call"
+  [(parallel [(call (match_operand 0 "" "") (match_operand 1 "" ""))
+              (use (match_operand 2 "" ""))])]
+  ""
+{
+  score_call (operands, false);
+  DONE;
+})
+
+(define_insn "call_internal_score7"
+  [(call (mem:SI (match_operand:SI 0 "call_insn_operand" "d,Z"))
+         (match_operand 1 "" ""))
+   (clobber (reg:SI RA_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  if (!flag_pic)
+    switch (which_alternative)
+      {
+      case 0: return \"brl%S0\t%0\";
+      case 1: return \"jl\t%0\";
+      default: gcc_unreachable ();
+      }
+  else
+     switch (which_alternative)
+      {
+      case 0: return \"mv\tr29, %0\;brl\tr29\";
+      case 1: return \"la\tr29, %0\;brl\tr29\";
+      default: gcc_unreachable ();
+      }
+}
+  [(set_attr "type" "call")])
+
+(define_expand "call_value"
+  [(parallel [(set (match_operand 0 "" "")
+                   (call (match_operand 1 "" "") (match_operand 2 "" "")))
+              (use (match_operand 3 "" ""))])]
+  ""
+{
+  score_call_value (operands, false);
+  DONE;
+})
+
+(define_insn "call_value_internal_score7"
+  [(set (match_operand 0 "register_operand" "=d,d")
+        (call (mem:SI (match_operand:SI 1 "call_insn_operand" "d,Z"))
+              (match_operand 2 "" "")))
+   (clobber (reg:SI RA_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  if (!flag_pic)
+    switch (which_alternative)
+      {
+      case 0: return \"brl%S1\t%1\";
+      case 1: return \"jl\t%1\";
+      default: gcc_unreachable ();
+      }
+  else
+    switch (which_alternative)
+      {
+      case 0: return \"mv\tr29, %1\;brl\tr29\";
+      case 1: return \"la\tr29, %1\;brl\tr29\";
+      default: gcc_unreachable ();
+      }
+}
+  [(set_attr "type" "call")])
+
+(define_expand "indirect_jump"
+  [(set (pc) (match_operand 0 "score_register_operand" "d"))]
+  ""
+{
+  rtx dest;
+  dest = operands[0];
+  if (GET_CODE (dest) != REG
+      || GET_MODE (dest) != Pmode)
+    operands[0] = copy_to_mode_reg (Pmode, dest);
+
+  emit_jump_insn (gen_indirect_jump_internal_score (operands[0]));
+  DONE;
+})
+
+(define_insn "indirect_jump_internal_score"
+  [(set (pc) (match_operand:SI 0 "score_register_operand" "d"))]
+  ""
+  "br%S0   %0"
+  [(set_attr "type" "jump")])
+
+(define_expand "tablejump"
+  [(set (pc)
+        (match_operand 0 "score_register_operand" "d"))
+   (use (label_ref (match_operand 1 "" "")))]
+  ""
+{
+  if (TARGET_SCORE7 || TARGET_SCORE7D)
+    emit_jump_insn (gen_tablejump_internal_score7 (operands[0], operands[1]));
+
+  DONE;
+})
+
+(define_insn "tablejump_internal_score7"
+  [(set (pc)
+        (match_operand:SI 0 "register_operand" "d"))
+   (use (label_ref (match_operand 1 "" "")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+{
+  if (flag_pic)
+    return \"mv\tr29, %0\;.cpadd\tr29\;br\tr29\";
+  else
+    return \"br%S0\t%0\";
+}
+  [(set_attr "type" "jump")])
+
+(define_expand "prologue"
+  [(const_int 1)]
+  ""
+{
+  score_prologue ();
+  DONE;
+})
+
+(define_expand "epilogue"
+  [(const_int 2)]
+  ""
+{
+  score_epilogue (false);
+  DONE;
+})
+
+(define_expand "sibcall_epilogue"
+  [(const_int 2)]
+  ""
+{
+  score_epilogue (true);
+  DONE;
+})
+
+(define_insn "return_internal_score7"
+  [(return)
+   (use (match_operand 0 "pmode_register_operand" "d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "br%S0\t%0")
+
+(define_insn "nop"
+  [(const_int 0)]
+  ""
+  "#nop!"
+)
+
+(define_insn "cpload_score7"
+  [(unspec_volatile:SI [(const_int 1)] CPLOAD)]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)
+   && flag_pic"
+  ".cpload\tr29"
+)
+
+(define_insn "cprestore_use_fp_score7"
+  [(unspec_volatile:SI [(match_operand:SI 0 "" "")] CPRESTORE)
+   (use (reg:SI FP_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)
+   && flag_pic"
+  ".cprestore\tr2, %0"
+)
+
+(define_insn "cprestore_use_sp_score7"
+  [(unspec_volatile:SI [(match_operand:SI 0 "" "")] CPRESTORE)
+   (use (reg:SI SP_REGNUM))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)
+   && flag_pic"
+  ".cprestore\tr0, %0"
+)
+
+(define_insn "pushsi_score7"
+  [(set (match_operand:SI 0 "push_operand" "=<")
+        (match_operand:SI 1 "register_operand" "d"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "push!\t%1, [r0]"
+  [(set_attr "type" "store")
+   (set_attr "mode" "SI")])
+
+(define_insn "popsi_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (match_operand:SI 1 "pop_operand" ">"))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "pop!\t%0, [r0]"
+  [(set_attr "type" "store")
+   (set_attr "mode" "SI")])
+
+(define_peephole2
+  [(set (match_operand:SI 0 "g32reg_operand" "")
+        (match_operand:SI 1 "loreg_operand" ""))
+   (set (match_operand:SI 2 "g32reg_operand" "")
+        (match_operand:SI 3 "hireg_operand" ""))]
+  ""
+  [(parallel
+       [(set (match_dup 0) (match_dup 1))
+        (set (match_dup 2) (match_dup 3))])])
+
+(define_peephole2
+  [(set (match_operand:SI 0 "g32reg_operand" "")
+        (match_operand:SI 1 "hireg_operand" ""))
+   (set (match_operand:SI 2 "g32reg_operand" "")
+        (match_operand:SI 3 "loreg_operand" ""))]
+  ""
+  [(parallel
+       [(set (match_dup 2) (match_dup 3))
+        (set (match_dup 0) (match_dup 1))])])
+
+(define_insn "movhilo"
+  [(parallel
+    [(set (match_operand:SI 0 "register_operand" "=d")
+          (match_operand:SI 1 "loreg_operand" ""))
+     (set (match_operand:SI 2 "register_operand" "=d")
+          (match_operand:SI 3 "hireg_operand" ""))])]
+  ""
+  "mfcehl\t%2, %0"
+  [(set_attr "type" "fce")
+   (set_attr "mode" "SI")])
+
+(define_expand "movsicc"
+  [(set (match_operand:SI 0 "register_operand" "")
+        (if_then_else:SI (match_operator 1 "comparison_operator"
+                          [(reg:CC CC_REGNUM) (const_int 0)])
+                         (match_operand:SI 2 "register_operand" "")
+                         (match_operand:SI 3 "register_operand" "")))]
+  ""
+{
+  score_movsicc (operands);
+})
+
+(define_insn "movsicc_internal_score7"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (if_then_else:SI (match_operator 1 "comparison_operator"
+                          [(reg:CC CC_REGNUM) (const_int 0)])
+                         (match_operand:SI 2 "arith_operand" "d")
+                         (match_operand:SI 3 "arith_operand" "0")))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "mv%C1\t%0, %2"
+  [(set_attr "type" "cndmv")
+   (set_attr "mode" "SI")])
+
+(define_insn "zero_extract_bittst_score7"
+  [(set (reg:CC_NZ CC_REGNUM)
+        (compare:CC_NZ (unspec:SI
+                        [(match_operand:SI 0 "register_operand" "*e,d")
+                         (match_operand:SI 1 "const_uimm5" "")]
+                        BITTST)
+                       (const_int 0)))]
+  "(TARGET_SCORE7 || TARGET_SCORE7D)"
+  "@
+   bittst!\t%0, %c1
+   bittst.c\t%0, %c1"
+  [(set_attr "type" "arith")
+   (set_attr "up_c" "yes")
+   (set_attr "mode" "SI")])
+
+(define_insn "andsi3_extzh"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (and:SI (match_operand:SI 1 "register_operand" "d")
+                (const_int 65535)))]
+  ""
+  "extzh\t%0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "length" "4")
+   (set_attr "mode" "SI")])
+
+(define_insn "clzsi2"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (clz:SI (match_operand:SI 1 "register_operand" "d")))]
+  "(TARGET_SCORE7D)"
+  "clz\t%0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "smaxsi3"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (smax:SI (match_operand:SI 1 "register_operand" "d")
+                 (match_operand:SI 2 "register_operand" "d")))]
+  "(TARGET_SCORE7D)"
+  "max\t%0, %1, %2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "sminsi3"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (smin:SI (match_operand:SI 1 "register_operand" "d")
+                 (match_operand:SI 2 "register_operand" "d")))]
+  "(TARGET_SCORE7D)"
+  "min\t%0, %1, %2"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "abssi2"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (abs:SI (match_operand:SI 1 "register_operand" "d")))]
+  "(TARGET_SCORE7D)"
+  "abs\t%0, %1"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_insn "sffs"
+  [(set (match_operand:SI 0 "register_operand" "=d")
+        (unspec:SI [(match_operand:SI 1 "register_operand" "d")] SFFS))]
+  "(TARGET_SCORE7D)"
+  "bitrev\t%0, %1, r0\;clz\t%0, %0\;addi\t%0, 0x1"
+  [(set_attr "type" "arith")
+   (set_attr "mode" "SI")])
+
+(define_expand "ffssi2"
+  [(set (match_operand:SI 0 "register_operand")
+        (ffs:SI (match_operand:SI 1 "register_operand")))]
+  "(TARGET_SCORE7D)"
+{
+  emit_insn (gen_sffs (operands[0], operands[1]));
+  emit_insn (gen_rtx_SET (gen_rtx_REG (CC_NZmode, CC_REGNUM),
+                          gen_rtx_COMPARE (CC_NZmode, operands[0],
+                                           GEN_INT (33))));
+  if (TARGET_SCORE7D)
+    emit_insn (gen_movsicc_internal_score7 (operands[0],
+               gen_rtx_fmt_ee (EQ, VOIDmode, operands[0], GEN_INT (33)),
+               GEN_INT (0),
+               operands[0]));
+  DONE;
+})
+
+(define_peephole2
+  [(set (match_operand:SI 0 "loreg_operand" "")
+        (match_operand:SI 1 "register_operand" ""))
+   (set (match_operand:SI 2 "hireg_operand" "")
+        (match_operand:SI 3 "register_operand" ""))]
+  "(TARGET_SCORE7D)"
+  [(parallel
+       [(set (match_dup 0) (match_dup 1))
+        (set (match_dup 2) (match_dup 3))])])
+
+(define_peephole2
+  [(set (match_operand:SI 0 "hireg_operand" "")
+        (match_operand:SI 1 "register_operand" ""))
+   (set (match_operand:SI 2 "loreg_operand" "")
+        (match_operand:SI 3 "register_operand" ""))]
+  "(TARGET_SCORE7D)"
+  [(parallel
+       [(set (match_dup 2) (match_dup 3))
+        (set (match_dup 0) (match_dup 1))])])
+
+(define_insn "movtohilo"
+  [(parallel
+       [(set (match_operand:SI 0 "loreg_operand" "=l")
+             (match_operand:SI 1 "register_operand" "d"))
+        (set (match_operand:SI 2 "hireg_operand" "=h")
+             (match_operand:SI 3 "register_operand" "d"))])]
+  "(TARGET_SCORE7D)"
+  "mtcehl\t%3, %1"
+  [(set_attr "type" "fce")
+   (set_attr "mode" "SI")])
+
+(define_insn "mulsi3addsi"
+  [(set (match_operand:SI 0 "register_operand" "=l,l,d")
+        (plus:SI (mult:SI (match_operand:SI 2 "register_operand" "d,d,d")
+                          (match_operand:SI 3 "register_operand" "d,d,d"))
+                 (match_operand:SI 1 "register_operand" "0,d,l")))
+   (clobber (reg:SI HI_REGNUM))]
+  "(TARGET_SCORE7D)"
+  "@
+   mad\t%2, %3
+   mtcel%S1\t%1\;mad\t%2, %3
+   mad\t%2, %3\;mfcel%S0\t%0"
+  [(set_attr "mode" "SI")])
+
+(define_insn "mulsi3subsi"
+  [(set (match_operand:SI 0 "register_operand" "=l,l,d")
+        (minus:SI (match_operand:SI 1 "register_operand" "0,d,l")
+                  (mult:SI (match_operand:SI 2 "register_operand" "d,d,d")
+                           (match_operand:SI 3 "register_operand" "d,d,d"))))
+   (clobber (reg:SI HI_REGNUM))]
+  "(TARGET_SCORE7D)"
+  "@
+   msb\t%2, %3
+   mtcel%S1\t%1\;msb\t%2, %3
+   msb\t%2, %3\;mfcel%S0\t%0"
+  [(set_attr "mode" "SI")])
+
+(define_insn "mulsidi3adddi"
+  [(set (match_operand:DI 0 "register_operand" "=x")
+        (plus:DI (mult:DI
+                  (sign_extend:DI (match_operand:SI 2 "register_operand" "%d"))
+                  (sign_extend:DI (match_operand:SI 3 "register_operand" "d")))
+                 (match_operand:DI 1 "register_operand" "0")))]
+  "(TARGET_SCORE7D)"
+  "mad\t%2, %3"
+  [(set_attr "mode" "DI")])
+
+(define_insn "umulsidi3adddi"
+  [(set (match_operand:DI 0 "register_operand" "=x")
+        (plus:DI (mult:DI
+                  (zero_extend:DI (match_operand:SI 2 "register_operand" "%d"))
+                  (zero_extend:DI (match_operand:SI 3 "register_operand" "d")))
+                 (match_operand:DI 1 "register_operand" "0")))]
+  "(TARGET_SCORE7D)"
+  "madu\t%2, %3"
+  [(set_attr "mode" "DI")])
+
+(define_insn "mulsidi3subdi"
+  [(set (match_operand:DI 0 "register_operand" "=x")
+        (minus:DI
+         (match_operand:DI 1 "register_operand" "0")
+         (mult:DI
+          (sign_extend:DI (match_operand:SI 2 "register_operand" "%d"))
+          (sign_extend:DI (match_operand:SI 3 "register_operand" "d")))))]
+  "(TARGET_SCORE7D)"
+  "msb\t%2, %3"
+  [(set_attr "mode" "DI")])
+
+(define_insn "umulsidi3subdi"
+  [(set (match_operand:DI 0 "register_operand" "=x")
+        (minus:DI
+         (match_operand:DI 1 "register_operand" "0")
+         (mult:DI (zero_extend:DI
+                   (match_operand:SI 2 "register_operand" "%d"))
+                  (zero_extend:DI
+                   (match_operand:SI 3 "register_operand" "d")))))]
+  "(TARGET_SCORE7D)"
+  "msbu\t%2, %3"
+  [(set_attr "mode" "DI")])
+
diff --git a/gcc/config/score/score.opt b/gcc/config/score/score.opt
new file mode 100644
index 000000000..aa103ad18
--- /dev/null
+++ b/gcc/config/score/score.opt
@@ -0,0 +1,57 @@
+; Options for the Sunnorth port of the compiler.
+
+; Copyright (C) 2005-2014 Free Software Foundation, Inc.
+;
+; This file is part of GCC.
+;
+; GCC is free software; you can redistribute it and/or modify it under
+; the terms of the GNU General Public License as published by the Free
+; Software Foundation; either version 3, or (at your option) any later
+; version.
+;
+; GCC is distributed in the hope that it will be useful, but WITHOUT ANY
+; WARRANTY; without even the implied warranty of MERCHANTABILITY or
+; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
+; for more details.
+;
+; You should have received a copy of the GNU General Public License
+; along with GCC; see the file COPYING3.  If not see
+; <http://www.gnu.org/licenses/>.
+
+meb
+Target RejectNegative InverseMask(LITTLE_ENDIAN)
+Generate big-endian code
+
+mel
+Target RejectNegative Mask(LITTLE_ENDIAN)
+Generate little-endian code
+
+mnhwloop
+Target RejectNegative Mask(NHWLOOP)
+Disable bcnz instruction
+
+muls
+Target RejectNegative Mask(ULS)
+Enable unaligned load/store instruction
+
+mscore7
+Target RejectNegative Mask(SCORE7)
+Support SCORE 7 ISA
+
+mscore7d
+Target RejectNegative Mask(SCORE7D)
+Support SCORE 7D ISA
+
+march=
+Target RejectNegative Joined Enum(score_arch)
+Specify the name of the target architecture
+
+Enum
+Name(score_arch) Type(int)
+Known SCORE architectures (for use with the -march= option):
+
+EnumValue
+Enum(score_arch) String(score7) Value(MASK_SCORE7)
+
+EnumValue
+Enum(score_arch) String(score7d) Value(MASK_SCORE7 | MASK_SCORE7D)
diff --git a/gcc/config/score/score.opt.urls b/gcc/config/score/score.opt.urls
new file mode 100644
index 000000000..7ada2500b
--- /dev/null
+++ b/gcc/config/score/score.opt.urls
@@ -0,0 +1,2 @@
+meb
+UrlSuffix(gcc/score-options.html#index-meb)
diff --git a/libgcc/config.host b/libgcc/config.host
index 06fae1545..05e141c34 100644
--- a/libgcc/config.host
+++ b/libgcc/config.host
@@ -1413,6 +1413,10 @@ s390x-ibm-tpf*)
 	extra_parts="crtbeginS.o crtendS.o"
 	md_unwind_header=s390/tpf-unwind.h
 	;;
+score-*-elf)
+	tmake_file="${tmake_file} t-softfp-sfdf t-softfp-excl t-softfp"
+	extra_parts="$extra_parts crti.o crtn.o"
+        ;;
 sh-*-elf* | sh[12346l]*-*-elf*)
 	tmake_file="$tmake_file sh/t-sh t-crtstuff-pic t-softfp-sfdf t-softfp"
 	extra_parts="$extra_parts crt1.o crti.o crtn.o crtbeginS.o crtendS.o \
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
