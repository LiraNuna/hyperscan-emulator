#include <array>
#include <memory>

#include "hyperscan/memory/emptymemoryregion.h"
#include "hyperscan/memory/memoryregion.h"

#ifndef __HYPERSCAN_MEMORY_SEGMENTEDMEMORYREGION_H__
#define __HYPERSCAN_MEMORY_SEGMENTEDMEMORYREGION_H__

namespace hyperscan::memory {

template <unsigned segment_bit_size, unsigned segment_data_bit_size >
class SegmentedMemoryRegion : public MemoryRegion<segment_bit_size + segment_data_bit_size > {
	public:
		static constexpr unsigned DATA_BITS             = segment_data_bit_size;

		static constexpr unsigned SEGMENT_COUNT         = (1 << segment_bit_size);
		static constexpr unsigned SEGMENT_SIZE          = (1 << segment_data_bit_size);
		static constexpr unsigned SEGMENT_ACCESS_MASK   = SEGMENT_SIZE - 1;

		// Segment type
		typedef MemoryRegion<segment_data_bit_size> Segment;

		SegmentedMemoryRegion() {
			auto empty = std::shared_ptr<Segment>(new EmptyMemoryRegion<segment_data_bit_size>());
			std::fill(segments.begin(), segments.end(), empty);
		}

		[[nodiscard]]
		virtual uint32_t readU32(uint32_t address) const {
			return segments[address >> segment_data_bit_size]->readU32(address & SEGMENT_ACCESS_MASK);
		}

		virtual void writeU32(uint32_t address, uint32_t value) {
			segments[address >> segment_data_bit_size]->writeU32(address & SEGMENT_ACCESS_MASK, value);
		}

		void setRegion(uint8_t address, std::shared_ptr<Segment> segment) {
			segments[address] = segment;
		}

	protected:
		std::array<std::shared_ptr<Segment>, SEGMENT_COUNT> segments;
};

}

#endif
