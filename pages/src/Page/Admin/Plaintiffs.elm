module Page.Admin.Plaintiffs exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
import Date exposing (Date)
import DatePicker exposing (ChangeEvent(..))
import Element exposing (Element, centerX, column, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, table, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Head
import Head.Seo as Seo
import Html.Attributes
import Html.Events
import Http exposing (Error(..))
import InfiniteScroll
import Json.Decode as Decode
import Loader
import Log
import Logo
import Maybe.Extra
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Palette
import Path exposing (Path)
import Plaintiff exposing (Plaintiff)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint exposing (Endpoint)
import Rollbar exposing (Rollbar)
import Route
import Runtime exposing (Runtime)
import Search exposing (Cursor(..), Search)
import Session exposing (Session)
import Settings exposing (Settings)
import Shared
import Url.Builder exposing (QueryParameter)
import User exposing (User)
import View exposing (View)
import Widget
import Widget.Icon


type alias Model =
    { plaintiffs : List Plaintiff
    , selected : Maybe String
    , hovered : Maybe String
    , search : Search Search.Plaintiffs
    , infiniteScroll : InfiniteScroll.Model Msg
    }


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    let
        session =
            sharedModel.session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        maybeCred =
            Session.cred session

        filters =
            Maybe.withDefault Search.plaintiffsDefault <| Maybe.andThen (Maybe.map (Search.plaintiffsFromString << QueryParams.toString) << .query) pageUrl

        search =
            { filters = filters, cursor = NewSearch, previous = Just filters, totalMatches = Nothing }
    in
    ( { plaintiffs = []
      , search = search
      , selected = Nothing
      , hovered = Nothing
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      }
    , searchPlaintiffs domain maybeCred search
    )


searchPlaintiffs : String -> Maybe Cred -> Search Search.Plaintiffs -> Cmd Msg
searchPlaintiffs domain maybeCred search =
    Rest.get (Endpoint.plaintiffsSearch domain (queryArgsWithPagination search)) maybeCred GotPlaintiffs (Rest.collectionDecoder Plaintiff.decoder)


loadMore : String -> Maybe Cred -> Search Search.Plaintiffs -> InfiniteScroll.Direction -> Cmd Msg
loadMore domain maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchPlaintiffs domain maybeCred search

        End ->
            Cmd.none


queryArgsWithPagination : Search Search.Plaintiffs -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            Search.plaintiffsArgs filters
    in
    if Just search.filters == search.previous then
        case search.cursor of
            NewSearch ->
                queryArgs

            After plaintiffsCursor ->
                ( "cursor", plaintiffsCursor ) :: queryArgs

            End ->
                queryArgs

    else
        queryArgs


type Msg
    = InputName (Maybe String)
    | SelectPlaintiff String
    | HoverPlaintiff String
    | SearchPlaintiffs
    | GotPlaintiffs (Result Http.Error (Rest.Collection Plaintiff))
    | ChangedSorting String
    | InfiniteScrollMsg InfiniteScroll.Msg
    | NoOp


updateFilters :
    (Search.Plaintiffs -> Search.Plaintiffs)
    -> Model
    -> ( Model, Cmd Msg )
updateFilters transform model =
    let
        search =
            model.search
    in
    ( { model | search = { search | filters = transform search.filters } }, Cmd.none )


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
        rollbar =
            Log.reporting static.sharedData.runtime

        session =
            sharedModel.session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        InputName query ->
            updateFilters (\filters -> { filters | name = query }) model

        SelectPlaintiff name ->
            ( { model | selected = Just name }, Cmd.none )

        HoverPlaintiff name ->
            ( { model | hovered = Just name }, Cmd.none )

        SearchPlaintiffs ->
            ( model
            , Cmd.batch
                [ Maybe.withDefault Cmd.none <|
                    Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [ "plaintiffs" ] (Endpoint.toQueryArgs <| Search.plaintiffsArgs model.search.filters))) (Session.navKey session)
                , searchPlaintiffs domain (Session.cred session) model.search
                ]
            )

        GotPlaintiffs (Ok plaintiffsPage) ->
            let
                maybeCred =
                    Session.cred session

                search =
                    { filters = model.search.filters
                    , cursor = Maybe.withDefault End <| Maybe.map After plaintiffsPage.meta.afterCursor
                    , previous = Just model.search.filters
                    , totalMatches = Just plaintiffsPage.meta.totalMatches
                    }

                updatedModel =
                    { model | search = search }
            in
            if model.search.previous == Just model.search.filters then
                ( { updatedModel
                    | plaintiffs = model.plaintiffs ++ plaintiffsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | plaintiffs = plaintiffsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                  }
                , Cmd.none
                )

        GotPlaintiffs (Err httpError) ->
            ( model, logHttpError httpError )

        ChangedSorting _ ->
            ( model, Cmd.none )

        InfiniteScrollMsg subMsg ->
            case model.search.cursor of
                End ->
                    ( model, Cmd.none )

                _ ->
                    let
                        ( infiniteScroll, cmd ) =
                            InfiniteScroll.update InfiniteScrollMsg subMsg model.infiniteScroll
                    in
                    ( { model | infiniteScroll = infiniteScroll }, cmd )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


