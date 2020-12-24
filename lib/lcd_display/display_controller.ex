defmodule LcdDisplay.DisplayController do
  @moduledoc """
  Wraps a given display driver and controls the display using that driver.
  """

  use GenServer
  require Logger

  def child_spec(%{display_name: display_name} = initial_display) do
    %{
      id: {__MODULE__, display_name},
      start: {__MODULE__, :start_link, [initial_display]}
    }
  end

  defp via_tuple({driver_module, _display_name} = key)
       when is_tuple(key) and is_atom(driver_module) do
    LcdDisplay.ProcessRegistry.via_tuple({__MODULE__, key})
  end

  @doc """
  Discovers a process by the composite key of driver module atom and display name.
  """
  def whereis({driver_module, _display_name} = key)
      when is_tuple(key) and is_atom(driver_module) do
    case LcdDisplay.ProcessRegistry.whereis_name({__MODULE__, key}) do
      :undefined -> nil
      pid -> pid
    end
  end

  @doc """
  Starts a display driver process and registers the process with a composite key
  of driver module and display name.
  """
  def start_link(%{driver_module: driver_module, display_name: display_name} = initial_display) do
    GenServer.start_link(__MODULE__, initial_display,
      name: via_tuple({driver_module, display_name})
    )
  end

  @doc """
  Delegates the specified operation to the display driver, and updates the state as needed.

  ## Examples
    DisplayController.execute(pid, {:print, "Hello"})
  """
  def execute(pid, command), do: GenServer.call(pid, command)

  @impl true
  def init(initial_display), do: {:ok, initial_display}

  @impl true
  def handle_call(command, _from, display) do
    {_ok_or_error, new_display} = result = control_display(command, display)
    Logger.info(inspect(result))
    {:reply, result, Map.merge(display, new_display)}
  end

  defp control_display(command, %{driver_module: driver_module} = display) do
    apply(driver_module, :execute, [display, command])
  end
end
