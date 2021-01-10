defmodule LcdDisplay.GPIO do
  @moduledoc """
  Lets you control GPIOs.
  A thin wrapper of [elixir-circuits/circuits_gpio](https://github.com/elixir-circuits/circuits_gpio).
  """

  defmodule Behaviour do
    @moduledoc """
    Defines a behaviour required for GPIO abstraction.
    """

    @type gpio_pin :: pos_integer

    @callback open(gpio_pin, :output) :: {:ok, reference} | {:error, any}
    @callback write(reference, 0 | 1) :: :ok | {:error, any}
  end

  @behaviour LcdDisplay.GPIO.Behaviour

  def open(gpio_pin, :output), do: gpio_module().open(gpio_pin, :output)

  def write(gpio_ref, 0), do: gpio_module().write(gpio_ref, 0)
  def write(gpio_ref, 1), do: gpio_module().write(gpio_ref, 1)

  defp gpio_module() do
    # https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-compile-time-application-configuration
    Application.get_env(:lcd_display, :gpio_module, Circuits.GPIO)
  end
end

defmodule LcdDisplay.I2C do
  @moduledoc """
  Lets you communicate with hardware devices using the I2C protocol.
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
    # Logger.info("Writing #{inspect(data, base: :hex)} to #{inspect(i2c_address, base: :hex)}")
    i2c_module().write(i2c_ref, i2c_address, data)
  end

  defp i2c_module() do
    # https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-compile-time-application-configuration
    Application.get_env(:lcd_display, :i2c_module, Circuits.I2C)
  end
end
