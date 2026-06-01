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

type alias Submission =
    { id : Int
    , person : String
    , text : String
    , createdAt : String
    }

type alias Model =
    { apiUrl : String
    , inputText : String
    , status : String
    , person : Maybe Person
    , submissions : List Submission
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
      , submissions = []
      , submittedToday = False
      }
    , fetchSubmissions flags.apiUrl
    )



type Msg
    = UpdateText String
    | SelectPerson Person
    | Submit
    | SubmitResult (Result Http.Error String)
    | FetchSubmissions
    | GotSubmissions (Result Http.Error (List Submission))


port savePerson : String -> Cmd msg


submissionDecoder : Decode.Decoder Submission
submissionDecoder =
    Decode.map4 Submission
        (Decode.field "id" Decode.int)
        (Decode.field "person" Decode.string)
        (Decode.field "text" Decode.string)
        (Decode.field "created_at" Decode.string)

fetchSubmissions : String -> Cmd Msg
fetchSubmissions url =
    Http.get
        { url = url ++ "/submissions"
        , expect =
            Http.expectJson GotSubmissions
                (Decode.list submissionDecoder)
        }

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectPerson person ->
            let 
                personString =
                    case person of
                        Mary ->
                            "Mary"
                        
                        Connor ->
                            "Connor"
            in
            ( { model | person = Just person }
            , savePerson personString
            )

        UpdateText txt ->
            ( { model | inputText = txt }, Cmd.none )

        Submit ->
            case model.person of
                Nothing ->
                    ( model, Cmd.none )
                
                Just person ->
                    ( { model | status = "Sending..." }
                    , sendPost model.apiUrl person model.inputText
                    )

        SubmitResult result ->
            case result of
                Ok response ->
                    ( { model
                        | submittedToday = True
                        , inputText = ""
                        , status = response
                      }
                    , fetchSubmissions model.apiUrl
                    )

                Err err ->
                    ( { model | status = "Error: " ++ httpErrorToString err }
                    , Cmd.none
                    )
        FetchSubmissions ->
            ( model, fetchSubmissions model.apiUrl )
        
        GotSubmissions result -> 
            case result of
                Ok subs ->
                    ( { model | submissions = subs }, Cmd.none )
                
                Err err ->
                    ( { model | status = httpErrorToString err }, Cmd.none )


sendPost : String -> Person -> String -> Cmd Msg
sendPost url person payload =
    let
        personString =
            case person of
                Mary ->
                    "Mary"

                Connor ->
                    "Connor"
        body = 
            Encode.object
                [ ( "person", Encode.string personString )
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


viewSubmission : Submission -> Html Msg
viewSubmission sub =
    div []
        [ p [] [ text (sub.person ++ ": " ++ sub.text) ]
        , p [] [ text sub.createdAt ]
        ]

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
                                "type your message here")
                        , value model.inputText
                        , onInput UpdateText
                        ]
                        []
                    , button [ disabled model.submittedToday ] [ text "Submit" ]
                    ]
                , p [] [ text model.status ]

                , div []
                    (List.map viewSubmission model.submissions)
                ]


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = always Sub.none
        , view = view
        }