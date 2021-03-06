
open FAst
open AstLib
open FGramDef
open FGramGen
open Fsyntax
open LibUtil







{:create|Fgram (nonterminals: stru Fgram.t) (nonterminalsclear:  exp Fgram.t)
  delete_rule_header extend_header  (qualuid : vid Fgram.t) (qualid:vid Fgram.t)
  (t_qualid:vid Fgram.t )
  (entry_name : ([`name of FToken.name | `non] * FGramDef.name) Fgram.t )
   entry position assoc name string rules
  symbol rule meta_rule rule_list psymbol level level_list
  (entry: FGramDef.entry Fgram.t) (pattern: action_pattern Fgram.t )
  extend_body  newterminals  unsafe_extend_body  delete_rule_body
  simple_exp delete_rules |} ;;

{:extend|
  let ty:
  [ "("; qualid{x} ; ":"; t_qualid{t};")" -> `Dyn(x,t)
  |  qualuid{t} -> `Static t
  | -> `Static (`Uid(_loc,"Fgram")) (* Bootstrap*)]    

  nonterminals :
  [ ty {t}; L1 type_entry {ls} ->
    with stru
    let mk =
      match t with
      |`Static t -> let t = (t : vid :> exp ) in {:exp| $t.mk |}
      |`Dyn(x,t) ->
          let x = (x : vid :> exp) in
          let t = (t : vid :> exp ) in 
          {:exp|$t.mk_dynamic $x |}  in   
    sem_of_list
      ( List.map
      (fun (_loc,x,descr,ty) ->
        match (descr,ty) with
        |(Some d,None) ->
            {| let $lid:x = $mk $str:d |}
        | (Some d,Some typ) ->
            {| let $lid:x : $typ = $mk $str:d |}
        |(None,None) ->
            {| let $lid:x = $mk $str:x  |}
        | (None,Some typ) ->
            {| let $lid:x : $typ = $mk $str:x  |}  ) ls) ]

  let str : [`STR(_,y) -> y]
      
  let type_entry :
      [ `Lid x  -> (_loc,x,None,None)
      | "("; `Lid x ;`STR(_,y); ")" ->(_loc,x,Some y,None)
      | "(";`Lid x ;`STR(_,y);ctyp{t};  ")" -> (_loc,x,Some y,Some t)
      | "("; `Lid x; ":"; ctyp{t}; OPT str {y};  ")" -> (_loc,x,y,Some t) ]

  newterminals :
  [ "("; qualid{x}; ":";t_qualid{t};")"; L1 type_entry {ls}
    ->
      
      let mk  =
        let x = (x : vid :> exp) in
        {:exp|$id:t.mk_dynamic $x |}  in
      sem_of_list (* FIXME improve *)
        ({:stru| let $((x:>pat)) = $id:t.create_lexer ~annot:"" ~keywords:[] ()|} ::
         ( List.map
            (fun (_loc,x,descr,ty) ->
              match (descr,ty) with
              |(Some d,None) ->
                  {:stru| let $lid:x = $mk $str:d |}
              | (Some d,Some typ) ->
                  {:stru| let $lid:x : $typ = $mk $str:d |}
              |(None,None) ->
                  {:stru| let $lid:x = $mk $str:x  |}
              | (None,Some typ) ->
                  {:stru| let $lid:x : $typ = $mk $str:x  |}  ) ls)) ]


  
  nonterminalsclear :
  [ qualuid{t}; L1 a_lident {ls} ->
    let rest = List.map (fun (x:alident) ->
      let  x = (x:alident :> exp) in 
      let _loc = loc_of x in
      let t = (t:vid :> exp) in
      {:exp| $t.clear $x |}) ls in
    seq_sem rest ]

  extend_header :
  [ "("; qualid{i}; ":"; t_qualid{t}; ")" -> 
    let old=gm() in 
    let () = grammar_module_name := t  in
    (Some i,old)
  | qualuid{t}  ->
      let old = gm() in
      let () = grammar_module_name :=  t in 
      (None,old)
  | -> (None,gm())]

  extend_body :
  [ extend_header{(gram,old)};   L1 entry {el} -> 
    let res = text_of_functorial_extend _loc  gram  el in 
    let () = grammar_module_name := old in
    res      ]
  (* see [extend_body] *)

  unsafe_extend_body :
  [ extend_header{(gram,old)};   L1 entry {el} -> 
    let res = text_of_functorial_extend ~safe:false _loc  gram  el in 
    let () = grammar_module_name := old in
    res      ]
  (*for side effets, parser action *)
  delete_rule_header:
  [ qualuid{g} ->
    let old = gm () in let () = grammar_module_name := g  in old  ]

  delete_rule_body:
  [ delete_rule_header{old};  L1 delete_rules {es} ->
    begin
      grammar_module_name := old;
      seq_sem es
    end]

  delete_rules:
  [ name{n} ;":"; "["; L1  psymbols SEP "|" {sls};
    "]" ->
    exp_delete_rule _loc n sls ]
  let psymbols:
  [ L0 psymbol SEP ";"{sl} -> sl  ] 
  (* parse qualified [X.X] *)
  qualuid:
  [ `Uid x; ".";  S{xs} -> {:ident'|$uid:x.$xs|}
  | `Uid x -> `Uid(_loc,x) ] 

  qualid:
  [ `Uid x ; "."; S{xs} -> `Dot(_loc,`Uid(_loc,x),xs)
  | `Lid i -> `Lid(_loc,i)]

  t_qualid:
  [ `Uid x; ".";  S{xs} -> {:ident'|$uid:x.$xs|}
  | `Uid x; "."; `Lid "t" -> `Uid(_loc,x) ] 



  
  (* stands for the non-terminal  *)
  name:[ qualid{il} -> mk_name _loc il] 

  (* parse entry name, accept a quotation name setup (FIXME)*)
  entry_name:
  [ qualid{il}; OPT  str {name} -> 
    (match name with
    | Some x -> (let old = !AstQuotation.default in
      (AstQuotation.default:= FToken.resolve_name _loc (`Sub [], x);
       `name old))
    | None -> `non, mk_name _loc il)
  ]

  entry:
  [ entry_name{(n,p)}; ":";  OPT position{pos}; level_list{levels}
    ->
      begin 
        (match n with
        |`name old -> AstQuotation.default := old
        | _ -> ());
        match (pos,levels) with
        |(Some {:exp| `Level $_ |},`Group _) ->
            failwithf "For Group levels the position can not be applied to Level"
        | _ -> mk_entry ~local:false ~name:p ~pos ~levels
      end
  |  "let"; entry_name{(n,p)}; ":";  OPT position{pos}; level_list{levels} ->
      begin
        (match n with
        |`name old -> AstQuotation.default := old
        | _ -> ());
        match (pos,levels) with
        |(Some {:exp| `Level $_ |},`Group _) ->
            failwithf "For Group levels the position can not be applied to Level"
        | _ -> mk_entry ~local:true ~name:p ~pos ~levels
      end
  ]
  position :
  [ `Uid ("First"|"Last" as x ) ->   {:exp| $vrn:x |}
  | `Uid ("Before" | "After" | "Level" as x) ; string{n} ->
      {:exp| $vrn:x  $n |}
  | `Uid x ->
      failwithf
        "%s is not the right position:(First|Last) or (Before|After|Level)" x]

  level_list :
  [ "{"; L1 level {ll}; "}" -> `Group ll
  | level {l} -> `Single l] (* FIXME L1 does not work here *)

  level :
  [  OPT str {label};  OPT assoc{assoc}; rule_list{rules} ->
    mk_level ~label ~assoc ~rules ]
  (* FIXME a conflict {:extend|Fgram e:  "simple" ["-"; a_FLOAT{s} -> () ] |} *)



  assoc :
  [ `Uid ("LA"|"RA"|"NA" as x) ->     {:exp| $vrn:x |} 
  | `Uid x -> failwithf "%s is not a correct associativity:(LA|RA|NA)" x  ]

      
  rule_list :
  [ "["; "]" -> []
  | "["; L1 rule SEP "|"{rules}; "]" ->
    retype_rule_list_without_patterns _loc rules ]

  rule :
  [ L0 psymbol SEP ";"{prod}; OPT opt_action{action} ->
    mk_rule ~prod ~action ]
  let opt_action : ["->"; exp{act}-> act]

  pattern :
  [ `Lid i -> {:pat'| $lid:i |}
  | "_" -> {:pat'| _ |}
  | "("; pattern{p}; ")" -> p
  | "("; pattern{p1}; ","; L1 S SEP ","{ps}; ")"-> tuple_com (p1::ps) ]
      
  let brace_pattern : ["{";pattern{p};"}"->p]

  psymbol :
  [ symbol{s} ; OPT  brace_pattern {p} ->
    match p with
    |Some _ ->
        { s with pattern = (p:  action_pattern option :>  pat option) }
    | None -> s  ] 

  let sep_symbol : [`Uid "SEP"; symbol{t}->t]
  let level_str :  [`Uid "Level"; `STR (_, s) -> s ]
  symbol:
  [ `Uid ("L0"| "L1" as x); S{s}; OPT  sep_symbol{sep } ->
    let () = check_not_tok s in
    let styp = {:ctyp'| $(s.styp) list   |} in 
    let text = mk_slist _loc
        (match x with
        |"L0" -> false | "L1" -> true
        | _ -> failwithf "only (L0|L1) allowed here") sep s in
    mk_symbol ~text ~styp ~pattern:None
  |`Uid "OPT"; S{s}  ->
    let () = check_not_tok s in
    let styp = {:ctyp'|  $(s.styp) option |} in 
    let text = `Sopt _loc s.text in
    mk_symbol  ~text ~styp ~pattern:None
  |`Uid "TRY"; S{s} ->
      let text = `Stry _loc s.text in
      mk_symbol  ~text ~styp:(s.styp) ~pattern:None
  | `Uid "PEEK"; S{s} ->
      let text = `Speek _loc s.text in
      mk_symbol ~text ~styp:(s.styp) ~pattern:None
  | `Uid "S" ->
      mk_symbol  ~text:(`Sself _loc)  ~styp:(`Self _loc ) ~pattern:None
  | simple_pat{p} ->
      token_of_simple_pat _loc p 
  | `STR (_, s) ->
        mk_symbol  ~text:(`Skeyword _loc s) ~styp:(`Tok _loc) ~pattern:None
  | name{n};  OPT level_str{lev} ->
        mk_symbol  ~text:(`Snterm _loc n lev)
          ~styp:({:ctyp'|'$(lid:n.tvar)|}) ~pattern:None
  (* | `Ant(("nt"|""),s); OPT level_str{lev} -> *)
  (*       let i = parse_ident _loc s in *)
  (*       let rec to_vid   (x:ident) : vid = *)
  (*         match x with *)
  (*         |`Apply _ -> failwithf "Id.to_vid" (\* FIXME type system may help*\) *)
  (*         |`Dot(_loc,a,b) -> `Dot(_loc, to_vid a, to_vid b) *)
  (*         | `Lid _ | `Uid _ | `Ant _ as x -> x in  *)
  (*       let n = mk_name _loc (to_vid i) in *)
  (*       mk_symbol ~text:(`Snterm _loc n lev) *)
  (*         ~styp:({:ctyp'|'$(lid:n.tvar)|}) ~pattern:None *)
  | "("; S{s}; ")" -> s ]

 (*  simple_pat "pat'": *)
 (*  ["`"; luident{s}  ->  {|$vrn:s|} *)
 (*  |"`"; luident{v}; `Ant (("" | "anti" as n) ,s) -> *)
 (*    {| $vrn:v $(mk_anti _loc ~c:"pat" n s)|} *)
 (*  |"`"; luident{s}; `STR(_,v) -> {| $vrn:s $str:v|} *)
 (*  |"`"; luident{s}; `Lid x  -> {| $vrn:s $lid:x |} *)
 (*  |"`"; luident{s}; "_" -> {|$vrn:s _|} *)
 (*  |"`"; luident{s}; "("; L1 internal_pat SEP ","{v}; ")" -> *)
 (*      (AstLib.appl_of_list ({:pat'|$vrn:s|} :: v)) *)
 (*        (\* here *)
 (*           we have to guarantee *)
 (*           {[ *)
 (*           {:pat-|`a(a,b,c)|};; *)
 (*           - : FAstN.pat = `App (`App (`App (`Vrn "a", `Lid "a"), `Lid "b"), `Lid "c") *)
 (*           ]} *)
 (*           is dumped correctly *)
 (*         *\) *)
 (* ] *)
 (*  internal_pat "pat'": (\* FIXME such grammar should be deprecated soon*\) *)
 (*  { *)
 (*   "as" *)
 (*     [S{p1} ; "as";a_lident{s} -> {| ($p1 as $s) |} ] *)
 (*     "|" *)
 (*     [S{p1}; "|"; S{p2}  -> {|$p1 | $p2 |} ] *)
 (*     "simple" *)
 (*     [ `STR(_,s) -> {| $str:s|} *)
 (*     | "_" -> {| _ |} *)
 (*     | `Lid x   ->  {| $lid:x|} *)
 (*     | "("; S{p}; ")" -> p] } *)

  

  string:
  [ `STR (_, s) -> {:exp| $str:s |}
  | `Ant ("", s) -> parse_exp _loc s ] (*suport antiquot for string*)



  simple_exp:
  [ a_lident{i} -> (i : alident :>exp) 
  | "("; exp{e}; ")" -> e ]  |};;


let d = `Absolute["Fan";"Lang"] in
begin
  AstQuotation.of_exp
    ~name:((d,  "extend")) ~entry:extend_body;
  AstQuotation.of_exp
    ~name:((d,  "unsafe_extend")) ~entry:unsafe_extend_body;
  AstQuotation.of_stru
    ~name:((d,"create")) ~entry:nonterminals;
  AstQuotation.of_stru
    ~name:((d,"new")) ~entry:newterminals;

  AstQuotation.of_exp
    ~name:((d,"delete")) ~entry:delete_rule_body;
  AstQuotation.of_exp
    ~name:((d,"clear")) ~entry:nonterminalsclear;
end;;


(*
  AstQuotation.add_quotation
  (d,"rule") rule
  ~mexp:FGramDef.Exp.meta_rule
  ~mpat:FGramDef.Pat.meta_rule
  ~exp_filter:(fun x-> (x :ep :>exp))
  ~pat_filter:(fun x->(x : ep :> pat));

  AstQuotation.add_quotation
  (d,"entry") entry
  ~mexp:FGramDef.Expr.meta_entry
  ~mpat:FGramDef.Patt.meta_entry
  ~exp_filter:(fun x-> (x :ep :> exp))
  ~pat_filter:(fun x-> (x :ep :> pat));

  AstQuotation.add_quotation
  (d,"level") level
  ~mexp:FGramDef.Expr.meta_level
  ~mpat:FGramDef.Patt.meta_level
  ~exp_filter:(fun x-> (x :ep :> exp))
  ~pat_filter:(fun x-> (x :ep :> pat));

  AstQuotation.add_quotation
  (d,"symbol") psymbol
  ~mexp:FGramDef.Expr.meta_symbol
  ~mpat:FGramDef.Patt.meta_symbol
  ~exp_filter:(fun x -> (x :ep :>exp))
  ~pat_filter:(fun x->  (x :ep :>pat));
 *)  






(* let _loc = FLoc.ghost; *)
(* let u : FanGrammar.entry= {:entry| *)
(*   simple_exp: *)
(*   [ a_lident{i} -> {:exp| $(id:(i:>ident)) |} *)
(*   | "("; exp{e}; ")" -> e ] *)
(* |};   *)
(* let u : FGramDef.rule = {:rule| *)
(*   a_lident{i} -> print_string i *)
(* |};   *)

(* let u : FGramDef.symbol = {:symbol| *)
(*   "x" *)
(* |}; *)
















