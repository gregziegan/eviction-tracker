module Page.Admin.Defendants.Edit exposing (Data, Model, Msg, page)

import Browser.Events exposing (onMouseDown)
import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import Defendant exposing (Defendant)
import Dict
import Element exposing (Element, below, centerX, column, el, fill, height, maximum, minimum, padding, paddingXY, paragraph, px, row, spacing, spacingXY, text, textColumn, width)
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Head
import Head.Seo as Seo
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Log
import Logo
import MultiInput
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import QueryParams
import Regex
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Rollbar exposing (Rollbar)
import Runtime
import Session exposing (Session)
import Shared
import Sprite
import UI.Button as Button
import UI.Icon as Icon
import UI.Palette as Palette
import UI.RenderConfig exposing (RenderConfig)
import Url.Builder
import View exposing (View)


type alias FormOptions =
    { tooltip : Maybe Tooltip
    , problems : List Problem
    , originalDefendant : Maybe Defendant
    , renderConfig : RenderConfig
    }


type alias Form =
    { firstName : String
    , lastName : String
    }


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type Tooltip
    = DefendantInfo
    | FirstNameInfo
    | LastNameInfo


type SaveState
    = SavingDefendant
    | Done


type alias Model =
    { id : Maybe Int
    , defendant : Maybe Defendant
    , tooltip : Maybe Tooltip
    , problems : List Problem
    , form : FormStatus
    , saveState : SaveState
    , newFormOnSuccess : Bool
    }


editForm : Defendant -> Form
editForm defendant =
    { firstName = defendant.name
    , lastName = defendant.lastName
    }


initCreate : Form
initCreate =
    { firstName = ""
    , lastName = ""
    }


type FormStatus
    = Initializing Int
    | Ready Form


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    let
        session =
            sharedModel.session

        maybeCred =
            Session.cred session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        maybeId =
            case pageUrl of
                Just url ->
                    url.query
                        |> Maybe.andThen (Dict.get "id" << QueryParams.toDict)
                        |> Maybe.andThen List.head
                        |> Maybe.andThen String.toInt

                Nothing ->
                    Nothing
    in
    ( { defendant = Nothing
      , id = maybeId
      , tooltip = Nothing
      , problems = []
      , form =
            case maybeId of
                Just id ->
                    Initializing id

                Nothing ->
                    Ready initCreate
      , saveState = Done
      , newFormOnSuccess = False
      }
    , case maybeId of
        Just id ->
            getDefendant domain id maybeCred

        Nothing ->
            Cmd.none
    )


getDefendant : String -> Int -> Maybe Cred -> Cmd Msg
getDefendant domain id maybeCred =
    Rest.get (Endpoint.defendant domain id) maybeCred GotDefendant (Rest.itemDecoder Defendant.decoder)


type Msg
    = GotDefendant (Result Http.Error (Rest.Item Defendant))
    | ChangeTooltip Tooltip
    | CloseTooltip
    | ChangedFirstName String
    | ChangedLastName String
    | SubmitForm
    | SubmitAndAddAnother
    | CreatedDefendant (Result Http.Error (Rest.Item Defendant))
    | NoOp


updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    ( { model
        | form =
            case model.form of
                Initializing _ ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
      }
    , Cmd.none
    )


updateFormNarrow : (Form -> ( Form, Cmd Msg )) -> Model -> ( Model, Cmd Msg )
updateFormNarrow transform model =
    let
        ( newForm, cmd ) =
            case model.form of
                Initializing _ ->
                    ( model.form, Cmd.none )

                Ready oldForm ->
                    let
                        ( updatedForm, dropdownCmd ) =
                            transform oldForm
                    in
                    ( Ready updatedForm, dropdownCmd )
    in
    ( { model
        | form = newForm
      }
    , cmd
    )


savingError : Http.Error -> Model -> Model
savingError httpError model =
    let
        problems =
            [ ServerError "Error saving defendant" ]
    in
    { model | problems = problems }


defaultSeparators : List String
defaultSeparators =
    [ "\n", "\t" ]


multiInputUpdateConfig =
    { separators = defaultSeparators }


