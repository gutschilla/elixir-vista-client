defmodule VistaClient.Transformations.Filters.Films do
  alias VistaClient.Transformations.Filters.Sessions, as: SessionFilter
  alias VistaClient.Film

  require Logger

  # yields map: { "film_id" => %Film{…} or "film_id" => nil}
  defp film_ids_of(sessions) do
    Enum.reduce(
      sessions,
      %{},
      fn session, map ->
        map |> Map.put(session.film_id_string, session.film)
      end
    )
  end

  @doc """
  Looks a film up by its id. This can be nil in case the film isn't found. This
  can happen when a film has been removed from the list of scheduled films but
  and this list was relaoded, but ther are (old) sessions are still referencing
  this film.
  """
  @spec get_by_id([%Film{}], binary()) :: %Film{} | nil
  def get_by_id(films, id) do
    films
    |> Enum.find(fn %Film{id: ^id} -> true; _ -> false end)
    |> case do
         f = %Film{} -> f
         nil         -> Logger.warn("Unable to find referenced film id: #{id}"); nil # will cause this film to be removed
       end
  end

  # depending on day_or_days argument being a list of days or just a day
  # choose the better function to grep
  defp session_filter_of_day(sessions, days) when is_list(days) do
    SessionFilter.of_days(sessions, days)
  end
  # of_day/2 is faster than of_days/2 since the former can pattern-match on the date
  defp session_filter_of_day(sessions, day = %Date{}) do
    SessionFilter.of_day(sessions, day)
  end

  def of_day(films, sessions, day_or_days) do
    sessions
    |> session_filter_of_day(day_or_days)
    |> film_ids_of()
    |> Enum.map(fn {_id, film = %Film{}} -> film; {id, nil} -> films |> get_by_id(id) end)
    |> Enum.filter(fn %Film{} -> true; _ -> false end) # remove deleted films, see case clause in get_by_id/2
    |> Enum.sort_by(fn %Film{name: name} -> name end)
  end
end
