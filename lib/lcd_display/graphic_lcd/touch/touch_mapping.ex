defmodule LcdDisplay.TouchMapping do
  @moduledoc false

  @enforce_keys [
    :screen_width,
    :screen_height,
    :raw_x_min,
    :raw_x_max,
    :raw_y_min,
    :raw_y_max
  ]
  defstruct [
    :screen_width,
    :screen_height,
    :raw_x_min,
    :raw_x_max,
    :raw_y_min,
    :raw_y_max,
    swap_xy: false,
    invert_x: false,
    invert_y: false,
    rotation: 0
  ]

  def new(opts) do
    screen_width = Keyword.fetch!(opts, :screen_width)
    screen_height = Keyword.fetch!(opts, :screen_height)

    raw_x_min = Keyword.fetch!(opts, :raw_x_min)
    raw_x_max = Keyword.fetch!(opts, :raw_x_max)
    raw_y_min = Keyword.fetch!(opts, :raw_y_min)
    raw_y_max = Keyword.fetch!(opts, :raw_y_max)

    swap_xy = Keyword.get(opts, :swap_xy, false)
    invert_x = Keyword.get(opts, :invert_x, false)
    invert_y = Keyword.get(opts, :invert_y, false)
    rotation = normalize_rotation(Keyword.get(opts, :rotation, 0))

    %__MODULE__{
      screen_width: screen_width,
      screen_height: screen_height,
      raw_x_min: raw_x_min,
      raw_x_max: raw_x_max,
      raw_y_min: raw_y_min,
      raw_y_max: raw_y_max,
      swap_xy: swap_xy,
      invert_x: invert_x,
      invert_y: invert_y,
      rotation: rotation
    }
  end

  def to_screen(%__MODULE__{} = mapping, raw_x, raw_y)
      when is_integer(raw_x) and is_integer(raw_y) do
    {nx0, ny0} =
      {
        normalize(raw_x, mapping.raw_x_min, mapping.raw_x_max),
        normalize(raw_y, mapping.raw_y_min, mapping.raw_y_max)
      }

    {nx, ny} =
      if mapping.swap_xy do
        {ny0, nx0}
      else
        {nx0, ny0}
      end

    nx = maybe_invert(nx, mapping.invert_x)
    ny = maybe_invert(ny, mapping.invert_y)

    rotation = mapping.rotation

    {panel_w, panel_h} =
      case rotation do
        0 -> {mapping.screen_width, mapping.screen_height}
        180 -> {mapping.screen_width, mapping.screen_height}
        90 -> {mapping.screen_height, mapping.screen_width}
        270 -> {mapping.screen_height, mapping.screen_width}
      end

    px = frac_to_int(nx, panel_w)
    py = frac_to_int(ny, panel_h)

    {sx, sy} =
      case rotation do
        0 -> {px, py}
        180 -> {mapping.screen_width - 1 - px, mapping.screen_height - 1 - py}
        90 -> {panel_h - 1 - py, px}
        270 -> {py, panel_w - 1 - px}
      end

    {sx, sy}
  end

  defp normalize(raw, from, to) do
    cond do
      from == to ->
        0.0

      true ->
        f = (raw - from) / (to - from)

        cond do
          f <= 0.0 -> 0.0
          f >= 1.0 -> 1.0
          true -> f
        end
    end
  end

  defp maybe_invert(v, false), do: v
  defp maybe_invert(v, true), do: 1.0 - v

  defp frac_to_int(_f, size) when size <= 1, do: 0

  defp frac_to_int(f, size) do
    f =
      cond do
        f < 0.0 -> 0.0
        f > 1.0 -> 1.0
        true -> f
      end

    trunc(f * (size - 1))
  end

  defp normalize_rotation(rot) when rot in [0, 90, 180, 270], do: rot

  defp normalize_rotation(rot) when is_integer(rot) do
    r =
      rot
      |> rem(360)
      |> Kernel.+(360)
      |> rem(360)

    case r do
      v when v in [0, 90, 180, 270] -> v
      _ -> 0
    end
  end
end
