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
        LcdDisplay.HD44780.PCF8575,
        %{
          display_name: "display 1", # the identifier
          i2c_bus: "i2c-1",          # I2C bus name
          i2c_address: 0x27,         # 7-bit address
          rows: 2,                   # the number of display rows
          cols: 16,                  # the number of display columns
          font_size: "5x8"           # "5x10" or "5x8"
        }
      )
  """
  def display_controller(driver_module, config) when is_atom(driver_module) and is_map(config) do
    display_name = config[:display_name] || "Display #{:rand.uniform(999)}"

    case DisplayController.whereis({driver_module, display_name}) do
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
    with {:ok, display} <- driver_module.start(config), do: display
  end
end
