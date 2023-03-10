defmodule PolygonTest do
  use ExUnit.Case, async: true

  doctest Polygon

  # defp box_polygon(), do: [{0, 10}, {10, 10}, {10, 0}, {0, 0}]
  # defp m_polygon(), do: [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
  # defp mflag_polygon(), do: polygon = [{0, 0}, {10, 0}, {5, 10}, {10, 20}, {0, 20}]

  ##
  ## Polygon.intersects?
  ##

  test "intersects? detects point intersection" do
    line = {{5, 5}, {15, 15}}
    # Box
    polygon = [{0, 10}, {10, 10}, {10, 0}, {0, 0}]
    assert Polygon.intersects?(polygon, line) == {:point_intersection, {10.0, 10.0}}
  end

  test "intersects? detects edge intersection" do
    line = {{5, 5}, {5, 15}}
    # Box
    polygon = [{0, 10}, {10, 10}, {10, 0}, {0, 0}]
    assert Polygon.intersects?(polygon, line) == {:intersection, {5.0, 10.0}}
  end

  test "intersects? detects no intersection" do
    line = {{20, 20}, {30, 30}}
    # Box
    polygon = [{0, 10}, {10, 10}, {10, 0}, {0, 0}]
    assert Polygon.intersects?(polygon, line) == :nointersection
  end

  test "intersects? detects segment" do
    line = {{1, 10}, {9, 10}}
    # Box
    polygon = [{0, 10}, {10, 10}, {10, 0}]
    assert Polygon.intersects?(polygon, line) == :on_segment
  end

  ##
  ## Polygon.intersections
  ##

  test "can get multiple intersections when there's two points" do
    line = {{6, 1}, {6, 19}}
    # Sideways M / flag style
    polygon = [{0, 0}, {10, 0}, {5, 10}, {10, 20}, {0, 20}]
    assert Polygon.intersections(polygon, line) == [{6.0, 8.0}, {6.0, 12.0}]
  end

  test "can get multiple intersections when there's no intersections" do
    line = {{6, 1}, {6, 3}}
    # Sideways M / flag style
    polygon = [{0, 0}, {10, 0}, {5, 10}, {10, 20}, {0, 20}]
    assert Polygon.intersections(polygon, line) == []
  end

  test "intersections when it's on segment" do
    line = {{0, 1}, {0, 3}}
    # Sideways M / flag style
    polygon = [{0, 0}, {10, 0}, {5, 10}, {10, 20}, {0, 20}]
    assert Polygon.intersections(polygon, line) == []
  end

  ##
  ## Polygon.first/last_intersection
  ##

  test "find first/last intersection when there's two points" do
    line = {{6, 1}, {6, 19}}
    # Sideways M / flag style
    polygon = [{0, 0}, {10, 0}, {5, 10}, {10, 20}, {0, 20}]
    assert Polygon.first_intersection(polygon, line) == {6.0, 8.0}
    assert Polygon.last_intersection(polygon, line) == {6.0, 12.0}
  end

  test "find first/last intersection when there's no intersections" do
    line = {{6, 1}, {6, 3}}
    # Sideways M / flag style
    polygon = [{0, 0}, {10, 0}, {5, 10}, {10, 20}, {0, 20}]
    assert Polygon.first_intersection(polygon, line) == nil
    assert Polygon.last_intersection(polygon, line) == nil
  end

  ##
  ## Polygon.is_line_of_sight?
  ##

  test "is_line_of_sight? line is outside and no intersection" do
    line = {{10, 30}, {20, 30}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line is inside and no intersection" do
    line = {{8, 2}, {12, 2}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line starts inside and ends outside" do
    line = {{18, 2}, {22, 2}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line starts outside and ends inside" do
    line = {{22, 2}, {18, 2}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside and doesn't touch holes" do
    line = {{10, 6}, {12, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line in inside but ends in a hole" do
    line = {{6, 6}, {12, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but intersects a hole" do
    line = {{3, 6}, {12, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but intersects a hole through a vertice" do
    line = {{4, 4}, {8, 8}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but touches a hole on an edge" do
    line = {{4, 6}, {5, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line in inside but touches a hole on a vertex" do
    line = {{4, 8}, {5, 7}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line is from corner to corner of hole" do
    line = {{5, 5}, {7, 7}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line is from corner to corner of polygon but outside" do
    line = {{0, 20}, {20, 20}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert Polygon.is_line_of_sight?(polygon, holes, line) == false
  end

  ##
  ## Polygon.is_inside?/outside?
  ##

  test "is_inside/outside not a polygon" do
    polygon = [{0, 0}, {2, 0}]
    point = {1, 1}
    assert Polygon.is_inside?(polygon, point) == false
    assert Polygon.is_outside?(polygon, point) == false
  end

  test "is_inside/outside triangle" do
    polygon = [{0, 0}, {2, 0}, {2, 2}]
    point = {1, 1}
    assert Polygon.is_inside?(polygon, point) == true
    assert Polygon.is_outside?(polygon, point) == false
  end

  test "is_inside/outside a box" do
    # Small Box
    polygon = [{0, 0}, {2, 0}, {2, 2}, {0, 2}]
    point = {1, 1}
    assert Polygon.is_inside?(polygon, point) == true
    assert Polygon.is_outside?(polygon, point) == false
  end

  test "is_inside/outside on edge is allowed and default" do
    # Small Box
    polygon = [{0, 0}, {2, 0}, {2, 2}, {0, 2}]
    point = {2, 1}
    assert Polygon.is_inside?(polygon, point) == true
    assert Polygon.is_outside?(polygon, point) == false
  end

  test "is_inside/outside on edge but not allowed" do
    # Small Box
    polygon = [{0, 0}, {2, 0}, {2, 2}, {0, 2}]
    point = {2, 1}
    assert Polygon.is_inside?(polygon, point, allow_border: false) == false
    assert Polygon.is_outside?(polygon, point, allow_border: false) == true
  end

  test "is_inside/outside on vertex is allowed and default" do
    # Small Box
    polygon = [{0, 0}, {2, 0}, {2, 2}, {0, 2}]
    point = {2, 2}
    assert Polygon.is_inside?(polygon, point) == true
    assert Polygon.is_outside?(polygon, point) == false
  end

  test "is_inside/outside on vertex but not allowed" do
    # Small Box
    polygon = [{0, 0}, {2, 0}, {2, 2}, {0, 2}]
    point = {2, 2}
    assert Polygon.is_inside?(polygon, point, allow_border: false) == false
    assert Polygon.is_outside?(polygon, point, allow_border: false) == true
  end

  ##
  ## Polygon.classify / is_concave / is_convex
  ##

  test "classify_vertices" do
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    assert Polygon.classify_vertices(polygon) == {[{10, 10}], [{0, 0}, {20, 0}, {20, 20}, {0, 20}]}
  end

  test "classify_vertices triangle" do
    triangle = [{50, 70}, {70, 50}, {70, 70}]
    assert Polygon.classify_vertices(triangle) == {[], triangle}
  end

  test "classify_vertices squiggle" do
    polygon = [{250, 170}, {256, 153}, {270, 160}, {295, 185}]
    assert Polygon.classify_vertices(polygon) == {[], polygon}
  end

  ##
  ## Polygon.nearest_edge
  ##

  test "nearest_edge" do
    # Box
    polygon = [{0, 0}, {2, 0}, {2, 2}, {0, 2}]
    assert Polygon.nearest_edge(polygon, {-1, 1}) == {{0, 2}, {0, 0}}
    assert Polygon.nearest_edge(polygon, {1, 2.5}) == {{2, 2}, {0, 2}}
    assert Polygon.nearest_edge(polygon, {3, 1}) == {{2, 0}, {2, 2}}
  end

  ##
  ## Polygon.nearest_point_on_edge
  ##

  test "nearest_point_on_edge" do
    # Box
    polygon = [{0, 0}, {2, 0}, {2, 2}, {0, 2}]
    # Walk around a few edges
    assert Polygon.nearest_point_on_edge(polygon, {-1, 1}) == {0, 1}
    assert Polygon.nearest_point_on_edge(polygon, {1, 2.5}) == {1, 2}
    assert Polygon.nearest_point_on_edge(polygon, {3, 1}) == {2, 1}

    # Near points of edges
    assert Polygon.nearest_point_on_edge(polygon, {3, 3}) == {2, 2}
    assert Polygon.nearest_point_on_edge(polygon, {3, -1}) == {2, 0}
    assert Polygon.nearest_point_on_edge(polygon, {-1, -1}) == {0, 0}
    assert Polygon.nearest_point_on_edge(polygon, {-1, 3}) == {0, 2}
  end

  ##
  ## Get.nearest_point
  ##

  test "nearest_point no map" do
    assert Polygon.nearest_point([], [], {{1, 1}, {2, 2}}) == {2, 2}
  end

  test "nearest_point no change needed" do
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Polygon.nearest_point(polygon, holes, {{1, 1}, {2, 1}}) == {2, 1}
  end

  test "nearest_point stop outside boundary" do
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Polygon.nearest_point(polygon, holes, {{1, 1}, {-1, 1}}) == {0, 1}
  end

  test "nearest_point stop in hole" do
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Polygon.nearest_point(polygon, holes, {{1, 6}, {5.5, 6}}) == {5, 6}
  end

  test "nearest_point stop in hole round" do
    # M shape
    polygon = [{0, 0}, {100, 0}, {200, 0}, {200, 200}, {100, 100}, {0, 200}]
    holes = [
      [{50, 70}, {70, 70}, {70, 50}],
    ]
    assert Polygon.nearest_point(polygon, holes, {{80, 80}, {69.8, 69.1}}) == {70, 69}
  end

  test "nearest_point stop in hole ceil-ceil" do
    # M shape
    polygon = [{0, 0}, {100, 0}, {200, 0}, {200, 200}, {100, 100}, {0, 200}]
    holes = [
      [{50, 70}, {69, 80}, {70, 50}],
    ]
    assert Polygon.nearest_point(polygon, holes, {{100, 90}, {68.4, 69.4}}) == {70, 70}
  end

  test "nearest_point stop in hole ceil-floor" do
   # M shape
    polygon = [{0, 0}, {100, 0}, {200, 0}, {200, 200}, {100, 100}, {0, 200}]
    holes = [
      [{50, 70}, {70, 80}, {70, 50}],
    ]
    assert Polygon.nearest_point(polygon, holes, {{80, 20}, {64, 59}}) == {63, 57}
  end
end
