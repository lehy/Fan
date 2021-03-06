
open LibUtil
open FToken


type assoc =
    [ `NA|`RA|`LA]
type position =
    [ `First | `Last | `Before of string | `After of string | `Level of string]



(* the [location] and the parsed value *)
type 'a cont_parse  = FLoc.t -> Gaction.t -> 'a parse 
    
type description = [ `Normal | `Antiquot]


(* open FAst *)

(** Duplication with fGramDef *)  
(* type lident = *)
(*     [ `Lid of (loc * string )] *)
(* and simple_pat = *)
(*   [ *)
(*    `Vrn of (loc * string) *)
(*   |`App of (loc * simple_pat * simple_pat ) *)
(*   | vid (\* contains ant *\) *)
(*   |`Com of (loc * simple_pat * simple_pat) *)
(*   |`Alias of (loc * simple_pat * alident) *)
(*   |`Bar of (loc * simple_pat * simple_pat) *)
(*   |`Str of (loc * string) *)
(*   |`Any of loc] (\* with ("Print" ) *\) *)
  
type descr = (* (description * string)  *)
    FAstN.pat
    (* (FAstN.pat * string) *)
      
      (* ATTENTION: the type system can not guarantee it would compile *)
type token_pattern = ((FToken.t -> bool) * descr * string)

type terminal =
    [ `Skeyword of string
    | `Stoken of token_pattern ]
  
type gram = {
    annot : string;
    gfilter         : FanTokenFilter.t;
    gkeywords :   SSet.t ref;
}

type label =  string option

    
type entry = {
    egram     : gram;
    ename     : string;
    mutable estart    :  int -> Gaction.t parse ;
    mutable econtinue : int -> Gaction.t cont_parse ;
    mutable edesc     :  desc;
    mutable freezed :  bool;}
and desc =
  | Dlevels of level list 
    (* | Dlevel of level  *)
  | Dparser of (stream -> Gaction.t )
and level = {
    lname   : label;
    assoc   : assoc ;
    productions : production list ;
   (* (assoc, lname, production) triple composes
      olevel which can be used by [Ginsert.level_of_olevel]
      to deduce  the whole level *)
    (* the raw productions stored in the level*)
    lsuffix : tree ;
    lprefix : tree}
and asymbol =
  [ `Snterm of entry
  | `Snterml of (entry * string) (* the second argument is the level name *)
  | `Slist0 of symbol
  | `Slist1 of symbol
  | `Sopt of symbol
  | `Stry of symbol
  | `Speek of symbol
  | `Sself
  | `Slist0sep of (symbol * symbol)        
  | `Slist1sep of (symbol * symbol)      
  | terminal ]  
and symbol =
  [
    `Snterm of entry
  | `Snterml of (entry * string) (* the second argument is the level name *)
  | `Slist0 of symbol
  | `Slist0sep of (symbol * symbol)
  | `Slist1 of symbol
  | `Slist1sep of (symbol * symbol)
  | `Sopt of symbol
  | `Stry of symbol
  | `Speek of symbol
  | `Sself
  | terminal
 ]
      
and tree = (* internal struccture *)
  | Node of node
  | LocAct of (* (int*Gaction.t) *)anno_action *  anno_action list (* (int * Action.t) *)
    (* | EarlyAction of Gaction.t and node (\* This action was only used to produce side effect *\) *)
    (* | ReplaceAction of Gaction.t and node  *)
    (* | LocActAppend of anno_action and list anno_action and tree  *)
  | DeadEnd 
and node = {
    node    : symbol ;
    son     : tree   ;
    brother : tree   }
and production= (symbol list  *  (* Gaction.t *) (string * Gaction.t))

(* number * symbols * action_as_tring * action *)
and anno_action = (int  * symbol list  * string  * Gaction.t) 



(* FIXME duplciate with Fgram.mli*)

(**
   [olevel] is the [processed output] from the Fgram DDSL, the runtime representation
   is [level], there is a function [Ginsert.level_of_olevel] which converts the
   processed output into the runtime
 *)      
type olevel = (label * assoc option  * production list )
type extend_statment = (position option  * olevel list )
type single_extend_statement =  (position option  * olevel)
type delete_statment = symbol list 



  
