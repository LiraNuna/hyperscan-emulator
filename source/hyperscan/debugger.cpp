#include <cstdio>
#include <csignal>
#include <iostream>
#include <sstream>
#include <iterator>
#include <vector>
#include <functional>
#include <map>

#include "hyperscan/debugger.h"
#include "hyperscan/disasm.h"

using namespace hyperscan;

bool debugger = false;
uint32_t memory_view_address = 0xa0000000;
std::unordered_map<uint32_t, bool> breakpoints = {};

uint32_t parse_address(const std::string &str, CPU* cpu) {
	if (str.starts_with("r")) {
		return cpu->r[std::stol(str.substr(1))];
	}

	try {
		return std::stol(str, nullptr, 16);
	} catch (const std::invalid_argument&) {
		return cpu->pc;
	}
}

const std::map<const std::string, std::function<void(std::vector<std::string>, CPU*)> > COMMAND_TABLE
		{{"",[](auto, auto cpu) {
			cpu->step();
		}},
		{"c", [](auto, auto) {
			debugger_disable();
		}},
		{"r", [](auto arguments, auto cpu) {
			uint32_t cycles = std::stol(arguments[0]);
			while (cycles--) {
				cpu->step();
			}
		}},
		{"b",  [](auto arguments, auto cpu) {
			if (arguments.empty()) {
				return debugger_breakpoint_toggle(cpu->pc, false);
			}

			for (const auto& arg : arguments) {
				debugger_breakpoint_toggle(parse_address(arg, cpu), false);
			}
		}},
		{"j",  [](auto arguments, auto cpu) {
			debugger_breakpoint_add(parse_address(arguments[0], cpu), true);
			debugger_disable();
		}},
		{"m", [](auto arguments, auto cpu) {
			debugger_view_memory(parse_address(arguments[0], cpu));
		}},
		{"i", [](auto arguments, auto cpu) {
			cpu->interrupt(std::stol(arguments[0]));
		}},
		{"so", [](auto, auto cpu) {
			CPU::InstructionDecoder instruction = cpu->miu->readU32(cpu->pc - (cpu->pc & 2));

			debugger_breakpoint_add(cpu->pc + (instruction.p0 * 2) + 2, true);
			debugger_disable();
		}},
		{"sb", [](auto arguments, auto cpu) {
			cpu->miu->writeU8(parse_address(arguments[0], cpu), parse_address(arguments[1], cpu));
		}},
		{"sh", [](auto arguments, auto cpu) {
			cpu->miu->writeU16(parse_address(arguments[0], cpu), parse_address(arguments[1], cpu));
		}},
		{"sw", [](auto arguments, auto cpu) {
			cpu->miu->writeU32(parse_address(arguments[0], cpu), parse_address(arguments[1], cpu));
		}},
		{"dump", [](auto arguments, auto cpu) {
			FILE* memdump = fopen(arguments[0].c_str(), "wb");
			for(int i=0; i<0x01000000; ++i)
				fputc(cpu->miu->readU8(0xA0000000 + i), memdump);
			fclose(memdump);
		}},
		{"q", [](auto, auto) {
			exit(0);
		}},
};

void move(size_t x, size_t y) {
	printf("\033[%zu;%zuH", y, x);
}

void draw_border() {
	printf("┌─────────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────┬────────────┐\n");
	for (int i = 0; i < 31; ++i)
		printf("│                                                             │                                                                               │            │\n");
	printf("├─────────────────────────────────────────────────[         ]─┤                                                                               │            │\n");
	for (int i = 0; i < 8; ++i)
		printf("│                                                             │                                                                               │            │\n");
	printf("├─────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────┴────────────┤\n");
	printf("│                                                                                                                                                          │\n");
	printf("└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\n");
}

void draw_registers(int x, int y, const CPU &cpu) {
	const auto get_register_value_color = [](uint32_t value) {
		switch (value) {
			case 0x88000000 ... 0x88250000: return "\033[32m";
			case 0xA0000000 ... 0xA0FFEFFF: return "\033[36m";
			case 0xA0FFF000 ... 0xA1000000: return "\033[33m";
			default: return "\033[39m";
		}
	};

	move(x + 50, y);
	printf("%sT\033[27m %sN\033[27m %sZ\033[27m %sC\033[27m %sV\033[27m",
		   cpu.T ? "\033[7m" : "",
		   cpu.N ? "\033[7m" : "",
		   cpu.Z ? "\033[7m" : "",
		   cpu.C ? "\033[7m" : "",
		   cpu.V ? "\033[7m" : "");

	for (int i = 0; i < 32; i += 4) {
		move(x + 1, y + (i / 4) + 1);

		for (int ri = i; ri < i + 4; ++ri) {
			printf("\033[37m%sr%d\033[39m ", (ri < 10) ? " " : "", ri);
			printf("\033[37m[%s%08x\033[37m]\033[39m ", get_register_value_color(cpu.r[ri]), cpu.r[ri]);
		}
	}
}

