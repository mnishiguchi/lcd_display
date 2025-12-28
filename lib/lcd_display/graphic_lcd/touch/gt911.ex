defmodule LcdDisplay.GT911 do
  @moduledoc false

  use LcdDisplay.TouchDriver, driver_impl: LcdDisplay.GT911.TouchDriverImpl
end

defmodule LcdDisplay.GT911.TouchDriverImpl do
  @moduledoc false

  @behaviour LcdDisplay.TouchDriver.TouchContract

  alias Circuits.I2C
  alias Circuits.GPIO
  alias LcdDisplay.TouchMapping

  import Bitwise
  require Logger

  defstruct [
    :i2c_ref,
    :screen_width,
    :screen_height,
    :rotation,
    :ui_pid,
    :i2c_address,
    :max_x,
    :max_y,
    :mapping,
    poll_interval_ms: 50
  ]

  @default_i2c_addr 0x14
  @default_interrupt_pin 4
  @default_reset_pin 17
  @default_poll_interval_ms 50

  @default_swap_xy false
  @default_invert_x false
  @default_invert_y false

  @impl true
  def init(opts) do
    bus_name = Keyword.fetch!(opts, :i2c_bus)
    i2c_address = Keyword.get(opts, :i2c_address, @default_i2c_addr)
    interrupt_pin = Keyword.get(opts, :interrupt_pin, @default_interrupt_pin)
    reset_pin = Keyword.get(opts, :reset_pin, @default_reset_pin)
    screen_width = Keyword.fetch!(opts, :screen_width)
    screen_height = Keyword.fetch!(opts, :screen_height)
    rotation = Keyword.get(opts, :rotation, 0)
    ui_pid = Keyword.get(opts, :ui_pid)
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)

    swap_xy = Keyword.get(opts, :swap_xy, @default_swap_xy)
    invert_x = Keyword.get(opts, :invert_x, @default_invert_x)
    invert_y = Keyword.get(opts, :invert_y, @default_invert_y)

    with {:ok, i2c_ref} <- I2C.open(bus_name),
         {:ok, rst} <- GPIO.open(reset_pin, :output),
         {:ok, int} <- GPIO.open(interrupt_pin, :output) do
      GPIO.write(int, 0)
      GPIO.write(rst, 0)
      Process.sleep(10)

      GPIO.write(rst, 1)
      Process.sleep(50)

      :ok = GPIO.close(int)
      :ok = GPIO.close(rst)
      Process.sleep(50)

      pid_bytes = read_reg16(i2c_ref, i2c_address, 0x8140, 4)
      product_id = pid_bytes |> Enum.map(&<<&1::utf8>>) |> Enum.join()
      Logger.info("[GT911] product_id=#{product_id}")

      [x_low, x_high, y_low, y_high] = read_reg16(i2c_ref, i2c_address, 0x8048, 4)
      max_x = x_high <<< 8 ||| x_low
      max_y = y_high <<< 8 ||| y_low

      Logger.info("[GT911] max_x=#{max_x} max_y=#{max_y}")

      enable_touch_reporting(i2c_ref, i2c_address)

      mapping =
        TouchMapping.new(
          screen_width: screen_width,
          screen_height: screen_height,
          raw_x_min: 0,
          raw_x_max: max_x,
          raw_y_min: 0,
          raw_y_max: max_y,
          rotation: rotation,
          swap_xy: swap_xy,
          invert_x: invert_x,
          invert_y: invert_y
        )

      state = %__MODULE__{
        i2c_ref: i2c_ref,
        screen_width: screen_width,
        screen_height: screen_height,
        rotation: rotation,
        ui_pid: ui_pid,
        i2c_address: i2c_address,
        max_x: max_x,
        max_y: max_y,
        mapping: mapping,
        poll_interval_ms: poll_interval_ms
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

  defp do_read_touch(%__MODULE__{i2c_ref: i2c, i2c_address: addr, mapping: mapping} = state) do
    case read_reg16(i2c, addr, 0x814E, 1) do
      [status] when (status &&& 0x80) != 0 ->
        num_points = status &&& 0x0F

        if num_points > 0 do
          buf = read_reg16(i2c, addr, 0x8150, num_points * 8)

          for i <- 0..(num_points - 1) do
            base = i * 8
            raw_x = (Enum.at(buf, base) || 0) ||| (Enum.at(buf, base + 1) || 0) <<< 8
            raw_y = (Enum.at(buf, base + 2) || 0) ||| (Enum.at(buf, base + 3) || 0) <<< 8
            touch_id = Enum.at(buf, base + 4) || 0
            {x, y} = TouchMapping.to_screen(mapping, raw_x, raw_y)

            touch_data = %{x: x, y: y, raw_x: raw_x, raw_y: raw_y, touch_id: touch_id}
            Logger.debug("[GT911] touched #{inspect(touch_data)}")

            if state.ui_pid do
              send(state.ui_pid, {:lcd_display_touch, touch_data})
            end
          end
        end

        safe_clear_status(i2c, addr)
        state

      _ ->
        state
    end
  end

  defp enable_touch_reporting(i2c, addr) do
    case write_reg16(i2c, addr, 0x8040, [0x01]) do
      :ok ->
        Logger.info("[GT911] enable_touch_reporting result=ok")

      {:error, reason} ->
        Logger.error("[GT911] enable_touch_reporting error=#{inspect(reason)}")
    end
  end

  defp safe_clear_status(i2c, addr) do
    case write_reg16(i2c, addr, 0x814E, [0x00]) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("[GT911] clear_status error=#{inspect(reason)}")
    end
  end

  defp read_reg16(i2c, addr, reg, len) do
    high = reg >>> 8 &&& 0xFF
    low = reg &&& 0xFF

    with :ok <- I2C.write(i2c, addr, <<high, low>>),
         {:ok, data} <- I2C.read(i2c, addr, len) do
      :binary.bin_to_list(data)
    else
      _ -> []
    end
  end

  defp write_reg16(i2c, addr, reg, values) do
    high = reg >>> 8 &&& 0xFF
    low = reg &&& 0xFF
    data = <<high, low>> <> :binary.list_to_bin(values)

    I2C.write(i2c, addr, data)
  end
end
