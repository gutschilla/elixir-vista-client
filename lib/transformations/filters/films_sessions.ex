defmodule VistaClient.Transformations.Filters.FilmsSessions do

  alias VistaClient.{Session}

  def filter_started_30mins(film_sessions) do
    cutoff_datetime = now_after_30mins()
    filter_started(film_sessions, cutoff_datetime)
  end

  defp now_after_30mins() do
    DateTime.utc_now |> DateTime.add(30*60, :second)
  end

  @doc """
  Takes a list of film_sessions and returns same list with all sessions that
  have started already (specified as cutoff_date_time) filtered out.

  """
  def filter_started(film_sessions, cutoff_datetime) do
    film_sessions
    |> Enum.map(fn fs -> filter_films_sessions(fs, cutoff_datetime) end)
  end

  def filter_films_sessions({film, sessions}, cutoff_datetime) do
    filtered_sessions =
      sessions
      |> Enum.filter(fn s -> session_valid?(s, cutoff_datetime) end)
    {film, filtered_sessions}
  end

  @doc """
  Compares session's showtime with cutoff_datetime. Returns true if showtime is
  after cutoff_datetime.

  # Examples

  iex> session = %Session{showtime: "2019-03-21 12:20:00.00000Z" |> NaiveDateTime.from_iso8601}
  iex> cutoff_datetime =            "2019-03-21 12:20:00.00000Z" |> DateTime.from_iso8601() |> elem(1)
  iex> __MODULE__.session_expired?(session, cutoff_datetime)
  false

  iex> session = %Session{showtime: "2019-03-21 12:20:00.00000Z" |> NaiveDateTime.from_iso8601}
  iex> cutoff_datetime =            "2019-03-21 12:10:00.00000Z" |> DateTime.from_iso8601() |> elem(1)
  iex> __MODULE__.session_expired?(session, cutoff_datetime)
  false
  """
  def session_expired?(%Session{showtime: showtime = %NaiveDateTime{}}, cutoff_datetime = %DateTime{}) do
    showtime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.compare(cutoff_datetime)
    |> Kernel.==(:lt)
  end

  def session_valid?(session, cutoff_datetime) do
    not session_expired?(session, cutoff_datetime)
  end
end
