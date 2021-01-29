defmodule LcdDisplay.DisplayController do
  @moduledoc """
  Wraps a given display driver and controls the display using that driver.
  """

  use GenServer
  require Logger

  @type display_driver :: LcdDisplay.HD44780.Driver.t()
  @type display_command :: LcdDisplay.HD44780.Driver.command()

  @doc """
  Starts a display driver process and registers the process with a composite key
  of driver module and display name.
  """
  @spec start_link(display_driver) :: {:ok, pid} | {:error, any}
  def start_link(display_driver) do
    GenServer.start_link(__MODULE__, display_driver)
  end

  @doc """
  Delegates the specified operation to the display driver, and updates the state as needed.

  ## Examples

      DisplayController.execute(pid, {:print, "Hello"})
  """
  def execute(pid, command), do: GenServer.call(pid, command)

  @impl true
  def init(display), do: {:ok, display}

  @impl true
  def handle_call(command, _from, display) do
    Logger.info(inspect(command))

    case result = execute_display_command(command, display) do
      {:ok, new_display} -> {:reply, result, Map.merge(display, new_display)}
      {:error, _} -> {:reply, result, display}
    end
  rescue
    e in FunctionClauseError -> {:reply, {:error, e}, display}
  end

  @spec execute_display_command(display_command, display_driver) :: {:ok, display_driver} | {:error, any}
  defp execute_display_command(command, display) do
    display.driver_module.execute(display, command)
  end
end
