open LibUtil

open Format

open Lexing

type lex_error =  
  | Illegal_character of char
  | Illegal_escape of string
  | Illegal_quotation of string
  | Illegal_antiquote
  | Unterminated_comment
  | Unterminated_string
  | Unterminated_quotation
  | Unterminated_antiquot
  | Unterminated_string_in_comment
  | Unterminated_string_in_quotation
  | Unterminated_string_in_antiquot
  | Comment_start
  | Comment_not_end
  | Literal_overflow of string 

exception Lexing_error of lex_error

let print_lex_error ppf e =
  match e with
  | Illegal_antiquote  -> fprintf ppf "Illegal_antiquote"
  | Illegal_character c ->
      fprintf ppf "Illegal character (%s)" (Char.escaped c)
  | Illegal_quotation s ->
      fprintf ppf "Illegal quotation (%s)" (String.escaped s)
  | Illegal_escape s ->
      fprintf ppf "Illegal backslash escape in string or character (%s)" s
  | Unterminated_comment  -> fprintf ppf "Comment not terminated"
  | Unterminated_string  -> fprintf ppf "String literal not terminated"
  | Unterminated_string_in_comment  ->
      fprintf ppf "This comment contains an unterminated string literal"
  | Unterminated_string_in_quotation  ->
      fprintf ppf "This quotation contains an unterminated string literal"
  | Unterminated_string_in_antiquot  ->
      fprintf ppf "This antiquotaion contains an unterminated string literal"
  | Unterminated_quotation  -> fprintf ppf "Quotation not terminated"
  | Unterminated_antiquot  -> fprintf ppf "Antiquotation not terminated"
  | Literal_overflow ty ->
      fprintf ppf
        "Integer literal exceeds the range of representable integers of type %s"
        ty
  | Comment_start  -> fprintf ppf "this is the start of a comment"
  | Comment_not_end  -> fprintf ppf "this is not the end of a comment"

let lex_error_to_string = to_string_of_printer print_lex_error

let _ =
  Printexc.register_printer
    (function | Lexing_error e -> Some (lex_error_to_string e) | _ -> None)

let debug = ref false

let opt_char_len = function | Some _ -> 1 | None  -> 0

let print_opt_char fmt =
  function | Some c -> fprintf fmt "Some %c" c | None  -> fprintf fmt "None"

module Stack =
  struct
    include Stack
    let push v stk =
      begin
        if debug.contents
        then Format.eprintf "Push %a@." print_opt_char v
        else (); push v stk
      end
    let pop stk =
      begin
        if debug.contents
        then Format.eprintf "Pop %a@." print_opt_char (top stk); pop stk
      end
  end

let opt_char: char option Stack.t = Stack.create ()

let turn_on_quotation_debug () = debug := true

let turn_off_quotation_debug () = debug := false

let clear_stack () = Stack.clear opt_char

let show_stack () =
  begin
    eprintf "stack expand to check the error message@.";
    Stack.iter (Format.eprintf "%a@." print_opt_char) opt_char
  end

type context = 
  {
  loc: FLoc.position;
  antiquots: bool;
  lexbuf: lexbuf;
  buffer: Buffer.t} 

let default_context lb =
  {
    loc = FLoc.dummy_pos;
    antiquots = false;
    lexbuf = lb;
    buffer = (Buffer.create 256)
  }

let store c = Buffer.add_string c.buffer (Lexing.lexeme c.lexbuf)

let buff_contents c =
  let contents = Buffer.contents c.buffer in
  begin Buffer.reset c.buffer; contents end

let loc_merge c = FLoc.of_positions c.loc (Lexing.lexeme_end_p c.lexbuf)

let set_start_p c = (c.lexbuf).lex_start_p <- c.loc

let move_curr_p shift c =
  (c.lexbuf).lex_curr_pos <- (c.lexbuf).lex_curr_pos + shift

let move_start_p shift c =
  (c.lexbuf).lex_start_p <- FLoc.move_pos shift (c.lexbuf).lex_start_p

let with_curr_loc lexer c =
  lexer { c with loc = (Lexing.lexeme_start_p c.lexbuf) } c.lexbuf

let store_parse f c = begin store c; f c c.lexbuf end

let mk_quotation quotation c ~name  ~loc  ~shift  ~retract  =
  let old = (c.lexbuf).lex_start_p in
  let s =
    begin
      with_curr_loc quotation c; (c.lexbuf).lex_start_p <- old;
      buff_contents c
    end in
  let contents = String.sub s 0 ((String.length s) - retract) in
  `QUOTATION (name, loc, shift, contents)

let update_loc ?file  ?(absolute= false)  ?(retract= 0)  ?(line= 1)  c =
  let lexbuf = c.lexbuf in
  let pos = lexbuf.lex_curr_p in
  let new_file = match file with | None  -> pos.pos_fname | Some s -> s in
  lexbuf.lex_curr_p <-
    {
      pos with
      pos_fname = new_file;
      pos_lnum = (if absolute then line else pos.pos_lnum + line);
      pos_bol = (pos.pos_cnum - retract)
    }

let err (error : lex_error) (loc : FLoc.t) =
  raise (FLoc.Exc_located (loc, (Lexing_error error)))

let warn error loc =
  Format.eprintf "Warning: %a: %a@." FLoc.print loc print_lex_error error

let rec comment c lexbuf =
  let rec __ocaml_lex_init_lexbuf lexbuf mem_size =
    let pos = lexbuf.Lexing.lex_curr_pos in
    begin
      lexbuf.Lexing.lex_mem <- Array.create mem_size (-1);
      lexbuf.Lexing.lex_start_pos <- pos; lexbuf.Lexing.lex_last_pos <- pos;
      lexbuf.Lexing.lex_last_action <- (-1)
    end
  and __ocaml_lex_next_char lexbuf =
    if lexbuf.Lexing.lex_curr_pos >= lexbuf.Lexing.lex_buffer_len
    then
      (if lexbuf.Lexing.lex_eof_reached
       then 256
       else
         begin
           lexbuf.Lexing.refill_buff lexbuf; __ocaml_lex_next_char lexbuf
         end)
    else
      (let i = lexbuf.Lexing.lex_curr_pos in
       let c = (lexbuf.Lexing.lex_buffer).[i] in
       begin lexbuf.Lexing.lex_curr_pos <- i + 1; Char.code c end)
  and __ocaml_lex_state0 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 10 -> __ocaml_lex_state3 lexbuf
    | 40 -> __ocaml_lex_state6 lexbuf
    | 256 -> __ocaml_lex_state4 lexbuf
    | 42 -> __ocaml_lex_state5 lexbuf
    | 13 -> __ocaml_lex_state2 lexbuf
    | _ -> __ocaml_lex_state1 lexbuf
  and __ocaml_lex_state1 lexbuf = 4
  and __ocaml_lex_state2 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 3;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state3 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state3 lexbuf = 3
  and __ocaml_lex_state4 lexbuf = 2
  and __ocaml_lex_state5 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 4;
      (match __ocaml_lex_next_char lexbuf with
       | 41 -> __ocaml_lex_state8 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state6 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 4;
      (match __ocaml_lex_next_char lexbuf with
       | 42 -> __ocaml_lex_state7 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state7 lexbuf = 0
  and __ocaml_lex_state8 lexbuf = 1 in
  begin
    __ocaml_lex_init_lexbuf lexbuf 0;
    (let __ocaml_lex_result = __ocaml_lex_state0 lexbuf in
     begin
       lexbuf.Lexing.lex_start_p <- lexbuf.Lexing.lex_curr_p;
       lexbuf.Lexing.lex_curr_p <-
         {
           (lexbuf.Lexing.lex_curr_p) with
           Lexing.pos_cnum =
             (lexbuf.Lexing.lex_abs_pos + lexbuf.Lexing.lex_curr_pos)
         };
       (match __ocaml_lex_result with
        | 0 -> begin store c; with_curr_loc comment c; comment c c.lexbuf end
        | 1 -> store c
        | 2 -> err Unterminated_comment (loc_merge c)
        | 3 -> begin update_loc c; store_parse comment c end
        | 4 -> store_parse comment c
        | _ -> failwith "lexing: empty token")
     end)
  end

let rec string c lexbuf =
  let rec __ocaml_lex_init_lexbuf lexbuf mem_size =
    let pos = lexbuf.Lexing.lex_curr_pos in
    begin
      lexbuf.Lexing.lex_mem <- Array.create mem_size (-1);
      lexbuf.Lexing.lex_start_pos <- pos; lexbuf.Lexing.lex_last_pos <- pos;
      lexbuf.Lexing.lex_last_action <- (-1)
    end
  and __ocaml_lex_next_char lexbuf =
    if lexbuf.Lexing.lex_curr_pos >= lexbuf.Lexing.lex_buffer_len
    then
      (if lexbuf.Lexing.lex_eof_reached
       then 256
       else
         begin
           lexbuf.Lexing.refill_buff lexbuf; __ocaml_lex_next_char lexbuf
         end)
    else
      (let i = lexbuf.Lexing.lex_curr_pos in
       let c = (lexbuf.Lexing.lex_buffer).[i] in
       begin lexbuf.Lexing.lex_curr_pos <- i + 1; Char.code c end)
  and __ocaml_lex_state0 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 13 -> __ocaml_lex_state3 lexbuf
    | 34 -> __ocaml_lex_state6 lexbuf
    | 10 -> __ocaml_lex_state4 lexbuf
    | 92 -> __ocaml_lex_state5 lexbuf
    | 256 -> __ocaml_lex_state2 lexbuf
    | _ -> __ocaml_lex_state1 lexbuf
  and __ocaml_lex_state1 lexbuf = 8
  and __ocaml_lex_state2 lexbuf = 7
  and __ocaml_lex_state3 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state4 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state4 lexbuf = 6
  and __ocaml_lex_state5 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 8;
      (match __ocaml_lex_next_char lexbuf with
       | 13 ->
           begin
             (lexbuf.Lexing.lex_mem).(1) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state11 lexbuf
           end
       | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state9 lexbuf
       | 120 -> __ocaml_lex_state8 lexbuf
       | 256 ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end
       | 32|34|39|92|98|110|114|116 -> __ocaml_lex_state10 lexbuf
       | 10 ->
           begin
             (lexbuf.Lexing.lex_mem).(1) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state12 lexbuf
           end
       | _ -> __ocaml_lex_state7 lexbuf)
    end
  and __ocaml_lex_state6 lexbuf = 0
  and __ocaml_lex_state7 lexbuf = 5
  and __ocaml_lex_state8 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 5;
      (match __ocaml_lex_next_char lexbuf with
       | 48|49|50|51|52|53|54|55|56|57|65|66|67|68|69|70|97|98|99|100|101|102
           -> __ocaml_lex_state15 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state9 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 5;
      (match __ocaml_lex_next_char lexbuf with
       | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state13 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state10 lexbuf = 2
  and __ocaml_lex_state11 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(1);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 1;
      (match __ocaml_lex_next_char lexbuf with
       | 9|10|32 -> __ocaml_lex_state12 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state12 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(1);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 1;
      (match __ocaml_lex_next_char lexbuf with
       | 9|32 -> __ocaml_lex_state12 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state13 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state14 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state14 lexbuf = 3
  and __ocaml_lex_state15 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57|65|66|67|68|69|70|97|98|99|100|101|102 ->
        __ocaml_lex_state16 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state16 lexbuf = 4 in
  begin
    __ocaml_lex_init_lexbuf lexbuf 2;
    (let __ocaml_lex_result = __ocaml_lex_state0 lexbuf in
     begin
       lexbuf.Lexing.lex_start_p <- lexbuf.Lexing.lex_curr_p;
       lexbuf.Lexing.lex_curr_p <-
         {
           (lexbuf.Lexing.lex_curr_p) with
           Lexing.pos_cnum =
             (lexbuf.Lexing.lex_abs_pos + lexbuf.Lexing.lex_curr_pos)
         };
       (match __ocaml_lex_result with
        | 0 -> set_start_p c
        | 1 ->
            let space =
              Lexing.sub_lexeme lexbuf (((lexbuf.Lexing.lex_mem).(0)) + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            begin
              update_loc c ~retract:(String.length space);
              store_parse string c
            end
        | 2 -> store_parse string c
        | 3 -> store_parse string c
        | 4 -> store_parse string c
        | 5 ->
            let x =
              Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 1) in
            begin
              warn (Illegal_escape (String.make 1 x)) (FLoc.of_lexbuf lexbuf);
              store_parse string c
            end
        | 6 -> begin update_loc c; store_parse string c end
        | 7 -> err Unterminated_string (loc_merge c)
        | 8 -> store_parse string c
        | _ -> failwith "lexing: empty token")
     end)
  end

let rec antiquot name depth c lexbuf =
  let rec __ocaml_lex_init_lexbuf lexbuf mem_size =
    let pos = lexbuf.Lexing.lex_curr_pos in
    begin
      lexbuf.Lexing.lex_mem <- Array.create mem_size (-1);
      lexbuf.Lexing.lex_start_pos <- pos; lexbuf.Lexing.lex_last_pos <- pos;
      lexbuf.Lexing.lex_last_action <- (-1)
    end
  and __ocaml_lex_next_char lexbuf =
    if lexbuf.Lexing.lex_curr_pos >= lexbuf.Lexing.lex_buffer_len
    then
      (if lexbuf.Lexing.lex_eof_reached
       then 256
       else
         begin
           lexbuf.Lexing.refill_buff lexbuf; __ocaml_lex_next_char lexbuf
         end)
    else
      (let i = lexbuf.Lexing.lex_curr_pos in
       let c = (lexbuf.Lexing.lex_buffer).[i] in
       begin lexbuf.Lexing.lex_curr_pos <- i + 1; Char.code c end)
  and __ocaml_lex_state0 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 123 -> __ocaml_lex_state3 lexbuf
    | 256 -> __ocaml_lex_state6 lexbuf
    | 13 -> __ocaml_lex_state4 lexbuf
    | 41 -> __ocaml_lex_state8 lexbuf
    | 10 -> __ocaml_lex_state5 lexbuf
    | 40 -> __ocaml_lex_state7 lexbuf
    | 34 -> __ocaml_lex_state2 lexbuf
    | _ -> __ocaml_lex_state1 lexbuf
  and __ocaml_lex_state1 lexbuf = 6
  and __ocaml_lex_state2 lexbuf = 5
  and __ocaml_lex_state3 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 58 -> __ocaml_lex_state11 lexbuf
       | 124 ->
           begin
             (lexbuf.Lexing.lex_mem).(1) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state9 lexbuf
           end
       | 64 -> __ocaml_lex_state10 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state4 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 3;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state5 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state5 lexbuf = 3
  and __ocaml_lex_state6 lexbuf = 2
  and __ocaml_lex_state7 lexbuf = 1
  and __ocaml_lex_state8 lexbuf = 0
  and __ocaml_lex_state9 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(0) <- (-1);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 4;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 ->
           __ocaml_lex_state14 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state10 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |95
                                |97
                                 |98
                                  |99
                                   |100
                                    |101
                                     |102
                                      |103
                                       |104
                                        |105
                                         |106
                                          |107
                                           |108
                                            |109
                                             |110
                                              |111
                                               |112
                                                |113
                                                 |114
                                                  |115
                                                   |116
                                                    |117
                                                     |118
                                                      |119
                                                       |120
                                                        |121
                                                         |122
                                                          |192
                                                           |193
                                                            |194
                                                             |195
                                                              |196
                                                               |197
                                                                |198
                                                                 |199
                                                                  |200
                                                                   |201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state13 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state11 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |95
                                |97
                                 |98
                                  |99
                                   |100
                                    |101
                                     |102
                                      |103
                                       |104
                                        |105
                                         |106
                                          |107
                                           |108
                                            |109
                                             |110
                                              |111
                                               |112
                                                |113
                                                 |114
                                                  |115
                                                   |116
                                                    |117
                                                     |118
                                                      |119
                                                       |120
                                                        |121
                                                         |122
                                                          |192
                                                           |193
                                                            |194
                                                             |195
                                                              |196
                                                               |197
                                                                |198
                                                                 |199
                                                                  |200
                                                                   |201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state12 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state12 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(1) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state9 lexbuf
        end
    | 64 -> __ocaml_lex_state10 lexbuf
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state12 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state13 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state13 lexbuf
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(1) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state9 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state14 lexbuf =
    begin (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(1); 4 end in
  begin
    __ocaml_lex_init_lexbuf lexbuf 2;
    (let __ocaml_lex_result = __ocaml_lex_state0 lexbuf in
     begin
       lexbuf.Lexing.lex_start_p <- lexbuf.Lexing.lex_curr_p;
       lexbuf.Lexing.lex_curr_p <-
         {
           (lexbuf.Lexing.lex_curr_p) with
           Lexing.pos_cnum =
             (lexbuf.Lexing.lex_abs_pos + lexbuf.Lexing.lex_curr_pos)
         };
       (match __ocaml_lex_result with
        | 0 ->
            if depth = 0
            then begin set_start_p c; `Ant (name, (buff_contents c)) end
            else store_parse (antiquot name (depth - 1)) c
        | 1 -> store_parse (antiquot name (depth + 1)) c
        | 2 -> err Unterminated_antiquot (loc_merge c)
        | 3 -> begin update_loc c; store_parse (antiquot name depth) c end
        | 4 ->
            let p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(0)) + 0) in
            begin
              Stack.push p opt_char; store c; with_curr_loc quotation c;
              antiquot name depth c c.lexbuf
            end
        | 5 ->
            begin
              store c; with_curr_loc string c; Buffer.add_char c.buffer '"';
              antiquot name depth c c.lexbuf
            end
        | 6 -> store_parse (antiquot name depth) c
        | _ -> failwith "lexing: empty token")
     end)
  end
