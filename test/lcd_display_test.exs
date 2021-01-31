defmodule LcdDisplayTest do
  use ExUnit.Case

  # https://hexdocs.pm/mox/Mox.html
  import Mox

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
    config = %{
      driver_module: LcdDisplay.MockHD44780,
      display_name: "display one",
      i2c_address: 39,
      cols: 16,
      rows: 2
    }

    assert {:ok, pid} = LcdDisplay.start_link(config)

    # This does not guarantee what happens on the hardware but at least demonstrates how the API works.
    assert {:ok, _display} = LcdDisplay.execute(pid, {:print, "Hello"})
  end
end
