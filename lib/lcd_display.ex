defmodule LcdDisplay do
  @moduledoc """
  A collection of utility functions to use this library.
  """

  # TODO: Add test

  @doc """
  Starts a supervised display controller process.
  """
  def start_display(driver_module, config) when is_atom(driver_module) and is_map(config) do
    display = initialize_display(driver_module, config)
    LcdDisplay.DisplayController.start_link(display)
  end

  @doc """
  Executes a supported command that is specified.
  """
  def execute(pid, command) when is_pid(pid) do
    LcdDisplay.DisplayController.execute(pid, command)
  end

  defp initialize_display(driver_module, config) when is_atom(driver_module) and is_map(config) do
    with {:ok, display} <- driver_module.start(config), do: display
  end
end
