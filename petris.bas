// Petris copyright 2020 Mark T. Tomczak
// Source code released under MIT license; see LICENSE file for details
//
// FamiStudio music engine is copyright 2019 BleuBleu, used
// as per the rules of the MIT license. FamiStudio is available at
// https://github.com/BleuBleu/FamiStudio

//header for nesasm
asm
	.inesprg 1 ;//one PRG bank
	.ineschr 1 ;//one CHR bank
	.inesmir 1 ;//mirroring type 1 (vertical)
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
	set $2000 %10000000 //NMI, 8x8 sprites, bg 0, fg 0
	set $2001 %00000000 // disable PPU for initialization

// init global variables
   	array absolute $200 sprite_mem 256
	array sprite_y 4
	array sprite_x 4
	array sprite_anim_idx 4
	array joy 4
	array joy_prev 4
	array joy_edge 4
	array scores 4
	array zeropage seed 2

initgame:
	gosub init_music
	set [seed 0] 19
	set [seed 1] 82
	set initgame_ctr 0
	    initgame_loop:
		set [sprite_y initgame_ctr] $FF
		set [sprite_x initgame_ctr] $00
		set [sprite_anim_idx initgame_ctr] $FF
		inc initgame_ctr
		if initgame_ctr <> 4 branchto initgame_loop
	set dog_wag_timer 0
	set dog_wag_frame 0
	set current_arrow_on 0
	set arrow_change_timer 20
	set playing 0
	set [scores 0] 0
	set [scores 1] 0
	set [scores 2] 0
	set [scores 3] 0

// prep us up
   	gosub clear_background
	gosub load_palette
	gosub clear_second_buffer
	gosub load_logo
	gosub load_copyright
	gosub load_dog
	gosub load_press_a_msg
	gosub load_arrows
	gosub load_score_text_init
	gosub load_score_hand_sprites
	gosub load_play_hand_sprites
	gosub load_end_screen
	gosub arrows_off

	gosub vwait
	set $2001 %00011000 //show sprites, bg

// -------- GAME LOGIC ------

mainwait:
	gosub nmi_wait
	// flush the sprites at $200 to the sprite buffer
	set $4014 2
	gosub vwait_end
	gosub load_joysticks
	set [seed 0] + [seed 0] 1
	if [seed 0] = 0 set [seed 1] + [seed 1] 1
	if [seed 1] = 0 set [seed 1] 1
	gosub update_hands
	// check A button press
	if & [joy_edge 0]  %10000000 = 0 branchto mainwait

	gosub nmi_wait
	gosub clear_press_a_msg
	gosub clear_copyright
	gosub vwait_end

set countdown_step 3
set countdown_delay 60
countdown:
	gosub nmi_wait
	gosub draw_countdown
	gosub vwait_end
	gosub load_joysticks
	dec countdown_delay
	if countdown_delay = 0 then
	   dec countdown_step
	   set countdown_delay 60
	endif
	if countdown_step <> 0 branchto countdown

	gosub nmi_wait
	gosub load_pet_msg
	gosub vwait_end

	set playing 1
	set countdown_step 20
	set countdown_delay 60
	gosub play_game_song
mainloop:
	gosub nmi_wait
	gosub draw
	gosub vwait_end
	gosub update_game_music
	gosub load_joysticks
	gosub game_step
	if countdown_step <> 0 branchto mainloop

enter_end:
	set playing 0
	gosub stop_game_song
	gosub hide_hands
	gosub compute_winner
	set enter_end_ctr 1
	enter_end_loop:
		set [sprite_mem enter_end_ctr] $01
		set enter_end_ctr + enter_end_ctr 4
		if enter_end_ctr <> 17 branchto enter_end_loop

end:
	gosub nmi_wait
	gosub draw_scores
	// flush the sprites at $200 to the sprite buffer
	set $4014 2
	gosub vwait_end
	set $2000 %10000001 //NMI, 8x8 sprites, scroll one page over

	gosub load_joysticks
	if & [joy_edge 0] %10000000 = 0 branchto end

	// pause rendering
	set $2001 0
	set $2005 0
	set $2005 0
	set $2000 %10000000
	goto initgame

// Controller data format
// H - - - - - - - - L
//   A B S S U D L R
//       E T
load_joysticks:
	set [joy 0] 0
	set $4016 1 // first strobe byte
	set $4016 0 // second strobe byte
	set load_joysticks_loopctr 0
	load_joysticks_loop_p1:
		set [joy 0] << [joy 0] 1
		set [joy 0] | [joy 0] & [$4016] 1
		inc load_joysticks_loopctr
		if load_joysticks_loopctr <> 8 branchto load_joysticks_loop_p1
	set [joy 2] 0
	// no strobe
	set load_joysticks_loopctr 0
	load_joysticks_loop_p3:
		set [joy 2] << [joy 2] 1
		set [joy 2] | [joy 2] & [$4016] 1
		inc load_joysticks_loopctr
		if load_joysticks_loopctr <> 8 branchto load_joysticks_loop_p3
	set [joy 1] 0
	set $4017 1 // first strobe byte
	set $4017 0 // second strobe byte
	set load_joysticks_loopctr 0
	load_joysticks_loop_p2:
		set [joy 1] << [joy 1] 1
		set [joy 1] | [joy 1] & [$4017] 1
		inc load_joysticks_loopctr
		if load_joysticks_loopctr <> 8 branchto load_joysticks_loop_p2
	set [joy 3] 0
	// no strobe
	set load_joysticks_loopctr 0
	load_joysticks_loop_p4:
		set [joy 3] << [joy 3] 1
		set [joy 3] | [joy 3] & [$4017] 1
		inc load_joysticks_loopctr
		if load_joysticks_loopctr <> 8 branchto load_joysticks_loop_p4
	// set up rising edges
	set load_joysticks_loopctr 0
	load_joysticks_loop_rise:
		set detect_edge_cur [joy load_joysticks_loopctr]
		set detect_edge_prev [joy_prev load_joysticks_loopctr]
		gosub detect_edge
		set [joy_edge load_joysticks_loopctr] detect_edge_cur
		set [joy_prev load_joysticks_loopctr] [joy load_joysticks_loopctr]
		inc load_joysticks_loopctr
		if load_joysticks_loopctr <> 4 branchto load_joysticks_loop_rise
	return

// expects detect_edge_cur and detect_edge_prev to be set to cur and prev vals
// on return, detect_edge_cur is the rising edges and detect_edge_prev is destroyed
detect_edge:
	// NOT detect_edge_prev
	set detect_edge_prev ^ %11111111 detect_edge_prev
	set detect_edge_cur & detect_edge_cur detect_edge_prev
	return


update_hands:
	set update_hands_player 0
	update_hands_loop:
		set find_hand_dir_arg [joy_edge update_hands_player]
		gosub find_hand_dir
		if find_hand_dir_arg <> 0 then
				set hand_click_arg - find_hand_dir_arg 1
				gosub hand_click
		endif
		inc update_hands_player
		if update_hands_player <> 4 branchto update_hands_loop

// figure out which direction the hand points based on edge-detect on a joystick
// input: find_hand_dir_arg is the edge-detect on the joy controlling the hand
// output: find_hand_dir_arg is the hand direction (0=none, 1=right, 2=left, 3=down, 4=up)
find_hand_dir:
	set find_hand_dir_arg & find_hand_dir_arg %00001111
	if find_hand_dir_arg = 0 return
	set find_hand_dir_accum 0
	find_hand_dir_loop:
		inc find_hand_dir_accum
		set find_hand_dir_arg >> find_hand_dir_arg 1
		if find_hand_dir_arg <> 0 branchto find_hand_dir_loop
	set find_hand_dir_arg find_hand_dir_accum
	return

// updates the hand state when controller button pressed
// update_hands_player: player we are updating
// hand_click_arg: direction that was clicked (0=right, 1=left, 2=down, 3=up), or 0 for no click
hand_click:
	set uhoh 0
	if playing = 1 then
	   	   // determine if score goes up or down
	      	   if hand_click_arg = current_arrow_on set [scores update_hands_player] + [scores update_hands_player] 1
		   if hand_click_arg <> current_arrow_on then
	   	      if [scores update_hands_player] > 0 set [scores update_hands_player] - [scores update_hands_player] 1
		      set uhoh 1
		   endif
	endif
	set hand_click_position_offset + << update_hands_player 3 << hand_click_arg 1
	set [sprite_y update_hands_player] [pet_hand_positions hand_click_position_offset]
	inc hand_click_position_offset
	set [sprite_x update_hands_player] [pet_hand_positions hand_click_position_offset]
	set [sprite_anim_idx update_hands_player] $00

	set hand_click_sprite_offset + << update_hands_player 2 1
	// switch from hand icon to X-hand icon if this was a bad pet
	set [sprite_mem hand_click_sprite_offset] + $01 uhoh
	return


// animation logic
animate:
	set animate_sprite_ctr 0
	animate_loop:
		set animate_sprite_y [sprite_y animate_sprite_ctr]
		set animate_sprite_x [sprite_x animate_sprite_ctr]
		set animate_sprite_idx [sprite_anim_idx animate_sprite_ctr]
		if animate_sprite_idx <> $FF then
		   if [animation animate_sprite_idx] = $80 branchto animate_finishsprite
		   set animate_sprite_y + animate_sprite_y [animation animate_sprite_idx]
		   inc animate_sprite_idx
		   set animate_sprite_x + animate_sprite_x [animation animate_sprite_idx]
		   inc animate_sprite_idx
		   set [sprite_anim_idx animate_sprite_ctr] animate_sprite_idx
		   goto animate_endif
		   animate_finishsprite:
			set [sprite_anim_idx animate_sprite_ctr] $FF
		   animate_endif:
		endif
		set [sprite_mem << animate_sprite_ctr 2] animate_sprite_y
		set [sprite_mem + << animate_sprite_ctr 2 3] animate_sprite_x
		inc animate_sprite_ctr
		if animate_sprite_ctr <> 4 goto animate_loop
	return


// -------- PPU MANIPULATION ---------

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

clear_second_buffer:
	set a $24
	gosub clear_background_helper
	set a $25
	gosub clear_background_helper
	set a $26
	gosub clear_background_helper
	set a $27
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
		if x <> 32 branchto load_palette_loop
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

// load Petris logo into vram
load_logo:
	set load_logo_row_idx 0
	set load_logo_first_tile_idx 0
	set load_logo_rows_loaded 0
	load_logo_row_loop:
		set $2006 [petris_logo_rows_start load_logo_row_idx]
		inc load_logo_row_idx
		set $2006 [petris_logo_rows_start load_logo_row_idx]
		inc load_logo_row_idx

		set load_logo_tile_to_load [petris_logo_row_first_tiles load_logo_first_tile_idx]
		inc load_logo_first_tile_idx
		set load_logo_tiles_loaded 0
		load_logo_tile_loop:
			set $2007 load_logo_tile_to_load
			inc load_logo_tile_to_load
			inc load_logo_tiles_loaded
			if load_logo_tiles_loaded <> 5 branchto load_logo_tile_loop
		inc load_logo_rows_loaded
		if load_logo_rows_loaded <> 2 branchto load_logo_row_loop
	return

load_copyright:
	set $2006 [copyright 0]
	set $2006 [copyright 1]
	set tmp [copyright 2]
	set ctr [copyright 3]
	load_copyright_loop:
		set $2007 tmp
		inc tmp
		dec ctr
		if ctr <> 0 branchto load_copyright_loop
	return

clear_copyright:
	set $2006 [copyright 0]
	set $2006 [copyright 1]
	set ctr [copyright 3]
	clear_copyright_loop:
		set $2007 $00
		dec ctr
		if ctr <> 0 branchto clear_copyright_loop
	return

// load "Press A!" call to action into VRAM
load_press_a_msg:
	set $2006 [press_a_msg 0]
	set $2006 [press_a_msg 1]
	set tmp [press_a_msg 2]
	set press_a_msg_ctr [press_a_msg 3]
	load_press_a_msg_loop:
		set $2007 tmp
		inc tmp
		dec press_a_msg_ctr
		if press_a_msg_ctr <> 0 branchto load_press_a_msg_loop
	return

clear_press_a_msg:
	set $2006 [press_a_msg 0]
	set $2006 [press_a_msg 1]
	set press_a_msg_ctr [press_a_msg 3]
	clear_press_a_msg_loop:
		set $2007 $00
		dec press_a_msg_ctr
		if press_a_msg_ctr <> 0 branchto clear_press_a_msg_loop
	return

// load "Pet!" call to action into VRAM
load_pet_msg:
	set $2006 [pet_msg 0]
	set $2006 [pet_msg 1]
	set tmp [pet_msg 2]
	set pet_msg_ctr [press_a_msg 3]
	load_pet_msg_loop:
		set $2007 tmp
		inc tmp
		dec pet_msg_ctr
		if pet_msg_ctr <> 0 branchto load_pet_msg_loop
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

// Play hands are sprites 0-3
load_play_hand_sprites:
	set lphs_ctr 0
	set lphs_attribs 0
	lphs_init:
		set [sprite_y lphs_ctr] $FF
		set [sprite_x lphs_ctr] $FF
		set [sprite_anim_idx lphs_ctr] $FF
		inc lphs_ctr
		if lphs_ctr <> 4 branchto lphs_init
	set lphs_ctr 0
	load_play_hand_sprites_loop:
		set [sprite_mem lphs_ctr] $FF
		inc lphs_ctr
		// hand icon is $01
		set [sprite_mem lphs_ctr] $01
		inc lphs_ctr
		set [sprite_mem lphs_ctr] lphs_attribs
		inc lphs_ctr
		// taking advantage of the fact palette selection is low-order bits, inc 1 to get player 2, player 3, etc. colors
		inc lphs_attribs
		set [sprite_mem lphs_ctr] $FF
		inc lphs_ctr
		// 16 is position of 4th sprite, 4 << 2
		if lphs_ctr <> 16 branchto load_play_hand_sprites_loop
	return


// Score hands are sprites 4-7
load_score_hand_sprites:
	// start at 4th sprite, 4 << 2
	set lshs_store_idx 16
	set lshs_load_idx 0
	set lshs_attribs 0
	load_score_hand_sprites_loop:
		set [sprite_mem lshs_store_idx] [score_hand_positions lshs_load_idx]
		inc lshs_store_idx
		inc lshs_load_idx

		// hand icon is $01
		set [sprite_mem lshs_store_idx] $01
		inc lshs_store_idx

		set [sprite_mem lshs_store_idx] lshs_attribs
		inc lshs_store_idx
		// taking advantage of the fact palette selection is low-order bits, inc 1 to get player 2, player 3, etc. colors
		inc lshs_attribs

		set [sprite_mem lshs_store_idx] [score_hand_positions lshs_load_idx]
		inc lshs_store_idx
		inc lshs_load_idx

		// 32 is position of 8th sprite, 8 << 2
		if lshs_store_idx <> 32 branchto load_score_hand_sprites_loop
	return

load_score_text_init:
	set lsti_page 0
	lsti_outer_loop:
		set lsti_counter 0
		set lsti_loadfrom 0
		lsti_loop:
			set lsti_tmp [score_text_positions lsti_loadfrom]
			set lsti_tmp + lsti_tmp << lsti_page 2
			set $2006 lsti_tmp
			inc lsti_loadfrom
			set $2006 - [score_text_positions lsti_loadfrom] 1
			inc lsti_loadfrom
			set $2007 $F1
			set $2007 $F2
			set $2007 $F2
			inc lsti_counter
			if lsti_counter <> 4 branchto lsti_loop
		inc lsti_page
		if lsti_page <> 2 branchto lsti_outer_loop
	return

load_end_screen:
	set $2006 [win_text 0]
	set $2006 [win_text 1]
	set load_end_screen_ctr 2
	load_end_screen_loop:
		set $2007 [win_text load_end_screen_ctr]
		inc load_end_screen_ctr
		if load_end_screen_ctr <> 10 branchto load_end_screen_loop
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
	if arrow_change_timer = 0 gosub change_arrow
	dec countdown_delay
	if countdown_delay = 0 then
	   set countdown_delay 60
	   dec countdown_step
	endif
	gosub update_hands
	gosub animate
	return

change_arrow:
	gosub random
	set change_arrow_val a
	set current_arrow_on & change_arrow_val %00000011
	set change_arrow_val %01111111
	set change_arrow_val >> change_arrow_val 1
	// choose a value between 72 and 103
	set arrow_change_timer + | change_arrow_val %00100000 40
	return


draw:
	gosub dog_wag
	gosub arrow_on
	gosub draw_scores
	gosub draw_timer
	// flush the sprites at $200 to the sprite buffer
	set $4014 2
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

draw_countdown:
	set $2006 [countdown_msg 0]
	set $2006 [countdown_msg 1]
	set $2007 + countdown_step $F2
	set $2007 [dot_dot_dot 0]
	return

draw_scores:
	set draw_scores_player 0
	draw_scores_loop:
		set compute_score_arg [scores draw_scores_player]
		gosub compute_score_sprites
		set draw_scores_textpo [score_text_positions << draw_scores_player 1]
		if playing = 0 set draw_scores_textpo + draw_scores_textpo $4
		set $2006 draw_scores_textpo
		set $2006 [score_text_positions + 1 << draw_scores_player 1]
		set $2007 score_sprite_tens
		set $2007 score_sprite_ones
		inc draw_scores_player
		if draw_scores_player <> 4 branchto draw_scores_loop
		return

draw_timer:
	set $2006 [clock_location 0]
	set $2006 [clock_location 1]
	set compute_score_arg countdown_step
	gosub compute_score_sprites
	set $2007 score_sprite_tens
	set $2007 score_sprite_ones
	return

// computes the sprites representing a score
// input: compute_score_arg is score to compute sprites for
// on return, score_sprite_tens is ID of tens, score_sprite_arg is ID of ones
compute_score_sprites:
	set score_sprite_tens 0
	if compute_score_arg < 10 then
	   set score_sprite_tens $F2
	   set score_sprite_ones + compute_score_arg $F2
	   return
	endif
	compute_score_sprites_loop:
		inc score_sprite_tens
		set compute_score_arg - compute_score_arg 10
		if compute_score_arg > 9 branchto compute_score_sprites_loop
	set score_sprite_tens + score_sprite_tens $F2
	set score_sprite_ones + compute_score_arg $F2
	return

hide_hands:
	set hide_hands_ctr 0
	hide_hands_loop:
		set [sprite_mem hide_hands_ctr] $FF
		set hide_hands_ctr + 4 hide_hands_ctr
		if hide_hands_ctr <> 16 branchto hide_hands_loop
	return

compute_winner:
	set winner 0
	set winner_score 0
	set winner_ctr 0
	compute_winner_find_loop:
		if [scores winner_ctr] > winner_score then
		   set winner winner_ctr
		   set winner_score [scores winner_ctr]
		endif
		inc winner_ctr
		if winner_ctr <> 4 branchto compute_winner_find_loop
	set [sprite_mem 0] 95
	set [sprite_mem 3] 119
	set [sprite_mem 2] winner
return

// galois 16-bit RNG, galois16 from https://github.com/bbbradsmith/prng_6502/blob/master/galois16.s
// on return, y is clobbered and a is set to an 8-bit random val
random:
	asm
		ldy #8
		lda seed+0
	endasm
random1:
	asm
		asl a       ; shift the register
		rol seed+1
		bcc random2
		eor #$39   ; apply XOR feedback whenever a 1 bit is shifted out
	endasm
random2:
	asm
		dey
		bne random1
		sta seed+0
		cmp #0     ; reload flags
		endasm
	return

// --------- GAME MUSIC ---------
init_music:
	asm
	  pha
	  txa
	  pha
	  tya
	  pha
	  lda #1
	  ldx #LOW(untitled_music_data)
	  ldy #HIGH(untitled_music_data)
	  jsr famistudio_init
	  pla
	  tay
	  pla
	  tax
	  pla
	endasm
	return

play_game_song:
	asm
	 pha
	 lda #0
	 jsr famistudio_music_play
	 pla
	endasm
	return

stop_game_song:
	asm
	 jsr famistudio_music_stop
	endasm
	return

update_game_music:
	asm
	 jsr famistudio_update
	endasm
	return

// --------- DATA -----------

// --- display objects

// Petris logo is 2 high, 5 wide
// start at tile y=3, x=11
petris_logo_rows_start:
	data $20, $6D, $20,$8D


petris_logo_row_first_tiles:
	data $05, $15

// Copyright text start y, start x, fist chr, length
copyright:
	data $22, $CA, $24, $0C

// "Press A!" call to action tile high-byte, tile low-byte, CHR start, CHR length
press_a_msg:
	data $21,$EE,$E7,$04

// "Pet!" call to action tile high-byte, tile low-byte, CHR start, CHR length
pet_msg:
	data $21,$EF,$EB,$03
// clock tile high-byte, tile low-byte
clock_location:
	data $22,$0F

// dot-dot-dot suffix CHR
dot_dot_dot:
	data $FC
// countdown high and low tile bytes
countdown_msg:
	data $21,$EF

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
	// right
	data $21, $12, $21, $32
	// left
	data $20, $CA, $20, $EA
	// bottom
	data $21, $CA, $21, $EA
	// top
	data $21, $0E, $21, $2E

arrow_tiles:
	// right
	data $4A, $4B, $5A, $5B
	// left
	data $22, $23, $32, $33
	// bottom
	data $A2, $A3, $B2, $B3
	// top
	data $46, $47, $56, $57

// encoded as high and low order bit of attribute, and bitmask for quadrant to set
arrow_attribute_addresses:
	// right
	data $23, $D4, $0C
	// left (bottom-right)
	data $23, $CA, $C0
	// bottom
	data $23, $DA, $C0
	// top
	data $23, $D3, $0C


// y and x pet positions of petting hands
// encoded as hand_index, <<3 + position(right,left,down,up) << 1
pet_hand_positions:
	data $4E,$8E, $3D,$59, $61,$57, $4F,$70
	data $4E,$94, $3D,$5F, $61,$5D, $4F,$76
	data $4E,$9A, $3D,$65, $61,$63, $4F,$7C
	data $4E,$A0, $3D,$6B, $61,$68, $4F,$81

// animation scripts
// format is pairs of y_offset, x_offset
// $80 indicates end of script
animation:
	data $FC, $00, $FD, $00, $FE, $00, $FF, $00, $80

// y and x positions of score hands
score_hand_positions:
	data $10,$10, $10,$C8, $C8,$10, $C8, $C8

// high-bit and low-bit background tile positions of score text
score_text_positions:
data $20,$44, $20,$5B
data $23,$24, $23,$3B

// high-bit, low-bit, and tile indices for "wins" text
win_text:
// 25 8b
	data $25, $8B, $E0, $E1, $E2, $E3, $00, $E4, $E5, $E6


palette:
	// background
	data $0F
	// dog
	data $20, $27, $CC
	// arrow dark
	data $0F
	data $01, $11, $12
	// arrow bright
	data $0F
	data $11, $22, $31
	// (unused)
	data $0F
	data $20, $27, $CC
	// P1 hand
	data $0F
	data $20, $26, $25
	// P2 hand
	data $0F
	data $20, $2A, $25
	// P3 hand
	data $0F
	data $20, $11, $25
	// P4 hand
	data $0F
	data $20, $23, $25


