defmodule LcdDisplay.HD44780.GPIO do
  @moduledoc """
  Knows how to commuticate with HD44780 type display using GPIO pins directly.
  Supports the 4-bit mode only.
  You can turn on/off the backlight.

  ## Usage

  ```
  config = %{
    display_name: "display 1",
    pin_rs: 2,
    pin_rw: 3,
    pin_en: 4,
    pin_d4: 23,
    pin_d5: 24,
    pin_d6: 25,
    pin_d7: 26,
    pin_led: 12,
  }

  # Start the LCD driver and get the initial display state.
  {:ok, display} = LcdDisplay.HD44780.GPIO.start(config)

  # Run a command and the display state will be updated.
  {:ok, display} = LcdDisplay.HD44780.GPIO.execute(display, {:print, "Hello world"})
  ```
  """

  use LcdDisplay.HD44780.Driver

  alias LcdDisplay.GPIO, as: ParallelBus

  @required_config_keys [
    :display_name,
    :pin_rs,
    :pin_en,
    :pin_d4,
    :pin_d5,
    :pin_d6,
    :pin_d7
  ]

  @optional_config_keys [:rows, :cols, :font_size, :pin_rw, :pin_led]

  @type display_driver :: LcdDisplay.HD44780.Driver.t()

  @typedoc """
  The configuration options.
  """
  @type config :: %{
          required(:pin_rs) => pos_integer,
          required(:pin_rw) => pos_integer,
          required(:pin_en) => pos_integer,
          required(:pin_d4) => pos_integer,
          required(:pin_d5) => pos_integer,
          required(:pin_d6) => pos_integer,
          required(:pin_d7) => pos_integer,
          required(:pin_led) => pos_integer,
          optional(:rows) => 1..4,
          optional(:cols) => 8..20,
          optional(:font_size) => pos_integer
        }

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @impl LcdDisplay.HD44780.Driver
  @spec start(config) :: {:ok, display_driver} | {:error, any}
  def start(config) do
    number_of_lines = if config[:rows] == 1, do: @number_of_lines_1, else: @number_of_lines_2
    font_size = if config[:font_size] == "5x10", do: @font_size_5x10, else: @font_size_5x8

    {:ok,
     config
     |> initial_state()
     |> set_backlight(true)
     |> initialize_display(function_set: @cmd_function_set ||| @mode_4bit ||| font_size ||| number_of_lines)}
  rescue
    e -> {:error, e.message || "Error starting #{__MODULE__}"}
  end

  @spec initial_state(config) :: display_driver | no_return
  defp initial_state(opts) do
    # Raise an error when required key is missing.
    Enum.each(@required_config_keys, &Map.fetch!(opts, &1))

    opts
    # Ensure that the datatype is map and remove garbage keys.
    |> Map.take(@required_config_keys ++ @optional_config_keys)
    |> Map.merge(%{
      driver_module: __MODULE__,
      rows: opts[:rows] || @default_rows,
      cols: opts[:cols] || @default_cols,

      # Initial values for features that we can change later.
      entry_mode: @cmd_entry_mode_set ||| @entry_left,
      display_control: @cmd_display_control ||| @display_on
    })
    |> open_gpio_pins()
  end

  # Initializes the display for 4-bit interface. See Hitachi HD44780 datasheet page 46 for details.
  @spec initialize_display(display_driver, list) :: display_driver | no_return
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

  # Setup GPIO output pins, merge the refs to the config map.
  @spec open_gpio_pins(map) :: map | no_return
  defp open_gpio_pins(config) do
    refs =
      config
      |> Enum.filter(fn {key, _} -> String.starts_with?("#{key}", "pin_") end)
      |> Enum.map(fn {pin_name, pin_number} ->
        {:ok, gpio_ref} = ParallelBus.open(pin_number, :output)
        key = String.replace("#{pin_name}", "pin", "ref") |> String.to_atom()
        {key, gpio_ref}
      end)
      |> Enum.into(%{})

    Map.merge(config, refs)
  end

  @doc """
  Executes the specified command and returns a new display state.
  """
  @impl LcdDisplay.HD44780.Driver
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
  def execute(_display, command), do: {:error, {:unsupported, command}}

  defp clear(display), do: display |> write_instruction(@cmd_clear_display) |> delay(2)

  defp home(display), do: display |> write_instruction(@cmd_return_home) |> delay(2)

  defp print(display, text) when is_binary(text) do
    # Translates a text to a charlist (list of bytes).
    text |> to_charlist() |> Enum.each(&write_data(display, &1))
    display
  end

  # Set the DDRAM address corresponding to the specified cursor position.
  @spec set_cursor(display_driver, pos_integer, pos_integer) :: display_driver
  defp set_cursor(display, row, col) when row >= 0 and col >= 0 do
    ddram_address = determine_ddram_address({row, col}, Map.take(display, [:rows, :cols]))
    write_instruction(display, @cmd_set_ddram_address ||| ddram_address)
  end

  @spec set_entry_mode_flag(display_driver, byte, boolean) :: display_driver
  defp set_entry_mode_flag(display, flag, on_off_bool) do
    entry_mode =
      if on_off_bool,
        do: display.entry_mode ||| flag,
        else: display.entry_mode &&& ~~~flag

    write_feature(%{display | entry_mode: entry_mode}, :entry_mode)
  end

  @spec set_display_control_flag(display_driver, byte, boolean) :: display_driver
  defp set_display_control_flag(display, flag, on_off_bool) do
    display_control =
      if on_off_bool,
        do: display.display_control ||| flag,
        else: display.display_control &&& ~~~flag

    write_feature(%{display | display_control: display_control}, :display_control)
  end

  # Write a feature based on the display state.
  @spec write_feature(display_driver, LcdDisplay.HD44780.Driver.feature()) :: display_driver
  defp write_feature(display, feature_key) when is_atom(feature_key) do
    display |> write_instruction(Map.fetch!(display, feature_key))
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
  @spec char(display_driver, 0..7, list(byte)) :: display_driver
  def char(display, index, bitmap) when index in 0..7 and length(bitmap) === 8 do
    write_instruction(display, @cmd_set_cgram_address ||| index <<< 3)
    for line <- bitmap, do: write_data(display, line)
    display
  end

  @spec set_backlight(display_driver, boolean) :: display_driver
  defp set_backlight(display, flag) when is_boolean(flag) do
    :ok = ParallelBus.write(display.ref_led, if(flag, do: 1, else: 0))
    display
  end

  @impl LcdDisplay.HD44780.Driver
  def write_instruction(display, byte), do: write_byte(display, byte, 0)

  @impl LcdDisplay.HD44780.Driver
  def write_data(display, byte), do: write_byte(display, byte, 1)

  @spec write_byte(display_driver, byte, 0 | 1) :: display_driver
  defp write_byte(display, byte, mode) when is_integer(byte) and byte in 0..255 and mode in 0..1 do
    <<first::4, second::4>> = <<byte>>

    display
    |> register_select(mode)
    |> delay(1)
    |> write_four_bits(first)
    |> write_four_bits(second)
  end

  @spec write_four_bits(display_driver, 0..15) :: display_driver
  defp write_four_bits(display, bits) when is_integer(bits) and bits in 0..15 do
    <<bit1::1, bit2::1, bit3::1, bit4::1>> = <<bits::4>>
    :ok = ParallelBus.write(display.ref_d4, bit4)
    :ok = ParallelBus.write(display.ref_d5, bit3)
    :ok = ParallelBus.write(display.ref_d6, bit2)
    :ok = ParallelBus.write(display.ref_d7, bit1)
    pulse_enable(display)
  end

  @spec register_select(display_driver, 0 | 1) :: display_driver
  defp register_select(display, flag) when flag in 0..1 do
    :ok = ParallelBus.write(display.ref_rs, flag)
    display
  end

  @spec enable(display_driver, 0 | 1) :: display_driver
  defp enable(display, flag) when flag in 0..1 do
    :ok = ParallelBus.write(display.ref_en, flag)
    display
  end

  @spec pulse_enable(display_driver) :: display_driver
  defp pulse_enable(display) do
    display
    |> enable(1)
    |> enable(0)
  end
end
