module register

pub enum MaskRegisters as u8 {
	 greyscale               = 0b00000001
	 leftmost_8pxl_background  = 0b00000010
	 leftmost_8pxl_sprite      = 0b00000100
	 show_background         = 0b00001000
	 show_sprites            = 0b00010000
	 emphasise_red           = 0b00100000
	 emphasise_green         = 0b01000000
	 emphasise_blue          = 0b10000000
}

pub type MaskRegister = u8

fn (flag &MaskRegister) contains(other MaskRegisters) bool {
	return (*flag & u8(other)) == u8(other)
}

fn (mut flag MaskRegister) insert(other MaskRegisters) {
	flag |= u8(other)
}

fn (mut flag MaskRegister) remove(other MaskRegisters) {
	flag &= ~u8(other)
}

fn (mut flag MaskRegister) set(other MaskRegisters, value bool) {
	if value {
		flag |= u8(other)
	}
	else {
		flag &= ~u8(other)
	}
}

pub enum Color {
    red
    green
    blue
}

pub fn (register &MaskRegister) is_grayscale() bool {
	return register.contains(MaskRegisters.greyscale)
}

pub fn (register &MaskRegister) leftmost_8pxl_background() bool {
	return register.contains(MaskRegisters.leftmost_8pxl_background)
}

pub fn (register &MaskRegister) leftmost_8pxl_sprite() bool {
	return register.contains(MaskRegisters.leftmost_8pxl_sprite)
}

pub fn (register &MaskRegister) show_background() bool {
	return register.contains(MaskRegisters.show_background)
}

pub fn (register &MaskRegister) show_sprites() bool {
	return register.contains(MaskRegisters.show_sprites)
}

pub fn (register &MaskRegister) emphasise() []Color {
	mut result := []Color {}
	if register.contains(MaskRegisters.emphasise_red) {
		result << Color.red
	}
	if register.contains(MaskRegisters.emphasise_blue) {
		result << Color.blue
	}
	if register.contains(MaskRegisters.emphasise_green) {
		result << Color.green
	}

	return result
}

pub fn (mut register MaskRegister) update(data u8) {
	register = data
}

