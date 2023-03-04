defmodule AstarPathfind do
  require Logger

  def new(graph, start, stop, heur_fun) do
    queue = [start]

    %{
      start: start,
      stop: stop,
      graph: graph,

      # (node, node) :: cost function
      heur_fun: heur_fun,

      queue: queue,
      shortest_path_tree: %{},
      frontier: %{},

      # Distance from start to node
      g_cost: %{},
      # Distance from start to node + heuristic distance to end
      f_cost: %{}
    }
  end

  def sort_queue(queue, f_cost) do
    Enum.sort_by(queue, fn e -> Map.get(f_cost, e) end, :asc)
  end

  def add_to_queue(queue, node) do
    Enum.sort(queue ++ [node])
    |> Enum.dedup
  end

  def search(state) do
    search_helper(state)
  end

  def search_helper(%{queue: []}=state) do
    state
  end

  def search_helper(%{queue: [current|queue]}=state) do
    # Logger.info("\n\n\n-----------------------------------------\nSEARCH")
    # Logger.info("state = #{inspect state, pretty: true}")
    # Logger.info("current = #{inspect current, pretty: true}")

    spt = Map.put(state.shortest_path_tree, current, Map.get(state.frontier, current))

    if current == state.stop do
      # Logger.info("stop, spt = #{inspect spt, pretty: true}")
      %{state | shortest_path_tree: spt}
    else
      edges = Map.get(state.graph, current, [])

      # Logger.info("edges = #{inspect edges, pretty: true}")

      seed = {state.frontier, queue, state.g_cost, state.f_cost}
      {f, q, g_cost, f_cost} = Enum.reduce(edges, seed, fn {node, edge_cost}, acc ->
        {frontier, queue, g_cost, f_cost} = acc
        # H cost
        heur_cost = state.heur_fun.(node, state.stop)
        # G cost
        shortest_distance_from_start = Map.get(g_cost, current, 0) + edge_cost
        # F cost = G cost + H cost
        total_distance = shortest_distance_from_start + heur_cost

        cond do
          not Map.has_key?(frontier, node) ->
            {
              Map.put(frontier, node, current),
              add_to_queue(queue, node),
              Map.put(g_cost, node, shortest_distance_from_start),
              Map.put(f_cost, node, total_distance),
            }
          shortest_distance_from_start < Map.get(g_cost, current, 0) and Map.get(spt, node) == nil ->
            {
              Map.put(frontier, node, current),
              queue,
              Map.put(g_cost, node, shortest_distance_from_start),
              Map.put(f_cost, node, total_distance),
            }
          true ->
            {frontier, queue, g_cost, f_cost}
        end
      end)

      new_state = %{
        state |
        queue: sort_queue(q, f_cost),
        frontier: f,
        f_cost: f_cost,
        g_cost: g_cost,
        shortest_path_tree: spt,
      }
      search_helper(new_state)
    end
  end

  def get_path(state, stop) do
    next = state.shortest_path_tree[stop]
    Logger.info("start")
    get_path(state, next, [stop])
    |> Enum.reverse
  end

  def get_path(_state, nil, acc) do
    Logger.info("fin")
    acc
  end

  def get_path(state, node, acc) do
    next = state.shortest_path_tree[node]
    Logger.info("skip #{inspect next} #{inspect node}")
    get_path(state, next, acc ++ [node])
  end
end
