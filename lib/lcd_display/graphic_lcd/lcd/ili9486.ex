defmodule LcdDisplay.ILI9486 do
  use LcdDisplay.DisplayDriver, driver_impl: LcdDisplay.ILI9486.DriverImpl
end

defmodule LcdDisplay.ILI9486.DriverImpl do
  require Logger
  import Bitwise

  import LcdDisplay.Utils,
    only: [
      open_spi_with_retry: 2,
      maybe_open_gpio: 2
    ]

  @behaviour LcdDisplay.DisplayDriver.DisplayContract

  # @ili9486_nop 0x00
  @ili9486_swreset 0x01

  # @ili9486_rddid 0x04
  # @ili9486_rddst 0x09
  # @ili9486_rdmode 0x0A
  # @ili9486_rdmadctl 0x0B
  # @ili9486_rdpixfmt 0x0C
  # @ili9486_rdimgfmt 0x0D
  # @ili9486_rdselfdiag 0x0F

  # @ili9486_slpin 0x10
  @ili9486_slpout 0x11
  @ili9486_ptlon 0x12
  @ili9486_noron 0x13

  @ili9486_invoff 0x20
  @ili9486_invon 0x21
  # @ili9486_gammaset 0x26
  @ili9486_dispoff 0x28
  @ili9486_dispon 0x29

  @ili9486_caset 0x2A
  @ili9486_paset 0x2B
  @ili9486_ramwr 0x2C
  # @ili9486_ramrd 0x2E

  # @ili9486_ptlar 0x30
  # @ili9486_vscrdef 0x33
  @ili9486_madctl 0x36
  # @ili9486_vscrsadd 0x37
  # @ili9486_idleoff 0x38
  @ili9486_idleon 0x39
  @ili9486_pixfmt 0x3A

  @ili9486_rgb_interface 0xB0
  @ili9486_frmctr1 0xB1
  # @ili9486_frmctr2 0xB2
  # @ili9486_frmctr3 0xB3
  # @ili9486_invctr 0xB4
  # @ili9486_dfunctr 0xB6

  # @ili9486_pwctr1 0xC0
  # @ili9486_pwctr2 0xC1
  @ili9486_pwctr3 0xC2
  # @ili9486_pwctr4 0xC3
  # @ili9486_pwctr5 0xC4
  @ili9486_vmctr1 0xC5
  # @ili9486_vmctr2 0xC7

  # @ili9486_rdid1 0xDA
  # @ili9486_rdid2 0xDB
  # @ili9486_rdid3 0xDC
  # @ili9486_rdid4 0xDD

  @ili9486_gmctrp1 0xE0
  @ili9486_gmctrn1 0xE1
  @ili9486_dgctr1 0xE2
  # @ili9486_dgctr2 0xE3

  @ili9486_mad_rgb 0x08
  @ili9486_mad_bgr 0x00
  @ili9486_18bit_pix 0x66
  @ili9486_16bit_pix 0x55

  @ili9486_mad_vertical 0x20
  @ili9486_mad_x_left 0x00
  @ili9486_mad_x_right 0x40
  @ili9486_mad_y_up 0x80
  @ili9486_mad_y_down 0x00

  # @ili9486_hispeedf1 0xF1
  # @ili9486_hispeedf2 0xF2
  # @ili9486_hispeedf8 0xF8
  # @ili9486_hispeedf9 0xF9

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
    :frame_rate_hz,
    :frame_divider,
    :frame_cycles,
    :invert_colors,
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
    :frame_rate_hz,
    :frame_divider,
    :frame_cycles,
    :invert_colors,
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
    frame_rate_hz = opts[:frame_rate_hz] || 70
    frame_divider = opts[:frame_divider] || 0b00
    frame_cycles = opts[:frame_cycles] || 0b10001
    data_bus = opts[:data_bus] || :parallel_8bit
    invert_colors = opts[:invert_colors] || false

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
          frame_rate_hz: frame_rate_hz,
          frame_divider: frame_divider,
          frame_cycles: frame_cycles,
          invert_colors: invert_colors,
          chunk_size: chunk_size
        }
        |> reset()
        |> init_sequence(data_bus)

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
    |> write_command(@ili9486_pixfmt, cmd_data: pixfmt_data(display))
    |> write_command(@ili9486_madctl, cmd_data: madctl_data(display))
  end

  @impl true
  def set_power(%__MODULE__{} = display, status) when status in [:on, :off] do
    case status do
      :on -> write_command(display, @ili9486_dispon)
      :off -> write_command(display, @ili9486_dispoff)
    end
  end

  @impl true
  def set_mode(%__MODULE__{} = display, display_mode) do
    case display_mode do
      :normal ->
        %__MODULE__{display | display_mode: :normal}
        |> write_command(@ili9486_noron)

      :partial ->
        %__MODULE__{display | display_mode: :partial}
        |> write_command(@ili9486_ptlon)

      :idle ->
        %__MODULE__{display | display_mode: :idle}
        |> write_command(@ili9486_idleon)
    end
  end

  @impl true
  def set_frame_rate(%__MODULE__{} = display, frame_rate_hz) do
    display_mode = display.display_mode
    frame_divider = display.frame_divider
    frame_cycles = display.frame_cycles

    index =
      display_mode
      |> valid_frame_rates()
      |> Enum.find_index(&(&1 == frame_rate_hz))

    p1 =
      index
      |> bsl(4)
      |> bor(frame_divider)

    %__MODULE__{display | frame_rate_hz: frame_rate_hz}
    |> write_command(@ili9486_frmctr1)
    |> write_data(p1)
    |> write_data(frame_cycles)
  end

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

  defp valid_frame_rates(:normal) do
    [28, 30, 32, 34, 36, 39, 42, 46, 50, 56, 62, 70, 81, 96, 117]
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

  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :rgb565}), do: @ili9486_mad_rgb
  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :bgr565}), do: @ili9486_mad_bgr
  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :rgb666}), do: @ili9486_mad_rgb
  defp mad_rgb_or_bgr(%__MODULE__{pixel_format: :bgr666}), do: @ili9486_mad_bgr

  defp pixfmt_data(%__MODULE__{pixel_format: :rgb565}), do: @ili9486_16bit_pix
  defp pixfmt_data(%__MODULE__{pixel_format: :bgr565}), do: @ili9486_16bit_pix
  defp pixfmt_data(%__MODULE__{pixel_format: :rgb666}), do: @ili9486_18bit_pix
  defp pixfmt_data(%__MODULE__{pixel_format: :bgr666}), do: @ili9486_18bit_pix

  defp madctl_data(%__MODULE__{rotation: 0, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_right)
    |> bor(@ili9486_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 90, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_left)
    |> bor(@ili9486_mad_y_down)
    |> bor(@ili9486_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 180, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_left)
    |> bor(@ili9486_mad_y_up)
  end

  defp madctl_data(%__MODULE__{rotation: 270, scan_direction: :right_down} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_right)
    |> bor(@ili9486_mad_y_up)
    |> bor(@ili9486_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 0, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_right)
    |> bor(@ili9486_mad_y_up)
  end

  defp madctl_data(%__MODULE__{rotation: 90, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_right)
    |> bor(@ili9486_mad_y_down)
    |> bor(@ili9486_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 180, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_left)
    |> bor(@ili9486_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 270, scan_direction: :right_up} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_left)
    |> bor(@ili9486_mad_y_up)
    |> bor(@ili9486_mad_vertical)
  end

  defp madctl_data(%__MODULE__{rotation: 0, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_left)
    |> bor(@ili9486_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 90, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_right)
    |> bor(@ili9486_mad_y_down)
  end

  defp madctl_data(%__MODULE__{rotation: 180, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_right)
    |> bor(@ili9486_mad_y_up)
  end

  defp madctl_data(%__MODULE__{rotation: 270, scan_direction: :rgb_mode} = display) do
    display
    |> mad_rgb_or_bgr()
    |> bor(@ili9486_mad_x_left)
    |> bor(@ili9486_mad_y_up)
  end

  defp set_inversion(%__MODULE__{} = display) do
    cmd = if display.invert_colors, do: @ili9486_invon, else: @ili9486_invoff
    write_command(display, cmd)
  end

  defp init_sequence(%__MODULE__{} = display, :parallel_8bit) do
    frame_rate_hz = display.frame_rate_hz

    display
    |> write_command(@ili9486_swreset, delay: 120)
    |> write_command(@ili9486_rgb_interface, cmd_data: 0x00)
    |> write_command(@ili9486_slpout, delay: 200)
    |> write_command(@ili9486_pixfmt, cmd_data: pixfmt_data(display))
    |> write_command(@ili9486_madctl, cmd_data: madctl_data(display))
    |> write_command(@ili9486_pwctr3, cmd_data: 0x44)
    |> write_command(@ili9486_vmctr1)
    |> write_data(0x00)
    |> write_data(0x00)
    |> write_data(0x00)
    |> write_data(0x00)
    |> write_command(@ili9486_gmctrp1)
    |> write_data(0x0F)
    |> write_data(0x1F)
    |> write_data(0x1C)
    |> write_data(0x0C)
    |> write_data(0x0F)
    |> write_data(0x08)
    |> write_data(0x48)
    |> write_data(0x98)
    |> write_data(0x37)
    |> write_data(0x0A)
    |> write_data(0x13)
    |> write_data(0x04)
    |> write_data(0x11)
    |> write_data(0x0D)
    |> write_data(0x00)
    |> write_command(@ili9486_gmctrn1)
    |> write_data(0x0F)
    |> write_data(0x32)
    |> write_data(0x2E)
    |> write_data(0x0B)
    |> write_data(0x0D)
    |> write_data(0x05)
    |> write_data(0x47)
    |> write_data(0x75)
    |> write_data(0x37)
    |> write_data(0x06)
    |> write_data(0x10)
    |> write_data(0x03)
    |> write_data(0x24)
    |> write_data(0x20)
    |> write_data(0x00)
    |> write_command(@ili9486_dgctr1)
    |> write_data(0x0F)
    |> write_data(0x32)
    |> write_data(0x2E)
    |> write_data(0x0B)
    |> write_data(0x0D)
    |> write_data(0x05)
    |> write_data(0x47)
    |> write_data(0x75)
    |> write_data(0x37)
    |> write_data(0x06)
    |> write_data(0x10)
    |> write_data(0x03)
    |> write_data(0x24)
    |> write_data(0x20)
    |> write_data(0x00)
    |> set_mode(:normal)
    |> set_inversion()
    |> write_command(@ili9486_slpout, delay: 200)
    |> write_command(@ili9486_dispon)
    |> set_frame_rate(frame_rate_hz)
  end

  defp init_sequence(%__MODULE__{} = display, :parallel_16bit) do
    frame_rate_hz = display.frame_rate_hz

    display
    |> write_command(@ili9486_swreset, delay: 120)
    |> write_command(@ili9486_rgb_interface, cmd_data: 0x00)
    |> write_command(@ili9486_slpout, delay: 250)
    |> write_command(@ili9486_pixfmt, cmd_data: pixfmt_data(display))
    |> write_command(@ili9486_pwctr3, cmd_data: 0x44)
    |> write_command(@ili9486_vmctr1, cmd_data: [0x00, 0x00, 0x00, 0x00])
    |> write_command(@ili9486_gmctrp1)
    |> write_data(0x0F)
    |> write_data(0x1F)
    |> write_data(0x1C)
    |> write_data(0x0C)
    |> write_data(0x0F)
    |> write_data(0x08)
    |> write_data(0x48)
    |> write_data(0x98)
    |> write_data(0x37)
    |> write_data(0x0A)
    |> write_data(0x13)
    |> write_data(0x04)
    |> write_data(0x11)
    |> write_data(0x0D)
    |> write_data(0x00)
    |> write_command(@ili9486_gmctrn1)
    |> write_data(0x0F)
    |> write_data(0x32)
    |> write_data(0x2E)
    |> write_data(0x0B)
    |> write_data(0x0D)
    |> write_data(0x05)
    |> write_data(0x47)
    |> write_data(0x75)
    |> write_data(0x37)
    |> write_data(0x06)
    |> write_data(0x10)
    |> write_data(0x03)
    |> write_data(0x24)
    |> write_data(0x20)
    |> write_data(0x00)
    |> write_command(@ili9486_dgctr1)
    |> write_data(0x0F)
    |> write_data(0x32)
    |> write_data(0x2E)
    |> write_data(0x0B)
    |> write_data(0x0D)
    |> write_data(0x05)
    |> write_data(0x47)
    |> write_data(0x75)
    |> write_data(0x37)
    |> write_data(0x06)
    |> write_data(0x10)
    |> write_data(0x03)
    |> write_data(0x24)
    |> write_data(0x20)
    |> write_data(0x00)
    |> set_mode(:normal)
    |> set_inversion()
    |> write_command(@ili9486_dispon, delay: 100)
    |> write_command(@ili9486_madctl, cmd_data: madctl_data(display))
    |> set_frame_rate(frame_rate_hz)
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
    |> write_command(@ili9486_caset)
    |> write_data(bsr(x0, 8))
    |> write_data(band(x0, 0xFF))
    |> write_data(bsr(x1, 8))
    |> write_data(band(x1, 0xFF))
    |> write_command(@ili9486_paset)
    |> write_data(bsr(y0, 8))
    |> write_data(band(y0, 0xFF))
    |> write_data(bsr(y1, 8))
    |> write_data(band(y1, 0xFF))
    |> write_command(@ili9486_ramwr)
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
