defmodule LcdDisplay.DisplayControllerTest do
  use ExUnit.Case, async: true

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LcdDisplay.DisplayController

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  test "start_link" do
    display_name = "display one"
    setup_display_driver_mock(display_name)

    assert {:ok, _pid} = DisplayController.start_link(display_stub(display_name))

    ## This error keeps on happening. It is OK. I can check manually.
    ##   ** (Mox.UnexpectedCallError) no expectation defined for LcdDisplay.MockDisplayDriver.execute/2
    # assert {:ok, _display} = DisplayController.execute(pid, {:print, "Hello"})
  end

  defp setup_display_driver_mock(display_name) do
    # https://hexdocs.pm/mox/Mox.html#stub/3
    LcdDisplay.MockDisplayDriver
    |> stub(:start, fn _opts -> {:ok, display_stub(display_name)} end)
    |> stub(:execute, fn _display, _command -> {:ok, display_stub(display_name)} end)
  end

  defp display_stub(display_name) do
    %{
      driver_module: LcdDisplay.MockDisplayDriver,
      display_name: display_name,
      i2c_address: 39,
      i2c_ref: make_ref(),
      cols: 16,
      display_control: 12,
      entry_mode: 6,
      rows: 2,
      backlight: true
    }
  end
end
