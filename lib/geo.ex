defmodule Geo do
  @moduledoc """
  Functions related to polygons and lines relevant for 2D map pathfinding.

  This provides functions for;

  * line of sight between two points
  * classify polygon vertices as concave or vertex
  * intersections of lines and polygons
  * checking if points are inside/outside polygons
  * finding nearest point on a polygon and distances

  Polygons are
  * A list of vertices, `[{x1, y1}, {x2,y2}, ...]`.
  * They must not be closed, ie. last vertex should not be equal to the first.
  * They must be in clockwise order in screen coordinates, otherwise
    convex/concave classification will be inversed as it traverses the egdes.

  > ### Order of vertices {: .warning}
  >
  > They must be in clockwise order in screen coordinates, otherwise
  > convex/concave classification will be inversed as it traverses the egdes.
  >
  > Here's a crude drawing as an example of the M shaped polygon used for many tests/docs.
  >
  > `polygon =
  > ![Order of vertices](graph.png)

  """

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

  # ported from http://www.david-gouveia.com/portfolio/pathfinding-on-a-2d-polygonal-map/
  @doc """
  Check if two lines intersect

  This is a simpler version of `line_segment_intersection/2`, which is typically
  a better choice since it handles endpoints and segment overlap too.

  ## Params
  * `line1` a `{{x1, y1}, {x2, y2}}` line segment
  * `line2` a `{{x3, y13, {x4, y4}}` line segment

  Returns `true` if they intersect, `false` otherwise.

  Note that this doesn't handle segment overlap or points touching. Use
  `line_segment_intersection/2` instead for that level of detail.
  """
  def do_lines_intersect?({{ax1, ay1}, {ax2, ay2}}=_l1, {{bx1, by1}, {bx2, by2}}=_l2) do
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
  match neither the concave/convex definition (angle gt/lt 180 degrees) this
  will discard these via `classify_vertex/2`.

  ## Examples
      # A vaguely M shaped polygon
      iex> Geo.classify_vertices([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}])
      {[{1, 0.5}], [{0, 0}, {2, 0}, {2, 1}, {0, 1}]}
  """
  def classify_vertices(polygon) do
    {concave, convex} = Enum.reduce(polygon, {0, []}, fn point, {idx, acc} ->
      {idx + 1, acc ++ [{point, classify_vertex(polygon, idx)}]}
    end)
    |> elem(1)
    |> Enum.reject(fn {_point, type} -> type == :neither end)
    |> Enum.split_with(fn {_point, type} -> type == :concave end)

    # Remove the type
    {Enum.map(concave, fn {p, _} -> p end), Enum.map(convex, fn {p, _} -> p end)}
  end

  @doc """
  Check if a vertex is concave, convex or neither.

  Whehter a vertex is concave or convex is defined by it pointing out - it's
  inner angle is less than 180 means convex and more than 180 means concave.

  When testing a vertex, keep this in mind and negate appropriately depending
  on whether it's the boundary polygon or a hole polygon being tested.

  ## Params
  * `polygon`, a list of `{x, y}` tuples outlining a polygon. This must be non-closed.
  * `at`, a position within `polygon` to check.

  Return
  * `:convex` for a convex vertice.
  * `:concave` for a concave vertice.
  * `:neither` for a vertice that's a straight edge, ie. 180 degrees.

  ## Examples
      # A vaguely M shaped polygon
      iex> Geo.classify_vertex([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 0)
      :convex
      iex> Geo.classify_vertex([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 1)
      :neither
      iex> Geo.classify_vertex([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 4)
      :concave
  """
  # See https://www.david-gouveia.com/pathfinding-on-a-2d-polygonal-map
  def classify_vertex(polygon, at) do
    next = Enum.at(polygon, rem(at+1, length(polygon)))
    current = Enum.at(polygon, at)
    prev = Enum.at(polygon, at-1)

    left = Vector.sub(current, prev)
    right = Vector.sub(next, current)
    cross = Vector.cross(left, right)

    cond do
      cross < 0 -> :concave
      cross > 0 -> :convex
      true -> :neither
    end
  end

  @doc """
  Check if a vertex is concave or not.

  ## Params
  * `polygon`, a list of `{x, y}` tuples outlining a polygon. This must be non-closed.
  * `at`, a position within `polygon` to check.

  Return `true` or `false`.

  Three points that fall on the same line (`[{0, 0}, {1, 0}, {2, 0}]`) does not
  match neither the concave/convex definition (angle gt/lt 180 degrees). This
  will return false for such a vertex.

  ## Examples
      # A vaguely M shaped polygon
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 0)
      false
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 1)
      false
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 2)
      false
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 3)
      false
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 4)
      true
      iex> Geo.is_concave?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 5)
      false
  """
  def is_concave?(polygon, at) do
    classify_vertex(polygon, at) == :concave
  end

  @doc """
  Check if a vertex is convex or not.

  ## Params
  * `polygon`, a list of `{x, y}` tuples outlining a polygon. This must be non-closed.
  * `at`, a position within `polygon` to check.

  Return `true` or `false`.

  Three points that fall on the same line (`[{0, 0}, {1, 0}, {2, 0}]`) does not
  match neither the concave/convex definition (angle gt/lt 180 degrees). This
  will return false for such a vertex.

  ## Examples
      # A vaguely M shaped polygon
      iex> Geo.is_convex?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 0)
      true
      iex> Geo.is_convex?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 1)
      false
      iex> Geo.is_convex?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 2)
      true
      iex> Geo.is_convex?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 3)
      true
      iex> Geo.is_convex?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 4)
      false
      iex> Geo.is_convex?([{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}], 5)
      true
  """
  def is_convex?(polygon, at) do
    classify_vertex(polygon, at) == :convex
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
  Checks if there's a line-of-sight (LOS) from `start` to `stop` within the map.

  ## Params
  * `polygon`, a list of `{x, y}` vertices. This is the main boundary map.
  * `holes`, a list of lists of `{x, y}` vertices. These are holes within
    `polygon`.
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  Returns `true` if there's a line-of-sight and none of the main polygon or
  holes obstruct the path. `false` otherwise.

  As the map consists of a boundary polygon with holes, LOS implies a few things;

  * If either `start` or `stop` is outside `polygon`, the result will be
    false. Even if both are outside, that's not considered a valid LOS.
  * If the distance between `start` and `stop` is tiny (< 0.1 arbitrarily), LOS
    is true.
  * Next, it checks that the line between `start` and `stop` has no
    intersections with `polygon` or `holes`.
  * Finally it checks if the middle of the line between `start` and `stop` is
    inside `polygon` and outside all holes - this ensures that corner-to-corner
    across a hole isn't considered a LOS.
  """
  def is_line_of_sight?(polygon, holes, line) do
    {start, stop} = line
    cond do
      not is_inside?(polygon, start) or not is_inside?(polygon, stop) -> false
      Vector.distance(start, stop) < 0.1 -> true
      not Enum.all?([polygon] ++ holes, fn points -> is_line_of_sight_helper(points, line) end) -> false
      true ->
          # This part ensures that two vertices across from each other are not
          # considered LOS. Without this, eg. a box-shaped hole would have
          # opposing corners be a LOS, except that the middle of the line falls
          # inside the hole per this check.
          middle = Vector.div(Vector.add(start, stop), 2)
          cond do
            not is_inside?(polygon, middle) -> false
            Enum.all?(holes, fn hole -> is_outside?(hole, middle, allow_border: false) end) -> true
            true -> false
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
    intersections(line, points, allow_points: true)
    |> Enum.map(fn {x, y} -> {round(x), round(y)} end)
    |> Enum.reject(fn p -> p == x or p == y end)
    == []
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
  def nearest_point_on_edge(polygon, point) do
    # Get the closest segment of the polygon
    {{x1, y1}, {x2, y2}} = nearest_edge(polygon, point)

    {x, y} = point
    u = (((x - x1) * (x2 - x1)) + ((y - y1) * (y2 - y1))) / (((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)))

    cond do
      u < 0 -> {x1, y1}
      u > 1 -> {x2, y2}
      true -> {x1 + u * (x2 - x1), y1 + u * (y2 - y1)}
    end
  end

  @doc """
  Find the nearest point for the given line if it's outside the map or in a
  hole.

  ## Params
  * `polygon`, a list of `{x, y}` vertices. This is the main boundary map.
  * `holes`, a list of lists of `{x, y}` vertices. These are holes within
    `polygon`.
  * `line` a tuple of points (`{{ax, ay}, {bx, by}}`) describing a line.

  The function will return a new point `{bx, by}` for b such that;

  * if `{bx, by}` is outside the main map, the new b is the closest point on
    the main map.

  * if b is inside the main map, but also inside a hole, the new bis the
    closest point on the holes edges.
  """
  # TODO: move to a polygon_map.ex
  def nearest_point([], _, {_start, stop}=_line) do
    stop
  end

  def nearest_point(polygon, holes, line) do
    {_start, stop} = line
    nearest_point_helper(polygon, holes, line, Geo.is_inside?(polygon, stop))
  end

  defp nearest_point_helper(_, holes, line, true) do
    nearest_point_in_holes(holes, line)
  end

  defp nearest_point_helper(points, _holes, line, false) do
    nearest_boundary_point_helper(points, line)
  end

  defp nearest_point_in_holes([], {_start, stop}=_line) do
    stop
  end

  defp nearest_point_in_holes([hole|holes], line) do
    {_start, stop} = line
    nearest_point_in_holes_helper([hole|holes], line, Geo.is_inside?(hole, stop, allow_border: false))
  end

  defp nearest_point_in_holes_helper([_hole|holes], line, false) do
    nearest_point_in_holes(holes, line)
  end

  defp nearest_point_in_holes_helper([hole|_holes], line, true) do
    nearest_boundary_point_helper(hole, line)
  end

  defp nearest_boundary_point_helper(polygon, line) do
    {_start, stop} = line
    {x, y} = Geo.nearest_point_on_edge(polygon, stop)

    # This is a problematic area - we want to round towards the start of the
    # line Eg. in complex.json scene, clicking {62, 310} yields {64.4, 308.8},
    # which naive rounding makes {64, 309}. This however places us *back*
    # *inside* the hole.

    # Some options are; try all four combos or floor/ceil and see which yields
    # the minimal distance - wrong, since the start might be on the far side of
    # a hole.

    # Shorten towards start? Same thing.

    # Actually run A-star to compute all four rounding and pick the shortest
    # path - that's a bit cpu heavy.

    # Compute all four rounding options and pick one that's *not* inside the
    # hole, and don't allow it to be on the border.

    p = {round(x), round(y)}
    a = {ceil(x), ceil(y)}
    b = {ceil(x), floor(y)}
    c = {floor(x), ceil(y)}
    d = {floor(x), floor(y)}

    cond do
      Geo.is_outside?(polygon, p, allow_border: false) ->
        p
      Geo.is_outside?(polygon, a, allow_border: false) ->
        a
      Geo.is_outside?(polygon, b, allow_border: false) ->
        b
      Geo.is_outside?(polygon, c, allow_border: false) ->
        c
      Geo.is_outside?(polygon, d, allow_border: false) ->
        d
    end
    # If none of the points are outside, we'll pleasantly crash and we should
    # improve this to continuously move outwards a reasonable amount until
    # we're outside.
  end
end
