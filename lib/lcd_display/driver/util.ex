defmodule LcdDisplay.DisplayDriver.Util do
  @moduledoc """
  A collection of utility functions that are used for display drivers.
  """

  @doc """
  Determines a cursor position based on the number of rows, the number of columns,
  and the zero-indexed cursor row and column.

  ## Examples

      iex> LcdDisplay.DisplayDriver.Util.determine_cursor_position({2, 16}, {0,0})
      0
      iex> LcdDisplay.DisplayDriver.Util.determine_cursor_position({2, 16}, {0,15})
      15
      iex> LcdDisplay.DisplayDriver.Util.determine_cursor_position({2, 16}, {1,0})
      64
      iex> LcdDisplay.DisplayDriver.Util.determine_cursor_position({2, 16}, {1,15})
      79
  """
  def determine_cursor_position({num_rows, num_cols}, {row, col})
      when num_rows >= 1 and num_cols >= 16 and row >= 0 and col >= 0 do
    col = min(col, num_cols - 1)
    row = min(row, num_rows - 1)
    num_cols |> row_offsets() |> elem(row) |> Kernel.+(col)
  end

  defp row_offsets(num_cols) when num_cols >= 16 do
    {0x00, 0x40, 0x00 + num_cols, 0x40 + num_cols}
  end
end
