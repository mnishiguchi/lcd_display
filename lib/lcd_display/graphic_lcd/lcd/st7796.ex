defmodule LcdDisplay.ST7796 do
  @moduledoc """
  Driver for ST7796-based graphic LCD panels.
  """

  use LcdDisplay.DisplayDriver, driver_impl: LcdDisplay.ST7796.DriverImpl
end

defmodule LcdDisplay.ST7796.DriverImpl do
  @moduledoc false

  require Logger
  import Bitwise

  import LcdDisplay.Utils,
    only: [
      open_spi_with_retry: 2,
      maybe_open_gpio: 2
    ]

  @behaviour LcdDisplay.DisplayDriver.DisplayContract

  @st7796_swreset 0x01
  @st7796_slpout 0x11
  @st7796_noron 0x13
  @st7796_ptlon 0x12
  # @st7796_invoff 0x20
  @st7796_invon 0x21
  @st7796_dispoff 0x28
  @st7796_dispon 0x29
  @st7796_caset 0x2A
  @st7796_paset 0x2B
  @st7796_ramwr 0x2C
  @st7796_madctl 0x36
  @st7796_idleoff 0x38
  @st7796_idleon 0x39
  @st7796_pixfmt 0x3A
  @st7796_invctr 0xB4
  @st7796_dispctrl 0xB7
  @st7796_pwctr1 0xC0
  @st7796_pwctr2 0xC1
  @st7796_pwctr3 0xC2
  @st7796_vmctr1 0xC5
  @st7796_adjctrl3 0xE8
  @st7796_pgamctrl 0xE0
  @st7796_ngamctrl 0xE1
  @st7796_cmdset 0xF0

  # MADCTL / pixel format bits
  @st7796_mad_rgb 0x08
  @st7796_mad_bgr 0x00
  @st7796_mad_vertical 0x20
  @st7796_mad_x_right 0x40
  @st7796_mad_x_left 0x00
  @st7796_mad_y_up 0x80
  @st7796_mad_y_down 0x00
  @st7796_pix_16bit 0x55
  @st7796_pix_18bit 0x66

  @enforce_keys [
    :lcd_spi,
    :gpio_data_command,
    :spi_bus,
    :spi_speed_hz,
    :width,
    :height,
    :x_offset,
    :y_offset,
    :data_bus,
    :display_mode,
    :chunk_size
  ]
  defstruct [
    :lcd_spi,
    :gpio_data_command,
    :gpio_reset,
    :spi_bus,
    :spi_speed_hz,
    :data_command_pin,
    :reset_pin,
    :width,
    :height,
    :x_offset,
    :y_offset,
    :pixel_format,
    :rotation,
    :scan_direction,
    :data_bus,
    :display_mode,
    :chunk_size
  ]

  @impl true
  def init(opts) do
    spi_bus = opts[:spi_bus] || "spidev0.0"
    data_command_pin = Keyword.fetch!(opts, :data_command_pin)
    spi_speed_hz = opts[:spi_speed_hz] || 16_000_000
    width = opts[:width] || 480
    height = opts[:height] || 320
    x_offset = opts[:x_offset] || 0
    y_offset = opts[:y_offset] || 0
    reset_pin = opts[:reset_pin]
    pixel_format = opts[:pixel_format] || :rgb565
    rotation = opts[:rotation] || 90
    scan_direction = opts[:scan_direction] || :right_down
    display_mode = opts[:display_mode] || :normal
    data_bus = opts[:data_bus] || :parallel_8bit

    with {:ok, lcd_spi} <- open_spi_with_retry(spi_bus, spi_speed_hz),
         {:ok, gpio_data_command} <- Circuits.GPIO.open(data_command_pin, :output) do
      gpio_reset = maybe_open_gpio(reset_pin, :output)
      chunk_size = calculate_chunk_size(lcd_spi, opts[:chunk_size], data_bus)

      display =
        %__MODULE__{
          lcd_spi: lcd_spi,
          gpio_data_command: gpio_data_command,
          gpio_reset: gpio_reset,
          spi_bus: spi_bus,
          spi_speed_hz: spi_speed_hz,
          data_command_pin: data_command_pin,
          reset_pin: reset_pin,
          width: width,
          height: height,
          x_offset: x_offset,
          y_offset: y_offset,
          pixel_format: pixel_format,
          rotation: rotation,
          scan_direction: scan_direction,
          data_bus: data_bus,
          display_mode: display_mode,
          chunk_size: chunk_size
        }
        |> reset()
        |> init_sequence()

      {:ok, display}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, %__MODULE__{} = display) do
    Circuits.SPI.close(display.lcd_spi)
    Circuits.GPIO.close(display.gpio_data_command)
    if display.gpio_reset, do: Circuits.GPIO.close(display.gpio_reset)

    :ok
  end

  @impl true
  def reset(%__MODULE__{} = display) do
    case display.gpio_reset do
      nil ->
        display

      gpio_reset ->
        Circuits.GPIO.write(gpio_reset, 1)
        :timer.sleep(500)
        Circuits.GPIO.write(gpio_reset, 0)
        :timer.sleep(500)
        Circuits.GPIO.write(gpio_reset, 1)
        :timer.sleep(500)
        display
    end
  end

  @impl true
  def size(%__MODULE__{} = display) do
    %{height: display.height, width: display.width}
  end

  @impl true
  def pixel_format(%__MODULE__{} = display) do
    display.pixel_format
  end

  @impl true
  def set_pixel_format(%__MODULE__{} = display, pixel_format)
      when pixel_format in [:bgr565, :rgb565, :bgr666, :rgb666] do
    display = %__MODULE__{display | pixel_format: pixel_format}

    display
    |> write_command(@st7796_pixfmt, cmd_data: pixfmt_data(display))
    |> write_command(@st7796_madctl, cmd_data: madctl_data(display))
  end

  @impl true
  def set_power(%__MODULE__{} = display, status) when status in [:on, :off] do
    case status do
      :on -> write_command(display, @st7796_dispon)
      :off -> write_command(display, @st7796_dispoff)
    end
  end

  @impl true
  def set_mode(%__MODULE__{} = display, display_mode) do
    case display_mode do
      :normal ->
        %__MODULE__{display | display_mode: :normal}
        |> write_command(@st7796_idleoff)
        |> write_command(@st7796_noron)

      :partial ->
        %__MODULE__{display | display_mode: :partial}
        |> write_command(@st7796_idleoff)
        |> write_command(@st7796_ptlon)

      :idle ->
        %__MODULE__{display | display_mode: :idle}
        |> write_command(@st7796_idleon)
    end
  end

  # ST7796 path does not currently use frame-rate control; keep as no-op
  @impl true
  def set_frame_rate(%__MODULE__{} = display, _frame_rate_hz), do: display

  @impl true
  def write_frame_565(display, image_data) when is_binary(image_data) do
    write_frame_565(display, :binary.bin_to_list(image_data))
  end

  @impl true
  def write_frame_565(%__MODULE__{} = display, image_data) when is_list(image_data) do
    display
    |> set_window(x0: 0, y0: 0, x1: nil, y1: nil)
    |> transfer_raw(image_data, true, false)
  end

  @impl true
  def write_frame_666(display, image_data) when is_binary(image_data) do
    write_frame_666(display, :binary.bin_to_list(image_data))
  end

  @impl true
  def write_frame_666(%__MODULE__{} = display, image_data) when is_list(image_data) do
    display
    |> set_window(x0: 0, y0: 0, x1: nil, y1: nil)
    |> transfer_raw(image_data, true, false)
  end

  @impl true
  def write_frame(%__MODULE__{pixel_format: target_color} = display, image_data, source_color)
      when is_binary(image_data) and source_color in [:rgb888, :bgr888] and
             target_color in [:rgb565, :bgr565] do
    write_frame_565(display, to_565(image_data, source_color, target_color))
  end

  @impl true
  def write_frame(%__MODULE__{pixel_format: target_color} = display, image_data, source_color)
      when is_binary(image_data) and source_color in [:rgb888, :bgr888] and
             target_color in [:rgb666, :bgr666] do
    write_frame_666(display, to_666(image_data, source_color, target_color))
  end

  @impl true
  def write_frame(display, image_data, source_color)
      when is_list(image_data) and source_color in [:rgb888, :bgr888] do
    write_frame(
      display,
      Enum.map(image_data, &Enum.into(&1, <<>>, fn byte -> <<byte::8>> end)),
      source_color
    )
  end

  @impl true
  def write_command(%__MODULE__{} = display, cmd, opts \\ []) when is_integer(cmd) do
    do_command(display, cmd, opts)
  end

  @impl true
  def write_data(%__MODULE__{} = display, []), do: display

  @impl true
  def write_data(%__MODULE__{data_bus: :parallel_8bit} = display, data) do
    transfer_raw(display, data, true, false)
  end

  @impl true
  def write_data(%__MODULE__{data_bus: :parallel_16bit} = display, data) do
    transfer_raw(display, data, true, true)
  end

  @impl true
  def transfer(%__MODULE__{} = display, bytes, is_data) when is_boolean(is_data) do
    to_be16 = display.data_bus == :parallel_16bit
    is_data_int = if is_data, do: 1, else: 0
    do_send(display, bytes, is_data_int, to_be16)
  end

  defp transfer_raw(%__MODULE__{} = display, bytes, is_data, to_be16) when is_boolean(is_data) do
    is_data_int = if is_data, do: 1, else: 0
    do_send(display, bytes, is_data_int, to_be16)
  end

  defp do_command(display, cmd, opts)

  defp do_command(%__MODULE__{data_bus: :parallel_8bit} = display, cmd, opts)
       when is_integer(cmd) do
    cmd_data = opts[:cmd_data] || []
    delay = opts[:delay] || 0

    display
    |> transfer_raw(cmd, false, false)
    |> write_data(cmd_data)
    |> then(fn d ->
      :timer.sleep(delay)
      d
    end)
  end

  defp do_command(%__MODULE__{data_bus: :parallel_16bit} = display, cmd, opts)
       when is_integer(cmd) do
    cmd_data = opts[:cmd_data] || []
    delay = opts[:delay] || 0

    display
    |> transfer_raw(cmd, false, true)
    |> write_data(cmd_data)
    |> then(fn d ->
      :timer.sleep(delay)
      d
    end)
  end

  defp to_be_u16(u8_bytes) do
    u8_bytes
    |> Enum.map(fn u8 -> [0x00, u8] end)
    |> IO.iodata_to_binary()
  end

  defp default_chunk_size(:parallel_16bit), do: 0x8000
  defp default_chunk_size(_data_bus), do: 4_096

  defp calculate_chunk_size(spi, requested_chunk_size, data_bus) do
    base =
      case requested_chunk_size do
        n when is_integer(n) and n > 0 -> n
        _ -> default_chunk_size(data_bus)
      end

    case Circuits.SPI.max_transfer_size(spi) do
      max when is_integer(max) and max > 0 -> min(base, max)
      _ -> base
    end
  end

  defp chunk_binary(binary, chunk_size) when is_binary(binary) do
    total_bytes = byte_size(binary)
    full_chunks = div(total_bytes, chunk_size)

    chunks =
      if full_chunks > 0 do
        for i <- 0..(full_chunks - 1), reduce: [] do
          acc -> [:binary.part(binary, chunk_size * i, chunk_size) | acc]
        end
      else
        []
      end

    remaining = rem(total_bytes, chunk_size)

    chunks =
      if remaining > 0 do
        [:binary.part(binary, chunk_size * full_chunks, remaining) | chunks]
      else
        chunks
      end

    Enum.reverse(chunks)
  end

  defp do_send(%__MODULE__{} = display, bytes, is_data, to_be16)
       when is_integer(bytes) and is_data in [0, 1] do
    do_send(display, <<band(bytes, 0xFF)>>, is_data, to_be16)
  end

  defp do_send(%__MODULE__{} = display, bytes, is_data, to_be16)
       when is_list(bytes) and is_data in [0, 1] do
    do_send(display, IO.iodata_to_binary(bytes), is_data, to_be16)
  end

  defp do_send(%__MODULE__{} = display, bytes, is_data, to_be16)
       when is_binary(bytes) and is_data in [0, 1] do
    bytes = if to_be16, do: to_be_u16(:binary.bin_to_list(bytes)), else: bytes

    Circuits.GPIO.write(display.gpio_data_command, is_data)

    for xfdata <- chunk_binary(bytes, display.chunk_size) do
      {:ok, _ret} = Circuits.SPI.transfer(display.lcd_spi, xfdata)
    end

    display
  end

  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :rgb565}), do: @st7796_mad_rgb
  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :bgr565}), do: @st7796_mad_bgr
  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :rgb666}), do: @st7796_mad_rgb
  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :bgr666}), do: @st7796_mad_bgr

  defp pixfmt_data(%__MODULE__{pixel_format: :rgb565}), do: @st7796_pix_16bit
  defp pixfmt_data(%__MODULE__{pixel_format: :bgr565}), do: @st7796_pix_16bit
  defp pixfmt_data(%__MODULE__{pixel_format: :rgb666}), do: @st7796_pix_18bit
  defp pixfmt_data(%__MODULE__{pixel_format: :bgr666}), do: @st7796_pix_18bit

  defp madctl_data(%__MODULE__{rotation: 0, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_right)
    |> bor(@st7796_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 90, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_left)
    |> bor(@st7796_mad_y_down)
    |> bor(@st7796_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 180, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_left)
    |> bor(@st7796_mad_y_up)
  end

  defp madctl_data(%__MODULE__{rotation: 270, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_right)
    |> bor(@st7796_mad_y_up)
    |> bor(@st7796_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 0, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_right)
    |> bor(@st7796_mad_y_up)
  end

  defp madctl_data(%__MODULE__{rotation: 90, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_right)
    |> bor(@st7796_mad_y_down)
    |> bor(@st7796_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 180, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_left)
    |> bor(@st7796_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 270, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_left)
    |> bor(@st7796_mad_y_up)
    |> bor(@st7796_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 0, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_left)
    |> bor(@st7796_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 90, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_right)
    |> bor(@st7796_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 180, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_right)
    |> bor(@st7796_mad_y_up)
  end

  defp madctl_data(%__MODULE__{rotation: 270, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@st7796_mad_x_left)
    |> bor(@st7796_mad_y_up)
  end

  defp init_sequence(%__MODULE__{} = display) do
    display
    |> write_command(@st7796_swreset, delay: 120)
    |> write_command(@st7796_slpout, delay: 120)
    |> write_command(@st7796_pixfmt, cmd_data: pixfmt_data(display))
    |> write_command(@st7796_madctl, cmd_data: madctl_data(display))
    |> write_command(@st7796_cmdset, cmd_data: 0xC3)
    |> write_command(@st7796_cmdset, cmd_data: 0x96)
    |> write_command(@st7796_invctr, cmd_data: 0x01)
    |> write_command(@st7796_dispctrl, cmd_data: 0xC6)
    |> write_command(@st7796_pwctr1, cmd_data: [0x80, 0x45])
    |> write_command(@st7796_pwctr2, cmd_data: 0x13)
    |> write_command(@st7796_pwctr3, cmd_data: 0xA7)
    |> write_command(@st7796_vmctr1, cmd_data: 0x0A)
    |> write_command(@st7796_adjctrl3)
    |> write_data([0x40, 0x8A, 0x00, 0x00, 0x29, 0x19, 0xA5, 0x33])
    |> write_command(@st7796_pgamctrl)
    |> write_data([
      0xD0,
      0x08,
      0x0F,
      0x06,
      0x06,
      0x33,
      0x30,
      0x33,
      0x47,
      0x17,
      0x13,
      0x13,
      0x2B,
      0x31
    ])
    |> write_command(@st7796_ngamctrl)
    |> write_data([
      0xD0,
      0x0A,
      0x11,
      0x0B,
      0x09,
      0x07,
      0x2F,
      0x33,
      0x47,
      0x38,
      0x15,
      0x16,
      0x2C,
      0x32
    ])
    |> write_command(@st7796_cmdset, cmd_data: 0x3C)
    |> write_command(@st7796_cmdset, cmd_data: 0x69)
    |> set_mode(:normal)
    |> write_command(@st7796_invon)
    |> write_command(@st7796_dispon, delay: 100)
  end

  defp set_window(%__MODULE__{} = display, opts) do
    width = display.width
    height = display.height
    x_offset = display.x_offset
    y_offset = display.y_offset

    x0 = opts[:x0] || 0
    y0 = opts[:y0] || 0
    x1 = opts[:x1] || width - 1
    y1 = opts[:y1] || height - 1

    x0 = x0 + x_offset
    x1 = x1 + x_offset
    y0 = y0 + y_offset
    y1 = y1 + y_offset

    display
    |> write_command(@st7796_caset)
    |> write_data(bsr(x0, 8))
    |> write_data(band(x0, 0xFF))
    |> write_data(bsr(x1, 8))
    |> write_data(band(x1, 0xFF))
    |> write_command(@st7796_paset)
    |> write_data(bsr(y0, 8))
    |> write_data(band(y0, 0xFF))
    |> write_data(bsr(y1, 8))
    |> write_data(band(y1, 0xFF))
    |> write_command(@st7796_ramwr)
  end

  defp to_565(image_data, source_color, target_color) when is_binary(image_data) do
    image_data
    |> CvtColor.cvt(source_color, target_color)
    |> :binary.bin_to_list()
  end

  defp to_666(image_data, :bgr888, :bgr666) when is_binary(image_data) do
    image_data
    |> :binary.bin_to_list()
  end

  defp to_666(image_data, source_color, target_color) when is_binary(image_data) do
    image_data
    |> CvtColor.cvt(source_color, target_color)
    |> :binary.bin_to_list()
  end
end