update :
    PageUrl
    -> Maybe Nav.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel static msg model =
    let
        session =
            sharedModel.session

        rollbar =
            Log.reporting static.sharedData.runtime

        domain =
            Runtime.domain static.sharedData.runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        GotDefendant result ->
            case result of
                Ok defendantPage ->
                    ( { model
                        | defendant = Just defendantPage.data
                        , form = Ready (editForm defendantPage.data)
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( model, logHttpError httpError )

        ChangeTooltip selection ->
            ( { model
                | tooltip =
                    if Just selection == model.tooltip then
                        Nothing

                    else
                        Just selection
              }
            , Cmd.none
            )

        CloseTooltip ->
            ( { model | tooltip = Nothing }, Cmd.none )

        ChangedFirstName name ->
            updateForm (\form -> { form | firstName = name }) model

        ChangedLastName name ->
            updateForm (\form -> { form | lastName = name }) model

        SubmitForm ->
            submitForm domain session model

        SubmitAndAddAnother ->
            submitFormAndAddAnother domain session model

        CreatedDefendant (Ok defendantItem) ->
            nextStepSave
                session
                { model
                    | defendant = Just defendantItem.data
                }

        CreatedDefendant (Err httpError) ->
            ( savingError httpError model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


submitFormAndAddAnother : String -> Session -> Model -> ( Model, Cmd Msg )
submitFormAndAddAnother domain session model =
    Tuple.mapFirst (\m -> { m | newFormOnSuccess = True }) (submitForm domain session model)


submitForm : String -> Session -> Model -> ( Model, Cmd Msg )
submitForm domain session model =
    let
        maybeCred =
            Session.cred session
    in
    case validate model.form of
        Ok validForm ->
            let
                defendant =
                    toDefendant model.id validForm
            in
            ( { model
                | newFormOnSuccess = False
                , problems = []
                , saveState = SavingDefendant
              }
            , updateDefendant domain maybeCred model defendant
            )

        Err problems ->
            ( { model | newFormOnSuccess = False, problems = problems }
            , Cmd.none
            )


toDefendant : Maybe Int -> TrimmedForm -> Defendant
toDefendant id (Trimmed form) =
    { id = Maybe.withDefault -1 id
    , firstName = form.firstName
    , lastName = form.lastName
    , middleName = Nothing
    , suffix = Nothing
    , name = form.firstName ++ " " ++ form.lastName
    , aliases = []
    , potentialPhones = Nothing
    , verifiedPhone = Nothing
    }


nextStepSave : Session -> Model -> ( Model, Cmd Msg )
nextStepSave session model =
    case validate model.form of
        Ok form ->
            let
                defendant =
                    toDefendant model.id form
            in
            case model.saveState of
                SavingDefendant ->
                    ( { model | saveState = Done }
                    , Cmd.none
                    )

                Done ->
                    ( model
                    , if model.newFormOnSuccess then
                        Maybe.withDefault Cmd.none <|
                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [] [])) (Session.navKey session)

                      else
                        Maybe.withDefault Cmd.none <|
                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [ String.fromInt defendant.id ] [])) (Session.navKey session)
                    )

        Err _ ->
            ( model, Cmd.none )


type alias Field =
    { tooltip : Maybe Tooltip
    , description : List (Element Msg)
    , children : List (Element Msg)
    , currentTooltip : Maybe Tooltip
    }


requiredStar =
    el [ Palette.toFontColor Palette.red, Element.alignTop, width Element.shrink ] (text "*")


viewField : Field -> Element Msg
viewField field =
    let
        tooltip =
            case field.tooltip of
                Just tip ->
                    withTooltip tip field.currentTooltip field.description

                Nothing ->
                    []
    in
    row
        ([ width fill, height fill, spacingXY 5 0, paddingXY 0 10 ] ++ tooltip)
        field.children


withValidation : ValidatedField -> List Problem -> List (Element.Attr () msg) -> List (Element.Attr () msg)
withValidation validatedField problems attrs =
    let
        maybeError =
            problems
                |> List.filterMap
                    (\problem ->
                        case problem of
                            InvalidEntry field problemText ->
                                if validatedField == field then
                                    Just problemText

                                else
                                    Nothing

                            ServerError _ ->
                                Nothing
                    )
                |> List.head
    in
    attrs
        ++ (case maybeError of
                Just errorText ->
                    [ Palette.toBorderColor Palette.red
                    , Element.below
                        (row [ paddingXY 0 10, spacing 5, Font.size 14 ]
                            [ FeatherIcons.alertTriangle
                                |> FeatherIcons.withSize 16
                                |> FeatherIcons.toHtml []
                                |> Element.html
                                |> Element.el []
                            , text errorText
                            ]
                        )
                    ]

                Nothing ->
                    []
           )


textInput attrs config =
    Input.text ([] ++ attrs) config


requiredLabel labelFn str =
    labelFn [] (row [ spacing 5 ] [ text str, requiredStar ])


