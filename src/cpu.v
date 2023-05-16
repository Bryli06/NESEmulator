module main

const (
	stack		= u16(0x0100)
	stack_reset = u8(0xfd)

	nmi = Interrupt {
		itype: .nmi
		vector_addr: 0xfffA
		b_flag_mask: 0b00100000
		cpu_cycles: 2
	}
)

pub enum InterruptType {
	nmi
}

pub struct Interrupt {
	itype InterruptType
	vector_addr u16
	b_flag_mask u8
	cpu_cycles u8
}

pub enum CpuFlags as u8 {
	carry             = 0b00000001
	zero              = 0b00000010
    interrupt_disable = 0b00000100
    decimal_mode      = 0b00001000
    @break            = 0b00010000
    break2            = 0b00100000
    overflow          = 0b01000000
    negativ           = 0b10000000
}

pub type CpuFlag = u8

fn (flag &CpuFlag) contains(other CpuFlags) bool {
	return (*flag & u8(other)) == u8(other)
}

fn (mut flag CpuFlag) insert(other CpuFlags) {
	flag |= u8(other)
}

fn (mut flag CpuFlag) remove(other CpuFlags) {
	flag &= ~u8(other)
}

fn (mut flag CpuFlag) set(other CpuFlags, value bool) {
	if value {
		flag |= u8(other)
	}
	else {
		flag &= ~u8(other)
	}
}

pub enum AddressingMode as u8 {
    immediate
    zeropage
    zeropage_x
    zeropage_y
    absolute
    absolute_x
    absolute_y
    indirect_x
    indirect_y
    noneaddressing
}

pub struct CPU {
mut:
    register_a u8
    register_x u8
    register_y u8
    status     CpuFlag = 0b100100
    program_counter u16
    stack_pointer u8 = stack_reset
	bus Bus
}

pub fn (cpu &CPU) str() string {
	return 'a: ${cpu.register_a}\nx: ${cpu.register_x}\ny: ${cpu.register_y}'
}

[inline]
fn (mut cpu CPU) mem_read(addr u16) u8 {
	return cpu.bus.mem_read(addr)
}

[inline]
fn (mut cpu CPU) mem_write(addr u16, data u8) {
	cpu.bus.mem_write(addr, data)
}

[inline]
fn (mut cpu CPU) mem_read_u16(pos u16) u16 {
	return cpu.bus.mem_read_u16(pos)
}

[inline]
fn (mut cpu CPU) mem_write_u16(pos u16, data u16) {
	cpu.bus.mem_write_u16(pos, data)
}

fn page_cross(addr1 u16, addr2 u16) bool {
	return addr1 & 0xFF00 != addr2 & 0xFF00
}

fn (mut cpu CPU) get_operand_address(mode AddressingMode) (u16, bool) {
	match mode {
		.immediate { return cpu.program_counter, false }
		else { return cpu.get_absolute_address(mode, cpu.program_counter) }
	}

	panic('impossible cpu operation how tf did u do this')
}

fn (mut cpu CPU) get_absolute_address(mode AddressingMode, addr u16) (u16, bool) {
	match mode {
		.zeropage { return u16(cpu.mem_read(addr)), false }

		.absolute { return cpu.mem_read_u16(addr), false }

		.zeropage_x {
			pos := cpu.mem_read(addr)
			address := pos + u16(cpu.register_x)
			return address, false
		}
		.zeropage_y {
			pos := cpu.mem_read(addr)
			address := pos + u16(cpu.register_y)
			return address, false
		}

		.absolute_x {
			base := cpu.mem_read_u16(addr)
			address := base + u16(cpu.register_x)
			return address, page_cross(base, addr)
		}
		.absolute_y {
			base := cpu.mem_read_u16(addr)
			address := base + u16(cpu.register_y)
			return address, page_cross(base, addr)
		}

		.indirect_x {
			base := cpu.mem_read(addr)

			ptr := u8(base) + cpu.register_x
			lo := cpu.mem_read(u16(ptr))
			hi := cpu.mem_read(u16(ptr + 1))
			return u16(hi) << 8 | u16(lo), false
		}
		.indirect_y {
			base := cpu.mem_read(addr)

			lo := cpu.mem_read(u16(base))
			hi := cpu.mem_read(u16(base+ 1))
			deref_base := u16(hi) << 8 | u16(lo)
			deref := deref_base + u16(cpu.register_y)
			return deref, page_cross(deref, deref_base)
		}
		else {
			panic('mode ${mode} is not supported')
		}
	}
}


