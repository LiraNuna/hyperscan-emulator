#include "hyperscan/memory/memoryregion.h"

#ifndef __HYPERSCAN_MEMORY_EMPTYMEMORYREGION_H__
#define __HYPERSCAN_MEMORY_EMPTYMEMORYREGION_H__

namespace hyperscan::memory {

/**
 * An empty, unassigned memory region
 */
template <unsigned addressable_bits >
class EmptyMemoryRegion : public MemoryRegion<addressable_bits> {
	public:
		virtual ~EmptyMemoryRegion() = default;

		[[nodiscard]]
		virtual uint8_t readU8(uint32_t) const {
			return -1;
		}

		[[nodiscard]]
		virtual uint16_t readU16(uint32_t) const {
			return -1;
		}

		[[nodiscard]]
		virtual uint32_t readU32(uint32_t) const {
			return -1;
		}

		virtual void writeU8(uint32_t, uint8_t) {
			// Do nothing
		}

		virtual void writeU16(uint32_t, uint16_t) {
			// Do nothing
		}

		virtual void writeU32(uint32_t, uint32_t) {
			// Do nothing
		}
};

}

#endif