// FamiStudio sound engine
// sourced from https://raw.githubusercontent.com/BleuBleu/FamiStudio/master/SoundEngine/famistudio_nesasm.asm
// Changes:
// 1) renamed famistudio_pitch_env_fine_value to famistudio_pitch_env_fine_val to avoid nesasm internal error (too large name?)
// 2) renamed update_pitch_relate_last_value to update_pitch_relate_last_val to avoid nesasm internal error (too large name?)
// 3) renamed FAMISTUDIO_USE_FAMITRACKER_TEMPO to FAMISTUDIO_USE_FT_TEMPO (name too long?)
// 4) renamed famistudio_dummy_pitch_envelope to famistudio_dummy_pitch_env (name too long)
// 5) renamed pitch_relate_update_with_last_val to update_pitch_relate_last_val (name too long)
// 6) renamed famistudio_channel_to_pitch_env to famistudio_chan_to_pitch_env
// 7) replaced famistudio_spec_code_jmp with famistudio_spec_code_jmp (names too long)
// 8) replaced speccode_clear_pitch_override_flag with spec_code_clear_pitchovr_flag (name too long)
// 9) replaced speccode_override_pitch_envelope with spec_code_over_pitchenv (yep, name too long)
// 10) replaced all instances special_code_ with speccode_
// 11) replaced all speccode_clear_arpeggio_override_flag with speccode_clear_arpover_flag
// 12) replaced all speccode_override_arpeggio_envelope with speccode_override_arpenv
// 13) replaced all famistudio_channel_to_arpeggio_env with famistudio_chan_to_arpenv
// 14) replaced all famistudio_channel_to_volume_env with famistudio_chan_to_volenv
asm
;======================================================================================================================
; FAMISTUDIO SOUND ENGINE (2.2.0)
;
; This is the FamiStudio sound engine. It is used by the NSF and ROM exporter of FamiStudio and can be used to make
; games. It supports every feature from FamiStudio, some of them are toggeable to save CPU/memory.
;
; This is essentially a heavily modified version of FamiTone2 by Shiru. A lot of his code and comments are still
; present here, so massive thanks to him!! I am not trying to steal his work or anything, i renamed a lot of functions
; and variables because at some point it was becoming a mess of coding standards and getting hard to maintain.
;
; Moderately advanced users can probably figure out how to use the sound engine simply by reading these comments.
; For more in-depth documentation, please go to:
;
;    https://famistudio.org/doc/soundengine/
;======================================================================================================================

;======================================================================================================================
; INTERFACE
;
; The interface is pretty much the same as FamiTone2, with a slightly different naming convention. The subroutines you
; can call from your game are:
;
;   - famistudio_init            : Initialize the engine with some music data.
;   - famistudio_music_play      : Start music playback with a specific song.
;   - famistudio_music_pause     : Pause/unpause music playback.
;   - famistudio_music_stop      : Stops music playback.
;   - famistudio_sfx_init        : Initialize SFX engine with SFX data.
;   - famistudio_sfx_play        : Play a SFX.
;   - famistudio_sfx_sample_play : Play a DPCM SFX.
;   - famistudio_update          : Updates the music/SFX engine, call once per frame, ideally from NMI.
;
; You can check the demo ROM to see how they are used or check out the online documentation for more info.
;======================================================================================================================

;======================================================================================================================
; CONFIGURATION
;
; There are 2 main ways of configuring the engine.
;
;   1) The simplest way is right here, in the section below. Simply comment/uncomment these defines, and move on
;      with your life.
;
;   2) The second way is "externally", using definitions coming from elsewhere in your app or the command line. If you
;      wish do so, simply define FAMISTUDIO_CFG_EXTERNAL=1 and this whole section will be ignored. You are then
;      responsible for providing all configuration. This is useful if you have multiple projects that needs
;      different configurations, while pointing to the same code file. This is how the provided demos and FamiStudio
;      uses it.
;
; Note that unless specified, the engine uses "if" and not "ifdef" for all boolean values so you need to define these
; to non-zero values. Undefined values will be assumed to be zero.
;
; There are 4 main things to configure, each of them will be detailed below.
;
;   1) Segments (ZP/RAM/PRG)
;   2) Audio expansion
;   3) Global engine parameters
;   4) Supported features
;======================================================================================================================

    .ifndef FAMISTUDIO_CFG_EXTERNAL
FAMISTUDIO_CFG_EXTERNAL = 0
    .endif

; Set this to configure the sound engine from outside (in your app, or from the command line)
    .if !FAMISTUDIO_CFG_EXTERNAL

;======================================================================================================================
; 1) SEGMENT CONFIGURATION
;
; You need to tell where you want to allocate the zeropage, RAM and code. This section will be slightly different for
; each assembler.
;
; For NESASM, you can specify the .rsset location for zeroage and RAM/BSS as well as the .bank/.org for the engine
; code. The .zp/.bss/.code section directives can also be emitted.  ALl these values are optional and will be tested
; as .ifdef.
;======================================================================================================================

; Define this to emit the ".zp" directive before the zeropage variables.
; FAMISTUDIO_NESASM_ZP_SECTION   = 1

; Address where to allocate the zeropage variables that the engine use.
FAMISTUDIO_NESASM_ZP_RSSET     = $00a0

; Define this to emit the ".bss" directive before the RAM/BSS variables.
; FAMISTUDIO_NESASM_BSS_SECTION  = 1

; Address where to allocate the RAN/BSS variables that the engine use.
FAMISTUDIO_NESASM_BSS_RSSET    = $0400

; Define this to emit the ".code" directive before the code section.
; FAMISTUDIO_NESASM_CODE_SECTION = 1

; Define this to emit the ".bank" directive before the code section.
; FAMISTUDIO_NESASM_CODE_BANK    = 0

; Address where to place the engine code.
; FAMISTUDIO_NESASM_CODE_ORG     = $8000

;======================================================================================================================
; 2) AUDIO EXPANSION CONFIGURATION
;
; You can enable up to one audio expansion (FAMISTUDIO_EXP_XXX). Enabling more than one expansion will lead to
; undefined behavior. Memory usage goes up as more complex expansions are used. The audio expansion you choose
; **MUST MATCH** with the data you will load in the engine. Loading a FDS song while enabling VRC6 will lead to
; undefined behavior.
;======================================================================================================================

; Konami VRC6 (2 extra square + saw)
; FAMISTUDIO_EXP_VRC6          = 1

; Konami VRC7 (6 FM channels)
; FAMISTUDIO_EXP_VRC7          = 1

; Nintendo MMC5 (2 extra squares, extra DPCM not supported)
; FAMISTUDIO_EXP_MMC5          = 1

; Sunsoft S5B (2 extra squares, advanced features not supported.)
; FAMISTUDIO_EXP_S5B           = 1

; Famicom Disk System (extra wavetable channel)
; FAMISTUDIO_EXP_FDS           = 1

; Namco 163 (between 1 and 8 extra wavetable channels) + number of channels.
; FAMISTUDIO_EXP_N163          = 1
; FAMISTUDIO_EXP_N163_CHN_CNT  = 4

;======================================================================================================================
; 3) GLOBAL ENGINE CONFIGURATION
;
; These are parameters that configures the engine, but are independent of the data you will be importing, such as
; which platform (PAL/NTSC) you want to support playback for, whether SFX are enabled or not, etc. They all have the
; form FAMISTUDIO_CFG_XXX.
;======================================================================================================================

; One of these MUST be defined (PAL or NTSC playback). Note that only NTSC support is supported when using any of the audio expansions.
; FAMISTUDIO_CFG_PAL_SUPPORT   = 1
FAMISTUDIO_CFG_NTSC_SUPPORT  = 1

; Support for sound effects playback + number of SFX that can play at once.
; FAMISTUDIO_CFG_SFX_SUPPORT   = 1
; FAMISTUDIO_CFG_SFX_STREAMS   = 2

; Blaarg's smooth vibrato technique. Eliminates phase resets ("pops") on square channels. Will be ignored if SFX are
; enabled since they are currently incompatible with each other. This might change in the future.
; FAMISTUDIO_CFG_SMOOTH_VIBRATO = 1

; Enables DPCM playback support.
FAMISTUDIO_CFG_DPCM_SUPPORT   = 1

; Must be enabled if you are calling sound effects from a different thread than the sound engine update.
; FAMISTUDIO_CFG_THREAD         = 1

;======================================================================================================================
; 4) SUPPORTED FEATURES CONFIGURATION
;
; Every feature supported in FamiStudio is supported by this sound engine. If you know for sure that you are not using
; specific features in your music, you can disable them to save memory/processing time. Using a feature in your song
; and failing to enable it will likely lead to crashes (BRK), or undefined behavior. They all have the form
; FAMISTUDIO_USE_XXX.
;======================================================================================================================

; Must be enabled if the songs you will be importing have been created using FamiTracker tempo mode. If you are using
; FamiStudio tempo mode, this must be undefined. You cannot mix and match tempo modes, the engine can only run in one
; mode or the other.
; More information at: https://famistudio.org/doc/song/#tempo-modes
FAMISTUDIO_USE_FT_TEMPO = 0

; Must be enabled if any song use the volume track. The volume track allows manipulating the volume at the track level
; independently from instruments.
; More information at: https://famistudio.org/doc/pianoroll/#editing-volume-tracks-effects
FAMISTUDIO_USE_VOLUME_TRACK   = 1

; Must be enabled if any song use the pitch track. The pitch track allows manipulating the pitch at the track level
; independently from instruments.
; More information at: https://famistudio.org/doc/pianoroll/#pitch
FAMISTUDIO_USE_PITCH_TRACK    = 1

; Must be enabled if any song use slide notes. Slide notes allows portamento and slide effects.
; More information at: https://famistudio.org/doc/pianoroll/#slide-notes
FAMISTUDIO_USE_SLIDE_NOTES    = 1

; Must be enabled if any song use the vibrato speed/depth effect track.
; More information at: https://famistudio.org/doc/pianoroll/#vibrato-depth-speed
FAMISTUDIO_USE_VIBRATO        = 1

; Must be enabled if any song use arpeggios (not to be confused with instrument arpeggio envelopes, those are always
; supported).
; More information at: (TODO)
FAMISTUDIO_USE_ARPEGGIO       = 1

    .endif

; Memory location of the DPCM samples. Must be between $c000 and $ffc0, and a multiple of 64.
    .ifndef FAMISTUDIO_DPCM_OFF
FAMISTUDIO_DPCM_OFF = $c000
    .endif

;======================================================================================================================
; END OF CONFIGURATION
;
; Ideally, you should not have to change anything below this line.
;======================================================================================================================

;======================================================================================================================
; INTERNAL DEFINES (Do not touch)
;======================================================================================================================

    .ifndef FAMISTUDIO_EXP_VRC6
FAMISTUDIO_EXP_VRC6 = 0
    .endif

    .ifndef FAMISTUDIO_EXP_VRC7
FAMISTUDIO_EXP_VRC7 = 0
    .endif

    .ifndef FAMISTUDIO_EXP_MMC5
FAMISTUDIO_EXP_MMC5 = 0
    .endif

    .ifndef FAMISTUDIO_EXP_S5B
FAMISTUDIO_EXP_S5B = 0
    .endif

    .ifndef FAMISTUDIO_EXP_FDS
FAMISTUDIO_EXP_FDS = 0
    .endif

    .ifndef FAMISTUDIO_EXP_N163
FAMISTUDIO_EXP_N163 = 0
    .endif

    .ifndef FAMISTUDIO_EXP_N163_CHN_CNT
FAMISTUDIO_EXP_N163_CHN_CNT = 1
    .endif

    .ifndef FAMISTUDIO_CFG_PAL_SUPPORT
FAMISTUDIO_CFG_PAL_SUPPORT = 0
    .endif

    .ifndef FAMISTUDIO_CFG_NTSC_SUPPORT
        .if FAMISTUDIO_CFG_PAL_SUPPORT
FAMISTUDIO_CFG_NTSC_SUPPORT = 0
        .else
FAMISTUDIO_CFG_NTSC_SUPPORT = 1
        .endif
    .endif

    .if (FAMISTUDIO_CFG_NTSC_SUPPORT != 0) & (FAMISTUDIO_CFG_PAL_SUPPORT != 0)
FAMISTUDIO_DUAL_SUPPORT = 1
    .else
FAMISTUDIO_DUAL_SUPPORT = 0
    .endif

    .ifndef FAMISTUDIO_CFG_SFX_SUPPORT
FAMISTUDIO_CFG_SFX_SUPPORT = 0
FAMISTUDIO_CFG_SFX_STREAMS = 0
    .endif

    .ifndef FAMISTUDIO_CFG_SFX_STREAMS
FAMISTUDIO_CFG_SFX_STREAMS = 1
    .endif

    .ifndef FAMISTUDIO_CFG_SMOOTH_VIBRATO
FAMISTUDIO_CFG_SMOOTH_VIBRATO = 0
    .endif

    .ifndef FAMISTUDIO_CFG_DPCM_SUPPORT
FAMISTUDIO_CFG_DPCM_SUPPORT = 0
    .endif

    .ifndef FAMISTUDIO_CFG_EQUALIZER
FAMISTUDIO_CFG_EQUALIZER = 0
    .endif

    .ifndef FAMISTUDIO_USE_FT_TEMPO
FAMISTUDIO_USE_FT_TEMPO = 0
    .endif

    .ifndef FAMISTUDIO_USE_VOLUME_TRACK
FAMISTUDIO_USE_VOLUME_TRACK = 0
    .endif

    .ifndef FAMISTUDIO_USE_PITCH_TRACK
FAMISTUDIO_USE_PITCH_TRACK = 0
    .endif

    .ifndef FAMISTUDIO_USE_SLIDE_NOTES
FAMISTUDIO_USE_SLIDE_NOTES = 0
    .endif

    .ifndef FAMISTUDIO_USE_VIBRATO
FAMISTUDIO_USE_VIBRATO = 0
    .endif

    .ifndef FAMISTUDIO_USE_ARPEGGIO
FAMISTUDIO_USE_ARPEGGIO = 0
    .endif

    .ifndef FAMISTUDIO_CFG_THREAD
FAMISTUDIO_CFG_THREAD = 0
    .endif

    .if (FAMISTUDIO_EXP_VRC6 + FAMISTUDIO_EXP_VRC7 + FAMISTUDIO_EXP_MMC5 + FAMISTUDIO_EXP_S5B + FAMISTUDIO_EXP_FDS + FAMISTUDIO_EXP_N163) = 0
FAMISTUDIO_EXP_NONE = 1
    .else
FAMISTUDIO_EXP_NONE = 0
    .endif

    .if (FAMISTUDIO_EXP_VRC7 + FAMISTUDIO_EXP_N163 + FAMISTUDIO_EXP_FDS) != 0
FAMISTUDIO_EXP_NOTE_START = 5
    .endif
    .if (FAMISTUDIO_EXP_VRC6) != 0
FAMISTUDIO_EXP_NOTE_START = 7
    .endif

    .if (FAMISTUDIO_CFG_SFX_SUPPORT != 0) & (FAMISTUDIO_CFG_SMOOTH_VIBRATO != 0)
    .error "Smooth vibrato and SFX canoot be used at the same time."
    .endif

    .if (FAMISTUDIO_EXP_VRC6 + FAMISTUDIO_EXP_VRC7 + FAMISTUDIO_EXP_MMC5 + FAMISTUDIO_EXP_S5B + FAMISTUDIO_EXP_FDS + FAMISTUDIO_EXP_N163) > 1
    .error "Only one audio expansion can be enabled."
    .endif

    .if (FAMISTUDIO_EXP_N163 != 0) & ((FAMISTUDIO_EXP_N163_CHN_CNT < 1) | (FAMISTUDIO_EXP_N163_CHN_CNT > 8))
    .error "N163 only supports between 1 and 8 channels."
    .endif

FAMISTUDIO_DPCM_PTR = (FAMISTUDIO_DPCM_OFF & $3fff) >> 6

    .if FAMISTUDIO_EXP_VRC7
FAMISTUDIO_NUM_ENVELOPES        = 3+3+2+3+2+2+2+2+2+2
FAMISTUDIO_NUM_PITCH_ENVELOPES  = 9
FAMISTUDIO_NUM_CHANNELS         = 11
    .endif
    .if FAMISTUDIO_EXP_VRC6
FAMISTUDIO_NUM_ENVELOPES        = 3+3+2+3+3+3+3
FAMISTUDIO_NUM_PITCH_ENVELOPES  = 6
FAMISTUDIO_NUM_CHANNELS         = 8
    .endif
    .if FAMISTUDIO_EXP_S5B
FAMISTUDIO_NUM_ENVELOPES        = 3+3+2+3+2+2+2
FAMISTUDIO_NUM_PITCH_ENVELOPES  = 6
FAMISTUDIO_NUM_CHANNELS         = 8
    .endif
    .if FAMISTUDIO_EXP_N163
FAMISTUDIO_NUM_ENVELOPES        = 3+3+2+3+(FAMISTUDIO_EXP_N163_CHN_CNT*2)
FAMISTUDIO_NUM_PITCH_ENVELOPES  = 3+FAMISTUDIO_EXP_N163_CHN_CNT
FAMISTUDIO_NUM_CHANNELS         = 5+FAMISTUDIO_EXP_N163_CHN_CNT
    .endif
    .if FAMISTUDIO_EXP_MMC5
FAMISTUDIO_NUM_ENVELOPES        = 3+3+2+3+3+3
FAMISTUDIO_NUM_PITCH_ENVELOPES  = 5
FAMISTUDIO_NUM_CHANNELS         = 7
    .endif
    .if FAMISTUDIO_EXP_FDS
FAMISTUDIO_NUM_ENVELOPES        = 3+3+2+3+2
FAMISTUDIO_NUM_PITCH_ENVELOPES  = 4
FAMISTUDIO_NUM_CHANNELS         = 6
    .endif
    .if FAMISTUDIO_EXP_NONE
FAMISTUDIO_NUM_ENVELOPES        = 3+3+2+3
FAMISTUDIO_NUM_PITCH_ENVELOPES  = 3
FAMISTUDIO_NUM_CHANNELS         = 5
    .endif

FAMISTUDIO_CH0_ENVS = 0
FAMISTUDIO_CH1_ENVS = 3
FAMISTUDIO_CH2_ENVS = 6
FAMISTUDIO_CH3_ENVS = 8

    .if FAMISTUDIO_EXP_VRC6
FAMISTUDIO_CH5_ENVS  = 11
FAMISTUDIO_CH6_ENVS  = 14
FAMISTUDIO_CH7_ENVS  = 17
    .endif
    .if FAMISTUDIO_EXP_VRC7
FAMISTUDIO_CH5_ENVS  = 11
FAMISTUDIO_CH6_ENVS  = 13
FAMISTUDIO_CH7_ENVS  = 15
FAMISTUDIO_CH8_ENVS  = 17
FAMISTUDIO_CH9_ENVS  = 19
FAMISTUDIO_CH10_ENVS = 21
    .endif
    .if FAMISTUDIO_EXP_N163
FAMISTUDIO_CH5_ENVS  = 11
FAMISTUDIO_CH6_ENVS  = 13
FAMISTUDIO_CH7_ENVS  = 15
FAMISTUDIO_CH8_ENVS  = 17
FAMISTUDIO_CH9_ENVS  = 19
FAMISTUDIO_CH10_ENVS = 21
FAMISTUDIO_CH11_ENVS = 23
FAMISTUDIO_CH12_ENVS = 25
    .endif
    .if FAMISTUDIO_EXP_FDS
FAMISTUDIO_CH5_ENVS  = 11
    .endif
    .if FAMISTUDIO_EXP_MMC5
FAMISTUDIO_CH5_ENVS  = 11
FAMISTUDIO_CH6_ENVS  = 14
    .endif
    .if FAMISTUDIO_EXP_S5B
FAMISTUDIO_CH5_ENVS  = 11
FAMISTUDIO_CH6_ENVS  = 13
FAMISTUDIO_CH7_ENVS  = 15
    .endif

FAMISTUDIO_ENV_VOLUME_OFF = 0
FAMISTUDIO_ENV_NOTE_OFF   = 1
FAMISTUDIO_ENV_DUTY_OFF   = 2

    .if FAMISTUDIO_EXP_VRC7
FAMISTUDIO_PITCH_SHIFT = 3
    .else
        .if FAMISTUDIO_EXP_N163
            .if (FAMISTUDIO_EXP_N163_CHN_CNT > 4)
FAMISTUDIO_PITCH_SHIFT = 5
            .endif
            .if (FAMISTUDIO_EXP_N163_CHN_CNT > 2) & (FAMISTUDIO_EXP_N163_CHN_CNT <= 4)
FAMISTUDIO_PITCH_SHIFT = 4
            .endif
            .if (FAMISTUDIO_EXP_N163_CHN_CNT > 1) & (FAMISTUDIO_EXP_N163_CHN_CNT <= 2)
FAMISTUDIO_PITCH_SHIFT = 3
            .endif
            .if (FAMISTUDIO_EXP_N163_CHN_CNT = 1)
FAMISTUDIO_PITCH_SHIFT = 2
            .endif
        .else
FAMISTUDIO_PITCH_SHIFT = 0
        .endif
    .endif

    .if FAMISTUDIO_EXP_N163
FAMISTUDIO_N163_CHN_MASK = (FAMISTUDIO_EXP_N163_CHN_CNT - 1) << 4
    .endif

    .if FAMISTUDIO_CFG_SFX_SUPPORT
FAMISTUDIO_SFX_STRUCT_SIZE = 15

FAMISTUDIO_SFX_CH0 = FAMISTUDIO_SFX_STRUCT_SIZE * 0
FAMISTUDIO_SFX_CH1 = FAMISTUDIO_SFX_STRUCT_SIZE * 1
FAMISTUDIO_SFX_CH2 = FAMISTUDIO_SFX_STRUCT_SIZE * 2
FAMISTUDIO_SFX_CH3 = FAMISTUDIO_SFX_STRUCT_SIZE * 3
    .endif

;======================================================================================================================
; RAM VARIABLES (You should not have to play with these)
;======================================================================================================================

    .ifdef FAMISTUDIO_NESASM_BSS_SECTION
    .bss
    .endif
    .ifdef FAMISTUDIO_NESASM_BSS_RSSET
    .rsset FAMISTUDIO_NESASM_BSS_RSSET
    .endif

famistudio_env_value:             .rs FAMISTUDIO_NUM_ENVELOPES
famistudio_env_repeat:            .rs FAMISTUDIO_NUM_ENVELOPES
famistudio_env_addr_lo:           .rs FAMISTUDIO_NUM_ENVELOPES
famistudio_env_addr_hi:           .rs FAMISTUDIO_NUM_ENVELOPES
famistudio_env_ptr:               .rs FAMISTUDIO_NUM_ENVELOPES

famistudio_pitch_env_value_lo:    .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
famistudio_pitch_env_value_hi:    .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
famistudio_pitch_env_repeat:      .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
famistudio_pitch_env_addr_lo:     .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
famistudio_pitch_env_addr_hi:     .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
famistudio_pitch_env_ptr:         .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
    .if FAMISTUDIO_USE_PITCH_TRACK
famistudio_pitch_env_fine_val:  .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
    .endif

    .if FAMISTUDIO_USE_SLIDE_NOTES
famistudio_slide_step:            .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
famistudio_slide_pitch_lo:        .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
famistudio_slide_pitch_hi:        .rs FAMISTUDIO_NUM_PITCH_ENVELOPES
    .endif

famistudio_chn_ptr_lo:            .rs FAMISTUDIO_NUM_CHANNELS
famistudio_chn_ptr_hi:            .rs FAMISTUDIO_NUM_CHANNELS
famistudio_chn_note:              .rs FAMISTUDIO_NUM_CHANNELS
famistudio_chn_instrument:        .rs FAMISTUDIO_NUM_CHANNELS
famistudio_chn_repeat:            .rs FAMISTUDIO_NUM_CHANNELS
famistudio_chn_return_lo:         .rs FAMISTUDIO_NUM_CHANNELS
famistudio_chn_return_hi:         .rs FAMISTUDIO_NUM_CHANNELS
famistudio_chn_ref_len:           .rs FAMISTUDIO_NUM_CHANNELS
    .if FAMISTUDIO_USE_VOLUME_TRACK
famistudio_chn_volume_track:      .rs FAMISTUDIO_NUM_CHANNELS
    .endif
    .if (FAMISTUDIO_USE_VIBRATO != 0) | (FAMISTUDIO_USE_ARPEGGIO != 0)
famistudio_chn_env_override:      .rs FAMISTUDIO_NUM_CHANNELS ; bit 7 = pitch, bit 0 = arpeggio.
    .endif
    .if (FAMISTUDIO_EXP_N163 != 0) | (FAMISTUDIO_EXP_VRC7 != 0) | (FAMISTUDIO_EXP_FDS != 0)
famistudio_chn_inst_changed:      .rs FAMISTUDIO_NUM_CHANNELS-5
    .endif
    .if FAMISTUDIO_CFG_EQUALIZER
famistudio_chn_note_counter:      .rs FAMISTUDIO_NUM_CHANNELS
    .endif
    .if FAMISTUDIO_EXP_VRC7
