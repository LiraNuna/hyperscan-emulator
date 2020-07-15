#include "cpu.h"

#include <cstdio>

// Sign extends x to the size of b bits
static int32_t sign_extend(uint32_t x, uint8_t b) {
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
	std::fill(sr, sr + 32, 0);

	CEH = 0;
	CEL = 0;

	pc = 0;
}

void CPU::step() {
	uint32_t instruction = miu.readU16(pc);

	// Pre-decode the instruction
	if(instruction & 0x8000) {
		// Remove p0 and p1 bits before handling the instruction as 30bit
		instruction &= 0x00007FFF;
		instruction |= miu.readU16(pc + 2) << 15;
		instruction &= 0x3FFFFFFF;

		exec32(instruction);
		pc += 4;
	} else {
		// p0 bit is not present and there is no next instruction
		// TODO: if p1 bit is in next 16bit instruction, parallel execution mode
		exec16(instruction);
		pc += 2;
	}
}

void CPU::interrupt(uint8_t cause) {
	// Don't fire if interrupts are disabled
	if(!(cr0 & 1))
		return;

	// Set cause in cr2
	cr2 &= ~0x00FC0000;
	cr2 |= (cause & 0x3F) << 18;

	// Save old PC
	cr5 = pc;

	// Jump to interrupt
	pc = cr3 + 0x1FC + (cause * 4);
}

void CPU::branch(uint8_t condition, uint32_t address, bool link) {
	if (conditional(condition)) {
		jump(address, link);
	}
}

void CPU::jump(uint32_t address, bool link) {
	if (link)
		r3 = pc + 4;

	pc = address;
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
					case 0x04: branch(insn.spform.rB, rA - 4, insn.spform.CU); break;

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

					// neg[.c] rD, rA
					case 0x0F: rD = sub(0, rA, insn.spform.CU); break;
					// and[.c] rD, rA, rB
					case 0x10: rD = bit_and(rA, rB, insn.spform.CU); break;
					// or[.c] rD, rA, rB
					case 0x11: rD = bit_or(rA, rB, insn.spform.CU); break;
					// not[.c] rD, rA, rB
					case 0x12: rD = bit_xor(rA, ~0, insn.spform.CU); break;
					// xor[.c] rD, rA, rB
					case 0x13: rD = bit_xor(rA, rB, insn.spform.CU); break;
					// bitclr[.c] rD, rA, imm5
					case 0x14: rD = bit_and(rA, ~(1 << insn.spform.rB), insn.spform.CU); break;
					// bitset[.c] rD, rA, imm5
					case 0x15: rD = bit_or(rA, 1 << insn.spform.rB, insn.spform.CU); break;
					// bittst.c rA, imm5
					case 0x16: bit_and(rA, 1 << insn.spform.rB, insn.spform.CU); break;
					// bittgl[.c] rA, imm5
					case 0x17: rD = bit_xor(rA, 1 << insn.spform.rB, insn.spform.CU); break;
					// sll[.c] rA, imm5
					case 0x18: rD = sll(rA, insn.spform.rB, insn.spform.CU); break;
					// srl[.c] rA, imm5
					case 0x1A: rD = srl(rA, insn.spform.rB, insn.spform.CU); break;
					// sra[.c] rA, imm5
					case 0x1B: rD = sra(rA, insn.spform.rB, insn.spform.CU); break;

					// mul rA, rD
					case 0x20: ce_op(rA, rD, std::multiplies<int64_t>()); break;
					// mulu rA, rD
					case 0x21: ce_op(rA, rD, std::multiplies<uint64_t>()); break;
					// div rA, rD
					case 0x22: ce_op(rA, rD, std::divides<int64_t>()); break;
					// divu rA, rD
					case 0x23: ce_op(rA, rD, std::divides<uint64_t>()); break;

					// mfce{hl} rD[, rA]
					case 0x24:
							switch(insn.spform.rB) {
								case 0x01: rD = CEL; break;
								case 0x02: rD = CEH; break;
								case 0x03: rD = CEH; rA = CEL; break;
							}
						break;
					// mtce{hl} rD[, rA]
					case 0x25:
							switch(insn.spform.rB) {
								case 0x01: CEL = rD; break;
								case 0x02: CEH = rD; break;
								case 0x03: CEH = rD; CEL = rA; break;
							}
						break;

					// mfsr rA, Srn
					case 0x28: rA = sr[insn.spform.rB]; break;
					// mtsr rA, Srn
					case 0x29: sr[insn.spform.rB] = rA; break;
					// t{cond}
					case 0x2A: T = conditional(insn.spform.rB); break;
					// mv{cond} rD, rA
					case 0x2B: if(conditional(insn.spform.rB)) rD = rA; break;
					// extsb[.c] rD, rA
					case 0x2C: rD = sign_extend(rA,  8); if(insn.spform.CU) basic_flags(rD); break;
					// extsh[.c] rD, rA
					case 0x2D: rD = sign_extend(rA, 16); if(insn.spform.CU) basic_flags(rD); break;
					// extzb[.c] rD, rA
					case 0x2E: rD = bit_and(rA, 0x000000FF, insn.spform.CU); break;
					// extzh[.c] rD, rA
					case 0x2F: rD = bit_and(rA, 0x0000FFFF, insn.spform.CU); break;

					// slli[.c] rD, rA, imm5
					case 0x38: rD = sll(rA, insn.spform.rB, insn.spform.CU); break;

					// srli[.c] rD, rA, imm5
					case 0x3A: rD = srl(rA, insn.spform.rB, insn.spform.CU); break;
					// srai[.c] rD, rA, imm5
					case 0x3B: rD = sra(rA, insn.spform.rB, insn.spform.CU); break;

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
					// ldi rD, imm16
					case 0x06: rD = sign_extend(insn.iform.Imm16, 16); break;

					default: debugDump();
				}
			} break;
		case 0x02: {
				// j[l] imm24
				jump(((pc & 0xFC000000) | (insn.jform.Disp24 << 1)) - 4, insn.jform.LK);
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
				int32_t disp = sign_extend(((insn.bcform.Disp18_9 << 9) | insn.bcform.Disp8_0) << 1, 20);
				branch(insn.bcform.BC, pc + disp - 4, insn.bcform.LK);
			} break;
		case 0x05: {
				uint32_t &rD = r[insn.iform.rD];
				uint32_t imm16 = insn.iform.Imm16 << 16;
				switch(insn.iform.func3) {
					// addis[.c] rD, imm16
					case 0x00: rD = add(rD, imm16, insn.iform.CU); break;
					// cmpis.c rD, imm16
					case 0x02:      cmp(rD, imm16, 3, insn.iform.CU); break;
					// andis.c rD, imm16
					case 0x04: rD = bit_and(rD, imm16, insn.iform.CU); break;
					// oris.c rD, imm16
					case 0x05: rD = bit_or(rD, imm16, insn.iform.CU); break;
					// ldis rD, imm16
					case 0x06: rD = imm16; break;

					default: debugDump();
				}
			} break;
		case 0x06: {
				uint32_t &rD = r[insn.crform.rD];
				uint32_t &crA = cr[insn.crform.crA];
				switch(insn.crform.CR_OP) {
					// mtcr rD, crA
					case 0x00: crA = rD; break;
					// mfcr rD, crA
					case 0x01: rD = crA; break;
					// rte
					case 0x84: jump(cr5 - 4, false); /* TODO: missing PSR */ break;

					default: debugDump();
				}
			} break;
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
				int32_t imm14 = sign_extend(insn.riform.Imm14, 14);

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
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu.readU32(rA + imm15);
			} break;
		case 0x11: {
				// lh rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = sign_extend(miu.readU16(rA + imm15), 16);
			} break;
		case 0x12: {
				// lhu rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu.readU16(rA + imm15);
			} break;
		case 0x13: {
				// lb rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = sign_extend(miu.readU8(rA + imm15), 8);
			} break;
		case 0x14: {
				// sw rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu.writeU32(rA + imm15, rD);
			} break;
		case 0x15: {
				// sh rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu.writeU16(rA + imm15, rD);
			} break;
		case 0x16: {
				// lbu rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu.readU8(rA + imm15);
			} break;
		case 0x17: {
				// sb rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu.writeU8(rA + imm15, rD);
			} break;
		case 0x18:
				// cache op, [rA, imm15]
			break;
		default: debugDump();
	}
}

