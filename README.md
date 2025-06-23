# Xain'd Sleena Pocket OpenFPGA Core by RndMnkIII:
[0.1.0 22/05/2026] Initial release with support for Analogizer adapter.

![Xaind Sleena](/doc/PORTADA.jpg)

Pocket port of original Xain'd Sleena MiSTer FPGA core that I created in 2022. This release includes native
support for Analogizer adapter. Refer to the Analogizer wiki for instructions about Analogizer configuration.

## ☕ Support me

If you like this project, you can support me here:

- [![Patreon](https://img.shields.io/badge/Patreon-donate-orange)](https://patreon.com/RndMnkIII)
- [![PayPal](https://img.shields.io/badge/PayPal-donate-blue)](https://paypal.me/analogizer)

## Introduction
Xain'd Sleena (ザインドスリーナ) is a two genre Platformer and side-scrolling arcade video game produced by Technos in 1986. It was licensed for release outside of Japan by Taito. In the USA, the game was published by Memetron, and the game was renamed to Solar Warrior. The European home computer ports renamed the game to Soldier of Light.

## Gameplay
![Instructions](/doc/xain_sleena_preview.JPG)
The main character, Xain, is a galactic bounty-hunter who must defeat evil forces who oppress five different planets. The player can select any order to play the various planets, so, there is no 'official' sequence of play (For the U.S. version, this game was released as 'Solar Warrior'. This version goes through a set sequence instead of having to choose planets).

Each planet is played with right horizontal and vertical scrolling, shooting enemies and dodging natural hazards. Xain can crouch, double crouch (prone), jump and double jump. In some of the planets the player will need to kill a sub-boss to resume. Certain enemies carry a powerup which changes the default laser gun into a different weapon. The different weapons which are cycled through powerups include a laser-grenade gun, a 2-way gun, a spreadfire gun and a strong bullet gun with their own respective damage and directional firing capabilities.

At the end of the planet, the player goes into battle with a boss. Once defeated, the player plants a bomb into the boss' base and has ten seconds to escape in a starship.

The next half of the planet stage is an interlude stage during which the player must battle through waves of enemy ships while heading to the next planet. After three planets there is a battle through an asteroid field and against a giant mothership.

When all five planets are liberated, the player will play the longer final stage on a gigantic metallic fortress, facing the bosses previously met on each of the five planets. Fighting bosses in this stage is optional. Halfway through the stage the player plants a bomb on the fortress core and has 60 seconds to reach the exit hangar and jump into the starship.

sources: https://en.wikipedia.org/wiki/Xain%27d_Sleena


This Analogizer core uses a configuration file to select Analogizer adapter remaining options, not based on the Pocket's menu system. It is necessary to run an external utility [Pupdate >= 4.4.0](https://github.com/mattpannella/pupdate/releases)  or [AnalogizerConfigurator >= 0.4](https://github.com/RndMnkIII/AnalogizerConfigurator/releases) to generate such a file. Once generated, you must copy the `analogizer.bin` file to the `/Assets/analogizer/common` folder on the Pocket SD card. If this folder does not exist, you must create it. Check the refered utility for the relevant options for the Analogizer adapter: SNAC controller, SNAC controller assigments (how to map physical SNAC game controllers to the Pocket openFPGA framework PAD format), Video output and Blank the Pocket Screen (On/Off).

This utility allows you to do a few things beyond the usual SNAC controller type and assignment, or video output type and blank of the Pocket screen.

### Game Controls:
This game uses Player1 controls for both P1 and P2 players. The only exception is the continue button that is Player2 Start. For ease of use I've
mapped to Player2 Start to Player1 L1 button. Can be used also Player2 Start button if you have two game controllers connected.
The R1 button shows/hides the Top 10 Ko-fi contributors (this comes from the original MiSTer development that was sponsored using Ko-fi sponsorship).

### OSD Controls:
The current release allows to adjust Horizontal/Vertical offset of the image with a range of -15/+15 units using the combination of inputs Start + Up/Down/Left/Right
and change video mode using Start + Button A press. While the OSD is show the game is paused.

* ▶Start + ⬆️: increase Vertical Offset
* ▶Start + ⬇️: decrease Vertical Offset
* ▶Start + ⬅️: increase Horizontal Offset
* ▶Start + ➡️: decrease Horizontal Offset

The OSD also shows the Analogizer settings.

The core can output RGBS, RGsB, YPbPr, Y/C and SVGA scandoubler (50% scanlines) video signals.
| Video output | Status | SOG Switch(Only R2,R3 Analogizer) |
| :----------- | :----: | :-------------------------------: |     
| RGBS         |  ✅    |     Off                           |
| RGsB         |  ✅    |     On                            |
| YPbPr        |  ✅🔹  |     On                            |
| Y/C NTSC     |  ✅    |     Off                           |
| Y/C PAL      |  ✅    |     Off                           |
| Scandoubler  |  ✅    |     Off                           |

🔹 Tested with Sony PVM-9044D

| :SNAC game controller:  | Analogizer A/B config Switch | Status |
| :---------------------- | :--------------------------- | :----: |
| DB15                    | A                            |  ✅    |
| NES                     | A                            |  ✅    |
| SNES                    | A                            |  ✅    |
| PCENGINE                | A                            |  ✅    |
| PCE MULTITAP            | A                            |  ✅    |
| PSX DS/DS2 Digital DPAD | B                            |  ✅    |
| PSX DS/DS2 Analog  DPAD | B                            |  ✅    |

The Analogizer interface allow to mix game inputs from compatible SNAC gamepads supported by Analogizer (DB15 Neogeo, NES, SNES, PCEngine, PSX) with Analogue Pocket built-in controls or from Dock USB or wireless supported controllers (Analogue support).

All Analogizer adapter versions (v1, v2 and v3) has a side slide switch labeled as 'A B' that must be configured based on the used SNAC game controller.
For example for use it with PSX Dual Shock or Dual Shock 2 native gamepad you must position the switch lever on the B side position. For the remaining
game controllers you must switch the lever on the A side position. 
Be careful when handling this switch. Use something with a thin, flat tip such as a precision screwdriver with a 2.0mm flat blade for example. Place the tip on the switch lever and press gently until it slides into the desired position:

```
     ---
   B|O  |A  A/B switch on position B
     ---   
     ---
   B|  O|A  A/B switch on position A
     ---
``` 

* **Analogizer** is responsible for generating the correct encoded Y/C signals from RGB and outputs to R,G pins of VGA port. Also redirects the CSync to VGA HSync pin.
The required external Y/C adapter that connects to VGA port is responsible for output Svideo o composite video signal using his internal electronics. Oficially
only the Mike Simone Y/C adapters (active) designs will be supported by Analogizer and will be the ones to use.
However, depending on the type of screen you have, passive Y/C adapters could work with different degrees of success.

Support native PCEngine/TurboGrafx-16 2btn, 6 btn gamepads and 5 player multitap using SNAC adapter
and PC Engine cable harness (specific for Analogizer). Many thanks to [Mike Simone](https://github.com/MikeS11/MiSTerFPGA_YC_Encoder) for his great Y/C Encoder project.

You will need to connect an active VGA to Y/C adapter to the VGA port (the 5V power is provided by VGA pin 9). I'll recomend one of these (active):
* [MiSTerAddons - Active Y/C Adapter](https://misteraddons.com/collections/parts/products/yc-active-encoder-board/)
* [MikeS11 Active VGA to Composite / S-Video](https://ultimatemister.com/product/mikes11-active-composite-svideo/)
* [Active VGA->Composite/S-Video adapter](https://antoniovillena.com/product/mikes1-vga-composite-adapter/)

Using another type of Y/C adapter not tested to be used with Analogizer will not receive official support.

## Relevant Pocket menu options: 
* __Enable Analogizer: Off, On__: if you don't enable this option all functionality related to Analogizer will be disabled.
* __Video Settings > Video Timing: 57.44Hz (Native), 60.0Hz (Standard)__: alternates between the default native video mode (intended for CRT displays) or a more convenient 60Hz mode (intended for modern displays that don't play well with odd video timings)
* __HACKS > CPU Turbo: 1.0x, 2.0x__: This tweak allows you to double the speed of the primary and secondary CPU, which results in more fluid movement in general but has some side effects, although it allows you to play the game until the end. Turn it on or off as you like during the game.

## ROM files:
You are not allowed to distribute and/or copy any rom contents related to this game using the core distribution files. You must be a legit propietary
of the hardware to use the ROM contents with this recreation. Use MRAtool to create the required `xsleenab.rom` or `xsleenaba.rom` files and place inside of `/Assets/xainsleena/common` folder.

## Acknowledgments
* __Martin Donlon__ (__@Wickerwaka__) for helping with the SDRAM controller and PLL reconfig, based on its fabulous Irem-M72 core (https://github.com/MiSTer-devel/Arcade-IremM72_MiSTer).
* __@topapate__ for his JT12 core (https://github.com/jotego/jt12).
* __marcusJordan__ for Pocket interface files from OpenGateWare project.

* To all Ko-fi contributors for supporting this project:__
LovePastrami__, __Zorro__, __Juan RA__, __Deu__, __@bdlou__, __Peter Bray__, __Nat__, __Funkycochise__, __David__, __Kevin Coleman__, __Denymetanol__, __Schermobianco__, __TontonKaloun__, __Wark91__, __Dan__, __Beaps__, __Todd Gill__, __John Stringer__, __Moi__, __Olivier Krumm__, __Raymond Bielun__, __peerlow__, __ManuelDopazoAtalaya__, __ALU_Card__.

* To all the people who with their comments have encouraged me to continue with this project.
