#include "cpu.h"

#include <cstdio>

// XXX: get rid of
extern void spg290_insn16(hyperscan::CPU &cpu, uint16_t insn);

// Sign extends x to the size of b bits
static uint32_t sign_extend(uint32_t x, uint8_t b) {
	uint32_t m = 1UL << (b - 1);

	x = x & ((1UL << b) - 1);
	return (x ^ m) - m;
}

namespace hyperscan {

CPU::CPU() {
	reset();
}

void CPU::reset() {
	reset_flags();
	reset_registers();
}

void CPU::reset_flags() {
	N = 0;
	Z = 0;
	C = 0;
	V = 0;
	T = 0;
}

void CPU::reset_registers() {
	std::fill(r, r + 32, 0);
	std::fill(cr, cr + 32, 0);

	pc = 0;
}

void CPU::step() {
	int instructionSize = 2;
	uint32_t instruction = miu.readU16(pc);

	// Pre-decode the instruction
	if(instruction & 0x8000) {
		// Remove p0 and p1 bits before handling the instruction as 30bit
		instruction &= 0x00007FFF;
		instruction |= miu.readU16(pc + 2) << 15;
		instruction &= 0x3FFFFFFF;

		instructionSize += 2;

		exec32(instruction);
	} else {
		// p0 bit is not present and there is no next instruction
		// TODO: if p1 bit is in next 16bit instruction, parallel execution mode
		exec16(instruction);
	}

	pc += instructionSize;
}

void CPU::exec32(const Instruction32 &insn) {
	switch(insn.OP) {
		case 0x00: {
				uint32_t &rD = r[insn.spform.rD];
				uint32_t &rA = r[insn.spform.rA];
				uint32_t &rB = r[insn.spform.rB];
				switch(insn.spform.func6) {
					// nop
					case 0x00: /* nothing */ break;

					// br{cond}[l] rA
					case 0x04: if(conditional(insn.spform.rB)) pc = rA - 4; break;

					// add[.c] rD, rA, rB
					case 0x08: rD = add(rA, rB, insn.spform.CU); break;
					// addc[.c] rD, rA, rB
					case 0x09: rD = addc(rA, rB, insn.spform.CU); break;
					// sub[.c] rD, rA, rB
					case 0x0A: rD = sub(rA, rB, insn.spform.CU); break;
					// subc[.c] rD, rA, rB
					case 0x0B: rD = subc(rA, rB, insn.spform.CU); break;
					// cmp{tcs}.c rA, rB
					case 0x0C:      cmp(rA, rB, insn.spform.rD & 0x03, insn.spform.CU); break;
					// cmpz{tcs}.c rA, rB
					case 0x0D:      cmp(rA, 0, insn.spform.rD & 0x03, insn.spform.CU); break;

					// not[.c] rD, rB
					case 0x0F: rD = bit_xor(rB, ~0, insn.spform.CU); break;
					// and[.c] rD, rA, rB
					case 0x10: rD = bit_and(rA, rB, insn.spform.CU); break;
					// or[.c] rD, rA, rB
					case 0x11: rD = bit_or(rA, rB, insn.spform.CU); break;
					// not[.c] rD, rA, rB
					case 0x12: rD = bit_xor(rA, ~0, insn.spform.CU); break;
					// xor[.c] rD, rA, rB
					case 0x13: rD = bit_or(rA, rB, insn.spform.CU); break;
					// bitclr[.c] rD, rA, imm5
					case 0x14: rD = bit_and(rA, ~(1 << insn.spform.rB), insn.spform.CU);
					// bitset[.c] rD, rA, imm5
					case 0x15: rD = bit_or(rA, 1 << insn.spform.rB, insn.spform.CU);
					// bittst.c rA, imm5
					case 0x16: bit_and(rA, 1 << insn.spform.rB, insn.spform.CU);
					// bittgl[.c] rA, imm5
					case 0x17: rD = bit_xor(rA, 1 << insn.spform.rB, insn.spform.CU);

					// mv{cond} rD, rA
					case 0x2B: if(conditional(insn.spform.rB)) rD = rA;
					// extsb[.c] rD, rA
					case 0x2C: rD = sign_extend(rA,  8); if(insn.spform.CU) basic_flags(rD); break;
					// extsh[.c] rD, rA
					case 0x2D: rD = sign_extend(rA, 16); if(insn.spform.CU) basic_flags(rD); break;
					// extzb[.c] rD, rA
					case 0x2E: rD = rA & 0x000000FF; if(insn.spform.CU) basic_flags(rD); break;
					// extzh[.c] rD, rA
					case 0x2F: rD = rA & 0x0000FFFF; if(insn.spform.CU) basic_flags(rD); break;

					// slli[.c] rD, rA, imm5
					case 0x38: rD = shift_left(rA, insn.spform.rB, insn.spform.CU); break;

					// srli[.c] rD, rA, imm5
					case 0x3A: rD = shift_right(rA, insn.spform.rB, insn.spform.CU); break;

					default: debugDump();
				}
			} break;
		case 0x01: {
				uint32_t &rD = r[insn.iform.rD];
				switch(insn.iform.func3) {
					// addi[.c] rD, imm16
					case 0x00: rD = add(rD, sign_extend(insn.iform.Imm16, 16), insn.iform.CU); break;
					// cmpi.c rD, imm16
					case 0x02:      cmp(rD, sign_extend(insn.iform.Imm16, 16), 3, insn.iform.CU); break;
					// andi.c rD, imm16
					case 0x04: rD = bit_and(rD, insn.iform.Imm16, insn.iform.CU); break;
					// ori.c rD, imm16
					case 0x05: rD = bit_or(rD, insn.iform.Imm16, insn.iform.CU); break;
					// ldi.c rD, imm16
					case 0x06: rD = sign_extend(insn.iform.Imm16, 16); break;

					default: debugDump();
				}
			} break;
		case 0x02: {
				// j[l] imm24
				if(insn.jform.LK)
					r3 = pc + 4;

				// Update PC
				pc &= 0xFC000000;
				pc |= (insn.jform.Disp24 << 1) - 4;
			} break;
		case 0x03: {
				uint32_t &rD = r[insn.rixform.rD];
				uint32_t &rA = r[insn.rixform.rA];

				// Pre-increment
				rA += sign_extend(insn.rixform.Imm12, 12);
				switch(insn.rixform.func3) {
					// lw rD, [rA, imm12]+
					case 0x00: rD = miu.readU32(rA); break;
					// lh rD, [rA, imm12]+
					case 0x01: rD = sign_extend(miu.readU16(rA), 16); break;
					// lhu rD, [rA, imm12]+
					case 0x02: rD = miu.readU16(rA); break;
					// lb rD, [rA, imm12]+
					case 0x03: rD = sign_extend(miu.readU8(rA), 8); break;
					// sw rD, [rA, imm12]+
					case 0x04: miu.writeU32(rA, rD); break;
					// sh rD, [rA, imm12]+
					case 0x05: miu.writeU16(rA, rD); break;
					// lbu rD, [rA, imm12]+
					case 0x06: rD = miu.readU8(rA); break;
					// sb rD, [rA, imm12]+
					case 0x07: miu.writeU8(rA, rD); break;

					default: debugDump();
				}
			} break;
		case 0x04: {
				// b{cond}[l]
				if(conditional(insn.bcform.BC)) {
					if(insn.bcform.LK)
						r3 = pc + 4;

					pc += sign_extend(((insn.bcform.Disp18_9 << 9) | insn.bcform.Disp8_0) << 1, 20) - 4;
				}
			} break;
		case 0x05: {
				uint32_t &rD = r[insn.iform.rD];
				switch(insn.iform.func3) {
					// addis[.c] rD, imm16
					case 0x00: rD = add(rD, insn.iform.Imm16, insn.iform.CU); break;
					// cmpis.c rD, imm16
					case 0x02:      cmp(rD, insn.iform.Imm16, 3, insn.iform.CU); break;
					// andis.c rD, imm16
					case 0x04: rD = bit_and(rD, insn.iform.Imm16, insn.iform.CU); break;
					// oris.c rD, imm16
					case 0x05: rD = bit_or(rD, insn.iform.Imm16, insn.iform.CU); break;
					// ldis.c rD, imm16
					case 0x06: rD = insn.iform.Imm16; break;

					default: debugDump();
				}
			} break;
		case 0x06:
				// TODO: co-processor, rte, drte, sleep
			break;
		case 0x07: {
				uint32_t &rD = r[insn.rixform.rD];
				uint32_t &rA = r[insn.rixform.rA];
				switch(insn.rixform.func3) {
					// lw rD, [rA]+, imm12
					case 0x00: rD = miu.readU32(rA); break;
					// lh rD, [rA]+, imm12
					case 0x01: rD = sign_extend(miu.readU16(rA), 16); break;
					// lhu rD, [rA]+, imm12
					case 0x02: rD = miu.readU16(rA); break;
					// lb rD, [rA]+, imm12
					case 0x03: rD = sign_extend(miu.readU8(rA), 8); break;
					// sw rD, [rA]+, imm12
					case 0x04: miu.writeU32(rA, rD); break;
					// sh rD, [rA]+, imm12
					case 0x05: miu.writeU16(rA, rD); break;
					// lbu rD, [rA]+, imm12
					case 0x06: rD = miu.readU8(rA); break;
					// sb rD, [rA]+, imm12
					case 0x07: miu.writeU8(rA, rD); break;

					default: debugDump();
				}
				// Post-increment
				rA += sign_extend(insn.rixform.Imm12, 12);
			} break;
		case 0x08: {
				// addri[.c] rD, rA, imm14
				uint32_t &rD = r[insn.riform.rD];
				uint32_t &rA = r[insn.riform.rA];
				uint32_t imm14 = sign_extend(insn.riform.Imm14, 14);

				rD = add(rA, imm14, insn.riform.CU);
			} break;
		case 0x0C: {
				// andri[.c] rD, rA, imm14
				uint32_t &rD = r[insn.riform.rD];
				uint32_t &rA = r[insn.riform.rA];
				uint32_t imm14 = insn.riform.Imm14;

				rD = bit_and(rA, imm14, insn.riform.CU);
			} break;
		case 0x0D: {
				// orri[.c] rD, rA, imm14
				uint32_t &rD = r[insn.riform.rD];
				uint32_t &rA = r[insn.riform.rA];
				uint32_t imm14 = insn.riform.Imm14;

				rD = bit_or(rA, imm14, insn.riform.CU);
			} break;
		case 0x10: {
				// lw rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu.readU32(rA + imm15);
			} break;
		case 0x11: {
				// lh rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = sign_extend(miu.readU16(rA + imm15), 16);
			} break;
		case 0x12: {
				// lhu rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu.readU16(rA + imm15);
			} break;
		case 0x13: {
				// lb rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = sign_extend(miu.readU8(rA + imm15), 8);
			} break;
		case 0x14: {
				// sw rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu.writeU32(rA + imm15, rD);
			} break;
		case 0x15: {
				// sh rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu.writeU16(rA + imm15, rD);
			} break;
		case 0x16: {
				// lbu rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu.readU8(rA + imm15);
			} break;
		case 0x17: {
				// sb rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				uint32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu.writeU8(rA + imm15, rD);
			} break;
		default: debugDump();
	}
}

void CPU::exec16(const Instruction16 &insn) {
	spg290_insn16(*this, insn.encoded);
}

bool CPU::conditional(uint8_t pattern) const {
	switch(pattern) {
		case 0x0: return  C;
		case 0x1: return !C;
		case 0x2: return  C && !Z;
		case 0x3: return !C ||  Z;
		case 0x4: return  Z;
		case 0x5: return !Z;
		case 0x6: return (N == V) && !Z;
		case 0x7: return (N != V) ||  Z;
		case 0x8: return (N == V);
		case 0x9: return (N != V);
		case 0xA: return  N;
		case 0xB: return !N;
		case 0xC: return  V;
		case 0xD: return !V;
		case 0xE: return false; // CNT > 0;
		case 0xF: return true;
	}

	return false;
}

void CPU::basic_flags(uint32_t res) {
	N = (res >> 31);
	Z = (res == 0);
}

void CPU::cmp(uint32_t a, uint32_t b, int tcs, bool flags) {
	if(!flags)
		return;

	sub(a, b, true);
	switch(tcs) {
		case 0x00: T = Z; break;
		case 0x01: T = N; break;
	}
}

uint32_t CPU::add(uint32_t a, uint32_t b, bool flags) {
	uint32_t res = a + b;
	if(flags) {
		basic_flags(res);
		C = (b > (0xFFFFFFFFU - a));
		V = (~(a ^ b) & (a ^ res)) >> 31;
	}

	return res;
}

uint32_t CPU::addc(uint32_t a, uint32_t b, bool flags) {
	return add(add(a, b, false), C, flags);
}

uint32_t CPU::sub(uint32_t a, uint32_t b, bool flags) {
	uint32_t res = a - b;
	if(flags) {
		basic_flags(res);
		C = (a >= b);
	    V = ((a ^ b) & ~(res ^ b)) >> 31;
	}

	return res;
}

uint32_t CPU::subc(uint32_t a, uint32_t b, bool flags) {
	return sub(sub(a, b, false), ~C, flags);
}

uint32_t CPU::bit_and(uint32_t a, uint32_t b, bool flags) {
	uint32_t res = a & b;
	if(flags)
		basic_flags(res);

	return res;
}

uint32_t CPU::bit_or(uint32_t a, uint32_t b, bool flags) {
	uint32_t res = a | b;
	if(flags)
		basic_flags(res);

	return res;
}

uint32_t CPU::bit_xor(uint32_t a, uint32_t b, bool flags) {
	uint32_t res = a ^ b;
	if(flags)
		basic_flags(res);

	return res;
}

uint32_t CPU::shift_left(uint32_t a, uint8_t sa, bool flags) {
	uint32_t res = a << sa;
	if(flags) {
		basic_flags(res);
		C = a & (1 << (32 - sa));
	}

	return res;
}

uint32_t CPU::shift_right(uint32_t a, uint8_t sa, bool flags) {
	uint32_t res = a >> sa;
	if(flags) {
		basic_flags(res);
		C = a & (1 << (sa - 1)); // XXX: Docs say this is right, but what if sa is 0?
	}

	return res;
}

void CPU::debugDump() {
	printf("PC = 0x%08X                N[%c] Z[%c] C[%c] V[%c] T[%c]\n",
		pc,
		N ? 'x' : ' ',
		Z ? 'x' : ' ',
		C ? 'x' : ' ',
		V ? 'x' : ' ',
		T ? 'x' : ' '
	);

	for(int i=0; i<32; i+=4) {
		for(int ri=i;ri<i+4; ++ri)
			printf("%sr%d[%08X] ", (ri < 10) ? " " : "", ri, r[ri]);

		printf("\n");
	}

	exit(1);
}

}