famistudio_chn_vrc7_prev_hi:      .rs 6
famistudio_chn_vrc7_patch:        .rs 6
famistudio_chn_vrc7_trigger:      .rs 6 ; bit 0 = new note triggered, bit 7 = note released.
    .endif
    .if FAMISTUDIO_EXP_N163
famistudio_chn_n163_wave_len:     .rs FAMISTUDIO_EXP_N163_CHN_CNT
    .endif

    .if FAMISTUDIO_USE_FT_TEMPO
famistudio_tempo_step_lo:         .rs 1
famistudio_tempo_step_hi:         .rs 1
famistudio_tempo_acc_lo:          .rs 1
famistudio_tempo_acc_hi:          .rs 1
    .else
famistudio_tempo_env_ptr_lo:      .rs 1
famistudio_tempo_env_ptr_hi:      .rs 1
famistudio_tempo_env_counter:     .rs 1
famistudio_tempo_env_idx:         .rs 1
famistudio_tempo_frame_num:       .rs 1
famistudio_tempo_frame_cnt:       .rs 1
    .endif

famistudio_pal_adjust:            .rs 1
famistudio_song_list_lo:          .rs 1
famistudio_song_list_hi:          .rs 1
famistudio_instrument_lo:         .rs 1
famistudio_instrument_hi:         .rs 1
famistudio_dpcm_list_lo:          .rs 1 ; TODO: Not needed if DPCM support is disabled.
famistudio_dpcm_list_hi:          .rs 1 ; TODO: Not needed if DPCM support is disabled.
famistudio_dpcm_effect:           .rs 1 ; TODO: Not needed if DPCM support is disabled.
famistudio_pulse1_prev:           .rs 1
famistudio_pulse2_prev:           .rs 1
famistudio_song_speed             = famistudio_chn_instrument+4

    .if FAMISTUDIO_EXP_MMC5
famistudio_mmc5_pulse1_prev:      .rs 1
famistudio_mmc5_pulse2_prev:      .rs 1
.endif

    .if FAMISTUDIO_EXP_FDS
famistudio_fds_mod_speed:         .rs 2
famistudio_fds_mod_depth:         .rs 1
famistudio_fds_mod_delay:         .rs 1
famistudio_fds_override_flags:    .rs 1 ; Bit 7 = mod speed overriden, bit 6 mod depth overriden
    .endif

    .if FAMISTUDIO_EXP_VRC7
famistudio_vrc7_dummy:            .rs 1 ; TODO: Find a dummy address i can simply write to without side effects.
    .endif

; FDS, N163 and VRC7 have very different instrument layout and are 16-bytes, so we keep them seperate.
    .if (FAMISTUDIO_EXP_FDS != 0) | (FAMISTUDIO_EXP_N163 != 0) | (FAMISTUDIO_EXP_VRC7 != 0)
famistudio_exp_instrument_lo:     .rs 1
famistudio_exp_instrument_hi:     .rs 1
    .endif

    .if FAMISTUDIO_CFG_SFX_SUPPORT

famistudio_output_buf:     .rs 11
famistudio_sfx_addr_lo:    .rs 1
famistudio_sfx_addr_hi:    .rs 1
famistudio_sfx_base_addr:  .rs (FAMISTUDIO_CFG_SFX_STREAMS * FAMISTUDIO_SFX_STRUCT_SIZE)

; TODO: Refactor SFX memory layout. These uses a AoS approach, not fan.
famistudio_sfx_repeat = famistudio_sfx_base_addr + 0
famistudio_sfx_ptr_lo = famistudio_sfx_base_addr + 1
famistudio_sfx_ptr_hi = famistudio_sfx_base_addr + 2
famistudio_sfx_offset = famistudio_sfx_base_addr + 3
famistudio_sfx_buffer = famistudio_sfx_base_addr + 4

    .endif

;======================================================================================================================
; ZEROPAGE VARIABLES
;
; These are only used as temporary variable during the famistudio_xxx calls.
; Feel free to alias those with other ZP values in your programs to save a few bytes.
;======================================================================================================================

    .ifdef FAMISTUDIO_NESASM_ZP_SECTION
    .zp
    .endif
    .ifdef FAMISTUDIO_NESASM_ZP_RSSET
    .rsset FAMISTUDIO_NESASM_ZP_RSSET
    .endif

famistudio_r0:   .rs 1
famistudio_r1:   .rs 1
famistudio_r2:   .rs 1

famistudio_ptr0: .rs 2
famistudio_ptr1: .rs 2

famistudio_ptr0_lo = famistudio_ptr0+0
famistudio_ptr0_hi = famistudio_ptr0+1
famistudio_ptr1_lo = famistudio_ptr1+0
famistudio_ptr1_hi = famistudio_ptr1+1

;======================================================================================================================
; CODE
;======================================================================================================================

    .ifdef FAMISTUDIO_NESASM_CODE_SECTION
    .code
    .endif
    .ifdef FAMISTUDIO_NESASM_CODE_BANK
    .bank FAMISTUDIO_NESASM_CODE_BANK
    .endif
    .ifdef FAMISTUDIO_NESASM_CODE_ORG
    .org FAMISTUDIO_NESASM_CODE_ORG
    .endif

FAMISTUDIO_APU_PL1_VOL    = $4000
FAMISTUDIO_APU_PL1_SWEEP  = $4001
FAMISTUDIO_APU_PL1_LO     = $4002
FAMISTUDIO_APU_PL1_HI     = $4003
FAMISTUDIO_APU_PL2_VOL    = $4004
FAMISTUDIO_APU_PL2_SWEEP  = $4005
FAMISTUDIO_APU_PL2_LO     = $4006
FAMISTUDIO_APU_PL2_HI     = $4007
FAMISTUDIO_APU_TRI_LINEAR = $4008
FAMISTUDIO_APU_TRI_LO     = $400a
FAMISTUDIO_APU_TRI_HI     = $400b
FAMISTUDIO_APU_NOISE_VOL  = $400c
FAMISTUDIO_APU_NOISE_LO   = $400e
FAMISTUDIO_APU_NOISE_HI   = $400f
FAMISTUDIO_APU_DMC_FREQ   = $4010
FAMISTUDIO_APU_DMC_RAW    = $4011
FAMISTUDIO_APU_DMC_START  = $4012
FAMISTUDIO_APU_DMC_LEN    = $4013
FAMISTUDIO_APU_SND_CHN    = $4015
FAMISTUDIO_APU_FRAME_CNT  = $4017

    .if FAMISTUDIO_EXP_VRC6
FAMISTUDIO_VRC6_PL1_VOL   = $9000
FAMISTUDIO_VRC6_PL1_LO    = $9001
FAMISTUDIO_VRC6_PL1_HI    = $9002
FAMISTUDIO_VRC6_PL2_VOL   = $a000
FAMISTUDIO_VRC6_PL2_LO    = $a001
FAMISTUDIO_VRC6_PL2_HI    = $a002
FAMISTUDIO_VRC6_SAW_VOL   = $b000
FAMISTUDIO_VRC6_SAW_LO    = $b001
FAMISTUDIO_VRC6_SAW_HI    = $b002
    .endif

    .if FAMISTUDIO_EXP_VRC7
FAMISTUDIO_VRC7_SILENCE   = $e000
FAMISTUDIO_VRC7_REG_SEL   = $9010
FAMISTUDIO_VRC7_REG_WRITE = $9030
FAMISTUDIO_VRC7_REG_LO_1  = $10
FAMISTUDIO_VRC7_REG_LO_2  = $11
FAMISTUDIO_VRC7_REG_LO_3  = $12
FAMISTUDIO_VRC7_REG_LO_4  = $13
FAMISTUDIO_VRC7_REG_LO_5  = $14
FAMISTUDIO_VRC7_REG_LO_6  = $15
FAMISTUDIO_VRC7_REG_HI_1  = $20
FAMISTUDIO_VRC7_REG_HI_2  = $21
FAMISTUDIO_VRC7_REG_HI_3  = $22
FAMISTUDIO_VRC7_REG_HI_4  = $23
FAMISTUDIO_VRC7_REG_HI_5  = $24
FAMISTUDIO_VRC7_REG_HI_6  = $25
FAMISTUDIO_VRC7_REG_VOL_1 = $30
FAMISTUDIO_VRC7_REG_VOL_2 = $31
FAMISTUDIO_VRC7_REG_VOL_3 = $32
FAMISTUDIO_VRC7_REG_VOL_4 = $33
FAMISTUDIO_VRC7_REG_VOL_5 = $34
FAMISTUDIO_VRC7_REG_VOL_6 = $35
    .endif

    .if FAMISTUDIO_EXP_MMC5
FAMISTUDIO_MMC5_PL1_VOL   = $5000
FAMISTUDIO_MMC5_PL1_SWEEP = $5001
FAMISTUDIO_MMC5_PL1_LO    = $5002
FAMISTUDIO_MMC5_PL1_HI    = $5003
FAMISTUDIO_MMC5_PL2_VOL   = $5004
FAMISTUDIO_MMC5_PL2_SWEEP = $5005
FAMISTUDIO_MMC5_PL2_LO    = $5006
FAMISTUDIO_MMC5_PL2_HI    = $5007
FAMISTUDIO_MMC5_PCM_MODE  = $5010
FAMISTUDIO_MMC5_SND_CHN   = $5015
    .endif

    .if FAMISTUDIO_EXP_N163
FAMISTUDIO_N163_SILENCE       = $e000
FAMISTUDIO_N163_ADDR          = $f800
FAMISTUDIO_N163_DATA          = $4800
FAMISTUDIO_N163_REG_FREQ_LO   = $78
FAMISTUDIO_N163_REG_PHASE_LO  = $79
FAMISTUDIO_N163_REG_FREQ_MID  = $7a
FAMISTUDIO_N163_REG_PHASE_MID = $7b
FAMISTUDIO_N163_REG_FREQ_HI   = $7c
FAMISTUDIO_N163_REG_PHASE_HI  = $7d
FAMISTUDIO_N163_REG_WAVE      = $7e
FAMISTUDIO_N163_REG_VOLUME    = $7f
    .endif

    .if FAMISTUDIO_EXP_S5B
FAMISTUDIO_S5B_ADDR       = $c000
FAMISTUDIO_S5B_DATA       = $e000
FAMISTUDIO_S5B_REG_LO_A   = $00
FAMISTUDIO_S5B_REG_HI_A   = $01
FAMISTUDIO_S5B_REG_LO_B   = $02
FAMISTUDIO_S5B_REG_HI_B   = $03
FAMISTUDIO_S5B_REG_LO_C   = $04
FAMISTUDIO_S5B_REG_HI_C   = $05
FAMISTUDIO_S5B_REG_NOISE  = $06
FAMISTUDIO_S5B_REG_TONE   = $07
FAMISTUDIO_S5B_REG_VOL_A  = $08
FAMISTUDIO_S5B_REG_VOL_B  = $09
FAMISTUDIO_S5B_REG_VOL_C  = $0a
FAMISTUDIO_S5B_REG_ENV_LO = $0b
FAMISTUDIO_S5B_REG_ENV_HI = $0c
FAMISTUDIO_S5B_REG_SHAPE  = $0d
FAMISTUDIO_S5B_REG_IO_A   = $0e
FAMISTUDIO_S5B_REG_IO_B   = $0f
    .endif

    .if FAMISTUDIO_EXP_FDS
FAMISTUDIO_FDS_WAV_START  = $4040
FAMISTUDIO_FDS_VOL_ENV    = $4080
FAMISTUDIO_FDS_FREQ_LO    = $4082
FAMISTUDIO_FDS_FREQ_HI    = $4083
FAMISTUDIO_FDS_SWEEP_ENV  = $4084
FAMISTUDIO_FDS_SWEEP_BIAS = $4085
FAMISTUDIO_FDS_MOD_LO     = $4086
FAMISTUDIO_FDS_MOD_HI     = $4087
FAMISTUDIO_FDS_MOD_TABLE  = $4088
FAMISTUDIO_FDS_VOL        = $4089
FAMISTUDIO_FDS_ENV_SPEED  = $408A
    .endif

    .if !FAMISTUDIO_CFG_SFX_SUPPORT
; Output directly to APU
FAMISTUDIO_ALIAS_PL1_VOL    = FAMISTUDIO_APU_PL1_VOL
FAMISTUDIO_ALIAS_PL1_LO     = FAMISTUDIO_APU_PL1_LO
FAMISTUDIO_ALIAS_PL1_HI     = FAMISTUDIO_APU_PL1_HI
FAMISTUDIO_ALIAS_PL2_VOL    = FAMISTUDIO_APU_PL2_VOL
FAMISTUDIO_ALIAS_PL2_LO     = FAMISTUDIO_APU_PL2_LO
FAMISTUDIO_ALIAS_PL2_HI     = FAMISTUDIO_APU_PL2_HI
FAMISTUDIO_ALIAS_TRI_LINEAR = FAMISTUDIO_APU_TRI_LINEAR
FAMISTUDIO_ALIAS_TRI_LO     = FAMISTUDIO_APU_TRI_LO
FAMISTUDIO_ALIAS_TRI_HI     = FAMISTUDIO_APU_TRI_HI
FAMISTUDIO_ALIAS_NOISE_VOL  = FAMISTUDIO_APU_NOISE_VOL
FAMISTUDIO_ALIAS_NOISE_LO   = FAMISTUDIO_APU_NOISE_LO
    .else
; Otherwise write to the output buffer
FAMISTUDIO_ALIAS_PL1_VOL    = famistudio_output_buf + 0
FAMISTUDIO_ALIAS_PL1_LO     = famistudio_output_buf + 1
FAMISTUDIO_ALIAS_PL1_HI     = famistudio_output_buf + 2
FAMISTUDIO_ALIAS_PL2_VOL    = famistudio_output_buf + 3
FAMISTUDIO_ALIAS_PL2_LO     = famistudio_output_buf + 4
FAMISTUDIO_ALIAS_PL2_HI     = famistudio_output_buf + 5
FAMISTUDIO_ALIAS_TRI_LINEAR = famistudio_output_buf + 6
FAMISTUDIO_ALIAS_TRI_LO     = famistudio_output_buf + 7
FAMISTUDIO_ALIAS_TRI_HI     = famistudio_output_buf + 8
FAMISTUDIO_ALIAS_NOISE_VOL  = famistudio_output_buf + 9
FAMISTUDIO_ALIAS_NOISE_LO   = famistudio_output_buf + 10
    .endif

;======================================================================================================================
; FAMISTUDIO_INIT (public)
;
; Reset APU, initialize the sound engine with some music data.
;
; [in] a : Playback platform, zero for PAL, non-zero for NTSC.
; [in] x : Pointer to music data (lo)
; [in] y : Pointer to music data (hi)
;======================================================================================================================

famistudio_init:

.music_data_ptr = famistudio_ptr0

    stx famistudio_song_list_lo
    sty famistudio_song_list_hi
    stx <.music_data_ptr+0
    sty <.music_data_ptr+1

    .if FAMISTUDIO_DUAL_SUPPORT
    tax
    beq .pal
    lda #97
.pal:
    .else
        .if FAMISTUDIO_CFG_PAL_SUPPORT
        lda #0
        .endif
        .if FAMISTUDIO_CFG_NTSC_SUPPORT
        lda #97
        .endif
    .endif
    sta famistudio_pal_adjust

    jsr famistudio_music_stop

    ; Instrument address
    ldy #1
    lda [.music_data_ptr],y
    sta famistudio_instrument_lo
    iny
    lda [.music_data_ptr],y
    sta famistudio_instrument_hi
    iny

    ; Expansions instrument address
    .if (FAMISTUDIO_EXP_FDS != 0) | (FAMISTUDIO_EXP_N163 != 0) | (FAMISTUDIO_EXP_VRC7 != 0)
        lda [.music_data_ptr],y
        sta famistudio_exp_instrument_lo
        iny
        lda [.music_data_ptr],y
        sta famistudio_exp_instrument_hi
        iny
    .endif

    ; Sample list address
    lda [.music_data_ptr],y
    sta famistudio_dpcm_list_lo
    iny
    lda [.music_data_ptr],y
    sta famistudio_dpcm_list_hi

    lda #$80 ; Previous pulse period MSB, to not write it when not changed
    sta famistudio_pulse1_prev
    sta famistudio_pulse2_prev

    lda #$0f ; Enable channels, stop DMC
    sta FAMISTUDIO_APU_SND_CHN
    lda #$80 ; Disable triangle length counter
    sta FAMISTUDIO_APU_TRI_LINEAR
    lda #$00 ; Load noise length
    sta FAMISTUDIO_APU_NOISE_HI

    lda #$30 ; Volumes to 0
    sta FAMISTUDIO_APU_PL1_VOL
    sta FAMISTUDIO_APU_PL2_VOL
    sta FAMISTUDIO_APU_NOISE_VOL
    lda #$08 ; No sweep
    sta FAMISTUDIO_APU_PL1_SWEEP
    sta FAMISTUDIO_APU_PL2_SWEEP

    .if FAMISTUDIO_EXP_VRC7
    lda #0
    sta FAMISTUDIO_VRC7_SILENCE ; Enable VRC7 audio.
    .endif

    .if FAMISTUDIO_EXP_MMC5
    lda #$00
    sta FAMISTUDIO_MMC5_PCM_MODE
    lda #$03
    sta FAMISTUDIO_MMC5_SND_CHN
    .endif

    .if FAMISTUDIO_EXP_S5B
    lda #FAMISTUDIO_S5B_REG_TONE
    sta FAMISTUDIO_S5B_ADDR
    lda #$38 ; No noise, just 3 tones for now.
    sta FAMISTUDIO_S5B_DATA
    .endif

    jmp famistudio_music_stop

;======================================================================================================================
; FAMISTUDIO_MUSIC_STOP (public)
;
; Stops any music currently playing, if any. Note that this will not update the APU, so sound might linger. Calling
; famistudio_update after this will update the APU.
;
; [in] no input params.
;======================================================================================================================

famistudio_music_stop:

    lda #0
    sta famistudio_song_speed
    sta famistudio_dpcm_effect

    ldx #0

.set_channels:

    lda #0
    sta famistudio_chn_repeat,x
    sta famistudio_chn_instrument,x
    sta famistudio_chn_note,x
    sta famistudio_chn_ref_len,x
    .if FAMISTUDIO_USE_VOLUME_TRACK
        sta famistudio_chn_volume_track,x
    .endif
    .if (FAMISTUDIO_USE_VIBRATO != 0) | (FAMISTUDIO_USE_ARPEGGIO != 0)
        sta famistudio_chn_env_override,x
    .endif
    .if FAMISTUDIO_CFG_EQUALIZER
        sta famistudio_chn_note_counter,x
    .endif

.nextchannel:
    inx
    cpx #FAMISTUDIO_NUM_CHANNELS
    bne .set_channels

    .if FAMISTUDIO_USE_SLIDE_NOTES
    ldx #0
    lda #0
.set_slides:

    sta famistudio_slide_step, x
    inx
    cpx #FAMISTUDIO_NUM_PITCH_ENVELOPES
    bne .set_slides
    .endif

    ldx #0

.set_envelopes:

    lda #LOW(famistudio_dummy_envelope)
    sta famistudio_env_addr_lo,x
    lda #HIGH(famistudio_dummy_envelope)
    sta famistudio_env_addr_hi,x
    lda #0
    sta famistudio_env_repeat,x
    sta famistudio_env_value,x
    sta famistudio_env_ptr,x
    inx
    cpx #FAMISTUDIO_NUM_ENVELOPES
    bne .set_envelopes

    ldx #0

.set_pitch_envelopes:

    lda #LOW(famistudio_dummy_pitch_env)
    sta famistudio_pitch_env_addr_lo,x
    lda #HIGH(famistudio_dummy_pitch_env)
    sta famistudio_pitch_env_addr_hi,x
    lda #0
    sta famistudio_pitch_env_repeat,x
    sta famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_hi,x
    .if FAMISTUDIO_USE_PITCH_TRACK
        sta famistudio_pitch_env_fine_val,x
    .endif
    lda #1
    sta famistudio_pitch_env_ptr,x
    inx
    cpx #FAMISTUDIO_NUM_PITCH_ENVELOPES
    bne .set_pitch_envelopes

    jmp famistudio_sample_stop

;======================================================================================================================
; FAMISTUDIO_MUSIC_PLAY (public)
;
; Plays a song from the loaded music data (from a previous call to famistudio_init).
;
; [in] a : Song index.
;======================================================================================================================

famistudio_music_play:

.tmp = famistudio_ptr0_lo
.song_list_ptr = famistudio_ptr0
.temp_env_ptr  = famistudio_ptr1

    ldx famistudio_song_list_lo
    stx <.song_list_ptr+0
    ldx famistudio_song_list_hi
    stx <.song_list_ptr+1

    ldy #0
    cmp [.song_list_ptr],y
    bcc .valid_song
    rts ; Invalid song index.

.valid_song:
    .if FAMISTUDIO_NUM_CHANNELS = 5
    asl a
    sta <.tmp
    asl a
    tax
    asl a
    adc <.tmp
    stx <.tmp
    adc <.tmp
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 6
    asl a
    asl a
    asl a
    asl a
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 7
    asl a
    sta <.tmp
    asl a
    asl a
    asl a
    adc <.tmp
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 8
    asl a
    asl a
    sta <.tmp
    asl a
    asl a
    adc <.tmp
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 9
    asl a
    sta <.tmp
    asl a
    tax
    asl a
    asl a
    adc <.tmp
    stx <.tmp
    adc <.tmp
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 10
    asl a
    asl a
    asl a
    sta <.tmp
    asl a
    adc <.tmp
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 11
    asl a
    sta <.tmp
    asl a
    asl a
    tax
    asl a
    adc <.tmp
    stx <.tmp
    adc <.tmp
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 12
    asl a
    asl a
    sta <.tmp
    asl a
    tax
    asl a
    adc <.tmp
    stx <.tmp
    adc <.tmp
    .endif
    .if FAMISTUDIO_NUM_CHANNELS = 13
    asl a
    sta <.tmp
    asl a
    asl a
    asl a
    asl a
    sec
    sbc <.tmp
    .endif

    .if (FAMISTUDIO_EXP_FDS != 0) | (FAMISTUDIO_EXP_VRC7 != 0) | (FAMISTUDIO_EXP_N163 != 0)
    adc #7 ; We have an extra expansion instrument pointer for these.
    .else
    adc #5
    .endif
    tay

    lda famistudio_song_list_lo
    sta <.song_list_ptr+0

    jsr famistudio_music_stop

    ldx #0

.set_channels:

    ; Channel data address
    lda [.song_list_ptr],y
    sta famistudio_chn_ptr_lo,x
    iny
    lda [.song_list_ptr],y
    sta famistudio_chn_ptr_hi,x
    iny

    lda #0
    sta famistudio_chn_repeat,x
    sta famistudio_chn_instrument,x
    sta famistudio_chn_note,x
    sta famistudio_chn_ref_len,x
    .if FAMISTUDIO_USE_VOLUME_TRACK
        lda #$f0
        sta famistudio_chn_volume_track,x
    .endif

.nextchannel:
    inx
    cpx #FAMISTUDIO_NUM_CHANNELS
    bne .set_channels

    .if FAMISTUDIO_USE_FT_TEMPO
    lda famistudio_pal_adjust
    beq .pal
    iny
    iny
