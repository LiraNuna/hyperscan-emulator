#ifndef __HYPERSCAN_IO_UART_H__
#define __HYPERSCAN_IO_UART_H__

#include <deque>

#include "io.h"
#include "hyperscan/memory/arraymemoryregion.h"

namespace hyperscan {

namespace io {

class UART : public memory::ArrayMemoryRegion<IOMemoryRegion::DATA_BITS > {
	public:
		UART();

		uint8_t readU8(uint32_t address) const override;

		uint16_t readU16(uint32_t address) const override;

		uint32_t readU32(uint32_t address) const override;

		void writeU8(uint32_t address, uint8_t value) override;

		void writeU16(uint32_t address, uint16_t value) override;

		void writeU32(uint32_t address, uint32_t value) override;
};

}

}

#endif