viewFirstName : FormOptions -> Form -> Element Msg
viewFirstName options form =
    column [ width (fill |> minimum 600), height fill, paddingXY 0 10 ]
        [ viewField
            { tooltip = Just FirstNameInfo
            , description = [ paragraph [] [ text "This name is how we uniquely identify a Defendant." ] ]
            , currentTooltip = options.tooltip
            , children =
                [ textInput
                    (withValidation FirstName options.problems [ Input.focusedOnLoad ])
                    { onChange = ChangedFirstName
                    , text = form.firstName
                    , placeholder = Nothing
                    , label = requiredLabel Input.labelAbove "First name"
                    }
                ]
            }
        ]


viewLastName : FormOptions -> Form -> Element Msg
viewLastName options form =
    column [ width (fill |> minimum 600), height fill, paddingXY 0 10 ]
        [ viewField
            { tooltip = Just LastNameInfo
            , description = [ paragraph [] [ text "This name is how we uniquely identify a Defendant." ] ]
            , currentTooltip = options.tooltip
            , children =
                [ textInput
                    (withValidation FirstName options.problems [ Input.focusedOnLoad ])
                    { onChange = ChangedLastName
                    , text = form.lastName
                    , placeholder = Nothing
                    , label = requiredLabel Input.labelAbove "Last name"
                    }
                ]
            }
        ]


matches : String -> String -> Bool
matches regex =
    let
        validRegex =
            Regex.fromString regex
                |> Maybe.withDefault Regex.never
    in
    Regex.findAtMost 1 validRegex >> List.isEmpty >> not


formGroup : List (Element Msg) -> Element Msg
formGroup group =
    row
        [ spacing 10
        , width fill
        ]
        group


tile : List (Element Msg) -> Element Msg
tile groups =
    column
        [ spacing 20
        , padding 20
        , width fill
        , Border.rounded 3
        , Palette.toBorderColor Palette.gray
        , Border.width 1
        , Border.shadow { offset = ( 0, 10 ), size = 1, blur = 30, color = Element.rgb 60 60 60 }
        ]
        groups


submitAndAddAnother : RenderConfig -> Element Msg
submitAndAddAnother cfg =
    Button.fromLabeledOnRightIcon (Icon.add "Save and add another")
        |> Button.cmd SubmitAndAddAnother Button.clear
        |> Button.renderElement cfg


submitButton : RenderConfig -> Element Msg
submitButton cfg =
    Button.fromLabeledOnRightIcon (Icon.check "Save")
        |> Button.cmd SubmitForm Button.primary
        |> Button.renderElement cfg


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing id ->
            column [] [ text ("Fetching defendant " ++ String.fromInt id) ]

        Ready form ->
            column [ centerX, spacing 30, width (fill |> maximum 1200) ]
                [ tile
                    [ paragraph [ Font.center, centerX ] [ text "Defendant" ]
                    , formGroup
                        [ viewFirstName options form
                        , viewLastName options form
                        ]
                    ]
                , row [ Element.alignRight, spacing 10 ]
                    [ submitAndAddAnother options.renderConfig
                    , submitButton options.renderConfig
                    ]
                ]


formOptions : RenderConfig -> Model -> FormOptions
formOptions cfg model =
    { tooltip = model.tooltip
    , problems = model.problems
    , originalDefendant = model.defendant
    , renderConfig = cfg
    }


viewProblem : Problem -> Element Msg
viewProblem problem =
    paragraph []
        [ case problem of
            InvalidEntry _ _ ->
                Element.none

            ServerError err ->
                text ("Something went wrong: " ++ err)
        ]


viewProblems : List Problem -> Element Msg
viewProblems problems =
    row [] [ column [] (List.map viewProblem problems) ]


viewTooltip : List (Element Msg) -> Element Msg
viewTooltip content =
    textColumn
        [ width (fill |> maximum 600)
        , padding 10
        , Palette.toBackgroundColor Palette.red
        , Palette.toFontColor Palette.genericWhite
        , Border.rounded 3
        , Font.size 14
        , Border.shadow
            { offset = ( 0, 3 ), blur = 6, size = 0, color = Element.rgba 0 0 0 0.32 }
        ]
        content


