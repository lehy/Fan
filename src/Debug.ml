(****************************************************************************)
(*                                                                          *)
(*                                   OCaml                                  *)
(*                                                                          *)
(*                            INRIA Rocquencourt                            *)
(*                                                                          *)
(*  Copyright  2006   Institut National de Recherche  en  Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed under   *)
(*  the terms of the GNU Library General Public License, with the special   *)
(*  exception on linking described in LICENSE at the top of the OCaml       *)
(*  source tree.                                                            *)
(*                                                                          *)
(****************************************************************************)

(* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)
(* camlp4r *)
open Format;
open FanUtil;
module Debug = struct value mode _ = False; end;

type section = string;

value out_channel =
  try
    let f = Sys.getenv "CAMLP4_DEBUG_FILE" in
    open_out_gen [Open_wronly; Open_creat; Open_append; Open_text]
                 0o666 f
  with
  [ Not_found -> Pervasives.stderr ];



value mode =
  try
    let str = Sys.getenv "CAMLP4_DEBUG" in
    let rec loop acc i =
      try
        let pos = String.index_from str i ':' in
        loop (SSet.add (String.sub str i (pos - i)) acc) (pos + 1)
      with
      [ Not_found ->
          SSet.add (String.sub str i (String.length str - i)) acc ] in
    let sections = loop SSet.empty 0 in
    if SSet.mem "*" sections then fun _ -> True
    else fun x -> SSet.mem x sections
  with [ Not_found -> fun _ -> False ];

value formatter =
  let header = "camlp4-debug: " in
  let at_bol = ref True in
  (make_formatter
    (fun buf pos len ->
       for i = pos to pos + len - 1 do
         if !at_bol then output_string out_channel header else ();
         let ch = buf.[i];
         output_char out_channel ch;
         at_bol.contents := ch = '\n';
       done)
    (fun () -> flush out_channel));

value printf section fmt = fprintf formatter ("%s: " ^^ fmt) section;