.pal:

    ; Tempo increment.
    lda [.song_list_ptr],y
    sta famistudio_tempo_step_lo
    iny
    lda [.song_list_ptr],y
    sta famistudio_tempo_step_hi

    lda #0 ; Reset tempo accumulator
    sta famistudio_tempo_acc_lo
    lda #6 ; Default speed
    sta famistudio_tempo_acc_hi
    sta famistudio_song_speed ; Apply default speed, this also enables music
    .else
    lda [.song_list_ptr],y
    sta famistudio_tempo_env_ptr_lo
    sta <.temp_env_ptr+0
    iny
    lda [.song_list_ptr],y
    sta famistudio_tempo_env_ptr_hi
    sta <.temp_env_ptr+1
    iny
    lda [.song_list_ptr],y
    .if FAMISTUDIO_DUAL_SUPPORT ; Dual mode
    ldx famistudio_pal_adjust
    bne .ntsc_target
    ora #1
    .ntsc_target:
    .else
    .if FAMISTUDIO_CFG_PAL_SUPPORT ; PAL only
    ora #1
    .endif
    .endif
    tax
    lda famistudio_tempo_frame_lookup, x ; Lookup contains the number of frames to run (0,1,2) to maintain tempo
    sta famistudio_tempo_frame_num
    ldy #0
    sty famistudio_tempo_env_idx
    lda [.temp_env_ptr],y
    clc
    adc #1
    sta famistudio_tempo_env_counter
    lda #6
    sta famistudio_song_speed ; Non-zero simply so the song isnt considered paused.
    .endif

    .if FAMISTUDIO_EXP_VRC7
    lda #0
    ldx #5
    .clear_vrc7_loop:
        sta famistudio_chn_vrc7_prev_hi, x
        sta famistudio_chn_vrc7_patch, x
        sta famistudio_chn_vrc7_trigger,x
        dex
        bpl .clear_vrc7_loop
    .endif

    .if FAMISTUDIO_EXP_FDS
    lda #0
    sta famistudio_fds_mod_speed+0
    sta famistudio_fds_mod_speed+1
    sta famistudio_fds_mod_depth
    sta famistudio_fds_mod_delay
    sta famistudio_fds_override_flags
    .endif

    .ifdef famistudio_chn_inst_changed
    lda #0
    ldx #(FAMISTUDIO_NUM_CHANNELS-5)
    .clear_inst_changed_loop:
        sta famistudio_chn_inst_changed, x
        dex
        bpl .clear_inst_changed_loop
    .endif

    .if FAMISTUDIO_EXP_N163
    lda #0
    ldx #FAMISTUDIO_EXP_N163_CHN_CNT
    .clear_vrc7_loop:
        sta famistudio_chn_n163_wave_len, x
        dex
        bpl .clear_vrc7_loop
    .endif

.skip:
    rts

;======================================================================================================================
; FAMISTUDIO_MUSIC_PAUSE (public)
;
; Pause/unpause the currently playing song. Note that this will not update the APU, so sound might linger. Calling
; famistudio_update after this will update the APU.
;
; [in] a : zero to play, non-zero to pause.
;======================================================================================================================

famistudio_music_pause:

    tax
    beq .unpause

.pause:

    jsr famistudio_sample_stop

    lda #0
    sta famistudio_env_value+FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    sta famistudio_env_value+FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    sta famistudio_env_value+FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    sta famistudio_env_value+FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .ifdef FAMISTUDIO_CH5_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH5_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH6_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH6_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH7_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH7_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH8_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH8_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH9_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH9_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH10_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH10_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH11_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH11_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH12_ENVS
    sta famistudio_env_value+FAMISTUDIO_CH12_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    lda famistudio_song_speed ; <= 0 pauses the music
    ora #$80
    bne .done
.unpause:
    lda famistudio_song_speed ; > 0 unpause music
    and #$7f
.done:
    sta famistudio_song_speed

    rts

;======================================================================================================================
; FAMISTUDIO_GET_NOTE_PITCH_MACRO (internal)
;
; Uber-macro used to compute the final pitch of a note, taking into account the current note, arpeggios, instrument
; pitch envelopes, slide notes and fine pitch tracks.
;
; [in] x : note index.
; [in] y : slide/pitch envelope index.
; [out] famistudio_ptr1 : Final note pitch.
;======================================================================================================================

famistudio_get_note_pitch_macro .macro ; pitch_env_offset, note_table_lsb, note_table_msb

pitch_env_offset\@ = \1
;note_table_lsb\@ = \2 ; Getting "Internal error" when trying to do this.
;note_table_msb\@ = \3 ; Getting "Internal error" when trying to do this.

.pitch   = famistudio_ptr1
.tmp_ror = famistudio_r0

    .if FAMISTUDIO_USE_PITCH_TRACK

    ; Pitch envelope + fine pitch (sign extended)
    clc
    lda famistudio_pitch_env_fine_val+pitch_env_offset\@, y
    adc famistudio_pitch_env_value_lo+pitch_env_offset\@, y
    sta <.pitch+0
    lda famistudio_pitch_env_fine_val+pitch_env_offset\@, y
    and #$80
    beq .pos
    lda #$ff
.pos:
    adc famistudio_pitch_env_value_hi+pitch_env_offset\@, y
    sta <.pitch+1

    .else

    ; Pitch envelope only
    lda famistudio_pitch_env_value_lo+pitch_env_offset\@, y
    sta <.pitch+0
    lda famistudio_pitch_env_value_hi+pitch_env_offset\@, y
    sta <.pitch+1

    .endif

    .if FAMISTUDIO_USE_SLIDE_NOTES
    ; Check if there is an active slide.
    lda famistudio_slide_step+pitch_env_offset\@, y
    beq .no_slide

    ; Add slide
    .if (pitch_env_offset\@ >= 3) & ((FAMISTUDIO_EXP_VRC7 != 0) | (FAMISTUDIO_EXP_N163 != 0))
    ; These channels dont have fractional part for slides and have the same shift for slides + pitch.
    clc
    lda famistudio_slide_pitch_lo+pitch_env_offset\@, y
    adc <.pitch+0
    sta <.pitch+0
    lda famistudio_slide_pitch_hi+pitch_env_offset\@, y
    adc <.pitch+1
    sta <.pitch+1
    .else
    ; Most channels have 1 bit of fraction for slides.
    lda famistudio_slide_pitch_hi+pitch_env_offset\@, y
    cmp #$80 ; Sign extend upcoming right shift.
    ror a ; We have 1 bit of fraction for slides, shift right hi byte.
    sta <.tmp_ror
    lda famistudio_slide_pitch_lo+pitch_env_offset\@, y
    ror a ; Shift right low byte.
    clc
    adc <.pitch+0
    sta <.pitch+0
    lda <.tmp_ror
    adc <.pitch+1
    sta <.pitch+1
    .endif
    .endif

.no_slide:

    .if (pitch_env_offset\@ >= 3) & ((FAMISTUDIO_EXP_VRC7 != 0) | (FAMISTUDIO_EXP_N163 != 0))
        .if FAMISTUDIO_PITCH_SHIFT >= 1
            asl <.pitch+0
            rol <.pitch+1
        .if FAMISTUDIO_PITCH_SHIFT >= 2
            asl <.pitch+0
            rol <.pitch+1
        .if FAMISTUDIO_PITCH_SHIFT >= 3
            asl <.pitch+0
            rol <.pitch+1
        .if FAMISTUDIO_PITCH_SHIFT >= 4
            asl <.pitch+0
            rol <.pitch+1
        .if FAMISTUDIO_PITCH_SHIFT >= 5
            asl <.pitch+0
            rol <.pitch+1
        .endif
        .endif
        .endif
        .endif
        .endif
    .endif

    ; Finally, add note pitch.
    clc
    lda \2,x ; \2 = note_table_lsb
    adc <.pitch+0
    sta <.pitch+0
    lda \3,x ; \3 = note_table_msb
    adc <.pitch+1
    sta <.pitch+1

    .endm

famistudio_get_note_pitch:
    famistudio_get_note_pitch_macro 0, famistudio_note_table_lsb, famistudio_note_table_msb
    rts

    .if FAMISTUDIO_EXP_VRC6
famistudio_get_note_pitch_vrc6_saw:
    famistudio_get_note_pitch_macro 0, famistudio_saw_note_table_lsb, famistudio_saw_note_table_msb
    rts
    .endif

;======================================================================================================================
; FAMISTUDIO_UPDATE_CHANNEL_SOUND (internal)
;
; Uber-macro used to update the APU registers for a given 2A03/VRC6/MMC5 channel. This macro is an absolute mess, but
; it is still more maintainable than having many different functions.
;
; [in] no input params.
;======================================================================================================================

famistudio_update_channel_sound .macro ; idx, env_offset, pulse_prev, vol_ora, hi_ora, reg_hi, reg_lo, reg_vol, reg_sweep

idx\@ = \1
env_offset\@ = \2
pulse_prev\@ = \3
vol_ora\@ = \4
hi_ora\@ = \5
reg_hi\@ = \6
reg_lo\@ = \7
reg_vol\@ = \8
reg_sweep\@ = \9

.tmp\@   = famistudio_r0
.pitch\@ = famistudio_ptr1

    lda famistudio_chn_note+idx\@
    bne .nocut\@
    jmp .set_volume\@

.nocut\@:
    clc
    adc famistudio_env_value+env_offset\@+FAMISTUDIO_ENV_NOTE_OFF

    .if idx\@ = 3 ; Noise channel is a bit special

    and #$0f
    eor #$0f
    sta <.tmp\@
    ldx famistudio_env_value+env_offset\@+FAMISTUDIO_ENV_DUTY_OFF
    lda famistudio_duty_lookup, x
    asl a
    and #$80
    ora <.tmp\@

    .else

    .if FAMISTUDIO_DUAL_SUPPORT
        clc
        adc famistudio_pal_adjust
    .endif
    tax

    .if idx\@ < 3
        ldy #idx\@
    .else
        ldy #(idx\@ - 2)
    .endif
    .if (FAMISTUDIO_EXP_VRC6 != 0) & (idx\@ = 7)
        jsr famistudio_get_note_pitch_vrc6_saw
    .else
        jsr famistudio_get_note_pitch
    .endif

    lda <.pitch\@+0
    sta reg_lo\@
    lda <.pitch\@+1

    .if (pulse_prev\@ != 0) & (FAMISTUDIO_CFG_SFX_SUPPORT = 0)
        .if (reg_sweep\@ != 0) & (FAMISTUDIO_CFG_SMOOTH_VIBRATO != 0)
            ; Blaarg's smooth vibrato technique, only used if high period delta is 1 or -1.
            tax ; X = new hi-period
            sec
            sbc pulse_prev\@ ; A = signed hi-period delta.
            beq .compute_volume
            stx pulse_prev\@
            tay
            iny ; We only care about -1 ($ff) and 1. Adding one means we only check of 0 or 2, we already checked for zero (so < 3).
            cpy #$03
            bcs .hi_delta_too_big\@
            ldx #$40
            stx FAMISTUDIO_APU_FRAME_CNT ; Reset frame counter in case it was about to clock
            lda famistudio_smooth_vibrato_period_lo_lookup, y ; Be sure low 8 bits of timer period are $ff (for positive delta), or $00 (for negative delta)
            sta reg_lo\@
            lda famistudio_smooth_vibrato_sweep_lookup, y ; Sweep enabled, shift = 7, set negative flag or delta is negative..
            sta reg_sweep\@
            lda #$c0
            sta FAMISTUDIO_APU_FRAME_CNT ; Clock sweep immediately
            lda #$08
            sta reg_sweep\@ ; Disable sweep
            lda <.pitch\@+0
            sta reg_lo\@ ; Restore lo-period.
            jmp .compute_volume\@
        .hi_delta_too_big\@:
            stx reg_hi\@
        .else
            cmp pulse_prev\@
            beq .compute_volume\@
            sta pulse_prev\@
        .endif
    .endif

    .if (hi_ora\@ != 0)
        ora #hi_ora\@
    .endif

    .endif ; idx = 3

    .if (pulse_prev\@ = 0) | (reg_sweep\@ = 0) | (FAMISTUDIO_CFG_SMOOTH_VIBRATO = 0)
    sta reg_hi\@
    .endif

.compute_volume\@:
    lda famistudio_env_value+env_offset\@+FAMISTUDIO_ENV_VOLUME_OFF

    .if FAMISTUDIO_USE_VOLUME_TRACK
        ora famistudio_chn_volume_track+idx\@
        tax
        lda famistudio_volume_table, x
    .endif

    .if (FAMISTUDIO_EXP_VRC6 != 0) & (idx\@ = 7)
    ; VRC6 saw has 6-bits
    asl a
    asl a
    .endif

.set_volume\@:

    .if (idx\@ = 0) | (idx\@ = 1) | (idx\@ = 3) | ((idx\@ >= 5) & (FAMISTUDIO_EXP_MMC5 != 0))
    ldx famistudio_env_value+env_offset\@+FAMISTUDIO_ENV_DUTY_OFF
    ora famistudio_duty_lookup, x
    .else
    .if ((idx\@ = 5) | (idx\@ = 6) & (FAMISTUDIO_EXP_VRC6 != 0))
    ldx famistudio_env_value+env_offset\@+FAMISTUDIO_ENV_DUTY_OFF
    ora famistudio_vrc6_duty_lookup, x
    .endif
    .endif

    .if (vol_ora\@ != 0)
    ora #vol_ora\@
    .endif

    sta reg_vol\@

    .endm

    .if FAMISTUDIO_EXP_FDS

;======================================================================================================================
; FAMISTUDIO_UPDATE_FDS_CHANNEL_SOUND (internal)
;
; Updates the FDS audio registers.
;
; [in] no input params.
;======================================================================================================================

famistudio_update_fds_channel_sound:

.pitch = famistudio_ptr1

    lda famistudio_chn_note+5
    bne .nocut
    jmp .set_volume

.nocut:
    clc
    adc famistudio_env_value+FAMISTUDIO_CH5_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    tax

    ldy #0
    famistudio_get_note_pitch_macro 3, famistudio_fds_note_table_lsb, famistudio_fds_note_table_msb

    lda <.pitch+0
    sta FAMISTUDIO_FDS_FREQ_LO
    lda <.pitch+1
    sta FAMISTUDIO_FDS_FREQ_HI

.check_mod_delay:
    lda famistudio_fds_mod_delay
    beq .zero_delay
    dec famistudio_fds_mod_delay
    lda #$80
    sta FAMISTUDIO_FDS_MOD_HI
    bne .compute_volume

.zero_delay:
    lda famistudio_fds_mod_speed+1
    sta FAMISTUDIO_FDS_MOD_HI
    lda famistudio_fds_mod_speed+0
    sta FAMISTUDIO_FDS_MOD_LO
    lda famistudio_fds_mod_depth
    ora #$80
    sta FAMISTUDIO_FDS_SWEEP_ENV

.compute_volume:
    lda famistudio_env_value+FAMISTUDIO_CH5_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .if FAMISTUDIO_USE_VOLUME_TRACK
        ora famistudio_chn_volume_track+5
        tax
        lda famistudio_volume_table, x
    .endif
    asl a ; FDS volume is 6-bits, but clamped to 32. Just double it.

.set_volume:
    ora #$80
    sta FAMISTUDIO_FDS_VOL_ENV
    lda #0
    sta famistudio_fds_override_flags

    rts

    .endif

    .if FAMISTUDIO_EXP_VRC7

famistudio_vrc7_reg_table_lo:
    .byte FAMISTUDIO_VRC7_REG_LO_1, FAMISTUDIO_VRC7_REG_LO_2, FAMISTUDIO_VRC7_REG_LO_3, FAMISTUDIO_VRC7_REG_LO_4, FAMISTUDIO_VRC7_REG_LO_5, FAMISTUDIO_VRC7_REG_LO_6
famistudio_vrc7_reg_table_hi:
    .byte FAMISTUDIO_VRC7_REG_HI_1, FAMISTUDIO_VRC7_REG_HI_2, FAMISTUDIO_VRC7_REG_HI_3, FAMISTUDIO_VRC7_REG_HI_4, FAMISTUDIO_VRC7_REG_HI_5, FAMISTUDIO_VRC7_REG_HI_6
famistudio_vrc7_vol_table:
    .byte FAMISTUDIO_VRC7_REG_VOL_1, FAMISTUDIO_VRC7_REG_VOL_2, FAMISTUDIO_VRC7_REG_VOL_3, FAMISTUDIO_VRC7_REG_VOL_4, FAMISTUDIO_VRC7_REG_VOL_5, FAMISTUDIO_VRC7_REG_VOL_6
famistudio_vrc7_env_table:
    .byte FAMISTUDIO_CH5_ENVS, FAMISTUDIO_CH6_ENVS, FAMISTUDIO_CH7_ENVS, FAMISTUDIO_CH8_ENVS, FAMISTUDIO_CH9_ENVS, FAMISTUDIO_CH10_ENVS
famistudio_vrc7_invert_vol_table:
    .byte $0f, $0e, $0d, $0c, $0b, $0a, $09, $08, $07, $06, $05, $04, $03, $02, $01, $00

; From nesdev wiki.
famistudio_vrc7_wait_reg_write:
    stx famistudio_vrc7_dummy
    ldx #$08
    .wait_loop:
        dex
        bne .wait_loop
        ldx famistudio_vrc7_dummy
    rts

; From nesdev wiki.
famistudio_vrc7_wait_reg_select:
    rts

;======================================================================================================================
; FAMISTUDIO_UPDATE_VRC7_CHANNEL_SOUND (internal)
;
; Updates the VRC7 audio registers for a given channel.
;
; [in] y: VRC7 channel idx (0,1,2,3,4,5)
;======================================================================================================================

famistudio_update_vrc7_channel_sound:

.pitch = famistudio_ptr1

    lda #0
    sta famistudio_chn_inst_changed,y

    lda famistudio_chn_vrc7_trigger,y
    bpl .check_cut

.release:

    ; Untrigger note.
    lda famistudio_vrc7_reg_table_hi,y
    sta FAMISTUDIO_VRC7_REG_SEL
    jsr famistudio_vrc7_wait_reg_select

    lda famistudio_chn_vrc7_prev_hi, y
    and #$ef ; remove trigger
    sta famistudio_chn_vrc7_prev_hi, y
    sta FAMISTUDIO_VRC7_REG_WRITE
    jsr famistudio_vrc7_wait_reg_write

    rts

.check_cut:

    lda famistudio_chn_note+5,y
    bne .nocut

.cut:
    ; Untrigger note.
    lda famistudio_vrc7_reg_table_hi,y
    sta FAMISTUDIO_VRC7_REG_SEL
    jsr famistudio_vrc7_wait_reg_select

    lda famistudio_chn_vrc7_prev_hi, y
    and #$cf ; Remove trigger + sustain
    sta famistudio_chn_vrc7_prev_hi, y
    sta FAMISTUDIO_VRC7_REG_WRITE
    jsr famistudio_vrc7_wait_reg_write

    rts

.nocut:

    ; Read note, apply arpeggio
    clc
    ldx famistudio_vrc7_env_table,y
    adc famistudio_env_value+FAMISTUDIO_ENV_NOTE_OFF,x
    tax

    ; Apply pitch envelope, fine pitch & slides
    famistudio_get_note_pitch_macro 3, famistudio_vrc7_note_table_lsb, famistudio_vrc7_note_table_msb

    ; Compute octave by dividing by 2 until we are <= 512 (0x100).
    ldx #0
    .compute_octave_loop:
        lda <.pitch+1
        cmp #2
        bcc .octave_done
        lsr a
        sta <.pitch+1
        ror <.pitch+0
        inx
        jmp .compute_octave_loop

    .octave_done:

    ; Write pitch (lo)
    lda famistudio_vrc7_reg_table_lo,y
    sta FAMISTUDIO_VRC7_REG_SEL
    jsr famistudio_vrc7_wait_reg_select

    lda <.pitch+0
    sta FAMISTUDIO_VRC7_REG_WRITE
    jsr famistudio_vrc7_wait_reg_write

    ; Un-trigger previous note if needed.
    lda famistudio_chn_vrc7_prev_hi, y
    and #$10 ; set trigger.
    beq .write_hi_period
    lda famistudio_chn_vrc7_trigger,y
    beq .write_hi_period
    .untrigger_prev_note:
        lda famistudio_vrc7_reg_table_hi,y
        sta FAMISTUDIO_VRC7_REG_SEL
        jsr famistudio_vrc7_wait_reg_select

        lda famistudio_chn_vrc7_prev_hi,y
        and #$ef ; remove trigger
        sta FAMISTUDIO_VRC7_REG_WRITE
        jsr famistudio_vrc7_wait_reg_write

    .write_hi_period:

    ; Write pitch (hi)
    lda famistudio_vrc7_reg_table_hi,y
    sta FAMISTUDIO_VRC7_REG_SEL
    jsr famistudio_vrc7_wait_reg_select

    txa
    asl a
    ora #$30
    ora <.pitch+1
    sta famistudio_chn_vrc7_prev_hi, y
    sta FAMISTUDIO_VRC7_REG_WRITE
    jsr famistudio_vrc7_wait_reg_write

    ; Read/multiply volume
    ldx famistudio_vrc7_env_table,y
    lda famistudio_env_value+FAMISTUDIO_ENV_VOLUME_OFF,x
    .if FAMISTUDIO_USE_VOLUME_TRACK
        ora famistudio_chn_volume_track+5, y
    .endif
    tax

    lda #0
    sta famistudio_chn_vrc7_trigger,y

.update_volume:

    ; Write volume
    lda famistudio_vrc7_vol_table,y
    sta FAMISTUDIO_VRC7_REG_SEL
    jsr famistudio_vrc7_wait_reg_select
    .if FAMISTUDIO_USE_VOLUME_TRACK
        lda famistudio_volume_table,x
        tax
    .endif
    lda famistudio_vrc7_invert_vol_table,x
    ora famistudio_chn_vrc7_patch,y
    sta FAMISTUDIO_VRC7_REG_WRITE
    jsr famistudio_vrc7_wait_reg_write

    rts

    .endif

    .if FAMISTUDIO_EXP_N163

famistudio_n163_reg_table_lo:
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $00
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $08
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $10
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $18
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $20
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $28
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $30
    .byte FAMISTUDIO_N163_REG_FREQ_LO - $38
famistudio_n163_reg_table_mid:
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $00
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $08
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $10
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $18
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $20
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $28
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $30
    .byte FAMISTUDIO_N163_REG_FREQ_MID - $38
famistudio_n163_reg_table_hi:
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $00
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $08
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $10
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $18
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $20
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $28
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $30
    .byte FAMISTUDIO_N163_REG_FREQ_HI - $38
famistudio_n163_vol_table:
    .byte FAMISTUDIO_N163_REG_VOLUME - $00
    .byte FAMISTUDIO_N163_REG_VOLUME - $08
    .byte FAMISTUDIO_N163_REG_VOLUME - $10
    .byte FAMISTUDIO_N163_REG_VOLUME - $18
    .byte FAMISTUDIO_N163_REG_VOLUME - $20
    .byte FAMISTUDIO_N163_REG_VOLUME - $28
    .byte FAMISTUDIO_N163_REG_VOLUME - $30
    .byte FAMISTUDIO_N163_REG_VOLUME - $38
famistudio_n163_env_table:
    .byte FAMISTUDIO_CH5_ENVS
    .byte FAMISTUDIO_CH6_ENVS
    .byte FAMISTUDIO_CH7_ENVS
    .byte FAMISTUDIO_CH8_ENVS
    .byte FAMISTUDIO_CH9_ENVS
    .byte FAMISTUDIO_CH10_ENVS
    .byte FAMISTUDIO_CH11_ENVS
    .byte FAMISTUDIO_CH12_ENVS

;======================================================================================================================
; FAMISTUDIO_UPDATE_N163_CHANNEL_SOUND (internal)
;
; Updates the N163 audio registers for a given channel.
;
; [in] y: N163 channel idx (0,1,2,3,4,5,6,7)
;======================================================================================================================

famistudio_update_n163_channel_sound:

.pitch    = famistudio_ptr1
.pitch_hi = famistudio_r2

    lda famistudio_chn_note+5,y
    bne .nocut
    ldx #0 ; This will fetch volume 0.
    bne .nocut
    jmp .update_volume

.nocut:

    ; Read note, apply arpeggio
    clc
    ldx famistudio_n163_env_table,y
    adc famistudio_env_value+FAMISTUDIO_ENV_NOTE_OFF,x
    tax

    ; Apply pitch envelope, fine pitch & slides
    famistudio_get_note_pitch_macro 3, famistudio_n163_note_table_lsb, famistudio_n163_note_table_msb

    ; Convert 16-bit -> 18-bit.
    asl <.pitch+0
    rol <.pitch+1
    lda #0
    adc #0
    sta <.pitch_hi
    asl <.pitch+0
    rol <.pitch+1
    rol <.pitch_hi

    ; Write pitch
    lda famistudio_n163_reg_table_lo,y
    sta FAMISTUDIO_N163_ADDR
    lda <.pitch+0
    sta FAMISTUDIO_N163_DATA
    lda famistudio_n163_reg_table_mid,y
    sta FAMISTUDIO_N163_ADDR
    lda <.pitch+1
    sta FAMISTUDIO_N163_DATA
    lda famistudio_n163_reg_table_hi,y
    sta FAMISTUDIO_N163_ADDR
    lda famistudio_chn_n163_wave_len,y
    ora <.pitch_hi
    sta FAMISTUDIO_N163_DATA

    ; Read/multiply volume
    ldx famistudio_n163_env_table,y
    lda famistudio_env_value+FAMISTUDIO_ENV_VOLUME_OFF,x
    .if FAMISTUDIO_USE_VOLUME_TRACK
        ora famistudio_chn_volume_track+5, y
    .endif
    tax

