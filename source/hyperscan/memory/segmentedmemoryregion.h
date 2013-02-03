#ifndef __HYPERSCAN_MEMORY_SEGMENTEDMEMORYREGION_H__
#define __HYPERSCAN_MEMORY_SEGMENTEDMEMORYREGION_H__

#include <set>
#include <array>
#include <algorithm>

#include "memoryregion.h"

namespace hyperscan {

namespace memory {

template <unsigned segment_bit_size, unsigned segment_data_bit_size >
class SegmentedMemoryRegion : public MemoryRegion<segment_bit_size + segment_data_bit_size > {
	protected:
		// Segment type
		typedef MemoryRegion<segment_data_bit_size > Segment;

		/**
		 * Since not all segments are used, this defines an unsued memory region
		 * TODO: Figure out what real hardware does when accessing unmapped address
		 */
		class UnmappedMemoryRegion: public MemoryRegion<segment_data_bit_size > {
			public:
				virtual ~UnmappedMemoryRegion() {

				}

				virtual uint8_t readU8(uint32_t) {
					return -1;
				}

				virtual uint16_t readU16(uint32_t) {
					return -1;
				}

				virtual uint32_t readU32(uint32_t) {
					return -1;
				}

				virtual void writeU8(uint32_t, uint8_t) {
					// Do nothing?
				}

				virtual void writeU16(uint32_t, uint16_t) {
					// Do nothing?
				}

				virtual void writeU32(uint32_t, uint32_t) {
					// Do nothing?
				}
		};

		UnmappedMemoryRegion* unmappedSegment;

	public:
		static constexpr unsigned TOTAL_SIZE  = (1 << (segment_bit_size + segment_data_bit_size));
		static constexpr unsigned ACCESS_MASK = TOTAL_SIZE - 1;

		static constexpr unsigned SEGMENT_COUNT       = (1 << segment_bit_size);
		static constexpr unsigned SEGMENT_SIZE        = (1 << segment_data_bit_size);
		static constexpr unsigned SEGMENT_ACCESS_MASK = SEGMENT_SIZE - 1;

		SegmentedMemoryRegion() {
			unmappedSegment = new UnmappedMemoryRegion();
			std::fill(segments.begin(), segments.end(), unmappedSegment);
		}

		~SegmentedMemoryRegion() {
			// Make sure not to double delete
			std::set<Segment* > uniqueSegments(segments.begin(), segments.end());
			for(Segment* segment : uniqueSegments)
				delete segment;

			if(uniqueSegments.count(unmappedSegment) == 0)
				delete unmappedSegment;
		}

		virtual uint8_t readU8(uint32_t address) {
			Segment* segment = segments[address >> segment_data_bit_size];
			return segment->readU8(address & SEGMENT_ACCESS_MASK);
		}

		virtual uint16_t readU16(uint32_t address) {
			Segment* segment = segments[address >> segment_data_bit_size];
			return segment->readU16(address & SEGMENT_ACCESS_MASK);
		}

		virtual uint32_t readU32(uint32_t address) {
			Segment* segment = segments[address >> segment_data_bit_size];
			return segment->readU32(address & SEGMENT_ACCESS_MASK);
		}

		virtual void writeU8(uint32_t address, uint8_t value) {
			Segment* segment = segments[address >> segment_data_bit_size];
			segment->writeU8(address & SEGMENT_ACCESS_MASK, value);
		}

		virtual void writeU16(uint32_t address, uint16_t value) {
			Segment* segment = segments[address >> segment_data_bit_size];
			segment->writeU16(address & SEGMENT_ACCESS_MASK, value);
		}

		virtual void writeU32(uint32_t address, uint32_t value) {
			Segment* segment = segments[address >> segment_data_bit_size];
			segment->writeU32(address & SEGMENT_ACCESS_MASK, value);
		}

		virtual void setRegion(uint8_t address, Segment* segment) {
			segments[address] = segment;
		}

	protected:
		std::array<Segment*, 1 << segment_bit_size > segments;
};

}

}

#endif
