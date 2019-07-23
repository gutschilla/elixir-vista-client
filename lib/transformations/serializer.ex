defmodule VistaClient.Transformations.Serializer do

  @moduledoc ~S"""
  Convert VistaClient's tuple-based internal data structures of

  - "films in a cinema on a day with their sessions" and
  - "films in a cinema in a week with their sessions by day"

  into Jason-digestible maps.

  ## Examples

        iex> alias VistaClient.{Film,Session,Transformations}
        iex> day_result = [{film, [session]}] = [{%Film{}, [%Session{}]}]
        iex> Transformations.Serializer.from_day_result(day_result)
        [
          %{
            "film" => %VistaClient.Film{id: nil, name: nil, rating: nil},
            "sessions" => [
              %VistaClient.Session{
                attributes: nil, cinema: nil, cinema_id: nil, date: nil, film: nil, film_id_string: nil, id_string: nil, showtime: nil, version: nil
              }
            ]
          }
        ]
        iex> day = ~D[2019-01-01]
        iex> week_result = [{film, [{day, [session]}]}]
        iex> Transformations.Serializer.from_week_result(week_result)
        [
          %{
            "days" => %{
              "2019-01-01" => [
                %VistaClient.Session{attributes: nil, cinema: nil, cinema_id: nil, date: nil, film: nil, film_id_string: nil, id_string: nil, showtime: nil, version: nil}
              ]
            },
            "film" => %VistaClient.Film{id: nil, name: nil, rating: nil}
          }
        ]
  """

  def from_week_result(films), do: film_screening_tuples(films)
  def from_day_result(films), do: film_sessions_tuples(films)

  defp film_screening_tuples(films) do
    Enum.map(
      films,
      fn {film, dst = _day_session_tuples} ->
        %{"film" => film, "days" => day_session_tuples(dst)}
      end
    )
  end

  defp day_session_tuples(day_session_tuples) do
    Enum.reduce(
      day_session_tuples,
      %{},
      fn {day, sessions}, map ->
        iso = Date.to_iso8601(day)
        Map.put(map, iso, sessions)
      end
    )
  end


  defp film_sessions_tuples(film_tuples) do
    Enum.map(
      film_tuples,
      fn {film, sessions} -> %{"film" => film, "sessions" => sessions}  end
    )
  end

end
