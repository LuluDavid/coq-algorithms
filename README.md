# CertifiedDjikstraLanguage

## Final results

With this tool, you will be able to automatize the processing of formally proven algorithms. To illustrate with 
Dijkstra's algorithm, we have been able to write minimal theorems such as :

```Coq
Definition Graph := g 1 2 4 ⊗ g 1 4 1 ⊗ g 1 5 2 ⊗ g 4 5 2 ⊗ g 4 6 3 ⊗ g 5 6 1 ⊗ g 5 3 0 ⊗ g 3 2 3 ⊗ g 4 2 4.

Definition Root := 1.

Theorem test : ProveDijkstra Graph Root.
Proof.
  TacticDijkstra Graph Root.
Qed.
```
To compute the final graph produced by the algorithm on ```Graph```, beginning at ```Root```, while providing 
a formal proof of its result ensuring few properties on the algorithm (this part needs to be enriched actually), and
providing feedback on the way the algorithm is proven :
```
COQC dijkstra_compute.v

Final reached graph is 
[(1, 1, 0); (1, 2, 4); (1, 4, 1); (1, 5, 2); (4, 6, 4); (5, 3, 2); (5, 6, 3)]
Generating automatically the arcs with Djikstra

Generate candidate C  1 2 4  from T  1 1 0

Generate vertice T  1 2 4

Generate candidate C  1 4 1  from T  1 1 0

Generate vertice T  1 4 1

Generate candidate C  1 5 2  from T  1 1 0

Generate vertice T  1 5 2

Generate candidate C  5 3 2  from T  1 5 2

Generate vertice T  5 3 2

Generate candidate C  5 6 3  from T  1 5 2

Generate vertice T  5 6 3

No more arcs to generate

Molecule under normal form

There is/are 2 guard constraint(s) to solve.

Constraints solved : every arc has already generated a covered vertice or a current candidate.

Cannot solve constraints

Constraints solved : every new generated candidate would have a bigger ponderation than in the current state
```

## Which initial problem ?

This work was initiated because **graph algorithms** and more generally algorithms (which are often 
encoded in imperative languages) can become a bit tricky to understand once they become more sophisticated.

Moreover, the proofs made on their behaviour often rely on their mathematical definition on not on their precise
implementation, whereas there often are **side effects** which are easier to deal with on the paper than in the program.

Additionally, to have a more intuitive way to define way, we thought the logical point of view would be quite
appropriate. With this aim in mind, it became clear that **Linear Logic** would be great to define algorithms,
because it relies on the *consumption of hypotheses* to produce outputs, which is quite similar to what an
imperative algorithm does.

That is why we decided to encode in Coq a minimal subset of linear logic to describe graph algorithms, with
the example of Djikstra.

This work is divided into two main parts :
  * **Theories**, where we introduce the whole certification around graph algorithms in Coq
  * **Compiler**, where we define a small DSL to run the transformations with a simpler syntax

I have written a whole report in french about it at the [following adress](https://drive.google.com/file/d/1M0zz_e-NL7pd5JiK6T-ITOtcgp3rFt5z/view?usp=sharing).

Here is the dependency graph for clearer understanding :

<p align="center"><img height = 800 src="https://github.com/LuluDavid/CertifiedDjikstraLanguage/blob/master/pictures/dependency_graph.png"></p>

## Theories

### Molecules

First, the algorithm's state is represented by a *multiplicative conjunction of atoms* (which can wrap whatever
information), called **Molecules**. Their definition is not optimised yet, as we prefered for the sake of
intuition to define them in a non-deterministic fashion :
```Molecule := 1 | Atom | Molecule * Molecule```
```Atom := P t (with P a unary predicate and t some value)```
, and to focus atoms in a molecule with rules later on (this could be change for matters of optimisation).

