#include <cstdio>
#include <iostream>
#include <memory>

#include "hyperscan/cpu.h"
#include "hyperscan/debugger.h"
#include "hyperscan/io/io.h"
#include "hyperscan/memory/arraymemoryregion.h"

using namespace hyperscan;

/**
 * TODO: make better
 */
auto createFileMemoryRegion(const char* fileName, uint32_t offset = 0) {
	auto result = std::make_shared<memory::ArrayMemoryRegion<24>>();

	FILE* f = fopen(fileName, "rb");
	if(!f) {
		fprintf(stderr, "bad file: %s", fileName);
		exit(1);
	}

	fseek(f, 0, SEEK_END);
	size_t fileSize = ftell(f);
	fseek(f, 0, SEEK_SET);

	if(fread(result->memory.data() + offset, 1, fileSize, f) != fileSize)
		fprintf(stderr, "WARNING: Bad firmware\n");

	fclose(f);

	return result;
}

int main() {
	CPU cpu;

	cpu.miu = std::make_shared<memory::SegmentedMemoryRegion<8, 24>>();
	auto firmware = createFileMemoryRegion("roms/hsfirmware.bin");
	auto dram = std::make_shared<memory::ArrayMemoryRegion<24>>();
	auto mmio = std::make_shared<io::IOMemoryRegion>();

	cpu.miu->setRegion(0x9E, firmware);
	cpu.miu->setRegion(0x9F, firmware);

	cpu.miu->setRegion(0x80, dram);
	cpu.miu->setRegion(0xA0, dram);

	cpu.miu->setRegion(0x08, mmio);
	cpu.miu->setRegion(0x88, mmio);

	// XXX: Debug control register
	cpu.cr29 = 0x20000000;

	// Firmware entry point
	cpu.pc = 0x9F000000;

//	// ISO "entry point"
//	cpu.pc = 0xA0091000;

	debugger_enable();
	while (1) {
		debugger_loop(cpu);
		cpu.step();
	}
}
