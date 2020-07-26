default: petris.nes

petris.nes: petris.asm
	nesasm -o petris.nes petris.asm

petris.asm: petris.bas foreground.chr background.chr
	nbasic -o petris.asm petris.bas
