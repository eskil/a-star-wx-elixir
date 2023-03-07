defmodule GeoTest do
  use ExUnit.Case, async: true

  # This should be used in the doctests to keep them readable.
  # polygon = [{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 0.5}, {0, 1}]

  doctest Geo

  test "detects intersection" do
    line = {{0, 0}, {10, 10}}
    polygon = [{0, 10}, {10, 10}, {10, 0}, {0, 0}, {0, 10}]
    offset_polygon = Enum.map(polygon, fn {x, y} -> {x + 5, y + 5} end)
    assert Geo.intersects?(line, offset_polygon) == {:point_intersection, {5.0, 5.0}}
  end

  test "detects no intersection" do
    line = {{20, 20}, {30, 30}}
    polygon = [{0, 10}, {10, 10}, {10, 0}, {0, 0}, {0, 10}]
    offset_polygon = Enum.map(polygon, fn {x, y} -> {x + 5, y + 5} end)
    assert Geo.intersects?(line, offset_polygon) == :nointersection
  end

  test "can get multiple intersections when there's two points" do
    line = {{6, 1}, {6, 19}}
    polygon = [{0, 20}, {10, 20}, {5, 10}, {10, 0}, {0, 0}, {0, 20}]
    assert Geo.intersections(line, polygon) == [{6.0, 12.0}, {6.0, 8.0}]
  end

  test "can get multiple intersections when there's no intersections" do
    line = {{6, 1}, {6, 3}}
    polygon = [{0, 20}, {10, 20}, {5, 10}, {10, 0}, {0, 0}, {0, 20}]
    assert Geo.intersections(line, polygon) == []
  end

  test "find nearest intersection when there's two points" do
    line = {{6, 1}, {6, 19}}
    polygon = [{0, 20}, {10, 20}, {5, 10}, {10, 0}, {0, 0}, {0, 20}]
    assert Geo.first_intersection(line, polygon) == {6.0, 8.0}
  end

  test "find nearest intersection when there's no intersections" do
    line = {{6, 1}, {6, 3}}
    polygon = [{0, 20}, {10, 20}, {5, 10}, {10, 0}, {0, 0}, {0, 20}]
    assert Geo.first_intersection(line, polygon) == nil
  end

  test "is_line_of_sight? line is outside and no intersection" do
    line = {{10, 30}, {20, 30}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 10}, {10, 5}, {0, 10}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line is inside and no intersection" do
    line = {{8, 2}, {12, 2}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line starts inside and ends outside" do
    line = {{18, 2}, {22, 2}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line starts outside and ends inside" do
    line = {{22, 2}, {18, 2}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside and doesn't touch holes" do
    line = {{10, 6}, {12, 6}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line in inside but ends in a hole" do
    line = {{6, 6}, {12, 6}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but intersects a hole" do
    line = {{3, 6}, {12, 6}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but intersects a hole through a vertice" do
    line = {{4, 4}, {8, 8}}
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert Geo.is_line_of_sight?(polygon, holes, line) == false
  end
end
