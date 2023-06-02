module main

import gx

const (
	system_palette = [
	   gx.rgb(0x80, 0x80, 0x80), gx.rgb(0x00, 0x3D, 0xA6), gx.rgb(0x00, 0x12, 0xB0), gx.rgb(0x44, 0x00, 0x96), gx.rgb(0xA1, 0x00, 0x5E),
	   gx.rgb(0xC7, 0x00, 0x28), gx.rgb(0xBA, 0x06, 0x00), gx.rgb(0x8C, 0x17, 0x00), gx.rgb(0x5C, 0x2F, 0x00), gx.rgb(0x10, 0x45, 0x00),
	   gx.rgb(0x05, 0x4A, 0x00), gx.rgb(0x00, 0x47, 0x2E), gx.rgb(0x00, 0x41, 0x66), gx.rgb(0x00, 0x00, 0x00), gx.rgb(0x05, 0x05, 0x05),
	   gx.rgb(0x05, 0x05, 0x05), gx.rgb(0xC7, 0xC7, 0xC7), gx.rgb(0x00, 0x77, 0xFF), gx.rgb(0x21, 0x55, 0xFF), gx.rgb(0x82, 0x37, 0xFA),
	   gx.rgb(0xEB, 0x2F, 0xB5), gx.rgb(0xFF, 0x29, 0x50), gx.rgb(0xFF, 0x22, 0x00), gx.rgb(0xD6, 0x32, 0x00), gx.rgb(0xC4, 0x62, 0x00),
	   gx.rgb(0x35, 0x80, 0x00), gx.rgb(0x05, 0x8F, 0x00), gx.rgb(0x00, 0x8A, 0x55), gx.rgb(0x00, 0x99, 0xCC), gx.rgb(0x21, 0x21, 0x21),
	   gx.rgb(0x09, 0x09, 0x09), gx.rgb(0x09, 0x09, 0x09), gx.rgb(0xFF, 0xFF, 0xFF), gx.rgb(0x0F, 0xD7, 0xFF), gx.rgb(0x69, 0xA2, 0xFF),
	   gx.rgb(0xD4, 0x80, 0xFF), gx.rgb(0xFF, 0x45, 0xF3), gx.rgb(0xFF, 0x61, 0x8B), gx.rgb(0xFF, 0x88, 0x33), gx.rgb(0xFF, 0x9C, 0x12),
	   gx.rgb(0xFA, 0xBC, 0x20), gx.rgb(0x9F, 0xE3, 0x0E), gx.rgb(0x2B, 0xF0, 0x35), gx.rgb(0x0C, 0xF0, 0xA4), gx.rgb(0x05, 0xFB, 0xFF),
	   gx.rgb(0x5E, 0x5E, 0x5E), gx.rgb(0x0D, 0x0D, 0x0D), gx.rgb(0x0D, 0x0D, 0x0D), gx.rgb(0xFF, 0xFF, 0xFF), gx.rgb(0xA6, 0xFC, 0xFF),
	   gx.rgb(0xB3, 0xEC, 0xFF), gx.rgb(0xDA, 0xAB, 0xEB), gx.rgb(0xFF, 0xA8, 0xF9), gx.rgb(0xFF, 0xAB, 0xB3), gx.rgb(0xFF, 0xD2, 0xB0),
	   gx.rgb(0xFF, 0xEF, 0xA6), gx.rgb(0xFF, 0xF7, 0x9C), gx.rgb(0xD7, 0xE8, 0x95), gx.rgb(0xA6, 0xED, 0xAF), gx.rgb(0xA2, 0xF2, 0xDA),
	   gx.rgb(0x99, 0xFF, 0xFC), gx.rgb(0xDD, 0xDD, 0xDD), gx.rgb(0x11, 0x11, 0x11), gx.rgb(0x11, 0x11, 0x11)
	]
)

pub struct Frame {
	width usize = 256
	height usize = 240
mut:
	data []gx.Color = []gx.Color{len: 256 * 240, cap: 256*240}
}

pub fn (mut frame Frame) set_pixel(x usize, y usize, rgb gx.Color) {
	idx := y * frame.width + x
	if idx < frame.data.len {
		frame.data[idx] = rgb
	}
}

struct Rect {
    x1 usize
    y1 usize
    x2 usize
    y2 usize
}

fn render_name_table(ppu &NesPPU, mut frame Frame, name_table []u8, view_port Rect, shift_x isize, shift_y isize) {
    bank := ppu.ctrl.bknd_pattern_addr()

    attribute_table := name_table[0x3c0..0x400]

    for i in 0..0x3c0 {
        tile_column := i % 32
        tile_row := i / 32
        tile_idx := u16(name_table[i])
		tile := ppu.chr_rom[(bank + tile_idx * 16)..(bank + tile_idx * 16 + 15 + 1)]
        palette := background_palette(ppu, attribute_table, tile_column, tile_row)

        for y in 0..8 {
            mut upper := tile[y]
            mut lower := tile[y + 8]

			for x := 7; x >= 0; x-- {
				value := (1 & lower) << 1 | (1 & upper)
				upper >>= 1
				lower >>= 1
				rgb := system_palette[usize(palette[value])]
				pixel_x := tile_column * 8 + x
                pixel_y := tile_row * 8 + y

                if pixel_x >= view_port.x1 && pixel_x < view_port.x2 && pixel_y >= view_port.y1 && pixel_y < view_port.y2 {
                    frame.set_pixel(usize(shift_x + isize(pixel_x)), usize(shift_y + isize(pixel_y)), rgb)
                }
           }
        }
    }
}

