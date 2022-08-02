(** Abstract domains with Hoare ordering. *)

open Pretty

exception Unsupported of string
let unsupported s = raise (Unsupported s)

(* Hoare hash set for partial orders: keeps incomparable elements separate
   - All comparable elements must have the same hash so that they land in the same bucket!
   - Pairwise operations like join then only need to be done per bucket.
   - E should throw Lattice.Incomparable if an operation is not defined for two elements.
     In this case the operation will be done on the level of the set instead.
   - Hoare set means that for comparable elements, we only keep the biggest one.
     -> We only need to find the first comparable element for a join etc.
     -> There should only be one element per bucket except for hash collisions.
*)
module HoarePO (E : Lattice.PO) =
struct
  open Batteries
  type bucket = E.t list
  type t = bucket Map.Int.t
  module Map = Map.Int

  module B = struct (* bucket *)
    (* join element e with bucket using op *)
    let rec join op e = function
      | [] -> [e]
      | x::xs -> try op e x :: xs with Lattice.Uncomparable -> x :: join op e xs

    (* widen new(!) element e with old(!) bucket using op *)
    let rec widen op e = function
      | [] -> []
      | x::xs -> try if E.leq x e then [op x e] else widen op e xs with Lattice.Uncomparable -> widen op e xs (* only widen if valid *)

    (* meet element e with bucket using op *)
    let rec meet op e = function
      | [] -> []
      | x::xs -> try [op e x] with Lattice.Uncomparable -> meet op e xs

    (* merge element e into its bucket in m using f, discard bucket if empty *)
    let merge_element f e m =
      let i = E.hash e in
      let b = f e (Map.find_default [] i m) in
      if b = [] then Map.remove i m
      else Map.add i b m
  end

  let elements m = Map.values m |> List.of_enum |> List.flatten

  (* merge elements in x and y by f *)
  (* TODO: unused, remove? *)
  let merge op f x y =
    let g = match op with
      | `Join -> B.join
      | `Meet -> B.meet
    in
    Map.merge (fun i a b -> match a, b with
        | Some a, Some b ->
          let r = List.fold_left (flip (g f)) a b in
          if r = [] then None else Some r
        | Some x, None
        | None, Some x when op = `Join -> Some x
        | _ -> None
      ) x y

  let merge_meet f x y =
    Map.merge (fun i a b -> match a, b with
        | Some a, Some b ->
          let r = List.concat_map (fun x -> B.meet f x a) b in
          if r = [] then None else Some r
        | _ -> None
      ) x y
  let merge_widen f x y =
    Map.merge (fun i a b -> match a, b with
        | Some a, Some b ->
          let r = List.concat_map (fun x -> B.widen f x a) b in
          let r = List.fold_left (fun r x -> B.join E.join x r) r b in (* join b per bucket *)
          if r = [] then None else Some r
        | None, Some b -> Some b (* join b per bucket *)
        | _ -> None
      ) x y

  (* join all elements from the smaller map into their bucket in the other one.
   * this doesn't need to go over all elements of both maps as the general merge above. *)
  let merge_join f x y =
    let x, y = if Map.cardinal x < Map.cardinal y then x, y else y, x in
    List.fold_left (flip (B.merge_element (B.join f))) y (elements x)

  let join   x y = merge_join E.join x y
  let widen  x y = merge_widen E.widen x y
  let meet   x y = merge_meet E.meet x y
  let narrow x y = merge_meet E.narrow x y (* TODO: fix narrow like widen? see Set *)

  (* Set *)
  let of_list_by f es = List.fold_left (flip (B.merge_element (B.join f))) Map.empty es
  let of_list es = of_list_by E.join es
  let singleton e = of_list [e]
  let exists p m = List.exists p (elements m)
  let for_all p m = List.for_all p (elements m)
  let mem e m = exists (E.leq e) m
  let choose m = List.hd (snd (Map.choose m))
  let apply_list f m = of_list (f (elements m))
  let map f m =
    (* Map.map (List.map f) m *)
    (* since hashes might change we need to rebuild: *)
    apply_list (List.map f) m
  let filter f m = apply_list (List.filter f) m (* TODO do something better? unused *)
  let remove x m =
    let ngreq x y = not (E.leq y x) in
    B.merge_element (fun _ -> List.filter (ngreq x)) x m
  (* let add e m = if mem e m then m else B.merge List.cons e m *)
  let add e m = if mem e m then m else join (singleton e) m
  let fold f m a = Map.fold (fun _ -> List.fold_right f) m a
  let cardinal m = fold (const succ) m 0
  let diff a b = apply_list (List.filter (fun x -> not (mem x b))) a
  let empty () = Map.empty
  let is_empty m = Map.is_empty m
  (* let union x y = merge (B.join keep_apart) x y *)
  let union x y = join x y
  let iter f m = Map.iter (fun _ -> List.iter f) m

  (* Lattice *)
  let bot () = Map.empty
  let is_bot = Map.is_empty
  let top () = unsupported "HoarePO.top"
  let is_top _ = false
  let leq x y = (* all elements in x must be leq than the ones in y *)
    for_all (flip mem y) x

  (* Printable *)
  let name () = "Set (" ^ E.name () ^ ")"
  (* let equal x y = try Map.equal (List.for_all2 E.equal) x y with Invalid_argument _ -> false *)
  let equal x y = leq x y && leq y x
  let hash xs = fold (fun v a -> a + E.hash v) xs 0
  let compare x y =
    if equal x y
      then 0
      else
        let caridnality_comp = compare (cardinal x) (cardinal y) in
        if caridnality_comp <> 0
          then caridnality_comp
          else Map.compare (List.compare E.compare) x y
  let show x : string =
    let all_elems : string list = List.map E.show (elements x) in
    Printable.get_short_list "{" "}" all_elems

  let to_yojson x = [%to_yojson: E.t list] (elements x)

  let pretty () x =
    let content = List.map (E.pretty ()) (elements x) in
    let rec separate x =
      match x with
      | [] -> []
      | [x] -> [x]
      | (x::xs) -> x ++ (text ", ") :: separate xs
    in
    let separated = separate content in
    let content = List.fold_left (++) nil separated in
    (text "{") ++ content ++ (text "}")

  let pretty_diff () ((x:t),(y:t)): Pretty.doc =
    Pretty.dprintf "HoarePO: %a not leq %a" pretty x pretty y
  let printXml f x =
    BatPrintf.fprintf f "<value>\n<set>\n";
    List.iter (E.printXml f) (elements x);
    BatPrintf.fprintf f "</set>\n</value>\n"
end
[@@deprecated]


module type SetS =
sig
  include SetDomain.S
  val apply_list: (elt list -> elt list) -> t -> t
end

(** Set of [Lattice] elements with Hoare ordering. *)
module Set (B : Lattice.S): SetS with type elt = B.t =
struct
  include SetDomain.Make (B)

  let mem x s = exists (B.leq x) s
  let leq a b = for_all (fun x -> mem x b) a (* mem uses B.leq! *)
  let le x y = B.leq x y && not (B.equal x y) && not (B.leq y x)
  let reduce s = filter (fun x -> not (exists (le x) s)) s
  let product_bot op a b =
    let a,b = elements a, elements b in
    List.concat_map (fun x -> List.map (fun y -> op x y) b) a |> fun x -> reduce (of_list x)
  let product_widen op a b = (* assumes b to be bigger than a *)
    let xs,ys = elements a, elements b in
    List.concat_map (fun x -> List.map (fun y -> op x y) ys) xs |> fun x -> reduce (union b (of_list x))
  let widen = product_widen (fun x y -> if B.leq x y then B.widen x y else B.bot ())
  let narrow = product_bot (fun x y -> if B.leq y x then B.narrow x y else x)

  let add x a = if mem x a then a else add x a (* special mem! *)
  let remove x a = filter (fun y -> not (B.leq y x)) a
  let join a b = union a b |> reduce
  let union _ _ = unsupported "Set.union"
  let inter _ _ = unsupported "Set.inter"
  let meet = product_bot B.meet
  let subset _ _ = unsupported "Set.subset"
  let map f a = map f a |> reduce
  let min_elt a = B.bot ()
  let apply_list f s = elements s |> f |> of_list
  let diff a b = apply_list (List.filter (fun x -> not (mem x b))) a
  let of_list xs = List.fold_right add xs (empty ()) |> reduce (* TODO: why not use Make's of_list if reduce anyway, right now add also is special *)

  (* Copied from Make *)
  let arbitrary () = QCheck.map ~rev:elements of_list @@ QCheck.small_list (B.arbitrary ())

  let pretty_diff () ((s1:t),(s2:t)): Pretty.doc =
    if leq s1 s2 then dprintf "%s (%d and %d paths): These are fine!" (name ()) (cardinal s1) (cardinal s2) else begin
      try
        let p t = not (mem t s2) in
        let evil = choose (filter p s1) in
        dprintf "%a:\n" B.pretty evil
        ++
        if is_empty s2 then
          text "empty set s2"
        else
          fold (fun other acc ->
              (dprintf "not leq %a because %a\n" B.pretty other B.pretty_diff (evil, other)) ++ acc
            ) s2 nil
      with Not_found ->
        dprintf "choose failed b/c of empty set s1: %d s2: %d"
        (cardinal s1)
        (cardinal s2)
    end
end


module Set_LiftTop (B : Lattice.S) (N: SetDomain.ToppedSetNames): SetS with type elt = B.t =
struct
  module S = Set (B)
  include SetDomain.LiftTop (S) (N)

  let min_elt a = B.bot ()
  let apply_list f = function
    | `Top -> `Top
    | `Lifted s -> `Lifted (S.apply_list f s)
end


(* TODO: weaken R to Lattice.S ? *)
module MapBot (SpecD:Lattice.S) (R:SetDomain.S) =
struct
  module SpecDGroupable =
  struct
    include Printable.Std
    include SpecD
  end
  include MapDomain.MapBot (SpecDGroupable) (R)

  (* TODO: get rid of these value-ignoring set-mimicing hacks *)
  let choose' = choose
  let choose (s: t): SpecD.t = fst (choose' s)
  let filter' = filter
  let filter (p: key -> bool) (s: t): t = filter (fun x _ -> p x) s
  let iter' = iter
  let for_all' = for_all
  let exists' = exists
  let exists (p: key -> bool) (s: t): bool = exists (fun x _ -> p x) s
  let fold' = fold
  let fold (f: key -> 'a -> 'a) (s: t) (acc: 'a): 'a = fold (fun x _ acc -> f x acc) s acc
  let add (x: key) (r: R.t) (s: t): t = add x (R.join r (find x s)) s
  let map (f: key -> key) (s: t): t = fold' (fun x v acc -> add (f x) v acc) s (empty ())
  (* TODO: reducing map, like HoareSet *)

  let elements (s: t): (key * R.t) list = bindings s
  let of_list (l: (key * R.t) list): t = List.fold_left (fun acc (x, r) -> add x r acc) (empty ()) l
  let union = long_map2 R.union


  (* copied & modified from SetDomain.Hoare_NoTop *)
  let mem x xr s = R.for_all (fun vie -> exists' (fun y yr -> SpecD.leq x y && R.mem vie yr) s) xr
  let leq a b = for_all' (fun x xr -> mem x xr b) a (* mem uses B.leq! *)

  let le x y = SpecD.leq x y && not (SpecD.equal x y) && not (SpecD.leq y x)
  let reduce (s: t): t =
    (* get map with just maximal keys and their ranges *)
    let maximals = filter (fun x -> not (exists (le x) s)) s in
    (* join le ranges also *)
    let maximals =
      mapi (fun x xr ->
          fold' (fun y yr acc ->
              if le y x then
                R.join acc yr
              else
                acc
            ) s xr
        ) maximals
    in
    maximals
  let product_bot op op2 a b =
    let a,b = elements a, elements b in
    List.concat_map (fun (x,xr) -> List.map (fun (y,yr) -> (op x y, op2 xr yr)) b) a |> fun x -> reduce (of_list x)
  let product_bot2 op2 a b =
    let a,b = elements a, elements b in
    List.concat_map (fun (x,xr) -> List.map (fun (y,yr) -> op2 (x, xr) (y, yr)) b) a |> fun x -> reduce (of_list x)
  (* why are type annotations needed for product_widen? *)
  (* TODO: unused now *)
  let product_widen op op2 (a:t) (b:t): t = (* assumes b to be bigger than a *)
    let xs,ys = elements a, elements b in
    List.concat_map (fun (x,xr) -> List.map (fun (y,yr) -> (op x y, op2 xr yr)) ys) xs |> fun x -> reduce (join b (of_list x)) (* join instead of union because R is HoareDomain.Set for witness generation *)
  let product_widen2 op2 (a:t) (b:t): t = (* assumes b to be bigger than a *)
    let xs,ys = elements a, elements b in
    List.concat_map (fun (x,xr) -> List.map (fun (y,yr) -> op2 (x, xr) (y, yr)) ys) xs |> fun x -> reduce (join b (of_list x)) (* join instead of union because R is HoareDomain.Set for witness generation *)
  let join a b = join a b |> reduce
  let meet = product_bot SpecD.meet R.inter
  (* let narrow = product_bot (fun x y -> if SpecD.leq y x then SpecD.narrow x y else x) R.narrow *)
  (* TODO: move PathSensitive3-specific narrow out of HoareMap *)
  let narrow = product_bot2 (fun (x, xr) (y, yr) -> if SpecD.leq y x then (SpecD.narrow x y, yr) else (x, xr))
  (* let widen = product_widen (fun x y -> if SpecD.leq x y then SpecD.widen x y else SpecD.bot ()) R.widen *)
  (* TODO: move PathSensitive3-specific widen out of HoareMap *)
  let widen = product_widen2 (fun (x, xr) (y, yr) -> if SpecD.leq x y then (SpecD.widen x y, yr) else (y, yr)) (* TODO: is this right now? *)

  (* TODO: shouldn't this also reduce? *)
  let apply_list f s = elements s |> f |> of_list

  let pretty_diff () ((s1:t),(s2:t)): Pretty.doc =
    if leq s1 s2 then dprintf "%s (%d and %d paths): These are fine!" (name ()) (cardinal s1) (cardinal s2) else begin
      try
        let p t tr = not (mem t tr s2) in
        let (evil, evilr) = choose' (filter' p s1) in
        let evilr' = R.choose evilr in
        dprintf "%a -> %a:\n" SpecD.pretty evil R.pretty (R.singleton evilr')
        ++
        if is_empty s2 then
          text "empty set s2"
        else
          fold' (fun other otherr acc ->
              (dprintf "not leq %a because %a\nand not mem %a because %a\n" SpecD.pretty other SpecD.pretty_diff (evil, other) R.pretty otherr R.pretty_diff (R.singleton evilr', otherr)) ++ acc
            ) s2 nil
      with Not_found ->
        dprintf "choose failed b/c of empty set s1: %d s2: %d"
        (cardinal s1)
        (cardinal s2)
    end
end

module type NewS =
sig
  include Lattice.S
  type elt
  val singleton: elt -> t
  val of_list: elt list -> t
  val exists: (elt -> bool) -> t -> bool
  val for_all: (elt -> bool) -> t -> bool
  val mem: elt -> t -> bool
  val choose: t -> elt
  val elements: t -> elt list
  val remove: elt -> t -> t
  val map: (elt -> elt) -> t -> t
  val fold: (elt -> 'a -> 'a) -> t -> 'a -> 'a
  val empty: unit -> t
  val add: elt -> t -> t
  val is_empty: t -> bool
  val union: t -> t -> t
  val diff: t -> t -> t
  val iter: (elt -> unit) -> t -> unit
  val cardinal: t -> int
end


module type Representative =
sig
  include Printable.S
  type elt
  val of_elt: elt -> t
end

module Projective (E: Lattice.S) (B: NewS with type elt = E.t) (R: Representative with type elt = E.t): NewS with type elt = E.t =
struct
  type elt = E.t

  module R =
  struct
    include Printable.Std (* for Groupable *)
    include R
  end
  module M = MapDomain.MapBot (R) (B)

  (** Invariant: no explicit bot buckets.
      Required for efficient [is_empty], [cardinal] and [choose]. *)

  let name () = "Projective (" ^ B.name () ^ ")"

  (* explicitly delegate, so we don't accidentally delegate too much *)

  type t = M.t
  let equal = M.equal
  let compare = M.compare
  let hash = M.hash
  let tag = M.tag
  let relift = M.relift

  let is_bot = M.is_bot
  let bot = M.bot
  let is_top = M.is_top
  let top = M.top

  let is_empty = M.is_empty
  let empty = M.empty
  let cardinal = M.cardinal

  let leq = M.leq
  let join = M.join
  let pretty_diff = M.pretty_diff

  let fold f m a = M.fold (fun _ e a -> B.fold f e a) m a
  let iter f m = M.iter (fun _ e -> B.iter f e) m
  let exists p m = M.exists (fun _ e -> B.exists p e) m
  let for_all p m = M.for_all (fun _ e -> B.for_all p e) m

  let singleton e = M.singleton (R.of_elt e) (B.singleton e)
  let choose m = B.choose (snd (M.choose m))

  let mem e m =
    match M.find_opt (R.of_elt e) m with
    | Some b -> B.mem e b
    | None -> false
  let add e m =
    let r = R.of_elt e in
    let b' = match M.find_opt r m with
      | Some b -> B.add e b
      | None -> B.singleton e
    in
    M.add r b' m
  let remove e m =
    let r = R.of_elt e in
    match M.find_opt r m with
    | Some b ->
      let b' = B.remove e b in
      if B.is_bot b' then
        M.remove r m (* remove bot bucket to preserve invariant *)
      else
        M.add r b' m
    | None -> m
  let diff m1 m2 =
    M.merge (fun _ b1 b2 ->
        match b1, b2 with
        | Some b1, Some b2 ->
          let b' = B.diff b1 b2 in
          if B.is_bot b' then
            None (* remove bot bucket to preserve invariant *)
          else
            Some b'
        | Some _, None -> b1
        | None, _ -> None
      ) m1 m2

  let of_list es = List.fold_left (fun acc e ->
      add e acc
    ) (empty ()) es
  let elements m = fold List.cons m [] (* no intermediate per-bucket lists *)
  let map f m = fold (fun e acc ->
      add (f e) acc
    ) m (empty ()) (* no intermediate lists *)

  let widen m1 m2 =
    assert (leq m1 m2);
    M.widen m1 m2

  let meet m1 m2 =
    M.merge (fun _ b1 b2 ->
        match b1, b2 with
        | Some b1, Some b2 ->
          let b' = B.meet b1 b2 in
          if B.is_bot b' then
            None (* remove bot bucket to preserve invariant *)
          else
            Some b'
        | _, _ -> None
      ) m1 m2
  let narrow m1 m2 =
    M.merge (fun _ b1 b2 ->
        match b1, b2 with
        | Some b1, Some b2 ->
          let b' = B.narrow b1 b2 in
          if B.is_bot b' then
            None (* remove bot bucket to preserve invariant *)
          else
            Some b'
        | _, _ -> None
      ) m1 m2

  let union = join

  let pretty () m =
    Pretty.(dprintf "{%a}" (d_list ", " E.pretty) (elements m))
  let show m = Pretty.sprint ~width:max_int (pretty () m) (* TODO: delegate to E.show instead *)
  let to_yojson m = [%to_yojson: E.t list] (elements m)
  let printXml f m =
    (* based on SetDomain *)
    BatPrintf.fprintf f "<value>\n<set>\n";
    iter (E.printXml f) m;
    BatPrintf.fprintf f "</set>\n</value>\n"

  let arbitrary () = failwith "Projective.arbitrary"
end


module type Equivalence =
sig
  type elt
  val cong: elt -> elt -> bool
end

module Pairwise (E: Lattice.S) (B: NewS with type elt = E.t) (Q: Equivalence with type elt = E.t): NewS with type elt = E.t =
struct
  type elt = E.t

  module S = SetDomain.Make (B)

  (** Invariant: no explicit bot buckets.
      Required for efficient [is_empty], [cardinal] and [choose]. *)

  let name () = "Pairwise (" ^ B.name () ^ ")"

  (* explicitly delegate, so we don't accidentally delegate too much *)

  type t = S.t
  let equal = S.equal
  let compare = S.compare
  let hash = S.hash
  let tag = S.tag
  let relift = S.relift

  let is_bot = S.is_bot
  let bot = S.bot
  let is_top = S.is_top
  let top = S.top

  let is_empty = S.is_empty
  let empty = S.empty
  let cardinal = S.cardinal

  let fold f s a = S.fold (fun b a -> B.fold f b a) s a
  let iter f s = S.iter (fun b -> B.iter f b) s
  let exists p s = S.exists (fun b -> B.exists p b) s
  let for_all p s = S.for_all (fun b -> B.for_all p b) s

  let singleton e = S.singleton (B.singleton e)
  let choose s = B.choose (S.choose s)

  (* based on SetDomain.SensitiveConf *)

  let mem e s =
    S.exists (fun b -> Q.cong (B.choose b) e && B.mem e b) s
  let add e s =
    let (s_match, s_rest) = S.partition (fun b -> Q.cong (B.choose b) e) s in
    let b' = match S.choose s_match with
      | b ->
        assert (S.cardinal s_match = 1);
        B.add e b
      | exception Not_found -> B.singleton e
    in
    S.add b' s_rest
  let remove e s =
    let (s_match, s_rest) = S.partition (fun b -> Q.cong (B.choose b) e) s in
    match S.choose s_match with
    | b ->
      assert (S.cardinal s_match = 1);
      let b' = B.remove e b in
      if B.is_bot b' then
        s_rest (* remove bot bucket to preserve invariant *)
      else
        S.add b' s
    | exception Not_found -> s
  let diff s1 s2 =
    let f b2 (s1, acc) =
      let e2 = B.choose b2 in
      let (s1_match, s1_rest) = S.partition (fun b1 -> Q.cong (B.choose b1) e2) s1 in
      let acc' = match S.choose s1_match with
        | b1 ->
          assert (S.cardinal s1_match = 1);
          let b' = B.diff b1 b2 in
          if B.is_bot b' then
            acc (* remove bot bucket to preserve invariant *)
          else
            S.add b' acc
        | exception Not_found -> acc
      in
      (s1_rest, acc')
    in
    let (s1', acc) = S.fold f s2 (s1, empty ()) in
    S.union s1' acc

  let of_list es = List.fold_left (fun acc e ->
      add e acc
    ) (empty ()) es
  let elements m = fold List.cons m [] (* no intermediate per-bucket lists *)
  let map f s = fold (fun e acc ->
      add (f e) acc
    ) s (empty ()) (* no intermediate lists *)

  let leq s1 s2 =
    S.for_all (fun b1 ->
        let e1 = B.choose b1 in
        S.exists (fun b2 -> Q.cong (B.choose b2) e1 && B.leq b1 b2) s2
      ) s1

  let join s1 s2 =
    let f b2 (s1, acc) =
      let e2 = B.choose b2 in
      let (s1_match, s1_rest) = S.partition (fun b1 -> Q.cong (B.choose b1) e2) s1 in
      let b' = match S.choose s1_match with
        | b1 ->
          assert (S.cardinal s1_match = 1);
          B.join b1 b2
        | exception Not_found -> b2
      in
      (s1_rest, S.add b' acc)
    in
    let (s1', acc) = S.fold f s2 (s1, empty ()) in
    S.union s1' acc

  let widen s1 s2 =
    assert (leq s1 s2);
    let f b2 (s1, acc) =
      let e2 = B.choose b2 in
      let (s1_match, s1_rest) = S.partition (fun e1 -> Q.cong (B.choose e1) e2) s1 in
      let b' = match S.choose s1_match with
        | b1 ->
          assert (S.cardinal s1_match = 1);
          B.widen b1 b2
        | exception Not_found -> b2
      in
      (s1_rest, S.add b' acc)
    in
    let (s1', acc) = S.fold f s2 (s1, empty ()) in
    assert (is_empty s1'); (* since [leq s1 s2], folding over s2 should remove all s1 *)
    acc (* TODO: extra union s2 needed? *)

  let meet s1 s2 =
    let f b2 (s1, acc) =
      let e2 = B.choose b2 in
      let (s1_match, s1_rest) = S.partition (fun b1 -> Q.cong (B.choose b1) e2) s1 in
      let acc' = match S.choose s1_match with
        | b1 ->
          assert (S.cardinal s1_match = 1);
          let b' = B.meet b1 b2 in
          if B.is_bot b' then
            acc (* remove bot bucket to preserve invariant *)
          else
            S.add b' acc
        | exception Not_found -> acc
      in
      (s1_rest, acc')
    in
    snd (S.fold f s2 (s1, S.empty ()))

  let narrow s1 s2 =
    let f b2 (s1, acc) =
      let e2 = B.choose b2 in
      let (s1_match, s1_rest) = S.partition (fun b1 -> Q.cong (B.choose b1) e2) s1 in
      let acc' = match S.choose s1_match with
        | b1 ->
          assert (S.cardinal s1_match = 1);
          let b' = B.narrow b1 b2 in
          if B.is_bot b' then
            acc (* remove bot bucket to preserve invariant *)
          else
            S.add b' acc
        | exception Not_found -> acc
      in
      (s1_rest, acc')
    in
    snd (S.fold f s2 (s1, S.empty ()))

  let union = join

  let pretty () s =
    Pretty.(dprintf "{%a}" (d_list ", " E.pretty) (elements s))
  let show s = Pretty.sprint ~width:max_int (pretty () s) (* TODO: delegate to E.show instead *)
  let to_yojson s = [%to_yojson: E.t list] (elements s)
  let printXml f s =
    (* based on SetDomain *)
    BatPrintf.fprintf f "<value>\n<set>\n";
    iter (E.printXml f) s;
    BatPrintf.fprintf f "</set>\n</value>\n"

  let pretty_diff () _ = failwith "Pairwise.pretty_diff" (* TODO *)

  let arbitrary () = failwith "Pairwise.arbitrary"
end


module Joined (E: Lattice.S): NewS with type elt = E.t =
struct
  type elt = E.t
  include E

  let singleton e = e
  let of_list es = List.fold_left E.join (E.bot ()) es
  let exists p e = p e
  let for_all p e = p e
  let mem e e' = E.leq e e'
  let choose e = e
  let elements e = [e]
  let remove e e' =
    if E.leq e' e then
      E.bot ()
    else
      e'
  let map f e = f e
  let fold f e a = f e a
  let empty () = E.bot ()
  let add e e' = E.join e e'
  let is_empty e = E.is_bot e
  let union e e' = E.join e e'
  let diff e e' = remove e' e
  let iter f e = f e
  let cardinal e =
    if is_bot e then
      0
    else
      1
end

module Set2 (E: Lattice.S): NewS with type elt = E.t =
struct
  module H = Set (E)
  include H


  (* version of widen which doesn't use E.bot *)
  let product_widen (op: elt -> elt -> elt option) a b = (* assumes b to be bigger than a *)
  let xs,ys = elements a, elements b in
  List.concat_map (fun x -> List.filter_map (fun y -> op x y) ys) xs |> fun x -> join b (of_list x)
  let widen = product_widen (fun x y -> if E.leq x y then Some (E.widen x y) else None)

  (* widen is actually extrapolation operator, so define connector-based widening instead *)
  let leq_em s1 s2 =
    is_bot s1 || leq s1 s2 && for_all (fun e2 -> exists (fun e1 -> E.leq e1 e2) s1) s2
  let join_em s1 s2 =
    join s1 s2
    |> elements
    |> BatList.reduce E.join
    |> singleton

  let widen s1 s2 =
    assert (leq s1 s2);
    let s2' =
      if leq_em s1 s2 then
        s2
      else
        join_em s1 s2
    in
    widen s1 s2'
end
