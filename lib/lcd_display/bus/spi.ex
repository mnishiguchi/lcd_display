defmodule LcdDisplay.SPI do
  @moduledoc """
  Lets you communicate with hardware devices using the [SPI](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface) protocol.
  A thin wrapper of [elixir-circuits/circuits_spi](https://github.com/elixir-circuits/circuits_spi).
  """

  require Logger

  defmodule Behaviour do
    @moduledoc """
    Defines a behaviour required for SPI abstraction.
    """

    @type spi_bus :: String.t()
    @type spi_address :: byte
    @type data :: binary

    @callback open(binary() | charlist(), list) :: {:ok, reference} | {:error, any}
    @callback transfer(reference, data) :: {:ok, binary()} | {:error, any}
  end

  @behaviour LcdDisplay.SPI.Behaviour

  def open(spi_bus, opts \\ []), do: spi_module().open(spi_bus, opts)

  def transfer(spi_ref, data) do
    # Logger.info("[#{__MODULE__}] Writing #{inspect(data, base: :hex)}")
    spi_module().transfer(spi_ref, data)
  end

  defp spi_module() do
    # https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-compile-time-application-configuration
    Application.get_env(:lcd_display, :spi_module, Circuits.SPI)
  end
end