.update_volume:
    ; Write volume
    lda famistudio_n163_vol_table,y
    sta FAMISTUDIO_N163_ADDR
    .if FAMISTUDIO_USE_VOLUME_TRACK
        lda famistudio_volume_table,x
    .else
        txa
    .endif
    ora #FAMISTUDIO_N163_CHN_MASK
    sta FAMISTUDIO_N163_DATA

    lda #0
    sta famistudio_chn_inst_changed,y

    rts

    .endif

    .if FAMISTUDIO_EXP_S5B

famistudio_s5b_reg_table_lo:
    .byte FAMISTUDIO_S5B_REG_LO_A, FAMISTUDIO_S5B_REG_LO_B, FAMISTUDIO_S5B_REG_LO_C
famistudio_s5b_reg_table_hi:
    .byte FAMISTUDIO_S5B_REG_HI_A, FAMISTUDIO_S5B_REG_HI_B, FAMISTUDIO_S5B_REG_HI_C
famistudio_s5b_vol_table:
    .byte FAMISTUDIO_S5B_REG_VOL_A, FAMISTUDIO_S5B_REG_VOL_B, FAMISTUDIO_S5B_REG_VOL_C
famistudio_s5b_env_table:
    .byte FAMISTUDIO_CH5_ENVS, FAMISTUDIO_CH6_ENVS, FAMISTUDIO_CH7_ENVS

;======================================================================================================================
; FAMISTUDIO_UPDATE_S5B_CHANNEL_SOUND (internal)
;
; Updates the S5B audio registers for a given channel.
;
; [in] y: S5B channel idx (0,1,2)
;======================================================================================================================

famistudio_update_s5b_channel_sound:

.pitch = famistudio_ptr1

    lda famistudio_chn_note+5,y
    bne .nocut
    ldx #0 ; This will fetch volume 0.
    beq .update_volume

.nocut:

    ; Read note, apply arpeggio
    clc
    ldx famistudio_s5b_env_table,y
    adc famistudio_env_value+FAMISTUDIO_ENV_NOTE_OFF,x
    tax

    ; Apply pitch envelope, fine pitch & slides
    famistudio_get_note_pitch_macro 3, famistudio_note_table_lsb, famistudio_note_table_msb

    ; Write pitch
    lda famistudio_s5b_reg_table_lo,y
    sta FAMISTUDIO_S5B_ADDR
    lda <.pitch+0
    sta FAMISTUDIO_S5B_DATA
    lda famistudio_s5b_reg_table_hi,y
    sta FAMISTUDIO_S5B_ADDR
    lda <.pitch+1
    sta FAMISTUDIO_S5B_DATA

    ; Read/multiply volume
    ldx famistudio_s5b_env_table,y
    lda famistudio_env_value+FAMISTUDIO_ENV_VOLUME_OFF,x
    .if FAMISTUDIO_USE_VOLUME_TRACK
        ora famistudio_chn_volume_track+5, y
    .endif
    tax

.update_volume:
    ; Write volume
    lda famistudio_s5b_vol_table,y
    sta FAMISTUDIO_S5B_ADDR
    .if FAMISTUDIO_USE_VOLUME_TRACK
        lda famistudio_volume_table,x
        sta FAMISTUDIO_S5B_DATA
    .else
        stx FAMISTUDIO_S5B_DATA
    .endif
    rts

    .endif

;======================================================================================================================
; FAMISTUDIO_UPDATE_ROW (internal)
;
; Macro to advance the song for a given channel. Will read any new note or effect (if any) and load any new
; instrument (if any).
;======================================================================================================================

famistudio_update_row .macro ; channel_idx, env_idx

channel_idx\@ = \1
env_idx\@ = \2

    ldx #channel_idx\@
    jsr famistudio_channel_update
    bcc .no_new_note\@
    ldx #env_idx\@
    ldy #channel_idx\@
    lda famistudio_chn_instrument+channel_idx\@

    .if (FAMISTUDIO_EXP_FDS != 0) & (channel_idx\@ >= 5)
    jsr famistudio_set_fds_instrument
    .endif
    .if (FAMISTUDIO_EXP_VRC7 != 0) & (channel_idx\@ >= 5)
    jsr famistudio_set_vrc7_instrument
    .endif
    .if (FAMISTUDIO_EXP_N163 != 0) & (channel_idx\@ >= 5)
    jsr famistudio_set_n163_instrument
    .endif
    .if ((FAMISTUDIO_EXP_FDS + FAMISTUDIO_EXP_VRC7 + FAMISTUDIO_EXP_N163) = 0) | (channel_idx\@ < 5)
    jsr famistudio_set_instrument
    .endif

    .if FAMISTUDIO_CFG_EQUALIZER
    .new_note\@:
        ldx #channel_idx\@
        lda #8
        sta famistudio_chn_note_counter, x
        jmp .done\@
    .no_new_note\@:
        ldx #channel_idx\@
        lda famistudio_chn_note_counter, x
        beq .done\@
        dec famistudio_chn_note_counter, x
    .done\@:
    .else
    .no_new_note\@:
    .endif

    .endm

;======================================================================================================================
; FAMISTUDIO_UPDATE_ROW_DPCM (internal)
;
; Special version for DPCM.
;======================================================================================================================

famistudio_update_row_dpcm .macro ; channel_idx

channel_idx\@ = \1

    .if FAMISTUDIO_CFG_DPCM_SUPPORT
    ldx #channel_idx\@
    jsr famistudio_channel_update
    bcc .no_new_note\@
    lda famistudio_chn_note+channel_idx\@
    bne .play_sample\@
    jsr famistudio_sample_stop
    bne .no_new_note\@
.play_sample\@:
    jsr famistudio_music_sample_play

    .if FAMISTUDIO_CFG_EQUALIZER
    .new_note\@:
        ldx #channel_idx\@
        lda #8
        sta famistudio_chn_note_counter, x
        jmp .done\@
    .no_new_note\@:
        ldx #channel_idx\@
        lda famistudio_chn_note_counter, x
        beq .done\@
        dec famistudio_chn_note_counter, x
    .done\@:
    .else
    .no_new_note\@:
    .endif

    .endif
    .endm

;======================================================================================================================
; FAMISTUDIO_UPDATE (public)
;
; Main update function, should be called once per frame, ideally at the end of NMI. Will update the tempo, advance
; the song if needed, update instrument and apply any change to the APU registers.
;
; [in] no input params.
;======================================================================================================================

famistudio_update:

.pitch_env_type = famistudio_r0
.temp_pitch     = famistudio_r1
.tempo_env_ptr  = famistudio_ptr0
.env_ptr        = famistudio_ptr0
.pitch_env_ptr  = famistudio_ptr0

    .if FAMISTUDIO_CFG_THREAD
    lda <famistudio_ptr0_lo
    pha
    lda <famistudio_ptr0_hi
    pha
    .endif

    lda famistudio_song_speed ; Speed 0 means that no music is playing currently
    bmi .pause ; Bit 7 set is the pause flag
    bne .update
.pause:
    .if !FAMISTUDIO_USE_FT_TEMPO
    lda #1
    sta famistudio_tempo_frame_cnt
    .endif
    jmp .update_sound

;----------------------------------------------------------------------------------------------------------------------
.update:

    .if FAMISTUDIO_USE_FT_TEMPO
    clc  ; Update frame counter that considers speed, tempo, and PAL/NTSC
    lda famistudio_tempo_acc_lo
    adc famistudio_tempo_step_lo
    sta famistudio_tempo_acc_lo
    lda famistudio_tempo_acc_hi
    adc famistudio_tempo_step_hi
    cmp famistudio_song_speed
    bcs .update_row ; Overflow, row update is needed
    sta famistudio_tempo_acc_hi ; No row update, skip to the envelopes update
    jmp .update_envelopes

.update_row:
    sec
    sbc famistudio_song_speed
    sta famistudio_tempo_acc_hi

    .else ; FamiStudio tempo

    ; Decrement envelope counter, see if we need to advance.
    dec famistudio_tempo_env_counter
    beq .advance_tempo_envelope
    lda #1
    jmp .store_frame_count

.advance_tempo_envelope:
    ; Advance the envelope by one step.
    lda famistudio_tempo_env_ptr_lo
    sta <.tempo_env_ptr+0
    lda famistudio_tempo_env_ptr_hi
    sta <.tempo_env_ptr+1

    inc famistudio_tempo_env_idx
    ldy famistudio_tempo_env_idx
    lda [.tempo_env_ptr],y
    bpl .store_counter ; Negative value means we loop back to to index 1.

.tempo_envelope_end:
    ldy #1
    sty famistudio_tempo_env_idx
    lda [.tempo_env_ptr],y

.store_counter:
    ; Reset the counter
    sta famistudio_tempo_env_counter
    lda famistudio_tempo_frame_num
    bne .store_frame_count
    jmp .skip_frame

.store_frame_count:
    sta famistudio_tempo_frame_cnt

.update_row:

    .endif

    ; TODO: Turn most of these in loops, no reasons to be macros.
    famistudio_update_row 0, FAMISTUDIO_CH0_ENVS
    famistudio_update_row 1, FAMISTUDIO_CH1_ENVS
    famistudio_update_row 2, FAMISTUDIO_CH2_ENVS
    famistudio_update_row 3, FAMISTUDIO_CH3_ENVS
    famistudio_update_row_dpcm 4

    .if FAMISTUDIO_EXP_VRC6
    famistudio_update_row 5, FAMISTUDIO_CH5_ENVS
    famistudio_update_row 6, FAMISTUDIO_CH6_ENVS
    famistudio_update_row 7, FAMISTUDIO_CH7_ENVS
    .endif

    .if FAMISTUDIO_EXP_VRC7
    famistudio_update_row  5, FAMISTUDIO_CH5_ENVS
    famistudio_update_row  6, FAMISTUDIO_CH6_ENVS
    famistudio_update_row  7, FAMISTUDIO_CH7_ENVS
    famistudio_update_row  8, FAMISTUDIO_CH8_ENVS
    famistudio_update_row  9, FAMISTUDIO_CH9_ENVS
    famistudio_update_row 10, FAMISTUDIO_CH10_ENVS
    .endif

    .if FAMISTUDIO_EXP_FDS
    famistudio_update_row 5, FAMISTUDIO_CH5_ENVS
    .endif

    .if FAMISTUDIO_EXP_MMC5
    famistudio_update_row 5, FAMISTUDIO_CH5_ENVS
    famistudio_update_row 6, FAMISTUDIO_CH6_ENVS
    .endif

    .if FAMISTUDIO_EXP_S5B
    famistudio_update_row 5, FAMISTUDIO_CH5_ENVS
    famistudio_update_row 6, FAMISTUDIO_CH6_ENVS
    famistudio_update_row 7, FAMISTUDIO_CH7_ENVS
    .endif

    .if FAMISTUDIO_EXP_N163
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 1
        famistudio_update_row  5, FAMISTUDIO_CH5_ENVS
        .endif
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 2
        famistudio_update_row  6, FAMISTUDIO_CH6_ENVS
        .endif
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 3
        famistudio_update_row  7, FAMISTUDIO_CH7_ENVS
        .endif
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 4
        famistudio_update_row  8, FAMISTUDIO_CH8_ENVS
        .endif
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 5
        famistudio_update_row  9, FAMISTUDIO_CH9_ENVS
        .endif
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 6
        famistudio_update_row 10, FAMISTUDIO_CH10_ENVS
        .endif
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 7
        famistudio_update_row 11, FAMISTUDIO_CH11_ENVS
        .endif
        .if FAMISTUDIO_EXP_N163_CHN_CNT >= 8
        famistudio_update_row 12, FAMISTUDIO_CH12_ENVS
        .endif
    .endif

;----------------------------------------------------------------------------------------------------------------------
.update_envelopes:
    ldx #0

.env_process:
    lda famistudio_env_repeat,x
    beq .env_read
    dec famistudio_env_repeat,x
    bne .env_next

.env_read:
    lda famistudio_env_addr_lo,x
    sta <.env_ptr+0
    lda famistudio_env_addr_hi,x
    sta <.env_ptr+1
    ldy famistudio_env_ptr,x

.env_read_value:
    lda [.env_ptr],y
    bpl .env_special ; Values below 128 used as a special code, loop or repeat
    clc              ; Values above 128 are output value+192 (output values are signed -63..64)
    adc #256-192
    sta famistudio_env_value,x
    iny
    bne .env_next_store_ptr

.env_special:
    bne .env_set_repeat  ; Zero is the loop point, non-zero values used for the repeat counter
    iny
    lda [.env_ptr],y     ; Read loop position
    tay
    jmp .env_read_value

.env_set_repeat:
    iny
    sta famistudio_env_repeat,x ; Store the repeat counter value

.env_next_store_ptr:
    tya
    sta famistudio_env_ptr,x

.env_next:
    inx

    cpx #FAMISTUDIO_NUM_ENVELOPES
    bne .env_process

;----------------------------------------------------------------------------------------------------------------------
.update_pitch_envelopes:
    ldx #0
    jmp .pitch_env_process

.update_pitch_relate_last_val:
    lda famistudio_pitch_env_repeat,x
    sec
    sbc #1
    sta famistudio_pitch_env_repeat,x
    and #$7f
    beq .pitch_env_read
    lda famistudio_pitch_env_addr_lo,x
    sta <.pitch_env_ptr+0
    lda famistudio_pitch_env_addr_hi,x
    sta <.pitch_env_ptr+1
    ldy famistudio_pitch_env_ptr,x
    dey
    dey
    lda [.pitch_env_ptr],y
    clc
    adc #256-192
    sta <.temp_pitch
    clc
    adc famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_lo,x
    lda <.temp_pitch
    bpl .pitch_relative_last_pos
    lda #$ff
.pitch_relative_last_pos:
    adc famistudio_pitch_env_value_hi,x
    sta famistudio_pitch_env_value_hi,x
    jmp .pitch_env_next

.pitch_env_process:
    lda famistudio_pitch_env_repeat,x
    cmp #$81
    bcs .update_pitch_relate_last_val
    and #$7f
    beq .pitch_env_read
    dec famistudio_pitch_env_repeat,x
    bne .pitch_env_next

.pitch_env_read:
    lda famistudio_pitch_env_addr_lo,x
    sta <.pitch_env_ptr+0
    lda famistudio_pitch_env_addr_hi,x
    sta <.pitch_env_ptr+1
    ldy #0
    lda [.pitch_env_ptr],y
    sta <.pitch_env_type ; First value is 0 for absolute envelope, 0x80 for relative.
    ldy famistudio_pitch_env_ptr,x

.pitch_env_read_value:
    lda [.pitch_env_ptr],y
    bpl .pitch_env_special
    clc
    adc #256-192
    bit <.pitch_env_type
    bmi .pitch_relative

.pitch_absolute:
    sta famistudio_pitch_env_value_lo,x
    ora #0
    bmi .pitch_absolute_neg
    lda #0
    jmp .pitch_absolute_set_value_hi
.pitch_absolute_neg:
    lda #$ff
.pitch_absolute_set_value_hi:
    sta famistudio_pitch_env_value_hi,x
    iny
    jmp .pitch_env_next_store_ptr

.pitch_relative:
    sta <.temp_pitch
    clc
    adc famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_lo,x
    lda <.temp_pitch
    and #$80
    bpl .pitch_relative_pos
    lda #$ff
.pitch_relative_pos:
    adc famistudio_pitch_env_value_hi,x
    sta famistudio_pitch_env_value_hi,x
    iny
    jmp .pitch_env_next_store_ptr

.pitch_env_special:
    bne .pitch_env_set_repeat
    iny
    lda [.pitch_env_ptr],y
    tay
    jmp .pitch_env_read_value

.pitch_env_set_repeat:
    iny
    ora <.pitch_env_type ; This is going to set the relative flag in the hi-bit.
    sta famistudio_pitch_env_repeat,x

.pitch_env_next_store_ptr:
    tya
    sta famistudio_pitch_env_ptr,x

.pitch_env_next:
    inx

    cpx #FAMISTUDIO_NUM_PITCH_ENVELOPES
    bne .pitch_env_process

    .if FAMISTUDIO_USE_SLIDE_NOTES
;----------------------------------------------------------------------------------------------------------------------
.update_slides:
    ldx #0

.slide_process:
    lda famistudio_slide_step,x ; Zero repeat means no active slide.
    beq .slide_next
    clc ; Add step to slide pitch (16bit + 8bit signed).
    lda famistudio_slide_step,x
    adc famistudio_slide_pitch_lo,x
    sta famistudio_slide_pitch_lo,x
    lda famistudio_slide_step,x
    and #$80
    beq .positive_slide

.negative_slide:
    lda #$ff
    adc famistudio_slide_pitch_hi,x
    sta famistudio_slide_pitch_hi,x
    bpl .slide_next
    jmp .clear_slide

.positive_slide:
    adc famistudio_slide_pitch_hi,x
    sta famistudio_slide_pitch_hi,x
    bmi .slide_next

.clear_slide:
    lda #0
    sta famistudio_slide_step,x

.slide_next:
    inx
    cpx #FAMISTUDIO_NUM_PITCH_ENVELOPES
    bne .slide_process
    .endif

;----------------------------------------------------------------------------------------------------------------------
.update_sound:

    famistudio_update_channel_sound 0, FAMISTUDIO_CH0_ENVS, famistudio_pulse1_prev, 0, 0, FAMISTUDIO_ALIAS_PL1_HI, FAMISTUDIO_ALIAS_PL1_LO, FAMISTUDIO_ALIAS_PL1_VOL, FAMISTUDIO_APU_PL1_SWEEP
    famistudio_update_channel_sound 1, FAMISTUDIO_CH1_ENVS, famistudio_pulse2_prev, 0, 0, FAMISTUDIO_ALIAS_PL2_HI, FAMISTUDIO_ALIAS_PL2_LO, FAMISTUDIO_ALIAS_PL2_VOL, FAMISTUDIO_APU_PL2_SWEEP
    famistudio_update_channel_sound 2, FAMISTUDIO_CH2_ENVS, 0, #$80, 0, FAMISTUDIO_ALIAS_TRI_HI, FAMISTUDIO_ALIAS_TRI_LO, FAMISTUDIO_ALIAS_TRI_LINEAR, 0
    famistudio_update_channel_sound 3, FAMISTUDIO_CH3_ENVS, 0, #$f0, 0, FAMISTUDIO_ALIAS_NOISE_LO, 0, FAMISTUDIO_ALIAS_NOISE_VOL, 0

    .if FAMISTUDIO_EXP_VRC6
    famistudio_update_channel_sound 5, FAMISTUDIO_CH5_ENVS, 0, 0, #$80, FAMISTUDIO_VRC6_PL1_HI, FAMISTUDIO_VRC6_PL1_LO, FAMISTUDIO_VRC6_PL1_VOL, 0
    famistudio_update_channel_sound 6, FAMISTUDIO_CH6_ENVS, 0, 0, #$80, FAMISTUDIO_VRC6_PL2_HI, FAMISTUDIO_VRC6_PL2_LO, FAMISTUDIO_VRC6_PL2_VOL, 0
    famistudio_update_channel_sound 7, FAMISTUDIO_CH7_ENVS, 0, 0, #$80, FAMISTUDIO_VRC6_SAW_HI, FAMISTUDIO_VRC6_SAW_LO, FAMISTUDIO_VRC6_SAW_VOL, 0
    .endif

    .if FAMISTUDIO_EXP_MMC5
    famistudio_update_channel_sound 5, FAMISTUDIO_CH5_ENVS, famistudio_mmc5_pulse1_prev, 0, 0, FAMISTUDIO_MMC5_PL1_HI, FAMISTUDIO_MMC5_PL1_LO, FAMISTUDIO_MMC5_PL1_VOL, 0
    famistudio_update_channel_sound 6, FAMISTUDIO_CH6_ENVS, famistudio_mmc5_pulse2_prev, 0, 0, FAMISTUDIO_MMC5_PL2_HI, FAMISTUDIO_MMC5_PL2_LO, FAMISTUDIO_MMC5_PL2_VOL, 0
    .endif

    .if FAMISTUDIO_EXP_FDS
    jsr famistudio_update_fds_channel_sound
    .endif

    .if FAMISTUDIO_EXP_VRC7
    ldy #0
    .vrc7_channel_loop:
        jsr famistudio_update_vrc7_channel_sound
        iny
        cpy #6
        bne .vrc7_channel_loop
    .endif

    .if FAMISTUDIO_EXP_N163
    ldy #0
    .n163_channel_loop:
        jsr famistudio_update_n163_channel_sound
        iny
        cpy #FAMISTUDIO_EXP_N163_CHN_CNT
        bne .n163_channel_loop
    .endif

    .if FAMISTUDIO_EXP_S5B
    ldy #0
    .s5b_channel_loop:
        jsr famistudio_update_s5b_channel_sound
        iny
        cpy #3
        bne .s5b_channel_loop
    .endif

    .if !FAMISTUDIO_USE_FT_TEMPO
    ; See if we need to run a double frame (playing NTSC song on PAL)
    dec famistudio_tempo_frame_cnt
    beq .skip_frame
    jmp .update_row
    .endif

.skip_frame:

;----------------------------------------------------------------------------------------------------------------------
    .if FAMISTUDIO_CFG_SFX_SUPPORT

    ; Process all sound effect streams
    .if FAMISTUDIO_CFG_SFX_STREAMS > 0
    ldx #FAMISTUDIO_SFX_CH0
    jsr famistudio_sfx_update
    .endif
    .if FAMISTUDIO_CFG_SFX_STREAMS > 1
    ldx #FAMISTUDIO_SFX_CH1
    jsr famistudio_sfx_update
    .endif
    .if FAMISTUDIO_CFG_SFX_STREAMS > 2
    ldx #FAMISTUDIO_SFX_CH2
    jsr famistudio_sfx_update
    .endif
    .if FAMISTUDIO_CFG_SFX_STREAMS > 3
    ldx #FAMISTUDIO_SFX_CH3
    jsr famistudio_sfx_update
    .endif

    ; Send data from the output buffer to the APU

    lda famistudio_output_buf      ; Pulse 1 volume
    sta FAMISTUDIO_APU_PL1_VOL
    lda famistudio_output_buf+1    ; Pulse 1 period LSB
    sta FAMISTUDIO_APU_PL1_LO
    lda famistudio_output_buf+2    ; Pulse 1 period MSB, only applied when changed
    cmp famistudio_pulse1_prev
    beq .no_pulse1_upd
    sta famistudio_pulse1_prev
    sta FAMISTUDIO_APU_PL1_HI

.no_pulse1_upd:
    lda famistudio_output_buf+3    ; Pulse 2 volume
    sta FAMISTUDIO_APU_PL2_VOL
    lda famistudio_output_buf+4    ; Pulse 2 period LSB
    sta FAMISTUDIO_APU_PL2_LO
    lda famistudio_output_buf+5    ; Pulse 2 period MSB, only applied when changed
    cmp famistudio_pulse2_prev
    beq .no_pulse2_upd
    sta famistudio_pulse2_prev
    sta FAMISTUDIO_APU_PL2_HI

.no_pulse2_upd:
    lda famistudio_output_buf+6    ; Triangle volume (plays or not)
    sta FAMISTUDIO_APU_TRI_LINEAR
    lda famistudio_output_buf+7    ; Triangle period LSB
    sta FAMISTUDIO_APU_TRI_LO
    lda famistudio_output_buf+8    ; Triangle period MSB
    sta FAMISTUDIO_APU_TRI_HI

    lda famistudio_output_buf+9    ; Noise volume
    sta FAMISTUDIO_APU_NOISE_VOL
    lda famistudio_output_buf+10   ; Noise period
    sta FAMISTUDIO_APU_NOISE_LO

    .endif

    .if FAMISTUDIO_CFG_THREAD
    pla
    sta <famistudio_ptr0_hi
    pla
    sta <famistudio_ptr0_lo
    .endif

    rts

