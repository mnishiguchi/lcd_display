defmodule LcdDisplay.CommunicationBus do
  @moduledoc false

  defmodule GPIO do
    @moduledoc """
    Defines a behaviour required for GPIO abstraction.
    """
    @callback open(pos_integer, :output) :: {:ok, reference} | {:error, any}
    @callback write(reference, 0 | 1) :: :ok | {:error, any}
  end

  defmodule I2C do
    @moduledoc """
    Defines a behaviour required for I²C abstraction.
    """
    @callback open(binary) :: {:ok, reference} | {:error, any}
    @callback write(reference, pos_integer, binary) :: :ok | {:error, any}
  end
end

defmodule LcdDisplay.GPIO do
  @moduledoc """
  Lets you control GPIOs.
  A thin wrapper of [elixir-circuits/circuits_gpio](https://github.com/elixir-circuits/circuits_gpio).
  """

  @behaviour LcdDisplay.CommunicationBus.GPIO

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

  @behaviour LcdDisplay.CommunicationBus.I2C

  def open(i2c_device), do: i2c_module().open(i2c_device)

  def write(i2c_ref, i2c_address, data), do: i2c_module().write(i2c_ref, i2c_address, data)

  defp i2c_module() do
    # https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-compile-time-application-configuration
    Application.get_env(:lcd_display, :i2c_module, Circuits.I2C)
  end
end
