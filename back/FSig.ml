

open FAst

type vrn =
  | Sum 
  | TyVrnEq
  | TyVrnSup
  | TyVrnInf
  | TyVrnInfSup
  | TyAbstr
      


type trail_info = (vrn*int)

(* [collumn] meta data for the record *)
type col = {
    col_label:string;
    col_mutable:bool;
    col_ctyp:ctyp
  }

(** a series of [partial ast nodes] generated by the type
    suppose the type is [int] which is the same as [ty]
    [fmt;test] is the names as extra arguments
    arity is 2 and i is 3
 *)
type ty_info = {
    name_exp: exp; (*  [meta_int] *)
    info_exp: exp; (* [meta_int fmt test _a3] *)
    ep0: ep; (* _a3*)
    id_ep: ep; (* (_a3,_b3) *)
    id_eps: ep list ; (* [_a3;_b3] *)
    ty: ctyp; (* int *) 
  }


type vbranch =
   [ `variant of (string* ctyp list )
   | `abbrev of ident ]
type branch =
   [ `branch of (string * ctyp list) ]
(* Feed to user to compose an expession node *)
type record_col = {
    re_label: string ;
    re_mutable: bool ;
    re_info: ty_info;
  }
type record_info =  record_col list

(* types below are used to tell fan how to produce
   function of type [ident -> ident]
 *)
type basic_id_transform =
    [ `Pre of string
    | `Post of string
    | `Fun of (string->string) ]

type rhs_basic_id_transform =
    [ basic_id_transform
    | `Exp of string -> exp ]

type full_id_transform =
    [  basic_id_transform
    | `Idents of  vid list  -> vid 
    (* decompose to a list of ident and compose as an ident *)          
    | `Id of vid -> vid
    (* just pass the ident to user do ident transform *)
    | `Last of string -> vid
    (* pass the string, and << .$old$. .$return$. >>  *)      
    | `Obj of  (string -> string) ]

open StdLib
open Objs;;

{:fans|keep on; derive (Print); |};;

{:ocaml|
type named_type = (string* typedecl)
and and_types = named_type list
and types =
    [ `Mutual of and_types
    | `Single of named_type ]

and mtyps =  types list

type destination =
  |Obj of kind
  (* | Type of ctyp         *)
  |Str_item
and kind =
  | Fold
  | Iter (* Iter style *) 
  | Map (* Map style *)
  | Concrete of ctyp


type warning_type =
  | Abstract of string 
  | Qualified of string 
 
  |};;

  
type plugin_name = string 

type plugin = {
    transform:(mtyps -> stru option);
    position: string option ;
    filter: (string->bool) option ;
  }



