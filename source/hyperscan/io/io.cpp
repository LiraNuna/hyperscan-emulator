#include "io.h"
#include "uart.h"

namespace hyperscan {

namespace io {

IOMemoryRegion::IOMemoryRegion() {
	// 0x0815_0000 ~ 0x0815_FFFF
	setRegion(0x15, new UART());
}

}

}
