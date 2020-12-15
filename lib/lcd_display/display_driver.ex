defmodule LcdDisplay.DisplayDriver do
  @moduledoc """
  Defines a behaviour required for an LCD driver.
  """

  @typedoc """
  Type that represents the display state.
  """
  @type display :: %{
          required(:driver_module) => atom(),
          required(:name) => String.t(),
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
          | :entry_right_to_left
          | :entry_left_to_right
          | {:backlight, boolean()}
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
  @callback execute(display, command) :: {:ok | :error, display}
end
