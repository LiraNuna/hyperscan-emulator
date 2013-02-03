#include <array>
#include <fstream>
#include <stdint.h>

#ifndef __HYPERSCAN_MIU_H__
#define __HYPERSCAN_MIU_H__

namespace hyperscan {

namespace memory {

/**
 * The main Memory Interfacing Unit
 */
class MIU {
	public:
		/**
		 * Defines a memory region inside the MIU
		 */
		class MemoryRegion {
			public:
				/**
				 * Create a new memory region
				 */
				MemoryRegion(uint32_t mask) :
						mask(mask) {

				}

				virtual ~MemoryRegion() {

				}

				/**
				 * Read an unsigned byte
				 */
				virtual uint8_t readU8(uint32_t address) = 0;

				/**
				 * Read an unsigned half-word
				 */
				virtual uint16_t readU16(uint32_t address) = 0;

				/**
				 * Read an unsigned word
				 */
				virtual uint32_t readU32(uint32_t address) = 0;

				/**
				 * Write an unsigned byte
				 */
				virtual void writeU8(uint32_t address, uint8_t value) = 0;

				/**
				 * Write an unsigned half-word
				 */
				virtual void writeU16(uint32_t address, uint16_t value) = 0;

				/**
				 * Write an unsigned word
				 */
				virtual void writeU32(uint32_t address, uint32_t value) = 0;

				/**
				 * The mask used for accessing memory inside this memory region
				 * All reads and writes will be given (address & mask) before called
				 */
				const uint32_t mask;
		};

		MIU();

		~MIU();

		uint8_t readU8(uint32_t address);

		uint16_t readU16(uint32_t address);

		uint32_t readU32(uint32_t address);

		void writeU8(uint32_t address, uint8_t value);

		void writeU16(uint32_t address, uint16_t value);

		void writeU32(uint32_t address, uint32_t value);

		void setRegion(uint8_t region, MemoryRegion* memRegion);

	protected:
		/**
		 * Since not all regions are used, this defines an unsued memory region
		 * When the MIU is initialized, all memory regions are unused
		 */
		class ReservedMemoryRegion: public MemoryRegion {
			public:
				ReservedMemoryRegion() :
						MemoryRegion(0xFFFFFFFF) {

				}

				virtual ~ReservedMemoryRegion() {

				}

				virtual uint8_t readU8(uint32_t) {
					return -1;
				}

				virtual uint16_t readU16(uint32_t) {
					return -1;
				}

				virtual uint32_t readU32(uint32_t) {
					return -1;
				}

				virtual void writeU8(uint32_t, uint8_t) {
					// Do nothing?
				}

				virtual void writeU16(uint32_t, uint16_t) {
					// Do nothing?
				}

				virtual void writeU32(uint32_t, uint32_t) {
					// Do nothing?
				}
		};

		std::array<MemoryRegion*, 0x100 > regions;
		ReservedMemoryRegion* reservedRegion;
};

}

}

#endif
