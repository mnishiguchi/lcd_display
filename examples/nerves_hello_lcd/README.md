# Hello LCD

This example demonstrates how to control a [Hitachi HD44780LCD](https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller) compatible display with minimal wiring.
The example demonstrates printing `"Hello world"` on an LCD display using the [LcdDisplay](https://github.com/mnishiguchi/lcd_display) library.

![nerves_hello_lcd_20201213_185620](https://user-images.githubusercontent.com/7563926/102028171-ba8a6780-3d76-11eb-94f4-f82272fc3063.gif)

## Prepare hardware

- A host machine (e.g. your laptop)
- A target board (e.g. Raspberry Pi)
- SD card
- [LCD display (16x2)](https://www.google.com/search?q=16x2+LCD+display&tbm=isch)
- [I2C interface module](https://www.google.com/search?q=16x2+LCD+display+I2C+interface)
- female to female Jumper wires

Connect:

- 5V to [5V Power](https://pinout.xyz/pinout/5v_power)
- GND to [Ground](https://pinout.xyz/pinout/ground)
- SDA to [SDA](https://pinout.xyz/pinout/pin3_gpio2)
- SCL to [SCL](https://pinout.xyz/pinout/pin5_gpio3)

[![](https://user-images.githubusercontent.com/7563926/102290618-65358e00-3f0f-11eb-9031-ecd5227af653.png)](https://pinout.xyz/)

## Burn firmware to an SD card

Set necessary environment variables. [Here is a list of target tags that Nerves supports.](https://hexdocs.pm/nerves/targets.html)

```sh
$ export WIFI_SSID=_____  # your WIFI id
$ export WIFI_PSK=______  # your WIFI password
$ export MIX_TARGET=rpi4  # your target board
```

Install dependencies.

```sh
$ mix deps.get
```

Here are some firmware-related commands.

```sh
$ mix help | grep firmware

mix burn                   # Write a firmware image to an SDCard
mix firmware               # Build a firmware bundle
mix firmware.burn          # Build a firmware bundle and write it to an SDCard
mix firmware.gen.script    # Generates a shell script for pushing firmware updates
mix firmware.image         # Create a firmware image file
mix firmware.metadata      # Print out metadata for the current firmware
mix firmware.patch         # Build a firmware patch
mix firmware.unpack        # Unpack a firmware bundle for inspection
mix upload                 # Uploads firmware to a Nerves device over SSH
```

Create firmware.

```sh
$ mix firmware
```

Insert the SD card into your host machine.

Burn the firmware to that SD card.

```
$ mix firmware.burn
```

Insert the SD card into your target board.

Power your target board on.

## Connect to your target board

Check the connection by pinging.

```
$ ping nerves.local
```

SSH into your target board, then interactive Elixir shell will start.

```sh
$ ssh nerves.local

Interactive Elixir (1.11.2) - press Ctrl+C to exit (type h() ENTER for help)
Toolshed imported. Run h(Toolshed) for more info.
RingLogger is collecting log messages from Elixir and Linux. To see the
messages, either attach the current IEx session to the logger:

  RingLogger.attach

or print the next messages in the log:

  RingLogger.next

iex(1)> RingLogger.attach
:ok
iex(2)> NervesHelloLcd.hello_i2c()
```

Run `NervesHelloLcd.hello_i2c()`, then "Hello world" text will be printed on your LCD.

## Learn more about Nerves

- Official docs: https://hexdocs.pm/nerves/getting-started.html
- Official website: https://nerves-project.org/
- Forum: https://elixirforum.com/c/nerves-forum
- Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
- Source: https://github.com/nerves-project/nerves
