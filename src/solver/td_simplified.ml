(** Terminating op-down solver with side effects. Baseline for comparisons with td_parallel solvers ([td_simplified]).*)

(** Top down solver that uses the box-operator for widening/narrowing at widening points.
 * Options:
 * - solvers.td3.remove-wpoint (default: true): Remove widening points when a variable is and stays stable in iterate. Increases precision of nested loops.*)

open Batteries
open ConstrSys
open Messages

module M = Messages

module Base : GenericEqSolver =
  functor (S:EqConstrSys) ->
  functor (HM:Hashtbl.S with type key = S.v) ->
  struct
    open SolverBox.Warrow (S.Dom)
    include Generic.SolverStats (S) (HM)
    module VS = Set.Make (S.Var)

    type solver_data = {
      infl: VS.t HM.t;
      rho: S.Dom.t HM.t;
      wpoint: unit HM.t;
      stable: unit HM.t;
    }

    let create_empty_data () = {
      infl = HM.create 10;
      rho = HM.create 10;
      wpoint = HM.create 10;
      stable = HM.create 10;
    }

    let print_data data =
      Logs.debug "|rho|=%d" (HM.length data.rho);
      Logs.debug "|stable|=%d" (HM.length data.stable);
      Logs.debug "|infl|=%d" (HM.length data.infl);
      Logs.debug "|wpoint|=%d" (HM.length data.wpoint)

    let print_data_verbose data str =
      if Logs.Level.should_log Debug then (
        Logs.debug "%s:" str;
        print_data data
      )

    let solve st vs =
      let data = create_empty_data () in

      let called = HM.create 10 in
      let infl = data.infl in
      let rho = data.rho in
      let wpoint = data.wpoint in
      let stable = data.stable in

      let remove_wpoint = GobConfig.get_bool "solvers.td3.remove-wpoint" in

      let () = print_solver_stats := fun () ->
          print_data data;
          Logs.info "|called|=%d" (HM.length called);
          print_context_stats rho
      in

      let add_infl y x =
        if tracing then trace "infl" "add_infl %a %a" S.Var.pretty_trace y S.Var.pretty_trace x;
        HM.replace infl y (VS.add x (HM.find_default infl y VS.empty));
      in

      let init x =
        if not (HM.mem rho x) then (
          new_var_event x;
          if tracing then trace "init" "init %a" S.Var.pretty_trace x;
          HM.replace rho x (S.Dom.bot ())
        )
      in

      let eq x get set =
        if tracing then trace "eq" "eq %a" S.Var.pretty_trace x;
        match S.system x with
        | None -> S.Dom.bot ()
        | Some f -> f get set
      in

      let rec destabilize x =
        if tracing then trace "destab" "destabilize %a" S.Var.pretty_trace x;
        let w = HM.find_default infl x VS.empty in
        HM.replace infl x VS.empty;
        VS.iter (fun y ->
            if tracing then trace "destab" "stable remove %a" S.Var.pretty_trace y;
            HM.remove stable y;
            destabilize y
          ) w
      in

      let rec iterate ?reuse_eq x = (* ~(inner) solve in td3*)
        let query x y = (* ~eval in td3 *)
          if tracing then trace "sol_query" "entering query for %a; stable %b; called %b" S.Var.pretty_trace y (HM.mem stable y) (HM.mem called y);
          get_var_event y;
          if not (HM.mem called y) then (
            if S.system y = None then (
              init y;
              HM.replace stable y ()
            ) else (
              HM.replace called y ();
              if tracing then trace "iter" "iterate called from query";
              iterate y;
              HM.remove called y)
          ) else (
            if tracing && not (HM.mem wpoint y) then trace "wpoint" "query adding wpoint %a" S.Var.pretty_trace y;
            HM.replace wpoint y ();
          );
          let tmp = HM.find rho y in
          add_infl y x;
          if tracing then trace "answer" "exiting query for %a\nanswer: %a" S.Var.pretty_trace y S.Dom.pretty tmp;
          tmp
        in

        let side x y d = (* side from x to y; only to variables y w/o rhs; x only used for trace *)
          if tracing then trace "side" "side to %a (wpx: %b) from %a ## value: %a" S.Var.pretty_trace y (HM.mem wpoint y) S.Var.pretty_trace x S.Dom.pretty d;
          assert (S.system y = None);
          init y;
          let widen a b =
            if M.tracing then M.trace "sidew" "side widen %a" S.Var.pretty_trace y;
            S.Dom.widen a (S.Dom.join a b)
          in
          let op a b = if HM.mem wpoint y then widen a b else S.Dom.join a b
          in
          let old = HM.find rho y in
          let tmp = op old d in
          HM.replace stable y ();
          if not (S.Dom.leq tmp old) then (
            if tracing && not (S.Dom.is_bot old) then trace "solside" "side to %a (wpx: %b) from %a: %a -> %a" S.Var.pretty_trace y (HM.mem wpoint y) S.Var.pretty_trace x S.Dom.pretty old S.Dom.pretty tmp;
            if tracing && not (S.Dom.is_bot old) then trace "solchange" "side to %a (wpx: %b) from %a: %a" S.Var.pretty_trace y (HM.mem wpoint y) S.Var.pretty_trace x S.Dom.pretty_diff (tmp, old);
            HM.replace rho y tmp;
            destabilize y;
            (* make y a widening point. This will only matter for the next side _ y.  *)
            if tracing && not (HM.mem wpoint y) then trace "wpoint" "side adding wpoint %a" S.Var.pretty_trace y;
            HM.replace wpoint y ()
          )
        in  

        (* begining of iterate*)
        if tracing then trace "iter" "iterate %a, called: %b, stable: %b, wpoint: %b" S.Var.pretty_trace x (HM.mem called x) (HM.mem stable x) (HM.mem wpoint x);
        init x;
        assert (S.system x <> None);
        if not (HM.mem stable x) then (
          HM.replace stable x ();
          let wp = HM.mem wpoint x in (* if x becomes a wpoint during eq, checking this will delay widening until next iterate *)
          let eqd = eq x (query x) (side x) in (* d from equation/rhs *)
          let old = HM.find rho x in (* d from older iterate *)
          let wpd = (* d after widen/narrow (if wp) *)
            if not wp then eqd
            else box old eqd
          in
          if not (Timing.wrap "S.Dom.equal" (fun () -> S.Dom.equal old wpd) ()) then ( 
            (* old != wpd *)
            if tracing then trace "sol" "Changed";
            if tracing && not (S.Dom.is_bot old) && HM.mem wpoint x then trace "solchange" "%a (wpx: %b): %a" S.Var.pretty_trace x (HM.mem wpoint x) S.Dom.pretty_diff (wpd, old);
            update_var_event x old wpd;
            HM.replace  rho x wpd;
            destabilize x;
            if tracing then trace "iter" "iterate changed %a" S.Var.pretty_trace x;
            (iterate[@tailcall]) x
          ) else (
            (* old == wpd *)
            if not (HM.mem stable x) then ( 
              (* value unchanged, but not stable, i.e. destabilized itself during rhs *)
              if tracing then trace "iter" "iterate still unstable %a" S.Var.pretty_trace x;
              (iterate[@tailcall]) x
            ) else (
              if remove_wpoint then ( 
                (* this makes e.g. nested loops precise, ex. tests/regression/34-localization/01-nested.c - if we do not remove wpoint, the inner loop head will stay a wpoint and widen the outer loop variable. *)
                if tracing && (HM.mem wpoint x) then trace "wpoint" "iterate removing wpoint %a" S.Var.pretty_trace x;
                HM.remove wpoint x
              )
            )
          )
        )
      in

      let set_start (x,d) =
        init x;
        HM.replace rho x d;
        HM.replace stable x ();
      in

      (* beginning of main solve *)
      start_event ();

      List.iter set_start st;

      List.iter init vs;
      (* If we have multiple start variables vs, we might solve v1, then while solving v2 we side some global which v1 depends on with a new value. Then v1 is no longer stable and we have to solve it again. *)
      let i = ref 0 in
      let rec solver () = (* as while loop in paper *)
        incr i;
        let unstable_vs = List.filter (neg (HM.mem stable)) vs in
        if unstable_vs <> [] then (
          if Logs.Level.should_log Debug then (
            if !i = 1 then Logs.newline ();
            Logs.debug "Unstable solver start vars in %d. phase:" !i;
            List.iter (fun v -> Logs.debug "\t%a" S.Var.pretty_trace v) unstable_vs;
            Logs.newline ();
            flush_all ();
          );
          List.iter (fun x -> HM.replace called x ();
                      if tracing then trace "multivar" "solving for %a" S.Var.pretty_trace x;
                      iterate x; 
                      HM.remove called x
                    ) unstable_vs;
          solver ();
        )
      in
      solver ();
      (* After termination, only those variables are stable which are
       * - reachable from any of the queried variables vs, or
       * - effected by side-effects and have no constraints on their own (this should be the case for all of our analyses). *)

      stop_event ();
      print_data_verbose data "Data after iterate completed";

      if GobConfig.get_bool "dbg.print_wpoints" then (
        Logs.newline ();
        Logs.debug "Widening points:";
        HM.iter (fun k () -> Logs.debug "%a" S.Var.pretty_trace k) wpoint;
        Logs.newline ();
      );

      rho
  end

let () =
  Selector.add_solver ("td_simplified", (module PostSolver.EqIncrSolverFromEqSolver (Base)));
