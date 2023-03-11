defmodule Scene do
  @moduledoc """
  This module contains the code related to loading the scene information from a
  json file.
  """

  # Transform a json `[x, y]` list to a `{x, y}` tuple and ensure it's a integer (trunc)
  defp transform_point([x, y]) do
    {round(x), round(y)}
  end

  # Transform a json polygon, `name, [[x, y], [x, y]...]` list to a `{name, [{x, y}, ...]}`.
  defp transform_walkbox({name, points}) do
    points = Enum.map(points, &(transform_point(&1)))
    {name, points}
  end

  defp transform_walkboxes(polygons) do
    polygons
    |> Enum.map(&(transform_walkbox(&1)))
  end

  # In case the json polygon is closed (last == first) point, drop the last
  # since we handle them as open.
  defp unclose_walkbox({name, points}) do
    if Enum.at(points, 0) == Enum.at(points, -1) do
      {name, Enum.drop(points, -1)}
    else
      {name, points}
    end
  end

  defp unclose_walkboxes(polygons) do
    polygons
    |> Enum.map(&(unclose_walkbox(&1)))
  end

  @doc """
  Helper to split polygons into the the main and the holes.

  ## Examples
  iex> Scene.classify_polygons([{:main, [{0, 0}, {10, 0}, {5, 5}]}, {:hole1, [{1, 1}, {9, 1}, {4, 5}]}])
  {[{0, 0}, {10, 0}, {5, 5}], [[{1, 1}, {9, 1}, {4, 5}]]}
  """
  def classify_polygons(polygons) do
    {mains, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)
    holes = Enum.map(holes, fn {_name, polygon} -> polygon end)
    {mains[:main], holes}
  end

  # Quick and dirty tap function that'll crash if any polygon isn't clockwise.
  defp check_clockwise(polygons) do
    true = Enum.all?(polygons, fn {_name, polygon} -> Polygon.is_clockwise?(polygon) end)
  end

  @doc """
  Load and prepare a a json file from `priv/`.

  Eg. `load("complex")` will load `priv/complex.json`.

  ## Examples
      iex> Scene.load("scene1")
      {{50, 50}, [hole: [{300, 200}, {400, 200}, {400, 300}, {300, 300}], main: [{40, 40}, {590, 40}, {590, 460}, {40, 460}]]}
  """
  def load(scene) do
    path = Application.app_dir(:astarwx)
    filename = "#{path}/priv/#{scene}.json"
    {:ok, file} = File.read(filename)
    {:ok, json} = Poison.decode(file, keys: :atoms)

    polygons =
      json[:polygons]
      |> transform_walkboxes
      |> unclose_walkboxes
      |> tap(&check_clockwise/1)

    {
      transform_point(json[:start]),
      polygons,
    }
  end
end
