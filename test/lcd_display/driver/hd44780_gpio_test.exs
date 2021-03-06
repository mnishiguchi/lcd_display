defmodule LcdDisplay.HD44780.GPIOTest do
  use ExUnit.Case, async: true

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LcdDisplay.HD44780

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    Mox.stub_with(LcdDisplay.MockGPIO, LcdDisplay.GPIO.Stub)
    :ok
  end

  test "LcdDisplay.GPIO mock works" do
    assert {:ok, gpio_ref} = LcdDisplay.GPIO.open(12, :output)
    assert :ok = LcdDisplay.GPIO.write(gpio_ref, 1)
    assert :ok = LcdDisplay.GPIO.write(gpio_ref, 0)
  end

  test "start display" do
    {:ok, display} = HD44780.GPIO.start(default_config())

    assert %{
             driver_module: LcdDisplay.HD44780.GPIO,
             font_size: "5x8",
             rows: 2,
             cols: 16,
             pin_rs: 1,
             pin_rw: 2,
             pin_en: 3,
             pin_d4: 7,
             pin_d5: 8,
             pin_d6: 9,
             pin_d7: 10,
             pin_led: 12,
             ref_rs: ref_rs,
             ref_rw: ref_rw,
             ref_en: ref_en,
             ref_d4: ref_d4,
             ref_d5: ref_d5,
             ref_d6: ref_d6,
             ref_d7: ref_d7,
             ref_led: ref_led,
             entry_mode: 6,
             display_control: 12
           } = display

    assert is_reference(ref_rs)
    assert is_reference(ref_rw)
    assert is_reference(ref_en)
    assert is_reference(ref_d4)
    assert is_reference(ref_d5)
    assert is_reference(ref_d6)
    assert is_reference(ref_d7)
    assert is_reference(ref_led)
  end

  describe "required config keys" do
    test "start with missing required keys" do
      c = default_config()
      assert {:error, %KeyError{}} = HD44780.GPIO.start(Map.drop(c, [:pin_rs]))
      assert {:error, %KeyError{}} = HD44780.GPIO.start(Map.drop(c, [:pin_en]))
      assert {:error, %KeyError{}} = HD44780.GPIO.start(Map.drop(c, [:pin_d4]))
      assert {:error, %KeyError{}} = HD44780.GPIO.start(Map.drop(c, [:pin_d5]))
      assert {:error, %KeyError{}} = HD44780.GPIO.start(Map.drop(c, [:pin_d6]))
      assert {:error, %KeyError{}} = HD44780.GPIO.start(Map.drop(c, [:pin_d7]))
    end
  end

  describe "commands" do
    setup do
      with {:ok, display} <- HD44780.GPIO.start(default_config()), do: %{display: display}
    end

    test "execute valid commands", %{display: d} do
      assert {:ok, %{}} = HD44780.GPIO.execute(d, :clear)
      assert {:ok, %{}} = HD44780.GPIO.execute(d, :home)
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:print, "Hello"})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:set_cursor, 2, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:cursor, false})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:cursor, true})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:blink, false})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:blink, true})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:autoscroll, false})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:autoscroll, true})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:scroll, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:left, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:right, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:backlight, false})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:backlight, true})
    end

    test "execute unsupported commands", %{display: d} do
      assert {:error, {:unsupported, _command}} = HD44780.GPIO.execute(d, {:write, "Hello"})
      assert {:error, {:unsupported, _command}} = HD44780.GPIO.execute(d, {:text_direction, false})
      assert {:error, {:unsupported, _command}} = HD44780.GPIO.execute(d, {:char, "invalid args"})
    end

    test "change entry_mode", %{display: d} do
      assert {:ok, %{entry_mode: 4}} = HD44780.GPIO.execute(d, {:text_direction, :right_to_left})
      assert {:ok, %{entry_mode: 6}} = HD44780.GPIO.execute(d, {:text_direction, :left_to_right})
    end

    test "change display_control", %{display: d} do
      assert {:ok, %{display_control: 8}} = HD44780.GPIO.execute(d, {:display, false})
      assert {:ok, %{display_control: 12}} = HD44780.GPIO.execute(d, {:display, true})
    end
  end

  defp default_config do
    %{
      rows: 2,
      cols: 16,
      font_size: "5x8",
      pin_rs: 1,
      pin_rw: 2,
      pin_en: 3,
      pin_d4: 7,
      pin_d5: 8,
      pin_d6: 9,
      pin_d7: 10,
      pin_led: 12
    }
  end
end
