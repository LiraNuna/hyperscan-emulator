#include <stdint.h>
#include <algorithm>

#include "memory/segmentedmemoryregion.h"

#ifndef __HYPERSCAN_CPU_H__
#define __HYPERSCAN_CPU_H__

namespace hyperscan {

class CPU {
	protected:
		union Instruction32 {
			Instruction32(uint32_t encoded):
				encoded(encoded) {

			}

			// OP = 0x02
			struct jform {
				uint32_t LK			:  1;
				uint32_t Disp24		: 24;
				uint32_t OP			:  5;
			} jform;

			// OP = 0x04
			struct bcform {
				uint32_t LK			:  1;
				uint32_t Disp8_0	:  9;
				uint32_t BC			:  5;
				uint32_t Disp18_9	: 10;
				uint32_t OP			:  5;
			} bcform;

			// OP = 0x00
			struct spform {
				uint32_t CU			:  1;
				uint32_t func6		:  6;
				uint32_t 			:  3;
				uint32_t rB			:  5;
				uint32_t rA			:  5;
				uint32_t rD			:  5;
				uint32_t OP			:  5;
			} spform;

			// OP = 0x01, 0x05
			struct iform {
				uint32_t CU			:  1;
				uint32_t Imm16		: 16;
				uint32_t func3		:  3;
				uint32_t rD			:  5;
				uint32_t OP			:  5;
			} iform;

			struct riform {
				uint32_t CU			:  1;
				uint32_t Imm14		: 14;
				uint32_t rA			:  5;
				uint32_t rD			:  5;
				uint32_t OP			:  5;
			} riform;

			struct rixform {
				uint32_t func3		:  3;
				uint32_t Imm12		: 12;
				uint32_t rA			:  5;
				uint32_t rD			:  5;
				uint32_t OP			:  5;
			} rixform;

			// Not in docs - 'memory' form
			struct mform {
				uint32_t Imm15      : 15;
				uint32_t rA         :  5;
				uint32_t rD         :  5;
				uint32_t OP         :  5;
			} mform;

			// TODO: CENew
			// TODO: CR-form

			struct crform {
				uint32_t CR_OP      :  8;
				uint32_t            :  7;
				uint32_t crA        :  5;
				uint32_t rD         :  5;
				uint32_t OP         :  5;
			} crform;

			// TODO: ldc/stc
			// TODO: cop

			struct {
				uint32_t			: 25;
				uint32_t OP			:  5;
			};

			uint32_t encoded;
		};

		union Instruction16 {
			Instruction16(uint16_t encoded):
				encoded(encoded) {

			}

			struct bxform {
				uint16_t Imm8		:  8;
				uint16_t EC			:  4;
				uint16_t OP			:  3;
			} bxform;

			struct jform {
				uint16_t LK			:  1;
				uint16_t Disp11		: 11;
				uint16_t OP			:  3;
			} jform;

			struct rform {
				uint16_t func4		:  4;
				uint16_t rA			:  4;
				uint16_t rD			:  4;
				uint16_t OP			:  3;
			} rform;

			// Not in docs. rDh access
			struct rhform {
				uint16_t func4		:  4;
				uint16_t rA			:  3;
				uint16_t H          :  1;
				uint16_t rD			:  4;
				uint16_t OP			:  3;
			} rhform;

			struct iform1 {
				uint16_t func3		:  3;
				uint16_t Imm5		:  5;
				uint16_t rD			:  4;
				uint16_t OP			:  3;
			} iform1;

			struct iform2 {
				uint16_t Imm8		:  8;
				uint16_t rD			:  4;
				uint16_t OP			:  3;
			} iform2;

			struct {
				uint32_t			: 12;
				uint32_t OP			:  3;
			};

			uint16_t encoded;
		};

	public:
		CPU();

		/**
		 * Reset the CPU
		 */
		void reset();

		/**
		 * Reset all CPU flags
		 */
		void reset_flags();

		/**
		 * Reset all CPU registers
		 */
		void reset_registers();

		/**
		 * Runs a single instruction from PC
		 * Advances PC and updates flags according to instruction
		 */
		void step();

		/**
		 * Causes an interrupt to fire
		 */
		void interrupt(uint8_t cause);

	protected:
		void exec16(const Instruction16 &insn);

		void exec32(const Instruction32 &insn);

		void branch(uint32_t address, bool link);

		void link();

		bool conditional(uint8_t pattern) const;

		void basic_flags(uint32_t res);

		void cmp(uint32_t a, uint32_t b, int tcs=3, bool flags=true);

		uint32_t add(uint32_t a, uint32_t b, bool flags);

		uint32_t addc(uint32_t a, uint32_t b, bool flags);

		uint32_t sub(uint32_t a, uint32_t b, bool flags);

		uint32_t subc(uint32_t a, uint32_t b, bool flags);

		uint32_t bit_and(uint32_t a, uint32_t b, bool flags);

		uint32_t bit_or(uint32_t a, uint32_t b, bool flags);

		uint32_t bit_xor(uint32_t a, uint32_t b, bool flags);

		uint32_t sll(uint32_t a, uint8_t sa, bool flags);

		uint32_t srl(uint32_t a, uint8_t sa, bool flags);

		uint32_t sra(uint32_t a, uint8_t sa, bool flags);

	private:
		void debugDump();

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

		// Special registers
		union {
			struct {
				uint32_t sr0, sr1, sr2;
			};

			struct {
				uint32_t CNT, LCR, SCR;
			};

			uint32_t sr[3];
		};

		// Flags
		bool N, Z, C, V, T;

		// Custom Engine Registers
		uint32_t CEH, CEL;

		// Program Counter
		uint32_t pc;

		// Memory interfacing unit
		memory::SegmentedMemoryRegion<8, 24 > miu;
};

}

#endif
