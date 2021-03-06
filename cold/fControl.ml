let g = Fgram.create_lexer ~annot:"" ~keywords:[] ()

let item = Fgram.mk_dynamic g "item"

let dot_namespace = Fgram.mk_dynamic g "dot_namespace"

let items = Fgram.mk_dynamic g "items"

let _ =
  begin
    Fgram.unsafe_extend_single (item : 'item Fgram.t )
      (None,
        (None, None,
          [([`Skeyword "default";
            `Stoken
              (((function | `STR (_,_) -> true | _ -> false)),
                (`App ((`App ((`Vrn "STR"), `Any)), `Any)), "`STR (_,_)")],
             ("AstQuotation.set_default (FToken.resolve_name _loc ((`Sub []), s))\n",
               (Fgram.mk_action
                  (fun (__fan_1 : [> FToken.t])  _  (_loc : FLoc.t)  ->
                     match __fan_1 with
                     | `STR (_,s) ->
                         (AstQuotation.set_default
                            (FToken.resolve_name _loc ((`Sub []), s)) : 
                         'item )
                     | _ ->
                         failwith
                           "AstQuotation.set_default (FToken.resolve_name _loc ((`Sub []), s))\n"))));
          ([`Skeyword "import";
           `Snterm (Fgram.obj (dot_namespace : 'dot_namespace Fgram.t ))],
            ("FToken.paths := ((`Absolute xs) :: (FToken.paths.contents))\n",
              (Fgram.mk_action
                 (fun (xs : 'dot_namespace)  _  (_loc : FLoc.t)  ->
                    (FToken.paths := ((`Absolute xs) ::
                       (FToken.paths.contents)) : 'item )))));
          ([`Skeyword "filter";
           `Stoken
             (((function | `STR (_,_) -> true | _ -> false)),
               (`App ((`App ((`Vrn "STR"), `Any)), `Any)), "`STR (_,_)")],
            ("AstFilters.use_implem_filter s\n",
              (Fgram.mk_action
                 (fun (__fan_1 : [> FToken.t])  _  (_loc : FLoc.t)  ->
                    match __fan_1 with
                    | `STR (_,s) -> (AstFilters.use_implem_filter s : 'item )
                    | _ -> failwith "AstFilters.use_implem_filter s\n"))));
          ([`Skeyword "lang_clear"],
            ("begin AstQuotation.clear_map (); AstQuotation.clear_default () end\n",
              (Fgram.mk_action
                 (fun _  (_loc : FLoc.t)  ->
                    (begin
                       AstQuotation.clear_map ();
                       AstQuotation.clear_default ()
                     end : 'item )))))]));
    Fgram.unsafe_extend_single (dot_namespace : 'dot_namespace Fgram.t )
      (None,
        (None, None,
          [([`Stoken
               (((function | `Uid _ -> true | _ -> false)),
                 (`App ((`Vrn "Uid"), `Any)), "`Uid _");
            `Skeyword ".";
            `Sself],
             ("i :: xs\n",
               (Fgram.mk_action
                  (fun (xs : 'dot_namespace)  _  (__fan_0 : [> FToken.t]) 
                     (_loc : FLoc.t)  ->
                     match __fan_0 with
                     | `Uid i -> (i :: xs : 'dot_namespace )
                     | _ -> failwith "i :: xs\n"))));
          ([`Stoken
              (((function | `Uid _ -> true | _ -> false)),
                (`App ((`Vrn "Uid"), `Any)), "`Uid _")],
            ("[i]\n",
              (Fgram.mk_action
                 (fun (__fan_0 : [> FToken.t])  (_loc : FLoc.t)  ->
                    match __fan_0 with
                    | `Uid i -> ([i] : 'dot_namespace )
                    | _ -> failwith "[i]\n"))))]));
    Fgram.unsafe_extend_single (items : 'items Fgram.t )
      (None,
        (None, None,
          [([`Snterm (Fgram.obj (item : 'item Fgram.t )); `Skeyword ";"],
             ("()\n",
               (Fgram.mk_action
                  (fun _  _  (_loc : FLoc.t)  -> (() : 'items )))));
          ([`Snterm (Fgram.obj (item : 'item Fgram.t ));
           `Skeyword ";";
           `Sself],
            ("()\n",
              (Fgram.mk_action
                 (fun _  _  _  (_loc : FLoc.t)  -> (() : 'items )))));
          ([],
            ("()\n",
              (Fgram.mk_action (fun (_loc : FLoc.t)  -> (() : 'items )))))]))
  end

let _ =
  Fdir.register ("control", (fun loc  c  -> Fgram.parse_string ~loc items c))