;======================================================================================================================
; FAMISTUDIO_SET_INSTRUMENT (internal)
;
; Internal function to set an instrument for a given channel. Will initialize all instrument envelopes.
;
; [in] x: first envelope index for this channel.
; [in] y: channel index
; [in] a: instrument index.
;======================================================================================================================

famistudio_set_instrument:

.intrument_ptr = famistudio_ptr0
.chan_idx      = famistudio_r1
.tmp_x         = famistudio_r2

    sty <.chan_idx
    asl a ; Instrument number is pre multiplied by 4
    tay
    lda famistudio_instrument_hi
    adc #0 ; Use carry to extend range for 64 instruments
    sta <.intrument_ptr+1
    lda famistudio_instrument_lo
    sta <.intrument_ptr+0

    ; Volume envelope
    lda [.intrument_ptr],y
    sta famistudio_env_addr_lo,x
    iny
    lda [.intrument_ptr],y
    iny
    sta famistudio_env_addr_hi,x
    inx

    ; Arpeggio envelope
    .if FAMISTUDIO_USE_ARPEGGIO
    stx <.tmp_x
    ldx <.chan_idx
    lda famistudio_chn_env_override,x ; Check if its overriden by arpeggio.
    lsr a
    ldx <.tmp_x
    bcc .read_arpeggio_ptr
    iny ; Instrument arpeggio is overriden by arpeggio, dont touch!
    jmp .init_envelopes
    .endif

.read_arpeggio_ptr:
    lda [.intrument_ptr],y
    sta famistudio_env_addr_lo,x
    iny
    lda [.intrument_ptr],y
    sta famistudio_env_addr_hi,x

.init_envelopes:
    ; Initialize volume + arpeggio envelopes.
    lda #1
    sta famistudio_env_ptr-1,x ; Reset volume envelope pointer to 1 (volume have releases point in index 0)
    lda #0
    sta famistudio_env_repeat-1,x
    sta famistudio_env_repeat,x
    sta famistudio_env_ptr,x

    ; Duty cycle envelope
    lda <.chan_idx
    cmp #2 ; Triangle has no duty.
    .if !FAMISTUDIO_EXP_S5B
    bne .duty
    .else
    beq .no_duty
    cmp #5 ; S5B has no duty.
    bcc .duty
    .endif
    .no_duty:
        iny
        iny
        bne .pitch_env
    .duty:
        inx
        iny
        lda [.intrument_ptr],y
        sta famistudio_env_addr_lo,x
        iny
        lda [.intrument_ptr],y
        sta famistudio_env_addr_hi,x
        lda #0
        sta famistudio_env_repeat,x
        sta famistudio_env_ptr,x
    .pitch_env:
    ; Pitch envelopes.
    ldx <.chan_idx
    .if FAMISTUDIO_USE_VIBRATO
    lda famistudio_chn_env_override,x ; Instrument pitch is overriden by vibrato, dont touch!
    bmi .no_pitch
    .endif
    lda famistudio_chan_to_pitch_env, x
    bmi .no_pitch
    tax
    lda #1
    sta famistudio_pitch_env_ptr,x     ; Reset pitch envelope pointert to 1 (pitch envelope have relative/absolute flag in the first byte)
    lda #0
    sta famistudio_pitch_env_repeat,x
    sta famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_hi,x
    iny
    lda [.intrument_ptr],y
    sta famistudio_pitch_env_addr_lo,x
    iny
    lda [.intrument_ptr],y
    sta famistudio_pitch_env_addr_hi,x
    .no_pitch:
    rts

    .if (FAMISTUDIO_EXP_FDS != 0) | (FAMISTUDIO_EXP_N163 != 0) | (FAMISTUDIO_EXP_VRC7 != 0)

;======================================================================================================================
; FAMISTUDIO_SET_EXP_INSTRUMENT_BASE (internal)
;
; Internal macro to set an expansion instrument for a given channel. Will initialize all instrument envelopes.
;
; [in] x: first envelope index for this channel.
; [in] y: channel index
; [in] a: instrument index.
;======================================================================================================================

famistudio_set_exp_instrument .macro

.chan_idx = famistudio_r1
.tmp_x    = famistudio_r2
.ptr      = famistudio_ptr0

    sty <.chan_idx
    asl a ; Instrument number is pre multiplied by 4
    asl a
    tay
    lda famistudio_exp_instrument_hi
    adc #0  ; Use carry to extend range for 64 instruments
    sta <.ptr+1
    lda famistudio_exp_instrument_lo
    sta <.ptr+0

    ; Volume envelope
    lda [.ptr],y
    sta famistudio_env_addr_lo,x
    iny
    lda [.ptr],y
    iny
    sta famistudio_env_addr_hi,x
    inx

    ; Arpeggio envelope
    .if FAMISTUDIO_USE_ARPEGGIO
    stx <.tmp_x
    ldx <.chan_idx
    lda famistudio_chn_env_override,x ; Check if its overriden by arpeggio.
    lsr a
    ldx <.tmp_x
    bcc .read_arpeggio_ptr
    iny ; Instrument arpeggio is overriden by arpeggio, dont touch!
    jmp .init_envelopes
    .endif

.read_arpeggio_ptr:
    lda [.ptr],y
    sta famistudio_env_addr_lo,x
    iny
    lda [.ptr],y
    sta famistudio_env_addr_hi,x
    jmp .init_envelopes

.init_envelopes:
    iny
    ; Initialize volume + arpeggio envelopes.
    lda #1
    sta famistudio_env_ptr-1,x ; Reset volume envelope pointer to 1 (volume have releases point in index 0)
    lda #0
    sta famistudio_env_repeat-1,x
    sta famistudio_env_repeat,x
    sta famistudio_env_ptr,x

    ; Pitch envelopes.
    ldx <.chan_idx
    .if FAMISTUDIO_USE_VIBRATO
    lda famistudio_chn_env_override,x ; Instrument pitch is overriden by vibrato, dont touch!
    bpl .pitch_env
    iny
    iny
    bne .pitch_overriden
    .endif

.pitch_env:
    dex
    dex ; Noise + DPCM dont have pitch envelopes
    lda #1
    sta famistudio_pitch_env_ptr,x ; Reset pitch envelope pointert to 1 (pitch envelope have relative/absolute flag in the first byte)
    lda #0
    sta famistudio_pitch_env_repeat,x
    sta famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_hi,x
    lda [.ptr],y
    sta famistudio_pitch_env_addr_lo,x
    iny
    lda [.ptr],y
    sta famistudio_pitch_env_addr_hi,x
    iny

.pitch_overriden:
    .endm

    .endif

    .if FAMISTUDIO_EXP_VRC7

;======================================================================================================================
; FAMISTUDIO_SET_VRC7_INSTRUMENT (internal)
;
; Internal function to set a VRC7 instrument for a given channel. Will load custom patch if needed.
;
; [in] x: first envelope index for this channel.
; [in] y: channel index
; [in] a: instrument index.
;======================================================================================================================

famistudio_set_vrc7_instrument:

.ptr      = famistudio_ptr0
.chan_idx = famistudio_r1

    famistudio_set_exp_instrument #0

    lda <.chan_idx
    sec
    sbc #5
    tax

    lda famistudio_chn_inst_changed,x
    beq .done

    lda [.ptr],y
    sta famistudio_chn_vrc7_patch, x
    bne .done

    .read_custom_patch:
    ldx #0
    iny
    .read_patch_loop:
        stx FAMISTUDIO_VRC7_REG_SEL
        jsr famistudio_vrc7_wait_reg_select
        lda [.ptr],y
        iny
        sta FAMISTUDIO_VRC7_REG_WRITE
        jsr famistudio_vrc7_wait_reg_write
        inx
        cpx #8
        bne .read_patch_loop

    .done:
    rts
    .endif

    .if FAMISTUDIO_EXP_FDS

;======================================================================================================================
; FAMISTUDIO_SET_FDS_INSTRUMENT (internal)
;
; Internal function to set a FDS instrument. Will upload the wave and modulation envelope if needed.
;
; [in] x: first envelope index for this channel.
; [in] y: channel index
; [in] a: instrument index.
;======================================================================================================================

famistudio_set_fds_instrument:

.ptr        = famistudio_ptr0
.wave_ptr   = famistudio_ptr1
.master_vol = famistudio_r1
.tmp_y      = famistudio_r2

    famistudio_set_exp_instrument

    lda #0
    sta FAMISTUDIO_FDS_SWEEP_BIAS

    lda famistudio_chn_inst_changed
    bne .write_fds_wave

    iny ; Skip master volume + wave + mod envelope.
    iny
    iny
    iny
    iny

    jmp .load_mod_param

    .write_fds_wave:

        lda [.ptr],y
        sta <.master_vol
        iny

        ora #$80
        sta FAMISTUDIO_FDS_VOL ; Enable wave RAM write

        ; FDS Waveform
        lda [.ptr],y
        sta <.wave_ptr+0
        iny
        lda [.ptr],y
        sta <.wave_ptr+1
        iny
        sty <.tmp_y

        ldy #0
        .wave_loop:
            lda [.wave_ptr],y
            sta FAMISTUDIO_FDS_WAV_START,y
            iny
            cpy #64
            bne .wave_loop

        lda #$80
        sta FAMISTUDIO_FDS_MOD_HI ; Need to disable modulation before writing.
        lda <.master_vol
        sta FAMISTUDIO_FDS_VOL ; Disable RAM write.
        lda #0
        sta FAMISTUDIO_FDS_SWEEP_BIAS

        ; FDS Modulation
        ldy <.tmp_y
        lda [.ptr],y
        sta <.wave_ptr+0
        iny
        lda [.ptr],y
        sta <.wave_ptr+1
        iny
        sty <.tmp_y

        ldy #0
        .mod_loop:
            lda [.wave_ptr],y
            sta FAMISTUDIO_FDS_MOD_TABLE
            iny
            cpy #32
            bne .mod_loop

        lda #0
        sta famistudio_chn_inst_changed

        ldy <.tmp_y

    .load_mod_param:

        .check_mod_speed:
            bit famistudio_fds_override_flags
            bmi .mod_speed_overriden

            .load_mod_speed:
                lda [.ptr],y
                sta famistudio_fds_mod_speed+0
                iny
                lda [.ptr],y
                sta famistudio_fds_mod_speed+1
                jmp .check_mod_depth

            .mod_speed_overriden:
                iny

        .check_mod_depth:
            iny
            bit famistudio_fds_override_flags
            bvs .mod_depth_overriden

            .load_mod_depth:
                lda [.ptr],y
                sta famistudio_fds_mod_depth

            .mod_depth_overriden:
                iny
                lda [.ptr],y
                sta famistudio_fds_mod_delay

    rts
    .endif

    .if FAMISTUDIO_EXP_N163

famistudio_n163_wave_table:
    .byte FAMISTUDIO_N163_REG_WAVE - $00
    .byte FAMISTUDIO_N163_REG_WAVE - $08
    .byte FAMISTUDIO_N163_REG_WAVE - $10
    .byte FAMISTUDIO_N163_REG_WAVE - $18
    .byte FAMISTUDIO_N163_REG_WAVE - $20
    .byte FAMISTUDIO_N163_REG_WAVE - $28
    .byte FAMISTUDIO_N163_REG_WAVE - $30
    .byte FAMISTUDIO_N163_REG_WAVE - $38

;======================================================================================================================
; FAMISTUDIO_SET_FDS_INSTRUMENT (internal)
;
; Internal function to set a N163 instrument. Will upload the waveform if needed.
;
; [in] x: first envelope index for this channel.
; [in] y: channel index
; [in] a: instrument index.
;======================================================================================================================

famistudio_set_n163_instrument:

.ptr      = famistudio_ptr0
.wave_ptr = famistudio_ptr1
.wave_len = famistudio_r0
.wave_pos = famistudio_r1
.chan_idx = famistudio_r1

    famistudio_set_exp_instrument

    ; Wave position
    lda <.chan_idx
    sec
    sbc #5
    tax

    lda famistudio_chn_inst_changed,x
    beq .done

    lda famistudio_n163_wave_table, x
    sta FAMISTUDIO_N163_ADDR
    lda [.ptr],y
    sta <.wave_pos
    sta FAMISTUDIO_N163_DATA
    iny

    ; Wave length
    lda [.ptr],y
    sta <.wave_len
    lda #$00 ; 256 - wave length
    sec
    sbc <.wave_len
    sec
    sbc <.wave_len
    sta famistudio_chn_n163_wave_len, x
    iny

    ; N163 wave pointer.
    lda [.ptr],y
    sta <.wave_ptr+0
    iny
    lda [.ptr],y
    sta <.wave_ptr+1

    ; N163 wave
    lda <.wave_pos
    ora #$80
    sta FAMISTUDIO_N163_ADDR
    ldy #0
    .wave_loop:
        lda [.wave_ptr],y
        sta FAMISTUDIO_N163_DATA
        iny
        cpy <.wave_len
        bne .wave_loop

    .done:
    rts

    .endif

; Increments 16-bit. (internal)
famistudio_inc_16 .macro ; addr
addr\@ = \1
    inc <addr\@+0
    bne .ok\@
    inc <addr\@+1
.ok\@:
    .endm

; Add 8-bit to a 16-bit (unsigned). (internal)
famistudio_add_16_8 .macro ; addr, val
addr\@ = \1
val\@ = \2
    clc
    lda #val\@
    adc <addr\@+0
    sta <addr\@+0
    bcc .ok\@
    inc <addr\@+1
.ok\@:
    .endm

;======================================================================================================================
; FAMISTUDIO_CHANNEL_UPDATE (internal)
;
; Advances the song by one frame for a given channel. If a new note or effect(s) are found, they will be processed.
;
; [in] x: channel index
;======================================================================================================================

famistudio_channel_update:

.tmp_ptr_lo           = famistudio_r0
.tmp_chan_idx         = famistudio_r0
.tmp_slide_from       = famistudio_r1
.tmp_slide_idx        = famistudio_r1
.no_attack_flag       = famistudio_r2
.slide_delta_lo       = famistudio_ptr1_hi
.channel_data_ptr     = famistudio_ptr0
.speccode_jmp_ptr = famistudio_ptr1
.tempo_env_ptr        = famistudio_ptr1
.volume_env_ptr       = famistudio_ptr1

    lda famistudio_chn_repeat,x
    beq .no_repeat
    dec famistudio_chn_repeat,x
    clc
    rts

.no_repeat:
    lda #0
    sta <.no_attack_flag
    lda famistudio_chn_ptr_lo,x
    sta <.channel_data_ptr+0
    lda famistudio_chn_ptr_hi,x
    sta <.channel_data_ptr+1
    ldy #0

.read_byte:
    lda [.channel_data_ptr],y
    famistudio_inc_16 .channel_data_ptr

.check_regular_note:
    cmp #$61
    bcs .check_special_code ; $00 to $60 are regular notes, most common case.
    jmp .regular_note

.check_special_code:
    ora #0
    bpl .check_volume_track
    jmp .special_code ; Bit 7: 0=note 1=special code

.check_volume_track:
    cmp #$70
    bcc .speccode_6x

    .if FAMISTUDIO_USE_VOLUME_TRACK
.volume_track:
    and #$0f
    asl a
    asl a
    asl a
    asl a
    sta famistudio_chn_volume_track,x
    jmp .read_byte
    .else
    brk ; If you hit this, this mean you use the volume track in your songs, but did not enable the "FAMISTUDIO_USE_VOLUME_TRACK" feature.
    .endif

.speccode_6x:
    stx <.tmp_chan_idx
    and #$0f
    tax
    lda .famistudio_spec_code_jmp_lo-1,x
    sta <.speccode_jmp_ptr+0
    lda .famistudio_spec_code_jmp_hi-1,x
    sta <.speccode_jmp_ptr+1
    ldx <.tmp_chan_idx
    jmp [.speccode_jmp_ptr]

    .if FAMISTUDIO_EXP_FDS

.speccode_fds_mod_depth:
    lda [.channel_data_ptr],y
    famistudio_inc_16 .channel_data_ptr
    sta famistudio_fds_mod_depth
    lda #$40
    ora famistudio_fds_override_flags
    sta famistudio_fds_override_flags
    jmp .read_byte

.speccode_fds_mod_speed:
    lda [.channel_data_ptr],y
    sta famistudio_fds_mod_speed+0
    iny
    lda [.channel_data_ptr],y
    sta famistudio_fds_mod_speed+1
    famistudio_add_16_8 .channel_data_ptr, #2
    lda #$80
    ora famistudio_fds_override_flags
    sta famistudio_fds_override_flags
    dey
    jmp .read_byte

    .endif

    .if FAMISTUDIO_USE_PITCH_TRACK
.speccode_fine_pitch:
    stx <.tmp_chan_idx
    lda famistudio_chan_to_pitch_env,x
    tax
    lda [.channel_data_ptr],y
    famistudio_inc_16 .channel_data_ptr
    sta famistudio_pitch_env_fine_val,x
    ldx <.tmp_chan_idx
    jmp .read_byte
    .endif

    .if FAMISTUDIO_USE_VIBRATO
.spec_code_clear_pitchovr_flag:
    lda #$7f
    and famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    jmp .read_byte

.spec_code_over_pitchenv:
    lda #$80
    ora famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    stx <.tmp_chan_idx
    lda famistudio_chan_to_pitch_env,x
    tax
    lda [.channel_data_ptr],y
    sta famistudio_pitch_env_addr_lo,x
    iny
    lda [.channel_data_ptr],y
    sta famistudio_pitch_env_addr_hi,x
    lda #0
    tay
    sta famistudio_pitch_env_repeat,x
    lda #1
    sta famistudio_pitch_env_ptr,x
    ldx <.tmp_chan_idx
    famistudio_add_16_8 .channel_data_ptr, #2
    jmp .read_byte
    .endif

    .if FAMISTUDIO_USE_ARPEGGIO
.speccode_clear_arpover_flag:
    lda #$fe
    and famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    jmp .read_byte

.speccode_override_arpenv:
    lda #$01
    ora famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    stx <.tmp_chan_idx
    lda famistudio_chan_to_arpenv,x
    tax
    lda [.channel_data_ptr],y
    sta famistudio_env_addr_lo,x
    iny
    lda [.channel_data_ptr],y
    sta famistudio_env_addr_hi,x
    lda #0
    tay
    sta famistudio_env_repeat,x ; Reset the envelope since this might be a no-attack note.
    sta famistudio_env_value,x
    sta famistudio_env_ptr,x
    ldx <.tmp_chan_idx
    famistudio_add_16_8 .channel_data_ptr, #2
    jmp .read_byte

.speccode_reset_arpeggio:
    stx <.tmp_chan_idx
    lda famistudio_chan_to_arpenv,x
    tax
    lda #0
    sta famistudio_env_repeat,x
    sta famistudio_env_value,x
    sta famistudio_env_ptr,x
    ldx <.tmp_chan_idx
    jmp .read_byte
    .endif

.speccode_disable_attack:
    lda #1
    sta <.no_attack_flag
    jmp .read_byte

    .if FAMISTUDIO_USE_SLIDE_NOTES
.speccode_slide:
    stx <.tmp_chan_idx
    lda famistudio_channel_to_slide,x
    tax
    lda [.channel_data_ptr],y ; Read slide step size
    iny
    sta famistudio_slide_step,x
    lda [.channel_data_ptr],y ; Read slide note from
    .if FAMISTUDIO_DUAL_SUPPORT
    clc
    adc famistudio_pal_adjust
    .endif
    sta <.tmp_slide_from
    iny
    lda [.channel_data_ptr],y ; Read slide note to
    ldy <.tmp_slide_from       ; reload note from
    .if FAMISTUDIO_DUAL_SUPPORT
    adc famistudio_pal_adjust
    .endif
    stx <.tmp_slide_idx ; X contained the slide index.
    tax
    .ifdef FAMISTUDIO_EXP_NOTE_START
    lda <.tmp_chan_idx
    cmp #FAMISTUDIO_EXP_NOTE_START
    bcs .note_table_expansion
    .endif
    sec ; Subtract the pitch of both notes.
    lda famistudio_note_table_lsb,y
    sbc famistudio_note_table_lsb,x
    sta <.slide_delta_lo
    lda famistudio_note_table_msb,y
    sbc famistudio_note_table_msb,x
    .ifdef FAMISTUDIO_EXP_NOTE_START
    jmp .note_table_done
.note_table_expansion:
    sec
    lda famistudio_exp_note_table_lsb,y
    sbc famistudio_exp_note_table_lsb,x
    sta <.slide_delta_lo
    lda famistudio_exp_note_table_msb,y
    sbc famistudio_exp_note_table_msb,x
.note_table_done:
    .endif
    ldx <.tmp_slide_idx ; slide index.
    sta famistudio_slide_pitch_hi,x
    .if (FAMISTUDIO_EXP_N163 != 0) | (FAMISTUDIO_EXP_VRC7 != 0)
        cpx #3 ; Slide #3 is the first of expansion slides.
        bcs .positive_shift
    .endif
    .negative_shift:
        lda <.slide_delta_lo
        asl a ; Shift-left, we have 1 bit of fractional slide.
        sta famistudio_slide_pitch_lo,x
        rol famistudio_slide_pitch_hi,x ; Shift-left, we have 1 bit of fractional slide.
    .if (FAMISTUDIO_EXP_N163 != 0) | (FAMISTUDIO_EXP_VRC7 != 0)
        jmp .shift_done
    .positive_shift:
        lda <.slide_delta_lo
        sta famistudio_slide_pitch_lo,x
        .if FAMISTUDIO_PITCH_SHIFT >= 1
            lda famistudio_slide_pitch_hi,x
            cmp #$80
            ror famistudio_slide_pitch_hi,x
            ror famistudio_slide_pitch_lo,x
        .if FAMISTUDIO_PITCH_SHIFT >= 2
            lda famistudio_slide_pitch_hi,x
            cmp #$80
            ror famistudio_slide_pitch_hi,x
            ror famistudio_slide_pitch_lo,x
        .if FAMISTUDIO_PITCH_SHIFT >= 3
            lda famistudio_slide_pitch_hi,x
            cmp #$80
            ror famistudio_slide_pitch_hi,x
            ror famistudio_slide_pitch_lo,x
        .if FAMISTUDIO_PITCH_SHIFT >= 4
            lda famistudio_slide_pitch_hi,x
            cmp #$80
            ror famistudio_slide_pitch_hi,x
            ror famistudio_slide_pitch_lo,x
        .if FAMISTUDIO_PITCH_SHIFT >= 5
            lda famistudio_slide_pitch_hi,x
            cmp #$80
            ror famistudio_slide_pitch_hi,x
            ror famistudio_slide_pitch_lo,x
        .endif
        .endif
        .endif
        .endif
        .endif
    .shift_done:
    .endif
    ldx <.tmp_chan_idx
    ldy #2
    lda [.channel_data_ptr],y ; Re-read the target note (ugly...)
    sta famistudio_chn_note,x ; Store note code
    famistudio_add_16_8 .channel_data_ptr, #3

.slide_done_pos:
    ldy #0
    jmp .sec_and_done
    .endif

.regular_note:
    sta famistudio_chn_note,x ; Store note code
    .if FAMISTUDIO_USE_SLIDE_NOTES
    ldy famistudio_channel_to_slide,x ; Clear any previous slide on new node.
    bmi .sec_and_done
    lda #0
    sta famistudio_slide_step,y
    .endif
.sec_and_done:
    lda <.no_attack_flag
    bne .no_attack
    lda famistudio_chn_note,x ; Dont trigger attack on stop notes.
    beq .no_attack
    .if FAMISTUDIO_EXP_VRC7
    cpx #5
    bcs .vrc7_channel
    sec ; New note flag is set
    jmp .done
    .vrc7_channel:
        lda #1
        sta famistudio_chn_vrc7_trigger-5,x ; Set trigger flag for VRC7
    .endif
    sec ; New note flag is set
    jmp .done
