module main

fn test_0xa9_lda_immediate_load_data() {
    mut cpu := CPU { }
    cpu.load_and_run([u8(0xa9), 0x05, 0x00])
    assert cpu.register_a == 5
    assert cpu.status & 0b0000_0010 == 0b00
    assert cpu.status & 0b1000_0000 == 0
}

fn test_0xaa_tax_move_a_to_x() {
    mut cpu := CPU { }
    cpu.register_a = 10
    cpu.load_and_run([u8(0xaa), 0x00])

    assert cpu.register_x == 10
}

fn test_5_ops_working_together() {
    mut cpu := CPU { }
    cpu.load_and_run([u8(0xa9), 0xc0, 0xaa, 0xe8, 0x00])

    assert cpu.register_x == 0xc1
}

fn test_inx_overflow() {
    mut cpu := CPU { }
    cpu.register_x = 0xff
    cpu.load_and_run([u8(0xe8), 0xe8, 0x00])

    assert cpu.register_x == 1
}

fn test_lda_from_memory() {
    mut cpu := CPU { }
    cpu.mem_write(0x10, 0x55)

    cpu.load_and_run([u8(0xa5), 0x10, 0x00])

    assert cpu.register_a == 0x55
}
