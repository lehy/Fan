
open FanOps
open AstLib
open Filters

include PreCast

open AstQuotation
open Syntax
open LibUtil
open AstQuotation


let efilter str e =
    let e = exp_filter e in let _loc = loc_of e in
    {:exp|($e : Ast.$lid:str)|}
let pfilter str e =
  let p = pat_filter e in let _loc = loc_of p in {:pat|($p : Ast.$lid:str)|};;


let d = `Absolute ["Fan"; "Lang"]

let _ = begin (* FIXME make the printer more restict later *)
  of_stru_with_filter ~name:(d, "ocaml") ~entry:strus
    ~filter:LangOcaml.filter ;
  of_exp ~name:(d, "fans") ~entry:LangFans.fan_quots;
  of_exp ~name:(d, "save") ~entry:LangSave.save_quot;
  of_stru ~name:(d, "include") ~entry:LangInclude.include_quot
end
    
let d = `Absolute ["Fan"; "Lang"; "Macro"]

let _ = begin 
  of_exp_with_filter ~name:(d, "exp") ~entry:exp
    ~filter:(AstMacros.macro_expander#exp);
  of_clfield_with_filter ~name:(d, "clfield") ~entry:clfield
    ~filter:(AstMacros.macro_expander#clfield);
  of_stru_with_filter ~name:(d, "stru") ~entry:stru
    ~filter:(AstMacros.macro_expander#stru)
end
    
let d = `Absolute ["Fan"; "Lang"; "Meta"]

let _ = begin 
  add_quotation (d, "sigi'") sigi_quot ~mexp:(Filters.me#sigi)
    ~mpat:(Filters.mp#sigi) ~exp_filter ~pat_filter;
  add_quotation (d, "stru'") stru_quot ~mexp:(Filters.me#stru)
    ~mpat:(Filters.mp#stru) ~exp_filter ~pat_filter;
  add_quotation (d, "ctyp'") ctyp_quot ~mexp:(Filters.me#ctyp)
    ~mpat:(Filters.mp#ctyp) ~exp_filter ~pat_filter;
  add_quotation (d, "pat'") pat_quot ~mexp:(Filters.me#pat)
    ~mpat:(Filters.mp#pat) ~exp_filter ~pat_filter;
  add_quotation (d, "exp'") exp_quot ~mexp:(Filters.me#exp)
    ~mpat:(Filters.mp#exp) ~exp_filter ~pat_filter;
  add_quotation (d, "mtyp'") mtyp_quot ~mexp:(Filters.me#mtyp)
    ~mpat:(Filters.mp#mtyp) ~exp_filter ~pat_filter;
  add_quotation (d, "mexp'") mexp_quot ~mexp:(Filters.me#mexp)
    ~mpat:(Filters.mp#mexp) ~exp_filter ~pat_filter;
  add_quotation (d, "cltyp'") cltyp_quot ~mexp:(Filters.me#cltyp)
    ~mpat:(Filters.mp#cltyp) ~exp_filter ~pat_filter;
  add_quotation (d, "clexp'") clexp_quot ~mexp:(Filters.me#clexp)
    ~mpat:(Filters.mp#clexp) ~exp_filter ~pat_filter;
  add_quotation (d, "clsigi'") clsigi_quot ~mexp:(Filters.me#clsigi)
    ~mpat:(Filters.mp#clsigi) ~exp_filter ~pat_filter;
  add_quotation (d, "clfield'") clfield_quot ~mexp:(Filters.me#clfield)
    ~mpat:(Filters.mp#clfield) ~exp_filter ~pat_filter;
  add_quotation (d, "constr'") constr_quot ~mexp:(Filters.me#constr)
    ~mpat:(Filters.mp#constr) ~exp_filter ~pat_filter;
  add_quotation (d, "bind'") bind_quot ~mexp:(Filters.me#bind)
    ~mpat:(Filters.mp#bind) ~exp_filter ~pat_filter;
  add_quotation (d, "rec_exp'") rec_exp_quot ~mexp:(Filters.me#rec_exp)
    ~mpat:(Filters.mp#rec_exp) ~exp_filter ~pat_filter;
  add_quotation (d, "case'") case_quot ~mexp:(Filters.me#case)
    ~mpat:(Filters.mp#case) ~exp_filter ~pat_filter;
  add_quotation (d, "mbind'") mbind_quot ~mexp:(Filters.me#mbind)
    ~mpat:(Filters.mp#mbind) ~exp_filter ~pat_filter;
  add_quotation (d, "ident'") ident_quot ~mexp:(Filters.me#ident)
    ~mpat:(Filters.mp#ident) ~exp_filter ~pat_filter;
  add_quotation (d, "rec_flag'") rec_flag_quot ~mexp:(Filters.me#flag)
    ~mpat:(Filters.mp#flag) ~exp_filter ~pat_filter;
  add_quotation (d, "private_flag'") private_flag_quot
    ~mexp:(Filters.me#flag) ~mpat:(Filters.mp#flag)
    ~exp_filter ~pat_filter;
  add_quotation (d, "row_var_flag'") row_var_flag_quot
    ~mexp:(Filters.me#flag) ~mpat:(Filters.mp#flag)
    ~exp_filter ~pat_filter;
  add_quotation (d, "mutable_flag'") mutable_flag_quot
    ~mexp:(Filters.me#flag) ~mpat:(Filters.mp#flag)
    ~exp_filter ~pat_filter;
  add_quotation (d, "virtual_flag'") virtual_flag_quot
    ~mexp:(Filters.me#flag) ~mpat:(Filters.mp#flag)
    ~exp_filter ~pat_filter;
  add_quotation (d, "override_flag'") override_flag_quot
    ~mexp:(Filters.me#flag) ~mpat:(Filters.mp#flag)
    ~exp_filter ~pat_filter;
  add_quotation (d, "direction_flag'") direction_flag_quot
    ~mexp:(Filters.me#flag) ~mpat:(Filters.mp#flag)
    ~exp_filter ~pat_filter;
  add_quotation (d, "or_ctyp'") constructor_declarations
    ~mexp:(Filters.me#or_ctyp) ~mpat:(Filters.me#or_ctyp) ~exp_filter
    ~pat_filter;
  add_quotation (d, "row_field'") row_field ~mexp:(Filters.me#row_field)
    ~mpat:(Filters.mp#row_field) ~exp_filter ~pat_filter
end

let _ = begin
  add_quotation (d, "sigi") sigi_quot ~mexp:(Filters.me#sigi)
    ~mpat:(Filters.mp#sigi) ~exp_filter:(efilter "sigi")
    ~pat_filter:(pfilter "sigi");
  add_quotation (d, "stru") stru_quot ~mexp:(Filters.me#stru)
    ~mpat:(Filters.mp#stru) ~exp_filter:(efilter "stru")
    ~pat_filter:(pfilter "stru");
  add_quotation (d, "ctyp") ctyp_quot ~mexp:(Filters.me#ctyp)
    ~mpat:(Filters.mp#ctyp) ~exp_filter:(efilter "ctyp")
    ~pat_filter:(pfilter "ctyp");
  add_quotation (d, "pat") pat_quot ~mexp:(Filters.me#pat)
    ~mpat:(Filters.mp#pat) ~exp_filter:(efilter "pat")
    ~pat_filter:(pfilter "pat");
  add_quotation (d, "ep") exp_quot ~mexp:(Filters.me#exp)
    ~mpat:(Filters.mp#exp) ~exp_filter:(efilter "ep")
    ~pat_filter:(pfilter "ep");
  add_quotation (d, "exp") exp_quot ~mexp:(Filters.me#exp)
    ~mpat:(Filters.mp#exp) ~exp_filter:(efilter "exp")
    ~pat_filter:(pfilter "exp");
  add_quotation (d, "mtyp") mtyp_quot ~mexp:(Filters.me#mtyp)
    ~mpat:(Filters.mp#mtyp) ~exp_filter:(efilter "mtyp")
    ~pat_filter:(pfilter "mtyp");
  add_quotation (d, "mexp") mexp_quot ~mexp:(Filters.me#mexp)
    ~mpat:(Filters.mp#mexp) ~exp_filter:(efilter "mexp")
    ~pat_filter:(pfilter "mexp");
  add_quotation (d, "cltyp") cltyp_quot ~mexp:(Filters.me#cltyp)
    ~mpat:(Filters.mp#cltyp) ~exp_filter:(efilter "cltyp")
    ~pat_filter:(pfilter "cltyp");
  add_quotation (d, "clexp") clexp_quot ~mexp:(Filters.me#clexp)
    ~mpat:(Filters.mp#clexp) ~exp_filter:(efilter "clexp")
    ~pat_filter:(pfilter "clexp");
  add_quotation (d, "clsigi") clsigi_quot ~mexp:(Filters.me#clsigi)
    ~mpat:(Filters.mp#clsigi) ~exp_filter:(efilter "clsigi")
    ~pat_filter:(pfilter "clsigi");
  add_quotation (d, "clfield") clfield_quot ~mexp:(Filters.me#clfield)
    ~mpat:(Filters.mp#clfield) ~exp_filter:(efilter "clfield")
    ~pat_filter:(pfilter "clfield");
  add_quotation (d, "constr") constr_quot ~mexp:(Filters.me#constr)
    ~mpat:(Filters.mp#constr) ~exp_filter:(efilter "constr")
    ~pat_filter:(pfilter "constr");
  add_quotation (d, "bind") bind_quot ~mexp:(Filters.me#bind)
    ~mpat:(Filters.mp#bind) ~exp_filter:(efilter "bind")
    ~pat_filter:(pfilter "bind");
  add_quotation (d, "rec_exp") rec_exp_quot ~mexp:(Filters.me#rec_exp)
    ~mpat:(Filters.mp#rec_exp) ~exp_filter:(efilter "rec_exp")
    ~pat_filter:(pfilter "rec_exp");
  add_quotation (d, "case") case_quot ~mexp:(Filters.me#case)
    ~mpat:(Filters.mp#case) ~exp_filter:(efilter "case")
    ~pat_filter:(pfilter "case");
  add_quotation (d, "mbind") mbind_quot ~mexp:(Filters.me#mbind)
    ~mpat:(Filters.mp#mbind) ~exp_filter:(efilter "mbind")
    ~pat_filter:(pfilter "mbind");
  add_quotation (d, "ident") ident_quot ~mexp:(Filters.me#ident)
    ~mpat:(Filters.mp#ident) ~exp_filter:(efilter "ident")
    ~pat_filter:(pfilter "ident");
  add_quotation (d, "or_ctyp") constructor_declarations
    ~mexp:(Filters.me#or_ctyp) ~mpat:(Filters.me#or_ctyp)
    ~exp_filter:(efilter "or_ctyp") ~pat_filter:(pfilter "or_ctyp");
  add_quotation (d, "row_field") row_field ~mexp:(Filters.me#row_field)
    ~mpat:(Filters.mp#row_field) ~exp_filter:(efilter "row_field")
    ~pat_filter:(pfilter "row_field");
  of_exp ~name:(d, "with_exp") ~entry:with_exp_lang;
  of_stru ~name:(d, "with_stru") ~entry:with_stru_lang;
  add ((`Absolute ["Fan"; "Lang"]), "str") FanDyn.exp_tag
    (fun _loc  _loc_option  s  -> `Str (_loc, s));
  add ((`Absolute ["Fan"; "Lang"]), "str") FanDyn.stru_tag
    (fun _loc  _loc_option  s  -> `StExp (_loc, (`Str (_loc, s))))
