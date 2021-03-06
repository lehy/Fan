open FAst

open FanOps

open Format

open AstLib

open LibUtil

open FGramDef

let print_warning = eprintf "%a:\n%s@." FLoc.print

let prefix = "__fan_"

let ghost = FLoc.ghost

let grammar_module_name = ref (`Uid (ghost, "Fgram"))

let gm () =
  (match FConfig.compilation_unit.contents with
   | Some "Fgram" -> `Uid (ghost, "")
   | Some _|None  -> grammar_module_name.contents : vid )

let mk_entry ~local  ~name  ~pos  ~levels  = { name; pos; levels; local }

let mk_level ~label  ~assoc  ~rules  = { label; assoc; rules }

let mk_rule ~prod  ~action  = { prod; action }

let mk_symbol ?(pattern= None)  ~text  ~styp  = { text; styp; pattern }

let check_not_tok s =
  match s with
  | { text = `Stok (_loc,_,_);_} ->
      FLoc.raise _loc
        (XStream.Error
           ("Deprecated syntax, use a sub rule. " ^
              "L0 STRING becomes L0 [ x = STRING -> x ]"))
  | _ -> ()

let new_type_var =
  let i = ref 0 in
  fun ()  -> begin incr i; "e__" ^ (string_of_int i.contents) end

let gensym = let i = ref 0 in fun ()  -> begin incr i; i end

let gen_lid () = prefix ^ (string_of_int (gensym ()).contents)

let retype_rule_list_without_patterns _loc rl =
  try
    List.map
      (function
       | { prod = ({ pattern = None ; styp = `Tok _;_} as s)::[];
           action = None  } ->
           {
             prod =
               [{ s with pattern = (Some (`Lid (_loc, "x") : FAst.pat )) }];
             action =
               (Some
                  (`App
                     (_loc,
                       (`Dot
                          (_loc, (gm ()), (`Lid (_loc, "string_of_token")))),
                       (`Lid (_loc, "x"))) : FAst.exp ))
           }
       | { prod = ({ pattern = None ;_} as s)::[]; action = None  } ->
           {
             prod =
               [{ s with pattern = (Some (`Lid (_loc, "x") : FAst.pat )) }];
             action = (Some (`Lid (_loc, "x") : FAst.exp ))
           }
       | { prod = []; action = Some _ } as r -> r
       | _ -> raise Exit) rl
  with | Exit  -> rl

let make_ctyp (styp : styp) tvar =
  (let rec aux v =
     match (v : styp ) with
     | #vid' as x -> (x : vid'  :>ctyp)
     | `Quote _ as x -> x
     | `App (_loc,t1,t2) -> (`App (_loc, (aux t1), (aux t2)) : FAst.ctyp )
     | `Self _loc ->
         if tvar = ""
         then
           FLoc.raise _loc
             (XStream.Error "S: illegal in anonymous entry level")
         else
           (`Quote (_loc, (`Normal _loc), (`Lid (_loc, tvar))) : FAst.ctyp )
     | `Tok _loc ->
         (`PolySup
            (_loc,
              (`Ctyp
                 (_loc,
                   (`Dot (_loc, (`Uid (_loc, "FToken")), (`Lid (_loc, "t"))))))) : 
         FAst.ctyp )
     | `Type t -> t in
   aux styp : ctyp )

let rec make_exp (tvar : string) (x : text) =
  let rec aux tvar (x : text) =
    match x with
    | `Slist (_loc,min,t,ts) ->
        let txt = aux "" t.text in
        (match ts with
         | None  ->
             if min
             then (`App (_loc, (`Vrn (_loc, "Slist1")), txt) : FAst.exp )
             else (`App (_loc, (`Vrn (_loc, "Slist0")), txt) : FAst.exp )
         | Some s ->
             let x = aux tvar s.text in
             if min
             then
               (`App
                  (_loc, (`Vrn (_loc, "Slist1sep")),
                    (`Par (_loc, (`Com (_loc, txt, x))))) : FAst.exp )
             else
               (`App
                  (_loc, (`Vrn (_loc, "Slist0sep")),
                    (`Par (_loc, (`Com (_loc, txt, x))))) : FAst.exp ))
    | `Sself _loc -> (`Vrn (_loc, "Sself") : FAst.exp )
    | `Skeyword (_loc,kwd) ->
        (`App (_loc, (`Vrn (_loc, "Skeyword")), (`Str (_loc, kwd))) : 
        FAst.exp )
    | `Snterm (_loc,n,lev) ->
        let obj: FAst.exp =
          `App
            (_loc,
              (`Field (_loc, (gm () : vid  :>exp), (`Lid (_loc, "obj")))),
              (`Constraint
                 (_loc, (n.exp),
                   (`App
                      (_loc,
                        (`Dot
                           (_loc, (gm () : vid  :>ident), (`Lid (_loc, "t")))),
                        (`Quote
                           (_loc, (`Normal _loc), (`Lid (_loc, (n.tvar)))))))))) in
        (match lev with
         | Some lab ->
             (`App
                (_loc, (`Vrn (_loc, "Snterml")),
                  (`Par (_loc, (`Com (_loc, obj, (`Str (_loc, lab))))))) : 
             FAst.exp )
         | None  ->
             if n.tvar = tvar
             then (`Vrn (_loc, "Sself") : FAst.exp )
             else (`App (_loc, (`Vrn (_loc, "Snterm")), obj) : FAst.exp ))
    | `Sopt (_loc,t) ->
        (`App (_loc, (`Vrn (_loc, "Sopt")), (aux "" t)) : FAst.exp )
    | `Stry (_loc,t) ->
        (`App (_loc, (`Vrn (_loc, "Stry")), (aux "" t)) : FAst.exp )
    | `Speek (_loc,t) ->
        (`App (_loc, (`Vrn (_loc, "Speek")), (aux "" t)) : FAst.exp )
    | `Stok (_loc,match_fun,descr) ->
        let v =
          object 
            inherit  FanAstN.meta
            method! ant _loc x =
              match x with
              | `Ant (_loc,{ FanUtil.content = x;_}) ->
                  (`App (_loc, (`Vrn (_loc, "Str")), (`Lid (_loc, x))) : 
                  FAst.ep )
          end in
        let descr' = Objs.strip_pat (descr :>pat) in
        let mdescr = (v#pat _loc descr' :>exp) in
        let mstr = FGramDef.string_of_simple_pat descr in
        (`App
           (_loc, (`Vrn (_loc, "Stoken")),
             (`Par
                (_loc,
                  (`Com
                     (_loc, match_fun,
                       (`Com (_loc, mdescr, (`Str (_loc, mstr))))))))) : 
          FAst.exp ) in
  aux tvar x
and make_exp_rules (_loc : loc) (rl : (text list * exp * exp option) list)
  (tvar : string) =
  list_of_list _loc
    (List.map
       (fun (sl,action,raw)  ->
          let action_string =
            match raw with | None  -> "" | Some e -> Ast2pt.to_string_exp e in
          let sl =
            list_of_list _loc (List.map (fun t  -> make_exp tvar t) sl) in
          (`Par
             (_loc,
               (`Com
                  (_loc, sl,
                    (`Par
                       (_loc,
                         (`Com (_loc, (`Str (_loc, action_string)), action))))))) : 
            FAst.exp )) rl)

let text_of_action (_loc : loc) (psl : symbol list)
  ?action:(act : exp option)  (rtvar : string) (tvar : string) =
  (let locid: FAst.pat = `Lid (_loc, (FLoc.name.contents)) in
   let act = Option.default (`Uid (_loc, "()") : FAst.exp ) act in
   let (_,tok_match_pl) =
     List.fold_lefti
       (fun i  ((oe,op) as ep)  x  ->
          match x with
          | { pattern = Some p; text = `Stok _;_} ->
              let id = prefix ^ (string_of_int i) in
              (((`Lid (_loc, id) : FAst.exp ) :: oe), (p :: op))
          | _ -> ep) ([], []) psl in
   let e =
     let e1: FAst.exp =
       `Constraint
         (_loc, act, (`Quote (_loc, (`Normal _loc), (`Lid (_loc, rtvar))))) in
     match tok_match_pl with
     | ([],_) ->
         (`Fun
            (_loc,
              (`Case
                 (_loc,
                   (`Constraint
                      (_loc, locid,
                        (`Dot
                           (_loc, (`Uid (_loc, "FLoc")), (`Lid (_loc, "t")))))),
                   e1))) : FAst.exp )
     | (e,p) ->
         let (exp,pat) =
           match (e, p) with
           | (x::[],y::[]) -> (x, y)
           | _ -> ((tuple_com e), (tuple_com p)) in
         let action_string = Ast2pt.to_string_exp act in
         (`Fun
            (_loc,
              (`Case
                 (_loc,
                   (`Constraint
                      (_loc, locid,
                        (`Dot
                           (_loc, (`Uid (_loc, "FLoc")), (`Lid (_loc, "t")))))),
                   (`Match
                      (_loc, exp,
                        (`Bar
                           (_loc, (`Case (_loc, pat, e1)),
                             (`Case
                                (_loc, (`Any _loc),
                                  (`App
                                     (_loc, (`Lid (_loc, "failwith")),
                                       (`Str
                                          (_loc,
                                            (String.escaped action_string)))))))))))))) : 
           FAst.exp ) in
   let (_,txt) =
     List.fold_lefti
       (fun i  txt  s  ->
          match s.pattern with
          | Some (`Alias (_loc,`App (_,_,`Par (_,(`Any _ : FAst.pat))),p)) ->
              let p = typing (p : alident  :>pat) (make_ctyp s.styp tvar) in
              (`Fun (_loc, (`Case (_loc, p, txt))) : FAst.exp )
          | Some p when is_irrefut_pat p ->
              let p = typing p (make_ctyp s.styp tvar) in
              (`Fun (_loc, (`Case (_loc, p, txt))) : FAst.exp )
          | None  ->
              (`Fun (_loc, (`Case (_loc, (`Any _loc), txt))) : FAst.exp )
          | Some _ ->
              let p =
                typing
                  (`Lid (_loc, (prefix ^ (string_of_int i))) : FAst.pat )
                  (make_ctyp s.styp tvar) in
              (`Fun (_loc, (`Case (_loc, p, txt))) : FAst.exp )) e psl in
   (`App (_loc, (`Dot (_loc, (gm ()), (`Lid (_loc, "mk_action")))), txt) : 
     FAst.exp ) : exp )

let exp_delete_rule _loc n (symbolss : symbol list list) =
  let f _loc n sl =
    let sl = list_of_list _loc (List.map (fun s  -> make_exp "" s.text) sl) in
    ((n.exp : FAst.exp ), sl) in
  let rest =
    List.map
      (fun sl  ->
         let (e,b) = f _loc n sl in
         (`App
            (_loc,
              (`App
                 (_loc, (`Dot (_loc, (gm ()), (`Lid (_loc, "delete_rule")))),
                   e)), b) : FAst.exp )) symbolss in
  match symbolss with
  | [] -> (`Uid (_loc, "()") : FAst.exp )
  | _ -> seq_sem rest

let mk_name _loc (i : vid) =
  let rec aux: vid -> string =
    function
    | `Lid (_,x)|`Uid (_,x) -> x
    | `Dot (_,`Uid (_,x),xs) -> x ^ ("__" ^ (aux xs))
    | _ -> failwith "internal error in the Grammar extension" in
  { exp = (i :>exp); tvar = (aux i); loc = _loc }

let mk_slist loc min sep symb = `Slist (loc, min, symb, sep)

let text_of_entry ?(safe= true)  (e : entry) =
  (let _loc = (e.name).loc in
   let ent =
     let x = e.name in
     (`Constraint
        (_loc, (x.exp),
          (`App
             (_loc,
               (`Dot (_loc, (gm () : vid  :>ident), (`Lid (_loc, "t")))),
               (`Quote (_loc, (`Normal _loc), (`Lid (_loc, (x.tvar)))))))) : 
       FAst.exp ) in
   let pos =
     match e.pos with
     | Some pos -> (`App (_loc, (`Uid (_loc, "Some")), pos) : FAst.exp )
     | None  -> (`Uid (_loc, "None") : FAst.exp ) in
   let apply level =
     let lab =
       match level.label with
       | Some lab ->
           (`App (_loc, (`Uid (_loc, "Some")), (`Str (_loc, lab))) : 
           FAst.exp )
       | None  -> (`Uid (_loc, "None") : FAst.exp ) in
     let ass =
       match level.assoc with
       | Some ass -> (`App (_loc, (`Uid (_loc, "Some")), ass) : FAst.exp )
       | None  -> (`Uid (_loc, "None") : FAst.exp ) in
     let mk_srule loc (t : string) (tvar : string) (r : rule) =
       (let sl = List.map (fun s  -> s.text) r.prod in
        let ac = text_of_action loc r.prod t ?action:(r.action) tvar in
        (sl, ac, (r.action)) : (text list * exp * exp option) ) in
     let mk_srules loc (t : string) (rl : rule list) (tvar : string) =
       List.map (mk_srule loc t tvar) rl in
     let rl = mk_srules _loc (e.name).tvar level.rules (e.name).tvar in
     let prod = make_exp_rules _loc rl (e.name).tvar in
     (`Par (_loc, (`Com (_loc, lab, (`Com (_loc, ass, prod))))) : FAst.exp ) in
   match e.levels with
   | `Single l ->
       if safe
       then
         (`App
            (_loc,
              (`App
                 (_loc,
                   (`Dot (_loc, (gm ()), (`Lid (_loc, "extend_single")))),
                   ent)), (`Par (_loc, (`Com (_loc, pos, (apply l)))))) : 
         FAst.exp )
       else
         (`App
            (_loc,
              (`App
                 (_loc,
                   (`Dot
                      (_loc, (gm ()), (`Lid (_loc, "unsafe_extend_single")))),
                   ent)), (`Par (_loc, (`Com (_loc, pos, (apply l)))))) : 
         FAst.exp )
   | `Group ls ->
       let txt = list_of_list _loc (List.map apply ls) in
       if safe
       then
         (`App
            (_loc,
              (`App
                 (_loc, (`Dot (_loc, (gm ()), (`Lid (_loc, "extend")))), ent)),
              (`Par (_loc, (`Com (_loc, pos, txt))))) : FAst.exp )
       else
         (`App
            (_loc,
              (`App
                 (_loc,
                   (`Dot (_loc, (gm ()), (`Lid (_loc, "unsafe_extend")))),
                   ent)), (`Par (_loc, (`Com (_loc, pos, txt))))) : FAst.exp ) : 
  exp )

let let_in_of_extend _loc (gram : vid option) locals default =
  let entry_mk =
    match gram with
    | Some g ->
        let g = (g : vid  :>exp) in
        (`App (_loc, (`Dot (_loc, (gm ()), (`Lid (_loc, "mk_dynamic")))), g) : 
          FAst.exp )
    | None  -> (`Dot (_loc, (gm ()), (`Lid (_loc, "mk"))) : FAst.exp ) in
  let local_bind_of_name =
    function
    | { exp = (`Lid (_,i) : FAst.exp); tvar = x; loc = _loc } ->
        (`Bind
           (_loc, (`Lid (_loc, i)),
             (`Constraint
                (_loc,
                  (`App
                     (_loc, (`Lid (_loc, "grammar_entry_create")),
                       (`Str (_loc, i)))),
                  (`App
                     (_loc,
                       (`Dot (_loc, (gm () :>ident), (`Lid (_loc, "t")))),
                       (`Quote (_loc, (`Normal _loc), (`Lid (_loc, x))))))))) : 
        FAst.bind )
    | { exp;_} ->
        failwithf "internal error in the Grammar extension %s"
          (Objs.dump_exp exp) in
  match locals with
  | [] -> default
  | ll ->
      let locals = and_of_list (List.map local_bind_of_name ll) in
      (`LetIn
         (_loc, (`Negative _loc),
           (`Bind
              (_loc, (`Lid (_loc, "grammar_entry_create")),
                (`Fun
                   (_loc,
                     (`Case
                        (_loc, (`Lid (_loc, "x")),
                          (`App (_loc, entry_mk, (`Lid (_loc, "x")))))))))),
           (`LetIn (_loc, (`Negative _loc), locals, default))) : FAst.exp )

let capture_antiquot =
  object 
    inherit  Objs.map as super
    val mutable constraints = ([] : (exp * exp) list )
    method! pat =
      function
      | `Ant (_loc,s) ->
          (match s with
           | { FanUtil.content = code;_} ->
               let cons: FAst.exp = `Lid (_loc, code) in
               let code' = "__fan__" ^ code in
               let cons': FAst.exp = `Lid (_loc, code') in
               let () = constraints <- (cons, cons') :: constraints in
               (`Lid (_loc, code') : FAst.pat ))
      | p -> super#pat p
    method get_captured_variables = constraints
    method clear_captured_variables = constraints <- []
  end

let filter_pat_with_captured_variables pat =
  begin
    capture_antiquot#clear_captured_variables;
    (let pat = capture_antiquot#pat pat in
     let constraints = capture_antiquot#get_captured_variables in
     (pat, constraints))
  end

let text_of_functorial_extend ?safe  _loc gram el =
  let args =
    let el = List.map (text_of_entry ?safe) el in
    match el with | [] -> (`Uid (_loc, "()") : FAst.exp ) | _ -> seq_sem el in
  let locals =
    List.filter_map
      (fun { name; local;_}  -> if local then Some name else None) el in
  let_in_of_extend _loc gram locals args

let token_of_simple_pat _loc (p : simple_pat) =
  let p_pat = (p : simple_pat  :>pat) in
  let (po,ls) = filter_pat_with_captured_variables p_pat in
  match ls with
  | [] ->
      let no_variable = FGramDef.wildcarder#simple_pat p in
      let match_fun =
        let v = (no_variable :>pat) in
        if is_irrefut_pat v
        then
          (`Fun (_loc, (`Case (_loc, v, (`Lid (_loc, "true"))))) : FAst.exp )
        else
          (`Fun
             (_loc,
               (`Bar
                  (_loc, (`Case (_loc, v, (`Lid (_loc, "true")))),
                    (`Case (_loc, (`Any _loc), (`Lid (_loc, "false"))))))) : 
          FAst.exp ) in
      let descr = no_variable in
      let text = `Stok (_loc, match_fun, descr) in
      { text; styp = (`Tok _loc); pattern = (Some p_pat) }
  | (x,y)::ys ->
      let guard =
        List.fold_left
          (fun acc  (x,y)  ->
             (`App
                (_loc, (`App (_loc, (`Lid (_loc, "&&")), acc)),
                  (`App (_loc, (`App (_loc, (`Lid (_loc, "=")), x)), y))) : 
             FAst.exp ))
          (`App (_loc, (`App (_loc, (`Lid (_loc, "=")), x)), y) : FAst.exp )
          ys in
      let match_fun: FAst.exp =
        `Fun
          (_loc,
            (`Bar
               (_loc, (`CaseWhen (_loc, po, guard, (`Lid (_loc, "true")))),
                 (`Case (_loc, (`Any _loc), (`Lid (_loc, "false"))))))) in
      let descr = FGramDef.wildcarder#simple_pat p in
      let text = `Stok (_loc, match_fun, descr) in
      { text; styp = (`Tok _loc); pattern = (Some (Objs.wildcarder#pat po)) }