%% SPDX-License-Identifier: AGPL-3.0-or-later

-module(presence_payload).
-typing([eqwalizer]).

-export([build/5, build/6, normalize_activities/1]).

-export_type([status/0, custom_status/0]).

-type status() :: online | offline | idle | dnd | invisible | binary().
-type custom_status() :: map() | null.

-spec build(map(), status(), boolean(), boolean(), custom_status()) -> map().
build(UserData, Status, Mobile, Afk, CustomStatus) ->
    build(UserData, Status, Mobile, Afk, CustomStatus, []).

-spec build(map(), status(), boolean(), boolean(), custom_status(), term()) -> map().
build(UserData, Status, Mobile, Afk, CustomStatus, Activities) ->
    StatusBin = ensure_status_binary(Status),
    Payload = #{
        <<"user">> => user_utils:normalize_user(UserData),
        <<"status">> => StatusBin,
        <<"mobile">> => Mobile,
        <<"afk">> => Afk,
        <<"custom_status">> => custom_status_for(StatusBin, CustomStatus)
    },
    put_activities(Payload, StatusBin, Activities).

-spec put_activities(map(), binary(), term()) -> map().
put_activities(Payload, <<"offline">>, _Activities) ->
    Payload;
put_activities(Payload, <<"invisible">>, _Activities) ->
    Payload;
put_activities(Payload, _StatusBin, Activities) ->
    case normalize_activities(Activities) of
        [] -> Payload;
        Normalized -> Payload#{<<"activities">> => Normalized}
    end.

-spec normalize_activities(term()) -> [map()].
normalize_activities(List) when is_list(List) ->
    normalize_activity_list(List, 0, []);
normalize_activities(_) ->
    [].

-spec normalize_activity_list([term()], non_neg_integer(), [map()]) -> [map()].
normalize_activity_list([], _Count, Acc) ->
    lists:reverse(Acc);
normalize_activity_list(_Rest, Count, Acc) when Count >= 5 ->
    lists:reverse(Acc);
normalize_activity_list([Item | Rest], Count, Acc) ->
    case normalize_activity(Item) of
        undefined -> normalize_activity_list(Rest, Count, Acc);
        Activity -> normalize_activity_list(Rest, Count + 1, [Activity | Acc])
    end.

-spec normalize_activity(term()) -> map() | undefined.
normalize_activity(Map) when is_map(Map) ->
    case clip_text(maps:get(<<"name">>, Map, undefined)) of
        undefined ->
            undefined;
        Name ->
            Activity0 = #{<<"name">> => Name, <<"type">> => activity_type(Map)},
            Activity1 = put_text(<<"details">>, Map, Activity0),
            Activity2 = put_text(<<"state">>, Map, Activity1),
            put_timestamps(Map, Activity2)
    end;
normalize_activity(_) ->
    undefined.

-spec activity_type(map()) -> 0 | 2 | 3.
activity_type(Map) ->
    case maps:get(<<"type">>, Map, 0) of
        2 -> 2;
        3 -> 3;
        _ -> 0
    end.

-spec put_text(binary(), map(), map()) -> map().
put_text(Key, Map, Activity) ->
    case clip_text(maps:get(Key, Map, undefined)) of
        undefined -> Activity;
        Text -> Activity#{Key => Text}
    end.

