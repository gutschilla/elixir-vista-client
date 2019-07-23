defmodule VistaClient.Transformations.Filters.Sessions do

  alias VistaClient.{Film, Cinema, Session}

  def of_cinema(sessions, %Cinema{id: id}) do
    of_cinema(sessions, id)
  end

  def of_cinema(sessions, id) when is_integer(id) do
    sessions
    |> Enum.filter(fn %Session{cinema_id: ^id} -> true; _ -> false end)
  end

  def of_day(sessions, day) do
    sessions
    |> Enum.filter(fn %Session{date: ^day} -> true; _ -> false end)
  end

  def of_days(sessions, days) do
    sessions
    |> Enum.filter(fn %Session{date: day} -> day in days end)
  end

  def of_film(sessions, film_id) when is_binary(film_id) do
    sessions
    |> Enum.filter(fn %Session{film_id_string: ^film_id} -> true; _ -> false end)
  end

  def of_film(sessions, %Film{id: id}) do
    of_film(sessions, id)
  end

  def sort(sessions) do
    # not using DateTime.compare()
    sessions
    |> Enum.sort_by(fn %Session{showtime: dt} ->
      dt
      |> DateTime.from_naive("Etc/UTC")
      |> elem(1) # FIXME: this can fail as it assumes {:ok, Datetime}
      |> DateTime.to_unix
    end
    )
  end
end
