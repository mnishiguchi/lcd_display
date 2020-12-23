defmodule LcdDisplay.DisplaySupervisorTest do
  use ExUnit.Case

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LcdDisplay.DisplaySupervisor

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  test "should be already started" do
    setup_display_driver_mock("display one")
    assert {:error, {:already_started, _pid}} = DisplaySupervisor.start_link(nil)
  end

  describe "display_controller" do
    test "returns the same pid for the same display name" do
      setup_display_driver_mock("display 1")

      pid1 =
        DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver,
          display_name: "display 1"
        )

      pid2 =
        DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver,
          display_name: "display 1"
        )

      assert is_pid(pid1)
      assert pid1 == pid2
    end

    test "returns a different pid for a different display name" do
      setup_display_driver_mock("display 1")

      pid1 =
        DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver,
          display_name: "display 1"
        )

      setup_display_driver_mock("display 2")

      pid2 =
        DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver,
          display_name: "display 2"
        )

      assert pid1 != pid2
    end
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
