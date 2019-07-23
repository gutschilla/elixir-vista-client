defmodule VistaClientTransformationsTest do
  use ExUnit.Case, async: true
  doctest VistaClient.Transformations
  doctest VistaClient.Transformations.Serializer

  alias VistaClient.{Transformations, Film, Session, Cinema}
  alias VistaClient.Transformations.Filters.Sessions, as: SessionFilter
  alias VistaClient.Transformations.Filters.Films,    as: FilmFilter
  alias VistaClient.Transformations.Serializer

  @cinemas [
    %Cinema{id: 1001, name: "Delphi Lux"},
    %Cinema{id: 1002, name: "Babylon"},
    %Cinema{id: 1003, name: "Rollberg"},
    %Cinema{id: 1004, name: "Yorck"},
    %Cinema{id: 1005, name: "Capitol Dahlem"},
    %Cinema{id: 1006, name: "Neues Off"},
    %Cinema{id: 1007, name: "Passage"},
    %Cinema{id: 1008, name: "Odeon"},
    %Cinema{id: 1009, name: "Kino International"},
    %Cinema{id: 1010, name: "Filmtheater am Friedrichshain"},
    %Cinema{id: 1011, name: "Blauer Stern"},
    %Cinema{id: 1012, name: "Cinema Paris"},
    %Cinema{id: 1014, name: "City Kinos"}
  ]

  @films [
    %Film{id: "HO00000676", name: "ROH 2019: La Forza Del Destino (Die Macht des Schi", rating: {:rating, "FSK 6"}},
    %Film{id: "HO00000701", name: "Beale Street",                                       rating: :unknown},
    %Film{id: "HO00000720", name: "Die Schule auf dem Zauberberg",                      rating: :unknown},
    %Film{id: "HO00000712", name: "Der Verlorene Sohn",                                 rating: {:rating, "FSK 12"}},
    %Film{id: "HO00000714", name: "Waltz with Bashir",                                  rating: {:rating, "FSK 12"}},
    %Film{id: "HO00000646", name: "Capernaum - Stadt der Hoffnung",                     rating: {:rating, "FSK 12"}},
  ]

  @sessions [
    %Session{attributes: ["OmU"], cinema_id: 1001, film_id_string: "HO00000714", id_string: "1001-13809", showtime: ~N[2019-02-20 22:00:00], date: ~D[2019-02-20], seats_available:  0, screen_name: "Kino A", version: "OmU"},
    %Session{attributes: ["OV"],  cinema_id: 1001, film_id_string: "HO00000720", id_string: "1001-14164", showtime: ~N[2019-02-20 21:00:00], date: ~D[2019-02-20], seats_available: 20, screen_name: "Kino B", version: "OV"},
    %Session{attributes: ["OV"],  cinema_id: 1001, film_id_string: "HO00000720", id_string: "1001-14167", showtime: ~N[2019-02-21 21:00:00], date: ~D[2019-02-21], seats_available: 30, screen_name: "Kino C", version: "OV"},
    %Session{attributes: ["OV"],  cinema_id: 1001, film_id_string: "HO00000720", id_string: "1001-14168", showtime: ~N[2019-02-20 19:00:00], date: ~D[2019-02-20], seats_available: 40, screen_name: "Kino D", version: "OV"},
    %Session{attributes: [],      cinema_id: 1011, film_id_string: "HO00000646", id_string: "1001-14261", showtime: ~N[2019-02-20 20:00:00], date: ~D[2019-02-20], seats_available: 50, screen_name: "Kino E", version: ""},
    %Session{attributes: [],      cinema_id: 1011, film_id_string: "HO00000646", id_string: "1001-14262", showtime: ~N[2019-02-23 20:00:00], date: ~D[2019-02-23], seats_available: 60, screen_name: "Kino F", version: ""},
  ]

  defp films_at(positions) when is_list(positions) do
    positions |> Enum.map(fn pos -> Enum.at(@films, pos) end)
  end
  defp sessions_at(positions) when is_list(positions) do
    positions |> Enum.map(fn pos -> Enum.at(@sessions, pos) end)
  end

  defp zauberberg(), do: films_at([2]) |> hd()
  defp bashir(),     do: films_at([4]) |> hd()
  defp capernaum(),  do: films_at([5]) |> hd()

  test "sessions_with_cinemas" do
    mapped
    = @sessions
    |> Transformations.Setters.set_cinemas(@cinemas)
    # all films should be matched
    assert Enum.all?(mapped, fn %Session{cinema: %Cinema{}} -> true; _ -> false end)
  end

  test "sessions_with_films" do
    mapped
    = @sessions
    |> Transformations.Setters.set_films(@films)
    # all films should be matched
    assert Enum.all?(mapped, fn %Session{film: %Film{}} -> true; _ -> false end)
  end

  test "of_cinema" do
    mapped = SessionFilter.of_cinema(@sessions, 1001)
    assert length(mapped) == 4
  end

  test "of_day" do
    assert @sessions
    |> SessionFilter.of_day(~D[2019-02-20])
    |> length == 4
  end

  test "of_days" do
    assert @sessions
    |> SessionFilter.of_days([~D[2019-02-20], ~D[2019-02-21]])
    |> length == 5
  end

  test "sorting by showtime" do
    sorted
    =  SessionFilter.of_cinema(@sessions, 1001)
    |> SessionFilter.sort()

    # assert ascending order:
    {outcome, _} = Enum.reduce(
      sorted,
      {:lt, DateTime.from_naive!(~N[1970-01-01 00:00:00], "Etc/UTC")},
      fn %Session{showtime: showtime}, {compared, prev_showtime} when compared in [:lt, :eq] ->
        this_dt = DateTime.from_naive!(showtime,      "Etc/UTC")
        prev_dt = DateTime.from_naive!(prev_showtime, "Etc/UTC")
        outcome = Date.compare(prev_dt, this_dt)
        {outcome, prev_dt};
        _, {:gt, offender} -> {:gt, offender}
      end
    )
    assert outcome in [:lt, :eq]
  end

  test "of film filter" do
    film1_id = @films |> Enum.at(2) |> Map.get(:id)
    film2    = @films |> Enum.at(1)
    film3    = @films |> Enum.at(5)
    assert @sessions |> SessionFilter.of_film(film1_id) |> length == 3
    assert @sessions |> SessionFilter.of_film(film2   ) |> length == 0
    assert @sessions |> SessionFilter.of_film(film3   ) |> length == 2
  end

  describe "Filters.Films" do
    test "get_by_id" do
      film = @films |> Enum.at(5) # Capernaum
      assert @films |> FilmFilter.get_by_id(film.id) == film
    end

    test "of_day" do
      assert FilmFilter.of_day(@films, @sessions, ~D[2019-02-20]) == films_at([5,2,4])
      assert FilmFilter.of_day(@films, @sessions, ~D[2019-02-21]) == films_at([2])
    end
  end

  describe "main transformations" do
    test "get_films_sessions_for day lux" do
      cinema_id = 1001
      day       = ~D[2019-02-20]
      films = Transformations.get_films_sessions_for_day({@sessions, @films}, cinema_id, day)
      assert films == [
        {zauberberg(), sessions_at([3,1])},
        {bashir(),     sessions_at([0])},
      ]
    end
    test "get_films_sessions_for day blauer stern" do
      cinema_id = 1011
      day       = ~D[2019-02-20]
      films = Transformations.get_films_sessions_for_day({@sessions, @films}, cinema_id, day)
      assert films == [{capernaum(), sessions_at([4])}]
      films2 = Transformations.get_films_sessions_for_day({@sessions, @films}, cinema_id, day |> Date.add(1))
      assert films2 == []
      films3 = Transformations.get_films_sessions_for_day({@sessions, @films}, cinema_id, day |> Date.add(3))
      assert films3 == [{capernaum(), sessions_at([5])}]
    end

    test "get_films_sessions_for week" do
      cinema_id = 1001
      first_day = ~D[2019-02-20]
      films = Transformations.get_films_sessions_for_week(
        {@sessions, @films},
        cinema_id, first_day
      )

      assert films == [
        {
          zauberberg(),
          [
            {~D[2019-02-20], sessions_at([3,1])},
            {~D[2019-02-21], sessions_at([2])},
            {~D[2019-02-22], []}, {~D[2019-02-23], []}, {~D[2019-02-24], []}, {~D[2019-02-25], []}, {~D[2019-02-26], []}
          ]
        },
        {
          bashir(),
          [
            {~D[2019-02-20], sessions_at([0])},
            {~D[2019-02-21], []}, {~D[2019-02-22], []}, {~D[2019-02-23], []}, {~D[2019-02-24], []}, {~D[2019-02-25], []}, {~D[2019-02-26], []}
          ]
        }
      ]
    end

    test "serializable day_result" do
      films = Transformations.get_films_sessions_for_day({@sessions, @films}, 1001, ~D[2019-02-21])
      {:ok, json} = films |> Serializer.from_day_result |> Jason.encode()
      assert json == ~S'[{"film":{"id":"HO00000720","name":"Die Schule auf dem Zauberberg","rating":"unknown"},"sessions":[{"attributes":["OV"],"cinema":null,"cinema_id":1001,"date":"2019-02-21","film":null,"film_id_string":"HO00000720","id_string":"1001-14167","screen_name":"Kino C","seats_available":30,"showtime":"2019-02-21T21:00:00","version":"OV"}]}]'
    end

    test "serializable week_result" do
      films = Transformations.get_films_sessions_for_week({@sessions, @films}, 1001, ~D[2019-02-21])
      {:ok, json} = films |> Serializer.from_week_result |> Jason.encode()
      assert json == ~S'[{"days":{"2019-02-21":[{"attributes":["OV"],"cinema":null,"cinema_id":1001,"date":"2019-02-21","film":null,"film_id_string":"HO00000720","id_string":"1001-14167","screen_name":"Kino C","seats_available":30,"showtime":"2019-02-21T21:00:00","version":"OV"}],"2019-02-22":[],"2019-02-23":[],"2019-02-24":[],"2019-02-25":[],"2019-02-26":[],"2019-02-27":[]},"film":{"id":"HO00000720","name":"Die Schule auf dem Zauberberg","rating":"unknown"}}]'
    end
  end

end
