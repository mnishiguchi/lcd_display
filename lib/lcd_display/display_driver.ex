defmodule LcdDisplay.DisplayDriver do
  @moduledoc """
  Defines a behaviour required for an LCD driver.
  """

  @type display :: map

  @type feature :: :entry_mode | :display_control

  @type command ::
          :clear
          | :home
          | {:print, String.t()}
          | {:write, charlist}
          | {:set_cursor, integer, integer}
          | {:cursor, :on | :off}
          | {:blink, :on | :off}
          | {:display, :on | :off}
          | {:autoscroll, :on | :off}
          | :entry_right_to_left
          | :entry_left_to_right
          | {:backlight, :on | :off}
          | {:scroll, integer}
          | {:left, integer}
          | {:right, integer}
          | {:char, integer, byte}

  @doc """
  Initializes the LCD driver and returns the initial display state.
  """
  @callback start(list) :: {:ok | :error, display}

  @doc """
  Stops the LCD driver.
  """
  @callback stop(display) :: :ok

  @doc """
  Executes the specified command and returns a new display state.
  """
  @callback execute(display, command()) :: {:ok | :error, display}
end
