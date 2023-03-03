defmodule AstarPathfind do
  require Logger

  defmodule Entry do
    defstruct [
      state: :unvisited,
      shortest_distance_from_start: nil,
      heuristic_distance_to_stop: nil,
      total_distance: nil,
      previous_node: nil,

    ]
  end

  def new(_graph, start, stop, heur_fun) do
    queue = []
      # graph
      # |> Enum.reduce(%{}, fn {{v1, v2}, _d}, acc ->
      #   Map.put(acc, v1, %Entry{heuristic_distance_to_stop: heuristic_dist_fun.(v1, stop)})
      #   Map.put(acc, v2, %Entry{heuristic_distance_to_stop: heuristic_dist_fun.(v2, stop)})
      # end)
      # |> Map.to_list
      # |> sort_queue_by_smallest_total_distance

    %{start: start, stop: stop, heur_fun: heur_fun, queue: queue}
  end

  def sort_queue_by_smallest_total_distance(state) do
    new_queue =
      state.queue
      |> Enum.sort_by(fn {_node, entry} -> entry.total_distance end, :asc)
    %{state | queue: new_queue}
  end

  def search(%{queue: []}=state) do
    state
  end

  def search(%{queue: _queue}=state) do
    state
  end

  def search_helper(state) do
    state
  end
end
