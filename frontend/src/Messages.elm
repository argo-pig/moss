module Messages exposing (main)

import Browser
import Html exposing (Html, div, p, text)
import Http
import Json.Decode as Decode


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
    , viewer : Maybe Person
    , submissions : List Submission
    }


type Msg
    = GotSubmissions (Result Http.Error (List Submission))


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        viewer =
            case flags.person of
                Just "Mary" ->
                    Just Mary

                Just "Connor" ->
                    Just Connor

                _ ->
                    Nothing
    in
    ( { apiUrl = flags.apiUrl
      , viewer = viewer
      , submissions = []
      }
    , fetch viewer flags.apiUrl
    )


fetch : Maybe Person -> String -> Cmd Msg
fetch viewer apiUrl =
    case viewer of
        Just person ->
            Http.get
                { url = apiUrl ++ "/submissions/" ++ otherPerson person
                , expect = Http.expectJson GotSubmissions submissionsDecoder
                }

        Nothing ->
            Cmd.none


otherPerson : Person -> String
otherPerson person =
    case person of
        Mary ->
            "Connor"

        Connor ->
            "Mary"


submissionDecoder : Decode.Decoder Submission
submissionDecoder =
    Decode.map4 Submission
        (Decode.field "id" Decode.int)
        (Decode.field "person" Decode.string)
        (Decode.field "text" Decode.string)
        (Decode.field "created_at" Decode.string)


submissionsDecoder : Decode.Decoder (List Submission)
submissionsDecoder =
    Decode.list submissionDecoder


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSubmissions result ->
            case result of
                Ok subs ->
                    ( { model | submissions = subs }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div []
        (List.map viewSubmission model.submissions)


viewSubmission : Submission -> Html Msg
viewSubmission sub =
    div []
        [ p [] [ text (sub.person ++ ": " ++ sub.text) ]
        , p [] [ text sub.createdAt ]
        ]


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = always Sub.none
        , view = view
        }