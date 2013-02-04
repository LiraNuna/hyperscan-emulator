#include <cstdio>
#include <iostream>

#include "hyperscan/cpu.h"
#include "hyperscan/memory/arraymemoryregion.h"

using namespace hyperscan;

void dumpRegisters(const hyperscan::CPU &cpu) {
	printf("PC = 0x%08X                N[%c] Z[%c] C[%c] V[%c] T[%c]\n",
		cpu.pc,
		cpu.N ? 'x' : ' ',
		cpu.Z ? 'x' : ' ',
		cpu.C ? 'x' : ' ',
		cpu.V ? 'x' : ' ',
		cpu.T ? 'x' : ' '
	);

	for(int i=0; i<32; i+=4) {
		printf("%sr%d[%08X] %sr%d[%08X] %sr%d[%08X] %sr%d[%08X]\n",
			((i + 0) < 10) ? " " : "", i + 0, cpu.r[i + 0],
			((i + 1) < 10) ? " " : "", i + 1, cpu.r[i + 1],
			((i + 2) < 10) ? " " : "", i + 2, cpu.r[i + 2],
			((i + 3) < 10) ? " " : "", i + 3, cpu.r[i + 3]
		);
	}
}

// --- utils
// -- TODO: move to cpu.cpp

// Sign extends x to the size of b bits
int32_t sign_extend(uint32_t x, uint8_t b) {
	uint32_t m = 1UL << (b - 1);

	x = x & ((1UL << b) - 1);
	return (x ^ m) - m;
}

// Retrieve bits s -> (start + size) as 0 -> size
uint32_t bit_range(uint32_t x, uint8_t start, uint8_t size) {
	return (x >> start) & ((1 << size) - 1);
}

// -- cpu emulation
// -- TODO: move to cpu.cpp

void spg290_insn16(hyperscan::CPU &cpu, uint16_t insn) {
	switch(insn >> 12) {
		case 0x00: {
				uint8_t rA = bit_range(insn, 4, 4);
				uint8_t rD = bit_range(insn, 8, 4);
				switch(bit_range(insn, 0, 4)) {
					case 0x00: /* nop */ break;
					case 0x01: cpu.g0[rD] = cpu.g1[rA]; break;
					case 0x02: cpu.g1[rD] = cpu.g0[rA]; break;
					case 0x03: cpu.g0[rD] = cpu.g0[rA]; break;
					case 0x04: if(cpu.conditional(rD)) cpu.pc = cpu.g0[rA] - 2; break;
					case 0x05: if(rA == 0) cpu.T = cpu.conditional(rD); break;
					default:
						fprintf(stderr, "unimplemented 16bit op0, %d\n", bit_range(insn, 0, 4));
						dumpRegisters(cpu);
						exit(1);
				}
			} break;
		case 0x02: {
				uint32_t &rA = cpu.g0[bit_range(insn, 4, 4)];
				uint32_t &rD = cpu.g0[bit_range(insn, 8, 4)];
				switch(bit_range(insn, 0, 4)) {
					case 0x03: cpu.cmp(rD, rA, true); break;
					case 0x08: rD = cpu.miu.readU8(rA); break;
					case 0x0C: cpu.miu.writeU32(rA, rD); break;
					// XXX: H-bit is not correclty behaving
					case 0x0A: rD = cpu.miu.readU8(rA); rA += 4; break;
					case 0x0E: cpu.miu.writeU32(rA -= 4, rD); break;
					case 0x0F: cpu.miu.writeU8(rA, rD); break;
					default:
						fprintf(stderr, "unimplemented 16bit op2, %d\n", bit_range(insn, 0, 4));
						dumpRegisters(cpu);
						exit(1);
				}
			} break;
		case 0x03:
				if(insn & 1)
					cpu.r3 = cpu.pc + 4;

				cpu.pc &= 0xFFFFF000;
				cpu.pc |= (bit_range(insn, 1, 11) << 1) - 2;
			break;
		case 0x04:
				if(cpu.conditional(bit_range(insn, 8, 4)))
					cpu.pc += (sign_extend(bit_range(insn, 0, 8), 8) << 1) - 2;
			break;
		case 0x05:
				cpu.g0[bit_range(insn, 8, 4)] = bit_range(insn, 0, 8);
			break;
		case 0x06: {
				uint32_t &rD = cpu.g0[bit_range(insn, 8, 4)];
				uint8_t imm5 = bit_range(insn, 3, 5);
				switch(bit_range(insn, 0, 3)) {
					case 0x04: rD = cpu.bit_and(rD, 1 << imm5, true); break;
					case 0x05: rD = cpu.bit_or(rD, 1 << imm5, true); break;
					case 0x06: cpu.bit_and(rD, 1 << imm5, true); break;
					default:
						fprintf(stderr, "unimplemented 16bit op6, func%d\n", bit_range(insn, 0, 3));
						dumpRegisters(cpu);
						exit(1);
				}
			} break;
		case 0x07: {
				uint32_t &rD = cpu.g0[bit_range(insn, 8, 4)];
				uint8_t imm5 = bit_range(insn, 3, 5);
				switch(bit_range(insn, 0, 3)) {
					case 0x00: rD = cpu.miu.readU8(cpu.r2 + (imm5 << 2)); break;
					case 0x04: cpu.miu.writeU32(cpu.r2 + (imm5 << 2), rD); break;
					default:
						fprintf(stderr, "unimplemented 16bit op7, func%d\n", bit_range(insn, 0, 3));
						dumpRegisters(cpu);
						exit(1);
				}
			} break;
		default:
			fprintf(stderr, "unimplemented (16bit): op=%04X (%d)\n", insn, insn >> 12);
			dumpRegisters(cpu);
			exit(1);
	}

}

/**
 * TODO: make better
 */
memory::ArrayMemoryRegion<24 >* createFileMemoryRegion(const char* fileName) {
	memory::ArrayMemoryRegion<24 >* result = new memory::ArrayMemoryRegion<24 >();

	FILE* f = fopen(fileName, "rb");
	if(!f) {
		fprintf(stderr, "bad file: %s", fileName);
		exit(1);
	}

	fseek(f, 0, SEEK_END);
	size_t fileSize = ftell(f);
	fseek(f, 0, SEEK_SET);

	if(fread(result->memory.begin(), 1, fileSize, f) != fileSize)
		fprintf(stderr, "WARNING: Bad firmware\n");

	fclose(f);

	return result;
}

/*
// XXX P_MIU1_SDRAM_SETTING: SDRAM self refresh
if(addr == 0x8807006C)
	return 0;
*/

int main() {
	hyperscan::CPU cpu;

	memory::ArrayMemoryRegion<24 >* firmware = createFileMemoryRegion("roms/hsfirmware.bin");
	memory::ArrayMemoryRegion<24 >* ram = new memory::ArrayMemoryRegion<24 >();
	memory::ArrayMemoryRegion<24 >* mmio = new memory::ArrayMemoryRegion<24 >();

	cpu.miu.setRegion(0x9E, firmware);
	cpu.miu.setRegion(0x9F, firmware);

	cpu.miu.setRegion(0x80, ram);
	cpu.miu.setRegion(0xA0, ram);

	cpu.miu.setRegion(0x08, mmio);
	cpu.miu.setRegion(0x88, mmio);

	// Firmware entry point
	cpu.pc = 0x9F000000;

//	// ISO "entry point"
//	cpu.pc = 0xA0091000;

	while(1)
		cpu.step();

	return 0;
}