withTooltip : Tooltip -> Maybe Tooltip -> List (Element Msg) -> List (Element.Attribute Msg)
withTooltip candidate active content =
    if Just candidate == active then
        [ below (viewTooltip content) ]

    else
        []


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    let
        cfg =
            sharedModel.renderConfig
    in
    { title = title
    , body =
        [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
        , row
            [ centerX
            , padding 20
            , Font.size 20
            , width (fill |> maximum 1200 |> minimum 400)
            , Element.inFront
                (el
                    ([ Font.size 14
                     , Element.alignRight
                     , Element.alignTop
                     , Events.onLoseFocus CloseTooltip
                     ]
                        ++ withTooltip DefendantInfo model.tooltip [ paragraph [] [ text "The person sueing a tenant for possession or fees." ] ]
                    )
                    (Button.fromLabel "Help" |> Button.cmd (ChangeTooltip DefendantInfo) Button.primary |> Button.renderElement cfg)
                )
            ]
            [ column [ centerX, spacing 10 ]
                [ row
                    [ width fill
                    ]
                    [ column [ centerX, width (px 300) ]
                        [ paragraph [ Font.center, centerX, width Element.shrink ]
                            [ text
                                ((case model.id of
                                    Just _ ->
                                        "Edit"

                                    Nothing ->
                                        "Create"
                                 )
                                    ++ " Defendant"
                                )
                            ]
                        ]
                    ]
                , viewProblems model.problems
                , row [ width fill ]
                    [ viewForm (formOptions cfg model) model.form
                    ]
                ]
            ]
        ]
    }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    case model.form of
        Initializing _ ->
            Sub.none

        Ready form ->
            Sub.batch <|
                Maybe.withDefault [] (Maybe.map (List.singleton << onOutsideClick) model.tooltip)


isOutsideTooltip : String -> Decode.Decoder Bool
isOutsideTooltip tooltipId =
    Decode.oneOf
        [ Decode.field "id" Decode.string
            |> Decode.andThen
                (\id ->
                    if tooltipId == id then
                        Decode.succeed False

                    else
                        Decode.fail "continue"
                )
        , Decode.lazy (\_ -> isOutsideTooltip tooltipId |> Decode.field "parentNode")
        , Decode.succeed True
        ]


outsideTarget : String -> Msg -> Decode.Decoder Msg
outsideTarget tooltipId msg =
    Decode.field "target" (isOutsideTooltip tooltipId)
        |> Decode.andThen
            (\isOutside ->
                if isOutside then
                    Decode.succeed msg

                else
                    Decode.fail "inside dropdown"
            )


onOutsideClick : Tooltip -> Sub Msg
onOutsideClick tip =
    onMouseDown (outsideTarget (tooltipToString tip) CloseTooltip)


tooltipToString : Tooltip -> String
tooltipToString tip =
    case tip of
        DefendantInfo ->
            "defendant-info"

        FirstNameInfo ->
            "first-name-info"

        LastNameInfo ->
            "last-name-info"



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed Form


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = FirstName
    | LastName


fieldsToValidate : List ValidatedField
fieldsToValidate =
    [ FirstName
    , LastName
    ]


{-| Trim the form and validate its fields. If there are problems, report them!
-}
validate : FormStatus -> Result (List Problem) TrimmedForm
validate formStatus =
    case formStatus of
        Initializing _ ->
            Err []

        Ready form ->
            let
                trimmedForm =
                    trimFields form
            in
            case List.concatMap (validateField trimmedForm) fieldsToValidate of
                [] ->
                    Ok trimmedForm

                problems ->
                    Err problems


validateField : TrimmedForm -> ValidatedField -> List Problem
validateField (Trimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            FirstName ->
                if String.isEmpty form.firstName then
                    []

                else
                    []

            LastName ->
                if String.isEmpty form.lastName then
                    []

                else
                    []


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { form
            | firstName = String.trim form.firstName
            , lastName = String.trim form.lastName
        }


conditional fieldName fn field =
    Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


toBody body =
    Encode.object [ ( "data", body ) ]
        |> Http.jsonBody


updateDefendant : String -> Maybe Cred -> Model -> Defendant -> Cmd Msg
updateDefendant domain maybeCred model form =
    let
        defendant =
            Encode.object
                ([ ( "name", Encode.string form.name )
                 ]
                    ++ conditional "id" Encode.int model.id
                )
    in
    case model.id of
        Just id ->
            Rest.itemDecoder Defendant.decoder
                |> Rest.patch (Endpoint.defendant domain id) maybeCred (toBody defendant) CreatedDefendant

        Nothing ->
            Rest.post (Endpoint.defendants domain []) maybeCred (toBody defendant) CreatedDefendant (Rest.itemDecoder Defendant.decoder)


type alias RouteParams =
    {}


page : Page.PageWithState RouteParams Data Model Msg
page =
    Page.single
        { head = head
        , data = data
        }
        |> Page.buildWithLocalState
            { init = init
            , update = update
            , view = view
            , subscriptions = subscriptions
            }


type alias Data =
    ()


data : DataSource Data
data =
    DataSource.succeed ()


title =
    "RDC | Admin | Defendants | Edit"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Edit defendant details"
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website
