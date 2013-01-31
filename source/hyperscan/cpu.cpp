#include "cpu.h"

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

uint32_t CPU::bitset(uint32_t a, uint8_t bit, bool flags) {
	uint32_t res = a | (1 << bit);

	if(flags) {
		// XXX: Those aren't in docs, may be wrong
		N = (res >> 31);
		Z = (res >> bit) & 1; // Doesn't really make sense, it's ALWAYS set
	}

	return res;
}

uint32_t CPU::bitclr(uint32_t a, uint8_t bit, bool flags) {
	uint32_t res = a & ~(1 << bit);

	if(flags) {
		// XXX: Those aren't in docs, may be wrong
		N = (res >> 31);
		Z = (res >> bit) & 1; // Doesn't really make sense, it's NEVER set
	}

	return res;
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

void CPU::bittst(uint32_t a, uint8_t bit, bool flags) {
	if(!flags)
		return;

	N = (a >> 31);
	Z = (a >> bit) & 1;
}

}
