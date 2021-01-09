defmodule LcdDisplay.ProcessRegistry do
  @moduledoc """
  Manages processes.
  """

  def child_spec(_args) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  @doc """
  Returns a standardized via-tuple for this registry.

  ## Examples

      iex> ProcessRegistry.via_tuple(SomeKey)
      {:via, Registry, {ProcessRegistry, SomeKey}}
  """
  def via_tuple(key) when is_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  @doc """
  Returns a PID or :undefined.

      iex> ProcessRegistry.whereis_name(SomeKey)
      #PID<0.235.0>

      iex> ProcessRegistry.whereis_name(OtherKey)
      :undefined
  """
  def whereis_name(key) when is_tuple(key) do
    Registry.whereis_name({__MODULE__, key})
  end

  @doc """
  Starts a unique registry.
  """
  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end
end