-spec put_timestamps(map(), map()) -> map().
put_timestamps(Map, Activity) ->
    case maps:get(<<"timestamps">>, Map, undefined) of
        Ts when is_map(Ts) ->
            Start = timestamp_value(maps:get(<<"start">>, Ts, undefined)),
            End = timestamp_value(maps:get(<<"end">>, Ts, undefined)),
            Out0 = maybe_put_ts(<<"start">>, Start, #{}),
            Out = maybe_put_ts(<<"end">>, End, Out0),
            case map_size(Out) of
                0 -> Activity;
                _ -> Activity#{<<"timestamps">> => Out}
            end;
        _ ->
            Activity
    end.

-spec maybe_put_ts(binary(), integer() | undefined, map()) -> map().
maybe_put_ts(_Key, undefined, Map) ->
    Map;
maybe_put_ts(Key, Value, Map) ->
    Map#{Key => Value}.

-spec timestamp_value(term()) -> integer() | undefined.
timestamp_value(N) when is_integer(N), N > 0, N < 10000000000000 ->
    N;
timestamp_value(_) ->
    undefined.

-spec clip_text(term()) -> binary() | undefined.
clip_text(Bin) when is_binary(Bin) ->
    Trimmed = string:trim(Bin),
    case Trimmed of
        <<>> -> undefined;
        _ when byte_size(Trimmed) > 128 -> undefined;
        _ -> Trimmed
    end;
clip_text(_) ->
    undefined.

-spec ensure_status_binary(term()) -> binary().
ensure_status_binary(online) -> <<"online">>;
ensure_status_binary(offline) -> <<"offline">>;
ensure_status_binary(idle) -> <<"idle">>;
ensure_status_binary(dnd) -> <<"dnd">>;
ensure_status_binary(invisible) -> <<"offline">>;
ensure_status_binary(<<"invisible">>) -> <<"offline">>;
ensure_status_binary(Status) when is_binary(Status) -> Status;
ensure_status_binary(_) -> <<"offline">>.

-spec custom_status_for(binary(), custom_status()) -> custom_status().
custom_status_for(<<"offline">>, _CustomStatus) ->
    null;
custom_status_for(<<"invisible">>, _CustomStatus) ->
    null;
custom_status_for(_StatusBin, CustomStatus) ->
    custom_status_expiry:clear_if_expired(normalize_custom_status(CustomStatus)).

-spec normalize_custom_status(term()) -> custom_status().
normalize_custom_status(null) -> null;
normalize_custom_status(CustomStatus) when is_map(CustomStatus) -> CustomStatus;
normalize_custom_status(_) -> null.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

ensure_status_binary_atom_test() ->
    ?assertEqual(<<"online">>, ensure_status_binary(online)),
    ?assertEqual(<<"offline">>, ensure_status_binary(offline)),
    ?assertEqual(<<"idle">>, ensure_status_binary(idle)),
    ?assertEqual(<<"dnd">>, ensure_status_binary(dnd)),
    ?assertEqual(<<"offline">>, ensure_status_binary(invisible)).

ensure_status_binary_binary_test() ->
    ?assertEqual(<<"online">>, ensure_status_binary(<<"online">>)),
    ?assertEqual(<<"offline">>, ensure_status_binary(<<"invisible">>)),
    ?assertEqual(<<"custom">>, ensure_status_binary(<<"custom">>)).

ensure_status_binary_unknown_test() ->
    ?assertEqual(<<"offline">>, ensure_status_binary(123)),
    ?assertEqual(<<"offline">>, ensure_status_binary(undefined)).

custom_status_for_visible_test() ->
    Status = #{<<"text">> => <<"hello">>},
    ?assertEqual(Status, custom_status_for(<<"online">>, Status)),
    ?assertEqual(Status, custom_status_for(<<"idle">>, Status)),
    ?assertEqual(Status, custom_status_for(<<"dnd">>, Status)).

custom_status_for_invisible_test() ->
    Status = #{<<"text">> => <<"hello">>},
    ?assertEqual(null, custom_status_for(<<"offline">>, Status)),
    ?assertEqual(null, custom_status_for(<<"invisible">>, Status)).

custom_status_for_null_test() ->
    ?assertEqual(null, custom_status_for(<<"online">>, null)).

normalize_custom_status_test() ->
    ?assertEqual(null, normalize_custom_status(null)),
    ?assertEqual(#{<<"text">> => <<"hi">>}, normalize_custom_status(#{<<"text">> => <<"hi">>})),
    ?assertEqual(null, normalize_custom_status(<<"invalid">>)),
    ?assertEqual(null, normalize_custom_status(123)).

build_invisible_atom_normalized_to_offline_test() ->
    CustomStatus = #{<<"text">> => <<"hello">>},
    Result = build(test_user(), invisible, false, false, CustomStatus),
    ?assertEqual(<<"offline">>, maps:get(<<"status">>, Result)),
    ?assertEqual(null, maps:get(<<"custom_status">>, Result)).

build_invisible_binary_normalized_to_offline_test() ->
    CustomStatus = #{<<"text">> => <<"hello">>},
    Result = build(test_user(), <<"invisible">>, false, false, CustomStatus),
    ?assertEqual(<<"offline">>, maps:get(<<"status">>, Result)),
    ?assertEqual(null, maps:get(<<"custom_status">>, Result)).

build_clears_expired_custom_status_test() ->
    Result = build(test_user(), online, false, false, expired_custom_status()),
    ?assertEqual(<<"online">>, maps:get(<<"status">>, Result)),
    ?assertEqual(null, maps:get(<<"custom_status">>, Result)).

build_coalesces_an_expired_status_with_no_status_test() ->
    ?assertEqual(
        build(test_user(), online, false, false, null),
        build(test_user(), online, false, false, expired_custom_status())
    ).

build_keeps_unexpired_custom_status_test() ->
    Live = future_custom_status(),
    Result = build(test_user(), dnd, false, false, Live),
    ?assertEqual(Live, maps:get(<<"custom_status">>, Result)).

build_keeps_custom_status_without_expires_at_test() ->
    Live = #{<<"text">> => <<"forever">>},
    Result = build(test_user(), idle, false, false, Live),
    ?assertEqual(Live, maps:get(<<"custom_status">>, Result)).

build_omits_empty_activities_test() ->
    Result = build(test_user(), online, false, false, null, []),
    ?assertNot(maps:is_key(<<"activities">>, Result)).

build_includes_activities_test() ->
    Activity = #{<<"name">> => <<"Spotify">>, <<"type">> => 2, <<"details">> => <<"Song">>},
    Result = build(test_user(), online, false, false, null, [Activity]),
    ?assertEqual([Activity], maps:get(<<"activities">>, Result)).

build_hides_activities_when_offline_test() ->
    Activity = #{<<"name">> => <<"Spotify">>, <<"type">> => 2},
    Result = build(test_user(), offline, false, false, null, [Activity]),
    ?assertNot(maps:is_key(<<"activities">>, Result)).

normalize_activities_drops_junk_test() ->
    ?assertEqual([], normalize_activities(<<"nope">>)),
    ?assertEqual(
        [#{<<"name">> => <<"Game">>, <<"type">> => 0}],
        normalize_activities([#{<<"name">> => <<"  Game  ">>, <<"type">> => 9}, <<"bad">>])
    ).

build_keeps_malformed_expires_at_test() ->
    Live = #{<<"text">> => <<"hi">>, <<"expires_at">> => <<"not-a-date">>},
    Result = build(test_user(), online, false, false, Live),
    ?assertEqual(Live, maps:get(<<"custom_status">>, Result)).

test_user() ->
    #{<<"id">> => <<"1">>, <<"username">> => <<"Test">>}.

expired_custom_status() ->
    #{
        <<"emoji_animated">> => false,
        <<"emoji_name">> => null,
        <<"expires_at">> => <<"2026-05-13T13:02:27.497Z">>,
        <<"text">> => <<"brb">>
    }.

future_custom_status() ->
    ExpiresAt = calendar:system_time_to_rfc3339(
        erlang:system_time(millisecond) + 3600000, [{unit, millisecond}, {offset, "Z"}]
    ),
    #{<<"text">> => <<"brb">>, <<"expires_at">> => list_to_binary(ExpiresAt)}.
-endif.
