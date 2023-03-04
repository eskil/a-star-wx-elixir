defmodule Geo do
  require Logger

  # TODO: line/polygon oder is inconsistent

  @doc """
  Checks if a line intersects a polygon.

  ## Params

  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns `true` or `false`.

  """
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
  def intersections(line, polygon, opts \\ []) do
    allow_points = Keyword.get(opts, :allow_points, false)
    prev_point = List.last(polygon)
    intersects_helper(line, polygon, prev_point, [])
    |> Enum.filter(fn
      {:intersection, _} -> true
      {:point_intersection, _} -> allow_points
      _ -> false
    end)
    |> Enum.map(fn {_, point} -> point end)
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
  def first_intersection({a, _b} = line, polygon) do
    Enum.min_by(intersections(line, polygon), fn ip ->
      Vector.distance(a, ip)
    end, fn ->
      nil
    end)
  end

  @doc """
  Get last intersections of a line with a polygon.

  ## Params

  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns a `{x, y}` tuples indicating where the line last intersects, or nil
  if there's no intersection.

  """
  # TODO: line/polygon oder is inconsistent
  def last_intersection({a, _b} = line, polygon) do
    Enum.max_by(intersections(line, polygon), fn ip ->
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
      {:point_intersection, _} = result -> result
    end
  end

  defp intersects_helper(_line, [], _prev_point, acc) do
    acc
  end

  defp intersects_helper(line, [next_point|polygon], prev_point, acc) when is_list(acc) do
    v = line_segment_intersection(line, {prev_point, next_point})
    intersects_helper(line, polygon, next_point, acc ++ [v])
  end

  # See https://khorbushko.github.io/article/2021/07/15/the-area-polygon-or-how-to-detect-line-segments-intersection.html for an explanation.
  @doc """
  Determine if `line1` and `line2` intersects.

  ## Params
  * `line1` a `{{x1, y1}, {x2, y2}}` line segment
  * `line2` a `{{x3, y13, {x4, y4}}` line segment

  Returns

  * `:on_segment` if one line is on the other

  * `:parallel` if the lines are parallel and do not intersect

  * `{:point_intersection, {x, y}}` if either line has an endpoint (`{x, y}`)
    on the other line

  * `{:intersection, {x, y}}` if either line has an endpoint (`{x, y}`) on the
  other line.


  """
  def line_segment_intersection(line1, line2) do
    # Logger.debug("\tintersection #{inspect line1} with #{inspect line2}")
    {{ax1, ay1}, {ax2, ay2}} = line1
    {{bx1, by1}, {bx2, by2}} = line2
    den = (by2 - by1) * (ax2 - ax1) - (bx2 - bx1) * (ay2 - ay1)

    if den == 0 do
      if (by1 - ay1) * (ax2 - ax1) == (bx1 - ax1) * (ay2 - ay1) do
        # Logger.debug("\t\ton onsegment")
        :on_segment
      else
        # Logger.debug("\t\tparallel")
        :parallel
      end
    else
      ua = ((bx2 - bx1) * (ay1 - by1) - (by2 - by1) * (ax1 - bx1)) / den
      ub = ((ax2 - ax1) * (ay1 - by1) - (ay2 - ay1) * (ax1 - bx1)) / den
      # Logger.debug("\t\tua #{ua}")
      # Logger.debug("\t\tub #{ub}")
      # The "and not (ua == 0.0 or ub == 0.0)" part ensures no intersection on points
      if ua >= 0.0 and ua <= 1.0 and ub >= 0.0 and ub <= 1.0 do
      # if ua >= 0.0 and ua <= 1.0 and ub >= 0.0 and ub <= 1.0 and not (ua == 0.0 or ub == 0.0) do
      # if ua > 0.0 and ua < 1.0 and ub > 0.0 and ub < 1.0 and not (ua == 0.0 or ub == 0.0) do
        {x, y} = {ax1 + ua * (ax2 - ax1), ay1 + ua * (ay2 - ay1)}
        if ua == 0.0 or ub == 1.0 or ua == 1.0 or ub == 0.0 do
          # Logger.debug("\t\tpoint intersection at #{inspect {x, y}}")
          {:point_intersection, {x, y}}
        else
          # Logger.debug("\t\tintersection at #{inspect {x, y}}")
          {:intersection, {x, y}}
        end
      else
        # Logger.debug("\t\tnone")
        :none
      end
    end
  end

  def distance_to_segment_squared({{vx, vy}=v, {wx, wy}=w}=_line, {px, py}=point) do
    # var l2:Float = DistanceSquared(vx,vy,wx,wy);
		# if (l2 == 0) return DistanceSquared(px, py, vx, vy);
		# var t:Float = ((px - vx) * (wx - vx) + (py - vy) * (wy - vy)) / l2;
		# if (t < 0) return DistanceSquared(px, py, vx, vy);
		# if (t > 1) return DistanceSquared(px, py, wx, wy);
		# return DistanceSquared(px, py, vx + t * (wx - vx), vy + t * (wy - vy));
    l2 = Vector.distance_squared(v, w)
    if l2 == 0.0 do
      Vector.distance_squared(point, v)
    else
      t = ((px - vx) * (wx - vx) + (py - vy) * (wy - vy)) / l2
      cond do
        t < 0 -> Vector.distance_squared(point, v)
        t > 1 -> Vector.distance_squared(point, w)
        true -> Vector.distance_squared(point, {vx + t * (wx - vx), vy + t * (wy - vy)})
      end
    end
  end

  def distance_to_segment(line, point) do
    :math.sqrt(distance_to_segment_squared(line, point))
  end

  def closest_point_on_edge(polygon, point) do
    # Get the closest segment of the polygon
    {{x1, y1}, {x2, y2}} =
      polygon
      |> Enum.chunk_every(2, 1, Enum.slice(polygon, 0, 2))
      |> Enum.map(fn [a, b] -> {a, b} end)
      |> Enum.min_by(&(distance_to_segment(&1, point)))

    {x, y}=point
    u = (((x - x1) * (x2 - x1)) + ((y - y1) * (y2 - y1))) / (((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)))

    cond do
      u < 0 -> {x1, y1}
      u > 1 -> {x2, y2}
      true -> {x1 + u * (x2 - x1), y1 + u * (y2 - y1)}
    end
  end

  # ported from http://www.david-gouveia.com/portfolio/pathfinding-on-a-2d-polygonal-map/
  def lines_intersect({{ax1, ay1}, {ax2, ay2}}=_l1, {{bx1, by1}, {bx2, by2}}=_l2) do
    den = ((ax2 - ax1) * (by2 - by1)) - ((ay2 - ay1) * (bx2 - bx1))
    if den == 0 do
      false
    else
      num1 = ((ay1 - by1) * (bx2 - bx1)) - ((ax1 - bx1) * (by2 - by1))
      num2 = ((ay1 - by1) * (ax2 - ax1)) - ((ax1 - bx1) * (ay2 - ay1))
      if (num1 == 0 or num2 == 0) do
        false
      else
        r = num1 / den
        s = num2 / den
        (r > 0 and r < 1) and (s > 0 and s < 1)
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
  The opposite of is_inside?
  """
  def is_outside?(polygon, point, opts) do
    not is_inside?(polygon, point, opts)
  end

  # Alternate, https://sourceforge.net/p/polyclipping/code/HEAD/tree/trunk/cpp/clipper.cpp#l438
  @doc """
  Check if a point is inside a polygon or not.
  """
  def is_inside?(polygon, point, opts \\ [])

  def is_inside?(polygon, _point, _opts) when length(polygon) < 3 do
    false
  end

  # See https://www.david-gouveia.com/pathfinding-on-a-2d-polygonal-map
  def is_inside?(polygon, point, opts) do
    epsilon = 0.5

    prev = Enum.at(polygon, -1)
    prev_sq_dist = Vector.distance_squared(prev, point)

    {_, _, is_inside} = Enum.reduce_while(polygon, {prev, prev_sq_dist, false},
      fn current, {prev, prev_sq_dist, inside} ->
        sq_dist = Vector.distance_squared(current, point)
        if (prev_sq_dist + sq_dist + 2.0 * :math.sqrt(prev_sq_dist * sq_dist) - Vector.distance_squared(current, prev) < epsilon) do
          # "return toleranceOnOutside"
          allow = Keyword.get(opts, :allow_border, true)
          {:halt, {prev, prev_sq_dist, allow}}
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
    #   bool InLineOfSight(Polygon polygon, Vector2 start, Vector2 end)
    # {
    #   // Not in LOS if any of the ends is outside the polygon
    #   if (!polygon.Inside(start) || !polygon.Inside(end)) return false;
    {start, stop} = line
    # Logger.debug("is_line_of_sight? #{inspect line}")
    if not is_inside?(polygon, start) or not is_inside?(polygon, stop) do
      # Logger.debug("\toutside #{is_inside?(polygon, start)} #{is_inside?(polygon, stop)}")
      false
    else
      #   // In LOS if it's the same start and end location
      #   if (Vector2.Distance(start, end) < epsilon) return true;
      if Vector.distance(start, stop) < 0.5 do
        # Logger.debug("\tnear, yes")
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
        rv =
          Enum.reduce_while([{:main, polygon}] ++ holes, true, fn {name, points}, _acc ->
            is_line_of_sight_helper(name, points, line, :original)
          end)
        if not rv do
          # Logger.debug("\tno LOS")
          rv
        else
          #   // Finally the middle point in the segment determines if in LOS or not
          #   return polygon.Inside((start + end) / 2f);
          # }
          middle = Vector.div(Vector.add(start, stop), 2)
          acc = is_inside?(polygon, middle)
          # TODO: use Enum.any??
          acc = Enum.reduce(holes, acc, fn {_name, points}, acc ->
            if is_inside?(points, middle, allow_border: false) do
              false
            else
              acc
            end
          end)
          # Logger.debug("\t#{acc} by half #{inspect middle}")
          acc
        end
      end
    end
  end

  defp is_line_of_sight_helper(_name, points, line, :new) do
    pointsets = Enum.chunk_every(points, 2, 1, Enum.slice(points, 0, 2))
    if Enum.reduce_while(pointsets, false, fn [a, b]=_polygon_segment, _acc ->
          if lines_intersect({a, b}, line) do
            # Logger.debug("\t\t\tintersects #{name}")
            {:halt, false}
          else
            # Logger.debug("\t\t\tno intersects #{name}")
            {:cont, true}
          end
        end)
      do
      # Logger.debug("\t\t\tintersects #{name}")
      {:cont, true}
      else
        # Logger.debug("\t\t\tno intersects #{name}")
        {:halt, false}
    end
  end

  defp is_line_of_sight_helper(_name, points, {x, y}=line, :original) do
    # We get all intersections but remove the ones that are identical to the
    # line. This allows us to enable "allow_points: true", but only see
    # intersections with other lines and _other_ polygon vertices (points).
    # This is necessary since we're always calling this with a line between two
    # polygon vertices. Without this, having "allow_points: true", every such
    # line would immediately intersect at both ends.

    # TODO: line/polygon oder is inconsistent
    is =
      intersections(line, points, allow_points: true)
      |> Enum.map(fn {x, y} -> {round(x), round(y)} end)
      |> Enum.reject(fn p -> p == x or p == y end)
    # Logger.debug("\t\t\tvs #{name} = #{inspect is}")

    if is == [] do
      # Logger.debug("\t\t\tno intersects #{name}")
      {:cont, true}
    else
      # NOTE: maybe if I apply "is_inside" to intersection points with allow
      # border=false to check?
      # Logger.debug("\t\t\tintersects #{name}")
      {:halt, false}
    end
  end
end
