defmodule LcdDisplay.XPT2046 do
  @moduledoc false

  use LcdDisplay.TouchDriver, driver_impl: LcdDisplay.XPT2046.TouchDriverImpl
end

defmodule LcdDisplay.XPT2046.TouchDriverImpl do
  @moduledoc false

  @behaviour LcdDisplay.TouchDriver.TouchContract

  alias Circuits.SPI
  alias Circuits.GPIO
  alias LcdDisplay.TouchMapping

  import Bitwise
  require Logger

  defstruct [
    :spi,
    :irq,
    :screen_width,
    :screen_height,
    :rotation,
    :ui_pid,
    :mapping,
    :poll_interval_ms,
    :x_min,
    :x_max,
    :y_min,
    :y_max
  ]

  @default_spi_bus "spidev0.1"
  @default_interrupt_pin 17
  @default_poll_interval_ms 100

  @default_x_min 149
  @default_x_max 3845
  @default_y_min 294
  @default_y_max 3831

  @default_swap_xy false
  @default_invert_x false
  @default_invert_y false

  @impl true
  def init(opts) do
    spi_bus = Keyword.get(opts, :spi_bus, @default_spi_bus)
    interrupt_pin = Keyword.get(opts, :interrupt_pin, @default_interrupt_pin)
    screen_width = Keyword.fetch!(opts, :screen_width)
    screen_height = Keyword.fetch!(opts, :screen_height)
    rotation = Keyword.get(opts, :rotation, 0)
    ui_pid = Keyword.get(opts, :ui_pid)
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)

    x_min = Keyword.get(opts, :x_min, @default_x_min)
    x_max = Keyword.get(opts, :x_max, @default_x_max)
    y_min = Keyword.get(opts, :y_min, @default_y_min)
    y_max = Keyword.get(opts, :y_max, @default_y_max)

    swap_xy = Keyword.get(opts, :swap_xy, @default_swap_xy)
    invert_x = Keyword.get(opts, :invert_x, @default_invert_x)
    invert_y = Keyword.get(opts, :invert_y, @default_invert_y)

    with {:ok, irq} <- GPIO.open(interrupt_pin, :input),
         {:ok, spi} <- SPI.open(spi_bus) do
      mapping =
        TouchMapping.new(
          screen_width: screen_width,
          screen_height: screen_height,
          raw_x_min: x_min,
          raw_x_max: x_max,
          raw_y_min: y_min,
          raw_y_max: y_max,
          rotation: rotation,
          swap_xy: swap_xy,
          invert_x: invert_x,
          invert_y: invert_y
        )

      state = %__MODULE__{
        spi: spi,
        irq: irq,
        screen_width: screen_width,
        screen_height: screen_height,
        rotation: rotation,
        ui_pid: ui_pid,
        mapping: mapping,
        poll_interval_ms: poll_interval_ms,
        x_min: x_min,
        x_max: x_max,
        y_min: y_min,
        y_max: y_max
      }

      schedule_poll(state)
      {:ok, state}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:poll, %__MODULE__{} = state) do
    new_state = do_read_touch(state)
    schedule_poll(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, %__MODULE__{} = state) do
    {:noreply, state}
  end

  defp schedule_poll(%__MODULE__{poll_interval_ms: interval}) do
    Process.send_after(self(), :poll, interval)
  end

  defp do_read_touch(%__MODULE__{irq: irq, spi: spi, mapping: mapping} = state) do
    case GPIO.read(irq) do
      0 ->
        raw_x = read_axis(spi, 0x90)
        raw_y = read_axis(spi, 0xD0)
        {x, y} = TouchMapping.to_screen(mapping, raw_x, raw_y)

        touch_data = %{x: x, y: y, raw_x: raw_x, raw_y: raw_y}
        Logger.debug("[XPT2046] touched #{inspect(touch_data)}")

        if state.ui_pid do
          send(state.ui_pid, {:lcd_display_touch, touch_data})
        end

        state

      _ ->
        state
    end
  end

  defp read_axis(spi, command) do
    <<_ignore, h, l>> = SPI.transfer!(spi, <<command, 0x00, 0x00>>)
    (h <<< 8 ||| l) >>> 3
  end
end