and quotation c lexbuf =
  let rec __ocaml_lex_init_lexbuf lexbuf mem_size =
    let pos = lexbuf.Lexing.lex_curr_pos in
    begin
      lexbuf.Lexing.lex_mem <- Array.create mem_size (-1);
      lexbuf.Lexing.lex_start_pos <- pos; lexbuf.Lexing.lex_last_pos <- pos;
      lexbuf.Lexing.lex_last_action <- (-1)
    end
  and __ocaml_lex_next_char lexbuf =
    if lexbuf.Lexing.lex_curr_pos >= lexbuf.Lexing.lex_buffer_len
    then
      (if lexbuf.Lexing.lex_eof_reached
       then 256
       else
         begin
           lexbuf.Lexing.refill_buff lexbuf; __ocaml_lex_next_char lexbuf
         end)
    else
      (let i = lexbuf.Lexing.lex_curr_pos in
       let c = (lexbuf.Lexing.lex_buffer).[i] in
       begin lexbuf.Lexing.lex_curr_pos <- i + 1; Char.code c end)
  and __ocaml_lex_state0 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 10 -> __ocaml_lex_state3 lexbuf
    | 34 -> __ocaml_lex_state6 lexbuf
    | 123 -> __ocaml_lex_state9 lexbuf
    | 256 -> __ocaml_lex_state4 lexbuf
    | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 -> __ocaml_lex_state8 lexbuf
    | 39 -> __ocaml_lex_state5 lexbuf
    | 124 -> __ocaml_lex_state7 lexbuf
    | 13 -> __ocaml_lex_state2 lexbuf
    | _ -> __ocaml_lex_state1 lexbuf
  and __ocaml_lex_state1 lexbuf = 6
  and __ocaml_lex_state2 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 5;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state3 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state3 lexbuf = 5
  and __ocaml_lex_state4 lexbuf = 4
  and __ocaml_lex_state5 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 10|13|256 ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end
       | 92 -> __ocaml_lex_state21 lexbuf
       | _ -> __ocaml_lex_state22 lexbuf)
    end
  and __ocaml_lex_state6 lexbuf = 2
  and __ocaml_lex_state7 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 125 -> __ocaml_lex_state20 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state8 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 124 -> __ocaml_lex_state18 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state9 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 64 -> __ocaml_lex_state11 lexbuf
       | 124 ->
           begin
             (lexbuf.Lexing.lex_mem).(2) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state10 lexbuf
           end
       | 58 -> __ocaml_lex_state12 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state10 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(0) <- (-1);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 0;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 ->
           __ocaml_lex_state17 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state11 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |95
                                |97
                                 |98
                                  |99
                                   |100
                                    |101
                                     |102
                                      |103
                                       |104
                                        |105
                                         |106
                                          |107
                                           |108
                                            |109
                                             |110
                                              |111
                                               |112
                                                |113
                                                 |114
                                                  |115
                                                   |116
                                                    |117
                                                     |118
                                                      |119
                                                       |120
                                                        |121
                                                         |122
                                                          |192
                                                           |193
                                                            |194
                                                             |195
                                                              |196
                                                               |197
                                                                |198
                                                                 |199
                                                                  |200
                                                                   |201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state16 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state12 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 95
      |97
       |98
        |99
         |100
          |101
           |102
            |103
             |104
              |105
               |106
                |107
                 |108
                  |109
                   |110
                    |111
                     |112
                      |113
                       |114
                        |115
                         |116
                          |117
                           |118
                            |119
                             |120
                              |121
                               |122
                                |223
                                 |224
                                  |225
                                   |226
                                    |227
                                     |228
                                      |229
                                       |230
                                        |231
                                         |232
                                          |233
                                           |234
                                            |235
                                             |236
                                              |237
                                               |238
                                                |239
                                                 |240
                                                  |241
                                                   |242
                                                    |243
                                                     |244
                                                      |245
                                                       |246
                                                        |248
                                                         |249
                                                          |250
                                                           |251
                                                            |252|253|254|255
        -> __ocaml_lex_state13 lexbuf
    | 46 -> __ocaml_lex_state15 lexbuf
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |192
                                |193
                                 |194
                                  |195
                                   |196
                                    |197
                                     |198
                                      |199
                                       |200
                                        |201
                                         |202
                                          |203
                                           |204
                                            |205
                                             |206
                                              |207
                                               |208
                                                |209
                                                 |210
                                                  |211
                                                   |212
                                                    |213
                                                     |214
                                                      |216
                                                       |217
                                                        |218|219|220|221|222
        -> __ocaml_lex_state14 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state13 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39
      |45
       |48
        |49
         |50
          |51
           |52
            |53
             |54
              |55
               |56
                |57
                 |65
                  |66
                   |67
                    |68
                     |69
                      |70
                       |71
                        |72
                         |73
                          |74
                           |75
                            |76
                             |77
                              |78
                               |79
                                |80
                                 |81
                                  |82
                                   |83
                                    |84
                                     |85
                                      |86
                                       |87
                                        |88
                                         |89
                                          |90
                                           |95
                                            |97
                                             |98
                                              |99
                                               |100
                                                |101
                                                 |102
                                                  |103
                                                   |104
                                                    |105
                                                     |106
                                                      |107
                                                       |108
                                                        |109
                                                         |110
                                                          |111
                                                           |112
                                                            |113
                                                             |114
                                                              |115
                                                               |116
                                                                |117
                                                                 |118
                                                                  |119
                                                                   |120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state13 lexbuf
    | 64 -> __ocaml_lex_state11 lexbuf
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(2) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state10 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state14 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 46 -> __ocaml_lex_state15 lexbuf
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state14 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state15 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 95
      |97
       |98
        |99
         |100
          |101
           |102
            |103
             |104
              |105
               |106
                |107
                 |108
                  |109
                   |110
                    |111
                     |112
                      |113
                       |114
                        |115
                         |116
                          |117
                           |118
                            |119
                             |120
                              |121
                               |122
                                |223
                                 |224
                                  |225
                                   |226
                                    |227
                                     |228
                                      |229
                                       |230
                                        |231
                                         |232
                                          |233
                                           |234
                                            |235
                                             |236
                                              |237
                                               |238
                                                |239
                                                 |240
                                                  |241
                                                   |242
                                                    |243
                                                     |244
                                                      |245
                                                       |246
                                                        |248
                                                         |249
                                                          |250
                                                           |251
                                                            |252|253|254|255
        -> __ocaml_lex_state13 lexbuf
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |192
                                |193
                                 |194
                                  |195
                                   |196
                                    |197
                                     |198
                                      |199
                                       |200
                                        |201
                                         |202
                                          |203
                                           |204
                                            |205
                                             |206
                                              |207
                                               |208
                                                |209
                                                 |210
                                                  |211
                                                   |212
                                                    |213
                                                     |214
                                                      |216
                                                       |217
                                                        |218|219|220|221|222
        -> __ocaml_lex_state14 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state16 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state16 lexbuf
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(2) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state10 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state17 lexbuf =
    begin (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(2); 0 end
  and __ocaml_lex_state18 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 125 -> __ocaml_lex_state19 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state19 lexbuf =
    begin (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(1); 1 end
  and __ocaml_lex_state20 lexbuf =
    begin (lexbuf.Lexing.lex_mem).(0) <- (-1); 1 end
  and __ocaml_lex_state21 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 32|34|39|92|98|110|114|116 -> __ocaml_lex_state22 lexbuf
    | 120 -> __ocaml_lex_state24 lexbuf
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state25 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state22 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39 -> __ocaml_lex_state23 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state23 lexbuf = 3
  and __ocaml_lex_state24 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57|65|66|67|68|69|70|97|98|99|100|101|102 ->
        __ocaml_lex_state27 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state25 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state26 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state26 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state22 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state27 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57|65|66|67|68|69|70|97|98|99|100|101|102 ->
        __ocaml_lex_state22 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end in
  begin
    begin
      __ocaml_lex_init_lexbuf lexbuf 3;
      (lexbuf.Lexing.lex_mem).(1) <- lexbuf.Lexing.lex_curr_pos
    end;
    (let __ocaml_lex_result = __ocaml_lex_state0 lexbuf in
     begin
       lexbuf.Lexing.lex_start_p <- lexbuf.Lexing.lex_curr_p;
       lexbuf.Lexing.lex_curr_p <-
         {
           (lexbuf.Lexing.lex_curr_p) with
           Lexing.pos_cnum =
             (lexbuf.Lexing.lex_abs_pos + lexbuf.Lexing.lex_curr_pos)
         };
       (match __ocaml_lex_result with
        | 0 ->
            let p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(0)) + 0) in
            begin
              store c; Stack.push p opt_char; with_curr_loc quotation c;
              quotation c c.lexbuf
            end
        | 1 ->
            let p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(0)) + 0) in
            if not (Stack.is_empty opt_char)
            then
              let top = Stack.top opt_char in
              (if p <> top
               then store_parse quotation c
               else begin ignore (Stack.pop opt_char); store c end)
            else store_parse quotation c
        | 2 ->
            begin
              store c; with_curr_loc string c; Buffer.add_char c.buffer '"';
              quotation c c.lexbuf
            end
        | 3 -> store_parse quotation c
        | 4 ->
            begin show_stack (); err Unterminated_quotation (loc_merge c) end
        | 5 -> begin update_loc c; store_parse quotation c end
        | 6 -> store_parse quotation c
        | _ -> failwith "lexing: empty token")
     end)
  end

