module main

const (
	ram = 0x0000
	ram_mirrors_end = 0x1FFF
	ppu_registers = 0x2000
	ppu_registers_mirrors_end = 0x3FFF
)

pub struct Bus {
mut:
	cpu_vram [2048]u8 = [2048] u8 {init: 0}
	rom Rom
	ppu NesPPU

	cycles usize
	gameloop_callback fn(&NesPPU)
	joypad1 Joypad
}

fn (bus &Bus) read_prg_rom(address u16) u8 {
	mut addr := address - 0x8000
	if bus.rom.prg_rom.len == 0x4000 && addr >= 0x4000 {
		//mirror if needed
		addr = addr % 0x4000
	}
	return bus.rom.prg_rom[addr]
}

fn (mut bus Bus) mem_read(addr u16) u8 {
	if addr >= ram && addr <= ram_mirrors_end {
		mirror_down_addr := addr & 0b0000011111111111
		return bus.cpu_vram[mirror_down_addr]
	}
	if addr >= 0x2008 && addr <= ppu_registers_mirrors_end {
		mirror_down_addr := addr & 0b0010000000000111
		return bus.mem_read(mirror_down_addr)
	}
	if addr >= 0x8000 && addr <= 0xFFFF{
		return bus.read_prg_rom(addr)
	}
	match addr {
		0x2000, 0x2001, 0x2003, 0x2005, 0x2006, 0x4014 {
			panic('Attempt to read from write-only PPU address ${addr:x}')
		}
		0x2002 { return bus.ppu.read_status() }
		0x2004 { return bus.ppu.read_oam_data() }
		0x2007 { return bus.ppu.read_data() }

		0x4000...0x4015 {
			//ignore APU
			return 0
		}
		0x4016 {
			return bus.joypad1.read()
		}
		0x4017 {
			return 0 //joypad 2
		}
		else {
			println('Ignoring mem access at ${addr}')
			return 0
		}
	}
}

fn (mut bus Bus) mem_write(addr u16, data u8) {
	if addr >= ram && addr <= ram_mirrors_end {
		mirror_down_addr := addr & 0b11111111111
		bus.cpu_vram[mirror_down_addr] = data
		return
	}
	if addr >= 0x2008 && addr <= ppu_registers_mirrors_end {
		mirror_down_addr := addr & 0b0010000000000111
		bus.mem_write(mirror_down_addr, data)
		return
	}
	if addr >= 0x8000 && addr <= 0xFFFF{
		panic('Attempt to write to Cartridge ROM space')
	}
	match addr {
		0x2000 {
			bus.ppu.write_to_ctrl(data)
		}
		0x2001 {
			bus.ppu.write_to_mask(data)
		}

		0x2002 { panic("attempt to write to PPU status register") }

		0x2003 {
			bus.ppu.write_to_oam_addr(data)
		}
		0x2004 {
			bus.ppu.write_to_oam_data(data)
		}
		0x2005 {
			bus.ppu.write_to_scroll(data)
		}

		0x2006 {
			bus.ppu.write_to_ppu_addr(data)
		}
		0x2007 {
			bus.ppu.write_to_data(data)
		}

		0x4000...0x4013, 0x4015 {
			//ignore APU
		}
		0x4016 {
			bus.joypad1.write(data)
		}
		0x4017 {
			//joypad 2
		}
		0x4014 {
			mut buffer := [256]u8 { init: 0 }
			hi := u16(data) << 8
			for i in 0..u16(256) {
				buffer[i] = bus.mem_read(hi+i)
			}

			bus.ppu.write_oam_dma(buffer)
		}
		else {
			println('Ignoring mem write-access at ${addr}')
		}
	}
}

fn (mut bus Bus) mem_read_u16(pos u16) u16 {
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

pub fn (mut bus Bus) tick(cycles u8) {
	bus.cycles += cycles

	nmi_before := bus.ppu.nmi_interrupt != none
	bus.ppu.tick(cycles * 3)
	nmi_after := bus.ppu.nmi_interrupt != none
    if !nmi_before && nmi_after {
		bus.gameloop_callback(&bus.ppu)
	}
}

pub fn (mut bus Bus) poll_nmi_status() ?u8 {
	return bus.ppu.poll_nmi_interrupt()
}