void draw_memory(int x, int y, int h, const CPU &cpu, uint32_t startAddress) {
	const auto get_byte_color = [](uint8_t byte) {
		switch (byte) {
			case 0x00: return "\033[32m";
			case 0x20 ... 0x7E: return "\033[33m";
			case 0x7F: return "\033[94m";
			case 0xFF: return "\033[31m";
			default: return "";
		}
	};

	for (int i = 0; i < h; ++i) {
		move(x, y + i);

		printf("\033[37m%08x\033[39m:  ", startAddress + (i * 16));
		for (int ii = 0; ii < 16; ++ii) {
			if (ii == 8) {
				printf(" ");
			}

			uint8_t byte = cpu.miu->readU8(startAddress + (i * 16) + ii);
			printf("%s%02x\033[39m ", get_byte_color(byte), byte);
		}

		printf(" ");
		for (int ii = 0; ii < 16; ++ii) {
			uint8_t byte = cpu.miu->readU8(startAddress + (i * 16) + ii);
			printf("%s%c\033[39m", get_byte_color(byte), (byte > 0x20 && byte < 0x7E) ? byte : '.');
		}
	}
}

void draw_stack(size_t x, size_t y, size_t h, const CPU &cpu) {
	const auto get_value_color = [](uint32_t value) {
		switch (value) {
			case 0x88000000 ... 0x88250000: return "\033[32m";
			case 0xA0000000 ... 0xA0FFEFFF: return "\033[36m";
			case 0xA0FFF000 ... 0xA1000000: return "\033[33m";
			default: return "\033[39m";
		}
	};

	size_t stack_size = std::min<size_t>((0xa1000000 - cpu.r0) / 4, h);
	for (size_t i = 0; i < h - stack_size; ++i) {
		move(x, y + i);
		printf("%10s", "");
	}
	for (size_t i = 0; i < stack_size; ++i) {
		move(x, y + i + (h - stack_size));

		uint32_t address = cpu.r0 + (i * 4);
		printf("%s%s%s%08x\033[24;27;39m", address == cpu.r0 ? "▶ \033[7m" : "  ",
		       address == cpu.r2 ? "\033[4m" : "", get_value_color(cpu.miu->readU32(address)), cpu.miu->readU32(address));
	}
}

void draw_code(int x, int y, int lines, const CPU &cpu, uint32_t address, int lookback = 0) {
	while (lookback--) {
		address -= 4;
		if ((~cpu.miu->readU16(address) & 0x8000) || (address & 2) >> 1) {
			address += 2;
		}
	}

	for (int i = 0; i < lines; ++i) {
		move(x, y + i);

		CPU::InstructionDecoder instruction = cpu.miu->readU32(address - (address & 2));

		if (address == cpu.pc || (address - (address & 2) == cpu.pc && instruction.p1)) {
			printf("▶ \033[44m");
		} else if (breakpoints.contains(address)) {
			printf("\033[31m●\033[39m \033[41m");
		} else {
			printf("  ");
		}
		printf("\033[37m%08x\033[39m:       \033[s%41s\033[u", address, "");

		if (instruction.p0) {
			disasm32((instruction.high << 15) | instruction.low, address);
			address += 4;
		} else {
			if (instruction.p1) printf("\033[4m");
			disasm16((address & 2) ? instruction.high : instruction.low, address);
			address += 2;
		}

		printf("\033[24;49m");
	}
}

void debugger_breakpoint_add(uint32_t address, bool one_shot) {
	breakpoints.insert({address, one_shot});
}

void debugger_breakpoint_toggle(uint32_t address, bool one_shot) {
	if (!breakpoints.insert({address, one_shot}).second) {
		debugger_breakpoint_remove(address);
	}
}

void debugger_breakpoint_remove(uint32_t address) {
	breakpoints.erase(address);
}

void debugger_enable() {
	debugger = true;
}

void debugger_disable() {
	debugger = false;
}

void debugger_view_memory(uint32_t address) {
	memory_view_address = address;
}

void debugger_loop(CPU &cpu) {
	if (!debugger) {
		if (!breakpoints.contains(cpu.pc)) {
			return;
		}

		debugger_enable();
		if (breakpoints[cpu.pc]) {
			debugger_breakpoint_remove(cpu.pc);
		}
	}

	printf("\033[?1049h\033[H");

	signal(SIGINT, [](auto){ exit(0); });
	atexit([](){ printf("\033[?1049l"); });

	draw_border();
	while (debugger) {
		draw_stack(145, 2, 40, cpu);
		draw_registers(2, 33, cpu);
		draw_memory(65, 2, 40, cpu, memory_view_address);

		draw_code(3, 2, 31, cpu, cpu.pc, 31 / 2);

		move(3, 43);
		printf("> \033[s%133s\033[u", "");

		std::string command;
		std::getline(std::cin, command);

		std::string cmd;
		std::vector<std::string> arguments;

		std::istringstream iss(command);
		std::istream_iterator<std::string> iter = iss;
		cmd = *iter++;
		std::copy(iter, std::istream_iterator<std::string>(), std::back_inserter(arguments));

		if (COMMAND_TABLE.contains(cmd)) {
			COMMAND_TABLE.at(cmd)(arguments, &cpu);
		}
	}

	printf("\033[?1049l");
}