fn (mut cpu CPU) ldy(mode AddressingMode) {
	addr, page_cross := cpu.get_operand_address(mode)
	data := cpu.mem_read(addr)
	cpu.register_y = data
	cpu.update_zero_and_negative_flags(cpu.register_y)

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) ldx(mode AddressingMode) {
	addr, page_cross := cpu.get_operand_address(mode)
	data := cpu.mem_read(addr)
	cpu.register_x = data
	cpu.update_zero_and_negative_flags(cpu.register_x)

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) lda(mode AddressingMode) {
	addr, page_cross := cpu.get_operand_address(&mode)
	value := cpu.mem_read(addr)
	cpu.set_register_a(value)

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) sta(mode AddressingMode) {
	addr, _ := cpu.get_operand_address(mode)
	cpu.mem_write(addr, cpu.register_a)
}

fn (mut cpu CPU) set_register_a(value u8) {
	cpu.register_a = value
	cpu.update_zero_and_negative_flags(cpu.register_a)
}

fn (mut cpu CPU) and(mode AddressingMode) {
	addr, page_cross := cpu.get_operand_address(mode)
	data := cpu.mem_read(addr)
	cpu.set_register_a(data & cpu.register_a)

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) eor(mode AddressingMode) {
	addr, page_cross := cpu.get_operand_address(mode)
	data := cpu.mem_read(addr)
	cpu.set_register_a(data ^ cpu.register_a)

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) ora(mode AddressingMode) {
	addr, _ := cpu.get_operand_address(mode)
	data := cpu.mem_read(addr)
	cpu.set_register_a(data | cpu.register_a)
}

fn (mut cpu CPU) tax() {
	cpu.register_x = cpu.register_a
	cpu.update_zero_and_negative_flags(cpu.register_x)
}

fn (mut cpu CPU) update_zero_and_negative_flags(result u8) {
	if result == 0 {
		cpu.status.insert(CpuFlags.zero)
	} else {
		cpu.status.remove(CpuFlags.zero)
	}

	if result >> 7 == 1 {
		cpu.status.insert(CpuFlags.negativ)
	} else {
		cpu.status.remove(CpuFlags.negativ)
	}
}

fn (mut cpu CPU) update_negative_flags(result u8) {
    if result >> 7 == 1 {
        cpu.status.insert(CpuFlags.negativ)
    } else {
        cpu.status.remove(CpuFlags.negativ)
    }
}

fn (mut cpu CPU) inx() {
    cpu.register_x += 1
    cpu.update_zero_and_negative_flags(cpu.register_x)
}

fn (mut cpu CPU) iny() {
    cpu.register_y += 1
    cpu.update_zero_and_negative_flags(cpu.register_y)
}

pub fn (mut cpu CPU) load_and_run(program []u8) {
    cpu.load(program)
    cpu.reset()
    cpu.run()
}

pub fn (mut cpu CPU) load(program []u8) {
	for idx, x in program {
		cpu.mem_write(u16(0x8600+idx), x)
	}
    cpu.mem_write_u16(0xFFFC, 0x8600)
}

pub fn (mut cpu CPU) reset() {
    cpu.register_a = 0
    cpu.register_x = 0
    cpu.register_y = 0
    cpu.stack_pointer = stack_reset
    cpu.status = 0b100100

    cpu.program_counter = cpu.mem_read_u16(0xFFFC)
}

fn (mut cpu CPU) set_carry_flag() {
    cpu.status.insert(CpuFlags.carry)
}

fn (mut cpu CPU) clear_carry_flag() {
    cpu.status.remove(CpuFlags.carry)
}

