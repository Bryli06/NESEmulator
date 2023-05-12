module main

import gg
import gx
import rand
import time

fn color_matcher(b u8) gx.Color {
    match b {
        0 { return gx.black }
        1 { return gx.white }
        2, 9 { return gx.gray }
        3, 10 { return gx.red }
        4, 11 { return gx.green }
        5, 12 { return gx.blue }
        6, 13 { return gx.magenta }
        7, 14 { return gx.yellow }
        else { return gx.cyan }
    }
}

[heap]
struct Game {
mut:
	gg &gg.Context = unsafe { nil }
	frame [1024]gx.Color
	cpu &CPU
}

fn on_event(e &gg.Event, mut game Game) {
	if e.typ == .key_down {
		key_down(e.key_code, mut game)
	}
}

fn key_down(key gg.KeyCode, mut game Game) {
	match key {
		.up {
			game.cpu.mem_write(0xff, 0x77)
		}
		.down {
			game.cpu.mem_write(0xff, 0x73)
		}
		.left {
			game.cpu.mem_write(0xff, 0x61)
		}
		.right {
			game.cpu.mem_write(0xff, 0x64)
		}
		else { }
	}
}

fn frame(mut game Game) {
	game.gg.begin()
	for idx, c in game.frame {
		game.gg.draw_square_filled(10*(idx % 32), 10*(idx / 32),10, c)
	}
	game.gg.end()
}

fn (mut game Game) read_state() {
    mut update := false
    for i in 0x0200..0x600 {
        color_idx := game.cpu.mem_read(u16(i))
        color := color_matcher(color_idx)
        if game.frame[i-0x0200] != color {
			game.frame[i-0x0200] = color
            update = true
        }
    }
	if update {
		game.gg.refresh_ui()
	}
}

fn (mut game Game) update(mut cpu CPU) {

	cpu.mem_write(0xfe, u8(rand.int31() % 14 + 2))

	game.read_state()

	time.sleep(70000)
}


fn main() {
	mut bus := Bus {}
	mut cpu := CPU {bus: bus}

	mut game := &Game{
		gg: 0
		frame: [1024]gx.Color {}
		cpu: &cpu
	}

	game.gg = gg.new_context(
		bg_color: gx.white
		width: 320
		height: 320
		create_window: true
		window_title: 'snek'
		user_data: game
		frame_fn: frame
		event_fn: on_event
	)

	game_code := [
	u8(0x20), 0x06, 0x06, 0x20, 0x38, 0x06, 0x20, 0x0d, 0x06, 0x20, 0x2a, 0x06, 0x60, 0xa9, 0x02,
        0x85, 0x02, 0xa9, 0x04, 0x85, 0x03, 0xa9, 0x11, 0x85, 0x10, 0xa9, 0x10, 0x85, 0x12, 0xa9,
        0x0f, 0x85, 0x14, 0xa9, 0x04, 0x85, 0x11, 0x85, 0x13, 0x85, 0x15, 0x60, 0xa5, 0xfe, 0x85,
        0x00, 0xa5, 0xfe, 0x29, 0x03, 0x18, 0x69, 0x02, 0x85, 0x01, 0x60, 0x20, 0x4d, 0x06, 0x20,
        0x8d, 0x06, 0x20, 0xc3, 0x06, 0x20, 0x19, 0x07, 0x20, 0x20, 0x07, 0x20, 0x2d, 0x07, 0x4c,
        0x38, 0x06, 0xa5, 0xff, 0xc9, 0x77, 0xf0, 0x0d, 0xc9, 0x64, 0xf0, 0x14, 0xc9, 0x73, 0xf0,
        0x1b, 0xc9, 0x61, 0xf0, 0x22, 0x60, 0xa9, 0x04, 0x24, 0x02, 0xd0, 0x26, 0xa9, 0x01, 0x85,
        0x02, 0x60, 0xa9, 0x08, 0x24, 0x02, 0xd0, 0x1b, 0xa9, 0x02, 0x85, 0x02, 0x60, 0xa9, 0x01,
        0x24, 0x02, 0xd0, 0x10, 0xa9, 0x04, 0x85, 0x02, 0x60, 0xa9, 0x02, 0x24, 0x02, 0xd0, 0x05,
        0xa9, 0x08, 0x85, 0x02, 0x60, 0x60, 0x20, 0x94, 0x06, 0x20, 0xa8, 0x06, 0x60, 0xa5, 0x00,
        0xc5, 0x10, 0xd0, 0x0d, 0xa5, 0x01, 0xc5, 0x11, 0xd0, 0x07, 0xe6, 0x03, 0xe6, 0x03, 0x20,
        0x2a, 0x06, 0x60, 0xa2, 0x02, 0xb5, 0x10, 0xc5, 0x10, 0xd0, 0x06, 0xb5, 0x11, 0xc5, 0x11,
        0xf0, 0x09, 0xe8, 0xe8, 0xe4, 0x03, 0xf0, 0x06, 0x4c, 0xaa, 0x06, 0x4c, 0x35, 0x07, 0x60,
        0xa6, 0x03, 0xca, 0x8a, 0xb5, 0x10, 0x95, 0x12, 0xca, 0x10, 0xf9, 0xa5, 0x02, 0x4a, 0xb0,
        0x09, 0x4a, 0xb0, 0x19, 0x4a, 0xb0, 0x1f, 0x4a, 0xb0, 0x2f, 0xa5, 0x10, 0x38, 0xe9, 0x20,
        0x85, 0x10, 0x90, 0x01, 0x60, 0xc6, 0x11, 0xa9, 0x01, 0xc5, 0x11, 0xf0, 0x28, 0x60, 0xe6,
        0x10, 0xa9, 0x1f, 0x24, 0x10, 0xf0, 0x1f, 0x60, 0xa5, 0x10, 0x18, 0x69, 0x20, 0x85, 0x10,
        0xb0, 0x01, 0x60, 0xe6, 0x11, 0xa9, 0x06, 0xc5, 0x11, 0xf0, 0x0c, 0x60, 0xc6, 0x10, 0xa5,
        0x10, 0x29, 0x1f, 0xc9, 0x1f, 0xf0, 0x01, 0x60, 0x4c, 0x35, 0x07, 0xa0, 0x00, 0xa5, 0xfe,
        0x91, 0x00, 0x60, 0xa6, 0x03, 0xa9, 0x00, 0x81, 0x10, 0xa2, 0x00, 0xa9, 0x01, 0x81, 0x10,
        0x60, 0xa6, 0xff, 0xea, 0xea, 0xca, 0xd0, 0xfb, 0x60,
	]

	cpu.load(game_code)
	cpu.reset()
	cpu.program_counter = 0x0600

	spawn game.cpu.run_with_callback(game.update)

	game.gg.run()

}

