#include "disasm.h"

#include <iomanip>
#include <sstream>

using namespace hyperscan;

const char *REGISTERS[] = {
		"r0", "r1", "r2", "r3",
		"r4", "r5", "r6", "r7",
		"r8", "r9", "r10", "r11",
		"r12", "r13", "r14", "r15",
		"r16", "r17", "r18", "r19",
		"r20", "r21", "r22", "r23",
		"r24", "r25", "r26", "r27",
		"r28", "r29", "r30", "r31",
};

const char *CONDITIONALS[] = {
		"cs", "cc",
		"gtu", "leu",
		"eq", "ne",
		"gt", "le",
		"ge", "lt",
		"mi", "pl",
		"vs", "vc",
		"cnz", "",
};

const char *TCS[] = {
		"teq", "tmi",
		"", "",
};

int32_t sign_extend(uint32_t x, uint8_t b) {
	uint32_t m = 1UL << (b - 1);

	x = x & ((1UL << b) - 1);
	return (x ^ m) - m;
}

std::string op(const char *str) {
	return str;
}

std::string opb(const char *str, int cond = 15, bool link = false) {
	std::string r = op(str);
	r += CONDITIONALS[cond];
	if (link) r += "l";
	return r;
}

std::string opl(const char *str, bool link) {
	return opb(str, 15, link);
}

std::string opc(const char *str, bool c) {
	std::string r = op(str);
	if (c) r += ".c";
	return r;
}

std::string opt(const char *str, int tcs, bool c) {
	std::string r = op(str);
	r += TCS[tcs];
	if (c) r += ".c";
	return r;
}

std::string reg(int rg, const std::string &prefix = "") {
	std::string r = "\033[33m";
	r += prefix;
	r += REGISTERS[rg];
	r += "\033[39m";
	if (rg == 2) r += "\033[27m";
	return r;
}

std::string imm(const std::string &imm) {
	return "\033[95m" + imm + "\033[39m";
}

std::string immd(int i) {
	return imm(std::to_string(i));
}

std::string immx16(int i) {
	std::stringstream ha;
	ha << "0x" << std::hex << i;

	return imm(ha.str());
}

std::string immx32(int i) {
	std::stringstream ha;
	ha << "0x" << std::setfill('0') << std::setw(8) << std::hex << i;
	return imm(ha.str());
}

std::string mem(const std::string &str) {
	return "[" + str + "]";
}

std::string memoff(int r, int off) {
	return mem(reg(r) + ", " + immd(off));
}

void unknown() {
	printf("<unknown op>");
}

void ins(const std::string &insn) {
	printf("%-16s", insn.c_str());
}

void ins(const std::string &insn, const std::string &arg1) {
	printf("%-16s %s", insn.c_str(), arg1.c_str());
}

void ins(const std::string &insn, const std::string &arg1, const std::string &arg2) {
	printf("%-16s %s, %s", insn.c_str(), arg1.c_str(), arg2.c_str());
}

void ins(const std::string &insn, const std::string &arg1, const std::string &arg2, const std::string &arg3) {
	printf("%-16s %s, %s, %s", insn.c_str(), arg1.c_str(), arg2.c_str(), arg3.c_str());
}

