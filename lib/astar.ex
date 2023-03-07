defmodule AstarPathfind do
  require Logger

  def search(graph, start, stop, heur_fun) do
    # Logger.info("----------------------------------------- A-star")
    # Logger.info("graph = #{inspect graph, pretty: true}")
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

      # node => cost - distance from start to node
      g_cost: %{},
      # vertice => cost, distance from start to vervice + heuristic distance to stop
      f_cost: %{}
    }
    |> search_timed
    |> get_path
  end

  def sort_queue(queue, f_cost) do
    Enum.sort_by(queue, fn e -> Map.get(f_cost, e) end, :asc)
  end

  def add_to_queue(queue, node) do
    Enum.sort(queue ++ [node])
    |> Enum.dedup
  end

  def search_timed(state) do
    start_us = System.convert_time_unit(System.monotonic_time, :native, :microsecond)
    state = search_helper(state)
    end_us = System.convert_time_unit(System.monotonic_time, :native, :microsecond)
    elapsed_us = trunc(end_us - start_us)
    Logger.info("A-star search took #{elapsed_us}µs")
    state
  end

  def search_helper(%{queue: []}=state) do
    state
  end

  def search_helper(%{queue: [current|queue]}=state) do
    # Logger.info("----------------------------------------- A-star search")
    # Logger.info("current = #{inspect current, pretty: true}")
    # Logger.info("state = #{inspect Map.delete(state, :graph), pretty: true}")

    spt = Map.put(state.shortest_path_tree, current, Map.get(state.frontier, current))

    cond do
      current == state.stop ->
        # Logger.info("stop, spt = #{inspect spt, pretty: true}")
        %{state | shortest_path_tree: spt}
      true ->
        edges = Map.get(state.graph, current, [])

        # Logger.info("edges = #{inspect edges, pretty: true}")

        reduce_seed = {state.frontier, queue, state.g_cost, state.f_cost}

        {f, q, g_cost, f_cost} =
          Enum.reduce(edges, reduce_seed, fn {node, edge_cost}, acc ->
            {frontier, queue, g_cost, f_cost} = acc
            # H cost
            heur_cost = state.heur_fun.(node, state.stop)
            # G cost
            shortest_distance_from_start = Map.get(g_cost, current, 0) + edge_cost
            # F cost = G cost + H cost
            total_distance = shortest_distance_from_start + heur_cost
            # Logger.info("\t#{inspect node} heur_cost = #{heur_cost}")
            # Logger.info("\t#{inspect node} new g_cost = #{shortest_distance_from_start}")
            # Logger.info("\t#{inspect node} new cost = #{total_distance}\n")

            cond do
              node == state.start ->
                # No reason to go back
                # Logger.info("skip going back to start")
                acc
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

  def get_path(state) do
    next = state.shortest_path_tree[state.stop]
    get_path(state, state.start, next, [state.stop])
    |> Enum.reverse
  end

  def get_path(_state, _start, nil, acc) do
    acc
  end

  def get_path(_state, start, start, acc) do
    acc ++ [start]
  end

  def get_path(state, start, node, acc) do
    next = state.shortest_path_tree[node]
    get_path(state, start, next, acc ++ [node])
  end
end
