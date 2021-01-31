defmodule LcdDisplay.DisplayControllerTest do
  use ExUnit.Case

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LcdDisplay.DisplayController

  # Any process can consume mocks and stubs defined in your tests
  setup :set_mox_from_context

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Use a fake display driver
    Mox.stub_with(LcdDisplay.MockHD44780, LcdDisplay.HD44780.Stub)
    :ok
  end

  test "start_link" do
    display = %{
      driver_module: LcdDisplay.MockHD44780,
      i2c_address: 39,
      i2c_ref: make_ref(),
      cols: 16,
      display_control: 12,
      entry_mode: 6,
      rows: 2,
      backlight: true
    }

    assert {:ok, pid} = DisplayController.start_link(display)

    # This does not guarantee what happens on the hardware but tests at least the code does not crash
    assert {:ok, _display} = DisplayController.execute(pid, {:print, "Hello"})
  end
end
