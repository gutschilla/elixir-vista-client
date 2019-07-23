defmodule VistaClient.Transformations do

  alias VistaClient.Transformations.Filters.Sessions, as: SessionFilter
  alias VistaClient.Transformations.Filters.Films,    as: FilmFilter

  defp of_day_and_film(sessions, day, film) do
    sessions
    |> SessionFilter.of_day(day)
    |> SessionFilter.of_film(film)
    |> SessionFilter.sort
  end

  defp film_day_map(film, week, sessions) do
    Enum.map(week, fn day ->
      sessions = sessions |> of_day_and_film(day, film)
      {day, sessions}
    end)
  end

  @type sessions  :: [%VistaClient.Session{}]
  @type film      :: %VistaClient.Film{}
  @type films     :: [film]
  @type cinema_id :: integer()
  @type filter    :: :day | :week
  @type day       :: %Date{}

  @type day_result :: [{film, sessions}]

  @spec get_films_sessions_for_week({sessions, films}, cinema_id(), day) :: day_result
  def get_films_sessions_for_day({sessions, films}, cinema_id, day) do
    s = _sessions_for_cinema_on_day =
      sessions
      |> SessionFilter.of_cinema(cinema_id)
      |> SessionFilter.of_day(day)
    films
    |> FilmFilter.of_day(s, day)
    |> Enum.map(fn film -> {film, of_day_and_film(s, day, film)} end)
  end

  @type week_result :: [{film, [{day, sessions}]}]

  @spec get_films_sessions_for_week({sessions, films}, cinema_id(), day) :: week_result
  def get_films_sessions_for_week({sessions, films}, cinema_id, first_day) do
    week = Enum.map(0..6, fn x -> Date.add(first_day, x) end)
    s = _sessions_for_cinema_in_week =
      sessions
      |> SessionFilter.of_cinema(cinema_id)
      |> SessionFilter.of_days(week)
    films
    |> FilmFilter.of_day(s, week)
    |> Enum.map(fn film -> {film, film_day_map(film, week, s)} end)
  end

  def to_serializable(:week_result, films) do
    Enum.map(
      films,
      fn {film, dst = _day_session_tuples} ->
        %{"film" => film, "days" => to_serializable(:day_session_tuples, dst)}
      end
    )
  end

  def to_serializable(:day_session_tuples, day_session_tuples) do
    Enum.reduce(
      day_session_tuples,
      %{},
      fn {day, sessions}, map ->
        iso = Date.to_iso8601(day)
        Map.put(map, iso, sessions)
      end
    )
  end

  def to_serializable(:film_session_tuples, film_session_tuples) do
    Enum.reduce(
      film_session_tuples,
      [],
      fn {film, sessions}, list ->
        list ++ [%{film: film, sessions: sessions}]
      end
    )
  end

end
