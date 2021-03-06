

(** The front-end of Fan's gram DDSL *)

  
open FAst

(**
   {[
    with str t nonterminals {| U a b c d|}
    |> Ast2pt.print_stru f;
    let a = U.mk "a"
    let b = U.mk "b"
    let c = U.mk "c"
    let d = U.mk "d"]}
    It is very simple, may be improved to a depend on a simple engine
    It is used by DDSL [create]
 *)  
val nonterminals : stru Fgram.t

(** {[
     with str t nonterminalsclear {| U a b c d|} |> Ast2pt.print_exp f;
     U.clear a; U.clear b; U.clear c; U.clear d
    ]}
    It's used by DDSL [clear]   
 *)    
val nonterminalsclear : exp Fgram.t
val delete_rule_header : vid Fgram.t


(**  parse the header, return the current [grammar] and
     previous module name, it has side effect, and can not
     be used alone
     {[
     with str t extend_header {| U.M |};
     - : FAst.ident option * FAst.ident = (None, `Uid (, "Fgram"))
     with str t extend_header {| U |};
     - : FAst.ident option * FAst.ident =
     (None, `Dot (, `Uid (, "U"), `Uid (, "M")))
     with str t extend_header {| (g:U.t) |};
     - : FAst.ident option * FAst.ident = (Some (`Lid (, "g")), `Uid (, "U"))
     ]}
     It should be fixed by introducing more advanced grammar features *)    
val extend_header : (vid option * vid) Fgram.t
    
val qualuid : vid Fgram.t


(** parse qualified  [X.Y.g]
     {[
     with str t qualid {| A.B.g |};
     - : FAst.ident = `Dot (, `Uid (, "A"), `Dot (, `Uid (, "B"), `Lid (, "g")))
     ]} *)

val qualid : vid Fgram.t

(** parse qualified path ending with [X.t]
     {[
     with str t t_qualid {| A.U.t |};
     - : FAst.ident = `Dot (, `Uid (, "A"), `Uid (, "U"))
     ]} *)
val t_qualid : vid Fgram.t
    
val entry_name :
    ([ `name of FToken.name | `non ] * FGramDef.name) Fgram.t


(** return an entry [FGramDef.entry]
  {[with str t entry {| entry:
    [ entry_name{(n,p)}; ":";  OPT position{pos}; level_list{levels}
     -> begin 
     match n with
     |`name old -> AstQuotation.default := old
     | _ -> () ;  
    mk_entry ~name:p ~pos ~levels
    end] |}]}
   *)

val entry : FGramDef.entry Fgram.t




(** parse [position] and translate into [exp] node, fixme,
    delay the translation *)    
val position : exp Fgram.t

(** parse association, and translate into [exp] node. FIXME  *)    
val assoc : exp Fgram.t
val name : FGramDef.name Fgram.t
val string : exp Fgram.t

val simple_exp : exp Fgram.t
val delete_rules : exp Fgram.t

val pattern : FGramDef.action_pattern Fgram.t




(** return symbol with patterns (may override inferred patterns) *)
val psymbol : FGramDef.symbol Fgram.t
    
(** return symbol with pattern(inferred) or None  *)    
val symbol :  FGramDef.symbol Fgram.t

(** return a [rule]
    {[with str t rule {|  `Uid ("LA"|"RA"|"NA" as x)   |};
    - : FGramDef.rule =
     {prod =
     [{text =
     `Stok
     (,
     `Fun
     (,
     `Bar
     (,
     `Case
     (,
     `App
     (, `Vrn (, "Uid"),
     `Bar
     (, `Bar (, `Str (, "LA"), `Str (, "RA")), `Str (, "NA"))),
     `Nil , `Id (, `Lid (, "true"))),
     `Case (, `Any , `Nil , `Id (, `Lid (, "false"))))),
     "Normal", "`Uid (\"LA\"|\"RA\"|\"NA\")");
     styp = `Tok ;
     pattern =
     Some
     (`App
     (, `Vrn (, "Uid"),
     `Alias
     (, `Bar (, `Bar (, `Str (, "LA"), `Str (, "RA")), `Str (, "NA")),
     `Lid (, "x"))))}];
     action = None}
     ]} *)
val rule :  FGramDef.rule Fgram.t
val rule_list : FGramDef.rule list Fgram.t

val level :  FGramDef.level Fgram.t
val level_list :
    ([ `Group of (FGramDef.level list )
     | `Single of FGramDef.level ]) Fgram.t


(** the main entrance
     return an already converted expession
     {[
     with str t extend_body  {|
     nonterminalsclear:
     [ qualuid{t}; L0 [a_lident{x}->x ]{ls} -> ()] |} |> Ast2pt.print_exp f;

     Fgram.extend (nonterminalsclear : 'nonterminalsclear Fgram.t )
     (None,
     [(None, None,
     [([`Snterm (Fgram.obj (qualuid : 'qualuid Fgram.t ));
     `Slist0
     (Fgram.srules nonterminalsclear
     [([`Snterm (Fgram.obj (a_lident : 'a_lident Fgram.t ))],
     (Fgram.mk_action
     (fun (x : 'a_lident)  (_loc : FLoc.t)  -> (x : 'e__7 ))))])],
     (Fgram.mk_action
     (fun (ls : 'e__7 list)  (t : 'qualuid)  (_loc : FLoc.t)  ->
     (() : 'nonterminalsclear ))))])])
     ]}

     the function [text_of_functorial_extend] is the driving force
     it has type
     {[ FAst.loc ->
     FAst.ident option ->
     FGramDef.name list option -> FGramDef.entry list -> FAst.exp
     ]} *) 
val extend_body : exp Fgram.t
val delete_rule_body : exp Fgram.t

    
