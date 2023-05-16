module main

pub enum JoypadButtons as u8 {
	right             = 0b10000000
	left              = 0b01000000
	down              = 0b00100000
	up                = 0b00010000
	start             = 0b00001000
	@select           = 0b00000100
	button_b          = 0b00000010
	button_a          = 0b00000001
}

pub type JoypadButton = u8

fn (flag &JoypadButton) contains(other JoypadButtons) bool {
	return (*flag & u8(other)) == u8(other)
}

fn (mut flag JoypadButton) insert(other JoypadButtons) {
	flag |= u8(other)
}

fn (mut flag JoypadButton) remove(other JoypadButtons) {
	flag &= ~u8(other)
}

fn (mut flag JoypadButton) set(other JoypadButtons, value bool) {
	if value {
		flag |= u8(other)
	}
	else {
		flag &= ~u8(other)
	}
}

pub struct Joypad {
mut:
    strobe bool
    button_index u8
    button_status JoypadButton
}

pub fn (mut joypad Joypad) write(data u8) {
	joypad.strobe = data & 1 == 1
	if joypad.strobe {
		joypad.button_index = 0
	}
}

pub fn (mut joypad Joypad) read() u8 {
	if joypad.button_index > 7 {
		return 1
	}
	response := (joypad.button_status & (1 << joypad.button_index)) >> joypad.button_index
	if !joypad.strobe && joypad.button_index <= 7 {
		joypad.button_index += 1
	}
	return response
}

pub fn (mut joypad Joypad) set_button_pressed_status(button JoypadButtons, pressed bool) {
	joypad.button_status.set(button, pressed)
}
