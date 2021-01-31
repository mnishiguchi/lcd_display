defmodule NervesHelloLcd do
  @moduledoc """
  Some test programs for quick check.

  ## Examples

      NervesHelloLcd.hello_gpio
      NervesHelloLcd.hello_pcf8574
      NervesHelloLcd.hello_mcp23008
      NervesHelloLcd.hello_mcp23017
      NervesHelloLcd.hello_sn74hc595
  """

  def hello_pcf8574(opts \\ []), do: hello_i2c(LcdDisplay.HD44780.PCF8574, opts)

  def hello_mcp23008(opts \\ []), do: hello_i2c(LcdDisplay.HD44780.MCP23008, opts)

  def hello_mcp23017(opts \\ []) do
    {:ok, pid} = hello_i2c(LcdDisplay.HD44780.MCP23017, opts)

    0..5
    |> Enum.each(fn _ ->
      LcdDisplay.execute(pid, :random_color)
      Process.sleep(500)
    end)
  end

  def hello_i2c(driver_module, opts \\ []) do
    Circuits.I2C.detect_devices()
    config = opts |> Enum.into(%{driver_module: driver_module}) |> IO.inspect()

    {:ok, pid} = LcdDisplay.start_link(config)
    qa_steps(pid)
    pid
  end

  def hello_sn74hc595(opts \\ []), do: hello_spi(LcdDisplay.HD44780.SN74HC595, opts)

  def hello_spi(driver_module, opts \\ []) do
    config = opts |> Enum.into(%{driver_module: driver_module}) |> IO.inspect()

    {:ok, pid} = LcdDisplay.start_link(config)
    qa_steps(pid)
    pid
  end

  def hello_gpio(opts \\ []) do
    config =
      opts
      |> Enum.into(%{
        display_module: LcdDisplay.HD44780_GPIO,
        pin_rs: 5,
        pin_rw: 6,
        pin_en: 13,
        pin_d4: 23,
        pin_d5: 24,
        pin_d6: 25,
        pin_d7: 26,
        pin_led: 12
      })
      |> IO.inspect()

    {:ok, pid} = LcdDisplay.start_link(config)
    qa_steps(pid)
    pid
  end

  defp qa_steps(pid) do
    cursor_and_print(pid)
    blink_and_print(pid)
    backlight_off_on(pid)
    scroll_right_and_left(pid)
    autoscroll(pid)
    text_direction(pid)
    lgtm(pid)
    pid
  end

  defp cursor_and_print(pid) do
    introduction(pid, "Cursor")

    LcdDisplay.execute(pid, {:cursor, true})
    print_text(pid, 5)
    Process.sleep(1234)
  end

  defp blink_and_print(pid) do
    introduction(pid, "Blink")

    LcdDisplay.execute(pid, {:blink, true})
    print_text(pid, 5)
    Process.sleep(1234)
  end

  defp backlight_off_on(pid) do
    introduction(pid, "Backlight")

    LcdDisplay.execute(pid, {:backlight, false})
    Process.sleep(500)
    LcdDisplay.execute(pid, {:backlight, true})
    Process.sleep(1234)
  end

  defp scroll_right_and_left(pid) do
    introduction(pid, "Scroll")

    LcdDisplay.execute(pid, {:print, "<>"})

    0..3
    |> Enum.each(fn _ ->
      LcdDisplay.execute(pid, {:scroll, 1})
      Process.sleep(222)
    end)

    0..3
    |> Enum.each(fn _ ->
      LcdDisplay.execute(pid, {:scroll, -1})
      Process.sleep(222)
    end)

    Process.sleep(1234)
  end

  defp autoscroll(pid) do
    introduction(pid, "Autoscroll")

    LcdDisplay.execute(pid, {:autoscroll, true})
    LcdDisplay.execute(pid, {:set_cursor, 1, 15})
    print_text(pid)
    Process.sleep(1234)
  end

  defp text_direction(pid) do
    introduction(pid, "Text direction")
    LcdDisplay.execute(pid, {:set_cursor, 0, 15})
    LcdDisplay.execute(pid, {:text_direction, :right_to_left})
    print_text(pid)
    LcdDisplay.execute(pid, {:set_cursor, 1, 0})
    LcdDisplay.execute(pid, {:text_direction, :left_to_right})
    print_text(pid)
    Process.sleep(1234)
  end

  defp print_text(pid, limit \\ 16) do
    ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    |> Enum.take(limit)
    |> Enum.each(fn x ->
      {:ok, _} = LcdDisplay.execute(pid, {:print, "#{x}"})
      Process.sleep(222)
    end)
  end

  defp lgtm(pid) do
    LcdDisplay.execute(pid, :clear)
    LcdDisplay.execute(pid, {:set_cursor, 0, 0})
    LcdDisplay.execute(pid, {:print, "LGTM"})
  end

  defp introduction(pid, message) do
    LcdDisplay.execute(pid, :clear)

    # Default setup
    LcdDisplay.execute(pid, {:display, true})
    LcdDisplay.execute(pid, {:cursor, false})
    LcdDisplay.execute(pid, {:blink, false})
    LcdDisplay.execute(pid, {:autoscroll, false})

    # Print message and clear
    LcdDisplay.execute(pid, {:print, message})
    Process.sleep(1234)
    LcdDisplay.execute(pid, :clear)
  end
end