.no_attack:
    clc ; Pretend there is no new note.
    jmp .done

.special_code:
    and #$7f
    lsr a
    bcs .set_empty_rows
    asl a
    asl a
    sta famistudio_chn_instrument,x ; Store instrument number*4

    .if (FAMISTUDIO_EXP_N163 != 0) | (FAMISTUDIO_EXP_VRC7 != 0) | (FAMISTUDIO_EXP_FDS != 0)
    cpx #5
    bcc .regular_channel
        lda #1
        sta famistudio_chn_inst_changed-5, x
    .regular_channel:
    .endif
    jmp .read_byte

.set_speed:
    .if !FAMISTUDIO_USE_FT_TEMPO
    ; Load and reset the new tempo envelope.
    lda [.channel_data_ptr],y
    sta famistudio_tempo_env_ptr_lo
    sta <.tempo_env_ptr+0
    iny
    lda [.channel_data_ptr],y
    sta famistudio_tempo_env_ptr_hi
    sta <.tempo_env_ptr+1
    ldy #0
    sty famistudio_tempo_env_idx
    lda [.tempo_env_ptr],y
    sta famistudio_tempo_env_counter
    famistudio_add_16_8 .channel_data_ptr, #2
    .else
    lda [.channel_data_ptr],y
    sta famistudio_song_speed
    famistudio_inc_16 .channel_data_ptr
    .endif
    jmp .read_byte

.set_loop:
    lda [.channel_data_ptr],y
    sta <.tmp_ptr_lo
    iny
    lda [.channel_data_ptr],y
    sta <.channel_data_ptr+1
    lda <.tmp_ptr_lo
    sta <.channel_data_ptr+0
    dey
    jmp .read_byte

.set_empty_rows:
    cmp #$3d
    beq .set_speed
    cmp #$3c
    beq .release_note
    bcc .set_repeat
    cmp #$3e
    beq .set_loop

.set_reference:
    clc ; Remember return address+3
    lda <.channel_data_ptr+0
    adc #3
    sta famistudio_chn_return_lo,x
    lda <.channel_data_ptr+1
    adc #0
    sta famistudio_chn_return_hi,x
    lda [.channel_data_ptr],y ; Read length of the reference (how many rows)
    sta famistudio_chn_ref_len,x
    iny
    lda [.channel_data_ptr],y ; Read 16-bit absolute address of the reference
    sta <.tmp_ptr_lo
    iny
    lda [.channel_data_ptr],y
    sta <.channel_data_ptr+1
    lda <.tmp_ptr_lo
    sta <.channel_data_ptr+0
    ldy #0
    jmp .read_byte

.release_note:

    .if FAMISTUDIO_EXP_VRC7
    cpx #5
    bcc .apu_channel
    lda #$80
    sta famistudio_chn_vrc7_trigger-5,x ; Set release flag for VRC7
    .apu_channel:
    .endif

    stx <.tmp_chan_idx
    lda famistudio_chan_to_volenv,x ; DPCM(5) will never have releases.
    tax

    lda famistudio_env_addr_lo,x ; Load envelope data address into temp
    sta <.volume_env_ptr+0
    lda famistudio_env_addr_hi,x
    sta <.volume_env_ptr+1

    ldy #0
    lda [.volume_env_ptr],y ; Read first byte of the envelope data, this contains the release index.
    beq .env_has_no_release

    sta famistudio_env_ptr,x
    lda #0
    sta famistudio_env_repeat,x ; Need to reset envelope repeat to force update.

.env_has_no_release:
    ldx <.tmp_chan_idx
    clc
    jmp .done

.set_repeat:
    sta famistudio_chn_repeat,x ; Set up repeat counter, carry is clear, no new note

.done:
    lda famistudio_chn_ref_len,x ; Check reference row counter
    beq .no_ref                  ; If it is zero, there is no reference
    dec famistudio_chn_ref_len,x ; Decrease row counter
    bne .no_ref

    lda famistudio_chn_return_lo,x ; End of a reference, return to previous pointer
    sta famistudio_chn_ptr_lo,x
    lda famistudio_chn_return_hi,x
    sta famistudio_chn_ptr_hi,x
    rts

.no_ref:
    lda <.channel_data_ptr+0
    sta famistudio_chn_ptr_lo,x
    lda <.channel_data_ptr+1
    sta famistudio_chn_ptr_hi,x
    rts

    .if !FAMISTUDIO_USE_PITCH_TRACK
.speccode_fine_pitch:
    .endif
    .if !FAMISTUDIO_USE_VIBRATO
.spec_code_over_pitchenv:
.spec_code_clear_pitchovr_flag:
    .endif
    .if !FAMISTUDIO_USE_ARPEGGIO
.speccode_override_arpenv:
.speccode_clear_arpover_flag:
.speccode_reset_arpeggio:
    .endif
    .if !FAMISTUDIO_USE_SLIDE_NOTES
.speccode_slide:
    .endif
    ; If you hit this, this mean you either:
    ; - have fine pitches in your songs, but didnt enable "FAMISTUDIO_USE_PITCH_TRACK"
    ; - have vibrato effect in your songs, but didnt enable "FAMISTUDIO_USE_VIBRATO"
    ; - have arpeggiated chords in your songs, but didnt enable "FAMISTUDIO_USE_ARPEGGIO"
    ; - have slide notes in your songs, but didnt enable "FAMISTUDIO_USE_SLIDE_NOTES"
    brk

.famistudio_spec_code_jmp_lo:
    .byte LOW(.speccode_slide)                        ; $61
    .byte LOW(.speccode_disable_attack)               ; $62
    .byte LOW(.spec_code_over_pitchenv)      ; $63
    .byte LOW(.speccode_override_arpenv)   ; $64
    .byte LOW(.spec_code_clear_pitchovr_flag)    ; $65
    .byte LOW(.speccode_clear_arpover_flag) ; $66
    .byte LOW(.speccode_reset_arpeggio)               ; $67
    .byte LOW(.speccode_fine_pitch)                   ; $68
    .if FAMISTUDIO_EXP_FDS
    .byte LOW(.speccode_fds_mod_speed)                ; $69
    .byte LOW(.speccode_fds_mod_depth)                ; $6a
    .endif
.famistudio_spec_code_jmp_hi:
    .byte HIGH(.speccode_slide)                        ; $61
    .byte HIGH(.speccode_disable_attack)               ; $62
    .byte HIGH(.spec_code_over_pitchenv)      ; $63
    .byte HIGH(.speccode_override_arpenv)   ; $64
    .byte HIGH(.spec_code_clear_pitchovr_flag)       ; $65
    .byte HIGH(.speccode_clear_arpover_flag) ; $66
    .byte HIGH(.speccode_reset_arpeggio)               ; $67
    .byte HIGH(.speccode_fine_pitch)                   ; $68
    .if FAMISTUDIO_EXP_FDS
    .byte HIGH(.speccode_fds_mod_speed)                ; $69
    .byte HIGH(.speccode_fds_mod_depth)                ; $6a
    .endif

;======================================================================================================================
; FAMISTUDIO_SAMPLE_STOP (internal)
;
; Stop DPCM sample if it plays
;
; [in] no input params.
;======================================================================================================================

famistudio_sample_stop:

    lda #%00001111
    sta FAMISTUDIO_APU_SND_CHN
    rts


    .if FAMISTUDIO_CFG_DPCM_SUPPORT

;======================================================================================================================
; FAMISTUDIO_SAMPLE_PLAY_SFX (public)
;
; Play DPCM sample with higher priority, for sound effects
;
; [in] a: Sample index, 1...63.
;======================================================================================================================

famistudio_sfx_sample_play:

    ldx #1
    stx famistudio_dpcm_effect

sample_play:

.tmp = famistudio_r0
.sample_data_ptr = famistudio_ptr0

    sta <.tmp ; Sample number*3, offset in the sample table
    asl a
    clc
    adc <.tmp

    adc famistudio_dpcm_list_lo
    sta <.sample_data_ptr+0
    lda #0
    adc famistudio_dpcm_list_hi
    sta <.sample_data_ptr+1

    lda #%00001111 ; Stop DPCM
    sta FAMISTUDIO_APU_SND_CHN

    ldy #0
    lda [.sample_data_ptr],y ; Sample offset
    sta FAMISTUDIO_APU_DMC_START
    iny
    lda [.sample_data_ptr],y ; Sample length
    sta FAMISTUDIO_APU_DMC_LEN
    iny
    lda [.sample_data_ptr],y ; Pitch and loop
    sta FAMISTUDIO_APU_DMC_FREQ

    lda #32 ; Reset DAC counter
    sta FAMISTUDIO_APU_DMC_RAW
    lda #%00011111 ; Start DMC
    sta FAMISTUDIO_APU_SND_CHN

    rts

;======================================================================================================================
; FAMISTUDIO_SAMPLE_PLAY_MUSIC (internal)
;
; Play DPCM sample, used by music player, could be used externally. Samples played for music have lower priority than
; samples played by SFX.
;
; [in] a: Sample index, 1...63.
;======================================================================================================================

famistudio_music_sample_play:

    ldx famistudio_dpcm_effect
    beq sample_play
    tax
    lda FAMISTUDIO_APU_SND_CHN
    and #16
    beq .not_busy
    rts

.not_busy:
    sta famistudio_dpcm_effect
    txa
    jmp sample_play

    .endif

    .if FAMISTUDIO_CFG_SFX_SUPPORT

;======================================================================================================================
; FAMISTUDIO_SFX_INIT (public)
;
; Initialize the sound effect player.
;
; [in] x: Sound effect data pointer (lo)
; [in] y: Sound effect data pointer (hi)
;======================================================================================================================

famistudio_sfx_init:

.effect_list_ptr = famistudio_ptr0

    stx <.effect_list_ptr+0
    sty <.effect_list_ptr+1

    ldy #0

    .if FAMISTUDIO_DUAL_SUPPORT
    lda famistudio_pal_adjust ; Add 2 to the sound list pointer for PAL
    bne .ntsc
    iny
    iny
.ntsc:
    .endif

    lda [.effect_list_ptr],y
    sta famistudio_sfx_addr_lo
    iny
    lda [.effect_list_ptr],y
    sta famistudio_sfx_addr_hi

    ldx #FAMISTUDIO_SFX_CH0

.set_channels:
    jsr famistudio_sfx_clear_channel
    txa
    clc
    adc #FAMISTUDIO_SFX_STRUCT_SIZE
    tax
    cpx #FAMISTUDIO_SFX_STRUCT_SIZE*FAMISTUDIO_CFG_SFX_STREAMS
    bne .set_channels

    rts

;======================================================================================================================
; FAMISTUDIO_SFX_CLEAR_CHANNEL (internal)
;
; Clears output buffer of a sound effect.
;
; [in] x: Offset of the sound effect stream.
;======================================================================================================================

famistudio_sfx_clear_channel:

    lda #0
    sta famistudio_sfx_ptr_hi,x   ; This stops the effect
    sta famistudio_sfx_repeat,x
    sta famistudio_sfx_offset,x
    sta famistudio_sfx_buffer+6,x ; Mute triangle
    lda #$30
    sta famistudio_sfx_buffer+0,x ; Mute pulse1
    sta famistudio_sfx_buffer+3,x ; Mute pulse2
    sta famistudio_sfx_buffer+9,x ; Mute noise
    rts

;======================================================================================================================
; FAMISTUDIO_SFX_PLAY (public)
;
; Plays a sound effect.
;
; [in] a: Sound effect index (0...127)
; [in] x: Offset of sound effect channel, should be FAMISTUDIO_SFX_CH0..FAMISTUDIO_SFX_CH3
;======================================================================================================================

famistudio_sfx_play:

.effect_data_ptr = famistudio_ptr0

    asl a
    tay

    jsr famistudio_sfx_clear_channel ; Stops the effect if it plays

    lda famistudio_sfx_addr_lo
    sta <.effect_data_ptr+0
    lda famistudio_sfx_addr_hi
    sta <.effect_data_ptr+1

    lda [.effect_data_ptr],y
    sta famistudio_sfx_ptr_lo,x
    iny
    lda [.effect_data_ptr],y
    sta famistudio_sfx_ptr_hi,x ; This write enables the effect

    rts

;======================================================================================================================
; FAMISTUDIO_SFX_UPDATE (internal)
;
; Updates a single sound effect stream.
;
; [in] x: Offset of sound effect channel, should be FAMISTUDIO_SFX_CH0..FAMISTUDIO_SFX_CH3
;======================================================================================================================

famistudio_sfx_update:

.tmp = famistudio_r0
.effect_data_ptr = famistudio_ptr0

    lda famistudio_sfx_repeat,x ; Check if repeat counter is not zero
    beq .no_repeat
    dec famistudio_sfx_repeat,x ; Decrement and return
    bne .update_buf ; Just mix with output buffer

.no_repeat:
    lda famistudio_sfx_ptr_hi,x ; Check if MSB of the pointer is not zero
    bne .sfx_active
    rts ; Return otherwise, no active effect

.sfx_active:
    sta <.effect_data_ptr+1         ;load effect pointer into temp
    lda famistudio_sfx_ptr_lo,x
    sta <.effect_data_ptr+0
    ldy famistudio_sfx_offset,x
    clc

.read_byte:
    lda [.effect_data_ptr],y ; Read byte of effect
    bmi .get_data ; If bit 7 is set, it is a register write
    beq .eof
    iny
    sta famistudio_sfx_repeat,x ; If bit 7 is reset, it is number of repeats
    tya
    sta famistudio_sfx_offset,x
    jmp .update_buf

.get_data:
    iny
    stx <.tmp ; It is a register write
    adc <.tmp ; Get offset in the effect output buffer
    tax
    lda [.effect_data_ptr],y
    iny
    sta famistudio_sfx_buffer-128,x
    ldx <.tmp
    jmp .read_byte

.eof:
    sta famistudio_sfx_ptr_hi,x ; Mark channel as inactive

.update_buf:
    lda famistudio_output_buf ; Compare effect output buffer with main output buffer
    and #$0f ; If volume of pulse 1 of effect is higher than that of the main buffer, overwrite the main buffer value with the new one
    sta <.tmp
    lda famistudio_sfx_buffer+0,x
    and #$0f
    cmp <.tmp
    bcc .no_pulse1
    lda famistudio_sfx_buffer+0,x
    sta famistudio_output_buf+0
    lda famistudio_sfx_buffer+1,x
    sta famistudio_output_buf+1
    lda famistudio_sfx_buffer+2,x
    sta famistudio_output_buf+2

.no_pulse1:
    lda famistudio_output_buf+3
    and #$0f
    sta <.tmp
    lda famistudio_sfx_buffer+3,x
    and #$0f
    cmp <.tmp
    bcc .no_pulse2
    lda famistudio_sfx_buffer+3,x
    sta famistudio_output_buf+3
    lda famistudio_sfx_buffer+4,x
    sta famistudio_output_buf+4
    lda famistudio_sfx_buffer+5,x
    sta famistudio_output_buf+5

.no_pulse2:
    lda famistudio_sfx_buffer+6,x ; Overwrite triangle of main output buffer if it is active
    beq .no_triangle
    sta famistudio_output_buf+6
    lda famistudio_sfx_buffer+7,x
    sta famistudio_output_buf+7
    lda famistudio_sfx_buffer+8,x
    sta famistudio_output_buf+8

.no_triangle:
    lda famistudio_output_buf+9
    and #$0f
    sta <.tmp
    lda famistudio_sfx_buffer+9,x
    and #$0f
    cmp <.tmp
    bcc .no_noise
    lda famistudio_sfx_buffer+9,x
    sta famistudio_output_buf+9
    lda famistudio_sfx_buffer+10,x
    sta famistudio_output_buf+10

.no_noise:
    rts

    .endif

; Dummy envelope used to initialize all channels with silence
famistudio_dummy_envelope:
    .byte $c0,$7f,$00,$00

famistudio_dummy_pitch_env:
    .byte $00,$c0,$7f,$00,$01

; Note tables
famistudio_note_table_lsb:
    .if FAMISTUDIO_CFG_PAL_SUPPORT
        .byte $00
        .byte $68, $b6, $0e, $6f, $d9, $4b, $c6, $48, $d1, $60, $f6, $92 ; Octave 0
        .byte $34, $db, $86, $37, $ec, $a5, $62, $23, $e8, $b0, $7b, $49 ; Octave 1
        .byte $19, $ed, $c3, $9b, $75, $52, $31, $11, $f3, $d7, $bd, $a4 ; Octave 2
        .byte $8c, $76, $61, $4d, $3a, $29, $18, $08, $f9, $eb, $de, $d1 ; Octave 3
        .byte $c6, $ba, $b0, $a6, $9d, $94, $8b, $84, $7c, $75, $6e, $68 ; Octave 4
        .byte $62, $5d, $57, $52, $4e, $49, $45, $41, $3e, $3a, $37, $34 ; Octave 5
        .byte $31, $2e, $2b, $29, $26, $24, $22, $20, $1e, $1d, $1b, $19 ; Octave 6
        .byte $18, $16, $15, $14, $13, $12, $11, $10, $0f, $0e, $0d, $0c ; Octave 7
    .endif
    .if FAMISTUDIO_CFG_NTSC_SUPPORT
        .byte $00
        .byte $5b, $9c, $e6, $3b, $9a, $01, $72, $ea, $6a, $f1, $7f, $13 ; Octave 0
        .byte $ad, $4d, $f3, $9d, $4c, $00, $b8, $74, $34, $f8, $bf, $89 ; Octave 1
        .byte $56, $26, $f9, $ce, $a6, $80, $5c, $3a, $1a, $fb, $df, $c4 ; Octave 2
        .byte $ab, $93, $7c, $67, $52, $3f, $2d, $1c, $0c, $fd, $ef, $e1 ; Octave 3
        .byte $d5, $c9, $bd, $b3, $a9, $9f, $96, $8e, $86, $7e, $77, $70 ; Octave 4
        .byte $6a, $64, $5e, $59, $54, $4f, $4b, $46, $42, $3f, $3b, $38 ; Octave 5
        .byte $34, $31, $2f, $2c, $29, $27, $25, $23, $21, $1f, $1d, $1b ; Octave 6
        .byte $1a, $18, $17, $15, $14, $13, $12, $11, $10, $0f, $0e, $0d ; Octave 7
    .endif

