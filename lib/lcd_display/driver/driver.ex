defmodule LcdDisplay.Driver do
  @moduledoc """
  Defines a behaviour required for an LCD driver.
  """

  @type num_rows :: 1..4
  @type num_cols :: 8..20

  @typedoc """
  Type that represents the display state.
  """
  @type t :: %{
          required(:driver_module) => atom(),
          required(:display_name) => any(),
          required(:rows) => num_rows(),
          required(:cols) => num_cols(),
          required(:entry_mode) => byte(),
          required(:display_control) => byte(),
          required(:backlight) => boolean(),
          atom() => any()
        }

  @typedoc """
  Type that represents an available display feature.
  """
  @type feature :: :entry_mode | :display_control

  @typedoc """
  Type that represents a supported display command.

  | Supported Command      | Description                                                   |
  | ---------------------- | ------------------------------------------------------------- |
  | `:clear`               | Clear the display.                                            |
  | `:home`                | Move the cursor home.                                         |
  | `:print`               | Print a text at the current cursor.                           |
  | `:set_cursor`          | Set the cursor position (row and column).                     |
  | `:cursor`              | Switch on/off the underline cursor.                           |
  | `:display`             | Switch on/off the display without losing what is on it.       |
  | `:blink`               | Switch on/off the block cursor.                               |
  | `:autoscroll`          | Make existing text shift when new text is printed.            |
  | `:backlight`           | Switch on/off the backlight.                                  |
  | `:text_direction`      | Make text flow left/right from the cursor.                    |
  | `:scroll`              | Scroll text left and right.                                   |
  | `:left`                | Move the cursor left.                                         |
  | `:right`               | Move the cursor right.                                        |
  | `:char`                | Program custom character to CGRAM.                            |
  """
  @type command ::
          :clear
          | :home
          | {:print, String.t()}
          | {:set_cursor, integer(), integer()}
          | {:cursor, boolean()}
          | {:blink, boolean()}
          | {:display, boolean()}
          | {:autoscroll, boolean()}
          | {:backlight, boolean()}
          | {:text_direction, :right_to_left}
          | {:text_direction, :left_to_right}
          | {:scroll, integer()}
          | {:left, integer()}
          | {:right, integer()}
          | {:char, integer(), byte()}

  @type config :: map()

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @callback start(config) :: {:ok, t} | {:error, any}

  @doc """
  Executes the specified command and returns a new display state.
  """
  @callback execute(t, command) :: {:ok, t} | {:error, any}
end
