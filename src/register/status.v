module register

pub enum StatusRegisters as u8 {
	notused          = 0b00000001
	notused2         = 0b00000010
	notused3         = 0b00000100
	notused4         = 0b00001000
	notused5         = 0b00010000
	sprite_overflow  = 0b00100000
	sprite_zero_hit  = 0b01000000
	vblank_started   = 0b10000000
}

pub type StatusRegister = u8

fn (flag &StatusRegister) contains(other StatusRegisters) bool {
	return (*flag & u8(other)) == u8(other)
}

fn (mut flag StatusRegister) insert(other StatusRegisters) {
	flag |= u8(other)
}

fn (mut flag StatusRegister) remove(other StatusRegisters) {
	flag &= ~u8(other)
}

fn (mut flag StatusRegister) set(other StatusRegisters, value bool) {
	if value {
		flag |= u8(other)
	}
	else {
		flag &= ~u8(other)
	}
}

pub fn (mut register StatusRegister) set_vblank_status(status bool) {
	register.set(StatusRegisters.vblank_started, status)
}

pub fn (mut register StatusRegister) set_sprite_zero_hit(status bool) {
	register.set(StatusRegisters.sprite_zero_hit, status)
}

pub fn (mut register StatusRegister) set_sprite_overflow(status bool) {
	register.set(StatusRegisters.sprite_overflow, status)
}

pub fn (mut register StatusRegister) reset_vblank_status() {
	register.remove(StatusRegisters.vblank_started)
}

pub fn (register &StatusRegister) is_in_vblank() bool {
	return register.contains(StatusRegisters.vblank_started)
}

pub fn (register &StatusRegister) snapshot() u8 {
	return *register
}
