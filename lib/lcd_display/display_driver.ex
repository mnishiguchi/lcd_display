defmodule LcdDisplay.DisplayDriver do
  @moduledoc """
  Defines a behaviour required for an LCD driver.
  """

  @typedoc """
  Type that represents the display state.
  """
  @type display :: %{
          required(:driver_module) => atom(),
          required(:display_name) => String.t(),
          required(:rows) => integer(),
          required(:cols) => integer(),
          required(:entry_mode) => integer(),
          required(:display_control) => integer(),
          required(:backlight) => boolean()
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
  | `:write`               | write a character (byte) at the current cursor.               |
  | `:set_cursor`          | Move the cursor to the specified position (column and row).   |
  | `:cursor`              | Switch on/off the underline cursor.                           |
  | `:display`             | Switch on/off the display.                                    |
  | `:blink`               | Switch on/off the block cursor.                               |
  | `:autoscroll`          | Automatically scroll the display when a charactor is written. |
  | `:backlight`           | Switch on/off the backlight.                                  |
  | `:entry_right_to_left` | Text is printed from right to left.                           |
  | `:entry_left_to_right` | Text is printed from left to right.                           |
  | `:scroll`              | Scroll left/right the display.                                |
  | `:left`                | Move the cursor left.                                         |
  | `:right`               | Move the cursor right.                                        |
  | `:char`                | Program custom character to CGRAM.                            |
  """
  @type command ::
          :clear
          | :home
          | {:print, String.t()}
          | {:write, charlist()}
          | {:set_cursor, integer(), integer()}
          | {:cursor, boolean()}
          | {:blink, boolean()}
          | {:display, boolean()}
          | {:autoscroll, boolean()}
          | {:backlight, boolean()}
          | :entry_right_to_left
          | :entry_left_to_right
          | {:scroll, integer()}
          | {:left, integer()}
          | {:right, integer()}
          | {:char, integer(), byte()}

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @callback start(map) :: {:ok | :error, display}

  @doc """
  Stops the LCD driver.
  """
  @callback stop(display) :: :ok

  @doc """
  Executes the specified command and returns a new display state.
  """
  @callback execute(display, command) :: {:ok, display} | {:error, any()}
end
