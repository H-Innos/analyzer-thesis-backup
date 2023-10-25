(** SV-COMP specification strings and files. *)

open Batteries

type t =
  | UnreachCall of string
  | NoDataRace
  | NoOverflow
  | ValidFree
  | ValidDeref
  | ValidMemtrack
  | MemorySafety (* Internal property for use in Goblint; serves as a summary for ValidFree, ValidDeref and ValidMemtrack *)
  | ValidMemcleanup

let of_string s =
  let s = String.strip s in
  let regexp_multiple = Str.regexp "CHECK( init(main()), LTL(G \\(.*\\)) )\nCHECK( init(main()), LTL(G \\(.*\\)) )\nCHECK( init(main()), LTL(G \\(.*\\)) )" in
  let regexp_single = Str.regexp "CHECK( init(main()), LTL(G \\(.*\\)) )" in
  let regexp_negated = Str.regexp "CHECK( init(main()), LTL(G ! \\(.*\\)) )" in
  if Str.string_match regexp_negated s 0 then
    let global_not = Str.matched_group 1 s in
    if global_not = "data-race" then
      NoDataRace
    else if global_not = "overflow" then
      NoOverflow
    else
      let call_regex = Str.regexp "call(\\(.*\\)())" in
      if Str.string_match call_regex global_not 0 then
        let f = Str.matched_group 1 global_not in
        UnreachCall f
      else
        failwith "Svcomp.Specification.of_string: unknown global not expression"
  else if Str.string_match regexp_multiple s 0 then
    let global1 = Str.matched_group 1 s in
    let global2 = Str.matched_group 2 s in
    let global3 = Str.matched_group 3 s in
    let mem_safety_props = ["valid-free"; "valid-deref"; "valid-memtrack";] in
    if (global1 <> global2 && global1 <> global3 && global2 <> global3) && List.for_all (fun x -> List.mem x mem_safety_props) [global1; global2; global3] then
      MemorySafety
    else
      failwith "Svcomp.Specification.of_string: unknown global expression"
  else if Str.string_match regexp_single s 0 then
    let global = Str.matched_group 1 s in
    if global = "valid-memcleanup" then
      ValidMemcleanup
    else
      failwith "Svcomp.Specification.of_string: unknown global expression"
  else
    failwith "Svcomp.Specification.of_string: unknown expression"

let of_file path =
  let s = BatFile.with_file_in path BatIO.read_all in
  of_string s

let of_option () =
  let s = GobConfig.get_string "ana.specification" in
  if Sys.file_exists s then
    of_file s
  else
    of_string s

let to_string spec =
  let print_output spec_str is_neg =
    if is_neg then
      Printf.sprintf "CHECK( init(main()), LTL(G ! %s) )" spec_str
    else
      Printf.sprintf "CHECK( init(main()), LTL(G %s) )" spec_str
  in
  let spec_str, is_neg = match spec with
    | UnreachCall f -> "call(" ^ f ^ "())", true
    | NoDataRace -> "data-race", true
    | NoOverflow -> "overflow", true
    | ValidFree -> "valid-free", false
    | ValidDeref -> "valid-deref", false
    | ValidMemtrack -> "valid-memtrack", false
    | MemorySafety -> "memory-safety", false (* TODO: That's false, it's currently here just to complete the pattern match *)
    | ValidMemcleanup -> "valid-memcleanup", false
  in
  print_output spec_str is_neg
