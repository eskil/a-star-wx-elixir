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
    }
    {frame, state}
  end

  ##
  ## Wx Async Events
  ##

  @impl true
  def handle_event({:wx, _, _, _, {:wxSize, :size, size, _}} = event, state) do
    Logger.info("received size event: #{inspect(event)}")
    :wxPanel.setSize(state.wx_panel, size)
    {:noreply, state}
  end

  @impl true
  def handle_event({:wx, _, _, _, {:wxClose, :close_window}} = event, state) do
    Logger.info("received close event: #{inspect(event)}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :enter_window,
                     x, y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = _event, state) do
    {:noreply, %{state | cursor: {x, y}}}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :leave_window,
                     _x, _y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = _event, state) do
    {:noreply, %{state | cursor: nil}}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :motion, x, y,
                     _left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = event, state) do
    Logger.debug("mouse event #{inspect event, pretty: true}")
    {:noreply, %{state | cursor: {x, y}}}
  end

  @impl true
  def handle_event({:wx, _id, _wx_ref, _something,
                    {:wxMouse, :left_up,
                     x, y,
                     left_down, _middle_down, _right_down,
                     _control_down, _shift_down, _alt_down, _meta_down,
                     _wheel_rotation, _wheel_delta, _lines_per_action}} = _event,
    state
  ) do
    Logger.info("click #{inspect {x, y}} #{left_down}")
    {:noreply, state}
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
  def handle_sync_event({:wx, _, _, _, {:wxPaint, :paint}} = event, _, state) do
    Logger.debug("paint event #{inspect event, pretty: true}")

    dc = state.wx_memory_dc
    # cls
    brush = :wxBrush.new({0, 0, 0}, [{:style, Wx.wxSOLID}])
    :ok = :wxDC.setBackground(dc, brush)
    :ok = :wxDC.clear(dc)
    :wxBrush.destroy(brush)

    red = {255, 0, 0}
    green = {0, 255, 0}
    blue = {0, 150, 255}

    red_pen = :wxPen.new(red, [{:width,  1}, {:style, Wx.wxSOLID}])
    green_pen = :wxPen.new(green, [{:width,  1}, {:style, Wx.wxSOLID}])
    blue_pen = :wxPen.new(blue, [{:width,  1}, {:style, Wx.wxSOLID}])
    fat_blue_pen = :wxPen.new(blue, [{:width,  1}, {:style, Wx.wxSOLID}])

    brush = :wxBrush.new({0, 0, 0}, [{:style, Wx.wxTRANSPARENT}])

    for {_name, points} <- state.polygons do
      :wxDC.setPen(dc, blue_pen)
      :wxDC.setBrush(dc, brush)
      :ok = :wxDC.drawPolygon(dc, points)
      for point <- points do
        WxUtils.wx_crosshair(dc, point, red)
      end
    end

    WxUtils.wx_crosshair(dc, state.start, green)
    if state.cursor do
      :wxDC.setPen(dc, blue_pen)
      :ok = :wxDC.drawLine(dc, state.start, state.cursor)
      WxUtils.wx_crosshair(dc, state.cursor, red)
    end

    # Draw
    paint_dc = :wxPaintDC.new(state.wx_panel)
    :wxDC.blit(paint_dc, {0, 0}, @size, dc, {0, 0})

    # Cleanup :-/
    :wxPaintDC.destroy(paint_dc)
    :wxPen.destroy(red_pen)
    :wxPen.destroy(blue_pen)
    :wxPen.destroy(fat_blue_pen)
    :wxPen.destroy(green_pen)
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
    Logger.debug("Tick at #{start_ms}ms #{inspect state, pretty: true}")

    new_state = update(state)
    render(new_state)

    end_ms = System.convert_time_unit(System.monotonic_time, :native, :millisecond)
    elapsed = trunc(end_ms - start_ms)
    pause = max(0, state[:slice] - elapsed)
    Logger.debug("Elapsed #{elapsed}ms, pausing #{pause}ms")

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
    Logger.debug("render")
    :wxPanel.refresh(state.wx_panel, eraseBackground: false)
  end

  def stop(_state) do
    Logger.info("stopping")
  end

  ##
  ##
  ##

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

  def close_walkbox({name, points}) do
    if Enum.at(points, 0) == Enum.at(points, -1) do
      {name, points}
    else
      {name, points ++ [Enum.at(points, 0)]}
    end
  end

  def close_walkboxes(polygons) do
    polygons
    |> Enum.map(&(close_walkbox(&1)))
  end

  def load_scene() do
    path = Application.app_dir(:astarwx)
    filename = "#{path}/priv/scene1.json"
    Logger.info("Processing #{filename}")
    {:ok, file} = File.read(filename)
    {:ok, json} = Poison.decode(file, keys: :atoms)
    Logger.info("#{inspect json, pretty: true}")
    polygons =
      json[:polygons]
      |> transform_walkboxes
      |> close_walkboxes
    Logger.info("#{inspect polygons, pretty: true}")
    {
      transform_point(json[:start]),
      polygons,
    }
  end
end