/// note ignoring decimal mode
/// http://www.righto.com/2012/12/the-6502-overflow-flag-explained.html
fn (mut cpu CPU) add_to_register_a(data u8) {
    sum := u16(cpu.register_a) + u16(data) + ( if cpu.status.contains(CpuFlags.carry) { u16(1) } else { u16(0) })

    carry := sum > 0xff

    if carry {
        cpu.status.insert(CpuFlags.carry)
    } else {
        cpu.status.remove(CpuFlags.carry)
    }

    result := u8(sum)

    if (data ^ result) & (result ^ cpu.register_a) & 0x80 != 0 {
        cpu.status.insert(CpuFlags.overflow)
    } else {
        cpu.status.remove(CpuFlags.overflow)
    }

    cpu.set_register_a(result)
}

fn (mut cpu CPU) sub_from_register_a(data u8) {
	cpu.add_to_register_a(u8(i8(data) * -1 - i8(1)))
}

fn (mut cpu CPU) and_with_register_a(data u8) {
	cpu.set_register_a(data & cpu.register_a)
}

fn (mut cpu CPU) xor_with_register_a(data u8) {
	cpu.set_register_a(data ^ cpu.register_a)
}

fn (mut cpu CPU) or_with_register_a(data u8) {
	cpu.set_register_a(data | cpu.register_a)
}

fn (mut cpu CPU) sbc(mode AddressingMode) {
    addr, page_cross := cpu.get_operand_address(mode)
    data := cpu.mem_read(addr)
    cpu.add_to_register_a(u8(i8(data) * -1 - i8(1)))

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) adc(mode AddressingMode) {
    addr, page_cross := cpu.get_operand_address(mode)
    value := cpu.mem_read(addr)
    cpu.add_to_register_a(value)

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) stack_pop() u8 {
    cpu.stack_pointer += 1
    return cpu.mem_read(stack + u16(cpu.stack_pointer))
}

fn (mut cpu CPU) stack_push(data u8) {
    cpu.mem_write(stack + u16(cpu.stack_pointer), data)
    cpu.stack_pointer -= 1
}

fn (mut cpu CPU) stack_push_u16(data u16) {
    hi := u8(data >> 8)
    lo := u8(data & 0xff)
    cpu.stack_push(hi)
    cpu.stack_push(lo)
}

fn (mut cpu CPU) stack_pop_u16() u16 {
    lo := u16(cpu.stack_pop())
    hi := u16(cpu.stack_pop())

    return hi << 8 | lo
}

fn (mut cpu CPU) asl_accumulator() {
    mut data := cpu.register_a
    if data >> 7 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data << 1
    cpu.set_register_a(data)
}

fn (mut cpu CPU) asl(mode AddressingMode) u8 {
    addr, _ := cpu.get_operand_address(mode)
    mut data := cpu.mem_read(addr)
    if data >> 7 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data << 1
    cpu.mem_write(addr, data)
    cpu.update_zero_and_negative_flags(data)
    return data
}

fn (mut cpu CPU) lsr_accumulator() {
    mut data := cpu.register_a
    if data & 1 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data >> 1
    cpu.set_register_a(data)
}

fn (mut cpu CPU) lsr(mode AddressingMode) u8 {
    addr, _ := cpu.get_operand_address(mode)
    mut data := cpu.mem_read(addr)
    if data & 1 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data >> 1
    cpu.mem_write(addr, data)
    cpu.update_zero_and_negative_flags(data)
    return data
}

fn (mut cpu CPU) rol(mode AddressingMode) u8 {
    addr, _ := cpu.get_operand_address(mode)
    mut data := cpu.mem_read(addr)
    old_carry := cpu.status.contains(CpuFlags.carry)

    if data >> 7 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data << 1
    if old_carry {
        data = data | 1
    }
    cpu.mem_write(addr, data)
    cpu.update_negative_flags(data)
    return data
}

fn (mut cpu CPU) rol_accumulator() {
    mut data := cpu.register_a
    old_carry := cpu.status.contains(CpuFlags.carry)

    if data >> 7 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data << 1
    if old_carry {
        data = data | 1
    }
    cpu.set_register_a(data)
}

