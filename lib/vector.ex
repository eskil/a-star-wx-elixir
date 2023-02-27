defmodule Vector do
  def len({x, y}) do
    :math.sqrt(x * x + y * y)
  end

  def add({ax, ay}, {bx, by}) do
    {ax + bx, ay + by}
  end

  def sub({ax, ay}, {bx, by}) do
    {ax - bx, ay - by}
  end

  def distance({_ax, _ay}=a, {_bx, _by}=b) do
    len(sub(b, a))
  end

  def normalise({x, y}=v) do
    l = len(v)
    {x / l, y / l}
  end

  def dot({ax, ay}, {bx, by}) do
    ax * bx + ay * by
  end

  def cross({ax, ay}, {bx, by}) do
    ax * by - ay * bx
  end

  def shorten({x, y}=v, sz) do
    s = 1 - sz/len(v)
    {x * s, y * s}
  end

  def mag({x, y}) do
    :math.sqrt(:math.pow(x, 2) + :math.pow(y, 2))
  end

  def angle({0.0, y}) when y < 0 do
    - :math.pi / 2
  end

  def angle({0.0, _y}) do
    :math.pi / 2
  end

  def angle({0, y}) when y < 0 do
    - :math.pi / 2
  end

  def angle({0, _y}) do
    :math.pi / 2
  end

  def angle({x, y}) do
    :math.atan(-y / -x)
  end

  @doc"""
  Calls trunc on x & y to make the vector work with wx.
  """
  def truncate({x, y}) do
    {trunc(x), trunc(y)}
  end

  @doc """
  This is a graph oriented degree, ie. left is 0, up is 90 etc.

  ## Examples
      iex> alias Vector, as: Vector
      Vector
      iex> Vector.degrees_a({1, 1)}
      45.0
      iex> Vector.degrees_a({0, 1)}
      90.0
      iex> Vector.degrees_a({1, 0)}
      -0.0
      iex> Vector.degrees_a({-1, 1)}
      135.0
      iex> Vector.degrees_a({-1, 0)}
      180.0
      iex> Vector.degrees_a({-1, -1)}
      225.0
      iex> Vector.degrees_a({0, -1)}
      270.0
      iex> Vector.degrees_a({1, -1)}
      315.0
  """
  def degrees_a({x, y}=v) do
    a = angle(v) * (180 / :math.pi)
    a = if x < 0 do
      180 + a
    else
      if y < 0 do
        360 + a
      else
        a
      end
    end
    a
  end

  @doc """
  This is a screen oriented degree. Degrees are in North=up (0) South=down (180) degrees.
  Vectors are in x,y screen coordinate, so 1,1 = 135D down to right

  ## Examples
      iex> Vector.degrees({0, -1)}
      0
      iex> Vector.degrees({1, -1)}
      45
      iex> Vector.degrees({1, 0)}
      90
      iex> Vector.degrees({1, 1)}
      135
      iex> Vector.degrees({0, 1)}
      180
      iex> Vector.degrees({-1, 1)}
      225
      iex> Vector.degrees({-1, 0)}
      270
      iex> Vector.degrees({-1, -1)}
      315
  """
  def degrees({x, y}=v) do
    # z is our "north" and it's pointing "right" to rotate.
    z = {0, -1}
    d = dot(v, z)
    cos_a = d / (mag(v) * mag(y))
    d = :math.acos(cos_a) * (180 / :math.pi)
    if x < 0 do
      360 - d
    else
      d
    end
    |> trunc
  end
end
