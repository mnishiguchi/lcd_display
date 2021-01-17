defmodule LcdDisplay.I2C do
  @moduledoc """
  Lets you communicate with hardware devices using the [I2C](https://en.wikipedia.org/wiki/I%C2%B2C) protocol.
  A thin wrapper of [elixir-circuits/circuits_i2c](https://github.com/elixir-circuits/circuits_i2c).
  """

  require Logger

  defmodule Behaviour do
    @moduledoc """
    Defines a behaviour required for I2C abstraction.
    """

    @type i2c_bus :: String.t()
    @type i2c_address :: byte
    @type data :: binary

    @callback open(i2c_bus) :: {:ok, reference} | {:error, any}
    @callback write(reference, i2c_address, data) :: :ok | {:error, any}
  end

  @behaviour LcdDisplay.I2C.Behaviour

  def open(i2c_bus), do: i2c_module().open(i2c_bus)

  def write(i2c_ref, i2c_address, data) do
    # Logger.info("[#{__MODULE__}] Writing #{inspect(data, base: :hex)}")
    i2c_module().write(i2c_ref, i2c_address, data)
  end

  defp i2c_module() do
    # https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-compile-time-application-configuration
    Application.get_env(:lcd_display, :i2c_module, Circuits.I2C)
  end
end
