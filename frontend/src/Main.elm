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

type alias TodayResponse =
    { submitted : Bool
    , text : String
    }


todayDecoder : Decode.Decoder TodayResponse
todayDecoder =
    Decode.map2 TodayResponse
        (Decode.field "submitted" Decode.bool)
        (Decode.field "text" Decode.string)


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        maybePerson =
            case flags.person of
                Just "Mary" ->
                    Just Mary

                Just "Connor" ->
                    Just Connor

                _ ->
                    Nothing

        cmd =
            case maybePerson of
                Just person ->
                    fetchToday flags.apiUrl person

                Nothing ->
                    Cmd.none
    in
    ( { apiUrl = flags.apiUrl
      , inputText = ""
      , status = ""
      , person = maybePerson
      , submittedToday = False
      }
    , cmd
    )


type Msg
    = UpdateText String
    | SelectPerson Person
    | Submit
    | SubmitResult (Result Http.Error String)
    | GotToday (Result Http.Error TodayResponse)


port savePerson : String -> Cmd msg


personToString : Person -> String
personToString person =
    case person of
        Mary ->
            "Mary"

        Connor ->
            "Connor"

fetchToday : String -> Person -> Cmd Msg
fetchToday url person =
    Http.get
        { url = url ++ "/today/" ++ (personToString person)
        , expect =
            Http.expectJson GotToday todayDecoder
        }

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectPerson person ->
            ( { model 
                | person = Just person 
                , submittedToday = False
                , inputText = ""
                , status = ""
              }
            , Cmd.batch 
                [ savePerson (personToString person)
                , fetchToday model.apiUrl person
                ]
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

        GotToday result ->
            case result of
                Ok today ->
                    ( { model
                        | submittedToday = today.submitted
                        , inputText = today.text
                        , status =
                            if today.submitted then
                                "your message for today has been sent <3"
                            else
                                ""
                      }
                    , Cmd.none
                    )
                
                Err err ->
                    ( { model
                        | status = "Failed to load today's message"
                      }
                    , Cmd.none
                    )
        
        SubmitResult result ->
            case result of
                Ok _ ->
                    case model.person of
                        Just person ->
                             ( { model
                                 | submittedToday = True
                                 , status = "sent"
                               }
                             , fetchToday model.apiUrl person
                             )
                        Nothing ->
                            ( model, Cmd.none )

                Err (Http.BadStatus 409) ->
                    ( { model
                        | submittedToday = True
                        , status = "your message for today has been sent <3"
                      }
                    , Cmd.none
                    )

                Err err ->
                    ( { model
                        | status = "Error: " ++ httpErrorToString err
                      }
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
                                ""
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