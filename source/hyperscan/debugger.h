#include "hyperscan/cpu.h"

void debugger_breakpoint_add(uint32_t address, bool one_shot);

void debugger_breakpoint_toggle(uint32_t address, bool one_shot);

void debugger_breakpoint_remove(uint32_t address);

void debugger_enable();

void debugger_disable();

void debugger_loop(hyperscan::CPU &cpu);

void debugger_view_memory(uint32_t address);
