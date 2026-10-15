# Changes

## 0.1.0-preview.3

- Capture the presented Gamescope X11 window instead of its PipeWire source to
  avoid green preview recordings and the PipeWire buffer shutdown crash.
- Preserve existing previews when recording fails or the game exits mid-capture,
  and terminate the encoder when its capture helper closes.
- Update the recorder and rebuild its matching helper together, with backups.

## 0.1.0-preview.2

- Fix five-second video recording with the private Gamescope runtime: detect
  `gamescope.bin` and link PipeWire ports by the selected source's node ID.
- Pin bsnes v115 to its exact commit and verify the source archive SHA-256
  before extraction, patching or compilation.
- Verify BigPEmu's archive SHA-256 before extraction, in addition to the existing
  upstream size/FNV checks and installed executable SHA-256 check.

## 0.1.0-preview.1

- Omarchy shell plugin with a BareFront launcher button.
- Full first-install workflow for the supported emulator collection using Arch
  repository packages, Amiberry from AUR, and upstream application downloads.
- Application and user data stored separately from the plugin.
- Private, checksum-verified patched Gamescope and vkBasalt runtime.
- Frontend fullscreen restoration after games exit, PulseAudio for bsnes, and
  Stella's larger virtual desktop to avoid its debugger sizing assertion.

Targets Omarchy 4 on x86-64 with 1080p output. Tested on an existing installation;
fresh-machine installation and live shell-widget validation remain outstanding.