void disasm32(const CPU::Instruction32 &insn, uint32_t address) {
	printf("\033[s%32s\033[u", "");

	switch (insn.OP) {
		case 0x00:
			switch (insn.spform.func6) {
				case 0x00:
					return ins(
							op("nop"));
				case 0x04:
					return ins(
							opb("br", insn.spform.rB, insn.spform.CU),
							reg(insn.spform.rA));
				case 0x08:
					return ins(
							opc("add", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x09:
					return ins(
							opc("addc", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x0A:
					return ins(
							opc("sub", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x0B:
					return ins(
							opc("subc", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x0C:
					return ins(
							opt("cmp", insn.spform.rD, insn.spform.CU),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x0D:
					return ins(
							opt("cmpz", insn.spform.rD, insn.spform.CU),
							reg(insn.spform.rA));
				case 0x0F:
					return ins(
							opc("neg", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA));
				case 0x10:
					return ins(
							opc("and", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x11:
					return ins(
							opc("or", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x12:
					return ins(
							opc("not", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA));
				case 0x13:
					return ins(
							opc("xor", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x14:
					return ins(
							opc("bitclr", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							immd(insn.spform.rB));
				case 0x15:
					return ins(
							opc("bitset", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							immd(insn.spform.rB));
				case 0x16:
					return ins(
							opc("bittst", insn.spform.CU),
							reg(insn.spform.rA),
							immd(insn.spform.rB));
				case 0x17:
					return ins(
							opc("bittgl", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							immd(insn.spform.rB));
				case 0x18:
					return ins(
							opc("sll", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x1A:
					return ins(
							opc("srl", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x1B:
					return ins(
							opc("sra", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x20:
					return ins(
							opc("mul", insn.spform.CU),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x21:
					return ins(
							opc("mulu", insn.spform.CU),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x22:
					return ins(
							opc("div", insn.spform.CU),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x23:
					return ins(
							opc("divu", insn.spform.CU),
							reg(insn.spform.rA),
							reg(insn.spform.rB));
				case 0x24:
					switch (insn.spform.rB) {
						case 0x01:
							return ins(op("mfcel"), reg(insn.spform.rD));
						case 0x02:
							return ins(op("mfceh"), reg(insn.spform.rD));
						case 0x03:
							return ins(op("mfcehl"), reg(insn.spform.rD), reg(insn.spform.rA));
						default:
							return unknown();
					}
				case 0x25:
					switch (insn.spform.rB) {
						case 0x01:
							return ins(op("mtcel"), reg(insn.spform.rD));
						case 0x02:
							return ins(op("mtceh"), reg(insn.spform.rD));
						case 0x03:
							return ins(op("mtcehl"), reg(insn.spform.rD), reg(insn.spform.rA));
						default:
							return unknown();
					}
				case 0x28:
					return ins(op("mfsr"),
					           reg(insn.spform.rD),
					           reg(insn.spform.rB, "s"));
				case 0x29:
					return ins(op("mtsr"),
					           reg(insn.spform.rA),
					           reg(insn.spform.rB, "s"));
				case 0x2A:
					return ins(
							opb("t", insn.spform.rB));
				case 0x2B:
					return ins(
							opb("mv", insn.spform.rB),
							reg(insn.spform.rD),
							reg(insn.spform.rA));
				case 0x2C:
					return ins(
							opc("extsb", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA));
				case 0x2D:
					return ins(
							opc("extsh", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA));
				case 0x2E:
					return ins(
							opc("extzb", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA));
				case 0x2F:
					return ins(
							opc("extzh", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA));
				case 0x38:
					return ins(
							opc("slli", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							immd(insn.spform.rB));
				case 0x3A:
					return ins(
							opc("srli", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							immd(insn.spform.rB));
				case 0x3B:
					return ins(
							opc("srai", insn.spform.CU),
							reg(insn.spform.rD),
							reg(insn.spform.rA),
							immd(insn.spform.rB));

				default:
					return unknown();
			}
		case 0x01:
			switch (insn.iform.func3) {
				case 0x00:
					return ins(
							opc("addi", insn.iform.CU),
							reg(insn.iform.rD),
							immd(sign_extend(insn.iform.Imm16, 16)));
				case 0x02:
					return ins(
							opc("cmpi", insn.iform.CU),
							reg(insn.iform.rD),
							immd(sign_extend(insn.iform.Imm16, 16)));
				case 0x04:
					return ins(
							opc("andi", insn.iform.CU),
							reg(insn.iform.rD),
							immx16(insn.iform.Imm16));
				case 0x05:
					return ins(
							opc("ori", insn.iform.CU),
							reg(insn.iform.rD),
							immx16(insn.iform.Imm16));
				case 0x06:
					return ins(
							op("ldi"),
							reg(insn.iform.rD),
							immd(sign_extend(insn.iform.Imm16, 16)));
				default:
					return unknown();
			}
		case 0x02:
			return ins(
					opl("j", insn.jform.LK),
					immx32((address & 0xFC000000) | (insn.jform.Disp24 << 1)));
		case 0x03:
			switch (insn.rixform.func3) {
				case 0x00:
					return ins(
							op("lw"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				case 0x01:
					return ins(
							op("lh"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				case 0x02:
					return ins(
							op("lhu"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				case 0x03:
					return ins(
							op("lb"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				case 0x04:
					return ins(
							op("sw"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				case 0x05:
					return ins(
							op("sh"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				case 0x06:
					return ins(
							op("lbu"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				case 0x07:
					return ins(
							op("sb"),
							reg(insn.rixform.rD),
							memoff(insn.rixform.rA, sign_extend(insn.rixform.Imm12, 12)) + "+");
				default:
					return unknown();
			}
		case 0x04:
			return ins(
					opb("b", insn.bcform.BC, insn.bcform.LK),
					immx32(address + sign_extend(((insn.bcform.Disp18_9 << 9) | insn.bcform.Disp8_0) << 1, 20)));
		case 0x05:
			switch (insn.iform.func3) {
				case 0x00:
					return ins(
							opc("addis", insn.iform.CU),
							reg(insn.iform.rD),
							immx32(insn.iform.Imm16 << 16));
				case 0x02:
					return ins(
							opc("cmpis", insn.iform.CU),
							reg(insn.iform.rD),
							immx32(insn.iform.Imm16 << 16));
				case 0x04:
					return ins(
							opc("andis", insn.iform.CU),
							reg(insn.iform.rD),
							immx32(insn.iform.Imm16 << 16));
				case 0x05:
					return ins(
							opc("oris", insn.iform.CU),
							reg(insn.iform.rD),
							immx32(insn.iform.Imm16 << 16));
				case 0x06:
					return ins(
							opc("ldis", insn.iform.CU),
							reg(insn.iform.rD),
							immx32(insn.iform.Imm16 << 16));
				default:
					return unknown();
			}
		case 0x06: {
			switch (insn.crform.CR_OP) {
				case 0x00:
					return ins(
							op("mtcr"),
							reg(insn.crform.rD),
							reg(insn.crform.crA, "c"));
				case 0x01:
					return ins(
							op("mfcr"),
							reg(insn.crform.rD),
							reg(insn.crform.crA, "c"));
				case 0x84:
					return ins(op("rte"));
				default:
					return unknown();
			}
		}
		case 0x07: {
			int16_t imm12 = sign_extend(insn.rixform.Imm12, 12);
			switch (insn.rixform.func3) {
				case 0x00:
					return ins(
							op("lw"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				case 0x01:
					return ins(
							op("lh"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				case 0x02:
					return ins(
							op("lhu"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				case 0x03:
					return ins(
							op("lb"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				case 0x04:
					return ins(
							op("sw"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				case 0x05:
					return ins(
							op("sh"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				case 0x06:
					return ins(
							op("lbu"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				case 0x07:
					return ins(
							op("sb"),
							reg(insn.rixform.rD),
							mem(reg(insn.rixform.rA)) + "+",
							immd(imm12));
				default:
					return unknown();
			}
		}
		case 0x08:
			return ins(
					opc("addri", insn.riform.CU),
					reg(insn.riform.rD),
					reg(insn.riform.rA),
					immd(sign_extend(insn.riform.Imm14, 14)));
		case 0x0C:
			return ins(
					opc("andri", insn.riform.CU),
					reg(insn.riform.rD),
					reg(insn.riform.rA),
					immx16(insn.riform.Imm14));
		case 0x0D:
			return ins(
					opc("orri", insn.riform.CU),
					reg(insn.riform.rD),
					reg(insn.riform.rA),
					immx16(insn.riform.Imm14));
		case 0x10:
			return ins(
					op("lw"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x11:
			return ins(
					op("lh"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x12:
			return ins(
					op("lhu"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x13:
			return ins(
					op("lb"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x14:
			return ins(
					op("sw"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x15:
			return ins(
					op("sh"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x16:
			return ins(
					op("lbu"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x17:
			return ins(
					op("sb"),
					reg(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		case 0x18:
			return ins(
					op("cache"),
					immd(insn.mform.rD),
					memoff(insn.mform.rA, sign_extend(insn.mform.Imm15, 15)));
		default:
			return unknown();
	}
}

void disasm16(const CPU::Instruction16 &insn, uint32_t address) {
	switch (insn.OP) {
		case 0x00:
			switch (insn.rform.func4) {
				case 0x00:
					return ins(op("nop!"));
				case 0x01:
					return ins(op("mlfh!"), reg(insn.rform.rD), reg(insn.rform.rA + 16));
				case 0x02:
					return ins(op("mhfl!"), reg(insn.rform.rD + 16), reg(insn.rform.rA));
				case 0x03:
					return ins(op("mv!"), reg(insn.rform.rD), reg(insn.rform.rA));
				case 0x04:
					return ins(opb("br", insn.rform.rD, false) + "!", reg(insn.rform.rA));
				case 0x05:
					return ins(opb("t", insn.rform.rD) + "!");
				case 0x0C:
					return ins(opb("br", insn.rform.rD, true) + "!", reg(insn.rform.rA));

				default:
					return unknown();
			}
		case 0x01:
			switch (insn.rform.func4) {
				case 0x00:
					// mtce{lh}! rA
					switch (insn.rform.rD) {
						case 0x00:
							return ins(op("mtcel!"), reg(insn.rform.rA));
						case 0x01:
							return ins(op("mtceh!"), reg(insn.rform.rA));
						default:
							return unknown();
					}
				case 0x01:
					// mfce{lh}! rA
					switch (insn.rform.rD) {
						case 0x00:
							return ins(op("mfcel!"), reg(insn.rform.rA));
						case 0x01:
							return ins(op("mfceh!"), reg(insn.rform.rA));
						default:
							return unknown();
					}

				default:
					return unknown();
			}
		case 0x02:
			switch (insn.rform.func4) {
				case 0x00:
					return ins(
							op("add!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x01:
					return ins(
							op("sub!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x02:
					return ins(
							op("neg!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x03:
					return ins(
							op("cmp!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x04:
					return ins(
							op("and!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x05:
					return ins(
							op("or!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x06:
					return ins(
							op("not!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x07:
					return ins(
							op("xor!"),
							reg(insn.rform.rD),
							reg(insn.rform.rA));
				case 0x08:
					return ins(
							op("lw!"),
							reg(insn.rform.rD),
							mem(reg(insn.rform.rA)));
				case 0x09:
					return ins(
							op("lh!"),
							reg(insn.rform.rD),
							mem(reg(insn.rform.rA)));
				case 0x0A:
					return ins(
							op("pop!"),
							reg(insn.rhform.rD + (insn.rhform.H * 16)),
							mem(reg(insn.rhform.rA)));
				case 0x0B:
					return ins(
							op("lbu!"),
							reg(insn.rform.rD),
							mem(reg(insn.rform.rA)));
				case 0x0C:
					return ins(
							op("sw!"),
							reg(insn.rform.rD),
							mem(reg(insn.rform.rA)));
				case 0x0D:
					return ins(
							op("sh!"),
							reg(insn.rform.rD),
							mem(reg(insn.rform.rA)));
				case 0x0E:
					return ins(
							op("push!"),
							reg(insn.rhform.rD + (insn.rhform.H * 16)),
							mem(reg(insn.rhform.rA)));
				case 0x0F:
					return ins(
							op("sb!"),
							reg(insn.rform.rD),
							mem(reg(insn.rform.rA)));
			}
		case 0x03:
			return ins(
					opl("j", insn.jform.LK) + "!",
					immx32((address & 0xFFFFF000) | (insn.jform.Disp11 << 1)));
		case 0x04:
			return ins(
					opb("b", insn.bxform.EC) + "!",
					immx32(address + (sign_extend(insn.bxform.Imm8, 8) << 1)));
		case 0x05:
			return ins(
					op("ldui!"),
					reg(insn.iform2.rD),
					immx16(insn.iform2.Imm8));
		case 0x06:
			switch (insn.iform1.func3) {
				case 0x03:
					return ins(
							op("srli!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5));
				case 0x04:
					return ins(
							op("bitclr!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5));
				case 0x05:
					return ins(
							op("bitset!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5));
				case 0x06:
					return ins(
							op("bittst!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5));

				default:
					return unknown();
			}
		case 0x07:
			switch (insn.iform1.func3) {
				case 0x00:
					return ins(
							op("lwp!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5 << 2));
				case 0x01:
					return ins(
							op("lhp!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5 << 1));
				case 0x03:
					return ins(
							op("lbup!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5));
				case 0x04:
					return ins(
							op("swp!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5 << 2));
				case 0x05:
					return ins(
							op("shp!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5 << 1));
				case 0x07:
					return ins(
							op("sbp!"),
							reg(insn.iform1.rD),
							immd(insn.iform1.Imm5));

				default:
					return unknown();
			}

		default:
			return unknown();
	}
}
