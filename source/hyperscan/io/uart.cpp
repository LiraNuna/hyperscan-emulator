#include "hyperscan/io/uart.h"

namespace hyperscan::io {

uint32_t UART::readU32(uint32_t address) const {
	switch(address) {
		// RX
		case 0x0000:
			return 0x00000000;
		// Error register
		case 0x0004:
			return 0x00000000;
		// UART Control
		case 0x0008:
			return 0x00000000;
		// Baud rate
		case 0x000C:
			return 0x00000000;
		// Status
		case 0x0010:
			return 0x00000090;
	}

	// XXX: Is that what really happens?
	return ArrayMemoryRegion::readU32(address);
}

void UART::writeU32(uint32_t address, uint32_t value) {
	switch(address) {
		// TX
		case 0x0000:
			printf("%c", value & 0xFF);
			fflush(stdout);
			return;
		// Error register
		case 0x0004:
			return;
		// UART Control
		case 0x0008:
			return;
		// Baud rate
		case 0x000C:
			return;
		// Status
		case 0x0010:
			return;
	}

	// XXX: May not be needed
	ArrayMemoryRegion::writeU32(address, value);
}

}
