port module Main exposing (main)

import Json.Encode as Encode
import Json.Decode as Decode
import Browser
import Html exposing (Html, button, div, form, input, p, text)
import Html.Attributes exposing (disabled, placeholder, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http


type alias Flags =
    { apiUrl : String
    , person : Maybe String
    }


type Person
    = Mary
    | Connor


type alias Model =
    { apiUrl : String
    , inputText : String
    , status : String
    , person : Maybe Person
    , submittedToday : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { apiUrl = flags.apiUrl
      , inputText = ""
      , status = ""
      , person =
            case flags.person of
                Just "Mary" ->
                    Just Mary

                Just "Connor" ->
                    Just Connor

                _ ->
                    Nothing
      , submittedToday = False
      }
    , Cmd.none
    )


type Msg
    = UpdateText String
    | SelectPerson Person
    | Submit
    | SubmitResult (Result Http.Error String)


port savePerson : String -> Cmd msg


personToString : Person -> String
personToString person =
    case person of
        Mary ->
            "Mary"

        Connor ->
            "Connor"


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectPerson person ->
            ( { model | person = Just person }
            , savePerson (personToString person)
            )

        UpdateText txt ->
            ( { model | inputText = txt }, Cmd.none )

        Submit ->
            case model.person of
                Nothing ->
                    ( { model | status = "Select a user first" }
                    , Cmd.none
                    )

                Just person ->
                    ( { model | status = "Sending..." }
                    , sendPost model.apiUrl person model.inputText
                    )

        SubmitResult result ->
            case result of
                Ok response ->
                    if response == "already_submitted" then
                        ( { model
                            | submittedToday = True
                            , status = "your message for today has been sent <3"
                          }
                        , Cmd.none
                        )

                    else
                        ( { model
                            | submittedToday = True
                            , inputText = ""
                            , status = "sent ✔"
                          }
                        , Cmd.none
                        )

                Err (Http.BadStatus 409) ->
                    ( { model
                        | submittedToday = True
                        , status = "your message for today has been sent <3"
                      }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | status = "Error: " ++ httpErrorToString err }
                    , Cmd.none
                    )


sendPost : String -> Person -> String -> Cmd Msg
sendPost url person payload =
    let
        body =
            Encode.object
                [ ( "person", Encode.string (personToString person) )
                , ( "text", Encode.string payload )
                ]
    in
    Http.post
        { url = url ++ "/submit"
        , body = Http.jsonBody body
        , expect = Http.expectString SubmitResult
        }


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl _ ->
            "Bad URL"

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus code ->
            "HTTP " ++ String.fromInt code

        Http.BadBody _ ->
            "Bad response body"


view : Model -> Html Msg
view model =
    case model.person of
        Nothing ->
            div []
                [ button [ onClick (SelectPerson Mary) ] [ text "Mary" ]
                , button [ onClick (SelectPerson Connor) ] [ text "Connor" ]
                ]

        Just _ ->
            div []
                [ form [ onSubmit Submit ]
                    [ input
                        [ disabled model.submittedToday
                        , placeholder
                            (if model.submittedToday then
                                "your message for today has been sent <3"

                             else
                                "type your message here"
                            )
                        , value model.inputText
                        , onInput UpdateText
                        ]
                        []
                    , button
                        [ disabled model.submittedToday ]
                        [ text "Submit" ]
                    ]
                , p [] [ text model.status ]
                ]


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = always Sub.none
        , view = view
        }