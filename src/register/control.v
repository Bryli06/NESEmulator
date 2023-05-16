module register

pub enum ControlRegisters as u8 {
	nametable1              = 0b00000001
	nametable2              = 0b00000010
	vram_add_increment      = 0b00000100
	sprite_pattern_addr     = 0b00001000
	backround_pattern_addr  = 0b00010000
	sprite_size             = 0b00100000
	master_slave_select     = 0b01000000
	generate_nmi            = 0b10000000
}

pub type ControlRegister = u8

fn (flag &ControlRegister) contains(other ControlRegisters) bool {
	return (*flag & u8(other)) == u8(other)
}

fn (mut flag ControlRegister) insert(other ControlRegisters) {
	flag |= u8(other)
}

fn (mut flag ControlRegister) remove(other ControlRegisters) {
	flag &= ~u8(other)
}

fn (mut flag ControlRegister) set(other ControlRegisters, value bool) {
	if value {
		flag |= u8(other)
	}
	else {
		flag &= ~u8(other)
	}
}

pub fn (control &ControlRegister) nametable_addr() u16 {
	match *control & 0b11 {
		0 { return 0x2000 }
		1 { return 0x2400 }
		2 { return 0x2800 }
		3 { return 0x2c00 }
		else { panic('not possible') }
	}
	panic('not possible')
}

pub fn (control &ControlRegister) vram_addr_increment() u8 {
	if !control.contains(ControlRegisters.vram_add_increment) {
		return 1
	} else {
		return 32
	}
}

pub fn (control &ControlRegister) sprt_pattern_addr() u16 {
	if !control.contains(ControlRegisters.sprite_pattern_addr) {
		return 0
	} else {
		return 0x1000
	}
}

pub fn (control &ControlRegister) bknd_pattern_addr() u16 {
	if !control.contains(ControlRegisters.backround_pattern_addr) {
		return 0
	} else {
		return 0x1000
	}
}

pub fn (control &ControlRegister) sprite_size() u8 {
	if !control.contains(ControlRegisters.sprite_size) {
		return 8
	} else {
		return 16
	}
}

pub fn (control &ControlRegister) master_slave_select() u8 {
	if !control.contains(ControlRegisters.master_slave_select) {
		return 0
	} else {
		return 1
	}
}

pub fn (control &ControlRegister) generate_vblank_nmi() bool {
	return control.contains(ControlRegisters.generate_nmi)
}

pub fn (mut control ControlRegister) update(data u8) {
	control = data
}
