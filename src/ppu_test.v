module main

fn assert_eq(a usize, b usize) {
	assert a == b
}

fn test_ppu_vram_writes() {
	mut ppu := new_empty_rom()
	ppu.write_to_ppu_addr(0x23)
	ppu.write_to_ppu_addr(0x05)
	ppu.write_to_data(0x66)

	assert_eq(ppu.vram[0x0305], 0x66)
}


fn test_ppu_vram_reads() {
	mut ppu := new_empty_rom()
	ppu.write_to_ctrl(0)
	ppu.vram[0x0305] = 0x66

	ppu.write_to_ppu_addr(0x23)
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load_into_buffer
	assert_eq(ppu.addr.get(), 0x2306)
	assert_eq(ppu.read_data(), 0x66)
}


fn test_ppu_vram_reads_cross_page() {
	mut ppu := new_empty_rom()
	ppu.write_to_ctrl(0)
	ppu.vram[0x01ff] = 0x66
	ppu.vram[0x0200] = 0x77

	ppu.write_to_ppu_addr(0x21)
	ppu.write_to_ppu_addr(0xff)

	ppu.read_data() //load_into_buffer
	assert_eq(ppu.read_data(), 0x66)
	assert_eq(ppu.read_data(), 0x77)
}


fn test_ppu_vram_reads_step_32() {
	mut ppu := new_empty_rom()
	ppu.write_to_ctrl(0b100)
	ppu.vram[0x01ff] = 0x66
	ppu.vram[0x01ff + 32] = 0x77
	ppu.vram[0x01ff + 64] = 0x88

	ppu.write_to_ppu_addr(0x21)
	ppu.write_to_ppu_addr(0xff)

	ppu.read_data() //load_into_buffer
	assert_eq(ppu.read_data(), 0x66)
	assert_eq(ppu.read_data(), 0x77)
	assert_eq(ppu.read_data(), 0x88)
}

// Horizontal: https://wiki.nesdev.com/w/index.php/Mirroring
//   [0x2000 A ] [0x2400 a ]
//   [0x2800 B ] [0x2C00 b ]
fn test_vram_horizontal_mirror() {
	mut ppu := new_empty_rom()
	ppu.write_to_ppu_addr(0x24)
	ppu.write_to_ppu_addr(0x05)

	ppu.write_to_data(0x66) //write to a

	ppu.write_to_ppu_addr(0x28)
	ppu.write_to_ppu_addr(0x05)

	ppu.write_to_data(0x77) //write to B

	ppu.write_to_ppu_addr(0x20)
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load into buffer
	assert_eq(ppu.read_data(), 0x66) //read from A

	ppu.write_to_ppu_addr(0x2C)
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load into buffer
	assert_eq(ppu.read_data(), 0x77) //read from b
}
// Vertical: https://wiki.nesdev.com/w/index.php/Mirroring
//   [0x2000 A ] [0x2400 B ]
//   [0x2800 a ] [0x2C00 b ]

fn test_vram_vertical_mirror() {
	mut ppu := NesPPU {
		chr_rom: []u8 {len: 2048, cap: 2048, init: 0}
		mirroring: Mirroring.vertical
	}

	ppu.write_to_ppu_addr(0x20)
	ppu.write_to_ppu_addr(0x05)

	ppu.write_to_data(0x66) //write to A

	ppu.write_to_ppu_addr(0x2C)
	ppu.write_to_ppu_addr(0x05)

	ppu.write_to_data(0x77) //write to b

	ppu.write_to_ppu_addr(0x28)
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load into buffer
	assert_eq(ppu.read_data(), 0x66) //read from a

	ppu.write_to_ppu_addr(0x24)
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load into buffer
	assert_eq(ppu.read_data(), 0x77) //read from B
}


fn test_read_status_resets_latch() {
	mut ppu := new_empty_rom()
	ppu.vram[0x0305] = 0x66

	ppu.write_to_ppu_addr(0x21)
	ppu.write_to_ppu_addr(0x23)
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load_into_buffer
	assert ppu.read_data() != 0x66

	ppu.read_status()

	ppu.write_to_ppu_addr(0x23)
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load_into_buffer
	assert_eq(ppu.read_data(), 0x66)
}


fn test_ppu_vram_mirroring() {
	mut ppu := new_empty_rom()
	ppu.write_to_ctrl(0)
	ppu.vram[0x0305] = 0x66

	ppu.write_to_ppu_addr(0x63) //0x6305 -> 0x2305
	ppu.write_to_ppu_addr(0x05)

	ppu.read_data() //load into_buffer
	assert_eq(ppu.read_data(), 0x66)
	// assert_eq(ppu.addr.read(), 0x0306)
}


fn test_read_status_resets_vblank() {
	mut ppu := new_empty_rom()
	ppu.status.set_vblank_status(true)

	status := ppu.read_status()

	assert_eq(status >> 7, 1)
	assert_eq(ppu.status.snapshot() >> 7, 0)
}


fn test_oam_read_write() {
	mut ppu := new_empty_rom()
	ppu.write_to_oam_addr(0x10)
	ppu.write_to_oam_data(0x66)
	ppu.write_to_oam_data(0x77)

	ppu.write_to_oam_addr(0x10)
	assert_eq(ppu.read_oam_data(), 0x66)

	ppu.write_to_oam_addr(0x11)
	assert_eq(ppu.read_oam_data(), 0x77)
}


fn test_oam_dma() {
	mut ppu := new_empty_rom()

	mut data := [256]u8 {init: 0x66}
	data[0] = 0x77
	data[255] = 0x88

	ppu.write_to_oam_addr(0x10)
	ppu.write_oam_dma(&data)

	ppu.write_to_oam_addr(0xf) //wrap around
	assert_eq(ppu.read_oam_data(), 0x88)

	ppu.write_to_oam_addr(0x10)
	assert_eq(ppu.read_oam_data(), 0x77)

	ppu.write_to_oam_addr(0x11)
	assert_eq(ppu.read_oam_data(), 0x66)
}
