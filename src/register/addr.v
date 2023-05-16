module register

pub struct AddrRegister {
mut:
    value_hi u8
	value_lo u8
    hi_ptr bool = true
}

fn (mut addr AddrRegister) set(data u16) {
	addr.value_hi = u8(data >> 8)
	addr.value_lo = u8(data & 0xff)
}

pub fn (mut addr AddrRegister) update(data u8) {
	if addr.hi_ptr {
		addr.value_hi = data
	} else {
		addr.value_lo = data
	}

	if addr.get() > 0x3fff {
		addr.set(addr.get() & 0b11111111111111)
	}

	addr.hi_ptr = !addr.hi_ptr
}

pub fn (mut addr AddrRegister) increment(inc u8) {
	lo := addr.value_lo
	addr.value_lo += inc
	if lo > addr.value_lo {
		addr.value_hi += 1
	}
	if addr.get() > 0x3fff {
		addr.set(addr.get() & 0b11111111111111)
	}
}

pub fn (mut addr AddrRegister) reset_latch() {
	addr.hi_ptr = true
}

pub fn (addr &AddrRegister) get() u16 {
	return (u16(addr.value_hi) << 8) | u16(addr.value_lo)
}
