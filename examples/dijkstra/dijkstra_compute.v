Require Import List Nat Bool egalite Omega.
Import ListNotations.

(** Compute Djikstra's final table *)

Definition Triplet :Type := nat*nat*nat.

Fixpoint Absence (b':nat)(list:@list Triplet) :=
  match list with
  | []                => true
  | (a,b,n) :: l' => if (b =? b') then false else Absence b' l'
  end.

Fixpoint Presence (b':nat)(list:@list Triplet) :=
  match list with
  | []                => None
  | (a,b,n) :: l' => if (b =? b') then Some (a,b,n) else Presence b' l'
  end.

Fixpoint GenerateCandidates (arc:Triplet)(graph candidates table:@list Triplet): (@list Triplet) :=
  let (x, db) := arc in
  let (a, b) := x in
  (match graph with
  | []             => candidates
  | arc' :: graph' => let recursiveCall := (GenerateCandidates arc graph' candidates table) in
                        (
                        let (y, n) := arc' in
                        let (b'', b') := y in
                        if ((b'' =? b) && Absence b' table)
                        then (if (Absence b' candidates)
                              then (b, b', db+n) :: recursiveCall
                              else match Presence b' candidates with
                                   | None              => recursiveCall
                                   | Some (a', _, db') => if ((db+n) <? db')
                                                          then let newCandidates := (replace (a', b', db') 
                                                                                             (b, b', db+n) candidates cons) 
                                                                                     in
                                                                   (GenerateCandidates arc graph' newCandidates table)
                                                          else recursiveCall
                                      end)
                        else recursiveCall )
  end).

Definition overflow := 1000.

Definition tripletsMin (c:@list Triplet) :=
  match c with
  |[]     => None
  |x :: l => Some ((fix tripletsMinRec l' min := 
               match l' with
               | []       => min
               | y :: l'' => let c := (snd y) in let c' := (snd min) in
                             if (c <? c') then tripletsMinRec l'' y else tripletsMinRec l'' min
               end) l x)
  end.

Definition removeMin (c:@list Triplet) := 
  let min := (tripletsMin c) in 
  match min with
  | None    => (None, c)
  | Some c' => (min, remove c' c)
  end.

Definition uniqueApp{A:Type}`{Eqb A} (l1 l2: @list A) :=
  l1 ++ 
  (fix uniqueAppRec li lj :=
  match lj with
  | [] => []
  | x :: lj' => let res := uniqueAppRec li lj' in 
                if (list_mem x li) then res else (x :: res)
  end) l1 l2.

Notation "x +++ y" := (uniqueApp x y) (at level 60, right associativity) : list_scope.

(** Necessary here to show the decreasing argument *)
Fixpoint ConsumeCandidates(graph candidates table : @list Triplet)(overflow : nat) : (@list Triplet)*(@list Triplet):=
  let nilCase := ([], table) in
  match overflow with
  | 0    => nilCase
  | S n' => match candidates with
            | [] => nilCase
            | _  => let (arc, newCandidates) := (removeMin candidates) in
                    match arc with
                    | Some triplet => let candidatesRecord := (GenerateCandidates triplet graph newCandidates table) in
                                      let res := (ConsumeCandidates graph candidatesRecord (triplet::table) n') in
                                      (triplet :: candidatesRecord +++ fst res, snd res)
                    | None         => nilCase
                    end
            end
  end.

Definition DjikstraTriplets(root:nat)(l:@list Triplet) : (@list Triplet)*(@list Triplet) := 
  ConsumeCandidates l [(root, root, 0)][] overflow.

Require Import dijkstra molecules.
Import Pondéré.

Definition AtomeToTriplet(atome : At) := 
  match atome with
  | G a b n => (a, b, n)
  | T a b n => (a, b, n)
  | C a b n => (a, b, n)
  end.

Fixpoint MoleculeToTriplets(molecule : @Molecule At): (@list Triplet) :=
  match molecule with
  |un => []
  |atome x => [AtomeToTriplet x]
  |conjonctionMultiplicative M1 M2 => (MoleculeToTriplets M1)++(MoleculeToTriplets M2)
  end.

Fixpoint TripletsToTable(list : @list Triplet): (@Molecule At) :=
  match list with
  |[]               => un
  |[(a,b,n)]        => t a b n
  |(a,b,n) :: list' => TripletsToTable list' ⊗ (t a b n)
  end.

Definition Dijkstra(root:nat)(M:@Molecule At): (@list Triplet)*(@Molecule At) := 
  let calculation := (DjikstraTriplets root (MoleculeToTriplets M)) in 
  (fst calculation, TripletsToTable (snd calculation)).

(** Tactics *)

Fixpoint findFirst{A:Type} (l:list A)(f:A -> bool) :=
  match l with
  |nil     => None
  |x :: l' => if (f x) then Some x else findFirst l' f
  end.

Definition previousCovered (t:Triplet)(a':nat) : bool :=
  let (x,c) := t in let (a,b) := x in b =? a'.

Require Import tactics.

Ltac addArcsRec l triplets :=
  match l with
  | nil                => idtac "No more arcs to generate"; idtac ""
  | (?a,?b,?n) :: ?l'  => match eval compute 
                          in (findFirst triplets (fun (t:Triplet) => previousCovered t a)) with
                          | None                  => idtac "No more candidate to cover"
                          | Some (?a', _, ?da)  => idtac "Generate candidate C " a b n " from T " a' a da;
                                                     dupliquerExponentielle 0; Candidat1 a b (n-da) a' da;
                                                     idtac "Generate vertice T " a b n;
                                                     dupliquerExponentielle 2; Recouvrement1 a b n;
                                                     idtac ""; addArcsRec l' triplets
                          end
  end.


Ltac addArcs candidates triplets :=
  idtac "Generating automatically the arcs with Djikstra"; idtac "";
  match eval compute in 
(intersection candidates triplets) with
  |nil               => idtac "No obvious arcs"
  |(?a,?b,?n) :: ?l  => addArcsRec l triplets
  end.

Require Import dijkstra.
Import Pondéré.

Definition ProveDijkstra Graph Root := 
  let pair := (Dijkstra Root Graph) in
  let FinalTableGraph := snd pair in
  Transformation règles (Graph ⊗ t Root Root 0)(Graph ⊗ FinalTableGraph).

Ltac TacticDijkstra Graph Root :=
  (** Compute Final Graph and its associated tactic *)
  unfold ProveDijkstra;
  remember (Dijkstra Root Graph) as c eqn:Hc; cbv in Hc;
  remember (fst c) as p eqn:Hp; remember (snd c) as fg eqn:Hfg; 
  rewrite Hc in Hp, Hfg; cbv in Hp, Hfg; clear Hc;
  rewrite Hfg;
  (** Run the custom tactic *)
  match goal with
  | Hp: _ = ?x, Hfg : _ = ?y |- _ => idtac "Final reached graph is "x; addArcs x (MoleculeToTriplets y)
  end;
	(** Check the final constraints *)
	ChoisirNeutrePartout;
	ConclureCandidat1;
	ConclureCandidat2.

Definition Graph := g 1 2 4 ⊗ g 1 4 1 ⊗ g 1 5 2 ⊗ g 4 5 2 ⊗ g 4 6 3 ⊗ g 5 6 1 ⊗ g 5 3 0 ⊗ g 3 2 3 ⊗ g 4 2 4.

Definition Root := 1.

Theorem test : ProveDijkstra Graph Root.
Proof.
  TacticDijkstra Graph Root.
Qed.












