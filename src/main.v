module main

import os
import gg
import time

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
	else if e.typ == .key_up {
		key_up(e.key_code, mut game)
	}
}

fn key_down(key gg.KeyCode, mut game Game) {
	match key {
		.up {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.up, true)
		}
		.down {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.down, true)
		}
		.left {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.left, true)
		}
		.right {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.right, true)
		}
		.space {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.@select, true)
		}
		.enter {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.start, true)
		}
		.a {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.button_a, true)
		}
		.s {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.button_b, true)
		}
		else { }
	}
}

fn key_up(key gg.KeyCode, mut game Game) {
	match key {
		.up {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.up, false)
		}
		.down {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.down, false)
		}
		.left {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.left, false)
		}
		.right {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.right, false)
		}
		.space {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.@select, false)
		}
		.enter {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.start, false)
		}
		.a {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.button_a, false)
		}
		.s {
			game.cpu.bus.joypad1.set_button_pressed_status(JoypadButtons.button_b, false)
		}
		else { }
	}
}


fn draw_frame(mut game Game) {
	game.gg.begin()
	for idx, c in game.frame.data {
		game.gg.draw_pixel((idx % 256), (idx / 256), c)
	}
	game.gg.end()
}

fn main() {
	data := os.read_file_array[u8]('super.nes')
	mut rom := Rom {}
	rom.new(data)

	mut bus := Bus {
		rom: rom
		ppu: NesPPU {
			chr_rom: rom.chr_rom
			mirroring: rom.screen_mirroring
		}
		joypad1: Joypad { }
	}
	mut cpu := CPU { bus: bus }

	mut game := &Game{
		gg: 0
		frame: Frame {}
		cpu: &cpu
	}

	mut frame := &game.frame
	cpu.bus.gameloop_callback = fn[mut frame] (ppu &NesPPU) {
		render(ppu, mut frame)
		time.sleep(10000000)
	}

	game.gg = gg.new_context(
		width: 256
		height: 240
		create_window: true
		window_title: 'NESEmulator'
		user_data: game
		frame_fn: draw_frame
		event_fn: on_event
	)

	cpu.reset()

	spawn game.cpu.run()

	game.gg.run()
}

