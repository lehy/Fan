open Format

open FAst

open LibUtil

let with_open_out_file x f =
  match x with
  | Some file ->
      let oc = open_out_bin file in begin f oc; flush oc; close_out oc end
  | None  ->
      begin set_binary_mode_out stdout true; f stdout; flush stdout end

let sigi_printer =
  ref
    (fun ?input_file:_  ?output_file:_  _  -> failwith "No interface printer")

let stru_printer =
  ref
    (fun ?input_file:_  ?output_file:_  _  ->
       failwith "No implementation printer")

type 'a parser_fun = loc -> char XStream.t -> 'a option 

type 'a printer_fun =
  ?input_file:string -> ?output_file:string -> 'a option -> unit 

let register_text_printer () =
  let print_implem ?input_file:_  ?output_file  ast =
    let pt = match ast with | None  -> [] | Some ast -> Ast2pt.stru ast in
    with_open_out_file output_file
      (fun oc  ->
         let fmt = Format.formatter_of_out_channel oc in
         let () = AstPrint.structure fmt pt in pp_print_flush fmt ()) in
  let print_interf ?input_file:_  ?output_file  ast =
    let pt = match ast with | None  -> [] | Some ast -> Ast2pt.sigi ast in
    with_open_out_file output_file
      (fun oc  ->
         let fmt = Format.formatter_of_out_channel oc in
         let () = AstPrint.signature fmt pt in pp_print_flush fmt ()) in
  begin stru_printer := print_implem; sigi_printer := print_interf end

let dump_pt magic fname pt oc =
  begin
    output_string oc magic;
    output_value oc (if fname = "-" then "" else fname); output_value oc pt
  end

let register_bin_printer () =
  let print_interf ?(input_file= "-")  ?output_file  ast =
    let pt = match ast with | None  -> [] | Some ast -> Ast2pt.sigi ast in
    with_open_out_file output_file
      (dump_pt FConfig.ocaml_ast_intf_magic_number input_file pt) in
  let print_implem ?(input_file= "-")  ?output_file  ast =
    let pt = match ast with | None  -> [] | Some ast -> Ast2pt.stru ast in
    with_open_out_file output_file
      (dump_pt FConfig.ocaml_ast_impl_magic_number input_file pt) in
  begin stru_printer := print_implem; sigi_printer := print_interf end

let wrap directive_handler pa init_loc cs =
  let rec loop loc =
    let (pl,stopped_at_directive) = pa loc cs in
    match stopped_at_directive with
    | Some new_loc ->
        let pl =
          match List.rev pl with
          | [] -> []
          | x::xs ->
              (match directive_handler x with
               | None  -> xs
               | Some x -> x :: xs) in
        (List.rev pl) @ (loop (FLoc.join_end new_loc))
    | None  -> pl in
  loop init_loc

let simple_wrap pa init_loc cs =
  let rec loop loc =
    let (pl,stopped_at_directive) = pa loc cs in
    match stopped_at_directive with
    | Some new_loc ->
        if pl = []
        then loop (FLoc.join_end new_loc)
        else pl @ (loop (FLoc.join_end new_loc))
    | None  -> pl in
  loop init_loc

let parse_implem loc cs =
  let l = simple_wrap (Fgram.parse Fsyntax.implem) loc cs in
  match l with | [] -> None | l -> Some (AstLib.sem_of_list l)

let parse_interf loc cs =
  let l = simple_wrap (Fgram.parse Fsyntax.interf) loc cs in
  match l with | [] -> None | l -> Some (AstLib.sem_of_list l)

let parse_file name pa =
  let loc = FLoc.mk name in
  let print_warning = eprintf "%a:\n%s@." FLoc.print in
  let () = Fsyntax.current_warning := print_warning in
  let ic = if name = "-" then stdin else open_in_bin name in
  let clear () = if name = "-" then () else close_in ic in
  let cs = XStream.of_channel ic in finally ~action:clear (pa loc) cs

module CurrentPrinter =
  struct
    let print_interf ?input_file  ?output_file  ast =
      sigi_printer.contents ?input_file ?output_file ast
    let print_implem ?input_file  ?output_file  ast =
      stru_printer.contents ?input_file ?output_file ast
  end

let wrap parse_fun ~print_location  lb =
  try
    let token_stream = (lb |> FLexLib.from_lexbuf) |> Fgram.filter in
    let (__strm :_ XStream.t)= token_stream in
    match XStream.peek __strm with
    | Some (`EOI,_) -> begin XStream.junk __strm; raise End_of_file end
    | _ -> parse_fun token_stream
  with
  | End_of_file |Sys.Break |FLoc.Exc_located (_,(End_of_file |Sys.Break )) as
      x -> raise x
  | FLoc.Exc_located (loc,y) ->
      begin
        Format.eprintf "@[<0>%a%s@]@." print_location loc
          (Printexc.to_string y);
        raise Exit
      end
  | x ->
      begin
        Format.eprintf "@[<0>%s@]@." (Printexc.to_string x); raise Exit
      end

let toplevel_phrase token_stream =
  match Fgram.parse_origin_tokens Fsyntax.top_phrase token_stream with
  | Some stru ->
      let stru = AstFilters.apply_implem_filters stru in Ast2pt.phrase stru
  | None  -> raise End_of_file

let use_file token_stream =
  let loop () =
    let (pl,stopped_at_directive) =
      Fgram.parse_origin_tokens Fsyntax.implem token_stream in
    if stopped_at_directive <> None
    then match pl with | _ -> (pl, false)
    else (pl, true) in
  let (pl0,eoi) = loop () in
  let pl =
    if eoi
    then []
    else
      (let rec loop () =
         let (pl,stopped_at_directive) =
           Fgram.parse_origin_tokens Fsyntax.implem token_stream in
         if stopped_at_directive <> None then pl @ (loop ()) else pl in
       loop ()) in
  List.map (fun x  -> Ast2pt.phrase (AstFilters.apply_implem_filters x))
    (pl0 @ pl)