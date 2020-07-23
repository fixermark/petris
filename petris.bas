//header for nesasm
asm
	.inesprg 1 ;//one PRG bank
	.ineschr 1 ;//one CHR bank
	.inesmir 0 ;//mirroring type 0
	.inesmap 0 ;//memory mapper 0 (none)
	.org $8000
	.bank 0
endasm


start:
	set a 0
	set $2000 a
	set $2001 a //turn off the PPU
	asm
		sei ;//disable interrupts
	endasm
	gosub vwait
	gosub vwait //it's good to wait 2 vblanks at the start
	asm
		ldx #$ff
		txs ;//reset the stack
	endasm
	set $2000 %10101000 //NMI, 8x16 sprites, bg 0, fg 1
	set $2001 %00011000 //show sprites, bg, clipping

// init global variables
	set dog_wag_timer 0
	set dog_wag_frame 0
	set current_arrow_on 0
	set arrow_change_timer 20

// prep us up
   	gosub load_palette
   	gosub clear_background
	gosub load_dog
	gosub load_arrows
	gosub arrows_off

mainloop:
	gosub nmi_wait
	gosub draw
	gosub vwait_end
	gosub game_step
	goto mainloop

// --------------------------

clear_background:
	set a $20
	gosub clear_background_helper
	set a $21
	gosub clear_background_helper
	set a $22
	gosub clear_background_helper
	set a $23
	gosub clear_background_helper
	return

// clears a chunk of background
// a is the high-order bit of mem to clear
clear_background_helper:
	push a
	gosub vwait
	pop a
	set $2006 a
	set $2006 0
	gosub clear_ppu_256
	return

//clear a quarter kilobyte of ppu memory (nametable+attrib)
clear_ppu_256:
	set a 0
	set x 0
	clear_ppu_256_1:
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		set $2007 a
		inc x
		if x <> 16 branchto clear_ppu_256_1
	return

// load the color palette
load_palette:
	set $2006 $3F
	set $2006 0
	set x 0
	load_palette_loop:
		set $2007 [palette x]
		inc x
		if x <> 12 branchto load_palette_loop
	return

// Set initial palette for all arrows
arrows_off:
	set color_pattern %01010101
	set quadrant 0
	set x 0
	arrows_off_loop:
		set $2006 [arrow_attribute_addresses x]
		inc x
		set $2006 [arrow_attribute_addresses x]
		inc x
		set quadrant [arrow_attribute_addresses x]
		set $2007 & color_pattern quadrant
		inc x
		if x <> 12 branchto arrows_off_loop
	return

arrow_on:
	set arrow_on_count current_arrow_on
	set arrow_on_offset 0
	gosub arrows_off
	arrow_on_loop:
		if arrow_on_count=0 branchto arrow_on_continue
		set arrow_on_offset + 3 arrow_on_offset
		dec arrow_on_count
		goto arrow_on_loop
	arrow_on_continue:
	set $2006 [arrow_attribute_addresses arrow_on_offset]
	inc arrow_on_offset
	set $2006 [arrow_attribute_addresses arrow_on_offset]
	inc arrow_on_offset
	set $2007 & %10101010 [arrow_attribute_addresses arrow_on_offset]
	return

// load dog into vram
load_dog:
	set load_dog_vram_major [dog_row_start 0]
	gosub vwait
	load_dog_1:
		set x 0
		set $2006 load_dog_vram_major
		set $2006 0
		load_dog_1_loop:
			set $2007 [dog_dat x]
			inc x
			if x <> 64 branchto load_dog_1_loop
	gosub vwait
	load_dog_2:
		set x 0
		set $2006 load_dog_vram_major
		set $2006 $40
		load_dog_2_loop:
			set $2007 [dog_dat_2 x]
			inc x
			if x <> 64 branchto load_dog_2_loop
	gosub vwait
	load_dog_3:
		set x 0
		set $2006 load_dog_vram_major
		set $2006 $80
		load_dog_3_loop:
			set $2007 [dog_dat_3 x]
			inc x
			if x <> 64 branchto load_dog_3_loop
	gosub vwait
	load_dog_4:
		set x 0
		set $2006 load_dog_vram_major
		set $2006 $C0
		load_dog_4_loop:
			set $2007 [dog_dat_4 x]
			inc x
			if x <> 64 branchto load_dog_4_loop
	gosub vwait
	load_dog_5:
		set x 0
		set $2006 + load_dog_vram_major 1
		set $2006 $00
		load_dog_5_loop:
			set $2007 [dog_dat_5 x]
			inc x
			if x <> 32 branchto load_dog_5_loop
	return

load_arrows:
	set load_arrows_coord_idx 0
	set load_arrows_tile_idx 0
	set load_arrows_load_count 0
	load_arrows_loop:
		set $2006 [arrow_coordinates load_arrows_coord_idx]
		inc load_arrows_coord_idx
		set $2006 [arrow_coordinates load_arrows_coord_idx]
		inc load_arrows_coord_idx
		set $2007 [arrow_tiles load_arrows_tile_idx]
		inc load_arrows_tile_idx
		set $2007 [arrow_tiles load_arrows_tile_idx]
		inc load_arrows_tile_idx

		set $2006 [arrow_coordinates load_arrows_coord_idx]
		inc load_arrows_coord_idx
		set $2006 [arrow_coordinates load_arrows_coord_idx]
		inc load_arrows_coord_idx
		set $2007 [arrow_tiles load_arrows_tile_idx]
		inc load_arrows_tile_idx
		set $2007 [arrow_tiles load_arrows_tile_idx]
		inc load_arrows_tile_idx
		inc load_arrows_load_count
		if load_arrows_load_count <> 4 branchto load_arrows_loop
	return


