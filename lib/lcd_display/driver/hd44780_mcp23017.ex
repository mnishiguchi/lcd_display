defmodule LcdDisplay.HD44780.MCP23017 do
  @moduledoc """
  Knows how to commuticate with HD44780 type display through the 16-Bit I/O Expander with Serial Interface
  [MCP23017](https://ww1.microchip.com/downloads/en/devicedoc/20001952c.pdf).
  You can turn on/off the backlight and change the LED color by switching on/off red, green and blue.

  ## Usage

  ```
  iex(2)>  Circuits.I2C.detect_devices
  Devices on I2C bus "i2c-1":
  * 32  (0x20)

  1 devices detected on 1 I2C buses
  ```

  ```
  config = %{
    display_name: "display 1", # the identifier
    i2c_bus: "i2c-1",          # I2C bus name
    i2c_address: 0x20,         # 7-bit address
    rows: 2,                   # the number of display rows
    cols: 16,                  # the number of display columns
    font_size: "5x8"           # "5x10" or "5x8"
  }

  # Start the LCD driver and get the initial display state.
  {:ok, display} = LcdDisplay.HD44780.MCP23017.start(config)

  # Run a command and the display state will be updated.
  {:ok, display} = LcdDisplay.HD44780.MCP23017.execute(display, {:print, "Hello world"})

  # Turn on/off `:red`, `:green` and `:blue` to change the backlight color.
  {:ok, display} = LcdDisplay.HD44780.MCP23017.execute(display, {:red, false})

  # Pick a random backlight color.
  {:ok, display} = LcdDisplay.HD44780.MCP23017.execute(display, :random_color)
  ```

  ## MCP23017

  ### pin assignment

  This module assumes the following pin assignment:

  #### GPIOA

  | MCP23017 | HD44780              |
  | -------  | -------------------- |
  | GPA0     | -                    |
  | GPA1     | -                    |
  | GPA2     | -                    |
  | GPA3     | -                    |
  | GPA4     | -                    |
  | GPA5     | -                    |
  | GPA6     | LED RED              |
  | GPA7     | LED GREEN            |

  #### GPIOB

  | MCP23017 | HD44780              |
  | -------  | -------------------- |
  | GPB0     | LED BLUE             |
  | GPB1     | DB7 (Data Bus 7)     |
  | GPB2     | DB6 (Data Bus 6)     |
  | GPB3     | DB5 (Data Bus 5)     |
  | GPB4     | DB4 (Data Bus 4)     |
  | GPB5     | E (Enable)           |
  | GPB6     | -                    |
  | GPB7     | RS (Register Select) |
  """

  use LcdDisplay.Driver

  alias LcdDisplay.I2C, as: SerialBus

  @default_i2c_address 0x20

  @rs_instruction 0x00
  @rs_data 0x80
  @enable_bit 0x20
  @backlight_r 0x40
  @backlight_g 0x80
  @backlight_b 0x01

  # MCP23017 registers
  @mcp23017_iodir_a 0x00
  @mcp23017_iodir_b 0x01
  @mcp23017_gpio_a 0x12
  @mcp23017_gpio_b 0x13

  @typedoc """
  The configuration options.
  """
  @type config :: %{
          optional(:rows) => String.t(),
          optional(:cols) => pos_integer,
          optional(:font_size) => pos_integer
        }

  @type rgb_key :: :red | :green | :blue

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @impl LcdDisplay.Driver
  @spec start(config) :: {:ok, LcdDisplay.Driver.t()} | {:error, any}
  def start(config) do
    number_of_lines = if config[:rows] == 1, do: @number_of_lines_1, else: @number_of_lines_2
    font_size = if config[:font_size] == "5x10", do: @font_size_5x10, else: @font_size_5x8

    {:ok,
     config
     |> initial_state()
     |> expander_write(@backlight_b)
     |> initialize_display(function_set: @cmd_function_set ||| font_size ||| number_of_lines)}
  rescue
    e -> {:error, e}
  end

  @spec initial_state(config) :: LcdDisplay.Driver.t() | no_return
  defp initial_state(opts) do
    i2c_bus = opts[:i2c_bus] || "i2c-1"
    i2c_address = opts[:i2c_address] || @default_i2c_address

    {:ok, i2c_ref} = SerialBus.open(i2c_bus)

    # Make all the pins be outputs. Please refer to MCP23017 data sheet 3.5.
    :ok = SerialBus.write(i2c_ref, i2c_address, <<@mcp23017_iodir_a, 0x00>>)
    :ok = SerialBus.write(i2c_ref, i2c_address, <<@mcp23017_iodir_b, 0x00>>)

    %{
      driver_module: __MODULE__,
      display_name: opts[:display_name] || i2c_bus,
      i2c_ref: i2c_ref,
      i2c_address: i2c_address,
      rows: opts[:rows] || @default_rows,
      cols: opts[:cols] || @default_cols,

      # Initial values for features that we can change later.
      entry_mode: @cmd_entry_mode_set ||| @entry_left,
      display_control: @cmd_display_control ||| @display_on,
      # Switch on/off the backlight
      backlight: true,
      # Configure the backlight color by combining red, green and blue.
      red: true,
      green: true,
      blue: true
    }
  end

  # Initializes the display for 4-bit interface. See Hitachi HD44780 datasheet page 46 for details.
  @spec initialize_display(LcdDisplay.Driver.t(), list) :: LcdDisplay.Driver.t() | no_return
  defp initialize_display(display, function_set: function_set) do
    display
    # Function set (8-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(1)

    # Function set (4-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x02)

    # Function set (4-bit mode; Interface is 4 bits long)
    # The number of display lines and character font cannot be changed after this point.
    |> write_instruction(function_set)
    |> write_feature(:display_control)
    |> clear()
    |> write_feature(:entry_mode)
  end

  @doc """
  Executes the specified command and returns a new display state.
  """
  @impl LcdDisplay.Driver
  def execute(display, :clear), do: {:ok, clear(display)}
  def execute(display, :home), do: {:ok, home(display)}
  def execute(display, {:print, text}), do: {:ok, print(display, text)}
  def execute(display, {:set_cursor, row, col}), do: {:ok, set_cursor(display, row, col)}
  def execute(display, {:cursor, on_off_bool}), do: {:ok, set_display_control_flag(display, @cursor_on, on_off_bool)}
  def execute(display, {:blink, on_off_bool}), do: {:ok, set_display_control_flag(display, @blink_on, on_off_bool)}
  def execute(display, {:display, on_off_bool}), do: {:ok, set_display_control_flag(display, @display_on, on_off_bool)}
  def execute(display, {:autoscroll, on_off_bool}), do: {:ok, set_entry_mode_flag(display, @autoscroll, on_off_bool)}
  def execute(display, {:text_direction, :right_to_left}), do: {:ok, set_entry_mode_flag(display, @entry_left, false)}
  def execute(display, {:text_direction, :left_to_right}), do: {:ok, set_entry_mode_flag(display, @entry_left, true)}
  def execute(display, {:scroll, cols}), do: {:ok, scroll(display, cols)}
  def execute(display, {:right, cols}), do: {:ok, right(display, cols)}
  def execute(display, {:left, cols}), do: {:ok, left(display, cols)}
  def execute(display, {:char, index, bitmap}), do: {:ok, char(display, index, bitmap)}
  def execute(display, {:backlight, on_off_bool}), do: {:ok, set_backlight(display, on_off_bool)}
  def execute(display, {:red, on_off_bool}), do: {:ok, set_led_color(display, :red, on_off_bool)}
  def execute(display, {:green, on_off_bool}), do: {:ok, set_led_color(display, :green, on_off_bool)}
  def execute(display, {:blue, on_off_bool}), do: {:ok, set_led_color(display, :blue, on_off_bool)}
  def execute(display, :random_color), do: {:ok, set_random_color(display)}
  def execute(_display, command), do: {:error, {:unsupported, command}}

  defp clear(display), do: display |> write_instruction(@cmd_clear_display) |> delay(2)

  defp home(display), do: display |> write_instruction(@cmd_return_home) |> delay(2)

  defp print(display, text) when is_binary(text) do
    # Translates a text to a charlist (list of bytes).
    text |> to_charlist() |> Enum.each(&write_data(display, &1))
    display
  end

  # Set the DDRAM address corresponding to the specified cursor position.
  @spec set_cursor(LcdDisplay.Driver.t(), pos_integer, pos_integer) :: LcdDisplay.Driver.t()
  defp set_cursor(display, row, col) when row >= 0 and col >= 0 do
    ddram_address = determine_ddram_address({row, col}, Map.take(display, [:rows, :cols]))
    write_instruction(display, @cmd_set_ddram_address ||| ddram_address)
  end

  @spec set_entry_mode_flag(LcdDisplay.Driver.t(), byte, boolean) :: LcdDisplay.Driver.t()
  defp set_entry_mode_flag(display, flag, on_off_bool) do
    entry_mode =
      if on_off_bool,
        do: display.entry_mode ||| flag,
        else: display.entry_mode &&& ~~~flag

    write_feature(%{display | entry_mode: entry_mode}, :entry_mode)
  end

  @spec set_display_control_flag(LcdDisplay.Driver.t(), byte, boolean) :: LcdDisplay.Driver.t()
  defp set_display_control_flag(display, flag, on_off_bool) do
    display_control =
      if on_off_bool,
        do: display.display_control ||| flag,
        else: display.display_control &&& ~~~flag

    write_feature(%{display | display_control: display_control}, :display_control)
  end

  # Write a feature based on the display state.
  @spec write_feature(LcdDisplay.Driver.t(), LcdDisplay.Driver.feature()) :: LcdDisplay.Driver.t()
  defp write_feature(display, feature_key) when is_atom(feature_key) do
    write_instruction(display, Map.fetch!(display, feature_key))
  end

  defp scroll(display, 0), do: display

  # Scroll the entire display left
  defp scroll(display, cols) when cols < 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display)
    scroll(display, cols + 1)
  end

  # Scroll the entire display right
  defp scroll(display, cols) when cols > 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display ||| @shift_right)
    scroll(display, cols - 1)
  end

  # Move cursor right
  defp right(display, 0), do: display

  defp right(display, cols) do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_right)
    right(display, cols - 1)
  end

  # Move cursor left
  defp left(display, 0), do: display

  defp left(display, cols) do
    write_instruction(display, @cmd_cursor_shift_control)
    left(display, cols - 1)
  end

  # Program custom character to CGRAM. We only have 8 CGRAM locations.
  @spec char(LcdDisplay.Driver.t(), 0..7, list(byte)) :: LcdDisplay.Driver.t()
  def char(display, index, bitmap) when index in 0..7 and length(bitmap) === 8 do
    write_instruction(display, @cmd_set_cgram_address ||| index <<< 3)
    for line <- bitmap, do: write_data(display, line)
    display
  end

  @spec set_backlight(LcdDisplay.Driver.t(), boolean) :: LcdDisplay.Driver.t()
  defp set_backlight(display, flag) when is_boolean(flag) do
    # Set backlight and write 0 (nothing) to trigger it.
    %{display | backlight: flag}
    |> adjust_backlight_config()
    |> expander_write(0)
  end

  @spec set_led_color(LcdDisplay.Driver.t(), rgb_key, boolean) :: LcdDisplay.Driver.t()
  defp set_led_color(display, rgb_key, on_off_bool) do
    display
    |> Map.put(rgb_key, on_off_bool)
    |> adjust_backlight_config()
    |> expander_write(0)
  end

  @spec set_random_color(LcdDisplay.Driver.t()) :: LcdDisplay.Driver.t()
  def set_random_color(display) do
    display
    |> shuffle_color()
    |> adjust_backlight_config()
    |> expander_write(0)
  end

  @spec adjust_backlight_config(LcdDisplay.Driver.t()) :: LcdDisplay.Driver.t()
  defp adjust_backlight_config(%{backlight: backlight, red: red, green: green, blue: blue} = display) do
    display
    |> Map.merge(
      # Step 1: Default to the white LED when no color is specified.
      if(!red && !green && !blue, do: %{red: true, green: true, blue: true}, else: %{})
    )
    |> Map.merge(
      # Step 2: Turn off all colors when the backlight is turned off.
      if(backlight, do: %{}, else: %{red: false, green: false, blue: false})
    )
  end

  @spec shuffle_color(LcdDisplay.Driver.t()) :: LcdDisplay.Driver.t()
  defp shuffle_color(display) do
    display
    |> Map.merge(
      ~w(red green blue)a
      |> Enum.zip(
        [[true, false, false], [true, true, false]]
        |> Enum.shuffle()
        |> Enum.at(0)
        |> Enum.shuffle()
      )
      |> Enum.into(%{})
    )
  end

  @impl LcdDisplay.Driver
  def write_instruction(display, byte), do: write_byte(display, byte, @rs_instruction)

  @impl LcdDisplay.Driver
  def write_data(display, byte), do: write_byte(display, byte, @rs_data)

  @spec write_byte(LcdDisplay.Driver.t(), byte, byte) :: LcdDisplay.Driver.t()
  defp write_byte(display, byte, rs_bit) when is_integer(byte) and is_integer(rs_bit) do
    <<high_four_bits::4, low_four_bits::4>> = <<byte>>

    display
    |> write_four_bits(high_four_bits, rs_bit)
    |> write_four_bits(low_four_bits, rs_bit)
  end

  @spec write_four_bits(LcdDisplay.Driver.t(), 0..15, byte) :: LcdDisplay.Driver.t()
  defp write_four_bits(display, four_bits, rs_bit \\ 0)
       when is_integer(four_bits) and four_bits in 0..15 and is_integer(rs_bit) do
    <<d7::1, d6::1, d5::1, d4::1>> = <<four_bits::4>>
    <<reversed_four_bits::4>> = <<d4::1, d5::1, d6::1, d7::1>>
    byte = reversed_four_bits <<< 1 ||| rs_bit

    display
    |> expander_write(byte)
    |> pulse_enable(byte)
  end

  @spec pulse_enable(LcdDisplay.Driver.t(), byte) :: LcdDisplay.Driver.t()
  defp pulse_enable(display, byte) do
    display
    |> expander_write(byte ||| @enable_bit)
    |> expander_write(byte &&& ~~~@enable_bit)
  end

  @spec expander_write(LcdDisplay.Driver.t(), byte) :: LcdDisplay.Driver.t()
  defp expander_write(display, data_byte) do
    display
    |> expander_write_gpio_a()
    |> expander_write_gpio_b(data_byte)
  end

  # G R x x x x x x
  defp expander_write_gpio_a(display) do
    %{i2c_ref: i2c_ref, i2c_address: i2c_address} = display
    %{backlight: backlight, red: r, green: g} = display

    binary_gpio_a =
      cond do
        # The backlight RGB Flags turn off the LEDs.
        !backlight -> <<@mcp23017_gpio_a, @backlight_r ||| @backlight_g>>
        !r && !g -> <<@mcp23017_gpio_a, @backlight_r ||| @backlight_g>>
        !r -> <<@mcp23017_gpio_a, @backlight_r>>
        !g -> <<@mcp23017_gpio_a, @backlight_g>>
        true -> <<@mcp23017_gpio_a, 0x00>>
      end

    :ok = SerialBus.write(i2c_ref, i2c_address, binary_gpio_a)

    display
  end

  # Rs x E D4 D5 D6 D7 B
  defp expander_write_gpio_b(display, data_byte) do
    %{i2c_ref: i2c_ref, i2c_address: i2c_address} = display
    %{backlight: backlight, blue: b} = display

    binary_gpio_b =
      cond do
        # The backlight RGB Flags turn off the LEDs.
        !backlight -> <<@mcp23017_gpio_b, data_byte ||| @backlight_b>>
        !b -> <<@mcp23017_gpio_b, data_byte ||| @backlight_b>>
        true -> <<@mcp23017_gpio_b, data_byte>>
      end

    :ok = SerialBus.write(i2c_ref, i2c_address, binary_gpio_b)

    display
  end
end
