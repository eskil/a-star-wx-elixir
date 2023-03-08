defmodule AstarWx do
  @moduledoc false

  require Logger

  @behaviour :wx_object
  @title "A-star Wx Demo"
  @width 640
  @height 500
  @size {@width, @height}

  def start_link(args) do
    :wx_object.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("starting")

    fps = Application.get_env(:astarwx, :fps, 30)
    slice = trunc(1_000 / fps)

    # Setup window
    wx = :wx.new([{:debug, :verbose}, {:silent_start, false}])

    frame_id = System.unique_integer([:positive, :monotonic])
    frame = :wxFrame.new(wx, frame_id, @title, size: @size)
    :wxFrame.connect(frame, :size)
    :wxFrame.connect(frame, :close_window)

    panel = :wxPanel.new(frame, [])
    # https://www.erlang.org/doc/man/wxmouseevent#type-wxMouseEventType
    :wxPanel.connect(panel, :paint, [:callback])
    :wxPanel.connect(panel, :left_up)
    :wxPanel.connect(panel, :left_down)
    :wxFrame.connect(panel, :motion)
    :wxPanel.connect(panel, :enter_window)
    :wxPanel.connect(panel, :leave_window)

    :wxFrame.show(frame)

    cursor = :wxCursor.new(Wx.wxCURSOR_BLANK)
    :wxWindow.setCursor(panel, cursor)

    # This is what we draw on.
    blitmap = :wxBitmap.new(@width, @height)
    memory_dc = :wxMemoryDC.new(blitmap)

    Logger.info("starting timer #{slice}ms")
    timer_ref = Process.send_after(self(), :tick, slice)

    {start, polygons} = Scene.load("complex")

    walk_vertices = get_walk_vertices(polygons)
    walk_graph = create_walk_graph(polygons, walk_vertices)

    Logger.info("walk graphs = #{inspect walk_graph, pretty: true}")

    state = %{
      wx_frame: frame,
      wx_panel: panel,
      wx_memory_dc: memory_dc,

      updated_at: nil,

      timer_ref: timer_ref,
      slice: slice,

      # Start point to search from
      start: start,
      # Where the cursor is, also our stop point for saerch
      cursor: nil,

      polygons: polygons,

      # This is the list of fixed vertices (from the map) that we will draw
      fixed_walk_vertices: walk_vertices,

      # This is the fixed walk graph (from fixed_walk_vertices) that we'll
      # outline in red
      fixed_walk_graph: walk_graph,

      # This is the computed path we'll draw in green
      path: [],

      # This is the extended walk graph path we'll draw in orange while the
      # mouse is being pressed
      click_walk_graph: nil,
    }
    {frame, state}
  end

  ##
  ## Wx Async Events
  ##

  @impl true
  def handle_event({:wx, _, _, _, {:wxSize, :size, size, _}}=event, state) do
    Logger.info("received size event: #{inspect(event)}")
    :wxPanel.setSize(state.wx_panel, size)
    {:noreply, state}
  end

  @impl true
  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}=event, state) do
    Logger.info("received close event: #{inspect(event)}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :enter_window,
                     x, y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event, state) do
    {:noreply, %{state | cursor: {x, y}}}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :leave_window,
                     _x, _y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event, state) do
    {:noreply, %{state | cursor: nil}}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :motion, x, y,
                     true, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event, state
  ) do
    stop = {x, y}
    {graph, _vertices, path} = get_updated_graph_vertices_path(state.polygons, state.fixed_walk_vertices, state.fixed_walk_graph, state.start, stop)

    {:noreply, %{
        state |
        click_walk_graph: graph,
        cursor: stop,
        path: path,
     }
    }
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :motion, x, y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event, state) do
    {:noreply, %{state | cursor: {x, y}}}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :left_down,
                     x, y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event,
    state
  ) do
    Logger.info("click #{inspect {x, y}}")
    stop = {x, y}
    {graph, _vertices, path} = get_updated_graph_vertices_path(state.polygons, state.fixed_walk_vertices, state.fixed_walk_graph, state.start, stop)

    {:noreply, %{
        state |
        click_walk_graph: graph,
        path: path,
     }
    }
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :left_up,
                     x, y,
                     _left_up, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event,
    state
  ) do
    Logger.info("click #{inspect {x, y}}")
    # Reset fields so we only show the debug graph
    {:noreply, %{
        state |
        click_walk_graph: nil,
        start: {x, y},
        path: [],
     }
    }
  end

  @impl true
  def handle_event({:wx, _, _, _, _} = event, state) do
    Logger.info("unhandled wx event #{inspect event, pretty: true}")
    {:noreply, state}
  end

  ##
  ## Wx Sync Events
  ##

  @impl true
  def handle_sync_event({:wx, _, _, _, {:wxPaint, :paint}}=_event, _, state) do
    dc = state.wx_memory_dc
    WxUtils.wx_cls(dc)

    draw_polygons(dc, state.polygons)

    if state.cursor do
      line = {state.start, state.cursor}
      draw_a_b_line(dc, line, state.polygons)
      draw_cursors(dc, state.start, state.cursor, state.polygons)
    end

    draw_walk_vertices(dc, state)
    draw_walk_graph(dc, state)
    draw_walk_path(dc, state)

    # Draw
    paint_dc = :wxPaintDC.new(state.wx_panel)
    :wxDC.blit(paint_dc, {0, 0}, @size, dc, {0, 0})
    :wxPaintDC.destroy(paint_dc)

    :ok
  end

  @impl true
  def handle_sync_event(event, _, _state) do
    Logger.info("received sync event: #{inspect event, pretty: true}")
    :ok
  end

  ##
  ## Ticks
  ##

  @impl true
  def handle_info(:tick, state) do
    # This is called at the configured frame rate, and updates state (nothing
    # in this example), rerenders the screen and schedules the timer for next
    # frame.
    {elapsed_usec, {:ok, new_state}} = :timer.tc(fn ->
      new_state = update(state)
      :ok = render(new_state)
      {:ok, new_state}
    end)
    pause = max(0, state[:slice] - trunc(elapsed_usec / 1_000))
    timer_ref = Process.send_after(self(), :tick, pause)
    {:noreply, %{new_state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, _state) do
    Logger.info("A child process died: #{reason}")
  end

  @impl true
  def handle_info(msg, state) do
    Logger.error("received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating, #{inspect reason}")
    stop(state)
    exit(reason)
  end

  ##
  ## Gfx Loop
  ##

  def update(state) do
    state
  end

  def render(state) do
    :wxPanel.refresh(state.wx_panel, eraseBackground: false)
  end

  def stop(_state) do
    Logger.info("stopping")
  end

  ##
  ## Render helper funtions
  ##

  def draw_cursors(dc, start, cursor, polygons) do
    light_gray = {211, 211, 211}
    bright_red = {255, 0, 0}
    bright_green = {0, 255, 0}

    {main, holes} = Scene.classify_polygons(polygons)

    WxUtils.wx_crosshair(dc, start, bright_green, size: 6)

    if Geo.is_inside?(main, cursor) do
      if Enum.any?(holes, &(Geo.is_inside?(&1, cursor))) do
        WxUtils.wx_crosshair(dc, cursor, light_gray, size: 6)
      else
        WxUtils.wx_crosshair(dc, cursor, bright_red, size: 6)
      end
    else
      WxUtils.wx_crosshair(dc, cursor, light_gray, size: 6)
    end
  end

  def draw_polygons(dc, polygons) do
    blue = {0, 150, 255}
    opaque_blue = {0, 150, 255, 64}

    blue_pen = :wxPen.new(blue, [{:width,  1}, {:style, Wx.wxSOLID}])

    brush = :wxBrush.new({0, 0, 0}, [{:style, Wx.wxSOLID}])
    opaque_blue_brush = :wxBrush.new(opaque_blue, [{:style, Wx.wxSOLID}])

    {main, holes} = Scene.classify_polygons(polygons)

    :wxDC.setBrush(dc, opaque_blue_brush)
    :wxDC.setPen(dc, blue_pen)
    :ok = :wxDC.drawPolygon(dc, main)
    for point <- main do
      WxUtils.wx_crosshair(dc, point, blue)
    end

    :wxDC.setBrush(dc, brush)
    :wxDC.setPen(dc, blue_pen)
    for polygon <- holes do
      :ok = :wxDC.drawPolygon(dc, polygon)
      for point <- polygon do
        WxUtils.wx_crosshair(dc, point, blue)
      end
    end

    :wxPen.destroy(blue_pen)
    :wxBrush.destroy(brush)
    :wxBrush.destroy(opaque_blue_brush)
  end

  def draw_walk_vertices(dc, state) do
    blue = {0, 150, 255}
    opaque_blue = {0, 150, 255, 64}

    blue_pen = :wxPen.new(blue, [{:width,  1}, {:style, Wx.wxSOLID}])
    brush = :wxBrush.new(opaque_blue, [{:style, Wx.wxSOLID}])

    :wxDC.setPen(dc, blue_pen)
    :wxDC.setBrush(dc, brush)

    for point <- state.fixed_walk_vertices do
      :wxDC.drawCircle(dc, point, 5)
    end

    :wxPen.destroy(blue_pen)
    :wxBrush.destroy(brush)
  end

  def draw_a_b_line(dc, {a, b}=line, polygons) do
    brush = :wxBrush.new({0, 0, 0}, [{:style, Wx.wxTRANSPARENT}])
    :wxDC.setBrush(dc, brush)

    light_gray = {211, 211, 211, 128}
    light_gray_pen = :wxPen.new(light_gray, [{:width,  1}, {:style, Wx.wxSOLID}])

    bright_green = {0, 255, 0}
    bright_green_pen = :wxPen.new(bright_green, [{:width,  1}, {:style, Wx.wxSOLID}])

    {main, holes} = Scene.classify_polygons(polygons)

    if Geo.is_line_of_sight?(main, holes, line) do
      :wxDC.setPen(dc, bright_green_pen)
    else
      :wxDC.setPen(dc, light_gray_pen)
    end
    :ok = :wxDC.drawLine(dc, a, b)

    intersections = for {_name, points} <- polygons do
      Geo.intersections(line, points)
    end
    |> List.flatten
    |> Enum.sort(fn ia, ib ->
      v1 = Vector.sub(a, ia)
      v2 = Vector.sub(a, ib)
      Vector.distance(a, v1) < Vector.distance(a, v2)
    end)
    |> Enum.map(&(Vector.trunc_pos(&1)))

    for p <- intersections do
      WxUtils.wx_crosshair(dc, p, light_gray, size: 3)
    end

    case intersections do
      [] -> nil
      [p|_] -> WxUtils.wx_crosshair(dc, p, {255, 0, 0}, size: 3)
    end

    :wxPen.destroy(light_gray_pen)
    :wxPen.destroy(bright_green_pen)
    :wxBrush.destroy(brush)
  end

  def draw_walk_graph(dc, state) do
    light_red = {255, 0, 0, 64}
    bright_red = {255, 87, 51, 128}
    light_red_pen = :wxPen.new(light_red, [{:width,  1}, {:style, Wx.wxSOLID}])
    bright_red_pen = :wxPen.new(bright_red, [{:width,  1}, {:style, Wx.wxSOLID}])

    if state.click_walk_graph do
      :wxDC.setPen(dc, bright_red_pen)
      for {a, edges} <- state.click_walk_graph do
        for {b, _} <- edges do
          :ok = :wxDC.drawLine(dc, a, b)
        end
      end
    else
      :wxDC.setPen(dc, light_red_pen)
      for {a, edges} <- state.fixed_walk_graph do
        for {b, _} <- edges do
          :ok = :wxDC.drawLine(dc, a, b)
        end
      end
    end

    :wxPen.destroy(light_red_pen)
    :wxPen.destroy(bright_red_pen)
  end

  def draw_walk_path(dc, state) do
    bright_green_pen = :wxPen.new({64, 255, 64}, [{:width,  2}, {:style, Wx.wxSOLID}])
    :wxDC.setPen(dc, bright_green_pen)

    pointsets = Enum.chunk_every(state.path, 2, 1)
    Enum.map(pointsets, fn
      [a, b] ->
        :ok = :wxDC.drawLine(dc, a, b)
      _ ->
        :ok
    end)

    :wxPen.destroy(bright_green_pen)
  end

  # Convert time in microseconds to "pretty" time.
  defp usec_to_str(usec) when usec < 1_000 do
    "#{usec}µs"
  end

  defp usec_to_str(usec) when usec < 1_000_000 do
    "#{usec/1_000}ms"
  end

  defp usec_to_str(usec)  do
    "#{usec/1_000_000}s"
  end

  def get_updated_graph_vertices_path(polygons, vertices, graph, start, stop) do
    line = {start, stop}
    {main, holes} = Scene.classify_polygons(polygons)
    np = Geo.nearest_point(main, holes, line)

    {graph_usec, {new_graph, new_vertices}} = :timer.tc(fn -> extend_graph(polygons, graph, vertices, [start, np]) end)

    {astar_usec, path} = :timer.tc(fn ->
      astar = AstarPathfind.search(new_graph, start, np, fn a, b -> Vector.distance(a, b) end)
      AstarPathfind.get_path(astar)
    end)

    # Curtesy compute and print distance.
    distance =
      path
      |> Enum.chunk_every(2, 1)
      |> Enum.reduce(0, fn
        [a, b], acc -> acc + Vector.distance(a, b)
        _, acc -> acc
      end)
    Logger.info("graph extend = #{usec_to_str(graph_usec)} a-star=#{usec_to_str(astar_usec)} distance = #{distance}")

    {new_graph, new_vertices, path}
  end

  @doc """
  Given a list of polygons (main, & holes), returns a list of vertices.

  The vertices are the main polygon's concave vertices and the convex ones of
  the holes.
  """
  # TODO: move to a polygon_map.ex
  def get_walk_vertices(polygons) do
    {main, holes} = Scene.classify_polygons(polygons)
    {concave, _convex} = Geo.classify_vertices(main)

    convex = Enum.reduce(holes, [], fn points, acc ->
      {_, convex} = Geo.classify_vertices(points)
      acc ++ convex
    end)
    Logger.info("convex = #{inspect convex, pretty: true}")

    concave ++ convex
  end

  # TODO: move to a polygon_map.ex
  def get_edges(polygon, holes, points_a, points_b) do
    cost_fun = fn a, b -> Vector.distance(a, b) end
    is_reachable? = fn a, b -> Geo.is_line_of_sight?(polygon, holes, {a, b}) end

    # O(n^2) check all vertice combos for reachability...
    {_, all_edges} =
      Enum.reduce(points_a, {0, %{}}, fn a, {a_idx, acc1} ->
        {_, inner_edges} =
          Enum.reduce(points_b, {0, []}, fn b, {b_idx, acc2} ->
            # NOTE: this is where the edge value is becomes the key in the
            # graph. This is why a_idx and b_idx are available here, in case we
            # want to change it up to be the indexes into points. Unless those
            # two sets are the same, using the indexes makes no sense.
            if a != b and is_reachable?.(a, b) do
              {b_idx + 1, acc2 ++ [{b, cost_fun.(a, b)}]}
            else
              {b_idx + 1, acc2}
            end
          end)
        {a_idx + 1, Map.put(acc1, a, inner_edges)}
      end)
    Map.new(all_edges)
  end

  @doc """
  Given a polygon map (main & holes) and list of vertices, makes the graph.
  """
  # TODO: move to a polygon_map.ex
  def create_walk_graph(polygons, vertices) do
    {main, holes} = Scene.classify_polygons(polygons)
    get_edges(main, holes, vertices, vertices)
  end

  @doc """
  Given a polygon map (main & holes), list of vertices and the initial graph,
  extend the graph with extra `points`.

  This is used to "temporarily" expand the fixed walk graph with the start and
  end-point. This is a performance optimisation that saves work by reusing the
  fixed nodes and extend it with the moveable points.

  ## Params
  * `polygons`, a `%{main: [...], hole: [...], hole2: [...]}` polygon map.
  * `graph`, the fixed graph, eg. created via `create_walk_graph/2`.
  * `vertices` the nodes used to create `graph`.
  * `points` a list of coordinates, `[{x, y}, {x, y}...]`, to extend

  """
  # TODO: move to a polygon_map.ex
  def extend_graph(polygons, graph, vertices, points) do
    {main, holes} = Scene.classify_polygons(polygons)

    # To extend the graph `graph` made up up `vertices` with new points
    # `points`, we need to find three sets of edges (sub-graphs). The ones from
    # the new points to the existing vertices, vice-versa, and between the new
    # points.
    set_a = get_edges(main, holes, points, vertices)
    set_b = get_edges(main, holes, vertices, points)
    set_c = get_edges(main, holes, points, points)
    # Logger.info("set_a, points to vertices = #{inspect set_a, pretty: true}")
    # Logger.info("set_b, points to vertices = #{inspect set_b, pretty: true}")
    # Logger.info("set_c, points to points = #{inspect set_c, pretty: true}")

    # Merge the three new sub-graphs into graph. This uses Map.merge with a
    # merge func that combines values for identical keys (basically extend
    # them) and dedupes.
    merge_fun = fn _k, v1, v2 ->
      Enum.dedup(v1 ++ v2)
    end
    graph =
      graph
      |> Map.merge(set_a, merge_fun)
      |> Map.merge(set_b, merge_fun)
      |> Map.merge(set_c, merge_fun)

    {graph, vertices ++ points}
  end
end
