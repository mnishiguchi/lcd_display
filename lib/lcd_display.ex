defmodule LcdDisplay do
  @moduledoc """
  A collection of utility functions to use this library.
  """

  alias LcdDisplay.{DisplaySupervisor, DisplayController}

  @doc """
  Starts a supervised display controller process.
  """
  def start_display(driver_module, config) when is_atom(driver_module) and is_map(config) do
    DisplaySupervisor.display_controller(driver_module, config)
  end

  @doc """
  Executes a supported command that is specified.
  """
  def execute(pid, command) when is_pid(pid) do
    DisplayController.execute(pid, command)
  end
end
