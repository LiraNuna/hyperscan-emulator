#include "io.h"
#include "uart.h"

namespace hyperscan {

namespace io {

UART::UART() {

}

uint8_t UART::readU8(uint32_t address) const {
	// TODO: 8bit read

	return ArrayMemoryRegion::readU8(address);
}

uint16_t UART::readU16(uint32_t address) const {
	// TODO: 16bit read

	return ArrayMemoryRegion::readU16(address);
}

uint32_t UART::readU32(uint32_t address) const {
	switch(address) {
		// TX/RX
		case 0x0000:
			// When reading, acts as RX
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

void UART::writeU8(uint32_t address, uint8_t value) {
	// TODO: 8bit write

	ArrayMemoryRegion::writeU8(address, value);
}

void UART::writeU16(uint32_t address, uint16_t value) {
	// TODO: 16bit write

	ArrayMemoryRegion::writeU16(address, value);
}

void UART::writeU32(uint32_t address, uint32_t value) {
	switch(address) {
		// TX/RX
		case 0x0000:
			// When writing, acts as TX
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

}
