defmodule Geo do
  @moduledoc """
  Functions related to polygons and lines relevant for 2D map pathfinding.

  This provides functions for;

  * line of sight between two points
  * classify polygon vertices as concave or vertex
  * intersections of lines and polygons
  * checking if points are inside/outside polygons
  * finding nearest point on a polygon and distances
  """
  require Logger

  # TODO: line/polygon oder is inconsistent

  @doc """
  Checks if a line intersects a polygon.

  This is a bare-minimum function, and for most cases using `intersections/2`
  will be a better choice.

  ## Params
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.
  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns `true` or `false` wether the line intersects the polygon or not.
  """
  def intersects?(line, polygon) do
    prev_point = List.last(polygon)
    intersects_helper(line, polygon, prev_point)
  end

  @doc """
  Get all intersections of a line with a polygon including their type.

  This function basically calls `line_segment_intersection/2` for every segment
  of the `polygon` against the `line` and filters the results to only include
  the list of intersection points.

  ## Params
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.
  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a
    polygon. This must be non-closed.
  * `opts`
    * `:allow_points` (default `false`) whether a `on_point` intersection
      should be considered an intersection or not. This varies from use
      cases. Eg. when building a polygon, points will be connected and thus
      intersect if `true`. This may not be the desired result, so `false` won't
      consider points intersections.

  Returns a list of `{x, y}` tuples indicating where the line intersects, or
  `[]` if there's no intersections.

  ## Examples
      iex> polygon = [{0, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}]
      [{0, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}]
      iex> line = {{1, -1}, {1, 3}}
      {{1, -1}, {1, 3}}
      iex> Geo.intersections(line, polygon)
      [{1.0, 0.0}]
      iex> Geo.intersections(line, polygon, allow_points: true)
      [{1.0, 0.0}, {1.0, 0.5}]

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
    |> Enum.dedup
  end

  @doc """
  Get first intersections of a line with a polygon.

  The "opposite" of `last_intersection/2`.

  ## Params
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line. The
    first tuple (`{ax, ay}`) is considered the head of the line and "first" in
    this context means nearest to that point.
  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns a `{x, y}` tuples indicating where the line first intersects, or `nil`
  if there's no intersection.
  """
  def first_intersection({a, _b} = line, polygon) do
    Enum.min_by(intersections(line, polygon), fn ip ->
      Vector.distance(a, ip)
    end, fn ->
      nil
    end)
  end

  @doc """
  Get last intersections of a line with a polygon.

  The "opposite" of `first_intersection/2`.

  ## Params
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line. The
     second tuple (`{bx, by}`) is considered the end of the line and "last" in
     this context means nearest to that point.
  * `polygon` a list of points (`[{x, y}, {x, y}, ...]`) describing a polygon.

  Returns a `{x, y}` tuples indicating where the line last intersects, or nil
  if there's no intersection.
  """
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

  # For explanation of a lot of the math here;
  # * https://khorbushko.github.io/article/2021/07/15/the-area-polygon-or-how-to-detect-line-segments-intersection.html
  # * https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect/1968345#1968345
  @doc """
  Determine if, where and how two lines intersect.

  ## Params
  * `line1` a `{{x1, y1}, {x2, y2}}` line segment
  * `line2` a `{{x3, y13, {x4, y4}}` line segment

  Returns
  * `:on_segment` one line is on the other.
  * `:parallel` the lines are parallel and do not intersect.
  * `{:point_intersection, {x, y}}` either line has an endpoint (`{x, y}`) on
    the other line.
  * `{:intersection, {x, y}}` the lines intersect at `{x, y}`.
  * `:none` no intersection.

  ## Examples
      iex> Geo.line_segment_intersection({{1, 2}, {4, 2}}, {{2, 0}, {3, 0}})
      :parallel
      iex> Geo.line_segment_intersection({{1, 2}, {4, 2}}, {{2, 2}, {3, 2}})
      :on_segment
      iex> Geo.line_segment_intersection({{1, 2}, {4, 2}}, {{2, 0}, {2, 1}})
      :none
      iex> Geo.line_segment_intersection({{1, 2}, {4, 2}}, {{2, 0}, {2, 2}})
      {:point_intersection, {2.0, 2.0}}
      iex> Geo.line_segment_intersection({{1, 2}, {4, 2}}, {{2, 0}, {2, 3}})
      {:intersection, {2.0, 2.0}}
  """
  def line_segment_intersection(line1, line2) do
    {{ax1, ay1}, {ax2, ay2}} = line1
    {{bx1, by1}, {bx2, by2}} = line2
    den = (by2 - by1) * (ax2 - ax1) - (bx2 - bx1) * (ay2 - ay1)

    if den == 0 do
      if (by1 - ay1) * (ax2 - ax1) == (bx1 - ax1) * (ay2 - ay1) do
        :on_segment
      else
        :parallel
      end
    else
      ua = ((bx2 - bx1) * (ay1 - by1) - (by2 - by1) * (ax1 - bx1)) / den
      ub = ((ax2 - ax1) * (ay1 - by1) - (ay2 - ay1) * (ax1 - bx1)) / den
      if ua >= 0.0 and ua <= 1.0 and ub >= 0.0 and ub <= 1.0 do
        {x, y} = {ax1 + ua * (ax2 - ax1), ay1 + ua * (ay2 - ay1)}
        if ua == 0.0 or ub == 1.0 or ua == 1.0 or ub == 0.0 do
          {:point_intersection, {x, y}}
        else
          {:intersection, {x, y}}
        end
      else
        :none
      end
    end
  end

  @doc """
  Get the distance squared from a point to a line/segment.

  ## Params
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.
  * `point` a tuple `{x, y}` describing a point

  This returns the square of the distance beween the given point and segment as
  a float.

  ## Examples
      iex> Geo.distance_to_segment_squared({{2, 0}, {2, 2}}, {0, 1})
      4.0
  """
  def distance_to_segment_squared({{vx, vy}=v, {wx, wy}=w}=_line, {px, py}=point) do
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

  @doc """
  Get the distance from a point to a line/segment, aka the square root of
  `distance_squared/2`.

  ## Params
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.
  * `point` a tuple `{x, y}` describing a point

  This returns the distance beween the given point and segment as a float.

  ## Examples
      iex> Geo.distance_to_segment({{2, 0}, {2, 2}}, {0, 1})
      2.0
  """
  def distance_to_segment(line, point) do
    :math.sqrt(distance_to_segment_squared(line, point))
  end

  @doc """
  Find the edge of a polygon nearest a given point

  Given a `point` that's inside or outside a given `polygon`, this checks each
  segment of the polygon, and returns the nearest one.

  ## Params
  * `polygon`, a list of `{x, y}` vertices, `[{x1, y2}, {x2, y2}, ...]`. This
    must be non-closed.
  * `point` a tuple `{x, y}` describing a point

  Returns the `{{x1, y1}, {x2, y2}}` segment that is closest to the point.
  """
  def nearest_edge(polygon, point) do
    # Get the closest segment of the polygon
    polygon
    |> Enum.chunk_every(2, 1, Enum.slice(polygon, 0, 2))
    |> Enum.map(fn [a, b] -> {a, b} end)
    |> Enum.min_by(&(distance_to_segment(&1, point)))
  end

  @doc """
  Find the point on the edge of a polygon nearest a given point.

  Given a `point` that's inside or outside a given `polygon`, this uses
  `nearest_edge/2` to find the closest edge and then computes the point on the
  edge nearest the given `point`.

  ## Params
  * `polygon`, a list of `{x, y}` vertices, `[{x1, y2}, {x2, y2}, ...]`. This
    must be non-closed.
  * `point` a tuple `{x, y}` describing a point

  Returns the `{x, y}` on an edge of the polygon that is nearest `point`.
  """
  def closest_point_on_edge(polygon, point) do
    # Get the closest segment of the polygon
    {{x1, y1}, {x2, y2}} = nearest_edge(polygon, point)

    {x, y}=point
    u = (((x - x1) * (x2 - x1)) + ((y - y1) * (y2 - y1))) / (((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)))

    cond do
      u < 0 -> {x1, y1}
      u > 1 -> {x2, y2}
      true -> {x1 + u * (x2 - x1), y1 + u * (y2 - y1)}
    end
  end

  # ported from http://www.david-gouveia.com/portfolio/pathfinding-on-a-2d-polygonal-map/
  @doc """
  Test if two lines intersect

  This is a simpler version of `line_segment_intersection/2`, which is typically
  a better choice since it can handle endpoints too.

  ## Params
  * `line1` a `{{x1, y1}, {x2, y2}}` line segment
  * `line2` a `{{x3, y13, {x4, y4}}` line segment

  Returns `true` if they intersect anywhere (at ends too), `false` otherwise.
  """
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

  @doc """
  Split polygon into concave and convex vertices.

  When doing pathfinding, there will typically be a outer polygon bounding the
  "world" and multiple inner polygons describing "holes". The path can only be
  within the outer polygon and has to "walk around" the holes.

  Classifying the polygons into concave and convex gives the walkable graph.

  * The outer polygon's concave (pointing into the world) vertices should be
    used.
  * The holes' convex (point out of the hole, into the world) vertices should
    be used.

  In code, this looks like

  ```
  {concave, _convex} = Geo.classify_vertices(world)

  convex = Enum.reduce(holes, [], fn points, acc ->
    {_, convex} = Geo.classify_vertices(points)
    acc ++ convex
  end)

  vertices = concave ++ convex
  ```

  ## Params
  * `polygon`, a list of `{x, y}` tuples outlining a polygon. This must be non-closed.

  Returns `{list of concave vertices, list of convex}`.

  Three points that fall on the same line (`[{0, 0}, {1, 0}, {2, 0}]`) does not
  match neither the concave/convex definition (angle gt/lt 180 degrees), see
  `is_concave?/2.`

  ## Examples
      # A vaguely M shaped polygon
      iex> Geo.classify_vertices([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}])
      {[{1, 0.5}], [{0, 0}, {1, 0}, {2, 0}, {2, 1}, {0, 1}]}
  """
  def classify_vertices(polygon) do
    # We prepend the last vertex (-1) to the list and chunk into threes. That
    # way we have a list of triples {prev, current, next} that describe each
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

  @doc """
  Determines if a vertex is concave or not.

  ## Params
  * `polygon`, a list of `{x, y}` tuples outlining a polygon. This must be non-closed.
  * `at`, a position within `polygon` to check.

  Return `true` or `false`.

  Three points that fall on the same line (`[{0, 0}, {1, 0}, {2, 0}]`) does not
  match neither the concave/convex definition (angle gt/lt 180 degrees). This
  will return false for such a vertex.

  ## Examples
      # A vaguely M shaped polygon
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 1)
      false
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 2)
      false
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 3)
      false
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 4)
      true
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
  The opposite of is_inside?, provided for code readability.
  """
  def is_outside?(polygon, point, opts \\ [])

  def is_outside?(polygon, _point, _opts) when length(polygon) < 3 do
    false
  end

  def is_outside?(polygon, point, opts) do
    not is_inside?(polygon, point, opts)
  end

  @doc """
  Checks if there's a line-of-sight from `start` to `stop` within the map.

  ## Params
  * `polygon`, a list of `{x, y}` vertices. This is the main boundary map.
  * `holes`, a list of lists of `{x, y}` vertices. These are holes within
    `polygon`.
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  Returns `true` if there's a line-of-sight and none of the main polygon or
  holes obstruct the path. `false` otherwise.

  If either `start` or `stop` is outside `polygon`, the result will be false.
  """
  def is_line_of_sight?(polygon, holes, line) do
    {start, stop} = line
    if not is_inside?(polygon, start) or not is_inside?(polygon, stop) do
      false
    else
      if Vector.distance(start, stop) < 0.5 do
        true
      else
        # TODO: use Enum.any?
        rv =
          Enum.reduce_while([polygon] ++ holes, true, fn points, _acc ->
            is_line_of_sight_helper(points, line)
          end)
        if not rv do
          rv
        else
          middle = Vector.div(Vector.add(start, stop), 2)
          acc = is_inside?(polygon, middle)
          # TODO: use Enum.any??
          acc = Enum.reduce(holes, acc, fn points, acc ->
            if is_inside?(points, middle, allow_border: false) do
              false
            else
              acc
            end
          end)
          acc
        end
      end
    end
  end

  defp is_line_of_sight_helper(points, {x, y}=line) do
    # We get all intersections and reject the ones that are identical to the
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

    if is == [] do
      {:cont, true}
    else
      # NOTE: maybe if I apply "is_inside" to intersection points with allow
      # border=false to check?
      {:halt, false}
    end
  end
end
