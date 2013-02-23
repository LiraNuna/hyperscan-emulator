#ifndef __HYPERSCAN_IO_IOMEMORYREGION_H__
#define __HYPERSCAN_IO_IOMEMORYREGION_H__

#include "hyperscan/memory/segmentedmemoryregion.h"

namespace hyperscan {

namespace io {

class IOMemoryRegion : public memory::SegmentedMemoryRegion<8, 16 > {
	public:
		IOMemoryRegion();
};

}

}

#endif