pub fn render(ppu &NesPPU, mut frame Frame) {
	scroll_x := usize(ppu.scroll.scroll_x)
    scroll_y := usize(ppu.scroll.scroll_y)

    main_nametable, second_nametable := match ppu.mirroring {
		.vertical {
			match ppu.ctrl.nametable_addr() {
				0x2000, 0x2800 {
					ppu.vram[0..0x400], ppu.vram[0x400..0x800]
				}
				0x2400, 0x2c00 {
					ppu.vram[0x400..0x800], ppu.vram[0..0x400]
				}
				else { panic('how u get here') }
			}
		}
		.horizontal {
			match ppu.ctrl.nametable_addr() {
				0x2000, 0x2400 {
					ppu.vram[0..0x400], ppu.vram[0x400..0x800]
				}
				0x2800, 0x2c00 {
					ppu.vram[0x400..0x800], ppu.vram[0..0x400]
				}
				else { panic('how u get here') }
			}
		}
		else { panic('not supported mirroring type ${ppu.mirroring}') }
    }

    render_name_table(ppu, mut frame,
        main_nametable,
        Rect {
			x1: scroll_x,
			y1: scroll_y,
			x2: 256,
			y2: 240
		},
        -1 * isize(scroll_x), -1 * isize(scroll_y)
    )
    if scroll_x > 0 {
        render_name_table(ppu, mut frame,
            second_nametable,
            Rect {
				x1: 0,
				y1: 0,
				x2: scroll_x,
				y2: 240
			},
            isize(256 - scroll_x), 0
        )
    }
	else if scroll_y > 0 {
        render_name_table(ppu, mut frame,
            second_nametable,
            Rect {
				x1: 0,
				y1: 0,
				x2: 256,
				y2: scroll_y
			},
            0, isize(240 - scroll_y)
        )
    }


	for i := (ppu.oam_data.len-1) / 4 * 4; i >= 0; i-=4 {
        tile_idx := u16(ppu.oam_data[i + 1])
        tile_x := ppu.oam_data[i + 3]
        tile_y := ppu.oam_data[i]

        flip_vertical := bool(ppu.oam_data[i + 2] >> 7 & 1 == 1)
        flip_horizontal := bool(ppu.oam_data[i + 2] >> 6 & 1 == 1)
        pallette_idx := ppu.oam_data[i + 2] & 0b11
        palette := sprite_palette(ppu, pallette_idx)
        bank := ppu.ctrl.sprt_pattern_addr()

		tile := ppu.chr_rom[(bank + tile_idx * 16)..(bank + tile_idx * 16 + 15 + 1)]

        for y in 0..8 {
			mut upper := tile[y]
			mut lower := tile[y + 8]

			inner: for x := 7; x >= 0; x-- {
                value := (1 & lower) << 1 | (1 & upper)
                upper >>= 1
                lower >>= 1

                rgb := if value > 0 {
					system_palette[usize(palette[value])]
                } else {
					continue inner
					gx.rgb(0,0,0)
				}

				// println('${tile_x}, ${tile_y}')

				frame.set_pixel(
					if flip_horizontal { usize(tile_x + 7 - x) }
					else { usize(tile_x + x) },
					if flip_vertical { usize(tile_y + 7 - y) }
					else { usize(tile_y + y) },
					rgb
				)
            }
        }
    }
}

fn background_palette(ppu &NesPPU, attribute_table []u8, tile_column int, tile_row int) []u8 {
    attr_table_idx := tile_row / 4 * 8 + tile_column / 4
    attr_byte := attribute_table[attr_table_idx]

	palette_idx := (attr_byte >> ((tile_column % 4 / 2) * 2 + (tile_row % 4 / 2) * 4)) & 0b11 // disgusting

    palette_start := usize(1 + palette_idx * 4)
    return [
        ppu.palette_table[0],
        ppu.palette_table[palette_start],
        ppu.palette_table[palette_start + 1],
        ppu.palette_table[palette_start + 2],
    ]
}

fn sprite_palette(ppu &NesPPU, palette_idx u8) []u8 {
    palette_start := usize(0x11 + (palette_idx * 4))
    return [
        u8(0),
        ppu.palette_table[palette_start],
        ppu.palette_table[palette_start + 1],
        ppu.palette_table[palette_start + 2],
    ]
}
