defmodule Geo do
  def intersects?(line, polygon) do
    prev_point = List.last(polygon)
    intersects_helper(line, polygon, prev_point)
  end

  def intersections(line, polygon) do
    prev_point = List.last(polygon)
    intersects_helper(line, polygon, prev_point, [])
    |> Enum.filter(fn
      {:intersection, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:intersection, point} -> point end)
  end

  def intersection({a, _b} = line, polygon) do
    Enum.min_by(intersections(line, polygon), fn ip ->
      Vector.distance(a, ip)
    end, fn ->
      nil
    end)
  end

  defp intersects_helper(_line, [], _prev_point) do
    :nointersection
  end

  defp intersects_helper(line, [next_point|polygon], prev_point) do
    case line_segment_intersection(line, {prev_point, next_point}) do
      :parallel -> intersects_helper(line, polygon, next_point)
      :none -> intersects_helper(line, polygon, next_point)
      :on_segment -> :on_segment
      {:intersection, _} = result -> result
    end
  end

  defp intersects_helper(_line, [], _prev_point, acc) do
    acc
  end

  defp intersects_helper(line, [next_point|polygon], prev_point, acc) when is_list(acc) do
    v = line_segment_intersection(line, {prev_point, next_point})
    intersects_helper(line, polygon, next_point, acc ++ [v])
  end

  defp line_segment_intersection({{x1, y1}, {x2, y2}}, {{x3, y3}, {x4, y4}}) do
    den = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)

    if den == 0 do
      if (y3 - y1) * (x2 - x1) == (x3 - x1) * (y2 - y1) do
        :on_segment
      else
        :parallel
      end
    else
      ua = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / den
      ub = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / den

      if ua >= 0.0 and ua <= 1.0 and ub >= 0.0 and ub <= 1.0 do
        {x, y} = {x1 + ua * (x2 - x1), y1 + ua * (y2 - y1)}
        {:intersection, {x, y}}
      else
        :none
      end
    end
  end
end
