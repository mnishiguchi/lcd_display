defmodule LcdDisplay.SPI do
  @moduledoc """
  Lets you communicate with hardware devices using the I2C protocol.
  A thin wrapper of [elixir-circuits/circuits_spi](https://github.com/elixir-circuits/circuits_spi).
  """

  require Logger

  defmodule Behaviour do
    @moduledoc """
    Defines a behaviour required for I2C abstraction.
    """

    @type spi_bus :: String.t()
    @type spi_address :: byte
    @type data :: binary

    @callback open(spi_bus, list) :: {:ok, reference} | {:error, any}
    @callback transfer(reference, data) :: :ok | {:error, any}
  end

  @behaviour LcdDisplay.SPI.Behaviour

  @spec open(binary() | charlist(), list) :: {:ok, reference()}
  def open(spi_bus, opts \\ []), do: spi_module().open(spi_bus, opts)

  @spec transfer(reference(), binary()) :: {:ok, binary()} | {:error, term()}
  def transfer(spi_ref, data) do
    spi_module().transfer(spi_ref, data)
  end

  defp spi_module() do
    # https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-compile-time-application-configuration
    Application.get_env(:lcd_display, :spi_module, Circuits.SPI)
  end
end
