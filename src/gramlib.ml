open LibUtil


    
let setup_op_parser entry p =
  Fgram.setup_parser entry
    (parser
      | (`KEYWORD x | `SYMBOL x,_loc) when p x  -> {:exp| $lid:x |})

(* [infix_kwds_filter]  *)  
let rec infix_kwds_filter = parser
  | ((`KEYWORD "(", _) as tok); 'xs  ->
      (match xs with parser
      |(`KEYWORD ("or"|"mod"|"land"|"lor"|"lxor"|"lsl"|"lsr"|"asr" as i), _loc);
         (`KEYWORD ")", _); 'xs  ->
           {:stream| (`Lid i, _loc); '(infix_kwds_filter xs) |}
      |  'xs  ->
          {:stream| tok; 'infix_kwds_filter xs |}) 
  |  x; 'xs  ->
      {:stream| x; ' infix_kwds_filter xs |}
  |  -> {:stream||}

  









(* let mk_lang_meta fan_quots fan_quot fan_stru fan_exp fan_clfield fan_ctyp =  *)
(*   EXTEND Fgram GLOBAL: fan_quots fan_quot  fan_stru fan_exp  fan_clfield fan_ctyp  ; *)
(*   fan_quots: *)
(*     ["top" *)
(*        [  L0 [ fan_quot{x}; ";" -> x ]{strs} -> {:exp| begin $list:strs end |} ] ] *)
(*   fan_quot: *)
(*     ["top" *)
(*        [ "lang"; STRING{quot}-> begin      AstQuotation.default:= quot;  unit_literal _loc end  *)
(*        | "lang_at"; STRING{tag}; STRING{quot}->begin *)
(*            eprintf "Set: quotation expander %s at position %s@." quot tag ; *)
(*            AstQuotation.default_at_pos tag quot; *)
(*            unit_literal _loc *)
(*              end *)
(*        | "lang_clear" -> begin *)
(*            AstQuotation.default := ""; *)
(*            Hashtbl.clear AstQuotation.default_tbl; *)
(*            unit_literal _loc *)
(*        end ] ] END; *)
  (* fan_stru:[[STRING{file}; STRING{c} -> stru_of_file (file,c) ] ] *)
  (* fan_exp: [[ STRING{file}; STRING{c}-> exp_of_file (file,c) ]] *)
  (* fan_clfield: [[ STRING{file}; STRING{c}->  clfield_of_file (file,c) ]] *)
  (* fan_ctyp: [[STRING{file};STRING{c} ->  ctyp_of_file (file,c) ]] *)


  (* let mk_semi_list nt nts = *)
  (*   with rec_exp *)
  (*   {:extend|Fgram *)
  (*     nts:[ nt{b1};";";S{b2} -> {|$b1;$b2|} | nt{b1};";" -> b1 | nt{b1} -> b1 ] *)
  (*   |}; *)
    
  
(* test wheter revised or not hack*)  
(* let test_pat_lessminus = *)
(*     Fgram.of_parser "test_pat_lessminus" *)
(*       (fun strm -> *)
(*         let rec skip_pat n = *)
(*           match XStream.peek_nth n strm with *)
(*           [ Some (`KEYWORD "<-",_) -> n *)
(*           | Some (`KEYWORD ("[" | "[<"),_) -> *)
(*               skip_pat (ignore_upto "]" (n + 1) + 1) *)
(*           | Some (`KEYWORD "(",_) -> *)
(*               skip_pat (ignore_upto ")" (n + 1) + 1) *)
(*           | Some (`KEYWORD "{",_) -> *)
(*               skip_pat (ignore_upto "}" (n + 1) + 1) *)
(*           | Some (`KEYWORD ("as" | "::" | "," | "_"),_) *)
(*           | Some (`Lid _ | `Uid _, _) -> skip_pat (n + 1) *)
(*           | Some _ | None -> raise XStream.Failure ] *)
(*         and ignore_upto end_kwd n = *)
(*           match XStream.peek_nth n strm with *)
(*           [ Some (`KEYWORD prm,_) when prm = end_kwd -> n *)
(*           | Some (`KEYWORD ("[" | "[<"),_) -> *)
(*               ignore_upto end_kwd (ignore_upto "]" (n + 1) + 1) *)
(*           | Some (`KEYWORD "(",_) -> *)
(*               ignore_upto end_kwd (ignore_upto ")" (n + 1) + 1) *)
(*           | Some (`KEYWORD "{",_) -> *)
(*               ignore_upto end_kwd (ignore_upto "}" (n + 1) + 1) *)
(*           | Some _ -> ignore_upto end_kwd (n + 1) *)
(*           | None -> raise XStream.Failure ] *)
(*         in *)
(*         skip_pat 1); *)

