#include <cstdio>
#include <iostream>

#include "hyperscan/cpu.h"
#include "hyperscan/io/io.h"
#include "hyperscan/memory/arraymemoryregion.h"

using namespace hyperscan;

/**
 * TODO: make better
 */
memory::ArrayMemoryRegion<24 >* createFileMemoryRegion(const char* fileName) {
	memory::ArrayMemoryRegion<24 >* result = new memory::ArrayMemoryRegion<24 >();

	FILE* f = fopen(fileName, "rb");
	if(!f) {
		fprintf(stderr, "bad file: %s", fileName);
		exit(1);
	}

	fseek(f, 0, SEEK_END);
	size_t fileSize = ftell(f);
	fseek(f, 0, SEEK_SET);

	if(fread(result->memory.data(), 1, fileSize, f) != fileSize)
		fprintf(stderr, "WARNING: Bad firmware\n");

	fclose(f);

	return result;
}

int main() {
	CPU cpu;

	memory::ArrayMemoryRegion<24 >* firmware = createFileMemoryRegion("roms/hsfirmware.bin");
	memory::ArrayMemoryRegion<24 >* ram = new memory::ArrayMemoryRegion<24 >();
	io::IOMemoryRegion* mmio = new io::IOMemoryRegion();

	cpu.miu.setRegion(0x9E, firmware);
	cpu.miu.setRegion(0x9F, firmware);

	cpu.miu.setRegion(0x80, ram);
	cpu.miu.setRegion(0xA0, ram);

	cpu.miu.setRegion(0x08, mmio);
	cpu.miu.setRegion(0x88, mmio);

//	// XXX: P_MIU_STATUS: self refresh
//	mmio->memory[0x07006C] = 1;
//	// XXX: P_UART_Status: FIFO clear
//	mmio->memory[0x150010] = 0;
	// XXX: Debug control register
	cpu.cr29 = 0x20000000;

	// Firmware entry point
	cpu.pc = 0x9F000000;

//	// ISO "entry point"
//	cpu.pc = 0xA0091000;

	while(1)
		cpu.step();

	return 0;
}
