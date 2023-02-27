defmodule Geo do
  require Logger

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

  @doc"""
  Split polygon into concave and convex vertices.

  ## Params
  * `polygon`, a list of `{x, y}` tuples outlining a polygon. This must be non-closed.

  Returns `{list of concave vertices, list of convex}`.
  """
  def classify_vertices(polygon) do
    # We prepend the last vertex (-1) to the list and chunk into threes. That
    # way we have a list of triples that describe each {prev, current, next}
    # vertex set. We apply the logic to determine if it's concave. Finally
    # split by concave and filter out the boolean.
    {concave, convex} =
      Enum.chunk_every([Enum.at(polygon, -1)] ++ polygon, 3, 1, Enum.slice(polygon, 0, 2))
      |> Enum.map(fn [prev, current, next] ->
        left = Vector.sub(current, prev)
        right = Vector.sub(next, current)
        {current, Vector.cross(left, right) < 0}
      end)
      |> Enum.split_with(fn {_, is_concave} -> is_concave end)

    # finally remove the is_concave bit
    {Enum.map(concave, fn {p, _} -> p end), Enum.map(convex, fn {p, _} -> p end)}
  end

  @doc"""
  Determines if a vertex is concave or not.

  ## Params
  * `polygon`, a list of `{x, y}` tuples outlining a polygon. This must be non-closed.
  * `at`, a position within `polygon` to check.

  Return `true` or `false`.
  """
  # https://www.david-gouveia.com/pathfinding-on-a-2d-polygonal-map
  def is_concave?(polygon, at) do
    next = Enum.at(polygon, rem(at+1, length(polygon)))
    current = Enum.at(polygon, at)
    prev = Enum.at(polygon, at-1)

    left = Vector.sub(current, prev)
    right = Vector.sub(next, current)
    Vector.cross(left, right) < 0
  end

  def is_inside?(polygon, _point) when length(polygon) < 3 do
    false
  end

  def is_inside?(polygon, point) do
    Logger.info("is_inside? #{inspect polygon}")
    #     const float epsilon = 0.5f;
    epsilon = 0.5

    #     bool inside = false;

    #     // Must have 3 or more edges
    #     if (polygon.Count < 3) return false;
    # guard above

    #     Vector2 oldPoint = polygon[polygon.Count - 1];
    #     float oldSqDist = Vector2.DistanceSquared(oldPoint, point);

    last = Enum.at(polygon, -1)
    last_sq_dist = Vector.distance_squared(last, point)

    Logger.info("is_inside?")

    {_, _, is_inside} = Enum.reduce(polygon, {last, last_sq_dist, false},
      fn p, {last, last_sq_dist, inside} ->
        Logger.info("p = #{inspect p} last = #{inspect last} inside = #{inside}")
        sq_dist = Vector.distance_squared(p, point)
        if ((last_sq_dist + sq_dist + 2.0 * :math.sqrt(last_sq_dist * sq_dist)) - Vector.distance_squared(p, last) < epsilon) do
          # toleranceOnOutside
          {last, last_sq_dist, true}
        else
          {x, y} = point
          {px, _py} = last
          {left, right} = if (x > px) do
            {last, point}
          else
            {point, last}
          end
          {lx, ly} = left
          {rx, ry} = right
          inside = if (lx < x and x <= rx and (y - ly) * (ry - ly) < (ry - ly) * (x - ly)) do
            not inside
          else
            inside
          end
          {p, sq_dist, inside}
        end
      end)
    Logger.info("is_inside? = #{is_inside}")
    is_inside


    #     for (int i = 0; i < polygon.Count; i++)
    #     {
    #         Vector2 newPoint = polygon[i];
    #         float newSqDist = Vector2.DistanceSquared(newPoint, point);

    #         if (oldSqDist + newSqDist + 2.0f * System.Math.Sqrt(oldSqDist * newSqDist) - Vector2.DistanceSquared(newPoint, oldPoint) < epsilon)
    #             return toleranceOnOutside;

    #         Vector2 left;
    #         Vector2 right;
    #         if (newPoint.X > oldPoint.X)
    #         {
    #             left = oldPoint;
    #             right = newPoint;
    #         }
    #         else
    #         {
    #             left = newPoint;
    #             right = oldPoint;
    #         }

    #         if (left.X < point.X && point.X <= right.X && (point.Y - left.Y) * (right.X - left.X) < (right.Y - left.Y) * (point.X - left.X))
    #             inside = !inside;

    #         oldPoint = newPoint;
    #         oldSqDist = newSqDist;
    #     }

    #     return inside;
    # }
  end
end
