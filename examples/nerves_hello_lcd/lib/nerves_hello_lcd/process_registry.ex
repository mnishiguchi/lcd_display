defmodule NervesHelloLcd.ProcessRegistry do
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
      iex> ProcessRegistry.via_tuple({DisplayController, 20})
      {:via, Registry, {ProcessRegistry, {DisplayController, 20}}}
  """
  def via_tuple(key) when is_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  @doc """
  Returns a PID or :undefined.
  ## Examples
      iex> ProcessRegistry.whereis_name({DisplayController, 20})
      #PID<0.235.0>
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