fn (mut cpu CPU) ror(mode AddressingMode) u8 {
    addr, _ := cpu.get_operand_address(mode)
    mut data := cpu.mem_read(addr)
    old_carry := cpu.status.contains(CpuFlags.carry)

    if data & 1 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data >> 1
    if old_carry {
        data = data | 0b10000000
    }
    cpu.mem_write(addr, data)
    cpu.update_negative_flags(data)
    return data
}

fn (mut cpu CPU) ror_accumulator() {
    mut data := cpu.register_a
    old_carry := cpu.status.contains(CpuFlags.carry)

    if data & 1 == 1 {
        cpu.set_carry_flag()
    } else {
        cpu.clear_carry_flag()
    }
    data = data >> 1
    if old_carry {
        data = data | 0b10000000
    }
    cpu.set_register_a(data)
}

fn (mut cpu CPU) inc(mode AddressingMode) u8 {
    addr, _ := cpu.get_operand_address(mode)
    mut data := cpu.mem_read(addr)
	data += 1
    cpu.mem_write(addr, data)
    cpu.update_zero_and_negative_flags(data)
    return data
}

fn (mut cpu CPU) dey() {
    cpu.register_y -= 1
    cpu.update_zero_and_negative_flags(cpu.register_y)
}

fn (mut cpu CPU) dex() {
    cpu.register_x -= 1
    cpu.update_zero_and_negative_flags(cpu.register_x)
}

fn (mut cpu CPU) dec(mode AddressingMode) u8 {
    addr, _ := cpu.get_operand_address(mode)
    mut data := cpu.mem_read(addr)
    data -= 1
    cpu.mem_write(addr, data)
    cpu.update_zero_and_negative_flags(data)
    return data
}

fn (mut cpu CPU) pla() {
    data := cpu.stack_pop()
    cpu.set_register_a(data)
}

fn (mut cpu CPU) plp() {
    cpu.status = cpu.stack_pop()
    cpu.status.remove(CpuFlags.@break)
    cpu.status.insert(CpuFlags.break2)
}

fn (mut cpu CPU) php() {
    //http://wiki.nesdev.com/w/index.php/CPU_status_flag_behavior
    mut flags := cpu.status
    flags.insert(CpuFlags.@break)
    flags.insert(CpuFlags.break2)
    cpu.stack_push(flags)
}

fn (mut cpu CPU) bit(mode AddressingMode) {
    addr, _ := cpu.get_operand_address(mode)
    data := cpu.mem_read(addr)
    and := cpu.register_a & data
    if and == 0 {
        cpu.status.insert(CpuFlags.zero)
    } else {
        cpu.status.remove(CpuFlags.zero)
    }

    cpu.status.set(CpuFlags.negativ, data & 0b10000000 > 0)
    cpu.status.set(CpuFlags.overflow, data & 0b01000000 > 0)
}

fn (mut cpu CPU) compare(mode AddressingMode, compare_with u8) {
    addr, page_cross := cpu.get_operand_address(mode)
    data := cpu.mem_read(addr)
    if data <= compare_with {
        cpu.status.insert(CpuFlags.carry)
    } else {
        cpu.status.remove(CpuFlags.carry)
    }

    cpu.update_zero_and_negative_flags(compare_with-data)

	if page_cross {
		cpu.bus.tick(1)
	}
}

fn (mut cpu CPU) branch(condition bool) {
    if condition {
		cpu.bus.tick(1)

        jump := i8(cpu.mem_read(cpu.program_counter))
        jump_addr := cpu.program_counter + 1 + u16(jump)

		if (cpu.program_counter + 1) & 0xFF00 != jump_addr & 0xFF00 {
			cpu.bus.tick(1)
		}

        cpu.program_counter = jump_addr
    }
}

