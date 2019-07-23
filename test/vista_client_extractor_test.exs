defmodule VistaClientExtractorTest do
  use ExUnit.Case, async: true
  doctest VistaClient.Extractors
  doctest VistaClient.Film

  import VistaClient.Extractors, only: [
    {:extract_attributes, 1},
  ]

  test "attributes to version mapping" do

    attributes_1 = %{"SessionAttributesNames" => ["OV", "OmU" ]}
    attributes_2 = %{"SessionAttributesNames" => ["OmU", "OmUeng"]}
    attributes_3 = %{"SessionAttributesNames" => ["something_else", "OV"]}
    attributes_4 = %{"SessionAttributesNames" => []}

    assert {:ok, {"OmU", ["OV", "OmU"]}}           == extract_attributes(attributes_1)
    assert {:ok, {"OmU", ["OmU", "OmUeng"]}}       == extract_attributes(attributes_2)
    assert {:ok, {"OV", ["something_else", "OV"]}} == extract_attributes(attributes_3)
    assert {:ok, {"", []}}                         == extract_attributes(attributes_4)
  end

  test "make session struct from json" do
    json =
    """
    {
      "ID": "1001-14164",
      "CinemaId": "1001",
      "ScheduledFilmId": "HO00000720",
      "SessionId": "14164",
      "AreaCategoryCodes": [],
      "Showtime": "2019-02-26T20:00:00",
      "IsAllocatedSeating": false,
      "AllowChildAdmits": true,
      "SeatsAvailable": 66,
      "AllowComplimentaryTickets": true,
      "EventId": "",
      "PriceGroupCode": "0033",
      "ScreenName": "Kino 2",
      "ScreenNameAlt": "433402",
      "ScreenNumber": 2,
      "CinemaOperatorCode": "1001",
      "FormatCode": "0000000001",
      "FormatHOPK": "0000000001",
      "SalesChannels": ";CALL;RSP;GSALE;CELL;KIOSK;PDA;WWW;POSBK;POS;IVR;",
      "SessionAttributesNames": [
        "OV"
      ],
      "ConceptAttributesNames": [],
      "AllowTicketSales": true,
      "HasDynamicallyPricedTicketsAvailable": false,
      "PlayThroughId": null,
      "SessionBusinessDate": "2019-02-26T00:00:00",
      "SessionDisplayPriority": 0,
      "GroupSessionsByAttribute": false,
      "SoldoutStatus": 0,
      "TypeCode": "N"
    }
    """
    {:ok, session_map} = Jason.decode(json)
    assert(
      VistaClient.Session.from_map_list([session_map])
      ==
      {
        :ok,
       [
         %VistaClient.Session{
           id_string:      "1001-14164",
           cinema_id:      1001,
           film_id_string: "HO00000720",
           attributes:     ["OV"],
           version:        "OV",
           showtime: ~N[2019-02-26 20:00:00],
           date: ~D[2019-02-26],
           screen_name: "Kino 2",
           seats_available: 66,
         }
       ]
      }
    )
    assert(
      VistaClient.Session.from_map_list([session_map, %{something: :invalid}])
      ==
      {:error, :contains_unparsable_session}
    )
  end

  test "make film struct from json" do
    json = ~s"""
      {
        "ID": "1001-HO00000720",
        "ScheduledFilmId": "HO00000720",
        "CinemaId": "1001",
        "HasFutureSessions": false,
        "Title": "Schule auf dem Zauberberg, Die",
        "TitleAlt": "",
        "Distributor": "farbfilm Verleih GmbH",
        "Rating": "FSK unbek.",
        "RatingAlt": null,
        "RatingDescription": "",
        "RatingDescriptionAlt": null,
        "Synopsis": "Sie sind die zukünftige Elite: Die Sprösslinge der reichsten Familien der Welt – aufgewachsen im Überfluss und sicher eingebettet in ein Leben voller Geld, Genuss und Luxus. Was den jungen Heranwachsenden jedoch fehlt: der eigene Erfolg. Durch den Besuch des exklusivsten Internats der Welt – der Schule auf dem Zauberberg – soll sich das ändern. Hier sollen sie zu globalen Führungskräften ausgebildet werden. Absoluter Leistungsdruck inklusive.Unter den Töchtern von Milliardären und Söhnen von Oligarchen befindet sich auch Berk. Berk ist Einzelkind und Einzelgänger, der insgeheim nach seinen Freunden und einem beschaulichen Leben in seiner Heimat Istanbul sehnt. Doch er hat die Rechnung ohne seinen Vater gemacht, der sein Leben schon jetzt en détail durchgeplant hat. Als es um Berks Noten jedoch schlecht steht, streicht ihm sein Vater das Geld. Der Druck wächst. Reicht die Zeit aus, um das Ruder noch herumzureißen und den Schulabschluss zu schaffen? Und wie findet man eigentlich heraus, was einen glücklich macht? Geld ist dafür kein Garant.",
        "SynopsisAlt": "",
        "OpeningDate": "2019-02-28T00:00:00",
        "FilmHOPK": "HO00000720",
        "FilmHOCode": "0001593",
        "ShortCode": "",
        "RunTime": "87",
        "TrailerUrl": "",
        "DisplaySequence": 50,
        "TwitterTag": "Schule auf dem Zauberberg, Die",
        "HasSessionsAvailable": true,
        "GraphicUrl": "",
        "CinemaName": null,
        "CinemaNameAlt": null,
        "AllowTicketSales": true,
        "AdvertiseAdvanceBookingDate": false,
        "AdvanceBookingDate": null,
        "LoyaltyAdvanceBookingDate": null,
        "HasDynamicallyPricedTicketsAvailable": false,
        "IsPlayThroughMarketingFilm": false,
        "CustomerRatingStatistics": {
          "RatingCount": 0,
          "AverageScore": null
        },
        "CustomerRatingTrailerStatistics": {
          "RatingCount": 0,
          "RatingCountLiked": 0
        },
        "NationalOpeningDate": "2019-02-28T00:00:00",
        "CorporateFilmId": "",
        "EDICode": "3025506"
      }
    """
    {:ok, film_map} = Jason.decode(json)
    assert VistaClient.Film.from_map(film_map) == %VistaClient.Film{
      id:     "HO00000720",
      rating: :unknown,
      name:  "Die Schule auf dem Zauberberg"
    }
  end

  test "transform film names" do
    assert VistaClient.Film.transform_name("Foo,     The") == "The Foo"
    assert VistaClient.Film.transform_name("We love you") == "We love you"
    assert VistaClient.Film.transform_name("A, Whole, lotta, commas") == "A, Whole, lotta, commas"
  end

  test "transform ratings" do
    assert VistaClient.Film.transform_rating("FSK unbek.") == :unknown
    assert VistaClient.Film.transform_rating("Whatnot") == {:rating, "Whatnot"}
  end

  test "Film extractor" do
    json = """
    [
      {"Name": "Blauer Stern", "ID": "1011"},
      {"Name": "Cinema Paris", "ID": "1012"},
      {"Name": "City Kinos",   "ID": "1014"}
    ]
    """
    {:ok, cinema_list} = Jason.decode(json)
    assert VistaClient.Cinema.from_map_list(cinema_list) == {:ok, [
      %VistaClient.Cinema{id: 1011, name: "Blauer Stern"},
      %VistaClient.Cinema{id: 1012, name: "Cinema Paris"},
      %VistaClient.Cinema{id: 1014, name: "City Kinos"},
    ]}
  end


end
