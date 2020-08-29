#ifndef __HYPERSCAN_DISASM__
#define __HYPERSCAN_DISASM__

#include "hyperscan/cpu.h"

void disasm16(const hyperscan::CPU::Instruction16 &insn, uint32_t address);

void disasm32(const hyperscan::CPU::Instruction32 &insn, uint32_t address);

#endif
