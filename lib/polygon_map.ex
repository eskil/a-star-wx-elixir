defmodule PolygonMap do
  @moduledoc """
  Utility functions to work on a polygon map.

  A polygon map is a set of a primary (main, boundary...) polygon that outlines
  the world, plus a list of polygons that make "holes" in the main polygon.

  See `Polygon` for details on how polygons are composed.

  The use case is eg. making a map with obstacles, and use the `Astar` module
  to find the shortest path between points in the map.
  """

  require Logger

  @doc """
  Given a list of polygons (main, & holes), returns a list of vertices.

  The vertices are the main polygon's concave vertices and the convex ones of
  the holes.
  """
  def get_walk_vertices(polygon, holes) do
    {concave, _convex} = Polygon.classify_vertices(polygon)
    convex = Enum.reduce(holes, [], fn points, acc ->
      {_concave, convex} = Polygon.classify_vertices(points)
      acc ++ convex
    end)

    concave ++ convex
  end

  @doc """
  Given a polygon map (main & holes) and list of vertices, makes the graph.
  """
  def create_walk_graph(polygon, holes, vertices) do
    get_edges(polygon, holes, vertices, vertices)
  end

  @doc """
  Given a polygon map (main & holes), list of vertices and the initial graph,
  extend the graph with extra `points`.

  This is used to "temporarily" expand the fixed walk graph with the start and
  end-point. This is a performance optimisation that saves work by reusing the
  fixed nodes and extend it with the moveable points.

  ## Params
  * `polygons`, a `%{main: [...], hole: [...], hole2: [...]}` polygon map.
  * `graph`, the fixed graph, eg. created via `create_walk_graph/2`.
  * `vertices` the nodes used to create `graph`.
  * `points` a list of coordinates, `[{x, y}, {x, y}...]`, to extend

  """
  # TODO: move to a polygon_map.ex
  def extend_graph(polygon, holes, graph, vertices, points) do

    # To extend the graph `graph` made up up `vertices` with new points
    # `points`, we need to find three sets of edges (sub-graphs). The ones from
    # the new points to the existing vertices, vice-versa, and between the new
    # points.
    set_a = get_edges(polygon, holes, points, vertices)
    set_b = get_edges(polygon, holes, vertices, points)
    set_c = get_edges(polygon, holes, points, points)
    # Logger.info("set_a, points to vertices = #{inspect set_a, pretty: true}")
    # Logger.info("set_b, points to vertices = #{inspect set_b, pretty: true}")
    # Logger.info("set_c, points to points = #{inspect set_c, pretty: true}")

    # Merge the three new sub-graphs into graph. This uses Map.merge with a
    # merge func that combines values for identical keys (basically extend
    # them) and dedupes.
    merge_fun = fn _k, v1, v2 ->
      Enum.dedup(v1 ++ v2)
    end
    graph =
      graph
      |> Map.merge(set_a, merge_fun)
      |> Map.merge(set_b, merge_fun)
      |> Map.merge(set_c, merge_fun)

    {graph, vertices ++ points}
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
  def nearest_point([], _, {_start, stop}=_line) do
    stop
  end

  def nearest_point(polygon, holes, line) do
    {_start, stop} = line
    nearest_point_helper(polygon, holes, line, Polygon.is_inside?(polygon, stop))
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
    nearest_point_in_holes_helper([hole|holes], line, Polygon.is_inside?(hole, stop, allow_border: false))
  end

  defp nearest_point_in_holes_helper([_hole|holes], line, false) do
    nearest_point_in_holes(holes, line)
  end

  defp nearest_point_in_holes_helper([hole|_holes], line, true) do
    nearest_boundary_point_helper(hole, line)
  end

  defp nearest_boundary_point_helper(polygon, line) do
    {_start, stop} = line
    {x, y} = Polygon.nearest_point_on_edge(polygon, stop)

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
      Polygon.is_outside?(polygon, p, allow_border: false) ->
        p
      Polygon.is_outside?(polygon, a, allow_border: false) ->
        a
      Polygon.is_outside?(polygon, b, allow_border: false) ->
        b
      Polygon.is_outside?(polygon, c, allow_border: false) ->
        c
      Polygon.is_outside?(polygon, d, allow_border: false) ->
        d
    end
    # If none of the points are outside, we'll pleasantly crash and we should
    # improve this to continuously move outwards a reasonable amount until
    # we're outside.
  end

  defp get_edges(polygon, holes, points_a, points_b) do
    cost_fun = fn a, b -> Vector.distance(a, b) end
    is_reachable? = fn a, b -> Polygon.is_line_of_sight?(polygon, holes, {a, b}) end

    # O(n^2) check all vertice combos for reachability...
    {_, all_edges} =
      Enum.reduce(points_a, {0, %{}}, fn a, {a_idx, acc1} ->
        {_, inner_edges} =
          Enum.reduce(points_b, {0, []}, fn b, {b_idx, acc2} ->
            # NOTE: this is where the edge value is becomes the key in the
            # graph. This is why a_idx and b_idx are available here, in case we
            # want to change it up to be the indexes into points. Unless those
            # two sets are the same, using the indexes makes no sense.
            if a != b and is_reachable?.(a, b) do
              {b_idx + 1, acc2 ++ [{b, cost_fun.(a, b)}]}
            else
              {b_idx + 1, acc2}
            end
          end)
        {a_idx + 1, Map.put(acc1, a, inner_edges)}
      end)
    Map.new(all_edges)
  end
end
