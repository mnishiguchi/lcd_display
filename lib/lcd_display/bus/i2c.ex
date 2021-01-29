defmodule LcdDisplay.I2C.Behaviour do
  @moduledoc """
  Defines a behaviour required for I2C abstraction.
  """

  @type bus_name :: String.t()
  @type address :: 0..127

  @callback open(bus_name) :: {:ok, reference} | {:error, any}
  @callback write(reference, address, iodata) :: :ok | {:error, any}
end

defmodule LcdDisplay.I2C do
  @moduledoc """
  Lets you communicate with hardware devices using the [I2C](https://en.wikipedia.org/wiki/I%C2%B2C) protocol.
  A thin wrapper of [elixir-circuits/circuits_i2c](https://github.com/elixir-circuits/circuits_i2c).
  """

  require Logger

  @behaviour LcdDisplay.I2C.Behaviour

  def open(bus_name), do: i2c_module().open(bus_name)

  def write(i2c_ref, address, data) do
    # Logger.info("[#{__MODULE__}] Writing #{inspect(data, base: :hex)}")
    i2c_module().write(i2c_ref, address, data)
  end

  defp i2c_module() do
    # https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-compile-time-application-configuration
    Application.get_env(:lcd_display, :i2c_module, Circuits.I2C)
  end
end

defmodule LcdDisplay.I2C.Stub do
  @moduledoc false

  @behaviour LcdDisplay.I2C.Behaviour

  def open(_bus_name), do: {:ok, Kernel.make_ref()}

  def write(_reference, _address, _data), do: :ok

  def read(_reference, _address, _bytes_to_read), do: {:ok, "stub"}

  def write_read(_reference, _address, _data, _bytes_to_read), do: {:ok, "stub"}
end
