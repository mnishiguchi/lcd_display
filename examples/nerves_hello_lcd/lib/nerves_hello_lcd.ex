defmodule NervesHelloLcd do
  alias NervesHelloLcd.{DisplaySupervisor, DisplayController}

  @moduledoc """
  Some test programs for quick check.
  ## Examples
      test_fn = fn ->
        Process.sleep(5000)
        Task.start_link(fn -> NervesHelloLcd.hello_gpio() end)
        Task.start_link(fn -> NervesHelloLcd.hello_i2c() end)
      end
      test_fn.()
  """

  def hello_i2c(opts \\ %{}) do
    pid =
      DisplaySupervisor.display_controller(
        LcdDisplay.HD44780.I2C,
        Enum.into(
          opts,
          %{display_name: "display 1"}
        )
      )

    cursor_and_print(pid)
    backlight_off_on(pid)
    scroll_right_and_left(pid)

    DisplayController.execute(pid, :clear)
  end

  def hello_gpio(opts \\ %{}) do
    pid =
      DisplaySupervisor.display_controller(
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

    DisplayController.execute(pid, :clear)
  end

  defp cursor_and_print(pid) do
    DisplayController.execute(pid, {:cursor, true})
    DisplayController.execute(pid, {:print, "Hello"})
    Process.sleep(500)
    DisplayController.execute(pid, {:right, 1})
    DisplayController.execute(pid, {:print, "world"})
    Process.sleep(500)
    DisplayController.execute(pid, {:cursor, false})
    Process.sleep(500)
  end

  defp backlight_off_on(pid) do
    DisplayController.execute(pid, {:backlight, false})
    Process.sleep(500)
    DisplayController.execute(pid, {:backlight, true})
    Process.sleep(500)
  end

  defp scroll_right_and_left(pid) do
    0..3
    |> Enum.each(fn _ ->
      DisplayController.execute(pid, {:scroll, 1})
      Process.sleep(300)
    end)

    0..3
    |> Enum.each(fn _ ->
      DisplayController.execute(pid, {:scroll, -1})
      Process.sleep(300)
    end)
  end
end
