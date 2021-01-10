defmodule LcdDisplay.HD44780.PCF8575 do
  @moduledoc """
  Knows how to commuticate with HD44780 type display through the 16-bit I/O expander
  [PCF8575](https://www.nxp.com/docs/en/data-sheet/PCF8575.pdf).
  You can turn on/off the backlight.

  ## Usage

  ```
  iex(2)>  Circuits.I2C.detect_devices
  Devices on I2C bus "i2c-1":
  * 39  (0x27)

  1 devices detected on 1 I2C buses
  ```

  ```
  config = %{
    display_name: "display 1", # the identifier
    i2c_bus: "i2c-1",          # I2C bus name
    i2c_address: 0x27,         # 7-bit address
    rows: 2,                   # the number of display rows
    cols: 16,                  # the number of display columns
    font_size: "5x8"           # "5x10" or "5x8"
  }

  # Start the LCD driver and get the initial display state.
  {:ok, display} = LcdDisplay.HD44780.PCF8575.start(config)

  # Run a command and the display state will be updated.
  {:ok, display} = LcdDisplay.HD44780.PCF8575.execute(display, {:print, "Hello world"})
  ```

  ## PCF8575

  ### pin assignment

  This module assumes the following pin assignment:

  | PCF8575 | HD44780              |
  | ------- | -------------------- |
  | P0      | RS (Register Select) |
  | P1      | -                    |
  | P2      | E (Enable)           |
  | P3      | LED                  |
  | P4      | DB4 (Data Bus 4)     |
  | P5      | DB5 (Data Bus 5)     |
  | P6      | DB6 (Data Bus 6)     |
  | P7      | DB7 (Data Bus 7)     |
  """

  use Bitwise
  require Logger
  import LcdDisplay.DriverUtil
  alias LcdDisplay.I2C, as: SerialBus

  @behaviour LcdDisplay.Driver

  # flags for function set
  @font_size_5x10 0x04
  @font_size_5x8 0x00
  @number_of_lines_2 0x08
  @number_of_lines_1 0x00

  # commands
  @cmd_clear_display 0x01
  @cmd_return_home 0x02
  @cmd_entry_mode_set 0x04
  @cmd_display_control 0x08
  @cmd_cursor_shift_control 0x10
  @cmd_function_set 0x20
  @cmd_set_cgram_address 0x40
  @cmd_set_ddram_address 0x80

  # flags for display entry mode
  @entry_left 0x02
  @autoscroll 0x01

  # flags for display on/off control
  @display_on 0x04
  @cursor_on 0x02
  @blink_on 0x01

  # flags for display/cursor shift
  @shift_display 0x08
  @shift_right 0x04

  @default_i2c_address 0x27
  @default_rows 2
  @default_cols 16

  @rs_instruction 0x00
  @rs_data 0x01
  @enable_bit 0x04
  @backlight_on 0x08

  @typedoc """
  The configuration options.
  """
  @type config :: %{
          optional(:rows) => String.t(),
          optional(:cols) => pos_integer,
          optional(:font_size) => pos_integer
        }

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @impl true
  @spec start(config) :: {:ok, LcdDisplay.Driver.t()} | {:error, any}
  def start(config) do
    number_of_lines = if config[:rows] == 1, do: @number_of_lines_1, else: @number_of_lines_2
    font_size = if config[:font_size] == "5x10", do: @font_size_5x10, else: @font_size_5x8

    {:ok,
     config
     |> initial_state()
     |> expander_write(@backlight_on)
     |> initialize_display(function_set: @cmd_function_set ||| font_size ||| number_of_lines)}
  rescue
    e -> {:error, e}
  end

  @spec initial_state(config) :: LcdDisplay.Driver.t() | no_return
  defp initial_state(opts) do
    i2c_bus = opts[:i2c_bus] || "i2c-1"
    {:ok, i2c_ref} = SerialBus.open(i2c_bus)

    %{
      driver_module: __MODULE__,
      display_name: opts[:display_name] || i2c_bus,
      i2c_ref: i2c_ref,
      i2c_address: opts[:i2c_address] || @default_i2c_address,
      rows: opts[:rows] || @default_rows,
      cols: opts[:cols] || @default_cols,

      # Initial values for features that we can change later.
      entry_mode: @cmd_entry_mode_set ||| @entry_left,
      display_control: @cmd_display_control ||| @display_on,
      backlight: true
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
  @impl true
  def execute(display, :clear) do
    clear(display)
    {:ok, display}
  end

  def execute(display, :home) do
    home(display)
    {:ok, display}
  end

  def execute(display, {:print, string}) when is_binary(string) do
    # Translates a string to a charlist (list of bytes).
    string |> to_charlist() |> Enum.each(&write_data(display, &1))
    {:ok, display}
  end

  def execute(display, {:set_cursor, row, col}) do
    {:ok, set_cursor(display, row, col)}
  end

  def execute(display, {:cursor, false}) do
    {:ok, disable_display_control_flag(display, @cursor_on)}
  end

  def execute(display, {:cursor, true}) do
    {:ok, enable_display_control_flag(display, @cursor_on)}
  end

  def execute(display, {:blink, false}) do
    {:ok, disable_display_control_flag(display, @blink_on)}
  end

  def execute(display, {:blink, true}) do
    {:ok, enable_display_control_flag(display, @blink_on)}
  end

  def execute(display, {:display, false}) do
    {:ok, disable_display_control_flag(display, @display_on)}
  end

  def execute(display, {:display, true}) do
    {:ok, enable_display_control_flag(display, @display_on)}
  end

  def execute(display, {:autoscroll, false}) do
    {:ok, disable_entry_mode_flag(display, @autoscroll)}
  end

  def execute(display, {:autoscroll, true}) do
    {:ok, enable_entry_mode_flag(display, @autoscroll)}
  end

  def execute(display, {:text_direction, :right_to_left}) do
    {:ok, disable_entry_mode_flag(display, @entry_left)}
  end

  def execute(display, {:text_direction, :left_to_right}) do
    {:ok, enable_entry_mode_flag(display, @entry_left)}
  end

  def execute(display, {:scroll, 0}), do: {:ok, display}

  # Scroll the entire display left
  def execute(display, {:scroll, cols}) when cols < 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display)
    execute(display, {:scroll, cols + 1})
  end

  # Scroll the entire display right
  def execute(display, {:scroll, cols}) when cols > 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display ||| @shift_right)
    execute(display, {:scroll, cols - 1})
  end

  # Move cursor right
  def execute(display, {:right, 0}), do: {:ok, display}

  def execute(display, {:right, cols}) do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_right)
    execute(display, {:right, cols - 1})
  end

  # Move cursor left
  def execute(display, {:left, 0}), do: {:ok, display}

  def execute(display, {:left, cols}) do
    write_instruction(display, @cmd_cursor_shift_control)
    execute(display, {:left, cols - 1})
  end

  # Program custom character to CGRAM. We only have 8 CGRAM locations.
  def execute(display, {:char, index, bitmap}) when index in 0..7 and length(bitmap) === 8 do
    write_instruction(display, @cmd_set_cgram_address ||| index <<< 3)
    for line <- bitmap, do: write_data(display, line)
    {:ok, display}
  end

  def execute(display, {:backlight, false}), do: {:ok, set_backlight(display, false)}
  def execute(display, {:backlight, true}), do: {:ok, set_backlight(display, true)}

  def execute(_display, command), do: {:error, {:unsupported, command}}

  ##
  ## Private utilities
  ##

  defp clear(display), do: display |> write_instruction(@cmd_clear_display) |> delay(2)

  defp home(display), do: display |> write_instruction(@cmd_return_home) |> delay(2)

  # Set the DDRAM address corresponding to the specified cursor position.
  @spec set_cursor(LcdDisplay.Driver.t(), pos_integer, pos_integer) :: LcdDisplay.Driver.t()
  defp set_cursor(display, row, col) when row >= 0 and col >= 0 do
    ddram_address = determine_ddram_address({row, col}, Map.take(display, [:rows, :cols]))
    write_instruction(display, @cmd_set_ddram_address ||| ddram_address)
  end

  @spec set_backlight(LcdDisplay.Driver.t(), boolean) :: LcdDisplay.Driver.t()
  defp set_backlight(display, flag) when is_boolean(flag) do
    # Set backlight and write 0 (nothing) to trigger it.
    %{display | backlight: flag} |> expander_write(0)
  end

  @spec disable_entry_mode_flag(LcdDisplay.Driver.t(), byte) :: LcdDisplay.Driver.t()
  defp disable_entry_mode_flag(display, flag) do
    entry_mode = display.entry_mode &&& ~~~flag
    %{display | entry_mode: entry_mode} |> write_feature(:entry_mode)
  end

  @spec enable_entry_mode_flag(LcdDisplay.Driver.t(), byte) :: LcdDisplay.Driver.t()
  defp enable_entry_mode_flag(display, flag) do
    entry_mode = display.entry_mode ||| flag
    %{display | entry_mode: entry_mode} |> write_feature(:entry_mode)
  end

  @spec disable_display_control_flag(LcdDisplay.Driver.t(), byte) :: LcdDisplay.Driver.t()
  defp disable_display_control_flag(display, flag) do
    display_control = display.display_control &&& ~~~flag
    %{display | display_control: display_control} |> write_feature(:display_control)
  end

  @spec enable_display_control_flag(LcdDisplay.Driver.t(), byte) :: LcdDisplay.Driver.t()
  defp enable_display_control_flag(display, flag) do
    display_control = display.display_control ||| flag
    %{display | display_control: display_control} |> write_feature(:display_control)
  end

  # Write a feature based on the display state.
  @spec write_feature(LcdDisplay.Driver.t(), LcdDisplay.Driver.feature()) :: LcdDisplay.Driver.t()
  defp write_feature(display, feature_key) when is_atom(feature_key) do
    display |> write_instruction(Map.fetch!(display, feature_key))
  end

  @spec delay(LcdDisplay.Driver.t(), pos_integer) :: LcdDisplay.Driver.t()
  defp delay(display, milliseconds) do
    with :ok <- Process.sleep(milliseconds), do: display
  end

  ##
  ## Low level data pushing commands
  ##

  defp write_instruction(display, byte), do: write_byte(display, byte, @rs_instruction)
  defp write_data(display, byte), do: write_byte(display, byte, @rs_data)

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
    byte = four_bits <<< 4 ||| rs_bit

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
  defp expander_write(%{i2c_ref: i2c_ref, i2c_address: i2c_address, backlight: backlight} = display, byte)
       when is_reference(i2c_ref) and is_integer(i2c_address) and is_boolean(backlight) and is_integer(byte) do
    data =
      if backlight,
        do: <<byte ||| @backlight_on>>,
        else: <<byte>>

    # <<data_body>> = data
    # Logger.info("[#{__MODULE__}.expander_write] #{data_body |> Integer.to_string(2) |> String.pad_leading(8, "0")}")

    :ok = SerialBus.write(i2c_ref, i2c_address, data)
    display
  end
end
