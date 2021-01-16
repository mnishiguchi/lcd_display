defmodule LcdDisplay.HD44780.MCP23017Test do
  use ExUnit.Case, async: true

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LcdDisplay.HD44780

  setup do
    setup_i2c_mock()
    :ok
  end

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  test "LcdDisplay.I2C mock works" do
    assert {:ok, i2c_ref} = LcdDisplay.I2C.open("i2c-1")
    assert :ok = LcdDisplay.I2C.write(i2c_ref, 0x20, <<0x00, 0x0F>>)
  end

  test "start with blank options" do
    assert {:ok, display} = HD44780.MCP23017.start(%{})

    assert %{
             driver_module: LcdDisplay.HD44780.MCP23017,
             i2c_address: 0x20,
             display_name: "i2c-1",
             i2c_ref: i2c_ref,
             rows: 2,
             cols: 16,
             entry_mode: 6,
             display_control: 12,
             backlight: true
           } = display

    assert is_reference(i2c_ref)
  end

  test "start with some options" do
    opts = %{i2c_address: 0x3F, display_name: "Display 1", rows: 4, cols: 20}
    {:ok, display} = HD44780.MCP23017.start(opts)
    assert %{i2c_address: 0x3F, display_name: "Display 1", rows: 4, cols: 20} = display
  end

  describe "commands" do
    setup do
      with {:ok, display} <- HD44780.MCP23017.start(%{}), do: %{display: display}
    end

    test "execute valid commands", %{display: d} do
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, :clear)
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, :home)
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:print, "Hello"})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:set_cursor, 2, 2})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:cursor, false})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:cursor, true})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:blink, false})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:blink, true})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:autoscroll, false})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:autoscroll, true})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:scroll, 2})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:left, 2})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:right, 2})
      assert {:ok, %{}} = HD44780.MCP23017.execute(d, {:char, 2, [1, 1, 1, 1, 1, 1, 1, 1]})
    end

    test "execute unsupported commands", %{display: d} do
      assert {:error, {:unsupported, _command}} = HD44780.MCP23017.execute(d, {:write, 'H'})
      assert {:error, {:unsupported, _command}} = HD44780.MCP23017.execute(d, {:text_direction, false})
      assert {:error, {:unsupported, _command}} = HD44780.MCP23017.execute(d, {:char, "invalid args"})
    end

    test "change entry_mode", %{display: d} do
      assert {:ok, %{entry_mode: 4}} = HD44780.MCP23017.execute(d, {:text_direction, :right_to_left})
      assert {:ok, %{entry_mode: 6}} = HD44780.MCP23017.execute(d, {:text_direction, :left_to_right})
    end

    test "change display_control", %{display: d} do
      assert {:ok, %{display_control: 8}} = HD44780.MCP23017.execute(d, {:display, false})
      assert {:ok, %{display_control: 12}} = HD44780.MCP23017.execute(d, {:display, true})
    end

    test "change backlight", %{display: d} do
      assert {:ok, %{backlight: false}} = HD44780.MCP23017.execute(d, {:backlight, false})
      assert {:ok, %{backlight: true}} = HD44780.MCP23017.execute(d, {:backlight, true})
    end
  end

  defp setup_i2c_mock() do
    # https://hexdocs.pm/mox/Mox.html#stub/3
    LcdDisplay.MockI2C
    |> stub(:open, fn _i2c_bus -> {:ok, Kernel.make_ref()} end)
    |> stub(:write, fn _ref, _address, _data -> :ok end)
  end
end
