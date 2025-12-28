# LcdDisplay

[![Hex.pm](https://img.shields.io/hexpm/v/lcd_display.svg)](https://hex.pm/packages/lcd_display)
[![API docs](https://img.shields.io/hexpm/v/lcd_display.svg?label=docs)](https://hexdocs.pm/lcd_display/LcdDisplay.html)
![CI](https://github.com/mnishiguchi/lcd_display/workflows/CI/badge.svg)

Elixir drivers for common LCD modules, intended for Linux SBCs and Nerves-based systems.

<p align="center">
  <img src="https://user-images.githubusercontent.com/7563926/102028171-ba8a6780-3d76-11eb-94f4-f82272fc3063.gif" alt="nerves_hello_lcd_20201213_185620" width="320">
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/57df0599-8d4c-42ba-9a08-b24ecd115ec1" alt="piyopiyo.ex" width="320">
</p>

## Supported display types

### Character LCD

HD44780-compatible character displays (e.g. 16x2, 20x4).

- Text-based output
- GPIO or I/O expanders (I2C / SPI backpacks)
- Typical use: status displays, simple menus

→ [Character LCD documentation](lib/lcd_display/character_lcd/README.md)

### Graphic LCD

Pixel-addressable LCD panels driven over SPI.

- Full-frame pixel rendering
- Typical use: images, custom UI, framebuffers

Supported panels:
- `LcdDisplay.ILI9486`
- `LcdDisplay.ST7796`

→ [Graphic LCD documentation](lib/lcd_display/graphic_lcd/README.md)

## Installation

You can install `LcdDisplay` by adding `lcd_display` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lcd_display, "~> 0.3"}
  ]
end
```
