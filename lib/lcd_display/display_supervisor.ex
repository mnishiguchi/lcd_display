defmodule LcdDisplay.DisplaySupervisor do
  @moduledoc """
  Supervises display controller processes.
  """

  # https://hexdocs.pm/elixir/DynamicSupervisor.html
  use DynamicSupervisor

  require Logger

  alias LcdDisplay.DisplayController

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Creates a `LcdDisplay.DisplayController` process.

  ## Examples

      pid = DisplaySupervisor.display_controller(
        LcdDisplay.HD44780.I2C,
        %{display_name: "display 1"}
      )
  """
  def display_controller(driver_module, config) when is_atom(driver_module) and is_map(config) do
    case DisplayController.whereis({driver_module, config.display_name}) do
      nil ->
        start_child(driver_module, config)

      pid ->
        Logger.info("Recreating the display controller for #{driver_module}")
        Process.exit(pid, :kill)
        display_controller(driver_module, config)
    end
  end

  defp start_child(driver_module, config) when is_map(config) do
    display = initialize_display(driver_module, config)

    case DynamicSupervisor.start_child(__MODULE__, DisplayController.child_spec(display)) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  defp initialize_display(driver_module, config) when is_atom(driver_module) and is_map(config) do
    with {:ok, display} <- apply(driver_module, :start, [config]), do: display
  end
end