fn (mut cpu CPU) interrupt(interrupt Interrupt) {
	cpu.stack_push_u16(cpu.program_counter)
	mut flag := cpu.status
	flag.set(CpuFlags.@break, interrupt.b_flag_mask & 0b010000 == 1)
	flag.set(CpuFlags.break2, interrupt.b_flag_mask & 0b100000 == 1)

	cpu.stack_push(flag)
	cpu.status.insert(CpuFlags.interrupt_disable)

	cpu.bus.tick(interrupt.cpu_cycles)
	cpu.program_counter = cpu.mem_read_u16(interrupt.vector_addr)
}

pub fn (mut cpu CPU) run() {
	cpu.run_with_callback(fn(mut cpu &CPU){

	})
}

pub fn (mut cpu CPU) run_with_callback(cb fn(mut cpu &CPU)) {
    opcodes := &main.opcodes_map

    for {
		if _nmi := cpu.bus.poll_nmi_status() {
			cpu.interrupt(nmi)
		}

		cb(mut cpu)
		// println(cpu)
        code := u8(cpu.mem_read(cpu.program_counter))
        cpu.program_counter += 1
        program_counter_state := cpu.program_counter

        opcode := (*opcodes)[code]

		// println("${code}")

        match code {
            0xa9, 0xa5, 0xb5, 0xad, 0xbd, 0xb9, 0xa1, 0xb1 {
                cpu.lda(opcode.mode)
            }

            0xAA { cpu.tax() }
            0xe8 { cpu.inx() }
            0x00 { return }

            /* CLD */ 0xd8 { cpu.status.remove(CpuFlags.decimal_mode) }

            /* CLI */ 0x58 { cpu.status.remove(CpuFlags.interrupt_disable) }

            /* CLV */ 0xb8 { cpu.status.remove(CpuFlags.overflow) }

            /* CLC */ 0x18 { cpu.clear_carry_flag() }

            /* SEC */ 0x38 { cpu.set_carry_flag() }

            /* SEI */ 0x78 { cpu.status.insert(CpuFlags.interrupt_disable) }

            /* SED */ 0xf8 { cpu.status.insert(CpuFlags.decimal_mode) }

            /* PHA */ 0x48 { cpu.stack_push(cpu.register_a) }

            /* PLA */
            0x68 {
                cpu.pla()
            }

            /* PHP */
            0x08 {
                cpu.php()
            }

            /* PLP */
            0x28 {
                cpu.plp()
            }

            /* ADC */
            0x69, 0x65, 0x75, 0x6d, 0x7d, 0x79, 0x61, 0x71 {
                cpu.adc(opcode.mode)
            }

            /* SBC */
            0xe9, 0xe5, 0xf5, 0xed, 0xfd, 0xf9, 0xe1, 0xf1 {
                cpu.sbc(opcode.mode)
            }

            /* AND */
            0x29, 0x25, 0x35, 0x2d, 0x3d, 0x39, 0x21, 0x31 {
                cpu.and(opcode.mode)
            }

            /* EOR */
            0x49, 0x45, 0x55, 0x4d, 0x5d, 0x59, 0x41, 0x51 {
                cpu.eor(opcode.mode)
            }

            /* ORA */
            0x09, 0x05, 0x15, 0x0d, 0x1d, 0x19, 0x01, 0x11 {
                cpu.ora(opcode.mode)
            }

            /* LSR */ 0x4a { cpu.lsr_accumulator() }

            /* LSR */
            0x46, 0x56, 0x4e, 0x5e {
                cpu.lsr(opcode.mode)
            }

            /*ASL*/ 0x0a { cpu.asl_accumulator() }

            /* ASL */
            0x06, 0x16, 0x0e, 0x1e {
                cpu.asl(opcode.mode)
            }

            /*ROL*/ 0x2a { cpu.rol_accumulator() }

            /* ROL */
            0x26, 0x36, 0x2e, 0x3e {
                cpu.rol(opcode.mode)
            }

            /* ROR */ 0x6a { cpu.ror_accumulator() }

            /* ROR */
            0x66, 0x76, 0x6e, 0x7e {
                cpu.ror(opcode.mode)
            }

            /* INC */
            0xe6, 0xf6, 0xee, 0xfe {
                cpu.inc(opcode.mode)
            }

            /* INY */
            0xc8 { cpu.iny() }

            /* DEC */
            0xc6, 0xd6, 0xce, 0xde {
                cpu.dec(opcode.mode)
            }

            /* DEX */
            0xca {
                cpu.dex()
            }

            /* DEY */
            0x88 {
                cpu.dey()
            }

            /* CMP */
            0xc9, 0xc5, 0xd5, 0xcd, 0xdd, 0xd9, 0xc1, 0xd1 {
                cpu.compare(opcode.mode, cpu.register_a)
            }

            /* CPY */
            0xc0, 0xc4, 0xcc {
                cpu.compare(opcode.mode, cpu.register_y)
            }

            /* CPX */
            0xe0, 0xe4, 0xec { cpu.compare(opcode.mode, cpu.register_x) }

            /* JMP Absolute */
            0x4c {
                mem_address := cpu.mem_read_u16(cpu.program_counter)
                cpu.program_counter = mem_address
            }

            /* JMP Indirect */
            0x6c {
                mem_address := cpu.mem_read_u16(cpu.program_counter)
                // let indirect_ref = cpu.mem_read_u16(mem_address)
                //6502 bug mode with with page boundary:
                //  if address $3000 contains $40, $30FF contains $80, and $3100 contains $50,
                // the result of JMP ($30FF) will be a transfer of control to $4080 rather than $5080 as you intended
                // i.e. the 6502 took the low byte of the address from $30FF and the high byte from $3000

                indirect_ref := if mem_address & 0x00FF == 0x00FF {
                    lo := cpu.mem_read(mem_address)
                    hi := cpu.mem_read(mem_address & 0xFF00)
                    u16(hi) << 8 | u16(lo)
                } else {
                    cpu.mem_read_u16(mem_address)
                }

                cpu.program_counter = indirect_ref
            }

            /* JSR */
            0x20 {
                cpu.stack_push_u16(cpu.program_counter + 2 - 1)
                target_address := cpu.mem_read_u16(cpu.program_counter)
                cpu.program_counter = target_address
            }

            /* RTS */
            0x60 {
                cpu.program_counter = cpu.stack_pop_u16() + 1
            }

            /* RTI */
            0x40 {
                cpu.status = cpu.stack_pop()
                cpu.status.remove(CpuFlags.@break)
                cpu.status.insert(CpuFlags.break2)

                cpu.program_counter = cpu.stack_pop_u16()
            }

            /* BNE */
            0xd0 {
                cpu.branch(!cpu.status.contains(CpuFlags.zero))
            }

            /* BVS */
            0x70 {
                cpu.branch(cpu.status.contains(CpuFlags.overflow))
            }

            /* BVC */
            0x50 {
                cpu.branch(!cpu.status.contains(CpuFlags.overflow))
            }

            /* BPL */
            0x10 {
                cpu.branch(!cpu.status.contains(CpuFlags.negativ))
            }

            /* BMI */
            0x30 {
                cpu.branch(cpu.status.contains(CpuFlags.negativ))
            }

            /* BEQ */
            0xf0 {
                cpu.branch(cpu.status.contains(CpuFlags.zero))
            }

            /* BCS */
            0xb0 {
                cpu.branch(cpu.status.contains(CpuFlags.carry))
            }

            /* BCC */
            0x90 {
                cpu.branch(!cpu.status.contains(CpuFlags.carry))
            }

            /* BIT */
            0x24, 0x2c {
                cpu.bit(opcode.mode)
            }

            /* STA */
            0x85, 0x95, 0x8d, 0x9d, 0x99, 0x81, 0x91 {
                cpu.sta(opcode.mode)
            }

            /* STX */
            0x86, 0x96, 0x8e {
                addr, _ := cpu.get_operand_address(opcode.mode)
                cpu.mem_write(addr, cpu.register_x)
            }

            /* STY */
            0x84, 0x94, 0x8c {
                addr, _ := cpu.get_operand_address(opcode.mode)
                cpu.mem_write(addr, cpu.register_y)
            }

            /* LDX */
            0xa2, 0xa6, 0xb6, 0xae, 0xbe {
                cpu.ldx(opcode.mode)
            }

            /* LDY */
            0xa0, 0xa4, 0xb4, 0xac, 0xbc {
                cpu.ldy(opcode.mode)
            }

            /* NOP */
            0xea {
                //do nothing
            }

            /* TAY */
            0xa8 {
                cpu.register_y = cpu.register_a
                cpu.update_zero_and_negative_flags(cpu.register_y)
            }

            /* TSX */
            0xba {
                cpu.register_x = cpu.stack_pointer
                cpu.update_zero_and_negative_flags(cpu.register_x)
            }

            /* TXA */
            0x8a {
                cpu.register_a = cpu.register_x
                cpu.update_zero_and_negative_flags(cpu.register_a)
            }

            /* TXS */
            0x9a {
                cpu.stack_pointer = cpu.register_x
            }

            /* TYA */
            0x98 {
                cpu.register_a = cpu.register_y
                cpu.update_zero_and_negative_flags(cpu.register_a)
            }

			/* DCP */
			0xc7, 0xd7, 0xCF, 0xdF, 0xdb, 0xd3, 0xc3 {
				addr, _ := cpu.get_operand_address(opcode.mode)
				mut data := cpu.mem_read(addr)
				data -= 1
				cpu.mem_write(addr, data)
				// cpu._update_zero_and_negative_flags(data)
				if data <= cpu.register_a {
					cpu.status.insert(CpuFlags.carry)
				}

				cpu.update_zero_and_negative_flags(cpu.register_a - (data))
			}

			/* RLA */
			0x27, 0x37, 0x2F, 0x3F, 0x3b, 0x33, 0x23 {
				data := cpu.rol(opcode.mode)
				cpu.and_with_register_a(data)
			}

			/* SLO */ //todo tests
			0x07, 0x17, 0x0F, 0x1f, 0x1b, 0x03, 0x13 {
				data := cpu.asl(opcode.mode)
				cpu.or_with_register_a(data)
			}

			/* SRE */ //todo tests
			0x47, 0x57, 0x4F, 0x5f, 0x5b, 0x43, 0x53 {
				data := cpu.lsr(opcode.mode)
				cpu.xor_with_register_a(data)
			}

			/* SKB */
			0x80, 0x82, 0x89, 0xc2, 0xe2 {
				/* 2 byte NOP (immediate ) */
				// todo: might be worth doing the read
			}

			/* AXS */
			0xCB {
				addr, _ := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)
				x_and_a := cpu.register_x & cpu.register_a
				result := x_and_a - data

				if data <= x_and_a {
					cpu.status.insert(CpuFlags.carry)
				}
				cpu.update_zero_and_negative_flags(result)

				cpu.register_x = result
			}

			/* ARR */
			0x6B {
				addr, _ := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)
				cpu.and_with_register_a(data)
				cpu.ror_accumulator()
				//todo: registers
				result := cpu.register_a
				bit_5 := (result >> 5) & 1
				bit_6 := (result >> 6) & 1

				if bit_6 == 1 {
					cpu.status.insert(CpuFlags.carry)
				} else {
					cpu.status.remove(CpuFlags.carry)
				}

				if bit_5 ^ bit_6 == 1 {
					cpu.status.insert(CpuFlags.overflow)
				} else {
					cpu.status.remove(CpuFlags.overflow)
				}

				cpu.update_zero_and_negative_flags(result)
			}

			/* unofficial SBC */
			0xeb {
				addr, _ := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)
				cpu.sub_from_register_a(data)
			}

			/* ANC */
			0x0b, 0x2b {
				addr, _ := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)
				cpu.and_with_register_a(data)
				if cpu.status.contains(CpuFlags.negativ) {
					cpu.status.insert(CpuFlags.carry)
				} else {
					cpu.status.remove(CpuFlags.carry)
				}
			}

			/* ALR */
			0x4b {
				addr, _ := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)
				cpu.and_with_register_a(data)
				cpu.lsr_accumulator()
			}

			//todo: test for everything bellow

			/* NOP read */
			0x04, 0x44, 0x64, 0x14, 0x34, 0x54, 0x74, 0xd4, 0xf4, 0x0c, 0x1c, 0x3c, 0x5c, 0x7c, 0xdc, 0xfc {
				addr, page_cross := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)

				if page_cross {
					cpu.bus.tick(1)
				}
				/* do nothing */
			}

			/* RRA */
			0x67, 0x77, 0x6f, 0x7f, 0x7b, 0x63, 0x73 {
				data := cpu.ror(opcode.mode)
				cpu.add_to_register_a(data)
			}

			/* ISB */
			0xe7, 0xf7, 0xef, 0xff, 0xfb, 0xe3, 0xf3 {
				data := cpu.inc(opcode.mode)
				cpu.sub_from_register_a(data)
			}

			/* NOPs */
			0x02, 0x12, 0x22, 0x32, 0x42, 0x52, 0x62, 0x72, 0x92, 0xb2, 0xd2, 0xf2 { /* do nothing */ }

			0x1a, 0x3a, 0x5a, 0x7a, 0xda, 0xfa { /* do nothing */ }

			/* LAX */
			0xa7, 0xb7, 0xaf, 0xbf, 0xa3, 0xb3 {
				addr, _ := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)
				cpu.set_register_a(data)
				cpu.register_x = cpu.register_a
			}

			/* SAX */
			0x87, 0x97, 0x8f, 0x83 {
				data := cpu.register_a & cpu.register_x
				addr, _ := cpu.get_operand_address(opcode.mode)
				cpu.mem_write(addr, data)
			}

			/* LXA */
			0xab {
				cpu.lda(opcode.mode)
				cpu.tax()
			}

			/* XAA */
			0x8b {
				cpu.register_a = cpu.register_x
				cpu.update_zero_and_negative_flags(cpu.register_a)
				addr, _ := cpu.get_operand_address(opcode.mode)
				data := cpu.mem_read(addr)
				cpu.and_with_register_a(data)
			}

			/* LAS */
			0xbb {
				addr, _ := cpu.get_operand_address(opcode.mode)
				mut data := cpu.mem_read(addr)
				data &= cpu.stack_pointer
				cpu.register_a = data
				cpu.register_x = data
				cpu.stack_pointer = data
				cpu.update_zero_and_negative_flags(data)
			}

			/* TAS */
			0x9b {
				mut data := cpu.register_a & cpu.register_x
				cpu.stack_pointer = data
				mem_address :=
					cpu.mem_read_u16(cpu.program_counter) + u16(cpu.register_y)

				data = (u8(mem_address >> 8) + 1) & cpu.stack_pointer
				cpu.mem_write(mem_address, data)
			}

			/* AHX  Indirect Y */
			0x93 {
				pos := cpu.mem_read(cpu.program_counter)
				mem_address := cpu.mem_read_u16(u16(pos)) + u16(cpu.register_y)
				data := cpu.register_a & cpu.register_x & u8(mem_address >> 8)
				cpu.mem_write(mem_address, data)
			}

			/* AHX Absolute Y*/
			0x9f {
				mem_address :=
					cpu.mem_read_u16(cpu.program_counter) + u16(cpu.register_y)

				data := cpu.register_a & cpu.register_x & u8(mem_address >> 8)
				cpu.mem_write(mem_address, data)
			}

			/* SHX */
			0x9e {
				mem_address :=
					cpu.mem_read_u16(cpu.program_counter) + u16(cpu.register_y)

				// todo if cross page boundry {
				//     mem_address &= (cpu.x as u16) << 8
				// }
				data := cpu.register_x & (u8(mem_address >> 8) + 1)
				cpu.mem_write(mem_address, data)
			}

			/* SHY */
			0x9c {
				mem_address :=
					cpu.mem_read_u16(cpu.program_counter) + u16(cpu.register_x)
				data := cpu.register_y & (u8(mem_address >> 8) + 1)
				cpu.mem_write(mem_address, data)
			}
			else { println("bruh") }
        }

		cpu.bus.tick(opcode.cycles)

        if program_counter_state == cpu.program_counter {
            cpu.program_counter += u16((opcode.len) - 1)
        }

    }
}
