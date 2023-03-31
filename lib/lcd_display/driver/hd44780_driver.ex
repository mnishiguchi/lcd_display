# credo:disable-for-this-file
defmodule LcdDisplay.HD44780.Driver do
  @moduledoc """
  Defines a behaviour required for an LCD driver.
  """

  @type num_rows :: 1..4
  @type num_cols :: 8..20

  @typedoc """
  Type that represents the display state.
  """
  @type t :: %{
          required(:driver_module) => atom,
          required(:rows) => num_rows,
          required(:cols) => num_cols,
          required(:entry_mode) => byte,
          required(:display_control) => byte,
          required(:backlight) => boolean,
          atom => any
        }

  @typedoc """
  Type that represents an available display feature.
  """
  @type feature :: :entry_mode | :display_control

  @typedoc """
  Type that represents a supported display command.
  Some driver modules do not support the backlight LED commands.

  | Supported Command      | Description                                                   |
  | ---------------------- | ------------------------------------------------------------- |
  | `:clear`               | Clear the display.                                            |
  | `:home`                | Move the cursor home.                                         |
  | `:print`               | Print a character or text at the current cursor.              |
  | `:set_cursor`          | Set the cursor position (row and column).                     |
  | `:cursor`              | Switch on/off the underline cursor.                           |
  | `:display`             | Switch on/off the display without losing what is on it.       |
  | `:blink`               | Switch on/off the block cursor.                               |
  | `:autoscroll`          | Make existing text shift when new text is printed.            |
  | `:text_direction`      | Make text flow left/right from the cursor.                    |
  | `:scroll`              | Scroll text left and right.                                   |
  | `:left`                | Move the cursor left.                                         |
  | `:right`               | Move the cursor right.                                        |
  | `:backlight`           | Switch on/off the backlight.                                  |
  | `:red`                 | Switch on/off the red LED.                                    |
  | `:green`               | Switch on/off the green LED.                                  |
  | `:blue`                | Switch on/off the blue LED.                                   |
  """
  @type command ::
          :clear
          | :home
          | {:print, String.t() | byte}
          | {:set_cursor, integer, integer}
          | {:cursor, boolean}
          | {:blink, boolean}
          | {:display, boolean}
          | {:autoscroll, boolean}
          | {:text_direction, :right_to_left}
          | {:text_direction, :left_to_right}
          | {:scroll, integer}
          | {:left, integer}
          | {:right, integer}
          | {:backlight, boolean}
          | {:red, boolean}
          | {:green, boolean}
          | {:blue, boolean}

  @type config :: map()

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @callback start(config) :: {:ok, t} | {:error, any}

  @doc """
  Executes the specified command and returns a new display state.
  """
  @callback execute(t, command) :: {:ok, t} | {:error, any}

  @doc """
  Sends an instruction byte to the display.
  """
  @callback write_instruction(t, byte) :: t

  @doc """
  Sends a data byte to the display.
  """
  @callback write_data(t, byte) :: t

  @doc """
  Injects the common logic for an LCD driver.
  For display flags, please refer to [HD44780 data sheet](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf).

  ## Examples

      use LcdDisplay.HD44780.Driver

  """
  defmacro __using__(_) do
    quote do
      import Bitwise
      import LcdDisplay.HD44780.Util

      @behaviour LcdDisplay.HD44780.Driver

      @default_rows 2
      @default_cols 16

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

      @spec delay(LcdDisplay.HD44780.Driver.t(), pos_integer) :: LcdDisplay.HD44780.Driver.t()
      defp delay(display, milliseconds) do
        :ok = Process.sleep(milliseconds)
        display
      end
    end
  end
end

defmodule LcdDisplay.HD44780.Stub do
  @moduledoc false

  @behaviour LcdDisplay.HD44780.Driver

  @impl true
  def start(_config) do
    {:ok, display_stub()}
  end

  @impl true
  def execute(_display, _command) do
    {:ok, display_stub()}
  end

  @impl true
  def write_data(_display, _data) do
    display_stub()
  end

  defp display_stub() do
    %{
      driver_module: LcdDisplay.MockHD44780,
      i2c_address: 39,
      i2c_ref: make_ref(),
      cols: 16,
      display_control: 12,
      entry_mode: 6,
      rows: 2,
      backlight: true
    }
  end
end
