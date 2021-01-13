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

  use Bitwise
  require Logger
  import LcdDisplay.DriverUtil
  alias LcdDisplay.GPIO, as: ParallelBus

  @behaviour LcdDisplay.Driver

  # flags for function set
  @mode_4bit 0x01
  @font_size_5x8 0x00
  @font_size_5x10 0x04
  @number_of_lines_1 0x00
  @number_of_lines_2 0x08

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

  @default_rows 2
  @default_cols 16

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
  @impl true
  @spec start(config) :: {:ok, LcdDisplay.Driver.t()} | {:error, any}
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

  @spec initial_state(config) :: LcdDisplay.Driver.t() | no_return
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
    execute(display, {:write, to_charlist(string)})
  end

  # Writes a list of integers.
  def execute(display, {:write, bytes}) when is_list(bytes) do
    Enum.each(bytes, &write_data(display, &1))
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

  def execute(display, {:backlight, false}), do: {:ok, set_backlight(display, false)}
  def execute(display, {:backlight, true}), do: {:ok, set_backlight(display, true)}

  def execute(display, {:scroll, 0}), do: {:ok, display}

  # Scroll the entire display left
  def execute(display, {:scroll, cols}) when cols < 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display)
    execute(display, {:scroll, cols + 1})
  end

  # Scroll the entire display right
  def execute(display, {:scroll, cols}) do
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

  def execute(_display, command), do: {:error, {:unsupported, command}}

  defp clear(display), do: display |> write_instruction(@cmd_clear_display) |> delay(2)

  defp home(display), do: display |> write_instruction(@cmd_return_home) |> delay(2)

  ##
  ## Low level data pushing commands
  ##

  # Set the DDRAM address corresponding to the specified cursor position.
  @spec set_cursor(LcdDisplay.Driver.t(), pos_integer, pos_integer) :: LcdDisplay.Driver.t()
  defp set_cursor(display, row, col) when row >= 0 and col >= 0 do
    ddram_address = determine_ddram_address({row, col}, Map.take(display, [:rows, :cols]))
    write_instruction(display, @cmd_set_ddram_address ||| ddram_address)
  end

  @spec set_backlight(LcdDisplay.Driver.t(), boolean) :: LcdDisplay.Driver.t()
  defp set_backlight(display, flag) when is_boolean(flag) do
    with :ok <- ParallelBus.write(display.ref_led, if(flag, do: 1, else: 0)), do: display
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

  defp write_instruction(display, byte), do: write_byte(display, byte, 0)

  defp write_data(display, byte), do: write_byte(display, byte, 1)

  @spec write_byte(LcdDisplay.Driver.t(), byte, 0 | 1) :: LcdDisplay.Driver.t()
  defp write_byte(display, byte, mode) when is_integer(byte) and byte in 0..255 and mode in 0..1 do
    <<first::4, second::4>> = <<byte>>

    display
    |> register_select(mode)
    |> delay(1)
    |> write_four_bits(first)
    |> write_four_bits(second)
  end

  @spec write_four_bits(LcdDisplay.Driver.t(), 0..15) :: LcdDisplay.Driver.t()
  defp write_four_bits(display, bits) when is_integer(bits) and bits in 0..15 do
    <<bit1::1, bit2::1, bit3::1, bit4::1>> = <<bits::4>>
    :ok = ParallelBus.write(display.ref_d4, bit4)
    :ok = ParallelBus.write(display.ref_d5, bit3)
    :ok = ParallelBus.write(display.ref_d6, bit2)
    :ok = ParallelBus.write(display.ref_d7, bit1)
    pulse_enable(display)
  end

  @spec register_select(LcdDisplay.Driver.t(), 0 | 1) :: LcdDisplay.Driver.t()
  defp register_select(display, flag) when flag in 0..1 do
    with :ok <- ParallelBus.write(display.ref_rs, flag), do: display
  end

  @spec enable(LcdDisplay.Driver.t(), 0 | 1) :: LcdDisplay.Driver.t()
  defp enable(display, flag) when flag in 0..1 do
    with :ok <- ParallelBus.write(display.ref_en, flag), do: display
  end

  @spec pulse_enable(LcdDisplay.Driver.t()) :: LcdDisplay.Driver.t()
  defp pulse_enable(display) do
    display |> enable(1) |> enable(0)
  end

  @spec delay(LcdDisplay.Driver.t(), pos_integer) :: LcdDisplay.Driver.t()
  defp delay(display, milliseconds) do
    with :ok <- Process.sleep(milliseconds), do: display
  end
end
