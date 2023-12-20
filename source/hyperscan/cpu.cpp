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
	reset_registers();
}

void CPU::reset_registers() {
	std::fill(r, r + 32, 0);
	std::fill(cr, cr + 32, 0);
	std::fill(sr, sr + 32, 0);

	CEH = 0;
	CEL = 0;

	pc = 0;
}

uint32_t CPU::step() {
	// Decode into a 32bit instruction or sequential/parallel 16bit instructions
	InstructionDecoder instruction = miu->readU32(pc);

	// We can only run a 16bit instruction when PC is non-word aligned
	if (pc & 2) {
		return pc += exec16<16>(instruction.low);
	}

	// XXX: (p0 & p1) vs p0?
	if (instruction.p0) {
		return pc += exec32((instruction.high << 15) | instruction.low);
	}

	Instruction16 insn16 = instruction.low;
	if (instruction.p1) {
		return pc += exec16<32>(T ? instruction.low : instruction.high);
	}

	return pc += exec16<16>(insn16);
}

void CPU::exception(uint8_t cause) {
	// Set cause in cr2
	cr2 &= ~0x00FC0000;
	cr2 |= (cause & 0x3F) << 18;

	// Save old PC
	cr5 = pc;

	// Jump
	pc = cr3 + (cause * 4);
}

void CPU::interrupt(uint8_t cause) {
	// Don't fire if interrupts are disabled
	if(!(cr0 & 1))
		return;

	exception((63 - cause) + 128);
}

template <int I>
uint32_t CPU::branch(uint8_t condition, uint32_t address, bool link) {
	if (conditional(condition, true)) {
		return jump<I>(address, link);
	}

	return I / 8;
}

template <int I>
uint32_t CPU::jump(uint32_t address, bool link) {
	if (link)
		r3 = pc + (I / 8);

	pc = address;

	return 0;
}

