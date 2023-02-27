defmodule Geo do
  require Logger

  @doc """
  Checks if a line intersects a polygon.

  ## Params

  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns `true` or `false`.

  """
  # TODO: line/polygon oder is inconsistent
  def intersects?(line, polygon) do
    prev_point = List.last(polygon)
    intersects_helper(line, polygon, prev_point)
  end

  @doc """
  Get intersections of a line with a polygon.

  ## Params

  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns a list of `{x, y}` tuples indicating where the line intersects, or
  `[]` if there's no intersections.

  """
  # TODO: line/polygon oder is inconsistent
  def intersections(line, polygon) do
    prev_point = List.last(polygon)
    intersects_helper(line, polygon, prev_point, [])
    |> Enum.filter(fn
      {:intersection, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:intersection, point} -> point end)
  end

  @doc """
  Get first intersections of a line with a polygon.

  ## Params

  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns a `{x, y}` tuples indicating where the line first intersects, or nil
  if there's no intersection.

  """
  # TODO: line/polygon oder is inconsistent
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
  # See https://www.david-gouveia.com/pathfinding-on-a-2d-polygonal-map
  def is_concave?(polygon, at) do
    next = Enum.at(polygon, rem(at+1, length(polygon)))
    current = Enum.at(polygon, at)
    prev = Enum.at(polygon, at-1)

    left = Vector.sub(current, prev)
    right = Vector.sub(next, current)
    Vector.cross(left, right) < 0
  end

  @doc """
  Check if a point is inside a polygon or not.
  """
  def is_inside?(polygon, _point) when length(polygon) < 3 do
    false
  end

  # See https://www.david-gouveia.com/pathfinding-on-a-2d-polygonal-map
  def is_inside?(polygon, point) do
    epsilon = 0.5

    prev = Enum.at(polygon, -1)
    prev_sq_dist = Vector.distance_squared(prev, point)

    {_, _, is_inside} = Enum.reduce_while(polygon, {prev, prev_sq_dist, false},
      fn current, {prev, prev_sq_dist, inside} ->
        sq_dist = Vector.distance_squared(current, point)
        if (prev_sq_dist + sq_dist + 2.0 * :math.sqrt(prev_sq_dist * sq_dist) - Vector.distance_squared(current, prev) < epsilon) do
          # "return toleranceOnOutside"
          {:halt, {prev, prev_sq_dist, false}}
        else
          {x, y} = point
          {px, _py} = prev
          {left, right} = if (x > px) do
            {prev, current}
          else
            {current, prev}
          end
          {lx, ly} = left
          {rx, ry} = right
          inside = if (lx < x and x <= rx and (y - ly) * (rx - lx) < (ry - ly) * (x - lx)) do
            not inside
          else
            inside
          end
          {:cont, {current, sq_dist, inside}}
        end
      end)
    is_inside
  end

  @doc """
  Checks if there's a line-of-sight from `start` to `stop` within the map.

  ## Params

  * `polygon`, a list of `{x, y}` vertices. This is the main boundary map.

  * `holes`, a list of lists of `{x, y}` vertices. These are holes within
    `polygon`.

  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  Returns ...

  """
  def is_line_of_sight?(polygon, holes, line) do
    Logger.info("is los? #{inspect polygon} with holes #{inspect holes} on #{inspect line}")
    #   bool InLineOfSight(Polygon polygon, Vector2 start, Vector2 end)
    # {
    #   // Not in LOS if any of the ends is outside the polygon
    #   if (!polygon.Inside(start) || !polygon.Inside(end)) return false;
    {start, stop} = line
    if not is_inside?(polygon, start) or not is_inside?(polygon, stop) do
      Logger.info("start or stop not inside polygon")
      Logger.info("start #{inspect start} = #{is_inside?(polygon, start)}")
      Logger.info("stop #{inspect stop} = #{is_inside?(polygon, stop)}")
      false
    else
      #   // In LOS if it's the same start and end location
      #   if (Vector2.Distance(start, end) < epsilon) return true;
      if Vector.distance(start, stop) < 0.5 do
        Logger.info("distance < 0.5")
        true
      else
        #   // Not in LOS if any edge is intersected by the start-end line segment
        #   foreach (var vertices in polygon) {
        #     var n = vertices.Count;
        #     for (int i = 0; j < n; i++)
        #       if (LineSegmentsCross(start, end, vertices[i], vertices[(i+1)%n]))
        #         return false;
        #   }
        # TODO: use Enum.any?
        rv = Enum.reduce_while([{:main, polygon}] ++ holes, true, fn {name, points}, _acc ->
          Logger.info("Checking intersect with #{name} #{inspect points}")
          # TODO: line/polygon oder is inconsistent
          if intersections(line, points) == [] do
            Logger.info("Intersect with #{name}, no")
            {:cont, true}
          else
            Logger.info("Intersect with #{name}, YES")
            {:halt, false}
          end
        end)
        if not rv do
          rv
        else
          #   // Finally the middle point in the segment determines if in LOS or not
          #   return polygon.Inside((start + end) / 2f);
          # }
          middle = Vector.div(Vector.add(start, stop), 2)
          acc = is_inside?(polygon, middle)
          Logger.info("Middle #{inspect middle} inside main = #{acc}")
          # TODO: use Enum.any??
          acc = Enum.reduce(holes, acc, fn {name, points}, acc ->
            if is_inside?(points, middle) do
              Logger.info("Middle #{inspect middle} is inside #{name} = #{acc}")
              false
            else
              Logger.info("Middle #{inspect middle} not inside #{name} = #{acc}")
              acc
            end
          end)
          acc
        end
      end
    end

  end
end
