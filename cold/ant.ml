open FAst

open LibUtil

open FanUtil

let antiquot_expander ~parse_pat  ~parse_exp  =
  object 
    inherit  Objs.map as super
    method! pat (x : pat) =
      match x with
      | `Ant (_loc,{ cxt; sep; decorations; content = code }) ->
          let meta_loc_pat _loc _ = (`Any _loc : FAst.pat ) in
          let mloc _loc = meta_loc_pat _loc _loc in
          let e = parse_pat _loc code in
          (match (decorations, cxt, sep) with
           | (("uid"|"lid"|"par"|"seq"|"flo"|"int"|"int32"|"int64"
               |"nativeint"|"chr"|"str" as x),_,_)
             |(("vrn" as x),("exp"|"pat"),_) ->
               let x = String.capitalize x in
               (`App (_loc, (`App (_loc, (`Vrn (_loc, x)), (mloc _loc))), e) : 
                 FAst.pat )
           | _ -> super#pat e)
      | e -> super#pat e
    method! exp (x : exp) =
      match x with
      | `Ant (_loc,{ cxt; sep; decorations; content = code }) ->
          let meta_loc_exp _loc loc =
            match AstQuotation.current_loc_name.contents with
            | Some "here" -> AstLib.meta_here _loc loc
            | x ->
                let x = Option.default FLoc.name.contents x in
                (`Lid (_loc, x) : FAst.exp ) in
          let mloc _loc = meta_loc_exp _loc _loc in
          let e = parse_exp _loc code in
          (match (decorations, cxt, sep) with
           | (("uid"|"lid"|"par"|"seq"|"flo"|"int"|"int32"|"int64"
               |"nativeint"|"chr"|"str" as x),_,_)
             |(("vrn" as x),("exp"|"pat"),_) ->
               (`App
                  (_loc, (`Vrn (_loc, (String.capitalize x))),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`nativeint",_,_) ->
               let e: FAst.exp =
                 `App
                   (_loc,
                     (`Dot
                        (_loc, (`Uid (_loc, "Nativeint")),
                          (`Lid (_loc, "to_string")))), e) in
               (`App
                  (_loc, (`Vrn (_loc, "Nativeint")),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`int",_,_) ->
               let e: FAst.exp =
                 `App (_loc, (`Lid (_loc, "string_of_int")), e) in
               (`App
                  (_loc, (`Vrn (_loc, "Int")),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`int32",_,_) ->
               let e: FAst.exp =
                 `App
                   (_loc,
                     (`Dot
                        (_loc, (`Uid (_loc, "Int32")),
                          (`Lid (_loc, "to_string")))), e) in
               (`App
                  (_loc, (`Vrn (_loc, "Int32")),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`int64",_,_) ->
               let e: FAst.exp =
                 `App
                   (_loc,
                     (`Dot
                        (_loc, (`Uid (_loc, "Int64")),
                          (`Lid (_loc, "to_string")))), e) in
               (`App
                  (_loc, (`Vrn (_loc, "Int64")),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`chr",_,_) ->
               let e: FAst.exp =
                 `App
                   (_loc,
                     (`Dot
                        (_loc, (`Uid (_loc, "Char")),
                          (`Lid (_loc, "escaped")))), e) in
               (`App
                  (_loc, (`Vrn (_loc, "Chr")),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`str",_,_) ->
               let e: FAst.exp =
                 `App
                   (_loc,
                     (`Dot
                        (_loc, (`Uid (_loc, "String")),
                          (`Lid (_loc, "escaped")))), e) in
               (`App
                  (_loc, (`Vrn (_loc, "Str")),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`flo",_,_) ->
               let e: FAst.exp =
                 `App (_loc, (`Lid (_loc, "string_of_float")), e) in
               (`App
                  (_loc, (`Vrn (_loc, "Flo")),
                    (`Par (_loc, (`Com (_loc, (mloc _loc), e))))) : FAst.exp )
           | ("`bool",_,_) ->
               (`App
                  (_loc, (`Vrn (_loc, "Lid")),
                    (`Par
                       (_loc,
                         (`Com
                            (_loc, (mloc _loc),
                              (`IfThenElse
                                 (_loc, e, (`Str (_loc, "true")),
                                   (`Str (_loc, "false"))))))))) : FAst.exp )
           | _ -> super#exp e)
      | e -> super#exp e
  end