# Petris
A NES game where you pet an adorable dog

Copyright 2020 Mark T. Tomczak, all rights reserved

Source and game released under the MIT license (see attached LICENSE file).

# Introduction

Petris is a simple 4-player game where you pet an adorable dog. To start the
game, have player 1 press "A". Players then have 20 seconds to pet the dog
where it wants to be petted.

![Petris example game, showing hands petting adorable dog](/play.png)

To pet the dog, press the controller button corresponding to the location:

* **Left** for head
* **Up** for back
* **Right** for butt
* **Down** for tummy

The highlighted blue arrow indicates where the dog wants pets. Players score 1
point for petting the right location and lose 1 point for petting another
location.

At the end of 20 seconds, the player with the most points and the dog
both win; the dog always wins because it got lots of good pets. Player 1 may
press "A" to play again.

# Development

Petris is compiled using [nesasm](https://github.com/camsaul/nesasm) (commit
229033a4b76466b447ad47704808a4d03c493cee) and
[nbasic](https://github.com/fixermark/nbasic) (commit
f0cdef7fcc12e34a4468b6d7e392dad59d634c24). Once both are installed and on your
PATH, `make` should cover you. I edited the CHR files using
[YY-CHR](https://www.romhacking.net/utilities/119/), but any CHR editor should
work fine.

Game music is in the `gametheme.fms` file, which is a FamiStudio project file (https://famistudio.org/). If changed, the music in the game can be updated as follows:

1. In FamiStudio, select Export and export as "FamiStudio Music Code"
2. The resulting file has CRLF endings. Convert to LF.
3. In `petris.bas`, replace the code between `asm` and `endasm` in the section labeled `petris-gametheme` with the contents of the exported file.
4. Run `make` to compile in the new theme song.

Pull requests are generally unlikely to be accepted (even the bugs matter in a
NES game!), but branches and fun hacks are extremely encouraged. Add features!
Make more adorable dogs! Have fun!

# Acknowledgments

Special thanks to Amanda Leight, for coming up with the original idea and for
being extremely supportive of her husband's weird hobbies.

Much appreciation to Bob Rost, author of the nbasic compiler, who's "Game
Development for the 8-bit NES" student-taught course in college was my doorway
into working with this quirky architecture. His
[resources](http://bobrost.com/nes/resources.php) list is an excellent source,
especially for nbasic itself.

Thanks to BleuBleu for creation of the [FamiStudio](https://github.com/BleuBleu/FamiStudio) framework, editing tool, and music engine.

Petris theme song is copyright 2020 Frances McCullar, used with permission.

Thanks to Frances, Ashley, and Cecilia McCullar for music assistance.
