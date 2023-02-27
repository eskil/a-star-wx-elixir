defmodule GeoTest do
  use ExUnit.Case, async: true

  doctest Geo

  test "detects intersection" do
    line = {{0, 0}, {10, 10}}
    polygon = [{0, 10}, {10, 10}, {10, 0}, {0, 0}, {0, 10}]
    offset_polygon = Enum.map(polygon, fn {x, y} -> {x + 5, y + 5} end)
    assert Geo.intersects?(line, offset_polygon) == {:intersection, {5.0, 5.0}}
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
    assert Geo.intersection(line, polygon) == {6.0, 8.0}
  end

  test "find nearest intersection when there's no intersections" do
    line = {{6, 1}, {6, 3}}
    polygon = [{0, 20}, {10, 20}, {5, 10}, {10, 0}, {0, 0}, {0, 20}]
    assert Geo.intersection(line, polygon) == nil
  end
end
