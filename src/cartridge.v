module main

const(
	nes_tag = [u8(0x4E), 0x45, 0x53, 0x1A]
	prg_rom_page_size = 16384
	chr_rom_page_size = 8192
)

pub enum Mirroring {
    vertical
    horizontal
    four_screen
}

pub struct Rom {
    prg_rom []u8
    chr_rom []u8
    mapper u8
    screen_mirroring Mirroring
}

fn (mut rom Rom) new(raw []u8) {
	if raw[0..4] != nes_tag {
		panic('File is not in iNES file format')
	}

	mapper := (raw[7] & 0b1111_0000) | (raw[6] >> 4)

	ines_ver := (raw[7] >> 2) & 0b11
	if ines_ver != 0 {
		panic('NES2.0 format is not supported')
	}

	four_screen := raw[6] & 0b1000 != 0
	vertical_mirroring := raw[6] & 0b1 != 0
	screen_mirroring := if four_screen {
		Mirroring.four_screen
	}
	else {
		if vertical_mirroring {
			Mirroring.vertical
		}
		else {
			Mirroring.horizontal
		}
	}

	prg_rom_size := int(raw[4]) * prg_rom_page_size
	chr_rom_size := int(raw[5]) * chr_rom_page_size

	skip_trainer := raw[6] & 0b100 != 0

	prg_rom_start := 16 + if skip_trainer { 512 } else { 0 }
	chr_rom_start := prg_rom_start + prg_rom_size

	rom = &Rom {
		prg_rom: raw[prg_rom_start..(prg_rom_start + prg_rom_size)]
		chr_rom: raw[chr_rom_start..(chr_rom_start + chr_rom_size)]
		mapper: mapper
		screen_mirroring: screen_mirroring
	}
}

