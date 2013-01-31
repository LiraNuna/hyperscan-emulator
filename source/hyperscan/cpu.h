#include <stdint.h>
#include <algorithm>

#ifndef __HYPERSCAN_CPU_H__
#define __HYPERSCAN_CPU_H__

namespace hyperscan {

class CPU {
	public:
		CPU();

		void reset();

		void reset_flags();

		void reset_registers();

		void basic_flags(uint32_t res);

		uint32_t add(uint32_t a, uint32_t b, bool flags);

		uint32_t addc(uint32_t a, uint32_t b, bool flags);

		uint32_t sub(uint32_t a, uint32_t b, bool flags);

		uint32_t bit_and(uint32_t a, uint32_t b, bool flags);

		uint32_t bit_or(uint32_t a, uint32_t b, bool flags);

		uint32_t shift_left(uint32_t a, uint8_t sa, bool flags);

		uint32_t shift_right(uint32_t a, uint8_t sa, bool flags);

		uint32_t bitset(uint32_t a, uint8_t bit, bool flags);

		uint32_t bitclr(uint32_t a, uint8_t bit, bool flags);

		void cmp(uint32_t a, uint32_t b, int tcs=3, bool flags=true);

		void bittst(uint32_t a, uint8_t bit, bool flags=true);

		bool conditional(uint8_t pattern) const;

	public:
		// Registers
		union {
			struct {
				union {
					struct {
						uint32_t  r0,  r1,  r2,  r3;
						uint32_t  r4,  r5,  r6,  r7;
						uint32_t  r8,  r9, r10, r11;
						uint32_t r12, r13, r14, r15;
					};

					uint32_t g0[16];
				};

				union {
					struct {
						uint32_t r16, r17, r18, r19;
						uint32_t r20, r21, r22, r23;
						uint32_t r24, r25, r26, r27;
						uint32_t r28, r29, r30, r31;
					};

					uint32_t g1[16];
				};
			};

			uint32_t r[32];
			uint32_t g[2][16];
		};

		// Control registers
		union {
			struct {
				uint32_t  cr0,  cr1,  cr2,  cr3;
				uint32_t  cr4,  cr5,  cr6,  cr7;
				uint32_t  cr8,  cr9, cr10, cr11;
				uint32_t cr12, cr13, cr14, cr15;
				uint32_t cr16, cr17, cr18, cr19;
				uint32_t cr20, cr21, cr22, cr23;
				uint32_t cr24, cr25, cr26, cr27;
				uint32_t cr28, cr29, cr30, cr31;
			};

			uint32_t cr[32];
		};

		// Flags
		bool N, Z, C, V, T;

		// Program Counter
		uint32_t pc;
};

}

#endif