The focus rules are based on a categoric theory on prefixes and suffixes introduced by [H.Grall](https://github.com/hgrall), where he decided to describe molecular indexing in a monadic fashion (cursor going through the molecule's atoms as a state).

The second important thing about molecules is to define a notion of molecular equivalence, which is globally
the equality between two sets of atoms up-to-permutation.

Basically, the rules to show **molecular equivalence** are :
  * The molecular and atomistic identities
  * The 1-elimination and 1-axiom
  * The cut
  * The left an right conjunction

<p align="center"><img src = "https://github.com/LuluDavid/CertifiedDjikstraLanguage/blob/master/pictures/molecular_equivalence.png" width="500" style="display: block; margin: 0 auto;"></p>

Finally, in order to decide if we can apply some graph rules, we defined a simple notion of Absence on our molecules,
which would be like a ~In _ _ which is true if an atom does not appear inside a Molecule. This inductive property is
quite important as it stands as a necessary condition to apply certain rules.

### Transformations

The goal then is to describe an algorithm as a passage from one molecule to another applying rules.

For this matter, we introduced rules to describe transformations between molecules, and then transformations.
The rules where defined as :
```
Rule := 1 | Reaction | ∀x. r (values) | ∀X.r (molecules) | r ⊠ r | r ∧ r 
(multiplicative and additive conjunctions on rules)
```
```
Reaction := g ? M1 -o M2, Rule 
(if (g:Prop) && we have M1, we can produce M2 and possibly another rule)
```

We then specified how to transform molecules thanks to rules with the following inference rules :

<p align="center"><img src = "https://github.com/LuluDavid/CertifiedDjikstraLanguage/blob/master/pictures/transformation_rules.png"></p>

For this purpose, we relied on a **shallow embedding** (Coq's forall and cofix).

### Application to graph algorithms

There is a first simple difference in the version (as mentionned in the report above):
  * There is a **straight** version with no intermediate structure, where we generate directly candidates from the graph to the table
  * There is a **intermediate** version, where we introduced a candidate table, which is a simple structure to decide which methods/order of selection we use to generate table's elements, with different push/pop methods (**depth-first/breadth-first search**)
  * There is another intermediate version but without the list structure and without push/pop methods, which is now obsolete.

To give an example of how we would define a simple rule, I will give the simplest here :
```Coq
(* G(a, b) & T(a', a) & ¬T(?, b) -> G(a, b) & T(a', a) & T(a, b) *)
Definition Recouvrement :=
  ∀_m X, ∀_v a, ∀_v b, ∀_v a',
          ((forall b', Absence (t a' a ⊗ X) (T b' b))
             ? (g a b ⊗ t a' a ⊗ X) -o (g a b ⊗ t a' a ⊗ t a b ⊗ X)).
```
It means that if you have an arc ```(a, b)```, that you have reached ```a``` in the final table, and that b is not yet in
the final table (```forall b', Absence (t a' a ⊗ X) (T b' b)```), then you can put (a, b) in the final table.  
I am opened to questions for further examples, do not hesitate to send a message.

Thus far, we have two main implementations of graph algorithms with our logical backend :
  * A **free** version, where we can apply rules to transform the graph, and stop whenever we think we reached the final state
  * A **constrained** version, where we need to prove that no more rules are appliable once we decide to stop
  * We are currently still working on a **generic** formulation of the constrained version, where the stopping conditions would be more general (depending on the guards), but it complicates a lot tactics because we then need inversion when we introduce ~.

In the last case, we have yet introduced a property :
```Coq
Definition Blocage{A : Type}(R : list (@Regle A))(M1 : @Molecule A) : Prop :=
  forall M2, ~(Transformation R M1 M2).
```
and a few properties on it, but we are still struggling with the final case's solving through tactics.

### Focus on the constrained version

For this topic, we wanted to be able to duplicate indefinetely rules and then be able to eliminate them once we think we're done, given a few stopping conditions.  
To do so, we used **CoFixpoints**. First, we introduce a basic exponential rule as :
```Coq
Definition exponentielDeterministe{A : Type}(r : @Regle A) : @Regle A.
  cofix E.
  exact (neutral ∧ (r ⊠ E)).
Defined.
```
This is actually not constrained, but there is actually a simple way to have a **"conditional" neutral**, which is :
```Coq
CoFixpoint Rule :=
  (∀_m Y, (g ? Y -o Y))
  ∧
  (r ⊠ Rule).
```
where ```(g:Prop)``` is the condition to check to be able to eliminate the rule (if ```g```, then identity rule), and if we cannot, then we produce one rule ```r``` (the infinitely produced rule) and another cofix ```Rule```.
