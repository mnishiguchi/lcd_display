defmodule NervesHelloLcd.Demo do
  alias NervesHelloLcd.{DisplaySupervisor, DisplayController}

  @doc """
  A test program for quick check.
  """
  def hello do
    pid =
      DisplaySupervisor.display_controller(
        LcdDisplay.HD44780.I2C,
        name: "display 1"
      )

    DisplayController.execute(pid, {:cursor, true})
    DisplayController.execute(pid, {:print, "Hello"})
    Process.sleep(300)
    DisplayController.execute(pid, {:right, 1})
    DisplayController.execute(pid, {:print, "world"})
    Process.sleep(300)
    DisplayController.execute(pid, {:cursor, false})
    Process.sleep(300)
    DisplayController.execute(pid, {:backlight, false})
    Process.sleep(300)
    DisplayController.execute(pid, {:backlight, true})
    Process.sleep(300)

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

    DisplayController.execute(pid, :clear)
  end
end
