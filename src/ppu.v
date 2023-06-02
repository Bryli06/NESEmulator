module main

import register

pub struct NesPPU {
mut:
    chr_rom []u8
    mirroring Mirroring
    ctrl register.ControlRegister = 0b00000000
    mask register.MaskRegister = 0b00000000
    status register.StatusRegister = 0b00000000
    scroll register.ScrollRegister = register.ScrollRegister {}
    addr register.AddrRegister = register.AddrRegister {}
    vram [2048]u8 = [2048]u8 { init: 0 }

    oam_addr u8
    oam_data [256]u8 = [256]u8 { init: 0 }
    palette_table [32]u8 = [32]u8 {init: 0}

    internal_data_buf u8

	scanline u16
	cycles usize
	nmi_interrupt ?u8
}


pub fn new_empty_rom() &NesPPU {
	return &NesPPU {
		chr_rom: []u8 {len: 2048, cap: 2048, init: 0}
		mirroring: Mirroring.horizontal
	}
}

// Horizontal
//   [ A ] [ a ]
//   [ B ] [ b ]

// Vertical
//   [ A ] [ B ]
//   [ a ] [ b ]

pub fn (ppu &NesPPU) mirror_vram_addr(addr u16) u16 {
	mirrored_vram := addr & 0b10111111111111 // mirror down 0x3000-0x3eff to 0x2000 - 0x2eff
	vram_index := mirrored_vram - 0x2000 // to vram vector
	name_table := vram_index / 0x400
	match ppu.mirroring {
		.vertical {
			match name_table {
				2, 3 { return vram_index - 0x800 }
				else { return vram_index }
			}
		}
		.horizontal {
			match name_table {
				1, 2 { return vram_index - 0x400 }
				3 { return vram_index - 0x800 }
				else { return vram_index}
			}
		}
		else {
			return vram_index
		}
	}
}

pub fn (mut ppu NesPPU) increment_vram_addr() {
	ppu.addr.increment(ppu.ctrl.vram_addr_increment())
}

pub fn (mut ppu NesPPU) write_to_ctrl(value u8) {
	before_nmi_status := ppu.ctrl.generate_vblank_nmi()
	ppu.ctrl.update(value)
	if !before_nmi_status && ppu.ctrl.generate_vblank_nmi() && ppu.status.is_in_vblank() {
		ppu.nmi_interrupt = 1
	}
}

pub fn (mut ppu NesPPU) write_to_mask(value u8) {
	ppu.mask.update(value)
}

pub fn (mut ppu NesPPU) read_status() u8 {
	data := ppu.status.snapshot()
	ppu.status.reset_vblank_status()
	ppu.addr.reset_latch()
	ppu.scroll.reset_latch()
	return data
}

pub fn (mut ppu NesPPU) write_to_oam_addr(value u8) {
	ppu.oam_addr = value
}

pub fn (mut ppu NesPPU) write_to_oam_data(value u8) {
	ppu.oam_data[ppu.oam_addr] = value
	ppu.oam_addr += 1
}

pub fn (mut ppu NesPPU) read_oam_data() u8 {
	return ppu.oam_data[ppu.oam_addr]
}

pub fn (mut ppu NesPPU) write_to_scroll(value u8) {
	ppu.scroll.write(value)
}

pub fn (mut ppu NesPPU) write_to_ppu_addr(value u8) {
	ppu.addr.update(value)
}

pub fn (mut ppu NesPPU) write_to_data(value u8) {
	addr := ppu.addr.get()
	if addr >= 0 && addr <= 0x1fff {
		println('attempt to write to chr rom space ${addr}')
	}
	else if addr >= 0x2000 && addr <= 0x2fff {
		ppu.vram[ppu.mirror_vram_addr(addr)] = value
	}
	else if addr >= 0x3000 && addr <= 0x3eff{
		panic('addr ${addr} shouldn\'t be used')
	}
	else {
		match addr {
			0x3f10, 0x3f14, 0x3f18, 0x3f1c {
				add_mirror := addr - 0x10
				ppu.palette_table[(add_mirror - 0x3f00)] = value
			}
			0x3f00...0x3fff {
				ppu.palette_table[(addr - 0x3f00)] = value
			}
			else {
				panic('unexpected access to mirrored space ${addr}')
			}
		}
	}
	ppu.increment_vram_addr()
}

pub fn (mut ppu NesPPU) read_data() u8 {
	addr := ppu.addr.get()

	ppu.increment_vram_addr()

	if addr >= 0 && addr <= 0x1fff {
		result := ppu.internal_data_buf
		ppu.internal_data_buf = ppu.chr_rom[addr]
		return result
	}
	else if addr >= 0x2000 && addr <= 0x2fff {
		result := ppu.internal_data_buf
		ppu.internal_data_buf = ppu.vram[ppu.mirror_vram_addr(addr)]
		return result
	}
	else if addr >= 0x3000 && addr <= 0x3eff{
		panic('addr ${addr} shouldn\'t be used')
	}
	match addr {
		//Addresses $3F10/$3F14/$3F18/$3F1C are mirrors of $3F00/$3F04/$3F08/$3F0C
		0x3f10, 0x3f14, 0x3f18, 0x3f1c {
			add_mirror := addr - 0x10
			return ppu.palette_table[(add_mirror - 0x3f00)]
		}

		0x3f00...0x3fff {
			return ppu.palette_table[(addr - 0x3f00)]
		}
		else {
			panic('unexpected access to mirrored space ${addr}')
		}
	}
}

pub fn (mut ppu NesPPU) write_oam_dma(data [256]u8) {
	for x in data {
		ppu.oam_data[ppu.oam_addr] = x
		ppu.oam_addr += 1
	}
}

pub fn (mut ppu NesPPU) tick(cycles u8) bool {
	ppu.cycles += cycles
	if ppu.cycles >= 341 {
		if ppu.is_sprite_0_hit(ppu.cycles) {
			ppu.status.set_sprite_zero_hit(true)
		}
		ppu.cycles = ppu.cycles - 341
		ppu.scanline += 1

		if ppu.scanline == 241 {
			ppu.status.set_vblank_status(true)
			ppu.status.set_sprite_zero_hit(false)
			if ppu.ctrl.generate_vblank_nmi() {
				ppu.nmi_interrupt = 1
			}
		}

		if ppu.scanline >= 262 {
			ppu.scanline = 0
			ppu.nmi_interrupt = none
			ppu.status.set_sprite_zero_hit(false)
			ppu.status.reset_vblank_status()
			return true
		}
	}
	return false
}

pub fn (mut ppu NesPPU) poll_nmi_interrupt() ?u8 {
	temp := ppu.nmi_interrupt
	ppu.nmi_interrupt = none
	return temp
}

fn (ppu &NesPPU) is_sprite_0_hit(cycle usize) bool {
	y := usize(ppu.oam_data[0])
	x := usize(ppu.oam_data[3])
	return (y == usize(ppu.scanline)) && x <= cycle && ppu.mask.show_sprites()
}
