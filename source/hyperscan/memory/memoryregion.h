#ifndef __HYPERSCAN_MEMORY_MEMORYREGION_H__
#define __HYPERSCAN_MEMORY_MEMORYREGION_H__

#include <stdint.h>

namespace hyperscan {

namespace memory {

/**
 * Defines a memory region inside the MIU
 */
template <unsigned addressable_bits >
class MemoryRegion {
	public:
		static constexpr unsigned TOTAL_SIZE  = (1 << addressable_bits);
		static constexpr unsigned ACCESS_MASK = TOTAL_SIZE - 1;

		virtual ~MemoryRegion() {

		}

		/**
		 * Read an unsigned byte
		 */
		virtual uint8_t readU8(uint32_t address) = 0;

		/**
		 * Read an unsigned half-word
		 */
		virtual uint16_t readU16(uint32_t address) = 0;

		/**
		 * Read an unsigned word
		 */
		virtual uint32_t readU32(uint32_t address) = 0;

		/**
		 * Write an unsigned byte
		 */
		virtual void writeU8(uint32_t address, uint8_t value) = 0;

		/**
		 * Write an unsigned half-word
		 */
		virtual void writeU16(uint32_t address, uint16_t value) = 0;

		/**
		 * Write an unsigned word
		 */
		virtual void writeU32(uint32_t address, uint32_t value) = 0;
};

}

}

#endif
