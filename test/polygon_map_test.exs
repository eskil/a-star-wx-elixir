defmodule PolygonMapTest do
  use ExUnit.Case, async: true

  doctest PolygonMap

  ##
  ## PolygonMap.nearest_point
  ##

  test "nearest_point no map" do
    assert PolygonMap.nearest_point([], [], {{1, 1}, {2, 2}}) == {2, 2}
  end

  test "nearest_point no change needed" do
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert PolygonMap.nearest_point(polygon, holes, {{1, 1}, {2, 1}}) == {2, 1}
  end

  test "nearest_point stop outside boundary" do
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert PolygonMap.nearest_point(polygon, holes, {{1, 1}, {-1, 1}}) == {0, 1}
  end

  test "nearest_point stop in hole" do
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 7}, {7, 7}, {7, 5}, {5, 5}],
      [{15, 7}, {17, 7}, {17, 5}, {15, 5}],
    ]
    assert PolygonMap.nearest_point(polygon, holes, {{1, 6}, {5.5, 6}}) == {5, 6}
  end

  test "nearest_point stop in hole round" do
    # M shape
    polygon = [{0, 0}, {100, 0}, {200, 0}, {200, 200}, {100, 100}, {0, 200}]
    holes = [
      [{50, 70}, {70, 70}, {70, 50}],
    ]
    assert PolygonMap.nearest_point(polygon, holes, {{80, 80}, {69.8, 69.1}}) == {70, 69}
  end

  test "nearest_point stop in hole ceil-ceil" do
    # M shape
    polygon = [{0, 0}, {100, 0}, {200, 0}, {200, 200}, {100, 100}, {0, 200}]
    holes = [
      [{50, 70}, {69, 80}, {70, 50}],
    ]
    assert PolygonMap.nearest_point(polygon, holes, {{100, 90}, {68.4, 69.4}}) == {70, 70}
  end

  test "nearest_point stop in hole ceil-floor" do
   # M shape
    polygon = [{0, 0}, {100, 0}, {200, 0}, {200, 200}, {100, 100}, {0, 200}]
    holes = [
      [{50, 70}, {70, 80}, {70, 50}],
    ]
    assert PolygonMap.nearest_point(polygon, holes, {{80, 20}, {64, 59}}) == {63, 57}
  end

  ##
  ## PolygonMap.is_line_of_sight?
  ##

  test "is_line_of_sight? line is outside and no intersection" do
    line = {{10, 30}, {20, 30}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line is inside and no intersection" do
    line = {{8, 2}, {12, 2}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line starts inside and ends outside" do
    line = {{18, 2}, {22, 2}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line starts outside and ends inside" do
    line = {{22, 2}, {18, 2}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside and doesn't touch holes" do
    line = {{10, 6}, {12, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line in inside but ends in a hole" do
    line = {{6, 6}, {12, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but intersects a hole" do
    line = {{3, 6}, {12, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but intersects a hole through a vertice" do
    line = {{4, 4}, {8, 8}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line in inside but touches a hole on an edge" do
    line = {{4, 6}, {5, 6}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line in inside but touches a hole on a vertex" do
    line = {{4, 8}, {5, 7}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == true
  end

  test "is_line_of_sight? line is from corner to corner of hole" do
    line = {{5, 5}, {7, 7}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end

  test "is_line_of_sight? line is from corner to corner of polygon but outside" do
    line = {{0, 20}, {20, 20}}
    # M shape
    polygon = [{0, 0}, {10, 0}, {20, 0}, {20, 20}, {10, 10}, {0, 20}]
    holes = [
      [{5, 5}, {7, 5}, {7, 7}, {5, 7}],
      [{15, 5}, {17, 5}, {17, 7}, {15, 7}],
    ]
    assert PolygonMap.is_line_of_sight?(polygon, holes, line) == false
  end
end
