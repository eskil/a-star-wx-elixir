defmodule Scene do
  @moduledoc """
  This module contains the code related to loading the scene information from a
  json file.
  """

  require Logger

  # Transform a json `[x, y]` list to a `{x, y}` tuple and ensure it's a integer (trunc)
  defp transform_point([x, y]) do
    {round(x), round(y)}
  end

  # Transform a json polygon, `name, [[x, y], [x, y]...]` list to a `{name, [{x, y}, ...]}`.
  def transform_walkbox({name, points}) do
    points = Enum.map(points, &(transform_point(&1)))
    {name, points}
  end

  def transform_walkboxes(polygons) do
    polygons
    |> Enum.map(&(transform_walkbox(&1)))
  end

  # In case the json polygon is closed (last == first) point, drop the last
  # since we handle them as open.
  def unclose_walkbox({name, points}) do
    if Enum.at(points, 0) == Enum.at(points, -1) do
      {name, Enum.drop(points, -1)}
    else
      {name, points}
    end
  end

  def unclose_walkboxes(polygons) do
    polygons
    |> Enum.map(&(unclose_walkbox(&1)))
  end

  def classify_polygons(polygons) do
    {mains, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)
    holes = Enum.map(holes, fn {_name, polygon} -> polygon end)
    {mains[:main], holes}
  end

  # Quick and dirty tap function that'll crash if any polygon isn't clockwise.
  defp check_clockwise(polygons) do
    true = Enum.all?(polygons, fn {_name, polygon} -> Polygon.is_clockwise?(polygon) end)
  end

  def load(scene) do
    path = Application.app_dir(:astarwx)
    filename = "#{path}/priv/#{scene}.json"
    Logger.info("Processing #{filename}")
    {:ok, file} = File.read(filename)
    {:ok, json} = Poison.decode(file, keys: :atoms)
    Logger.info("JSON #{inspect json, pretty: true}")

    polygons =
      json[:polygons]
      |> transform_walkboxes
      |> unclose_walkboxes
      |> tap(&check_clockwise/1)

    Logger.info("Polygons #{inspect polygons, pretty: true}")

    {
      transform_point(json[:start]),
      polygons,
    }
  end
end