onEnter : msg -> Element.Attribute msg
onEnter msg =
    Element.htmlAttribute
        (Html.Events.on "keyup"
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\key ->
                        if key == "Enter" then
                            Decode.succeed msg

                        else
                            Decode.fail "Not the enter key"
                    )
            )
        )


type alias SearchInputField =
    { label : String
    , placeholder : String
    , onChange : Maybe String -> Msg
    , query : Maybe String
    }


textSearch : SearchInputField -> Element Msg
textSearch { label, placeholder, query, onChange } =
    Input.search
        [ Element.width (fill |> Element.maximum 400)
        , onEnter SearchPlaintiffs
        ]
        { onChange = onChange << Just
        , text = Maybe.withDefault "" query
        , placeholder = Nothing
        , label = Input.labelAbove [] (text label)
        }


searchFields : Model -> Search.Plaintiffs -> List SearchInputField
searchFields model filters =
    [ { label = "Name", placeholder = "", onChange = InputName, query = filters.name }
    ]


viewSearchBar : Model -> Element Msg
viewSearchBar model =
    Element.row
        [ Element.width (fill |> maximum 1200)
        , Element.spacing 10
        , Element.padding 10
        , Element.centerY
        , Element.centerX
        ]
        [ column [ centerX ]
            [ row [ spacing 10 ]
                (List.map textSearch (searchFields model model.search.filters)
                    ++ [ Input.button
                            [ Element.alignBottom
                            , Background.color Palette.redLight
                            , Element.focused [ Background.color Palette.red ]
                            , Element.height fill
                            , Font.color (Element.rgb 255 255 255)
                            , Element.padding 10
                            , Border.rounded 5
                            , height (px 50)
                            ]
                            { onPress = Just SearchPlaintiffs, label = Element.text "Search" }
                       ]
                )
            ]
        ]


createNewPlaintiff : Element Msg
createNewPlaintiff =
    row [ centerX ]
        [ link buttonLinkAttrs
            { url = Url.Builder.relative [ "plaintiffs", "edit" ] []
            , label = text "Enter New Plaintiff"
            }
        ]


viewFilter filters =
    let
        ifNonEmpty prefix fn filter =
            case filter of
                Just value ->
                    [ paragraph [ centerX, Font.center ] [ text (prefix ++ fn value) ] ]

                Nothing ->
                    []
    in
    List.concat
        [ ifNonEmpty "name is " identity filters.name
        ]


viewEmptyResults filters =
    textColumn [ centerX, spacing 10 ]
        ([ paragraph [ Font.center, centerX, Font.size 24 ]
            [ text "No plaintiffs exist matching your search criteria:" ]
         , paragraph [ centerX, Font.italic, Font.center ]
            [ text "where..." ]
         ]
            ++ (List.intersperse (paragraph [ centerX, Font.center ] [ text "&" ]) <| viewFilter filters)
        )


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = "Organize - Plaintiffs"
    , body =
        [ row [ centerX, padding 10, Font.size 20, width (fill |> maximum 2000 |> minimum 400) ]
            [ column
                [ centerX
                , spacing 10
                , Element.inFront (loader model)
                ]
                [ createNewPlaintiff
                , viewSearchBar model
                , case model.search.totalMatches of
                    Just total ->
                        if total > 1 then
                            paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " plaintiffs matched your search.") ]

                        else
                            Element.none

                    Nothing ->
                        Element.none
                , if model.search.totalMatches == Just 0 then
                    Maybe.withDefault Element.none <| Maybe.map viewEmptyResults model.search.previous

                  else
                    viewPlaintiffs model
                ]
            ]
        ]
    }


