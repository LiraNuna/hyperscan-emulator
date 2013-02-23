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

		virtual uint8_t readU8(uint32_t address);

		virtual uint16_t readU16(uint32_t address);

		virtual uint32_t readU32(uint32_t address);

		virtual void writeU8(uint32_t address, uint8_t value);

		virtual void writeU16(uint32_t address, uint16_t value);

		virtual void writeU32(uint32_t address, uint32_t value);
};

}

}

#endif
