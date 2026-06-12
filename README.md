<a href="https://c3-lang.org">
  <img src="https://c3-lang.org/assets/logo.svg" align="right" height="100" />
</a>

**qori** is a Wayland compositor written in C3 using wlroots.

<div align="center">
  <a href="https://github.com/ManuLinares/qori/releases"><strong>Download Qori</strong></a>
</div>

## Shortcuts

| Shortcut                | Action                                 |
| ----------------------- | -------------------------------------- |
| Alt + Left Click        | Move windows                           |
| Alt + Left Double Click | Toggle maximization                    |
| Alt + Right Click       | Resize from the nearest edge or corner |
| Alt + Tab               | Cycle through windows                  |
| Logo + R                | Launch `bemenu-run`                    |

## Running (Pre-built Releases)

If you are using the [pre-built release](https://github.com/ManuLinares/qori/releases), the heavy graphics dependencies (such as `wlroots`, `wayland-server`, `libdrm`, `libdisplay-info`, `libliftoff`, `pixman`, `lcms2`, and `libxkbcommon`) are statically compiled directly into the binary. 

You only need standard hardware-level runtime libraries. On a typical Ubuntu/Debian desktop environment, these are already pre-installed. If you are starting from a minimal or server installation, you can install the runtime dependencies with:

```bash
sudo apt install libinput10 libseat1 libgbm1 libegl1 libgles2 libvulkan1 liblcms2-2 hwdata xkeyboard-config
```

## Features

<details>
<summary><b>Supported Features (Click to expand)</b></summary>

* **XDG Shell**
  * Toplevels
  * Popups
  * Maximization
  * Fullscreen
  * Minimization
* **Layer Shell**
  * Background
  * Bottom
  * Top
  * Overlay layers
* **Session Lock V1**
* **Drag and Drop**
  * Validation
  * Seat pointer drag
* **Client-requested cursor shapes**
* **Clipboard and primary selection transfers**
* **VT switching** (`Ctrl + Alt + F1-F12` or `XF86_SWITCH_VT_1-12`)
</details>

<details>
<summary><b>Unsupported Features (Click to expand)</b></summary>

* XWayland
* Multi-seat configurations
* Text input / IME protocols
* Fractional scaling
* Server-side window decorations
  * No compositor-drawn titlebars or borders
* External configuration files or window rules
  * Settings are hardcoded
* Virtual workspaces
</details>


## Dependencies

Building **qori** locally from source requires the following minimum library versions installed on your system:

* **wlroots**: `~0.21.0-dev`
* **wayland-server**: `>= 1.25.0`
* **wayland-protocols**: `>= 1.47`
* **libxkbcommon**: `>= 1.8.0`
* **pixman-1**: `>= 0.46.0`
* **libdisplay-info**: `>= 0.2.0`
* **libliftoff**: `>= 0.5.0`


## Build

```bash
c3c build -O1
# executable: build/qori
```

## Running

```bash
build/qori -s 'sfwbar & chromium --start-maximized & foot & thunar'

# Examples:
# build/qori -s "sfwbar & foot"
# build/qori -s "swaybg -i bg.png & sfwbar & foot"
```

## Dependencies

```json
"linked-libraries": [
  "wayland-server",
  "wlroots-0.21",
  "xkbcommon"
]
```
