defmodule AstarWx do
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

    # This is what we draw on.
    blitmap = :wxBitmap.new(@width, @height)
    memory_dc = :wxMemoryDC.new(blitmap)

    Logger.info("starting timer #{slice}ms")
    timer_ref = Process.send_after(self(), :tick, slice)

    {start, polygons} = load_scene()

    Logger.info("\n\n\n")
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

      start: start,
      polygons: polygons,
      cursor: nil,

      fixed_walk_vertices: walk_vertices,
      debug_walk_graph: walk_graph,

      walk_vertices: nil,
      walk_graph: nil,
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
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event, state) do
    stop = {x, y}
    line = {state.start, stop}
    np = find_nearest_point(state.polygons, line)

    walk_vertices = state.fixed_walk_vertices ++ [state.start, np]
    walk_graph = create_walk_graph(state.polygons, walk_vertices)

    {:noreply, %{
        state |
        walk_vertices: walk_vertices,
        walk_graph: walk_graph,
        cursor: stop,
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
                     left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event,
    state
  ) do
    Logger.info("click #{inspect {x, y}} #{left_down}")
    stop = {x, y}
    line = {state.start, stop}
    np = find_nearest_point(state.polygons, line)

    walk_vertices = state.fixed_walk_vertices ++ [state.start, np]
    walk_graph = create_walk_graph(state.polygons, walk_vertices)
    {:noreply, %{state | walk_vertices: walk_vertices, walk_graph: walk_graph}}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :left_up,
                     x, y,
                     left_up, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}}=_event,
    state
  ) do
    Logger.info("click #{inspect {x, y}} #{left_up}")
    # Reset fields so we only show the debug graph
    {:noreply, %{state | walk_vertices: nil, walk_graph: nil}}
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

    light_red = {255, 0, 0, 128}
    bright_red = {255, 87, 51, 192}
    green = {0, 255, 0}

    light_red_pen = :wxPen.new(light_red, [{:width,  1}, {:style, Wx.wxSOLID}])
    bright_red_pen = :wxPen.new(bright_red, [{:width,  1}, {:style, Wx.wxSOLID}])

    brush = :wxBrush.new({0, 0, 0}, [{:style, Wx.wxTRANSPARENT}])

    draw_polygons(dc, state.polygons)

    WxUtils.wx_crosshair(dc, state.start, green, size: 6)
    if state.cursor do
      line = {state.start, state.cursor}
      draw_a_b_line(dc, line, state.polygons)
      draw_cursor(dc, state.cursor, state.polygons)
    end

    if state.walk_graph do
      :wxDC.setPen(dc, bright_red_pen)
      for {{a, b}, _} <- state.walk_graph do
        :ok = :wxDC.drawLine(dc, a, b)
      end
    else
      :wxDC.setPen(dc, light_red_pen)
      for {{a, b}, _} <- state.debug_walk_graph do
        :ok = :wxDC.drawLine(dc, a, b)
      end
    end

    # Draw
    paint_dc = :wxPaintDC.new(state.wx_panel)
    :wxDC.blit(paint_dc, {0, 0}, @size, dc, {0, 0})

    # Cleanup :-/
    :wxPaintDC.destroy(paint_dc)
    :wxPen.destroy(light_red_pen)
    :wxPen.destroy(bright_red_pen)
    :wxBrush.destroy(brush)

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
    start_ms = System.convert_time_unit(System.monotonic_time, :native, :millisecond)

    new_state = update(state)
    render(new_state)

    end_ms = System.convert_time_unit(System.monotonic_time, :native, :millisecond)
    elapsed = trunc(end_ms - start_ms)
    pause = max(0, state[:slice] - elapsed)

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
  ##
  ##

  def draw_cursor(dc, cursor, polygons) do
    light_gray = {211, 211, 211}
    bright_green = {0, 255, 0}

    # TODO: this is done a lot, commoditise?
    {mains, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)

    if Geo.is_inside?(mains[:main], cursor) do
      # TODO: use Enum.any??
      is_in_hole = Enum.reduce_while(holes, false, fn {_name, points}, _acc ->
        if Geo.is_inside?(points, cursor) do
          {:halt, true}
        else
          {:cont, false}
        end
      end)
      if is_in_hole do
        WxUtils.wx_crosshair(dc, cursor, light_gray, size: 6)
      else
        WxUtils.wx_crosshair(dc, cursor, bright_green, size: 6)
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
    concave_brush = :wxBrush.new(opaque_blue, [{:style, Wx.wxSOLID}])
    opaque_blue_brush = :wxBrush.new(opaque_blue, [{:style, Wx.wxSOLID}])

    {main, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)

    :wxDC.setBrush(dc, opaque_blue_brush)
    :wxDC.setPen(dc, blue_pen)
    for {_name, points} <- main do
      :ok = :wxDC.drawPolygon(dc, points)
      for point <- points do
        WxUtils.wx_crosshair(dc, point, blue)
      end
    end

    :wxDC.setBrush(dc, brush)
    :wxDC.setPen(dc, blue_pen)
    for {_name, points} <- holes do
      :ok = :wxDC.drawPolygon(dc, points)
    end

    for {_name, points} <- polygons do
      for point <- points do
        WxUtils.wx_crosshair(dc, point, blue)
      end
    end

    for {_name, points} <- main do
      {concave, _} = Geo.classify_vertices(points)
      for point <- concave do
        :wxDC.setPen(dc, blue_pen)
        :wxDC.setBrush(dc, concave_brush)
        :wxDC.drawCircle(dc, point, 5)
      end
    end

    for {_name, points} <- holes do
      {_, convex} = Geo.classify_vertices(points)
      for point <- convex do
        :wxDC.setPen(dc, blue_pen)
        :wxDC.setBrush(dc, concave_brush)
        :wxDC.drawCircle(dc, point, 5)
      end
    end

    :wxPen.destroy(blue_pen)
    :wxBrush.destroy(brush)
    :wxBrush.destroy(concave_brush)
    :wxBrush.destroy(opaque_blue_brush)
  end

  def draw_a_b_line(dc, {a, b}=line, polygons) do
    brush = :wxBrush.new({0, 0, 0}, [{:style, Wx.wxTRANSPARENT}])
    :wxDC.setBrush(dc, brush)

    light_gray = {211, 211, 211, 128}
    light_gray_pen = :wxPen.new(light_gray, [{:width,  1}, {:style, Wx.wxSOLID}])

    bright_green = {0, 255, 0}
    bright_green_pen = :wxPen.new(bright_green, [{:width,  1}, {:style, Wx.wxSOLID}])

    {main, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)
    if Geo.is_line_of_sight?(main[:main], holes, line) do
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
    |> Enum.map(&(Vector.truncate(&1)))

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

  def get_walk_vertices(polygons) do
    # TODO: this is done a lot, commoditise? Or ditch the "named" polygon concept.
    {mains, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)

    {concave, _} = Enum.reduce(mains, {[], []}, fn {_name, points}, {acc_concave, acc_convex} ->
      {concave, convex} = Geo.classify_vertices(points)
      # Logger.info("polygon #{name} has concave #{inspect concave}")
      {acc_concave ++ concave, acc_convex ++ convex}
    end)

    {_, convex} = Enum.reduce(holes, {[], []}, fn {_name, points}, {acc_concave, acc_convex} ->
      {concave, convex} = Geo.classify_vertices(points)
      # Logger.info("polygon #{name} has convex #{inspect convex}")
      {acc_concave ++ concave, acc_convex ++ convex}
    end)
    # Logger.info("walk vertices = #{inspect concave++convex}")
    concave ++ convex
  end

  def create_walk_graph(polygons, vertices) do
    # TODO: this is done a lot, commoditise?
    {mains, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)

    {_, all_edges} =
      Enum.reduce(vertices, {0, []}, fn a, {a_idx, edges} ->
        {_, inner_edges} =
          Enum.reduce(vertices, {0, []}, fn b, {b_idx, edges} ->
            if a_idx != b_idx and Geo.is_line_of_sight?(mains[:main], holes, {a, b}) do
              # TODO: use idx or actual points?
              {b_idx + 1, edges ++ [{{a, b}, Vector.distance(a, b)}]}
            else
              {b_idx + 1, edges}
            end
          end)
        {a_idx + 1, edges ++ inner_edges}
      end)

    Map.new(all_edges )
  end

  def reduce_walk_graph(graph) do
    graph
    |> Enum.map(fn {{{ax, _ay}=a, {bx, _by}=b}, dist} ->
      if ax < bx do
        {{a, b}, dist}
      else
        {{b, a}, dist}
      end
    end)
    |> Map.new
  end

  def find_nearest_point([], {_start, stop}=_line) do
    stop
  end

  def find_nearest_point(polygons, line) do
    {main, holes} = Enum.split_with(polygons, fn {name, _} -> name == :main end)
    [{_name, points}] = main
    {_start, stop} = line
    find_nearest_point_helper(points, holes, line, Geo.is_inside?(points, stop))
  end

  def find_nearest_point_helper(_, holes, line, true) do
    find_nearest_point_in_holes(holes, line)
  end

  def find_nearest_point_helper(points, _holes, line, false) do
    find_nearest_stop_point(points, line)
  end

  def find_nearest_point_in_holes([], {_start, stop}=_line) do
    stop
  end

  def find_nearest_point_in_holes([hole|holes], line) do
    {_name, points} = hole
    {_start, stop} = line
    find_nearest_point_in_holes_helper([hole|holes], line, Geo.is_inside?(points, stop, allow_border: false))
  end

  def find_nearest_point_in_holes_helper([_hole|holes], line, false) do
    find_nearest_point_in_holes(holes, line)
  end

  def find_nearest_point_in_holes_helper([hole|_holes], line, true) do
    {_name, points} = hole
    find_nearest_stop_point(points, line)
  end

  def find_nearest_stop_point(points, line) do
    {_start, stop} = line
    {x, y} = Geo.closest_point_on_edge(points, stop)
    {trunc(x), trunc(y)}
  end

  def transform_point([x, y]) do
    {trunc(x), trunc(y)}
  end

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

  def load_scene() do
    path = Application.app_dir(:astarwx)
    filename = "#{path}/priv/scene21.json"
    # filename = "#{path}/priv/complex.json"
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