end
let _ =
  Options.add
    ("-dlang",
      (FanArg.String
         (fun s  ->
            AstQuotation.default := (FanToken.resolve_name ((`Sub []), s)))),
      " Set the default language")
open Syntax
{:create|Gram p|};;



{:extend|p:
  [pat{p};"when"; exp{e} -> {:exp| function | $pat:p when $e -> true |_ -> false |}
  |pat{p} -> {:exp'| function | $pat:p -> true | _ -> false |} ]
|};;

of_exp ~name:(d,"p") ~entry:p;;



open ParserRevise

open ParserMacro

open ParserGrammar

open ParserStream;;

(** for stream expression *)
of_exp ~name:(d,"stream") ~entry:ParserStream.stream_exp;;


open AstInjection


open PluginsN (* link the module *)  

open CodeTemplate

open OCamlLex

(* let d = `Absolute ["Fan"; "Lang"; "Meta"; "N"]
   {:stream| 1 ; 2; '(f 3)|}
 *)


(*************************************************************************)
(** begin quotation for Ast without locations *)
let m = new FanAstN.meta ;;

let efilter str e =
    let e = exp_filter_n e in
    let _loc = loc_of e in
    {:exp|($e : AstN.$lid:str)|}
let pfilter str e =
  let p = pat_filter_n e in
  let _loc = loc_of p in
  {:pat|($p : AstN.$lid:str)|};;


begin
    add_quotation (d, "sigi-") sigi_quot ~mexp:(fun loc p -> m#sigi loc (Objs.strip_loc_sigi p))
    ~mpat:(fun loc p -> m#sigi loc (Objs.strip_loc_sigi p))
     ~exp_filter:(efilter "sigi")
    ~pat_filter:(pfilter "sigi");
  add_quotation (d, "stru-") stru_quot ~mexp:(fun loc p -> m#stru loc (Objs.strip_loc_stru p))
    ~mpat:(fun loc p -> m#stru loc (Objs.strip_loc_stru p)) ~exp_filter:(efilter "stru")
    ~pat_filter:(pfilter "stru");
  add_quotation (d, "ctyp-") ctyp_quot ~mexp:(fun loc p -> m#ctyp loc (Objs.strip_loc_ctyp p))
    ~mpat:(fun loc p -> m#ctyp loc (Objs.strip_loc_ctyp p)) ~exp_filter:(efilter "ctyp")
    ~pat_filter:(pfilter "ctyp");
  add_quotation (d, "pat-") pat_quot ~mexp:(fun loc p -> m#pat loc (Objs.strip_loc_pat p))
    ~mpat:(fun loc p -> m#pat loc (Objs.strip_loc_pat p)) ~exp_filter:(efilter "pat")
    ~pat_filter:(pfilter "pat");
  add_quotation (d, "ep-") exp_quot ~mexp:(fun loc p -> m#exp loc (Objs.strip_loc_exp p))
    ~mpat:(fun loc p -> m#exp loc (Objs.strip_loc_exp p)) ~exp_filter:(efilter "ep")
    ~pat_filter:(pfilter "ep");
  add_quotation (d, "exp-") exp_quot
    ~mexp:(fun loc p -> m#exp loc (Objs.strip_loc_exp p))
    ~mpat:(fun loc p -> m#exp loc (Objs.strip_loc_exp p))
    ~exp_filter:(efilter "exp")
    ~pat_filter:(pfilter "exp");
  add_quotation (d, "mtyp-") mtyp_quot ~mexp:(fun loc p -> m#mtyp loc (Objs.strip_loc_mtyp p))
    ~mpat:(fun loc p -> m#mtyp loc (Objs.strip_loc_mtyp p)) ~exp_filter:(efilter "mtyp")
    ~pat_filter:(pfilter "mtyp");
  add_quotation (d, "mexp-") mexp_quot ~mexp:(fun loc p -> m#mexp loc (Objs.strip_loc_mexp p))
    ~mpat:(fun loc p -> m#mexp loc (Objs.strip_loc_mexp p)) ~exp_filter:(efilter "mexp")
    ~pat_filter:(pfilter "mexp");
  add_quotation (d, "cltyp-") cltyp_quot ~mexp:(fun loc p -> m#cltyp loc (Objs.strip_loc_cltyp p))
    ~mpat:(fun loc p -> m#cltyp loc (Objs.strip_loc_cltyp p)) ~exp_filter:(efilter "cltyp")
    ~pat_filter:(pfilter "cltyp");
  add_quotation (d, "clexp-") clexp_quot ~mexp:(fun loc p -> m#clexp loc (Objs.strip_loc_clexp p))
    ~mpat:(fun loc p -> m#clexp loc (Objs.strip_loc_clexp p)) ~exp_filter:(efilter "clexp")
    ~pat_filter:(pfilter "clexp");
  add_quotation (d, "clsigi-") clsigi_quot ~mexp:(fun loc p -> m#clsigi loc (Objs.strip_loc_clsigi p))
    ~mpat:(fun loc p -> m#clsigi loc (Objs.strip_loc_clsigi p)) ~exp_filter:(efilter "clsigi")
    ~pat_filter:(pfilter "clsigi");
  add_quotation (d, "clfield-") clfield_quot ~mexp:(fun loc p -> m#clfield loc (Objs.strip_loc_clfield p))
    ~mpat:(fun loc p -> m#clfield loc (Objs.strip_loc_clfield p)) ~exp_filter:(efilter "clfield")
    ~pat_filter:(pfilter "clfield");
  add_quotation (d, "constr-") constr_quot ~mexp:(fun loc p -> m#constr loc (Objs.strip_loc_constr p))
    ~mpat:(fun loc p -> m#constr loc (Objs.strip_loc_constr p)) ~exp_filter:(efilter "constr")
    ~pat_filter:(pfilter "constr");
  add_quotation (d, "bind-") bind_quot ~mexp:(fun loc p -> m#bind loc (Objs.strip_loc_bind p))
    ~mpat:(fun loc p -> m#bind loc (Objs.strip_loc_bind p)) ~exp_filter:(efilter "bind")
    ~pat_filter:(pfilter "bind");
  add_quotation (d, "rec_exp-") rec_exp_quot ~mexp:(fun loc p -> m#rec_exp loc (Objs.strip_loc_rec_exp p))
    ~mpat:(fun loc p -> m#rec_exp loc (Objs.strip_loc_rec_exp p)) ~exp_filter:(efilter "rec_exp")
    ~pat_filter:(pfilter "rec_exp");
  add_quotation (d, "case-") case_quot ~mexp:(fun loc p -> m#case loc (Objs.strip_loc_case p))
    ~mpat:(fun loc p -> m#case loc (Objs.strip_loc_case p)) ~exp_filter:(efilter "case")
    ~pat_filter:(pfilter "case");
  add_quotation (d, "mbind-") mbind_quot ~mexp:(fun loc p -> m#mbind loc (Objs.strip_loc_mbind p))
    ~mpat:(fun loc p -> m#mbind loc (Objs.strip_loc_mbind p)) ~exp_filter:(efilter "mbind")
    ~pat_filter:(pfilter "mbind");
  add_quotation (d, "ident-") ident_quot ~mexp:(fun loc p -> m#ident loc (Objs.strip_loc_ident p))
    ~mpat:(fun loc p -> m#ident loc (Objs.strip_loc_ident p)) ~exp_filter:(efilter "ident")
    ~pat_filter:(pfilter "ident");
  add_quotation (d, "or_ctyp-") constructor_declarations
    ~mexp:(fun loc p -> m#or_ctyp loc (Objs.strip_loc_or_ctyp p)) ~mpat:(fun loc p -> m#or_ctyp loc (Objs.strip_loc_or_ctyp p))
    ~exp_filter:(efilter "or_ctyp") ~pat_filter:(pfilter "or_ctyp");
  add_quotation (d, "row_field-") row_field ~mexp:(fun loc p -> m#row_field loc (Objs.strip_loc_row_field p))
    ~mpat:(fun loc p -> m#row_field loc (Objs.strip_loc_row_field p)) ~exp_filter:(efilter "row_field")
    ~pat_filter:(pfilter "row_field");
end;;


let exp_filter = exp_filter_n in
let pat_filter = pat_filter_n in
begin
    add_quotation (d, "sigi-'") sigi_quot ~mexp:(fun loc p -> m#sigi loc (Objs.strip_loc_sigi p))
    ~mpat:(fun loc p -> m#sigi loc (Objs.strip_loc_sigi p))
     ~exp_filter
    ~pat_filter;
  add_quotation (d, "stru-'") stru_quot ~mexp:(fun loc p -> m#stru loc (Objs.strip_loc_stru p))
    ~mpat:(fun loc p -> m#stru loc (Objs.strip_loc_stru p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "ctyp-'") ctyp_quot ~mexp:(fun loc p -> m#ctyp loc (Objs.strip_loc_ctyp p))
    ~mpat:(fun loc p -> m#ctyp loc (Objs.strip_loc_ctyp p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "pat-'") pat_quot ~mexp:(fun loc p -> m#pat loc (Objs.strip_loc_pat p))
    ~mpat:(fun loc p -> m#pat loc (Objs.strip_loc_pat p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "ep-'") exp_quot ~mexp:(fun loc p -> m#exp loc (Objs.strip_loc_exp p))
    ~mpat:(fun loc p -> m#exp loc (Objs.strip_loc_exp p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "exp-'") exp_quot
    ~mexp:(fun loc p -> m#exp loc (Objs.strip_loc_exp p))
    ~mpat:(fun loc p -> m#exp loc (Objs.strip_loc_exp p))
    ~exp_filter
    ~pat_filter;
  add_quotation (d, "mtyp-'") mtyp_quot ~mexp:(fun loc p -> m#mtyp loc (Objs.strip_loc_mtyp p))
    ~mpat:(fun loc p -> m#mtyp loc (Objs.strip_loc_mtyp p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "mexp-'") mexp_quot ~mexp:(fun loc p -> m#mexp loc (Objs.strip_loc_mexp p))
    ~mpat:(fun loc p -> m#mexp loc (Objs.strip_loc_mexp p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "cltyp-'") cltyp_quot ~mexp:(fun loc p -> m#cltyp loc (Objs.strip_loc_cltyp p))
    ~mpat:(fun loc p -> m#cltyp loc (Objs.strip_loc_cltyp p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "clexp-'") clexp_quot ~mexp:(fun loc p -> m#clexp loc (Objs.strip_loc_clexp p))
    ~mpat:(fun loc p -> m#clexp loc (Objs.strip_loc_clexp p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "clsigi-'") clsigi_quot ~mexp:(fun loc p -> m#clsigi loc (Objs.strip_loc_clsigi p))
    ~mpat:(fun loc p -> m#clsigi loc (Objs.strip_loc_clsigi p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "clfield-'") clfield_quot ~mexp:(fun loc p -> m#clfield loc (Objs.strip_loc_clfield p))
    ~mpat:(fun loc p -> m#clfield loc (Objs.strip_loc_clfield p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "constr-'") constr_quot ~mexp:(fun loc p -> m#constr loc (Objs.strip_loc_constr p))
    ~mpat:(fun loc p -> m#constr loc (Objs.strip_loc_constr p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "bind-'") bind_quot ~mexp:(fun loc p -> m#bind loc (Objs.strip_loc_bind p))
    ~mpat:(fun loc p -> m#bind loc (Objs.strip_loc_bind p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "rec_exp-'") rec_exp_quot ~mexp:(fun loc p -> m#rec_exp loc (Objs.strip_loc_rec_exp p))
    ~mpat:(fun loc p -> m#rec_exp loc (Objs.strip_loc_rec_exp p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "case-'") case_quot ~mexp:(fun loc p -> m#case loc (Objs.strip_loc_case p))
    ~mpat:(fun loc p -> m#case loc (Objs.strip_loc_case p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "mbind-'") mbind_quot ~mexp:(fun loc p -> m#mbind loc (Objs.strip_loc_mbind p))
    ~mpat:(fun loc p -> m#mbind loc (Objs.strip_loc_mbind p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "ident-'") ident_quot ~mexp:(fun loc p -> m#ident loc (Objs.strip_loc_ident p))
    ~mpat:(fun loc p -> m#ident loc (Objs.strip_loc_ident p)) ~exp_filter
    ~pat_filter;
  add_quotation (d, "or_ctyp-'") constructor_declarations
    ~mexp:(fun loc p -> m#or_ctyp loc (Objs.strip_loc_or_ctyp p)) ~mpat:(fun loc p -> m#or_ctyp loc (Objs.strip_loc_or_ctyp p))
    ~exp_filter ~pat_filter;
  add_quotation (d, "row_field-'") row_field ~mexp:(fun loc p -> m#row_field loc (Objs.strip_loc_row_field p))
    ~mpat:(fun loc p -> m#row_field loc (Objs.strip_loc_row_field p)) ~exp_filter
    ~pat_filter
end
;;
AstParsers.use_parsers
    [ "revise";
      "stream";
      "macro";
      (* "ListComprehension" *)
    ];;

MakeBin.main ();;
