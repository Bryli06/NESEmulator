module main

const (
	ram = 0x0000
	ram_mirrors_end = 0x1FFF
	ppu_registers = 0x2000
	ppu_registers_mirrors_end = 0x3FFF
)

pub struct Bus {
mut:
	bus_vram [2048]u8 = [2048] u8 {init: 0}
}

fn (bus &Bus) mem_read(addr u16) u8 {
	match addr {
		ram...ram_mirrors_end {
			mirror_down_addr := addr & 0b00000111_11111111
			return bus.bus_vram[mirror_down_addr]
		}
		ppu_registers...ppu_registers_mirrors_end {
			mirror_down_addr := addr & 0b00100000_00000111
			println('PPU is not supported yet')
			return 0
		}
		else {
			println('Ignoring mem access at ${addr}')
			return 0
		}
	}
}

fn (mut bus Bus) mem_write(addr u16, data u8) {
	match addr {
		ram...ram_mirrors_end {
			mirror_down_addr := addr & 0b11111111111
			bus.bus_vram[mirror_down_addr] = data
		}
		ppu_registers...ppu_registers_mirrors_end {
			mirror_down_addr := addr & 0b00100000_00000111
			println('PPU is not supported yet')
		}
		else {
			println('Ignoring mem write-access at ${addr}')
		}
	}
}

fn (bus &Bus) mem_read_u16(pos u16) u16 {
	lo := u16(bus.mem_read(pos))
	hi := u16(bus.mem_read(pos+1))
	return (hi << 8) | lo
}

fn (mut bus Bus) mem_write_u16(pos u16, data u16) {
	hi := u8(data >> 8)
	lo := u8(data & 0xff)
	bus.mem_write(pos, lo)
	bus.mem_write(pos+1, hi)
}