famistudio_note_table_msb:
    .if FAMISTUDIO_CFG_PAL_SUPPORT
        .byte $00
        .byte $0c, $0b, $0b, $0a, $09, $09, $08, $08, $07, $07, $06, $06 ; Octave 0
        .byte $06, $05, $05, $05, $04, $04, $04, $04, $03, $03, $03, $03 ; Octave 1
        .byte $03, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01 ; Octave 2
        .byte $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00 ; Octave 3
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 4
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 5
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 6
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 7
    .endif
    .if FAMISTUDIO_CFG_NTSC_SUPPORT
        .byte $00
        .byte $0d, $0c, $0b, $0b, $0a, $0a, $09, $08, $08, $07, $07, $07 ; Octave 0
        .byte $06, $06, $05, $05, $05, $05, $04, $04, $04, $03, $03, $03 ; Octave 1
        .byte $03, $03, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01 ; Octave 2
        .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00 ; Octave 3
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 4
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 5
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 6
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 7
    .endif

    .if FAMISTUDIO_EXP_VRC6
    famistudio_exp_note_table_lsb:
    famistudio_saw_note_table_lsb:
        .byte $00
        .byte $44, $69, $9a, $d6, $1e, $70, $cb, $30, $9e, $13, $91, $16 ; Octave 0
        .byte $a2, $34, $cc, $6b, $0e, $b7, $65, $18, $ce, $89, $48, $0a ; Octave 1
        .byte $d0, $99, $66, $35, $07, $db, $b2, $8b, $67, $44, $23, $05 ; Octave 2
        .byte $e8, $cc, $b2, $9a, $83, $6d, $59, $45, $33, $22, $11, $02 ; Octave 3
        .byte $f3, $e6, $d9, $cc, $c1, $b6, $ac, $a2, $99, $90, $88, $80 ; Octave 4
        .byte $79, $72, $6c, $66, $60, $5b, $55, $51, $4c, $48, $44, $40 ; Octave 5
        .byte $3c, $39, $35, $32, $2f, $2d, $2a, $28, $25, $23, $21, $1f ; Octave 6
        .byte $1e, $1c, $1a, $19, $17, $16, $15, $13, $12, $11, $10, $0f ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_saw_note_table_msb:
        .byte $00
        .byte $0f, $0e, $0d, $0c, $0c, $0b, $0a, $0a, $09, $09, $08, $08 ; Octave 0
        .byte $07, $07, $06, $06, $06, $05, $05, $05, $04, $04, $04, $04 ; Octave 1
        .byte $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $02 ; Octave 2
        .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01 ; Octave 3
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 4
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 5
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 6
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 7
    .endif

    .if FAMISTUDIO_EXP_VRC7
    famistudio_exp_note_table_lsb:
    famistudio_vrc7_note_table_lsb:
        .byte $00
        .byte $ac, $b7, $c2, $cd, $d9, $e6, $f4, $02, $12, $22, $33, $46 ; Octave 0
        .byte $58, $6e, $84, $9a, $b2, $cc, $e8, $04, $24, $44, $66, $8c ; Octave 1
        .byte $b0, $dc, $08, $34, $64, $98, $d0, $08, $48, $88, $cc, $18 ; Octave 2
        .byte $60, $b8, $10, $68, $c8, $30, $a0, $10, $90, $10, $98, $30 ; Octave 3
        .byte $c0, $70, $20, $d0, $90, $60, $40, $20, $20, $20, $30, $60 ; Octave 4
        .byte $80, $e0, $40, $a0, $20, $c0, $80, $40, $40, $40, $60, $c0 ; Octave 5
        .byte $00, $c0, $80, $40, $40, $80, $00, $80, $80, $80, $c0, $80 ; Octave 6
        .byte $00, $80, $00, $80, $80, $00, $00, $00, $00, $00, $80, $00 ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_vrc7_note_table_msb:
        .byte $00
        .byte $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01 ; Octave 0
        .byte $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02 ; Octave 1
        .byte $02, $02, $03, $03, $03, $03, $03, $04, $04, $04, $04, $05 ; Octave 2
        .byte $05, $05, $06, $06, $06, $07, $07, $08, $08, $09, $09, $0a ; Octave 3
        .byte $0a, $0b, $0c, $0c, $0d, $0e, $0f, $10, $11, $12, $13, $14 ; Octave 4
        .byte $15, $16, $18, $19, $1b, $1c, $1e, $20, $22, $24, $26, $28 ; Octave 5
        .byte $2b, $2d, $30, $33, $36, $39, $3d, $40, $44, $48, $4c, $51 ; Octave 6
        .byte $56, $5b, $61, $66, $6c, $73, $7a, $81, $89, $91, $99, $a3 ; Octave 7
    .endif

    .if FAMISTUDIO_EXP_FDS
    famistudio_exp_note_table_lsb:
    famistudio_fds_note_table_lsb:
        .byte $00
        .byte $13, $14, $16, $17, $18, $1a, $1b, $1d, $1e, $20, $22, $24 ; Octave 0
        .byte $26, $29, $2b, $2e, $30, $33, $36, $39, $3d, $40, $44, $48 ; Octave 1
        .byte $4d, $51, $56, $5b, $61, $66, $6c, $73, $7a, $81, $89, $91 ; Octave 2
        .byte $99, $a2, $ac, $b6, $c1, $cd, $d9, $e6, $f3, $02, $11, $21 ; Octave 3
        .byte $33, $45, $58, $6d, $82, $99, $b2, $cb, $e7, $04, $22, $43 ; Octave 4
        .byte $65, $8a, $b0, $d9, $04, $32, $63, $97, $cd, $07, $44, $85 ; Octave 5
        .byte $ca, $13, $60, $b2, $09, $65, $c6, $2d, $9b, $0e, $89, $0b ; Octave 6
        .byte $94, $26, $c1, $64, $12, $ca, $8c, $5b, $35, $1d, $12, $16 ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_fds_note_table_msb:
        .byte $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 0
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 1
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 2
        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01 ; Octave 3
        .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02 ; Octave 4
        .byte $02, $02, $02, $02, $03, $03, $03, $03, $03, $04, $04, $04 ; Octave 5
        .byte $04, $05, $05, $05, $06, $06, $06, $07, $07, $08, $08, $09 ; Octave 6
        .byte $09, $0a, $0a, $0b, $0c, $0c, $0d, $0e, $0f, $10, $11, $12 ; Octave 7
    .endif

    .if FAMISTUDIO_EXP_N163
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 1
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $47,$4c,$50,$55,$5a,$5f,$65,$6b,$72,$78,$80,$87 ; Octave 0
        .byte $8f,$98,$a1,$aa,$b5,$bf,$cb,$d7,$e4,$f1,$00,$0f ; Octave 1
        .byte $1f,$30,$42,$55,$6a,$7f,$96,$ae,$c8,$e3,$00,$1e ; Octave 2
        .byte $3e,$60,$85,$ab,$d4,$ff,$2c,$5d,$90,$c6,$00,$3d ; Octave 3
        .byte $7d,$c1,$0a,$57,$a8,$fe,$59,$ba,$20,$8d,$00,$7a ; Octave 4
        .byte $fb,$83,$14,$ae,$50,$fd,$b3,$74,$41,$1a,$00,$f4 ; Octave 5
        .byte $f6,$07,$29,$5c,$a1,$fa,$67,$e9,$83,$35,$01,$e8 ; Octave 6
        .byte $ec,$0f,$52,$b8,$43,$f4,$ce,$d3,$06,$6a,$02,$d1 ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Octave 0
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01 ; Octave 1
        .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02 ; Octave 2
        .byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$04,$04 ; Octave 3
        .byte $04,$04,$05,$05,$05,$05,$06,$06,$07,$07,$08,$08 ; Octave 4
        .byte $08,$09,$0a,$0a,$0b,$0b,$0c,$0d,$0e,$0f,$10,$10 ; Octave 5
        .byte $11,$13,$14,$15,$16,$17,$19,$1a,$1c,$1e,$20,$21 ; Octave 6
        .byte $23,$26,$28,$2a,$2d,$2f,$32,$35,$39,$3c,$40,$43 ; Octave 7
    .endif
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 2
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $8f,$98,$a1,$aa,$b5,$bf,$cb,$d7,$e4,$f1,$00,$0f ; Octave 0
        .byte $1f,$30,$42,$55,$6a,$7f,$96,$ae,$c8,$e3,$00,$1e ; Octave 1
        .byte $3e,$60,$85,$ab,$d4,$ff,$2c,$5d,$90,$c6,$00,$3d ; Octave 2
        .byte $7d,$c1,$0a,$57,$a8,$fe,$59,$ba,$20,$8d,$00,$7a ; Octave 3
        .byte $fb,$83,$14,$ae,$50,$fd,$b3,$74,$41,$1a,$00,$f4 ; Octave 4
        .byte $f6,$07,$29,$5c,$a1,$fa,$67,$e9,$83,$35,$01,$e8 ; Octave 5
        .byte $ec,$0f,$52,$b8,$43,$f4,$ce,$d3,$06,$6a,$02,$d1 ; Octave 6
        .byte $d9,$1f,$a5,$71,$86,$e8,$9c,$a7,$0d,$d5,$05,$a2 ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01 ; Octave 0
        .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02 ; Octave 1
        .byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$04,$04 ; Octave 2
        .byte $04,$04,$05,$05,$05,$05,$06,$06,$07,$07,$08,$08 ; Octave 3
        .byte $08,$09,$0a,$0a,$0b,$0b,$0c,$0d,$0e,$0f,$10,$10 ; Octave 4
        .byte $11,$13,$14,$15,$16,$17,$19,$1a,$1c,$1e,$20,$21 ; Octave 5
        .byte $23,$26,$28,$2a,$2d,$2f,$32,$35,$39,$3c,$40,$43 ; Octave 6
        .byte $47,$4c,$50,$55,$5a,$5f,$65,$6b,$72,$78,$80,$87 ; Octave 7
    .endif
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 3
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $d7,$e4,$f1,$00,$0f,$1f,$30,$42,$56,$6a,$80,$96 ; Octave 0
        .byte $af,$c8,$e3,$00,$1f,$3f,$61,$85,$ac,$d5,$00,$2d ; Octave 1
        .byte $5e,$91,$c7,$01,$3e,$7e,$c3,$0b,$58,$aa,$00,$5b ; Octave 2
        .byte $bc,$22,$8f,$02,$7c,$fd,$86,$17,$b1,$54,$00,$b7 ; Octave 3
        .byte $78,$45,$1f,$05,$f9,$fb,$0d,$2f,$62,$a8,$01,$6e ; Octave 4
        .byte $f1,$8b,$3e,$0a,$f2,$f7,$1a,$5e,$c5,$50,$02,$dc ; Octave 5
        .byte $e3,$17,$7c,$15,$e4,$ee,$35,$bd,$8a,$a0,$04,$b9 ; Octave 6
        .byte $c6,$2e,$f8,$2a,$c9,$dc,$6a,$7a,$14,$40,$08,$73 ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01 ; Octave 0
        .byte $01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03 ; Octave 1
        .byte $03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06 ; Octave 2
        .byte $06,$07,$07,$08,$08,$08,$09,$0a,$0a,$0b,$0c,$0c ; Octave 3
        .byte $0d,$0e,$0f,$10,$10,$11,$13,$14,$15,$16,$18,$19 ; Octave 4
        .byte $1a,$1c,$1e,$20,$21,$23,$26,$28,$2a,$2d,$30,$32 ; Octave 5
        .byte $35,$39,$3c,$40,$43,$47,$4c,$50,$55,$5a,$60,$65 ; Octave 6
        .byte $6b,$72,$78,$80,$87,$8f,$98,$a1,$ab,$b5,$c0,$cb ; Octave 7
    .endif
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 4
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $1f,$30,$42,$55,$6a,$7f,$96,$ae,$c8,$e3,$00,$1e ; Octave 0
        .byte $3e,$60,$85,$ab,$d4,$ff,$2c,$5d,$90,$c6,$00,$3d ; Octave 1
        .byte $7d,$c1,$0a,$57,$a8,$fe,$59,$ba,$20,$8d,$00,$7a ; Octave 2
        .byte $fb,$83,$14,$ae,$50,$fd,$b3,$74,$41,$1a,$00,$f4 ; Octave 3
        .byte $f6,$07,$29,$5c,$a1,$fa,$67,$e9,$83,$35,$01,$e8 ; Octave 4
        .byte $ec,$0f,$52,$b8,$43,$f4,$ce,$d3,$06,$6a,$02,$d1 ; Octave 5
        .byte $d9,$1f,$a5,$71,$86,$e8,$9c,$a7,$0d,$d5,$05,$a2 ; Octave 6
        .byte $b2,$3e,$4b,$e3,$0c,$d0,$38,$4e,$1b,$ab,$ff,$ff ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02 ; Octave 0
        .byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$04,$04 ; Octave 1
        .byte $04,$04,$05,$05,$05,$05,$06,$06,$07,$07,$08,$08 ; Octave 2
        .byte $08,$09,$0a,$0a,$0b,$0b,$0c,$0d,$0e,$0f,$10,$10 ; Octave 3
        .byte $11,$13,$14,$15,$16,$17,$19,$1a,$1c,$1e,$20,$21 ; Octave 4
        .byte $23,$26,$28,$2a,$2d,$2f,$32,$35,$39,$3c,$40,$43 ; Octave 5
        .byte $47,$4c,$50,$55,$5a,$5f,$65,$6b,$72,$78,$80,$87 ; Octave 6
        .byte $8f,$98,$a1,$aa,$b5,$bf,$cb,$d7,$e4,$f1,$ff,$ff ; Octave 7
    .endif
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 5
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $67,$7c,$93,$ab,$c4,$df,$fc,$1a,$3a,$5c,$80,$a6 ; Octave 0
        .byte $ce,$f9,$26,$56,$89,$bf,$f8,$34,$74,$b8,$00,$4c ; Octave 1
        .byte $9c,$f2,$4c,$ac,$12,$7e,$f0,$69,$e9,$70,$00,$98 ; Octave 2
        .byte $39,$e4,$99,$59,$24,$fc,$e0,$d2,$d2,$e1,$00,$31 ; Octave 3
        .byte $73,$c9,$33,$b3,$49,$f8,$c0,$a4,$a4,$c2,$01,$62 ; Octave 4
        .byte $e7,$93,$67,$67,$93,$f1,$81,$48,$48,$85,$03,$c5 ; Octave 5
        .byte $cf,$26,$cf,$ce,$27,$e2,$03,$90,$91,$0b,$06,$8a ; Octave 6
        .byte $9f,$4d,$9e,$9c,$4f,$c4,$06,$ff,$ff,$ff,$ff,$ff ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02 ; Octave 0
        .byte $02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$05,$05 ; Octave 1
        .byte $05,$05,$06,$06,$07,$07,$07,$08,$08,$09,$0a,$0a ; Octave 2
        .byte $0b,$0b,$0c,$0d,$0e,$0e,$0f,$10,$11,$12,$14,$15 ; Octave 3
        .byte $16,$17,$19,$1a,$1c,$1d,$1f,$21,$23,$25,$28,$2a ; Octave 4
        .byte $2c,$2f,$32,$35,$38,$3b,$3f,$43,$47,$4b,$50,$54 ; Octave 5
        .byte $59,$5f,$64,$6a,$71,$77,$7f,$86,$8e,$97,$a0,$a9 ; Octave 6
        .byte $b3,$be,$c9,$d5,$e2,$ef,$fe,$ff,$ff,$ff,$ff,$ff ; Octave 7
    .endif
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 6
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $af,$c8,$e3,$00,$1f,$3f,$61,$85,$ac,$d5,$00,$2d ; Octave 0
        .byte $5e,$91,$c7,$01,$3e,$7e,$c3,$0b,$58,$aa,$00,$5b ; Octave 1
        .byte $bc,$22,$8f,$02,$7c,$fd,$86,$17,$b1,$54,$00,$b7 ; Octave 2
        .byte $78,$45,$1f,$05,$f9,$fb,$0d,$2f,$62,$a8,$01,$6e ; Octave 3
        .byte $f1,$8b,$3e,$0a,$f2,$f7,$1a,$5e,$c5,$50,$02,$dc ; Octave 4
        .byte $e3,$17,$7c,$15,$e4,$ee,$35,$bd,$8a,$a0,$04,$b9 ; Octave 5
        .byte $c6,$2e,$f8,$2a,$c9,$dc,$6a,$7a,$14,$40,$08,$73 ; Octave 6
        .byte $8c,$5d,$f1,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03 ; Octave 0
        .byte $03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06 ; Octave 1
        .byte $06,$07,$07,$08,$08,$08,$09,$0a,$0a,$0b,$0c,$0c ; Octave 2
        .byte $0d,$0e,$0f,$10,$10,$11,$13,$14,$15,$16,$18,$19 ; Octave 3
        .byte $1a,$1c,$1e,$20,$21,$23,$26,$28,$2a,$2d,$30,$32 ; Octave 4
        .byte $35,$39,$3c,$40,$43,$47,$4c,$50,$55,$5a,$60,$65 ; Octave 5
        .byte $6b,$72,$78,$80,$87,$8f,$98,$a1,$ab,$b5,$c0,$cb ; Octave 6
        .byte $d7,$e4,$f1,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; Octave 7
    .endif
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 7
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $f6,$14,$34,$56,$79,$9f,$c7,$f1,$1e,$4d,$80,$b5 ; Octave 0
        .byte $ed,$29,$69,$ac,$f3,$3e,$8e,$e3,$3c,$9b,$00,$6a ; Octave 1
        .byte $db,$53,$d2,$58,$e6,$7d,$1d,$c6,$79,$37,$00,$d5 ; Octave 2
        .byte $b7,$a6,$a4,$b0,$cd,$fa,$3a,$8c,$f3,$6e,$01,$ab ; Octave 3
        .byte $6f,$4d,$48,$61,$9a,$f5,$74,$19,$e6,$dd,$02,$56 ; Octave 4
        .byte $de,$9b,$91,$c3,$35,$eb,$e8,$32,$cc,$bb,$04,$ad ; Octave 5
        .byte $bc,$36,$22,$86,$6b,$d6,$d1,$64,$98,$76,$09,$5b ; Octave 6
        .byte $79,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03 ; Octave 0
        .byte $03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$07,$07 ; Octave 1
        .byte $07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0e,$0e ; Octave 2
        .byte $0f,$10,$11,$12,$13,$14,$16,$17,$18,$1a,$1c,$1d ; Octave 3
        .byte $1f,$21,$23,$25,$27,$29,$2c,$2f,$31,$34,$38,$3b ; Octave 4
        .byte $3e,$42,$46,$4a,$4f,$53,$58,$5e,$63,$69,$70,$76 ; Octave 5
        .byte $7d,$85,$8d,$95,$9e,$a7,$b1,$bc,$c7,$d3,$e0,$ed ; Octave 6
        .byte $fb,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; Octave 7
    .endif
    .if FAMISTUDIO_EXP_N163_CHN_CNT = 8
    famistudio_exp_note_table_lsb:
    famistudio_n163_note_table_lsb:
        .byte $00
        .byte $3e,$60,$85,$ab,$d4,$ff,$2c,$5d,$90,$c6,$00,$3d ; Octave 0
        .byte $7d,$c1,$0a,$57,$a8,$fe,$59,$ba,$20,$8d,$00,$7a ; Octave 1
        .byte $fb,$83,$14,$ae,$50,$fd,$b3,$74,$41,$1a,$00,$f4 ; Octave 2
        .byte $f6,$07,$29,$5c,$a1,$fa,$67,$e9,$83,$35,$01,$e8 ; Octave 3
        .byte $ec,$0f,$52,$b8,$43,$f4,$ce,$d3,$06,$6a,$02,$d1 ; Octave 4
        .byte $d9,$1f,$a5,$71,$86,$e8,$9c,$a7,$0d,$d5,$05,$a2 ; Octave 5
        .byte $b2,$3e,$4b,$e3,$0c,$d0,$38,$4e,$1b,$ab,$ff,$ff ; Octave 6
        .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; Octave 7
    famistudio_exp_note_table_msb:
    famistudio_n163_note_table_msb:
        .byte $00
        .byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$04,$04 ; Octave 0
        .byte $04,$04,$05,$05,$05,$05,$06,$06,$07,$07,$08,$08 ; Octave 1
        .byte $08,$09,$0a,$0a,$0b,$0b,$0c,$0d,$0e,$0f,$10,$10 ; Octave 2
        .byte $11,$13,$14,$15,$16,$17,$19,$1a,$1c,$1e,$20,$21 ; Octave 3
        .byte $23,$26,$28,$2a,$2d,$2f,$32,$35,$39,$3c,$40,$43 ; Octave 4
        .byte $47,$4c,$50,$55,$5a,$5f,$65,$6b,$72,$78,$80,$87 ; Octave 5
        .byte $8f,$98,$a1,$aa,$b5,$bf,$cb,$d7,$e4,$f1,$ff,$ff ; Octave 6
        .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; Octave 7
    .endif
    .endif

; For a given channel, returns the index of the volume envelope.
famistudio_chan_to_volenv:
    .byte FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .byte FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .byte FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .byte FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .byte $ff
    .ifdef FAMISTUDIO_CH5_ENVS
    .byte FAMISTUDIO_CH5_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH6_ENVS
    .byte FAMISTUDIO_CH6_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH7_ENVS
    .byte FAMISTUDIO_CH7_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH8_ENVS
    .byte FAMISTUDIO_CH8_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH9_ENVS
    .byte FAMISTUDIO_CH9_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH10_ENVS
    .byte FAMISTUDIO_CH10_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH11_ENVS
    .byte FAMISTUDIO_CH11_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif
    .ifdef FAMISTUDIO_CH12_ENVS
    .byte FAMISTUDIO_CH12_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    .endif

    .if FAMISTUDIO_USE_ARPEGGIO
; For a given channel, returns the index of the arpeggio envelope.
famistudio_chan_to_arpenv:
    .byte FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .byte FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .byte FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .byte FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .byte $ff
    .ifdef FAMISTUDIO_CH5_ENVS
    .byte FAMISTUDIO_CH5_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .ifdef FAMISTUDIO_CH6_ENVS
    .byte FAMISTUDIO_CH6_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .ifdef FAMISTUDIO_CH7_ENVS
    .byte FAMISTUDIO_CH7_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .ifdef FAMISTUDIO_CH8_ENVS
    .byte FAMISTUDIO_CH8_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .ifdef FAMISTUDIO_CH9_ENVS
    .byte FAMISTUDIO_CH9_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .ifdef FAMISTUDIO_CH10_ENVS
    .byte FAMISTUDIO_CH10_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .ifdef FAMISTUDIO_CH11_ENVS
    .byte FAMISTUDIO_CH11_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .ifdef FAMISTUDIO_CH12_ENVS
    .byte FAMISTUDIO_CH12_ENVS+FAMISTUDIO_ENV_NOTE_OFF
    .endif
    .endif

; For a given channel, returns the index of the slide/pitch envelope.
famistudio_chan_to_pitch_env:
famistudio_channel_to_slide:
    .byte $00
    .byte $01
    .byte $02
    .byte $ff ; no slide for noise
    .byte $ff ; no slide for DPCM
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 4
    .byte $03
    .endif
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 5
    .byte $04
    .endif
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 6
    .byte $05
    .endif
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 7
    .byte $06
    .endif
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 8
    .byte $07
    .endif
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 9
    .byte $08
    .endif
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 10
    .byte $09
    .endif
    .if FAMISTUDIO_NUM_PITCH_ENVELOPES >= 11
    .byte $0a
    .endif

; Duty lookup table.
famistudio_duty_lookup:
    .byte $30
    .byte $70
    .byte $b0
    .byte $f0

    .if FAMISTUDIO_EXP_VRC6
; Duty lookup table for VRC6.
famistudio_vrc6_duty_lookup:
    .byte $00
    .byte $10
    .byte $20
    .byte $30
    .byte $40
    .byte $50
    .byte $60
    .byte $70
    .endif

    .if !FAMISTUDIO_USE_FT_TEMPO
famistudio_tempo_frame_lookup:
    .byte $01, $02 ; NTSC -> NTSC, NTSC -> PAL
    .byte $00, $01 ; PAL  -> NTSC, PAL  -> PAL
    .endif

    .if FAMISTUDIO_CFG_SMOOTH_VIBRATO
; lookup table for the 2 registers we need to set for smooth vibrato.
; Index 0 decrement the hi-period, index 2 increments. Index 1 is unused.
famistudio_smooth_vibrato_period_lo_lookup:
    .byte $00, $00, $ff
famistudio_smooth_vibrato_sweep_lookup:
    .byte $8f, $00, $87
    .endif

    .if FAMISTUDIO_USE_VOLUME_TRACK

; Precomputed volume multiplication table (rounded but never to zero unless one of the value is zero).
; Load the 2 volumes in the lo/hi nibble and fetch.

famistudio_volume_table:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02
    .byte $00, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $03, $03, $03
    .byte $00, $01, $01, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $04, $04
    .byte $00, $01, $01, $01, $01, $02, $02, $02, $03, $03, $03, $04, $04, $04, $05, $05
    .byte $00, $01, $01, $01, $02, $02, $02, $03, $03, $04, $04, $04, $05, $05, $06, $06
    .byte $00, $01, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07
    .byte $00, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $08
    .byte $00, $01, $01, $02, $02, $03, $04, $04, $05, $05, $06, $07, $07, $08, $08, $09
    .byte $00, $01, $01, $02, $03, $03, $04, $05, $05, $06, $07, $07, $08, $09, $09, $0a
    .byte $00, $01, $01, $02, $03, $04, $04, $05, $06, $07, $07, $08, $09, $0a, $0a, $0b
    .byte $00, $01, $02, $02, $03, $04, $05, $06, $06, $07, $08, $09, $0a, $0a, $0b, $0c
    .byte $00, $01, $02, $03, $03, $04, $05, $06, $07, $08, $09, $0a, $0a, $0b, $0c, $0d
    .byte $00, $01, $02, $03, $04, $05, $06, $07, $07, $08, $09, $0a, $0b, $0c, $0d, $0e
    .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f

    .endif
endasm

// petris-gametheme
// ---------
asm
;this file for FamiTone2 library generated by FamiStudio

untitled_music_data:
	.db 1
	.dw .instruments
	.dw .samples-3
	.dw .song0ch0,.song0ch1,.song0ch2,.song0ch3,.song0ch4
	.db LOW(.tempo_env11), HIGH(.tempo_env11), 0, 0

.instruments:
	.dw .env4,.env2,.env0,.env3
	.dw .env1,.env0,.env5,.env3

.samples:
.env0:
	.db $c0,$7f,$00,$00
.env1:
	.db $00,$cd,$c9,$c6,$c4,$02,$c2,$03,$c0,$00,$08
.env2:
	.db $c9,$c9,$c0,$00,$02
.env3:
	.db $00,$c0,$7f,$00,$01
.env4:
	.db $00,$c1,$cd,$ca,$c8,$c6,$c3,$c2,$c1,$c0,$00,$09
.env5:
	.db $c2,$7f,$00,$00
.tempo_env11:
	.db $01,$0a,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$80

.song0ch0:
.song0ch0loop:
.ref0:
	.db $c1,$82,$29,$93,$2c,$93,$00,$93,$29,$93,$2c,$93,$00,$93,$29,$93,$29,$93,$00,$93,$2c,$93,$00,$93,$29,$93,$00,$93
.ref1:
	.db $29,$93,$2c,$93,$00,$93,$29,$93,$2c,$93,$00,$93,$29,$93,$2c,$93,$00,$93,$29,$93,$29,$93,$00,$93,$2c,$93,$00,$93,$29,$93,$00,$93
	.db $ff,$20
	.dw .ref1
	.db $ff,$20
	.dw .ref1
	.db $ff,$20
	.dw .ref1
	.db $ff,$20
	.dw .ref1
.ref2:
	.db $29,$93,$2c,$93,$00,$93,$29,$93,$2c,$93,$00,$93,$29,$93,$2c,$93,$00,$93,$29,$93,$29,$93,$00,$93,$29,$d5
	.db $fd
	.dw .song0ch0loop

.song0ch1:
.song0ch1loop:
.ref3:
	.db $f7,$f7,$ef
.ref4:
	.db $f7,$f7,$ef
.ref5:
	.db $f7,$f7,$ef
.ref6:
	.db $f7,$f7,$ef
.ref7:
	.db $f7,$f7,$ef
.ref8:
	.db $f7,$f7,$ef
.ref9:
	.db $f7,$f7,$ef
	.db $fd
	.dw .song0ch1loop

.song0ch2:
.song0ch2loop:
.ref10:
	.db $f7,$f7,$ef
.ref11:
	.db $f7,$f7,$ef
.ref12:
	.db $f7,$f7,$ef
.ref13:
	.db $f7,$f7,$ef
.ref14:
	.db $f7,$f7,$ef
.ref15:
	.db $f7,$f7,$ef
.ref16:
	.db $f7,$f7,$ef
	.db $fd
	.dw .song0ch2loop

.song0ch3:
.song0ch3loop:
.ref17:
	.db $80,$30,$93,$00,$bf,$30,$93,$00,$bf,$30,$93,$00,$bf,$30,$93,$00,$bf
.ref18:
	.db $30,$93,$00,$bf,$30,$93,$00,$bf,$30,$93,$00,$bf,$30,$93,$00,$bf
	.db $ff,$10
	.dw .ref18
	.db $ff,$10
	.dw .ref18
	.db $ff,$10
	.dw .ref18
	.db $ff,$10
	.dw .ref18
	.db $ff,$10
	.dw .ref18
	.db $fd
	.dw .song0ch3loop

.song0ch4:
.song0ch4loop:
.ref19:
	.db $f7,$f7,$ef
.ref20:
	.db $f7,$f7,$ef
.ref21:
	.db $f7,$f7,$ef
.ref22:
	.db $f7,$f7,$ef
.ref23:
	.db $f7,$f7,$ef
.ref24:
	.db $f7,$f7,$ef
.ref25:
	.db $f7,$f7,$ef
	.db $fd
	.dw .song0ch4loop

endasm
// ---------

//File footer
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

