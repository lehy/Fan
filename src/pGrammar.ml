
open FAst
open AstLib
open FanGrammar
open FanGrammarTools
open Syntax
open LibUtil
open FanUtil


FanConfig.antiquotations := true;;



{:create|Gram (nonterminals: stru Gram.t) (nonterminalsclear:  exp Gram.t)
  delete_rule_header extend_header  (qualuid : vid Gram.t) (qualid:vid Gram.t)
  (t_qualid:vid Gram.t )
  (entry_name : ([`name of FanToken.name | `non] * FanGrammar.name) Gram.t )
  locals entry position assoc name string
  rules

  symbol
  rule
  meta_rule
  rule_list
  psymbol
  level
  level_list
  entry

  (pattern: action_pattern Gram.t )
  extend_body
  delete_rule_body
  simple_exp delete_rules
  (simple_pat: simple_pat Gram.t )
  internal_pat|}  ;;


{:extend|Gram

  nonterminals:
  [
   [ "("; qualid{x} ; ":"; t_qualid{t};")" -> `dynamic(x,t)
   |  qualuid{t} -> `static(t) ]{t};
    L1
      [ `Lid x  -> (_loc,x,None,None)
      | "("; `Lid x ;`STR(_,y); ")" ->(_loc,x,Some y,None)
      | "(";`Lid x ;`STR(_,y);ctyp{t};  ")" -> (_loc,x,Some y,Some t)
      | "("; `Lid x; ":"; ctyp{t}; OPT [`STR(_,y) -> y ]{y};  ")" -> (_loc,x,y,Some t) ] {ls}
    ->
    with stru
    let mk =
      match t with
      |`static t -> let t = (t : vid :> exp ) in {:exp| $t.mk |}
      |`dynamic(x,t) ->
          let x = (x : vid :> exp) in
          let t = (t : vid :> exp ) in 
          {:exp|$t.mk_dynamic $x |}  in   
    sem_of_list & List.map
      (fun (_loc,x,descr,ty) ->
        match (descr,ty) with
        |(Some d,None) ->
            {| let $lid:x = $mk $str:d |}
        | (Some d,Some typ) ->
            {| let $lid:x : $typ = $mk $str:d |}
        |(None,None) ->
            {| let $lid:x = $mk $str:x  |}
        | (None,Some typ) ->
            {| let $lid:x : $typ = $mk $str:x  |}  ) ls ]

  nonterminalsclear:
  [ qualuid{t}; L1 [a_lident{x}->x ]{ls} ->
    let rest = List.map (fun (x:alident) ->
      let  x = (x:alident :> exp) in 
      let _loc = loc_of x in
      let t = (t:vid :> exp) in
      {:exp| $t.clear $x |}) ls in
    seq_sem rest ]
|};;


{:extend|Gram


  extend_header:
  [ "("; qualid{i}; ":"; t_qualid{t}; ")" -> 
    let old=gm() in 
    let () = grammar_module_name := t (* (t:vid :> ident) *) in
    (Some i,old)
  | qualuid{t}  ->
      let old = gm() in
      let () = grammar_module_name :=  t (* (t:vid :> ident) *) in 
      (None,old)
  | -> (None,gm())]
  extend_body:
  [ extend_header{(gram,old)};  OPT locals{locals}; L1 entry {el} -> 
    let res = text_of_functorial_extend _loc  gram locals el in 
    let () = grammar_module_name := old in
    res      ]

  (*for side effets, parser action *)
  delete_rule_header:
  [ qualuid{g} ->
    let old = gm () in let () = grammar_module_name := g (* (g:vid :> ident) *) in old  ]

  delete_rule_body:
  [ delete_rule_header{old};  L1 delete_rules {es} ->
    begin
      grammar_module_name := old;
      seq_sem es
    end]

  delete_rules:
  [ name{n} ;":"; "["; L1 [ L0 psymbol SEP ";"{sl} -> sl  ] SEP "|" {sls};
    "]" ->
    exp_delete_rule _loc n sls ]

  (* parse qualified [X.X] *)
  qualuid:
  [ `Uid x; ".";  S{xs} -> {:ident'|$uid:x.$xs|}
  | `Uid x -> `Uid(_loc,x) ] 

  qualid:
  [ `Uid x ; "."; S{xs} -> `Dot(_loc,`Uid(_loc,x),xs)
  | `Lid i -> `Lid(_loc,i)]

  t_qualid:
  [ `Uid x; ".";  S{xs} ->
    {:ident'|$uid:x.$xs|}
  | `Uid x; "."; `Lid "t" -> `Uid(_loc,x) ] 



  locals:
  [ `Lid "local"; ":"; L1 name{sl}; ";" -> sl ]

  (* stands for the non-terminal  *)
  name:[ qualid{il} -> mk_name _loc il] 

  (* parse entry name, accept a quotation name setup (FIXME)*)
  entry_name:
  [ qualid{il}; OPT[`STR(_,x)->x]{name} -> 
    (match name with
    | Some x -> (let old = !AstQuotation.default in
      (AstQuotation.default:= FanToken.resolve_name (`Sub [], x);
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
        (match (pos,levels) with
        |(Some {:exp| `Level $_ |},`Group _) ->
            failwithf "For Group levels the position can not be applied to Level"
        | _ -> mk_entry ~name:p ~pos ~levels)
      end
  ]
  position:
  [ `Uid ("First"|"Last" as x ) ->   {:exp| $vrn:x |}
  | `Uid ("Before" | "After" | "Level" as x) ; string{n} ->
      {:exp| $vrn:x  $n |}
  | `Uid x ->
      failwithf
        "%s is not the right position:(First|Last) or (Before|After|Level)" x]

  level_list:
  [ "{"; L1 level {ll}; "}" -> `Group ll
  | level {l} -> `Single l] (* FIXME L1 does not work here *)

  level:
  [  OPT [`STR (_, x)  -> x ]{label};  OPT assoc{assoc}; rule_list{rules} ->
    mk_level ~label ~assoc ~rules ]
  (* FIXME a conflict {:extend|Gram e:  "simple" ["-"; a_FLOAT{s} -> () ] |} *)



  assoc:
  [ `Uid ("LA"|"RA"|"NA" as x) ->     {:exp| $vrn:x |} 
  | `Uid x -> failwithf "%s is not a correct associativity:(LA|RA|NA)" x  ]

  rule_list:
  [ "["; "]" -> []
  | "["; L1 rule SEP "|"{rules}; "]" ->
    retype_rule_list_without_patterns _loc rules ]

  rule:
  [ L0 psymbol SEP ";"{psl}; OPT ["->"; exp{act}-> act]{action} ->
    mk_rule ~prod:psl ~action ]


  psymbol:
  [ symbol{s} ; OPT ["{"; pattern{p} ; "}" -> p ] {p} ->
    match p with
    |Some _ ->
        {(s) with pattern = (p:  action_pattern option :>  pat option) }
    | None -> s  ] 


  symbol:
  [ `Uid ("L0"| "L1" as x); S{s}; OPT [`Uid "SEP"; symbol{t} -> t ]{sep } ->
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
      mk_symbol  ~text:(`Sself _loc)  ~styp:(`Self _loc "S") ~pattern:None
  |`Uid "N" ->
      mk_symbol  ~text:(`Snext _loc)   ~styp:(`Self _loc "N") ~pattern:None
  | `Uid ("FOLD0"|"FOLD1" as x); simple_exp{f}; simple_exp{e}; S{s} ->
    sfold _loc [x] f e s
  |`Uid ("FOLD0"|"FOLD1" as x ); simple_exp{f};
      simple_exp{e}; S{s};`Uid ("SEP" as y);
    symbol{sep}  ->
      sfold ~sep _loc [x;y] f e s  
  | "["; L1 rule SEP "|"{rl}; "]" ->
      let rl = retype_rule_list_without_patterns _loc rl in
      let t = new_type_var () in
      mk_symbol  ~text:(`Srules _loc (mk_srules _loc t rl ""))
        ~styp:({:ctyp'|'$lid:t |} )
        ~pattern:None
  | simple_pat{p} -> 
      let (p,ls) =
        Exp.filter_pat_with_captured_variables
          (p : simple_pat :>pat) in
      (match ls with
      | [] -> mk_tok _loc ~pattern:p (`Tok _loc)
      | (x,y)::ys ->
        let restrict =
          List.fold_left (fun acc (x,y) -> {:exp| $acc && ( $x = $y ) |} )
            {:exp| $x = $y |} ys  in  (* FIXME *)
        mk_tok _loc ~restrict ~pattern:p (`Tok _loc) )
  | `STR (_, s) ->
        mk_symbol  ~text:(`Skeyword _loc s) ~styp:(`Tok _loc) ~pattern:None
  | name{n};  OPT [`Uid "Level"; `STR (_, s) -> s ]{lev} ->
        mk_symbol  ~text:(`Snterm _loc n lev)
          ~styp:({:ctyp'|'$(lid:n.tvar)|}) ~pattern:None
  | `Ant(("nt"|""),s); OPT [`Uid "Level"; `STR (_, s) -> s ]{lev} ->
        let i = parse_ident _loc s in
        let n = mk_name _loc (Id.to_vid i) in (* FIXME  *)
        mk_symbol ~text:(`Snterm _loc n lev)
          ~styp:({:ctyp'|'$(lid:n.tvar)|}) ~pattern:None
  | "("; S{s}; ")" -> s ]

  simple_pat "pat'":
  ["`"; luident{s}  ->  {|$vrn:s|}
  |"`"; luident{v}; `Ant (("" | "anti" as n) ,s) ->
    {| $vrn:v $(mk_anti _loc ~c:"pat" n s)|}
  |"`"; luident{s}; `STR(_,v) -> {| $vrn:s $str:v|}
  |"`"; luident{s}; `Lid x  -> {| $vrn:s $lid:x |}
  |"`"; luident{s}; "_" -> {|$vrn:s _|}
  |"`"; luident{s}; "("; L1 internal_pat SEP ","{v}; ")" ->
    match v with
    | [x] ->  {:pat'| $vrn:s $x |}
    | x::xs ->
        let xs = com_of_list xs in
        {:pat'|$vrn:s ($x,$xs)|}
    | [] -> assert false]
  internal_pat "pat'": (* FIXME such grammar should be deprecated soon*)
  {
   "as"
     [S{p1} ; "as";a_lident{s} -> {| ($p1 as $s) |} ]
     "|"
     [S{p1}; "|"; S{p2}  -> {|$p1 | $p2 |} ]
     "simple"
     [ `STR(_,s) -> {| $str:s|}
     | "_" -> {| _ |}
     | `Lid x   ->  {| $lid:x|}
     | "("; S{p}; ")" -> p] }

  pattern:
  [ `Lid i -> {:pat'| $lid:i |}
  | "_" -> {:pat'| _ |}
  | "("; pattern{p}; ")" -> p
  | "("; pattern{p1}; ","; L1 S SEP ","{ps}; ")"-> tuple_com (p1::ps) ]
      (* {:pat| ($p1, $list:ps)|}] *)
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
    ~name:((d,"delete")) ~entry:delete_rule_body;
  AstQuotation.of_exp
    ~name:((d,"clear")) ~entry:nonterminalsclear;
  AstQuotation.of_stru
    ~name:((d,"create")) ~entry:nonterminals;
  
end;;


(*
  AstQuotation.add_quotation
  (d,"rule") rule
  ~mexp:FanGrammar.Exp.meta_rule
  ~mpat:FanGrammar.Pat.meta_rule
  ~exp_filter:(fun x-> (x :ep :>exp))
  ~pat_filter:(fun x->(x : ep :> pat));

  AstQuotation.add_quotation
  (d,"entry") entry
  ~mexp:FanGrammar.Expr.meta_entry
  ~mpat:FanGrammar.Patt.meta_entry
  ~exp_filter:(fun x-> (x :ep :> exp))
  ~pat_filter:(fun x-> (x :ep :> pat));

  AstQuotation.add_quotation
  (d,"level") level
  ~mexp:FanGrammar.Expr.meta_level
  ~mpat:FanGrammar.Patt.meta_level
  ~exp_filter:(fun x-> (x :ep :> exp))
  ~pat_filter:(fun x-> (x :ep :> pat));

  AstQuotation.add_quotation
  (d,"symbol") psymbol
  ~mexp:FanGrammar.Expr.meta_symbol
  ~mpat:FanGrammar.Patt.meta_symbol
  ~exp_filter:(fun x -> (x :ep :>exp))
  ~pat_filter:(fun x->  (x :ep :>pat));
 *)  






(* let _loc = FanLoc.ghost; *)
(* let u : FanGrammar.entry= {:entry| *)
(*   simple_exp: *)
(*   [ a_lident{i} -> {:exp| $(id:(i:>ident)) |} *)
(*   | "("; exp{e}; ")" -> e ] *)
(* |};   *)
(* let u : FanGrammar.rule = {:rule| *)
(*   a_lident{i} -> print_string i *)
(* |};   *)

(* let u : FanGrammar.symbol = {:symbol| *)
(*   "x" *)
(* |}; *)
