uint32_t CPU::exec32(const Instruction32 &insn) {
	switch(insn.OP) {
		case 0x00: {
				uint32_t &rD = r[insn.spform.rD];
				uint32_t &rA = r[insn.spform.rA];
				uint32_t &rB = r[insn.spform.rB];
				switch(insn.spform.func6) {
					// nop
					case 0x00: /* nothing */ break;

					// br{cond}[l] rA
					case 0x04: return branch<32>(insn.spform.rB, rA, insn.spform.CU);

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
					// cmpz{tcs}.c rA
					case 0x0D:      cmp(rA, 0, insn.spform.rD & 0x03, insn.spform.CU); break;

					// neg[.c] rD, rA
					case 0x0F: rD = sub(0, rB, insn.spform.CU); break;
					// and[.c] rD, rA, rB
					case 0x10: rD = bit_op(rA, rB, insn.spform.CU, std::bit_and()); break;
					// or[.c] rD, rA, rB
					case 0x11: rD = bit_op(rA, rB, insn.spform.CU, std::bit_or()); break;
					// not[.c] rD, rA
					case 0x12: rD = bit_op(rA, ~0, insn.spform.CU, std::bit_xor()); break;
					// xor[.c] rD, rA, rB
					case 0x13: rD = bit_op(rA, rB, insn.spform.CU, std::bit_xor()); break;
					// bitclr[.c] rD, rA, imm5
					case 0x14: rD = bit_op(rA, ~(1 << insn.spform.rB), insn.spform.CU, std::bit_and()); break;
					// bitset[.c] rD, rA, imm5
					case 0x15: rD = bit_op(rA, 1 << insn.spform.rB, insn.spform.CU, std::bit_or()); break;
					// bittst.c rA, imm5
					case 0x16:      bit_op(rA, 1 << insn.spform.rB, insn.spform.CU, std::bit_and()); break;
					// bittgl[.c] rA, imm5
					case 0x17: rD = bit_op(rA, 1 << insn.spform.rB, insn.spform.CU, std::bit_xor()); break;
					// sll[.c] rA, imm5
					case 0x18: rD = sll(rA, rB, insn.spform.CU); break;
					// srl[.c] rA, imm5
					case 0x1A: rD = srl(rA, rB, insn.spform.CU); break;
					// sra[.c] rA, imm5
					case 0x1B: rD = sra(rA, rB, insn.spform.CU); break;

					// mul rA, rB
					case 0x20: CE = std::multiplies<int64_t>()(rA, rB); break;
					// mulu rA, rB
					case 0x21: CE = std::multiplies<uint64_t>()(rA, rB); break;
					// div rA, rB
					case 0x22: CEL = std::divides<int64_t>()(rA, rB); CEH = std::modulus<int64_t>()(rA, rB); break;
					// divu rA, rB
					case 0x23: CEL = std::divides<uint64_t>()(rA, rB); CEH = std::modulus<uint64_t>()(rA, rB); break;

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

					// mfsr rD srB
					case 0x28: rD = sr[insn.spform.rB]; break;
					// mtsr rA, srB
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
					case 0x2E: rD = bit_op(rA, 0x000000FF, insn.spform.CU, std::bit_and()); break;
					// extzh[.c] rD, rA
					case 0x2F: rD = bit_op(rA, 0x0000FFFF, insn.spform.CU, std::bit_and()); break;

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
					case 0x04: rD = bit_op(rD, insn.iform.Imm16, insn.iform.CU, std::bit_and()); break;
					// ori.c rD, imm16
					case 0x05: rD = bit_op(rD, insn.iform.Imm16, insn.iform.CU, std::bit_or()); break;
					// ldi rD, imm16
					case 0x06: rD = sign_extend(insn.iform.Imm16, 16); break;

					default: debugDump();
				}
			} break;
		case 0x02:
				// j[l] imm24
				return jump<32>(((pc & 0xFE000000) | (insn.jform.Disp24 << 1)), insn.jform.LK);
		case 0x03: {
				uint32_t &rD = r[insn.rixform.rD];
				uint32_t &rA = r[insn.rixform.rA];

				// Pre-increment
				rA += sign_extend(insn.rixform.Imm12, 12);
				switch(insn.rixform.func3) {
					// lw rD, [rA, imm12]+
					case 0x00: rD = miu->readU32(rA); break;
					// lh rD, [rA, imm12]+
					case 0x01: rD = sign_extend(miu->readU16(rA), 16); break;
					// lhu rD, [rA, imm12]+
					case 0x02: rD = miu->readU16(rA); break;
					// lb rD, [rA, imm12]+
					case 0x03: rD = sign_extend(miu->readU8(rA), 8); break;
					// sw rD, [rA, imm12]+
					case 0x04: miu->writeU32(rA, rD); break;
					// sh rD, [rA, imm12]+
					case 0x05: miu->writeU16(rA, rD); break;
					// lbu rD, [rA, imm12]+
					case 0x06: rD = miu->readU8(rA); break;
					// sb rD, [rA, imm12]+
					case 0x07: miu->writeU8(rA, rD); break;

					default: debugDump();
				}
			} break;
		case 0x04: {
				// b{cond}[l]
				int32_t disp = sign_extend(((insn.bcform.Disp18_9 << 9) | insn.bcform.Disp8_0) << 1, 20);
				return branch<32>(insn.bcform.BC, pc + disp, insn.bcform.LK);
			}
		case 0x05: {
				uint32_t &rD = r[insn.iform.rD];
				uint32_t imm16 = insn.iform.Imm16 << 16;
				switch(insn.iform.func3) {
					// addis[.c] rD, imm16
					case 0x00: rD = add(rD, imm16, insn.iform.CU); break;
					// cmpis.c rD, imm16
					case 0x02:      cmp(rD, imm16, 3, insn.iform.CU); break;
					// andis.c rD, imm16
					case 0x04: rD = bit_op(rD, imm16, insn.iform.CU, std::bit_and()); break;
					// oris.c rD, imm16
					case 0x05: rD = bit_op(rD, imm16, insn.iform.CU, std::bit_or()); break;
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
					case 0x84: return jump<32>(cr5, false); /* TODO: missing PSR */

					default: debugDump();
				}
			} break;
		case 0x07: {
				uint32_t &rD = r[insn.rixform.rD];
				uint32_t &rA = r[insn.rixform.rA];
				switch(insn.rixform.func3) {
					// lw rD, [rA]+, imm12
					case 0x00: rD = miu->readU32(rA); break;
					// lh rD, [rA]+, imm12
					case 0x01: rD = sign_extend(miu->readU16(rA), 16); break;
					// lhu rD, [rA]+, imm12
					case 0x02: rD = miu->readU16(rA); break;
					// lb rD, [rA]+, imm12
					case 0x03: rD = sign_extend(miu->readU8(rA), 8); break;
					// sw rD, [rA]+, imm12
					case 0x04: miu->writeU32(rA, rD); break;
					// sh rD, [rA]+, imm12
					case 0x05: miu->writeU16(rA, rD); break;
					// lbu rD, [rA]+, imm12
					case 0x06: rD = miu->readU8(rA); break;
					// sb rD, [rA]+, imm12
					case 0x07: miu->writeU8(rA, rD); break;

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

				rD = bit_op(rA, imm14, insn.riform.CU, std::bit_and());
			} break;
		case 0x0D: {
				// orri[.c] rD, rA, imm14
				uint32_t &rD = r[insn.riform.rD];
				uint32_t &rA = r[insn.riform.rA];
				uint32_t imm14 = insn.riform.Imm14;

				rD = bit_op(rA, imm14, insn.riform.CU, std::bit_or());
			} break;
		case 0x10: {
				// lw rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu->readU32(rA + imm15);
			} break;
		case 0x11: {
				// lh rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = sign_extend(miu->readU16(rA + imm15), 16);
			} break;
		case 0x12: {
				// lhu rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu->readU16(rA + imm15);
			} break;
		case 0x13: {
				// lb rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = sign_extend(miu->readU8(rA + imm15), 8);
			} break;
		case 0x14: {
				// sw rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu->writeU32(rA + imm15, rD);
			} break;
		case 0x15: {
				// sh rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu->writeU16(rA + imm15, rD);
			} break;
		case 0x16: {
				// lbu rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				rD = miu->readU8(rA + imm15);
			} break;
		case 0x17: {
				// sb rD, [rA, imm15]
				uint32_t &rD = r[insn.mform.rD];
				uint32_t &rA = r[insn.mform.rA];
				int32_t imm15 = sign_extend(insn.mform.Imm15, 15);

				miu->writeU8(rA + imm15, rD);
			} break;
		case 0x18:
				// cache op, [rA, imm15]
			break;
		default: debugDump();
	}

	return 32 / 8;
}

template <int I>
uint32_t CPU::exec16(const Instruction16 &insn) {
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
					case 0x04: return branch<I>(insn.rform.rD, g0[insn.rform.rA], false);
					// t{cond}!
					case 0x05: T = conditional(insn.rform.rD); break;
					// br{cond}l! rAg0
					case 0x0C: return branch<I>(insn.rform.rD, g0[insn.rform.rA], true);

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
					case 0x04: rD = bit_op(rD, rA, true, std::bit_and()); break;
					// or! rDg0, rAg0
					case 0x05: rD = bit_op(rD, rA, true, std::bit_or()); break;
					// not! rDg0, rAg0
					case 0x06: rD = bit_op(rA, ~0, true, std::bit_xor()); break;
					// xor! rDg0, rAg0
					case 0x07: rD = bit_op(rD, rA, true, std::bit_xor()); break;
					// lw! rDg0, [rAg0]
					case 0x08: rD = miu->readU32(rA); break;
					// lh! rDg0, [rAg0]
					case 0x09: rD = sign_extend(miu->readU16(rA), 16); break;
					// pop! rDgh, [rAg0]
					case 0x0A: rDh = miu->readU32(rAh); rAh += 4; break;
					// lbu! rDg0, [rAg0]
					case 0x0B: rD = miu->readU8(rA); break;
					// sw! rDg0, [rAg0]
					case 0x0C: miu->writeU32(rA, rD); break;
					// sh! rDg0, [rAg0]
					case 0x0D: miu->writeU16(rA, rD); break;
					// push! rDgh, [rAg0]
					case 0x0E: miu->writeU32(rAh -= 4, rDh); break;
					// sb! rDg0, [rAg0]
					case 0x0F: miu->writeU8(rA, rD); break;
				}
			} break;
		case 0x03:
				// j[l]! imm11
				return jump<I>(((pc & 0xFFFFF000) | (insn.jform.Disp11 << 1)), insn.jform.LK);
		case 0x04:
				// b{cond}! imm8
				return branch<I>(insn.bxform.EC, pc + (sign_extend(insn.bxform.Imm8, 8) << 1), false);
		case 0x05:
				// ldiu! rD, imm8
				g0[insn.iform2.rD] = insn.iform2.Imm8;
			break;
		case 0x06: {
				uint32_t &rD = g0[insn.iform1.rD];
				uint32_t imm = 1 << insn.iform1.Imm5;
				switch(insn.iform1.func3) {
					// srli! rD, imm5
					case 0x03: rD = srl(rD, insn.iform1.Imm5, true); break;
					// bitclr! rD, imm5
					case 0x04: rD = bit_op(rD, ~imm, true, std::bit_and()); break;
					// bitset! rD, imm5
					case 0x05: rD = bit_op(rD, imm, true, std::bit_or()); break;
					// bittst! rD, imm5
					case 0x06:      bit_op(rD, imm, true, std::bit_and()); break;

					default: debugDump();
				}
			} break;
		case 0x07: {
				uint32_t &rD = g0[insn.iform1.rD];
				switch(insn.iform1.func3) {
					// lwp! rDg0, imm
					case 0x00: rD = miu->readU32(r2 + (insn.iform1.Imm5 << 2)); break;
					// lhp! rDg0, imm
					case 0x01: rD = miu->readU16(r2 + (insn.iform1.Imm5 << 1)); break;
					// lbup! rDg0, imm
					case 0x03: rD = miu->readU8(r2 + insn.iform1.Imm5); break;
					// swp! rDg0, imm
					case 0x04: miu->writeU32(r2 + (insn.iform1.Imm5 << 2), rD); break;
					// shp! rDg0, imm
					case 0x05: miu->writeU16(r2 + (insn.iform1.Imm5 << 1), rD); break;
					// sbp! rDg0, imm
					case 0x07: miu->writeU8(r2 + insn.iform1.Imm5, rD); break;

					default: debugDump();
				}
			} break;
		default: debugDump();
	}

	return I / 8;
}

bool CPU::conditional(uint8_t pattern, bool cnt) {
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
		case 0xE: return CNT && (CNT -= cnt) > 0;
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
	return sub(sub(a, b, false), !C, flags);
}

template <typename Op >
uint32_t CPU::bit_op(uint32_t a, uint32_t b, bool flags, Op op) {
    uint32_t res = op(a, b);
    if(flags) {
        basic_flags(res);
    }

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
		fputc(miu->readU8(0xA0000000 + i), memdump);
	fclose(memdump);

	exit(1);
}

}
