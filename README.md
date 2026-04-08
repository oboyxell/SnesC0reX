# SNESC0RE X

SNESC0RE X is based on SNESCORE

## Requirements

- PS5 console (any firmware, tested up to 13.00)
- LuaC0re set up and working
- Star Wars Racer Revenge - US (CUSA03474) or EU (CUSA03492)
- If you're on latest FW you can grab the digital version from the PS Store
- Python 3 on your PC
- PC and PS5 on the same network

## How To Run

1. Build the payload:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_with_zig.ps1
python .\make_snes_lua.py
```

2. Put your SNES ROMs in:

```text
compiled\roms\
```

3. Launch the emulator:

```powershell
python .\snes_launcher.py <PS5_IP>
```

## In-Emulator Controls

- `L1 + R1 + R2 + START (Options on DualSense)` = toggle widescreen
- `L1 + DPAD DOWN + START (Options on DualSense)` = return to the game list

## TODO

Add Second Controller
Add Support for Enhancement Chips