void CPU::exec16(const Instruction16 &insn) {
	switch(insn.OP) {
		case 0x00:
				switch(insn.rform.func4) {
					// nop!
					case 0x00: /* noting */ break;
					// mlfh! rDg0, rAg1
					case 0x01: g0[insn.rform.rD] = g1[insn.rform.rA]; break;
					// mhfl! rDg1, rAg0
					case 0x02: g1[insn.rform.rD] = g0[insn.rform.rA]; break;
					// mv! rDg0, rAg0
					case 0x03: g0[insn.rform.rD] = g0[insn.rform.rA]; break;
					// br{cond}! rAg0
					case 0x04: branch(insn.rform.rD, g0[insn.rform.rA] - 2, false); break;
					// t{cond}!
					case 0x05: T = conditional(insn.rform.rD); break;
					// br{cond}l! rAg0
					case 0x0C: branch(insn.rform.rD, g0[insn.rform.rA] - 2, false); break;

					default: debugDump();
				}
			break;
		case 0x01: {
				uint32_t &rA = g0[insn.rform.rA];
//				uint32_t &rD = g0[insn.rform.rD];
				switch(insn.rform.func4) {
					// mtce{lh}! rA
					case 0x00:
							switch(insn.rform.rD) {
								case 0x00: CEL = rA; break;
								case 0x01: CEH = rA; break;
							}
						break;
					// mfce{lh}! rA
					case 0x01:
							switch(insn.rform.rD) {
								case 0x00: rA = CEL; break;
								case 0x01: rA = CEH; break;
							}
						break;

					default: debugDump();
				}
			} break;
		case 0x02: {
				uint32_t &rA = g0[insn.rform.rA];
				uint32_t &rD = g0[insn.rform.rD];
				uint32_t &rAh = g0[insn.rhform.rA];
				uint32_t &rDh = g[insn.rhform.H][insn.rhform.rD];
				switch(insn.rform.func4) {
					// add! rDg0, rAg0
					case 0x00: rD = add(rD, rA, true); break;
					// sub! rDg0, rAg0
					case 0x01: rD = sub(rD, rA, true); break;
					// neg! rDg0, rAg0
					case 0x02: rD = sub(0, rA, true); break;
					// cmp! rDg0, rAg0
					case 0x03: sub(rD, rA, true); break;
					// and! rDg0, rAg0
					case 0x04: rD = bit_and(rD, rA, true); break;
					// or! rDg0, rAg0
					case 0x05: rD = bit_or(rD, rA, true); break;
					// not! rDg0, rAg0
					case 0x06: rD = bit_xor(rA, ~0, true); break;
					// xor! rDg0, rAg0
					case 0x07: rD = bit_xor(rD, rA, true); break;
					// lw! rDg0, [rAg0]
					case 0x08: rD = miu.readU32(rA); break;
					// lh! rDg0, [rAg0]
					case 0x09: rD = sign_extend(miu.readU16(rA), 16); break;
					// pop! rDgh, [rAg0]
					case 0x0A: rDh = miu.readU32(rAh); rAh += 4; break;
					// lbu! rDg0, [rAg0]
					case 0x0B: rD = miu.readU8(rA); break;
					// sw! rDg0, [rAg0]
					case 0x0C: miu.writeU32(rA, rD); break;
					// sh! rDg0, [rAg0]
					case 0x0D: miu.writeU16(rA, rD); break;
					// push! rDgh, [rAg0]
					case 0x0E: miu.writeU32(rAh -= 4, rDh); break;
					// sb! rDg0, [rAg0]
					case 0x0F: miu.writeU8(rA, rD); break;
				}
			} break;
		case 0x03:
				// j[l]! imm11
				jump(((pc & 0xFFFFF000) | (insn.jform.Disp11 << 1)) - 2, insn.jform.LK);
			break;
		case 0x04:
				// b{cond}! imm8
				branch(insn.bxform.EC, pc + (sign_extend(insn.bxform.Imm8, 8) << 1) - 2, false);
			break;
		case 0x05:
				// ldiu! imm8
				g0[insn.iform2.rD] = insn.iform2.Imm8;
			break;
		case 0x06: {
				uint32_t &rD = g0[insn.iform1.rD];
				uint32_t imm = 1 << insn.iform1.Imm5;
				switch(insn.iform1.func3) {
					// srli! rD, imm5
					case 0x03: rD = srl(rD, insn.iform1.Imm5, true); break;
					// bitclr! rD, imm5
					case 0x04: rD = bit_and(rD, ~imm, true); break;
					// bitset! rD, imm5
					case 0x05: rD = bit_or(rD, imm, true); break;
					// bittst! rD, imm5
					case 0x06: bit_and(rD, imm, true); break;

					default: debugDump();
				}
			} break;
		case 0x07: {
				uint32_t &rD = g0[insn.iform1.rD];
				switch(insn.iform1.func3) {
					// lwp! rDg0, imm
					case 0x00: rD = miu.readU32(r2 + (insn.iform1.Imm5 << 2)); break;
					// lbup! rDg0, imm
					case 0x01: rD = miu.readU8(r2 + insn.iform1.Imm5); break;

					// lhp! rDg0, imm
					case 0x03: rD = sign_extend(miu.readU8(r2 + (insn.iform1.Imm5 << 1)), 16); break;
					// swp! rDg0, imm
					case 0x04: miu.writeU32(r2 + (insn.iform1.Imm5 << 2), rD); break;
					// shp! rDg0, imm
					case 0x05: miu.writeU16(r2 + (insn.iform1.Imm5 << 1), rD); break;

					// sbp! rDg0, imm
					case 0x07: miu.writeU32(r2 + insn.iform1.Imm5, rD); break;

					default: debugDump();
				}
			} break;
		default: debugDump();
	}
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

template <typename Op >
void CPU::ce_op(uint32_t a, uint32_t b, Op op) {
	auto result = op(a, b);

	CEL = result & 0xFFFFFFFF;
	CEH = result >> 32;
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

uint32_t CPU::sll(uint32_t a, uint8_t sa, bool flags) {
	uint32_t res = a << sa;
	if(flags) {
		basic_flags(res);
		C = a & (1 << (32 - sa));
	}

	return res;
}

uint32_t CPU::srl(uint32_t a, uint8_t sa, bool flags) {
	uint32_t res = a >> sa;
	if(flags) {
		basic_flags(res);
		C = a & (1 << (sa - 1)); // XXX: Docs say this is right, but what if sa is 0?
	}

	return res;
}

uint32_t CPU::sra(uint32_t a, uint8_t sa, bool flags) {
	uint32_t res = int32_t(a) >> sa;
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

	FILE* memdump = fopen("MEMDUMP", "wb");
	for(int i=0; i<0x01000000; ++i)
		fputc(miu.readU8(0xA0000000 + i), memdump);
	fclose(memdump);

	exit(1);
}

}
