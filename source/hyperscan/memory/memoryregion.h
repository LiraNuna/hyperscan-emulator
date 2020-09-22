#include <cstdint>

#ifndef __HYPERSCAN_MEMORY_MEMORYREGION_H__
#define __HYPERSCAN_MEMORY_MEMORYREGION_H__

namespace hyperscan::memory {

/**
 * Defines a memory region inside the MIU
 */
template <unsigned addressable_bits >
class MemoryRegion {
	public:
		/**
		 * Read an unsigned byte
		 */
		[[nodiscard]]
		virtual uint8_t readU8(uint32_t address) const {
			uint32_t aligned = address & 0xFFFFFFFC;
			return readU32(aligned) >> (address - aligned) * 8;
		}

		/**
		 * Read an unsigned half-word
		 */
		[[nodiscard]]
		virtual uint16_t readU16(uint32_t address) const {
			uint32_t aligned = address & 0xFFFFFFFC;
			return readU32(aligned) >> (address - aligned) * 8;
		}

		/**
		 * Read an unsigned word
		 */
		[[nodiscard]]
		virtual uint32_t readU32(uint32_t address) const = 0;

		/**
		 * Write an unsigned byte
		 */
		virtual void writeU8(uint32_t address, uint8_t value) {
			uint32_t aligned = address & 0xFFFFFFFC;
			uint32_t mask = ~(0xFF << ((address - aligned) * 8));
			writeU32(aligned, (readU32(aligned) & mask) | (value << ((address - aligned) * 8)));
		}

		/**
		 * Write an unsigned half-word
		 */
		virtual void writeU16(uint32_t address, uint16_t value) {
			uint32_t aligned = address & 0xFFFFFFFC;
			uint32_t mask = ~(0xFFFF << ((address - aligned) * 8));
			writeU32(aligned, (readU32(aligned) & mask) | (value << ((address - aligned) * 8)));
		}

		/**
		 * Write an unsigned word
		 */
		virtual void writeU32(uint32_t address, uint32_t value) = 0;
};

}

#endif
