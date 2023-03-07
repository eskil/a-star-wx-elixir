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
    Logger.info("transform box -> #{inspect points}")
    points = Enum.map(points, &(transform_point(&1)))
    Logger.info("transform box <- #{inspect points}")
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

  def load() do
    path = Application.app_dir(:astarwx)
    # filename = "#{path}/priv/scene1.json"
    filename = "#{path}/priv/complex.json"
    Logger.info("Processing #{filename}")
    {:ok, file} = File.read(filename)
    {:ok, json} = Poison.decode(file, keys: :atoms)
    Logger.info("#{inspect json, pretty: true}")
    polygons =
      json[:polygons]
      |> transform_walkboxes
      |> unclose_walkboxes
    Logger.info("#{inspect polygons, pretty: true}")
    {
      transform_point(json[:start]),
      polygons,
    }
  end
end