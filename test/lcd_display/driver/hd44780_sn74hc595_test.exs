defmodule LcdDisplay.HD44780.SN74HC595Test do
  use ExUnit.Case, async: true

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LcdDisplay.HD44780

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    Mox.stub_with(LcdDisplay.MockSPI, LcdDisplay.SPI.Stub)
    :ok
  end

  test "LcdDisplay.SPI mock works" do
    assert {:ok, spi_ref} = LcdDisplay.SPI.open("spidev0.0")
    assert {:ok, "received data"} = LcdDisplay.SPI.transfer(spi_ref, <<0x00, 0x0F>>)
  end

  test "start with blank options" do
    assert {:ok, display} = HD44780.SN74HC595.start(%{})

    assert %{
             driver_module: LcdDisplay.HD44780.SN74HC595,
             spi_ref: spi_ref,
             rows: 2,
             cols: 16,
             entry_mode: 6,
             display_control: 12,
             backlight: true
           } = display

    assert is_reference(spi_ref)
  end

  test "start with some options" do
    opts = %{rows: 4, cols: 20}
    {:ok, display} = HD44780.SN74HC595.start(opts)
    assert %{rows: 4, cols: 20} = display
  end

  describe "commands" do
    setup do
      with {:ok, display} <- HD44780.SN74HC595.start(%{}), do: %{display: display}
    end

    test "execute valid commands", %{display: d} do
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, :clear)
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, :home)
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:print, "Hello"})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:set_cursor, 2, 2})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:cursor, false})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:cursor, true})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:blink, false})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:blink, true})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:autoscroll, false})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:autoscroll, true})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:scroll, 2})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:left, 2})
      assert {:ok, %{}} = HD44780.SN74HC595.execute(d, {:right, 2})
    end

    test "execute unsupported commands", %{display: d} do
      assert {:error, {:unsupported, _command}} = HD44780.SN74HC595.execute(d, {:write, 'H'})
      assert {:error, {:unsupported, _command}} = HD44780.SN74HC595.execute(d, {:text_direction, false})
      assert {:error, {:unsupported, _command}} = HD44780.SN74HC595.execute(d, {:char, "invalid args"})
    end

    test "change entry_mode", %{display: d} do
      assert {:ok, %{entry_mode: 4}} = HD44780.SN74HC595.execute(d, {:text_direction, :right_to_left})
      assert {:ok, %{entry_mode: 6}} = HD44780.SN74HC595.execute(d, {:text_direction, :left_to_right})
    end

    test "change display_control", %{display: d} do
      assert {:ok, %{display_control: 8}} = HD44780.SN74HC595.execute(d, {:display, false})
      assert {:ok, %{display_control: 12}} = HD44780.SN74HC595.execute(d, {:display, true})
    end

    test "change backlight", %{display: d} do
      assert {:ok, %{backlight: false}} = HD44780.SN74HC595.execute(d, {:backlight, false})
      assert {:ok, %{backlight: true}} = HD44780.SN74HC595.execute(d, {:backlight, true})
    end
  end
end
