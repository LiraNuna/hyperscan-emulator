#include <set>
#include <algorithm>

#include "miu.h"

namespace hyperscan {

namespace memory {

MIU::MIU() {
	reservedRegion = new ReservedMemoryRegion();
	std::fill(regions.begin(), regions.end(), reservedRegion);
}

MIU::~MIU() {
	// Use a set to make sure no region is deleted twice
	std::set<MemoryRegion* > memRegions(regions.begin(), regions.end());
	for(MemoryRegion* region : memRegions)
		delete region;

	// Because the reserved region is special, make sure it's deleted
	// We check if the set contains it and if it did not,  delete it manually
	if(memRegions.count(reservedRegion) == 0)
		delete reservedRegion;
}

uint8_t MIU::readU8(uint32_t address) {
	MemoryRegion* region = regions[address >> 24];
	return region->readU8(region->mask & address);
}

uint16_t MIU::readU16(uint32_t address) {
	MemoryRegion* region = regions[address >> 24];
	return region->readU16(region->mask & address);
}

uint32_t MIU::readU32(uint32_t address) {
	MemoryRegion* region = regions[address >> 24];
	return region->readU32(region->mask & address);
}

void MIU::writeU8(uint32_t address, uint8_t value) {
	MemoryRegion* region = regions[address >> 24];
	region->writeU8(region->mask & address, value);
}

void MIU::writeU16(uint32_t address, uint16_t value) {
	MemoryRegion* region = regions[address >> 24];
	region->writeU16(region->mask & address, value);
}

void MIU::writeU32(uint32_t address, uint32_t value) {
	MemoryRegion* region = regions[address >> 24];
	region->writeU32(region->mask & address, value);
}

void MIU::setRegion(uint8_t region, MIU::MemoryRegion* memRegion) {
	regions[region] = memRegion;
}

}

}