let token c lexbuf =
  let rec __ocaml_lex_init_lexbuf lexbuf mem_size =
    let pos = lexbuf.Lexing.lex_curr_pos in
    begin
      lexbuf.Lexing.lex_mem <- Array.create mem_size (-1);
      lexbuf.Lexing.lex_start_pos <- pos; lexbuf.Lexing.lex_last_pos <- pos;
      lexbuf.Lexing.lex_last_action <- (-1)
    end
  and __ocaml_lex_next_char lexbuf =
    if lexbuf.Lexing.lex_curr_pos >= lexbuf.Lexing.lex_buffer_len
    then
      (if lexbuf.Lexing.lex_eof_reached
       then 256
       else
         begin
           lexbuf.Lexing.refill_buff lexbuf; __ocaml_lex_next_char lexbuf
         end)
    else
      (let i = lexbuf.Lexing.lex_curr_pos in
       let c = (lexbuf.Lexing.lex_buffer).[i] in
       begin lexbuf.Lexing.lex_curr_pos <- i + 1; Char.code c end)
  and __ocaml_lex_state0 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 33|43|45|92 -> __ocaml_lex_state3 lexbuf
    | 60|61 -> __ocaml_lex_state6 lexbuf
    | 34 -> __ocaml_lex_state20 lexbuf
    | 46 -> __ocaml_lex_state13 lexbuf
    | 126 -> __ocaml_lex_state26 lexbuf
    | 48 -> __ocaml_lex_state22 lexbuf
    | 59 -> __ocaml_lex_state11 lexbuf
    | 91 -> __ocaml_lex_state9 lexbuf
    | 36 -> __ocaml_lex_state4 lexbuf
    | 37|38|47|64|94 -> __ocaml_lex_state8 lexbuf
    | 62 -> __ocaml_lex_state15 lexbuf
    | 13 -> __ocaml_lex_state28 lexbuf
    | 42 -> __ocaml_lex_state17 lexbuf
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |192
                                |193
                                 |194
                                  |195
                                   |196
                                    |197
                                     |198
                                      |199
                                       |200
                                        |201
                                         |202
                                          |203
                                           |204
                                            |205
                                             |206
                                              |207
                                               |208
                                                |209
                                                 |210
                                                  |211
                                                   |212
                                                    |213
                                                     |214
                                                      |216
                                                       |217
                                                        |218|219|220|221|222
        -> __ocaml_lex_state23 lexbuf
    | 9|12|32 -> __ocaml_lex_state27 lexbuf
    | 10 -> __ocaml_lex_state29 lexbuf
    | 41|93 -> __ocaml_lex_state5 lexbuf
    | 40 -> __ocaml_lex_state18 lexbuf
    | 95
      |97
       |98
        |99
         |100
          |101
           |102
            |103
             |104
              |105
               |106
                |107
                 |108
                  |109
                   |110
                    |111
                     |112
                      |113
                       |114
                        |115
                         |116
                          |117
                           |118
                            |119
                             |120
                              |121
                               |122
                                |223
                                 |224
                                  |225
                                   |226
                                    |227
                                     |228
                                      |229
                                       |230
                                        |231
                                         |232
                                          |233
                                           |234
                                            |235
                                             |236
                                              |237
                                               |238
                                                |239
                                                 |240
                                                  |241
                                                   |242
                                                    |243
                                                     |244
                                                      |245
                                                       |246
                                                        |248
                                                         |249
                                                          |250
                                                           |251
                                                            |252|253|254|255
        -> __ocaml_lex_state24 lexbuf
    | 39 -> __ocaml_lex_state19 lexbuf
    | 124 -> __ocaml_lex_state7 lexbuf
    | 63 -> __ocaml_lex_state25 lexbuf
    | 123 -> __ocaml_lex_state16 lexbuf
    | 49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state21 lexbuf
    | 44|96|125 -> __ocaml_lex_state10 lexbuf
    | 35 ->
        begin
          (lexbuf.Lexing.lex_mem).(4) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state14 lexbuf
        end
    | 58 -> __ocaml_lex_state12 lexbuf
    | 256 -> __ocaml_lex_state2 lexbuf
    | _ -> __ocaml_lex_state1 lexbuf
  and __ocaml_lex_state1 lexbuf = 32
  and __ocaml_lex_state2 lexbuf = 31
  and __ocaml_lex_state3 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|42|43|45|46|47|58|60|61|62|63|64|92|94|124|126 ->
           __ocaml_lex_state3 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state4 lexbuf = 29
  and __ocaml_lex_state5 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|47|64|94 -> __ocaml_lex_state105 lexbuf
       | 41|46|58|60|61|62|93|124 -> __ocaml_lex_state98 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state6 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 46|60|61|62 -> __ocaml_lex_state6 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state8 lexbuf
       | 58|124 -> __ocaml_lex_state133 lexbuf
       | 41|93 -> __ocaml_lex_state98 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state7 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 46|60|61|62 -> __ocaml_lex_state6 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state8 lexbuf
       | 58|124 -> __ocaml_lex_state133 lexbuf
       | 41|93 -> __ocaml_lex_state5 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state8 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 37|38|46|47|60|61|62|64|94 -> __ocaml_lex_state8 lexbuf
       | 41|93 -> __ocaml_lex_state103 lexbuf
       | 58|124 -> __ocaml_lex_state132 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state9 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 46 -> __ocaml_lex_state129 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state131 lexbuf
       | 58|60|61|62|124 -> __ocaml_lex_state130 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state10 lexbuf = 28
  and __ocaml_lex_state11 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 59 -> __ocaml_lex_state10 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state12 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 46|60 -> __ocaml_lex_state123 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state125 lexbuf
       | 41|93 -> __ocaml_lex_state5 lexbuf
       | 124 -> __ocaml_lex_state124 lexbuf
       | 61|62 -> __ocaml_lex_state126 lexbuf
       | 58 -> __ocaml_lex_state128 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state13 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 60|61|62 -> __ocaml_lex_state123 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state125 lexbuf
       | 58|124 -> __ocaml_lex_state124 lexbuf
       | 41|93 -> __ocaml_lex_state98 lexbuf
       | 46 -> __ocaml_lex_state126 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state14 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 123 -> __ocaml_lex_state108 lexbuf
       | 9|32 ->
           begin
             (lexbuf.Lexing.lex_mem).(4) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state107 lexbuf
           end
       | 48|49|50|51|52|53|54|55|56|57 ->
           begin
             (lexbuf.Lexing.lex_mem).(17) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state106 lexbuf
           end
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state15 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 46|60|61|62 -> __ocaml_lex_state99 lexbuf
       | 125 -> __ocaml_lex_state102 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state101 lexbuf
       | 58|124 -> __ocaml_lex_state100 lexbuf
       | 93 -> __ocaml_lex_state5 lexbuf
       | 41 -> __ocaml_lex_state98 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state16 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 64 -> __ocaml_lex_state73 lexbuf
       | 60 -> __ocaml_lex_state75 lexbuf
       | 124 ->
           begin
             (lexbuf.Lexing.lex_mem).(9) <- lexbuf.Lexing.lex_curr_pos;
             (lexbuf.Lexing.lex_mem).(8) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state74 lexbuf
           end
       | 58 -> __ocaml_lex_state72 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state17 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|42|43|45|46|47|58|60|61|62|63|64|92|94|124|126 ->
           __ocaml_lex_state3 lexbuf
       | 41 -> __ocaml_lex_state71 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state18 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|47|64|94 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state61 lexbuf
           end
       | 9|12|32 ->
           begin
             (lexbuf.Lexing.lex_mem).(5) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state57 lexbuf
           end
       | 33|43|45|63|92|126 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state58 lexbuf
           end
       | 42 -> __ocaml_lex_state62 lexbuf
       | 46|60|61|62 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state59 lexbuf
           end
       | 58|124 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state60 lexbuf
           end
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state19 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state48 lexbuf
       | 92 -> __ocaml_lex_state45 lexbuf
       | 13 -> __ocaml_lex_state47 lexbuf
       | 256 ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end
       | _ -> __ocaml_lex_state46 lexbuf)
    end
  and __ocaml_lex_state20 lexbuf = 8
  and __ocaml_lex_state21 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 76|108|110 -> __ocaml_lex_state36 lexbuf
       | 46 -> __ocaml_lex_state35 lexbuf
       | 48|49|50|51|52|53|54|55|56|57|95 -> __ocaml_lex_state21 lexbuf
       | 69|101 -> __ocaml_lex_state34 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state22 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 76|108|110 -> __ocaml_lex_state36 lexbuf
       | 79|111 -> __ocaml_lex_state38 lexbuf
       | 46 -> __ocaml_lex_state35 lexbuf
       | 66|98 -> __ocaml_lex_state37 lexbuf
       | 48|49|50|51|52|53|54|55|56|57|95 -> __ocaml_lex_state21 lexbuf
       | 69|101 -> __ocaml_lex_state34 lexbuf
       | 88|120 -> __ocaml_lex_state39 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state23 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 5;
      (match __ocaml_lex_next_char lexbuf with
       | 39
         |48
          |49
           |50
            |51
             |52
              |53
               |54
                |55
                 |56
                  |57
                   |65
                    |66
                     |67
                      |68
                       |69
                        |70
                         |71
                          |72
                           |73
                            |74
                             |75
                              |76
                               |77
                                |78
                                 |79
                                  |80
                                   |81
                                    |82
                                     |83
                                      |84
                                       |85
                                        |86
                                         |87
                                          |88
                                           |89
                                            |90
                                             |95
                                              |97
                                               |98
                                                |99
                                                 |100
                                                  |101
                                                   |102
                                                    |103
                                                     |104
                                                      |105
                                                       |106
                                                        |107
                                                         |108
                                                          |109
                                                           |110
                                                            |111
                                                             |112
                                                              |113
                                                               |114
                                                                |115
                                                                 |116
                                                                  |117
                                                                   |118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
           -> __ocaml_lex_state23 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state24 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 4;
      (match __ocaml_lex_next_char lexbuf with
       | 39
         |48
          |49
           |50
            |51
             |52
              |53
               |54
                |55
                 |56
                  |57
                   |65
                    |66
                     |67
                      |68
                       |69
                        |70
                         |71
                          |72
                           |73
                            |74
                             |75
                              |76
                               |77
                                |78
                                 |79
                                  |80
                                   |81
                                    |82
                                     |83
                                      |84
                                       |85
                                        |86
                                         |87
                                          |88
                                           |89
                                            |90
                                             |95
                                              |97
                                               |98
                                                |99
                                                 |100
                                                  |101
                                                   |102
                                                    |103
                                                     |104
                                                      |105
                                                       |106
                                                        |107
                                                         |108
                                                          |109
                                                           |110
                                                            |111
                                                             |112
                                                              |113
                                                               |114
                                                                |115
                                                                 |116
                                                                  |117
                                                                   |118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
           -> __ocaml_lex_state24 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state25 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|42|43|45|46|47|58|60|61|62|63|64|92|94|124|126 ->
           __ocaml_lex_state3 lexbuf
       | 95
         |97
          |98
           |99
            |100
             |101
              |102
               |103
                |104
                 |105
                  |106
                   |107
                    |108
                     |109
                      |110
                       |111
                        |112
                         |113
                          |114
                           |115
                            |116
                             |117
                              |118
                               |119
                                |120
                                 |121
                                  |122
                                   |223
                                    |224
                                     |225
                                      |226
                                       |227
                                        |228
                                         |229
                                          |230
                                           |231
                                            |232
                                             |233
                                              |234
                                               |235
                                                |236
                                                 |237
                                                  |238
                                                   |239
                                                    |240
                                                     |241
                                                      |242
                                                       |243
                                                        |244
                                                         |245
                                                          |246
                                                           |248
                                                            |249
                                                             |250
                                                              |251
                                                               |252
                                                                |253|254|255
           -> __ocaml_lex_state32 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state26 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|42|43|45|46|47|58|60|61|62|63|64|92|94|124|126 ->
           __ocaml_lex_state3 lexbuf
       | 95
         |97
          |98
           |99
            |100
             |101
              |102
               |103
                |104
                 |105
                  |106
                   |107
                    |108
                     |109
                      |110
                       |111
                        |112
                         |113
                          |114
                           |115
                            |116
                             |117
                              |118
                               |119
                                |120
                                 |121
                                  |122
                                   |223
                                    |224
                                     |225
                                      |226
                                       |227
                                        |228
                                         |229
                                          |230
                                           |231
                                            |232
                                             |233
                                              |234
                                               |235
                                                |236
                                                 |237
                                                  |238
                                                   |239
                                                    |240
                                                     |241
                                                      |242
                                                       |243
                                                        |244
                                                         |245
                                                          |246
                                                           |248
                                                            |249
                                                             |250
                                                              |251
                                                               |252
                                                                |253|254|255
           -> __ocaml_lex_state30 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state27 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 1;
      (match __ocaml_lex_next_char lexbuf with
       | 9|12|32 -> __ocaml_lex_state27 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state28 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 0;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state29 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state29 lexbuf = 0
  and __ocaml_lex_state30 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 58 -> __ocaml_lex_state31 lexbuf
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state30 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state31 lexbuf = 2
  and __ocaml_lex_state32 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state32 lexbuf
    | 58 -> __ocaml_lex_state33 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state33 lexbuf = 3
  and __ocaml_lex_state34 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 43|45 -> __ocaml_lex_state44 lexbuf
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state43 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state35 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 7;
      (match __ocaml_lex_next_char lexbuf with
       | 48|49|50|51|52|53|54|55|56|57|95 -> __ocaml_lex_state35 lexbuf
       | 69|101 -> __ocaml_lex_state34 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state36 lexbuf = 6
  and __ocaml_lex_state37 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49 -> __ocaml_lex_state42 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state38 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55 -> __ocaml_lex_state41 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state39 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57|65|66|67|68|69|70|97|98|99|100|101|102 ->
        __ocaml_lex_state40 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state40 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 48
         |49
          |50|51|52|53|54|55|56|57|65|66|67|68|69|70|95|97|98|99|100|101|102
           -> __ocaml_lex_state40 lexbuf
       | 76|108|110 -> __ocaml_lex_state36 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state41 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 76|108|110 -> __ocaml_lex_state36 lexbuf
       | 48|49|50|51|52|53|54|55|95 -> __ocaml_lex_state41 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state42 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 6;
      (match __ocaml_lex_next_char lexbuf with
       | 76|108|110 -> __ocaml_lex_state36 lexbuf
       | 48|49|95 -> __ocaml_lex_state42 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state43 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 7;
      (match __ocaml_lex_next_char lexbuf with
       | 48|49|50|51|52|53|54|55|56|57|95 -> __ocaml_lex_state43 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state44 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state43 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state45 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 120 -> __ocaml_lex_state52 lexbuf
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state53 lexbuf
    | 32|34|39|92|98|110|114|116 -> __ocaml_lex_state54 lexbuf
    | _ -> __ocaml_lex_state51 lexbuf
  and __ocaml_lex_state46 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39 -> __ocaml_lex_state50 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state47 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 10 -> __ocaml_lex_state48 lexbuf
    | 39 -> __ocaml_lex_state49 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state48 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39 -> __ocaml_lex_state49 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state49 lexbuf = 9
  and __ocaml_lex_state50 lexbuf = 10
  and __ocaml_lex_state51 lexbuf = 11
  and __ocaml_lex_state52 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 11;
      (match __ocaml_lex_next_char lexbuf with
       | 48|49|50|51|52|53|54|55|56|57|65|66|67|68|69|70|97|98|99|100|101|102
           -> __ocaml_lex_state56 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state53 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 11;
      (match __ocaml_lex_next_char lexbuf with
       | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state55 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state54 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 11;
      (match __ocaml_lex_next_char lexbuf with
       | 39 -> __ocaml_lex_state50 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state55 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57 -> __ocaml_lex_state46 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state56 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 48|49|50|51|52|53|54|55|56|57|65|66|67|68|69|70|97|98|99|100|101|102 ->
        __ocaml_lex_state46 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state57 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 9|12|32 ->
        begin
          (lexbuf.Lexing.lex_mem).(5) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state57 lexbuf
        end
    | 33|37|38|42|43|45|46|47|58|60|61|62|63|64|92|94|124|126 ->
        begin
          (lexbuf.Lexing.lex_mem).(7) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state68 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state58 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 33|37|38|42|43|45|46|47|58|60|61|62|63|64|92|94|124|126 ->
        begin
          (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state58 lexbuf
        end
    | 9|12|32 -> __ocaml_lex_state66 lexbuf
    | 41 -> __ocaml_lex_state65 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state59 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 37|38|47|64|94 ->
        begin
          (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state61 lexbuf
        end
    | 33|42|43|45|63|92|126 ->
        begin
          (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state58 lexbuf
        end
    | 9|12|32 -> __ocaml_lex_state66 lexbuf
    | 46|58|60|61|62|124 ->
        begin
          (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state59 lexbuf
        end
    | 41 -> __ocaml_lex_state65 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state60 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|47|64|94 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state67 lexbuf
           end
       | 33|42|43|45|63|92|126 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state58 lexbuf
           end
       | 9|12|32 -> __ocaml_lex_state66 lexbuf
       | 46|58|60|61|62|124 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state60 lexbuf
           end
       | 41 -> __ocaml_lex_state65 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state61 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|46|47|58|60|61|62|64|94|124 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state61 lexbuf
           end
       | 33|42|43|45|63|92|126 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state58 lexbuf
           end
       | 9|12|32 -> __ocaml_lex_state66 lexbuf
       | 40|91 -> __ocaml_lex_state64 lexbuf
       | 41 -> __ocaml_lex_state65 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state62 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 12;
      (match __ocaml_lex_next_char lexbuf with
       | 41 -> __ocaml_lex_state63 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state63 lexbuf = 13
  and __ocaml_lex_state64 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|40|46|47|58|60|61|62|64|91|94|124 ->
           __ocaml_lex_state64 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state65 lexbuf =
    begin (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(6); 26 end
  and __ocaml_lex_state66 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 9|12|32 -> __ocaml_lex_state66 lexbuf
    | 41 -> __ocaml_lex_state65 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state67 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|46|47|58|60|61|62|64|94|124 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state67 lexbuf
           end
       | 33|42|43|45|63|92|126 ->
           begin
             (lexbuf.Lexing.lex_mem).(6) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state58 lexbuf
           end
       | 9|12|32 -> __ocaml_lex_state66 lexbuf
       | 40|91 -> __ocaml_lex_state64 lexbuf
       | 41 -> __ocaml_lex_state65 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state68 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 41 -> __ocaml_lex_state69 lexbuf
    | 33|37|38|42|43|45|46|47|58|60|61|62|63|64|92|94|124|126 ->
        begin
          (lexbuf.Lexing.lex_mem).(7) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state68 lexbuf
        end
    | 9|12|32 -> __ocaml_lex_state70 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state69 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(5);
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(7); 27
    end
  and __ocaml_lex_state70 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 41 -> __ocaml_lex_state69 lexbuf
    | 9|12|32 -> __ocaml_lex_state70 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state71 lexbuf = 14
  and __ocaml_lex_state72 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |192
                                |193
                                 |194
                                  |195
                                   |196
                                    |197
                                     |198
                                      |199
                                       |200
                                        |201
                                         |202
                                          |203
                                           |204
                                            |205
                                             |206
                                              |207
                                               |208
                                                |209
                                                 |210
                                                  |211
                                                   |212
                                                    |213
                                                     |214
                                                      |216
                                                       |217
                                                        |218|219|220|221|222
        -> __ocaml_lex_state87 lexbuf
    | 46 -> __ocaml_lex_state88 lexbuf
    | 95
      |97
       |98
        |99
         |100
          |101
           |102
            |103
             |104
              |105
               |106
                |107
                 |108
                  |109
                   |110
                    |111
                     |112
                      |113
                       |114
                        |115
                         |116
                          |117
                           |118
                            |119
                             |120
                              |121
                               |122
                                |223
                                 |224
                                  |225
                                   |226
                                    |227
                                     |228
                                      |229
                                       |230
                                        |231
                                         |232
                                          |233
                                           |234
                                            |235
                                             |236
                                              |237
                                               |238
                                                |239
                                                 |240
                                                  |241
                                                   |242
                                                    |243
                                                     |244
                                                      |245
                                                       |246
                                                        |248
                                                         |249
                                                          |250
                                                           |251
                                                            |252|253|254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(13) <- lexbuf.Lexing.lex_curr_pos;
          (lexbuf.Lexing.lex_mem).(12) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state86 lexbuf
        end
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | _ -> __ocaml_lex_state85 lexbuf
  and __ocaml_lex_state73 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |95
                                |97
                                 |98
                                  |99
                                   |100
                                    |101
                                     |102
                                      |103
                                       |104
                                        |105
                                         |106
                                          |107
                                           |108
                                            |109
                                             |110
                                              |111
                                               |112
                                                |113
                                                 |114
                                                  |115
                                                   |116
                                                    |117
                                                     |118
                                                      |119
                                                       |120
                                                        |121
                                                         |122
                                                          |192
                                                           |193
                                                            |194
                                                             |195
                                                              |196
                                                               |197
                                                                |198
                                                                 |199
                                                                  |200
                                                                   |201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(10) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state81 lexbuf
        end
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | _ -> __ocaml_lex_state80 lexbuf
  and __ocaml_lex_state74 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(8);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 17;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 ->
           begin
             (lexbuf.Lexing.lex_mem).(8) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state78 lexbuf
           end
       | 124 -> __ocaml_lex_state77 lexbuf
       | 42 -> __ocaml_lex_state76 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state75 lexbuf = 15
  and __ocaml_lex_state76 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(8);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 17;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|42|43|45|46|47|58|61|63|64|92|94|124|126 ->
           __ocaml_lex_state76 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state77 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(8);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 17;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|42|43|45|46|47|58|61|63|64|92|94|124|126 ->
           __ocaml_lex_state76 lexbuf
       | 125 -> __ocaml_lex_state79 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state78 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(9);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(8);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 17;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|42|43|45|46|47|58|61|63|64|92|94|124|126 ->
           __ocaml_lex_state78 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state79 lexbuf = 18
  and __ocaml_lex_state80 lexbuf = 20
  and __ocaml_lex_state81 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 20;
      (match __ocaml_lex_next_char lexbuf with
       | 39
         |48
          |49
           |50
            |51
             |52
              |53
               |54
                |55
                 |56
                  |57
                   |65
                    |66
                     |67
                      |68
                       |69
                        |70
                         |71
                          |72
                           |73
                            |74
                             |75
                              |76
                               |77
                                |78
                                 |79
                                  |80
                                   |81
                                    |82
                                     |83
                                      |84
                                       |85
                                        |86
                                         |87
                                          |88
                                           |89
                                            |90
                                             |95
                                              |97
                                               |98
                                                |99
                                                 |100
                                                  |101
                                                   |102
                                                    |103
                                                     |104
                                                      |105
                                                       |106
                                                        |107
                                                         |108
                                                          |109
                                                           |110
                                                            |111
                                                             |112
                                                              |113
                                                               |114
                                                                |115
                                                                 |116
                                                                  |117
                                                                   |118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
           ->
           begin
             (lexbuf.Lexing.lex_mem).(10) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state83 lexbuf
           end
       | 124 ->
           begin
             (lexbuf.Lexing.lex_mem).(11) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state82 lexbuf
           end
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state82 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(10);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 19;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 ->
           __ocaml_lex_state84 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state83 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(10) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state83 lexbuf
        end
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(11) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state82 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state84 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(11);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(10); 19
    end
  and __ocaml_lex_state85 lexbuf = 24
  and __ocaml_lex_state86 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 24;
      (match __ocaml_lex_next_char lexbuf with
       | 64 -> __ocaml_lex_state92 lexbuf
       | 124 ->
           begin
             (lexbuf.Lexing.lex_mem).(14) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state93 lexbuf
           end
       | 39
         |45
          |48
           |49
            |50
             |51
              |52
               |53
                |54
                 |55
                  |56
                   |57
                    |65
                     |66
                      |67
                       |68
                        |69
                         |70
                          |71
                           |72
                            |73
                             |74
                              |75
                               |76
                                |77
                                 |78
                                  |79
                                   |80
                                    |81
                                     |82
                                      |83
                                       |84
                                        |85
                                         |86
                                          |87
                                           |88
                                            |89
                                             |90
                                              |95
                                               |97
                                                |98
                                                 |99
                                                  |100
                                                   |101
                                                    |102
                                                     |103
                                                      |104
                                                       |105
                                                        |106
                                                         |107
                                                          |108
                                                           |109
                                                            |110
                                                             |111
                                                              |112
                                                               |113
                                                                |114
                                                                 |115
                                                                  |116
                                                                   |117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
           ->
           begin
             (lexbuf.Lexing.lex_mem).(13) <- lexbuf.Lexing.lex_curr_pos;
             (lexbuf.Lexing.lex_mem).(12) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state89 lexbuf
           end
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state87 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 24;
      (match __ocaml_lex_next_char lexbuf with
       | 46 -> __ocaml_lex_state91 lexbuf
       | 39
         |48
          |49
           |50
            |51
             |52
              |53
               |54
                |55
                 |56
                  |57
                   |65
                    |66
                     |67
                      |68
                       |69
                        |70
                         |71
                          |72
                           |73
                            |74
                             |75
                              |76
                               |77
                                |78
                                 |79
                                  |80
                                   |81
                                    |82
                                     |83
                                      |84
                                       |85
                                        |86
                                         |87
                                          |88
                                           |89
                                            |90
                                             |95
                                              |97
                                               |98
                                                |99
                                                 |100
                                                  |101
                                                   |102
                                                    |103
                                                     |104
                                                      |105
                                                       |106
                                                        |107
                                                         |108
                                                          |109
                                                           |110
                                                            |111
                                                             |112
                                                              |113
                                                               |114
                                                                |115
                                                                 |116
                                                                  |117
                                                                   |118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
           -> __ocaml_lex_state90 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state88 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 24;
      (match __ocaml_lex_next_char lexbuf with
       | 95
         |97
          |98
           |99
            |100
             |101
              |102
               |103
                |104
                 |105
                  |106
                   |107
                    |108
                     |109
                      |110
                       |111
                        |112
                         |113
                          |114
                           |115
                            |116
                             |117
                              |118
                               |119
                                |120
                                 |121
                                  |122
                                   |223
                                    |224
                                     |225
                                      |226
                                       |227
                                        |228
                                         |229
                                          |230
                                           |231
                                            |232
                                             |233
                                              |234
                                               |235
                                                |236
                                                 |237
                                                  |238
                                                   |239
                                                    |240
                                                     |241
                                                      |242
                                                       |243
                                                        |244
                                                         |245
                                                          |246
                                                           |248
                                                            |249
                                                             |250
                                                              |251
                                                               |252
                                                                |253|254|255
           ->
           begin
             (lexbuf.Lexing.lex_mem).(13) <- lexbuf.Lexing.lex_curr_pos;
             (lexbuf.Lexing.lex_mem).(12) <- lexbuf.Lexing.lex_curr_pos;
             __ocaml_lex_state89 lexbuf
           end
       | 65
         |66
          |67
           |68
            |69
             |70
              |71
               |72
                |73
                 |74
                  |75
                   |76
                    |77
                     |78
                      |79
                       |80
                        |81
                         |82
                          |83
                           |84
                            |85
                             |86
                              |87
                               |88
                                |89
                                 |90
                                  |192
                                   |193
                                    |194
                                     |195
                                      |196
                                       |197
                                        |198
                                         |199
                                          |200
                                           |201
                                            |202
                                             |203
                                              |204
                                               |205
                                                |206
                                                 |207
                                                  |208
                                                   |209
                                                    |210
                                                     |211
                                                      |212
                                                       |213
                                                        |214
                                                         |216
                                                          |217
                                                           |218
                                                            |219|220|221|222
           -> __ocaml_lex_state90 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state89 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 64 -> __ocaml_lex_state92 lexbuf
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(14) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state93 lexbuf
        end
    | 39
      |45
       |48
        |49
         |50
          |51
           |52
            |53
             |54
              |55
               |56
                |57
                 |65
                  |66
                   |67
                    |68
                     |69
                      |70
                       |71
                        |72
                         |73
                          |74
                           |75
                            |76
                             |77
                              |78
                               |79
                                |80
                                 |81
                                  |82
                                   |83
                                    |84
                                     |85
                                      |86
                                       |87
                                        |88
                                         |89
                                          |90
                                           |95
                                            |97
                                             |98
                                              |99
                                               |100
                                                |101
                                                 |102
                                                  |103
                                                   |104
                                                    |105
                                                     |106
                                                      |107
                                                       |108
                                                        |109
                                                         |110
                                                          |111
                                                           |112
                                                            |113
                                                             |114
                                                              |115
                                                               |116
                                                                |117
                                                                 |118
                                                                  |119
                                                                   |120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(13) <- lexbuf.Lexing.lex_curr_pos;
          (lexbuf.Lexing.lex_mem).(12) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state89 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state90 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 46 -> __ocaml_lex_state91 lexbuf
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state90 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state91 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 95
      |97
       |98
        |99
         |100
          |101
           |102
            |103
             |104
              |105
               |106
                |107
                 |108
                  |109
                   |110
                    |111
                     |112
                      |113
                       |114
                        |115
                         |116
                          |117
                           |118
                            |119
                             |120
                              |121
                               |122
                                |223
                                 |224
                                  |225
                                   |226
                                    |227
                                     |228
                                      |229
                                       |230
                                        |231
                                         |232
                                          |233
                                           |234
                                            |235
                                             |236
                                              |237
                                               |238
                                                |239
                                                 |240
                                                  |241
                                                   |242
                                                    |243
                                                     |244
                                                      |245
                                                       |246
                                                        |248
                                                         |249
                                                          |250
                                                           |251
                                                            |252|253|254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(13) <- lexbuf.Lexing.lex_curr_pos;
          (lexbuf.Lexing.lex_mem).(12) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state89 lexbuf
        end
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |192
                                |193
                                 |194
                                  |195
                                   |196
                                    |197
                                     |198
                                      |199
                                       |200
                                        |201
                                         |202
                                          |203
                                           |204
                                            |205
                                             |206
                                              |207
                                               |208
                                                |209
                                                 |210
                                                  |211
                                                   |212
                                                    |213
                                                     |214
                                                      |216
                                                       |217
                                                        |218|219|220|221|222
        -> __ocaml_lex_state90 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state92 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |95
                                |97
                                 |98
                                  |99
                                   |100
                                    |101
                                     |102
                                      |103
                                       |104
                                        |105
                                         |106
                                          |107
                                           |108
                                            |109
                                             |110
                                              |111
                                               |112
                                                |113
                                                 |114
                                                  |115
                                                   |116
                                                    |117
                                                     |118
                                                      |119
                                                       |120
                                                        |121
                                                         |122
                                                          |192
                                                           |193
                                                            |194
                                                             |195
                                                              |196
                                                               |197
                                                                |198
                                                                 |199
                                                                  |200
                                                                   |201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(15) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state95 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state93 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(12);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 21;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 ->
           __ocaml_lex_state94 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state94 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(14);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(12); 21
    end
  and __ocaml_lex_state95 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(16) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state96 lexbuf
        end
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(15) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state95 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state96 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(2) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(13);
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(15);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 23;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 ->
           __ocaml_lex_state97 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state97 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(2) <- (lexbuf.Lexing.lex_mem).(16);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(13);
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(15); 23
    end
  and __ocaml_lex_state98 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 37|38|47|64|94 -> __ocaml_lex_state105 lexbuf
    | 41|46|58|60|61|62|93|124 -> __ocaml_lex_state98 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state99 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 46|60|61|62 -> __ocaml_lex_state99 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state101 lexbuf
       | 58|124 -> __ocaml_lex_state100 lexbuf
       | 93 -> __ocaml_lex_state5 lexbuf
       | 41 -> __ocaml_lex_state98 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state100 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 46|60|61|62 -> __ocaml_lex_state99 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state101 lexbuf
       | 58|124 -> __ocaml_lex_state100 lexbuf
       | 41|93 -> __ocaml_lex_state5 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state101 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 58|124 -> __ocaml_lex_state104 lexbuf
       | 37|38|46|47|60|61|62|64|94 -> __ocaml_lex_state101 lexbuf
       | 41|93 -> __ocaml_lex_state103 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state102 lexbuf = 16
  and __ocaml_lex_state103 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|46|47|58|60|61|62|64|94|124 -> __ocaml_lex_state105 lexbuf
       | 41|93 -> __ocaml_lex_state103 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state104 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 58|124 -> __ocaml_lex_state104 lexbuf
       | 37|38|46|47|60|61|62|64|94 -> __ocaml_lex_state101 lexbuf
       | 41|93 -> __ocaml_lex_state103 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state105 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 37|38|46|47|58|60|61|62|64|94|124 -> __ocaml_lex_state105 lexbuf
    | 41|93 -> __ocaml_lex_state103 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state106 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 9|32 -> __ocaml_lex_state119 lexbuf
    | 10 -> __ocaml_lex_state116 lexbuf
    | 34 ->
        begin
          (lexbuf.Lexing.lex_mem).(21) <- lexbuf.Lexing.lex_curr_pos;
          (lexbuf.Lexing.lex_mem).(20) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state118 lexbuf
        end
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | 48|49|50|51|52|53|54|55|56|57 ->
        begin
          (lexbuf.Lexing.lex_mem).(17) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state106 lexbuf
        end
    | 13 -> __ocaml_lex_state115 lexbuf
    | _ -> __ocaml_lex_state117 lexbuf
  and __ocaml_lex_state107 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 9|32 ->
        begin
          (lexbuf.Lexing.lex_mem).(4) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state107 lexbuf
        end
    | 48|49|50|51|52|53|54|55|56|57 ->
        begin
          (lexbuf.Lexing.lex_mem).(17) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state106 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state108 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 58 -> __ocaml_lex_state109 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state109 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 46 -> __ocaml_lex_state112 lexbuf
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |192
                                |193
                                 |194
                                  |195
                                   |196
                                    |197
                                     |198
                                      |199
                                       |200
                                        |201
                                         |202
                                          |203
                                           |204
                                            |205
                                             |206
                                              |207
                                               |208
                                                |209
                                                 |210
                                                  |211
                                                   |212
                                                    |213
                                                     |214
                                                      |216
                                                       |217
                                                        |218|219|220|221|222
        -> __ocaml_lex_state111 lexbuf
    | 95
      |97
       |98
        |99
         |100
          |101
           |102
            |103
             |104
              |105
               |106
                |107
                 |108
                  |109
                   |110
                    |111
                     |112
                      |113
                       |114
                        |115
                         |116
                          |117
                           |118
                            |119
                             |120
                              |121
                               |122
                                |223
                                 |224
                                  |225
                                   |226
                                    |227
                                     |228
                                      |229
                                       |230
                                        |231
                                         |232
                                          |233
                                           |234
                                            |235
                                             |236
                                              |237
                                               |238
                                                |239
                                                 |240
                                                  |241
                                                   |242
                                                    |243
                                                     |244
                                                      |245
                                                       |246
                                                        |248
                                                         |249
                                                          |250
                                                           |251
                                                            |252|253|254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(18) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state110 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state110 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 124 ->
        begin
          (lexbuf.Lexing.lex_mem).(19) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state113 lexbuf
        end
    | 39
      |45
       |48
        |49
         |50
          |51
           |52
            |53
             |54
              |55
               |56
                |57
                 |65
                  |66
                   |67
                    |68
                     |69
                      |70
                       |71
                        |72
                         |73
                          |74
                           |75
                            |76
                             |77
                              |78
                               |79
                                |80
                                 |81
                                  |82
                                   |83
                                    |84
                                     |85
                                      |86
                                       |87
                                        |88
                                         |89
                                          |90
                                           |95
                                            |97
                                             |98
                                              |99
                                               |100
                                                |101
                                                 |102
                                                  |103
                                                   |104
                                                    |105
                                                     |106
                                                      |107
                                                       |108
                                                        |109
                                                         |110
                                                          |111
                                                           |112
                                                            |113
                                                             |114
                                                              |115
                                                               |116
                                                                |117
                                                                 |118
                                                                  |119
                                                                   |120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(18) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state110 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state111 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 46 -> __ocaml_lex_state112 lexbuf
    | 39
      |48
       |49
        |50
         |51
          |52
           |53
            |54
             |55
              |56
               |57
                |65
                 |66
                  |67
                   |68
                    |69
                     |70
                      |71
                       |72
                        |73
                         |74
                          |75
                           |76
                            |77
                             |78
                              |79
                               |80
                                |81
                                 |82
                                  |83
                                   |84
                                    |85
                                     |86
                                      |87
                                       |88
                                        |89
                                         |90
                                          |95
                                           |97
                                            |98
                                             |99
                                              |100
                                               |101
                                                |102
                                                 |103
                                                  |104
                                                   |105
                                                    |106
                                                     |107
                                                      |108
                                                       |109
                                                        |110
                                                         |111
                                                          |112
                                                           |113
                                                            |114
                                                             |115
                                                              |116
                                                               |117
                                                                |118
                                                                 |119
                                                                  |120
                                                                   |121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
        -> __ocaml_lex_state111 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state112 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 65
      |66
       |67
        |68
         |69
          |70
           |71
            |72
             |73
              |74
               |75
                |76
                 |77
                  |78
                   |79
                    |80
                     |81
                      |82
                       |83
                        |84
                         |85
                          |86
                           |87
                            |88
                             |89
                              |90
                               |192
                                |193
                                 |194
                                  |195
                                   |196
                                    |197
                                     |198
                                      |199
                                       |200
                                        |201
                                         |202
                                          |203
                                           |204
                                            |205
                                             |206
                                              |207
                                               |208
                                                |209
                                                 |210
                                                  |211
                                                   |212
                                                    |213
                                                     |214
                                                      |216
                                                       |217
                                                        |218|219|220|221|222
        -> __ocaml_lex_state111 lexbuf
    | 95
      |97
       |98
        |99
         |100
          |101
           |102
            |103
             |104
              |105
               |106
                |107
                 |108
                  |109
                   |110
                    |111
                     |112
                      |113
                       |114
                        |115
                         |116
                          |117
                           |118
                            |119
                             |120
                              |121
                               |122
                                |223
                                 |224
                                  |225
                                   |226
                                    |227
                                     |228
                                      |229
                                       |230
                                        |231
                                         |232
                                          |233
                                           |234
                                            |235
                                             |236
                                              |237
                                               |238
                                                |239
                                                 |240
                                                  |241
                                                   |242
                                                    |243
                                                     |244
                                                      |245
                                                       |246
                                                        |248
                                                         |249
                                                          |250
                                                           |251
                                                            |252|253|254|255
        ->
        begin
          (lexbuf.Lexing.lex_mem).(18) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state110 lexbuf
        end
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state113 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(18);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 22;
      (match __ocaml_lex_next_char lexbuf with
       | 33|37|38|43|45|46|47|58|61|63|64|92|94|126 ->
           __ocaml_lex_state114 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state114 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(19);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(18); 22
    end
  and __ocaml_lex_state115 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(3) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(4);
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(17);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 25;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state116 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state116 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(3) <- (-1);
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(4);
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(17); 25
    end
  and __ocaml_lex_state117 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 10 -> __ocaml_lex_state116 lexbuf
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | 13 -> __ocaml_lex_state115 lexbuf
    | _ -> __ocaml_lex_state117 lexbuf
  and __ocaml_lex_state118 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 10 -> __ocaml_lex_state116 lexbuf
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | 13 -> __ocaml_lex_state115 lexbuf
    | 34 -> __ocaml_lex_state120 lexbuf
    | _ ->
        begin
          (lexbuf.Lexing.lex_mem).(21) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state118 lexbuf
        end
  and __ocaml_lex_state119 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 9|32 -> __ocaml_lex_state119 lexbuf
    | 10 -> __ocaml_lex_state116 lexbuf
    | 34 ->
        begin
          (lexbuf.Lexing.lex_mem).(20) <- lexbuf.Lexing.lex_curr_pos;
          (lexbuf.Lexing.lex_mem).(21) <- lexbuf.Lexing.lex_curr_pos;
          __ocaml_lex_state118 lexbuf
        end
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | 13 -> __ocaml_lex_state115 lexbuf
    | _ -> __ocaml_lex_state117 lexbuf
  and __ocaml_lex_state120 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 10 -> __ocaml_lex_state122 lexbuf
    | 13 -> __ocaml_lex_state121 lexbuf
    | 256 ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
    | _ -> __ocaml_lex_state120 lexbuf
  and __ocaml_lex_state121 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(4);
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(17);
      (lexbuf.Lexing.lex_mem).(3) <- (lexbuf.Lexing.lex_mem).(20);
      (lexbuf.Lexing.lex_mem).(2) <- (lexbuf.Lexing.lex_mem).(21);
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 25;
      (match __ocaml_lex_next_char lexbuf with
       | 10 -> __ocaml_lex_state122 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state122 lexbuf =
    begin
      (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(4);
      (lexbuf.Lexing.lex_mem).(1) <- (lexbuf.Lexing.lex_mem).(17);
      (lexbuf.Lexing.lex_mem).(3) <- (lexbuf.Lexing.lex_mem).(20);
      (lexbuf.Lexing.lex_mem).(2) <- (lexbuf.Lexing.lex_mem).(21); 25
    end
  and __ocaml_lex_state123 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 46|60|61|62 -> __ocaml_lex_state123 lexbuf
    | 37|38|47|64|94 -> __ocaml_lex_state125 lexbuf
    | 58|124 -> __ocaml_lex_state124 lexbuf
    | 41|93 -> __ocaml_lex_state98 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state124 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 46|60|61|62 -> __ocaml_lex_state123 lexbuf
    | 37|38|47|64|94 -> __ocaml_lex_state125 lexbuf
    | 41 -> __ocaml_lex_state5 lexbuf
    | 58|124 -> __ocaml_lex_state124 lexbuf
    | 93 -> __ocaml_lex_state98 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state125 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 58|124 -> __ocaml_lex_state127 lexbuf
    | 37|38|46|47|60|61|62|64|94 -> __ocaml_lex_state125 lexbuf
    | 41|93 -> __ocaml_lex_state103 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state126 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 46|60|61|62 -> __ocaml_lex_state123 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state125 lexbuf
       | 58|124 -> __ocaml_lex_state124 lexbuf
       | 41|93 -> __ocaml_lex_state98 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state127 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 58|124 -> __ocaml_lex_state127 lexbuf
    | 37|38|46|47|60|61|62|64|94 -> __ocaml_lex_state125 lexbuf
    | 41|93 -> __ocaml_lex_state103 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state128 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 46|60|61|62 -> __ocaml_lex_state123 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state125 lexbuf
       | 41 -> __ocaml_lex_state5 lexbuf
       | 58|124 -> __ocaml_lex_state124 lexbuf
       | 93 -> __ocaml_lex_state98 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state129 lexbuf =
    match __ocaml_lex_next_char lexbuf with
    | 46|58|61|62|124 -> __ocaml_lex_state129 lexbuf
    | 37|38|47|64|94 -> __ocaml_lex_state131 lexbuf
    | 60 -> __ocaml_lex_state130 lexbuf
    | _ ->
        begin
          lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
          lexbuf.Lexing.lex_last_action
        end
  and __ocaml_lex_state130 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 46|58|61|62|124 -> __ocaml_lex_state129 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state131 lexbuf
       | 60 -> __ocaml_lex_state130 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state131 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 28;
      (match __ocaml_lex_next_char lexbuf with
       | 37|38|46|47|58|60|61|62|64|94|124 -> __ocaml_lex_state131 lexbuf
       | 40|91 -> __ocaml_lex_state64 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state132 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 37|38|46|47|60|61|62|64|94 -> __ocaml_lex_state8 lexbuf
       | 41|93 -> __ocaml_lex_state103 lexbuf
       | 58|124 -> __ocaml_lex_state132 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end
  and __ocaml_lex_state133 lexbuf =
    begin
      lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
      lexbuf.Lexing.lex_last_action <- 30;
      (match __ocaml_lex_next_char lexbuf with
       | 33|42|43|45|63|92|126 -> __ocaml_lex_state3 lexbuf
       | 46|60|61|62 -> __ocaml_lex_state6 lexbuf
       | 37|38|47|64|94 -> __ocaml_lex_state8 lexbuf
       | 58|124 -> __ocaml_lex_state133 lexbuf
       | 41 -> __ocaml_lex_state5 lexbuf
       | 93 -> __ocaml_lex_state98 lexbuf
       | _ ->
           begin
             lexbuf.Lexing.lex_curr_pos <- lexbuf.Lexing.lex_last_pos;
             lexbuf.Lexing.lex_last_action
           end)
    end in
  begin
    __ocaml_lex_init_lexbuf lexbuf 22;
    (let __ocaml_lex_result = __ocaml_lex_state0 lexbuf in
     begin
       lexbuf.Lexing.lex_start_p <- lexbuf.Lexing.lex_curr_p;
       lexbuf.Lexing.lex_curr_p <-
         {
           (lexbuf.Lexing.lex_curr_p) with
           Lexing.pos_cnum =
             (lexbuf.Lexing.lex_abs_pos + lexbuf.Lexing.lex_curr_pos)
         };
       (match __ocaml_lex_result with
        | 0 -> begin update_loc c; `NEWLINE end
        | 1 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            `BLANKS x
        | 2 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 1)
                (lexbuf.Lexing.lex_curr_pos + (-1)) in
            `LABEL x
        | 3 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 1)
                (lexbuf.Lexing.lex_curr_pos + (-1)) in
            `OPTLABEL x
        | 4 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            `Lid x
        | 5 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            `Uid x
        | 6 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            let cvt_int_literal s =
              let n = String.length s in
              match s.[n - 1] with
              | 'l' ->
                  `INT32 ((let open Int32 in neg (of_string ("-" ^ s))), s)
              | 'L' ->
                  `INT64 ((let open Int64 in neg (of_string ("-" ^ s))), s)
              | 'n' ->
                  `NATIVEINT
                    ((let open Nativeint in neg (of_string ("-" ^ s))), s)
              | _ -> `INT ((- (int_of_string ("-" ^ s))), s) in
            (try cvt_int_literal x
             with
             | Failure _ -> err (Literal_overflow x) (FLoc.of_lexbuf lexbuf))
        | 7 ->
            let f =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            (try `Flo ((float_of_string f), f)
             with
             | Failure _ -> err (Literal_overflow f) (FLoc.of_lexbuf lexbuf))
        | 8 ->
            begin
              with_curr_loc string c;
              (let s = buff_contents c in `STR ((TokenEval.string s), s))
            end
        | 9 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 1)
                (lexbuf.Lexing.lex_curr_pos + (-1)) in
            begin update_loc c ~retract:1; `CHAR ((TokenEval.char x), x) end
        | 10 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 1)
                (lexbuf.Lexing.lex_curr_pos + (-1)) in
            `CHAR ((TokenEval.char x), x)
        | 11 ->
            let c =
              Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 2) in
            err (Illegal_escape (String.make 1 c)) (FLoc.of_lexbuf lexbuf)
        | 12 ->
            begin
              store c;
              (let old = (c.lexbuf).lex_start_p in
               `COMMENT
                 (begin
                    with_curr_loc comment c; (c.lexbuf).lex_start_p <- old;
                    buff_contents c
                  end))
            end
        | 13 ->
            begin
              warn Comment_start (FLoc.of_lexbuf lexbuf); comment c c.lexbuf;
              `COMMENT (buff_contents c)
            end
        | 14 ->
            begin
              warn Comment_not_end (FLoc.of_lexbuf lexbuf);
              move_curr_p (-1) c; `SYMBOL "*"
            end
        | 15 ->
            let s =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_start_pos + 2) in
            `SYMBOL s
        | 16 ->
            let s =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_start_pos + 2) in
            `SYMBOL s
        | 17 ->
            let p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(1)) + 0)
            and beginning =
              Lexing.sub_lexeme lexbuf (((lexbuf.Lexing.lex_mem).(0)) + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            begin
              move_curr_p (- (String.length beginning)) c;
              Stack.push p opt_char;
              (let len = 2 + (opt_char_len p) in
               mk_quotation quotation c ~name:FToken.empty_name ~loc:""
                 ~shift:len ~retract:len)
            end
        | 18 -> `QUOTATION (FToken.empty_name, "", 2, "")
        | 19 ->
            let loc =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 2)
                (((lexbuf.Lexing.lex_mem).(0)) + 0)
            and p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(1)) + 0) in
            begin
              Stack.push p opt_char;
              mk_quotation quotation c ~name:FToken.empty_name ~loc
                ~shift:(((2 + 1) + (String.length loc)) + (opt_char_len p))
                ~retract:(2 + (opt_char_len p))
            end
        | 20 ->
            let c =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_start_pos + 3) in
            err (Illegal_quotation c) (FLoc.of_lexbuf lexbuf)
        | 21 ->
            let name =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 2)
                (((lexbuf.Lexing.lex_mem).(0)) + 0)
            and p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(1)) + 0) in
            let len = String.length name in
            let name =
              FToken.resolve_name (FLoc.of_lexbuf lexbuf)
                (FToken.name_of_string name) in
            begin
              Stack.push p opt_char;
              mk_quotation quotation c ~name ~loc:""
                ~shift:(((2 + 1) + len) + (opt_char_len p))
                ~retract:(2 + (opt_char_len p))
            end
        | 22 ->
            let name =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 3)
                (((lexbuf.Lexing.lex_mem).(0)) + 0)
            and p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(1)) + 0) in
            let len = String.length name in
            let () = Stack.push p opt_char in
            let retract = (opt_char_len p) + 2 in
            let old = (c.lexbuf).lex_start_p in
            let s =
              begin
                with_curr_loc quotation c; (c.lexbuf).lex_start_p <- old;
                buff_contents c
              end in
            let contents = String.sub s 0 ((String.length s) - retract) in
            `DirQuotation
              ((((3 + 1) + len) + (opt_char_len p)), name, contents)
        | 23 ->
            let name =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 2)
                (((lexbuf.Lexing.lex_mem).(0)) + 0)
            and loc =
              Lexing.sub_lexeme lexbuf (((lexbuf.Lexing.lex_mem).(0)) + 1)
                (((lexbuf.Lexing.lex_mem).(1)) + 0)
            and p =
              Lexing.sub_lexeme_char_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(2)) + 0) in
            let len = String.length name in
            let name =
              FToken.resolve_name (FLoc.of_lexbuf lexbuf)
                (FToken.name_of_string name) in
            begin
              Stack.push p opt_char;
              mk_quotation quotation c ~name ~loc
                ~shift:((((2 + 2) + (String.length loc)) + len) +
                          (opt_char_len p)) ~retract:(2 + (opt_char_len p))
            end
        | 24 ->
            let c =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_start_pos + 3) in
            err (Illegal_quotation c) (FLoc.of_lexbuf lexbuf)
        | 25 ->
            let num =
              Lexing.sub_lexeme lexbuf (((lexbuf.Lexing.lex_mem).(0)) + 0)
                (((lexbuf.Lexing.lex_mem).(1)) + 0)
            and name =
              Lexing.sub_lexeme_opt lexbuf
                (((lexbuf.Lexing.lex_mem).(3)) + 0)
                (((lexbuf.Lexing.lex_mem).(2)) + 0) in
            let inum = int_of_string num in
            begin
              update_loc c ?file:name ~line:inum ~absolute:true;
              `LINE_DIRECTIVE (inum, name)
            end
        | 26 ->
            let op =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 1)
                (((lexbuf.Lexing.lex_mem).(0)) + 0) in
            `ESCAPED_IDENT op
        | 27 ->
            let op =
              Lexing.sub_lexeme lexbuf (((lexbuf.Lexing.lex_mem).(0)) + 0)
                (((lexbuf.Lexing.lex_mem).(1)) + 0) in
            `ESCAPED_IDENT op
        | 28 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            `SYMBOL x
        | 29 ->
            let dollar c lexbuf =
              let rec __ocaml_lex_init_lexbuf lexbuf mem_size =
                let pos = lexbuf.Lexing.lex_curr_pos in
                begin
                  lexbuf.Lexing.lex_mem <- Array.create mem_size (-1);
                  lexbuf.Lexing.lex_start_pos <- pos;
                  lexbuf.Lexing.lex_last_pos <- pos;
                  lexbuf.Lexing.lex_last_action <- (-1)
                end
              and __ocaml_lex_next_char lexbuf =
                if lexbuf.Lexing.lex_curr_pos >= lexbuf.Lexing.lex_buffer_len
                then
                  (if lexbuf.Lexing.lex_eof_reached
                   then 256
                   else
                     begin
                       lexbuf.Lexing.refill_buff lexbuf;
                       __ocaml_lex_next_char lexbuf
                     end)
                else
                  (let i = lexbuf.Lexing.lex_curr_pos in
                   let c = (lexbuf.Lexing.lex_buffer).[i] in
                   begin lexbuf.Lexing.lex_curr_pos <- i + 1; Char.code c end)
              and __ocaml_lex_state0 lexbuf =
                match __ocaml_lex_next_char lexbuf with
                | 58 -> __ocaml_lex_state3 lexbuf
                | 95
                  |97
                   |98
                    |99
                     |100
                      |101
                       |102
                        |103
                         |104
                          |105
                           |106
                            |107
                             |108
                              |109
                               |110
                                |111
                                 |112
                                  |113
                                   |114
                                    |115
                                     |116
                                      |117
                                       |118
                                        |119
                                         |120
                                          |121
                                           |122
                                            |223
                                             |224
                                              |225
                                               |226
                                                |227
                                                 |228
                                                  |229
                                                   |230
                                                    |231
                                                     |232
                                                      |233
                                                       |234
                                                        |235
                                                         |236
                                                          |237
                                                           |238
                                                            |239
                                                             |240
                                                              |241
                                                               |242
                                                                |243
                                                                 |244
                                                                  |245
                                                                   |246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                    ->
                    begin
                      (lexbuf.Lexing.lex_mem).(1) <-
                      lexbuf.Lexing.lex_curr_pos; __ocaml_lex_state6 lexbuf
                    end
                | 33|46 ->
                    begin
                      (lexbuf.Lexing.lex_mem).(1) <-
                      lexbuf.Lexing.lex_curr_pos; __ocaml_lex_state4 lexbuf
                    end
                | 39
                  |48
                   |49
                    |50
                     |51
                      |52
                       |53
                        |54
                         |55
                          |56
                           |57
                            |65
                             |66
                              |67
                               |68
                                |69
                                 |70
                                  |71
                                   |72
                                    |73
                                     |74
                                      |75
                                       |76
                                        |77
                                         |78
                                          |79
                                           |80
                                            |81
                                             |82
                                              |83
                                               |84
                                                |85
                                                 |86
                                                  |87
                                                   |88
                                                    |89
                                                     |90
                                                      |192
                                                       |193
                                                        |194
                                                         |195
                                                          |196
                                                           |197
                                                            |198
                                                             |199
                                                              |200
                                                               |201
                                                                |202
                                                                 |203
                                                                  |204
                                                                   |205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221|222
                    ->
                    begin
                      (lexbuf.Lexing.lex_mem).(1) <-
                      lexbuf.Lexing.lex_curr_pos; __ocaml_lex_state5 lexbuf
                    end
                | 256 ->
                    begin
                      lexbuf.Lexing.lex_curr_pos <-
                        lexbuf.Lexing.lex_last_pos;
                      lexbuf.Lexing.lex_last_action
                    end
                | 96 ->
                    begin
                      (lexbuf.Lexing.lex_mem).(1) <-
                      lexbuf.Lexing.lex_curr_pos; __ocaml_lex_state7 lexbuf
                    end
                | 40 -> __ocaml_lex_state2 lexbuf
                | _ -> __ocaml_lex_state1 lexbuf
              and __ocaml_lex_state1 lexbuf = 4
              and __ocaml_lex_state2 lexbuf =
                begin
                  lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
                  lexbuf.Lexing.lex_last_action <- 3;
                  (match __ocaml_lex_next_char lexbuf with
                   | 33|46 -> __ocaml_lex_state13 lexbuf
                   | 96 -> __ocaml_lex_state15 lexbuf
                   | 39
                     |48
                      |49
                       |50
                        |51
                         |52
                          |53
                           |54
                            |55
                             |56
                              |57
                               |65
                                |66
                                 |67
                                  |68
                                   |69
                                    |70
                                     |71
                                      |72
                                       |73
                                        |74
                                         |75
                                          |76
                                           |77
                                            |78
                                             |79
                                              |80
                                               |81
                                                |82
                                                 |83
                                                  |84
                                                   |85
                                                    |86
                                                     |87
                                                      |88
                                                       |89
                                                        |90
                                                         |95
                                                          |97
                                                           |98
                                                            |99
                                                             |100
                                                              |101
                                                               |102
                                                                |103
                                                                 |104
                                                                  |105
                                                                   |106
                                                                    |
                                                                    107
                                                                    |
                                                                    108
                                                                    |
                                                                    109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                       -> __ocaml_lex_state14 lexbuf
                   | 58 -> __ocaml_lex_state12 lexbuf
                   | _ ->
                       begin
                         lexbuf.Lexing.lex_curr_pos <-
                           lexbuf.Lexing.lex_last_pos;
                         lexbuf.Lexing.lex_last_action
                       end)
                end
              and __ocaml_lex_state3 lexbuf =
                begin
                  lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
                  lexbuf.Lexing.lex_last_action <- 4;
                  (match __ocaml_lex_next_char lexbuf with
                   | 39
                     |48
                      |49
                       |50
                        |51
                         |52
                          |53
                           |54
                            |55
                             |56
                              |57
                               |65
                                |66
                                 |67
                                  |68
                                   |69
                                    |70
                                     |71
                                      |72
                                       |73
                                        |74
                                         |75
                                          |76
                                           |77
                                            |78
                                             |79
                                              |80
                                               |81
                                                |82
                                                 |83
                                                  |84
                                                   |85
                                                    |86
                                                     |87
                                                      |88
                                                       |89
                                                        |90
                                                         |95
                                                          |97
                                                           |98
                                                            |99
                                                             |100
                                                              |101
                                                               |102
                                                                |103
                                                                 |104
                                                                  |105
                                                                   |106
                                                                    |
                                                                    107
                                                                    |
                                                                    108
                                                                    |
                                                                    109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                       -> __ocaml_lex_state11 lexbuf
                   | _ ->
                       begin
                         lexbuf.Lexing.lex_curr_pos <-
                           lexbuf.Lexing.lex_last_pos;
                         lexbuf.Lexing.lex_last_action
                       end)
                end
              and __ocaml_lex_state4 lexbuf =
                begin
                  lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
                  lexbuf.Lexing.lex_last_action <- 4;
                  (match __ocaml_lex_next_char lexbuf with
                   | 33|46 ->
                       begin
                         (lexbuf.Lexing.lex_mem).(1) <-
                         lexbuf.Lexing.lex_curr_pos;
                         __ocaml_lex_state9 lexbuf
                       end
                   | 58 -> __ocaml_lex_state8 lexbuf
                   | _ ->
                       begin
                         lexbuf.Lexing.lex_curr_pos <-
                           lexbuf.Lexing.lex_last_pos;
                         lexbuf.Lexing.lex_last_action
                       end)
                end
              and __ocaml_lex_state5 lexbuf =
                begin
                  lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
                  lexbuf.Lexing.lex_last_action <- 4;
                  (match __ocaml_lex_next_char lexbuf with
                   | 58 -> __ocaml_lex_state8 lexbuf
                   | 39
                     |48
                      |49
                       |50
                        |51
                         |52
                          |53
                           |54
                            |55
                             |56
                              |57
                               |65
                                |66
                                 |67
                                  |68
                                   |69
                                    |70
                                     |71
                                      |72
                                       |73
                                        |74
                                         |75
                                          |76
                                           |77
                                            |78
                                             |79
                                              |80
                                               |81
                                                |82
                                                 |83
                                                  |84
                                                   |85
                                                    |86
                                                     |87
                                                      |88
                                                       |89
                                                        |90
                                                         |95
                                                          |97
                                                           |98
                                                            |99
                                                             |100
                                                              |101
                                                               |102
                                                                |103
                                                                 |104
                                                                  |105
                                                                   |106
                                                                    |
                                                                    107
                                                                    |
                                                                    108
                                                                    |
                                                                    109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                       ->
                       begin
                         (lexbuf.Lexing.lex_mem).(1) <-
                         lexbuf.Lexing.lex_curr_pos;
                         __ocaml_lex_state10 lexbuf
                       end
                   | _ ->
                       begin
                         lexbuf.Lexing.lex_curr_pos <-
                           lexbuf.Lexing.lex_last_pos;
                         lexbuf.Lexing.lex_last_action
                       end)
                end
              and __ocaml_lex_state6 lexbuf =
                begin
                  lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
                  lexbuf.Lexing.lex_last_action <- 1;
                  (match __ocaml_lex_next_char lexbuf with
                   | 39
                     |48
                      |49
                       |50
                        |51
                         |52
                          |53
                           |54
                            |55
                             |56
                              |57
                               |65
                                |66
                                 |67
                                  |68
                                   |69
                                    |70
                                     |71
                                      |72
                                       |73
                                        |74
                                         |75
                                          |76
                                           |77
                                            |78
                                             |79
                                              |80
                                               |81
                                                |82
                                                 |83
                                                  |84
                                                   |85
                                                    |86
                                                     |87
                                                      |88
                                                       |89
                                                        |90
                                                         |95
                                                          |97
                                                           |98
                                                            |99
                                                             |100
                                                              |101
                                                               |102
                                                                |103
                                                                 |104
                                                                  |105
                                                                   |106
                                                                    |
                                                                    107
                                                                    |
                                                                    108
                                                                    |
                                                                    109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                       ->
                       begin
                         (lexbuf.Lexing.lex_mem).(1) <-
                         lexbuf.Lexing.lex_curr_pos;
                         __ocaml_lex_state6 lexbuf
                       end
                   | 58 -> __ocaml_lex_state8 lexbuf
                   | _ ->
                       begin
                         lexbuf.Lexing.lex_curr_pos <-
                           lexbuf.Lexing.lex_last_pos;
                         lexbuf.Lexing.lex_last_action
                       end)
                end
              and __ocaml_lex_state7 lexbuf =
                begin
                  lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
                  lexbuf.Lexing.lex_last_action <- 4;
                  (match __ocaml_lex_next_char lexbuf with
                   | 33|46 ->
                       begin
                         (lexbuf.Lexing.lex_mem).(1) <-
                         lexbuf.Lexing.lex_curr_pos;
                         __ocaml_lex_state9 lexbuf
                       end
                   | 58 -> __ocaml_lex_state8 lexbuf
                   | 39
                     |48
                      |49
                       |50
                        |51
                         |52
                          |53
                           |54
                            |55
                             |56
                              |57
                               |65
                                |66
                                 |67
                                  |68
                                   |69
                                    |70
                                     |71
                                      |72
                                       |73
                                        |74
                                         |75
                                          |76
                                           |77
                                            |78
                                             |79
                                              |80
                                               |81
                                                |82
                                                 |83
                                                  |84
                                                   |85
                                                    |86
                                                     |87
                                                      |88
                                                       |89
                                                        |90
                                                         |95
                                                          |97
                                                           |98
                                                            |99
                                                             |100
                                                              |101
                                                               |102
                                                                |103
                                                                 |104
                                                                  |105
                                                                   |106
                                                                    |
                                                                    107
                                                                    |
                                                                    108
                                                                    |
                                                                    109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                       ->
                       begin
                         (lexbuf.Lexing.lex_mem).(1) <-
                         lexbuf.Lexing.lex_curr_pos;
                         __ocaml_lex_state10 lexbuf
                       end
                   | _ ->
                       begin
                         lexbuf.Lexing.lex_curr_pos <-
                           lexbuf.Lexing.lex_last_pos;
                         lexbuf.Lexing.lex_last_action
                       end)
                end
              and __ocaml_lex_state8 lexbuf =
                match __ocaml_lex_next_char lexbuf with
                | 39
                  |48
                   |49
                    |50
                     |51
                      |52
                       |53
                        |54
                         |55
                          |56
                           |57
                            |65
                             |66
                              |67
                               |68
                                |69
                                 |70
                                  |71
                                   |72
                                    |73
                                     |74
                                      |75
                                       |76
                                        |77
                                         |78
                                          |79
                                           |80
                                            |81
                                             |82
                                              |83
                                               |84
                                                |85
                                                 |86
                                                  |87
                                                   |88
                                                    |89
                                                     |90
                                                      |95
                                                       |97
                                                        |98
                                                         |99
                                                          |100
                                                           |101
                                                            |102
                                                             |103
                                                              |104
                                                               |105
                                                                |106
                                                                 |107
                                                                  |108
                                                                   |109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                    -> __ocaml_lex_state11 lexbuf
                | _ ->
                    begin
                      lexbuf.Lexing.lex_curr_pos <-
                        lexbuf.Lexing.lex_last_pos;
                      lexbuf.Lexing.lex_last_action
                    end
              and __ocaml_lex_state9 lexbuf =
                match __ocaml_lex_next_char lexbuf with
                | 33|46 ->
                    begin
                      (lexbuf.Lexing.lex_mem).(1) <-
                      lexbuf.Lexing.lex_curr_pos; __ocaml_lex_state9 lexbuf
                    end
                | 58 -> __ocaml_lex_state8 lexbuf
                | _ ->
                    begin
                      lexbuf.Lexing.lex_curr_pos <-
                        lexbuf.Lexing.lex_last_pos;
                      lexbuf.Lexing.lex_last_action
                    end
              and __ocaml_lex_state10 lexbuf =
                match __ocaml_lex_next_char lexbuf with
                | 58 -> __ocaml_lex_state8 lexbuf
                | 39
                  |48
                   |49
                    |50
                     |51
                      |52
                       |53
                        |54
                         |55
                          |56
                           |57
                            |65
                             |66
                              |67
                               |68
                                |69
                                 |70
                                  |71
                                   |72
                                    |73
                                     |74
                                      |75
                                       |76
                                        |77
                                         |78
                                          |79
                                           |80
                                            |81
                                             |82
                                              |83
                                               |84
                                                |85
                                                 |86
                                                  |87
                                                   |88
                                                    |89
                                                     |90
                                                      |95
                                                       |97
                                                        |98
                                                         |99
                                                          |100
                                                           |101
                                                            |102
                                                             |103
                                                              |104
                                                               |105
                                                                |106
                                                                 |107
                                                                  |108
                                                                   |109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                    ->
                    begin
                      (lexbuf.Lexing.lex_mem).(1) <-
                      lexbuf.Lexing.lex_curr_pos; __ocaml_lex_state10 lexbuf
                    end
                | _ ->
                    begin
                      lexbuf.Lexing.lex_curr_pos <-
                        lexbuf.Lexing.lex_last_pos;
                      lexbuf.Lexing.lex_last_action
                    end
              and __ocaml_lex_state11 lexbuf =
                begin
                  (lexbuf.Lexing.lex_mem).(0) <- (lexbuf.Lexing.lex_mem).(1);
                  lexbuf.Lexing.lex_last_pos <- lexbuf.Lexing.lex_curr_pos;
                  lexbuf.Lexing.lex_last_action <- 0;
                  (match __ocaml_lex_next_char lexbuf with
                   | 39
                     |48
                      |49
                       |50
                        |51
                         |52
                          |53
                           |54
                            |55
                             |56
                              |57
                               |65
                                |66
                                 |67
                                  |68
                                   |69
                                    |70
                                     |71
                                      |72
                                       |73
                                        |74
                                         |75
                                          |76
                                           |77
                                            |78
                                             |79
                                              |80
                                               |81
                                                |82
                                                 |83
                                                  |84
                                                   |85
                                                    |86
                                                     |87
                                                      |88
                                                       |89
                                                        |90
                                                         |95
                                                          |97
                                                           |98
                                                            |99
                                                             |100
                                                              |101
                                                               |102
                                                                |103
                                                                 |104
                                                                  |105
                                                                   |106
                                                                    |
                                                                    107
                                                                    |
                                                                    108
                                                                    |
                                                                    109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                       -> __ocaml_lex_state11 lexbuf
                   | _ ->
                       begin
                         lexbuf.Lexing.lex_curr_pos <-
                           lexbuf.Lexing.lex_last_pos;
                         lexbuf.Lexing.lex_last_action
                       end)
                end
              and __ocaml_lex_state12 lexbuf = 2
              and __ocaml_lex_state13 lexbuf =
                match __ocaml_lex_next_char lexbuf with
                | 33|46 -> __ocaml_lex_state13 lexbuf
                | 58 -> __ocaml_lex_state12 lexbuf
                | _ ->
                    begin
                      lexbuf.Lexing.lex_curr_pos <-
                        lexbuf.Lexing.lex_last_pos;
                      lexbuf.Lexing.lex_last_action
                    end
              and __ocaml_lex_state14 lexbuf =
                match __ocaml_lex_next_char lexbuf with
                | 39
                  |48
                   |49
                    |50
                     |51
                      |52
                       |53
                        |54
                         |55
                          |56
                           |57
                            |65
                             |66
                              |67
                               |68
                                |69
                                 |70
                                  |71
                                   |72
                                    |73
                                     |74
                                      |75
                                       |76
                                        |77
                                         |78
                                          |79
                                           |80
                                            |81
                                             |82
                                              |83
                                               |84
                                                |85
                                                 |86
                                                  |87
                                                   |88
                                                    |89
                                                     |90
                                                      |95
                                                       |97
                                                        |98
                                                         |99
                                                          |100
                                                           |101
                                                            |102
                                                             |103
                                                              |104
                                                               |105
                                                                |106
                                                                 |107
                                                                  |108
                                                                   |109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                    -> __ocaml_lex_state14 lexbuf
                | 58 -> __ocaml_lex_state12 lexbuf
                | _ ->
                    begin
                      lexbuf.Lexing.lex_curr_pos <-
                        lexbuf.Lexing.lex_last_pos;
                      lexbuf.Lexing.lex_last_action
                    end
              and __ocaml_lex_state15 lexbuf =
                match __ocaml_lex_next_char lexbuf with
                | 33|46 -> __ocaml_lex_state13 lexbuf
                | 39
                  |48
                   |49
                    |50
                     |51
                      |52
                       |53
                        |54
                         |55
                          |56
                           |57
                            |65
                             |66
                              |67
                               |68
                                |69
                                 |70
                                  |71
                                   |72
                                    |73
                                     |74
                                      |75
                                       |76
                                        |77
                                         |78
                                          |79
                                           |80
                                            |81
                                             |82
                                              |83
                                               |84
                                                |85
                                                 |86
                                                  |87
                                                   |88
                                                    |89
                                                     |90
                                                      |95
                                                       |97
                                                        |98
                                                         |99
                                                          |100
                                                           |101
                                                            |102
                                                             |103
                                                              |104
                                                               |105
                                                                |106
                                                                 |107
                                                                  |108
                                                                   |109
                                                                    |
                                                                    110
                                                                    |
                                                                    111
                                                                    |
                                                                    112
                                                                    |
                                                                    113
                                                                    |
                                                                    114
                                                                    |
                                                                    115
                                                                    |
                                                                    116
                                                                    |
                                                                    117
                                                                    |
                                                                    118
                                                                    |
                                                                    119
                                                                    |
                                                                    120
                                                                    |
                                                                    121
                                                                    |
                                                                    122
                                                                    |
                                                                    192
                                                                    |
                                                                    193
                                                                    |
                                                                    194
                                                                    |
                                                                    195
                                                                    |
                                                                    196
                                                                    |
                                                                    197
                                                                    |
                                                                    198
                                                                    |
                                                                    199
                                                                    |
                                                                    200
                                                                    |
                                                                    201
                                                                    |
                                                                    202
                                                                    |
                                                                    203
                                                                    |
                                                                    204
                                                                    |
                                                                    205
                                                                    |
                                                                    206
                                                                    |
                                                                    207
                                                                    |
                                                                    208
                                                                    |
                                                                    209
                                                                    |
                                                                    210
                                                                    |
                                                                    211
                                                                    |
                                                                    212
                                                                    |
                                                                    213
                                                                    |
                                                                    214
                                                                    |
                                                                    216
                                                                    |
                                                                    217
                                                                    |
                                                                    218
                                                                    |
                                                                    219
                                                                    |
                                                                    220
                                                                    |
                                                                    221
                                                                    |
                                                                    222
                                                                    |
                                                                    223
                                                                    |
                                                                    224
                                                                    |
                                                                    225
                                                                    |
                                                                    226
                                                                    |
                                                                    227
                                                                    |
                                                                    228
                                                                    |
                                                                    229
                                                                    |
                                                                    230
                                                                    |
                                                                    231
                                                                    |
                                                                    232
                                                                    |
                                                                    233
                                                                    |
                                                                    234
                                                                    |
                                                                    235
                                                                    |
                                                                    236
                                                                    |
                                                                    237
                                                                    |
                                                                    238
                                                                    |
                                                                    239
                                                                    |
                                                                    240
                                                                    |
                                                                    241
                                                                    |
                                                                    242
                                                                    |
                                                                    243
                                                                    |
                                                                    244
                                                                    |
                                                                    245
                                                                    |
                                                                    246
                                                                    |
                                                                    248
                                                                    |
                                                                    249
                                                                    |
                                                                    250
                                                                    |
                                                                    251
                                                                    |
                                                                    252
                                                                    |
                                                                    253
                                                                    |
                                                                    254|255
                    -> __ocaml_lex_state14 lexbuf
                | 58 -> __ocaml_lex_state12 lexbuf
                | _ ->
                    begin
                      lexbuf.Lexing.lex_curr_pos <-
                        lexbuf.Lexing.lex_last_pos;
                      lexbuf.Lexing.lex_last_action
                    end in
              begin
                begin
                  __ocaml_lex_init_lexbuf lexbuf 2;
                  (lexbuf.Lexing.lex_mem).(1) <- lexbuf.Lexing.lex_curr_pos
                end;
                (let __ocaml_lex_result = __ocaml_lex_state0 lexbuf in
                 begin
                   lexbuf.Lexing.lex_start_p <- lexbuf.Lexing.lex_curr_p;
                   lexbuf.Lexing.lex_curr_p <-
                     {
                       (lexbuf.Lexing.lex_curr_p) with
                       Lexing.pos_cnum =
                         (lexbuf.Lexing.lex_abs_pos +
                            lexbuf.Lexing.lex_curr_pos)
                     };
                   (match __ocaml_lex_result with
                    | 0 ->
                        let name =
                          Lexing.sub_lexeme lexbuf
                            (lexbuf.Lexing.lex_start_pos + 0)
                            (((lexbuf.Lexing.lex_mem).(0)) + 0)
                        and x =
                          Lexing.sub_lexeme lexbuf
                            (((lexbuf.Lexing.lex_mem).(0)) + 1)
                            (lexbuf.Lexing.lex_curr_pos + 0) in
                        begin
                          move_start_p ((String.length name) + 1) c;
                          `Ant (name, x)
                        end
                    | 1 ->
                        let x =
                          Lexing.sub_lexeme lexbuf
                            (lexbuf.Lexing.lex_start_pos + 0)
                            (lexbuf.Lexing.lex_curr_pos + 0) in
                        `Ant ("", x)
                    | 2 ->
                        let name =
                          Lexing.sub_lexeme lexbuf
                            (lexbuf.Lexing.lex_start_pos + 1)
                            (lexbuf.Lexing.lex_curr_pos + (-1)) in
                        antiquot name 0
                          {
                            c with
                            loc =
                              (FLoc.move_pos (3 + (String.length name)) c.loc)
                          } c.lexbuf
                    | 3 ->
                        antiquot "" 0
                          { c with loc = (FLoc.move_pos 2 c.loc) } c.lexbuf
                    | 4 ->
                        let c =
                          Lexing.sub_lexeme_char lexbuf
                            (lexbuf.Lexing.lex_start_pos + 0) in
                        err (Illegal_character c) (FLoc.of_lexbuf lexbuf)
                    | _ -> failwith "lexing: empty token")
                 end)
              end in
            if c.antiquots
            then with_curr_loc dollar c
            else err Illegal_antiquote (FLoc.of_lexbuf lexbuf)
        | 30 ->
            let x =
              Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 0)
                (lexbuf.Lexing.lex_curr_pos + 0) in
            `SYMBOL x
        | 31 ->
            let pos = lexbuf.lex_curr_p in
            begin
              lexbuf.lex_curr_p <-
                {
                  pos with
                  pos_bol = (pos.pos_bol + 1);
                  pos_cnum = (pos.pos_cnum + 1)
                };
              `EOI
            end
        | 32 ->
            let c =
              Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 0) in
            err (Illegal_character c) (FLoc.of_lexbuf lexbuf)
        | _ -> failwith "lexing: empty token")
     end)
  end