# HDR on COSMIC (experimental) — how to build and run it

This branch is [franzjeger/cosmic-hdr-reference](https://github.com/franzjeger/cosmic-hdr-reference)
(HDR output, `wp_color_management_v1`, Wine/Proton scRGB passthrough) rebased onto current
upstream cosmic-comp, with a separate login session so the stock COSMIC session stays as a fallback.
Tracking issue: [pop-os/cosmic-comp#1384](https://github.com/pop-os/cosmic-comp/issues/1384).

> [!WARNING]
> Experimental, not reviewed upstream. It replaces the compositor for that session only, but a
> compositor bug or driver crash can still freeze your display. Keep the normal **COSMIC**
> session as your fallback: if anything goes wrong, reboot and pick it at the login screen.

## Tested setup

| | |
|---|---|
| Distro | Pop!_OS 24.04, COSMIC packages from 2026-10 |
| Kernel | 7.2.6 |
| GPU / driver | RTX 4090, NVIDIA open kernel modules 595.104.02 |
| HDR display | Samsung Odyssey Neo G9 (LS49AG95), 5120x1440, DP |
| Second display | Dell S2417DG, SDR (stays SDR, works alongside) |
| Game | Cyberpunk 2077 (heavily modded, via MO2) with GE-Proton11-11 |

Upstream base of this branch: cosmic-comp `8cb1802`, Smithay `8a27023`. The original snapshot
was validated by its author on an RTX 5090 and an AMD 680M; Intel is untested.

## 1. Get the code

Both repos must sit side by side; cosmic-comp uses `../smithay` as a path dependency.

```sh
mkdir -p ~/projects/cosmic-hdr && cd ~/projects/cosmic-hdr
git clone -b hdr https://github.com/Liquidmasl/cosmic-comp.git
git clone -b hdr https://github.com/Liquidmasl/smithay.git
```

## 2. Build dependencies

```sh
sudo apt install -y pkg-config cmake libegl1-mesa-dev libfontconfig-dev libgbm-dev \
  libinput-dev libpixman-1-dev libseat-dev libsystemd-dev libudev-dev libwayland-dev \
  libxcb1-dev libxkbcommon-dev meson ninja-build hwdata
```

Rust comes from [rustup](https://rustup.rs); the repo's `rust-toolchain.toml` pulls the right version.

**libdisplay-info 0.3**: the HDR code reads the EDID HDR static metadata through libdisplay-info
0.3, but Ubuntu 24.04 / Pop ship 0.1.1. Build 0.3 as a static library into a private prefix so
nothing on the system changes:

```sh
cd ~/projects/cosmic-hdr
git clone -b 0.3.0 https://gitlab.freedesktop.org/emersion/libdisplay-info.git
cd libdisplay-info
meson setup build --prefix="$HOME/projects/cosmic-hdr/deps" \
  -Ddefault_library=static -Db_staticpic=true --buildtype=release
ninja -C build install
```

## 3. Build the compositor

```sh
cd ~/projects/cosmic-hdr/cosmic-comp
export PKG_CONFIG_PATH="$HOME/projects/cosmic-hdr/deps/lib/x86_64-linux-gnu/pkgconfig"
cargo build --release
cargo test --release --workspace   # optional, should all pass
```

## 4. Install the extra login session

Find the connector of your HDR display:

```sh
cosmic-randr list
```

Then install (example for `DP-1`):

```sh
sudo ./hdr-session/install.sh DP-1
```

This puts the compositor in `/opt/cosmic-hdr/bin`, writes the chosen connector to
`/opt/cosmic-hdr/env`, and adds **COSMIC (HDR)** to the login screen. It works because
`cosmic-session` starts `cosmic-comp` via `PATH`; the wrapper only prepends `/opt/cosmic-hdr/bin`
and then runs the stock `start-cosmic`. No distribution file is modified.

Back up your config first, the HDR session shares it with stock COSMIC:

```sh
tar -czf ~/cosmic-config-backup.tar.gz -C ~ .config/cosmic .local/state/cosmic-comp
```

## 5. Log in and verify

Log out, pick **COSMIC (HDR)**, log in. The desktop should look the same as before (SDR content
is mapped to 203 nits), and the monitor's OSD should report HDR. Check what the compositor sees:

```sh
cat ~/.local/state/cosmic/com.system76.CosmicComp/v1/hdr_outputs
```

You want `active: true` and `capable: true` for your connector; `max_luminance` is the panel peak
from EDID.

## 6. Games (Proton)

- **Use GE-Proton**: Valve's Proton (incl. Experimental 11) ignores `PROTON_ENABLE_WAYLAND` and
  `PROTON_ENABLE_HDR`. Install [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom/releases)
  into `~/.local/share/Steam/compatibilitytools.d/`, restart Steam, and force it under
  the game's Properties → Compatibility.
- **Launch options**, keep anything already there after them:
  ```text
  PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 %command%
  ```
- Check it took effect: the game process should map `winewayland`, not `winex11`
  (`grep -o 'winewayland\|winex11' /proc/<pid>/maps | sort -u`).
- **In game** (Cyberpunk 2077): HDR mode becomes selectable. Set max brightness to the panel peak
  from step 5 (about 1000 here), paper white around 200–250. Under the Wayland driver the game may
  number your monitors differently; pick the HDR one again.
- On the monitor, use a plain HDR mode (Samsung: *HDR Standard*, or HGiG if offered) rather than
  dynamic/game tone mapping, otherwise highlights get tone-mapped twice.
- Switching an existing prefix to a different Proton build upgrades it; back up
  `steamapps/compatdata/<appid>` first if you care about what's in it.

## Undo

```sh
sudo ./hdr-session/uninstall.sh
```

If the HDR session does not come up: reboot (or switch to a text console with `Ctrl+Alt+F3`) and
choose the normal **COSMIC** session.

## Known rough edges

- Desktop SDR content is composited in 8 bit and converted to PQ at the end; not the final
  architecture (see the reference repo's README).
- The fork changes signal/shutdown handling in `src/lib.rs` for every session it runs, and has a
  couple of 10 ms polling loops. Harmless in practice so far.
- After a COSMIC update the rest of the desktop (panel, settings) moves on while this compositor
  doesn't. If the HDR session misbehaves after an update, rebase `hdr` onto the new upstream
  cosmic-comp and rebuild.
