open FAst

type name =  {
  exp: exp;
  tvar: string;
  loc: loc} 

type styp =
  [ vid' | `App of (loc * styp * styp)
  | `Quote of (loc * position_flag * alident) | `Self of loc | `Tok of loc
  | `Type of ctyp] 

type entry =  {
  name: name;
  pos: exp option;
  local: bool;
  levels: levels} 
and levels = [ `Group of level list | `Single of level] 
and level =  {
  label: string option;
  assoc: exp option;
  rules: rule list} 
and rule =  {
  prod: symbol list;
  action: exp option} 
and symbol =  {
  text: text;
  styp: styp;
  pattern: pat option} 
and text =
  [ `Slist of (loc * bool * symbol * symbol option)
  | `Snterm of (loc * name * string option) | `Sopt of (loc * text)
  | `Stry of (loc * text) | `Speek of (loc * text) | `Sself of loc
  | `Skeyword of (loc * string) | `Stok of (loc * exp * FAstN.pat)] 

type used =  
  | Unused
  | UsedScanned
  | UsedNotScanned 

type simple_pat =
  [ `Vrn of (loc * string) | `App of (loc * simple_pat * simple_pat) | 
    vid
  | `Com of (loc * simple_pat * simple_pat)
  | `Alias of (loc * simple_pat * alident)
  | `Bar of (loc * simple_pat * simple_pat) | `Str of (loc * string)
  | `Any of loc | ant] 

type action_pattern =
  [ vid | `Com of (loc * action_pattern * action_pattern)
  | `Par of (loc * action_pattern) | `Any of loc] 