loader : Model -> Element Msg
loader { infiniteScroll, search } =
    if InfiniteScroll.isLoading infiniteScroll || search.totalMatches == Nothing then
        row
            [ width fill
            , Element.alignBottom
            ]
            [ Element.el [ centerX, width Element.shrink, height Element.shrink ] (Element.html (Loader.horizontal Color.red)) ]

    else
        Element.none


ascIcon =
    FeatherIcons.chevronUp
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


sortIconStyle =
    { size = 20, color = Color.white }


descIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


noSortIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


tableStyle =
    { elementTable = []
    , content =
        { header = buttonStyle
        , ascIcon = ascIcon
        , descIcon = descIcon
        , defaultIcon = noSortIcon
        }
    }


buttonStyle =
    { elementButton =
        [ width (px 40), height (px 40), Background.color Palette.sred, centerX, Font.center ]
    , ifDisabled = []
    , ifActive = []
    , otherwise = []
    , content =
        { elementRow = [ centerX, Font.center ]
        , content =
            { text = { contentText = [] }
            , icon = { ifDisabled = sortIconStyle, ifActive = sortIconStyle, otherwise = sortIconStyle }
            }
        }
    }


buttonLinkAttrs : List (Element.Attribute Msg)
buttonLinkAttrs =
    [ Background.color Palette.white
    , Font.color Palette.red
    , Border.rounded 3
    , Border.color Palette.sred
    , Border.width 1
    , padding 10
    , Font.size 16
    , Element.mouseOver [ Background.color Palette.redLightest ]
    , Element.focused [ Background.color Palette.redLightest ]
    ]


viewEditButton : Maybe String -> Int -> Plaintiff -> Element Msg
viewEditButton hovered index plaintiff =
    row
        (tableCellAttrs (modBy 2 index == 0) hovered plaintiff)
        [ link
            (buttonLinkAttrs ++ [ Events.onFocus (SelectPlaintiff plaintiff.name) ])
            { url = Url.Builder.relative [ "plaintiffs", "edit" ] (Endpoint.toQueryArgs [ ( "id", String.fromInt plaintiff.id ) ])
            , label = text "Edit"
            }
        ]


tableCellAttrs : Bool -> Maybe String -> Plaintiff -> List (Element.Attribute Msg)
tableCellAttrs striped hovered plaintiff =
    [ Element.width (Element.shrink |> maximum 400)
    , height (px 60)
    , Element.scrollbarX

    --, Element.clipX
    , Element.padding 10
    , Border.solid
    , Border.color Palette.grayLight
    , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
    , Events.onMouseDown (SelectPlaintiff plaintiff.name)
    , Events.onMouseEnter (HoverPlaintiff plaintiff.name)
    ]
        ++ (if hovered == Just plaintiff.name then
                [ Background.color Palette.redLightest ]

            else if striped then
                [ Background.color Palette.grayBack ]

            else
                []
           )


viewHeaderCell text =
    Element.row
        [ Element.width (Element.shrink |> maximum 200)
        , Element.padding 10
        , Font.semiBold
        , Border.solid
        , Border.color Palette.grayLight
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        ]
        [ Element.text text ]


viewTextRow : Maybe String -> (Plaintiff -> String) -> Int -> Plaintiff -> Element Msg
viewTextRow hovered toText index plaintiff =
    Element.row (tableCellAttrs (modBy 2 index == 0) hovered plaintiff)
        [ Element.text (toText plaintiff) ]


viewPlaintiffs : Model -> Element Msg
viewPlaintiffs model =
    let
        cell =
            viewTextRow model.hovered
    in
    Element.indexedTable
        [ width (fill |> maximum 1400)
        , height (px 600)
        , Font.size 14
        , Element.scrollbarY
        , Element.htmlAttribute (InfiniteScroll.infiniteScroll InfiniteScrollMsg)
        ]
        { data = model.plaintiffs
        , columns =
            [ { header = viewHeaderCell "Name"
              , view = cell <| .name
              , width = Element.fill
              }
            , { header = viewHeaderCell "Aliases"
              , view = cell <| String.join "," << .aliases
              , width = Element.fill
              }
            , { header = viewHeaderCell "Edit"
              , view = viewEditButton model.hovered
              , width = fill
              }
            ]
        }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none


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


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Manage plaintiffs"
        , locale = Nothing
        , title = "Red Door Collective | Admin | Plaintiffs"
        }
        |> Seo.website
