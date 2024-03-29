#include <array>

#include "hyperscan/memory/memoryregion.h"

#ifndef __HYPERSCAN_MEMORY_ARRAYMEMORYREGION_H__
#define __HYPERSCAN_MEMORY_ARRAYMEMORYREGION_H__

namespace hyperscan::memory {

/**
 * Memory region from an array
 */
template <unsigned addressable_bits >
class ArrayMemoryRegion: public MemoryRegion<addressable_bits > {
	public:
		static constexpr unsigned TOTAL_SIZE  = (1 << addressable_bits);

		[[nodiscard]]
		virtual uint8_t readU8(uint32_t address) const {
			return memory[address];
		}

		[[nodiscard]]
		virtual uint16_t readU16(uint32_t address) const {
			return memory[address + 0] << 0 |
				   memory[address + 1] << 8;
		}

		[[nodiscard]]
		virtual uint32_t readU32(uint32_t address) const {
			return memory[address + 0] <<  0 |
				   memory[address + 1] <<  8 |
				   memory[address + 2] << 16 |
				   memory[address + 3] << 24;
		}

		virtual void writeU8(uint32_t address, uint8_t value) {
			memory[address] = value;
		}

		virtual void writeU16(uint32_t address, uint16_t value) {
			memory[address + 0] = (value >> 0) & 0xFF;
			memory[address + 1] = (value >> 8) & 0xFF;
		}

		virtual void writeU32(uint32_t address, uint32_t value) {
			memory[address + 0] = (value >>  0) & 0xFF;
			memory[address + 1] = (value >>  8) & 0xFF;
			memory[address + 2] = (value >> 16) & 0xFF;
			memory[address + 3] = (value >> 24) & 0xFF;
		}

		std::array<uint8_t, TOTAL_SIZE > memory;
};

}

#endif
