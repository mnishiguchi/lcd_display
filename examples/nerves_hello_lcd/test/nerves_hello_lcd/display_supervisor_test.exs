defmodule NervesHelloLcd.DisplaySupervisorTest do
  use ExUnit.Case

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias NervesHelloLcd.DisplaySupervisor

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  test "should be already started" do
    setup_display_driver_mock(name: "display one")
    assert {:error, {:already_started, _pid}} = DisplaySupervisor.start_link(nil)
  end

  describe "display_controller" do
    test "returns the same pid for the same display name" do
      setup_display_driver_mock(name: "display 1")
      pid1 = DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver, name: "display 1")
      pid2 = DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver, name: "display 1")

      assert is_pid(pid1)
      assert pid1 == pid2
    end

    test "returns a different pid for a different display name" do
      setup_display_driver_mock(name: "display 1")
      pid1 = DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver, name: "display 1")

      setup_display_driver_mock(name: "display 2")
      pid2 = DisplaySupervisor.display_controller(LcdDisplay.MockDisplayDriver, name: "display 2")

      assert pid1 != pid2
    end
  end

  defp setup_display_driver_mock(display) do
    display_name = Keyword.fetch!(display, :name)

    # https://hexdocs.pm/mox/Mox.html#stub/3
    LcdDisplay.MockDisplayDriver
    |> stub(:start, fn _opts -> {:ok, display_stub(display_name)} end)
    |> stub(:execute, fn _display, _command -> {:ok, display_stub(display_name)} end)
  end

  defp display_stub(name) do
    %{
      driver_module: LcdDisplay.MockDisplayDriver,
      name: name,
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
