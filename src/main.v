module main

import os
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
	frame Frame
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
	for idx, c in game.frame.data {
		game.gg.draw_pixel((idx % 256), (idx / 256), c)
	}
	game.gg.end()
}

/*
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
}*/

fn (mut game Game) update(ppu &NesPPU) {

	//cpu.mem_write(0xfe, u8(rand.int31() % 14 + 2))

	//game.read_state()

	//time.sleep(70000)
	render(ppu, mut game.frame)
}


fn main() {
	data := os.read_file_array[u8]('pacman.nes')
	mut rom := Rom {}
	rom.new(data)

	mut bus := Bus {
		rom: rom
		ppu: NesPPU {
			chr_rom: rom.chr_rom
			mirroring: rom.screen_mirroring
		}
	}
	mut cpu := CPU { bus: bus }

	mut game := &Game{
		gg: 0
		frame: Frame {}
		cpu: &cpu
	}

	cpu.bus.gameloop_callback = game.update

	game.gg = gg.new_context(
		bg_color: gx.white
		width: 256
		height: 240
		create_window: true
		window_title: 'pacman'
		user_data: game
		frame_fn: frame
		event_fn: on_event
	)

	cpu.reset()

	spawn game.cpu.run()

	game.gg.run()

}

