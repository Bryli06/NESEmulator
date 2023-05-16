module register

pub struct ScrollRegister {
mut:
    scroll_x u8
    scroll_y u8
    latch bool
}

pub fn (mut scroll ScrollRegister) write(data u8) {
	if !scroll.latch {
		scroll.scroll_x = data
	} else {
		scroll.scroll_y = data
	}
	scroll.latch = !scroll.latch
}

pub fn (mut scroll ScrollRegister) reset_latch() {
	scroll.latch = false
}
