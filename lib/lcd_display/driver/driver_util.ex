defmodule LcdDisplay.DriverUtil do
  @moduledoc """
  A collection of utility functions that are used for display drivers.
  """

  @type row_col_pos :: {non_neg_integer(), non_neg_integer()}

  @typedoc """
  Typically 2x16 or 4x20.
  """
  @type display_config :: %{
          required(:rows) => LcdDisplay.Driver.num_rows(),
          required(:cols) => LcdDisplay.Driver.num_cols(),
          any => any
        }

  @doc """
  Determines a Display Data RAM (DDRAM) address based on the display configuration (rows and columns)
  and the zero-indexed cursor position (row and column).

  ## Examples

      iex> LcdDisplay.DriverUtil.determine_ddram_address({0,0}, %{rows: 2, cols: 16})
      0

      iex> LcdDisplay.DriverUtil.determine_ddram_address({0,15}, %{rows: 2, cols: 16})
      15

      iex> LcdDisplay.DriverUtil.determine_ddram_address({1,0}, %{rows: 2, cols: 16})
      64

      iex> LcdDisplay.DriverUtil.determine_ddram_address({1,15}, %{rows: 2, cols: 16})
      79
  """
  @spec determine_ddram_address(row_col_pos, display_config) :: non_neg_integer
  def determine_ddram_address({row_pos, col_pos} = _row_col_pos, %{rows: num_rows, cols: num_cols} = _display_config)
      when is_number(num_rows) and is_number(num_cols) and
             is_number(row_pos) and is_number(col_pos) and
             num_rows >= 1 and num_rows >= 1 and
             row_pos >= 0 and col_pos >= 0 do
    col_pos = min(col_pos, num_cols - 1)
    row_pos = min(row_pos, num_rows - 1)

    num_cols
    |> ddram_row_offsets()
    |> elem(row_pos)
    |> Kernel.+(col_pos)
  end

  @doc """
  Determine a list of row offsets based on how many columns the display has.

  ```
  0x00: | ROW 0 | ROW 2 |
  0x40: | ROW 1 | ROW 3 |
  ```

  For more info, please refer to [Hitachi HD44780 datasheet](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf) page 10.

  ## Examples

      iex> LcdDisplay.DriverUtil.ddram_row_offsets(8)
      {0, 64, 8, 72}

      iex> LcdDisplay.DriverUtil.ddram_row_offsets(16)
      {0, 64, 16, 80}

      iex> LcdDisplay.DriverUtil.ddram_row_offsets(20)
      {0, 64, 20, 84}
  """
  @spec ddram_row_offsets(LcdDisplay.Driver.num_cols()) :: {0, 64, pos_integer, pos_integer}
  def ddram_row_offsets(num_cols) when is_number(num_cols) and num_cols >= 1 do
    {
      0x00,
      0x40,
      0x00 + num_cols,
      0x40 + num_cols
    }
  end
end
