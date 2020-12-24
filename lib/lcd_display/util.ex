defmodule LcdDisplay.Util do
  @doc """
  Determines a cursor position based on:
  - the number of rows and the number of columns as a tuple
  - the zero-indexed cursor position (row and column) as a tuple
  ## Examples
      iex> LcdDisplay.Util.determine_cursor_position({2, 16}, {0,0})
      0
      iex> LcdDisplay.Util.determine_cursor_position({2, 16}, {15,0})
      64
      iex> LcdDisplay.Util.determine_cursor_position({2, 16}, {0,1})
      1
      iex> LcdDisplay.Util.determine_cursor_position({2, 16}, {15,1})
      65
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
