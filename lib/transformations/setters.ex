defmodule VistaClient.Transformations.Setters do

  alias VistaClient.{Film, Session, Cinema}

  @type film     :: %Film{}
  @type films    :: [film]
  @type session  :: %Session{}
  @type sessions :: [session]
  @type cinema   :: %Cinema{}
  @type cinemas  :: [cinema]

  # PRELOADERS

  @spec set_film(session, films) :: session
  def set_film(session = %Session{film_id_string: fid}, films) do
    film = films |> Enum.find(fn %Film{id: ^fid} -> true; _ -> false end)
    %Session{session | film: film}
  end

  @spec set_films(sessions, films) :: sessions
  def set_films(sessions, films) do
    sessions
    |> Enum.map(fn session -> set_film(session, films) end)
  end

  @spec set_cinema(session, cinemas) :: session
  def set_cinema(session = %Session{cinema_id: cid}, cinemas) do
    cinema = cinemas |> Enum.find(fn %Cinema{id: ^cid} -> true; _ -> false end)
    %Session{session | cinema: cinema}
  end

  @spec set_cinemas(sessions, cinemas) :: sessions
  def set_cinemas(sessions, cinemas) do
    sessions
    |> Enum.map(fn session -> set_cinema(session, cinemas) end)
  end
end
