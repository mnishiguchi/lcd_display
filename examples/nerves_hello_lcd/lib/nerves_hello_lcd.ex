defmodule NervesHelloLcd do
  @moduledoc """
  Some test programs for quick check.
  """

  def hello_i2c(opts \\ %{}) do
    pid =
      LcdDisplay.start_display(
        LcdDisplay.HD44780.I2C,
        Enum.into(
          opts,
          %{display_name: "display 1"}
        )
      )

    cursor_and_print(pid)
    backlight_off_on(pid)
    scroll_right_and_left(pid)

    LcdDisplay.execute(pid, :clear)
  end

  def hello_gpio(opts \\ %{}) do
    pid =
      LcdDisplay.start_display(
        LcdDisplay.HD44780.GPIO,
        Enum.into(
          opts,
          %{
            display_name: "display 2",
            pin_rs: 5,
            pin_rw: 6,
            pin_en: 13,
            pin_d4: 23,
            pin_d5: 24,
            pin_d6: 25,
            pin_d7: 26,
            pin_led_5v: 12
          }
        )
      )

    cursor_and_print(pid)
    backlight_off_on(pid)
    scroll_right_and_left(pid)

    LcdDisplay.execute(pid, :clear)
  end

  defp cursor_and_print(pid) do
    LcdDisplay.execute(pid, {:cursor, true})
    LcdDisplay.execute(pid, {:print, "Hello"})
    Process.sleep(500)
    LcdDisplay.execute(pid, {:right, 1})
    LcdDisplay.execute(pid, {:print, "world"})
    Process.sleep(500)
    LcdDisplay.execute(pid, {:cursor, false})
    Process.sleep(500)
  end

  defp backlight_off_on(pid) do
    LcdDisplay.execute(pid, {:backlight, false})
    Process.sleep(500)
    LcdDisplay.execute(pid, {:backlight, true})
    Process.sleep(500)
  end

  defp scroll_right_and_left(pid) do
    0..3
    |> Enum.each(fn _ ->
      LcdDisplay.execute(pid, {:scroll, 1})
      Process.sleep(300)
    end)

    0..3
    |> Enum.each(fn _ ->
      LcdDisplay.execute(pid, {:scroll, -1})
      Process.sleep(300)
    end)
  end
end