nmi_wait:
	set nmi_hit 0
	nmi_wait_1:
		if nmi_hit = 0 branchto nmi_wait_1
	return

//When enabled (bit 7 of $2000) NMI executes at 60fps
nmi:
	push a
	push x
	push y
	set nmi_hit 1
	pop y
	pop x
	pop a
	resume

irq:
	resume

//wait full vertical retrace
vwait:
	gosub vwait_start
	gosub vwait_end
	return

//wait until start of vertical retrace
vwait_start:
	asm
		lda $2002
		bpl vwait_start
	endasm
	return

//wait until end of vertical retrace
vwait_end:
	asm
		lda $2002
		bmi vwait_end
	endasm
	//set scroll and PPU base address
	set a 0
	set $2005 a
	set $2005 a
	set $2006 a
	set $2006 a
	return

game_step:
	set dog_wag_timer + dog_wag_timer 1
	if dog_wag_timer = 32 then
	   set dog_wag_timer 0
	   inc dog_wag_frame
	   if dog_wag_frame = 2 set dog_wag_frame 0
	endif
	set arrow_change_timer - arrow_change_timer 1
	if arrow_change_timer = 0 then
	   set arrow_change_timer 20
	   inc current_arrow_on
	   if current_arrow_on = 4 set current_arrow_on 0
	endif
	return

draw:
	gosub dog_wag
	gosub arrow_on
	return

dog_wag:
	set $2006 [dog_wag_tile 0]
	set $2006 [dog_wag_tile 1]
	set $2007 [dog_wag_chrs dog_wag_frame]
	// Note: not sure why this is necessary, but it
	// stops the screen from tearing when $2006 and $2007
	// get updated
	set $2005 0
	set $2005 0
	return


// dog is 9 high, 13 wide
// start at row 8, col 8
dog_row_start:
	data $21, 0

dog_dat:  // $2100
	data 0,0,0,0,0,0,0,0,0,0,$42,$43,$44,$45,0,0
	data 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	data 0,0,0,0,0,0,0,0,$50,$51,$52,$53,$54,$55,0,0
	data 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
dog_dat_2: // $2140
	data 0,0,0,0,0,0,0,0,0,$61,$62,$63,$64,$65,$66,$67
	data $68,$69,$6A,$6B,$6C,0,0,0,0,0,0,0,0,0,0,0
	data 0,0,0,0,0,0,0,0,0,0,0,$73,$74,$75,$76,$77
	data $78,$79,$7A,$7B,$7C,0,0,0,0,0,0,0,0,0,0,0
dog_dat_3: // $2180
	data 0,0,0,0,0,0,0,0,0,0,0,$83,$84,$85,$86,$87
	data $88,$89,$8A,$8B,$8C,0,0,0,0,0,0,0,0,0,0,0
	data 0,0,0,0,0,0,0,0,0,0,0,$93,$94,$95,$96,$97
	data $98,$99,$9A,$9B,$9C,0,0,0,0,0,0,0,0,0,0,0
dog_dat_4: // $21C0
	data 0,0,0,0,0,0,0,0,0,0,0,0,$A4,$A5,$A6,$A7
	data $A8,$A9,$AA,$AB,$AC,0,0,0,0,0,0,0,0,0,0,0
	data 0,0,0,0,0,0,0,0,0,0,0,0,$B4,$B5,0,0
	data 0,0,0,$BB,$BC,0,0,0,0,0,0,0,0,0,0,0
dog_dat_5: // $2200
	data 0,0,0,0,0,0,0,0,0,0,0,0,$C4,$C5,0,0
	data 0,0,0,$CB,$CC,0,0,0,0,0,0,0,0,0,0,0
dog_wag_chrs:
	data $8C,$8D
dog_wag_tile:
	data $21,$94

// arrow top-left coordinates: left, top, right, bottom
arrow_coordinates:
	// left
	data $20, $CA, $20, $EA
	// top
	data $21, $0E, $21, $2E
	// right
	data $21, $12, $21, $32
	// bottom
	data $21, $CA, $21, $EA

arrow_tiles:
	// left
	data $22, $23, $32, $33
	// top
	data $46, $47, $56, $57
	// right
	data $4A, $4B, $5A, $5B
	// bottom
	data $A2, $A3, $B2, $B3

// encoded as high and low order bit of attribute, and bitmask for quadrant to set
arrow_attribute_addresses:
	// left (bottom-right)
	data $23, $CA, $C0
	// top
	data $23, $D3, $0C
	// right
	data $23, $D4, $0C
	// bottom
	data $23, $DA, $C0

palette:
	// background
	data $0F
	// dog
	data $20, $27, $CC
	// (unused)
	data $0F
	// arrow dark
	data $01, $11, $12
	// (unused)
	data $0F
	// arrow bright
	data $11, $22, $31


//file footer
asm
;//jump table points to NMI, Reset, and IRQ start points
	.bank 1
	.org $fffa
	.dw nmi, start, irq
;//include CHR ROM
	.bank 2
	.org $0000
	.incbin "background.chr"
	.incbin "foreground.chr"
endasm

