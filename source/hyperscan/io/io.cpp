#include "hyperscan/io/io.h"
#include "hyperscan/io/uart.h"

namespace hyperscan::io {

IOMemoryRegion::IOMemoryRegion() {
	// 0x0815_0000 ~ 0x0815_FFFF
	setRegion(0x15, std::make_shared<UART>());
}

}
