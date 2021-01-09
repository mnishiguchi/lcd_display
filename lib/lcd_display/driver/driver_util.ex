defmodule LcdDisplay.DriverUtil do
  @moduledoc """
  A collection of utility functions that are used for display drivers.
  """

  @typep num_rows :: pos_integer()
  @typep num_cols :: pos_integer()
  @typep row_pos :: non_neg_integer()
  @typep col_pos :: non_neg_integer()

  @doc """
  Determines a cursor position based on the display configuration (rows and columns)
  and the zero-indexed cursor position (row and column).

  ## Examples

      iex> LcdDisplay.DriverUtil.determine_cursor_position({2, 16}, {0,0})
      0

      iex> LcdDisplay.DriverUtil.determine_cursor_position({2, 16}, {0,15})
      15

      iex> LcdDisplay.DriverUtil.determine_cursor_position({2, 16}, {1,0})
      64

      iex> LcdDisplay.DriverUtil.determine_cursor_position({2, 16}, {1,15})
      79
  """
  @spec determine_cursor_position({num_rows(), num_cols()}, {row_pos(), col_pos()}) :: non_neg_integer
  def determine_cursor_position({num_rows, num_cols}, {row_pos, col_pos})
      when is_number(num_rows) and is_number(num_cols) and
             is_number(row_pos) and is_number(col_pos) and
             num_rows >= 1 and num_rows >= 1 and
             row_pos >= 0 and col_pos >= 0 do
    col_pos = min(col_pos, num_cols - 1)
    row_pos = min(row_pos, num_rows - 1)

    num_cols
    |> row_offsets_for_num_cols()
    |> elem(row_pos)
    |> Kernel.+(col_pos)
  end

  @doc """
  Determine a list of row offsets based on how many columns the display has.

  ## Examples

  iex> LcdDisplay.DriverUtil.row_offsets_for_num_cols(8)
  {0, 64, 8, 72}

  iex> LcdDisplay.DriverUtil.row_offsets_for_num_cols(16)
  {0, 64, 16, 80}

  iex> LcdDisplay.DriverUtil.row_offsets_for_num_cols(20)
  {0, 64, 20, 84}
  """
  @spec row_offsets_for_num_cols(num_cols) :: {0, 64, pos_integer, pos_integer}
  def row_offsets_for_num_cols(num_cols) when is_number(num_cols) and num_cols >= 1 do
    {
      0x00,
      0x40,
      0x00 + num_cols,
      0x40 + num_cols
    }
  end
end
