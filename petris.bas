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
mainloop:
	gosub nmi_wait
	gosub draw
	gosub vwait_end
	gosub load_joysticks
	gosub game_step
	if countdown_step <> 0 branchto mainloop

enter_end:
	set playing 0
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

