defmodule LcdDisplay.Utils do
  @moduledoc false

  require Logger
  alias Circuits.SPI
  alias Circuits.GPIO

  def open_spi_with_retry(spi_bus, spi_speed_hz, attempts_left \\ 10)

  def open_spi_with_retry(spi_bus, spi_speed_hz, attempts_left) do
    case SPI.open(spi_bus, speed_hz: spi_speed_hz) do
      {:ok, spi} ->
        {:ok, spi}

      {:error, reason} when attempts_left > 1 ->
        Logger.warning(
          "[LcdDisplay] SPI open failed on #{inspect(spi_bus)} (#{inspect(reason)}); " <>
            "retrying in 100ms (#{attempts_left - 1} attempts left)"
        )

        Process.sleep(100)
        open_spi_with_retry(spi_bus, spi_speed_hz, attempts_left - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def maybe_open_gpio(nil, _direction), do: nil

  def maybe_open_gpio(pin, direction) when is_integer(pin) and pin >= 0 do
    {:ok, gpio} = GPIO.open(pin, direction)
    gpio
  end
end
