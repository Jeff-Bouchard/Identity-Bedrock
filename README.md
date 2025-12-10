# EIP4361

# Digital Identity Bedrock

This file defines the *minimal* cryptographic structure needed to authenticate / identify an entity.

---

## 1. Cryptographic Primitive

Let 
- **Σ = (KeyGen, Sign, Verify)** be a digital signature scheme.

Assumption (EUF-CMA security): For any probabilistic polynomial-time (PPT) adversary **A** with access to a signing oracle for a public key **pk**, the probability that **A** outputs a fresh message–signature pair **(m, σ)** such that

> `Verify(pk, m, σ) = 1`

and **m** was never queried to the signing oracle, is negligible:

> `Pr[A forges under pk] ≤ ε_sig`, with ε_sig ≈ 2⁻¹²⁸ in practice.

This is the *only* cryptographic assumption.

---

## 2. Identity Objects

An **identity** is the pair:

> `I := (id, pk)`

where:
- **id** is an arbitrary, unique label (string, URN, hash of metadata, etc.).
- **pk** is a public verification key output by `KeyGen()`.

We assume the existence of a **public directory** **D** containing such pairs, modeled as a set:

> `D ⊆ ID × PK`

with a membership predicate:

> `Bind(id, pk) = 1  ⇔  (id, pk) ∈ D`.

How **D** is implemented is *not* part of the bedrock; only the predicate `Bind` matters.

In the Privateness / Ness architecture, a natural concrete realization of **D** is:

- Emercoin Name–Value Storage (NVS) records whose values are produced by the **World Object Mapper (WORM)** tooling (for example, the `./key worm ...` flows in [`NESS-Network/NessNode`](https://github.com/NESS-Network/NessNode) and [`NESS-Network/PrivatenessTools`](https://github.com/NESS-Network/PrivatenessTools)).

This document stays at the mathematical level; WORM and Emercoin NVS are just one instantiation of the abstract directory `D`.

---

## 3. Authentication Protocol (Challenge–Response)

There are two roles:
- **Prover** `P` owning a secret key **sk** with public key **pk**.
- **Verifier** `V` who knows **id**, directory **D**, and thus can obtain **pk** such that `Bind(id, pk) = 1`.

### 3.1 Setup

1. `KeyGen()` outputs `(sk, pk)`.
2. The pair `(id, pk)` is inserted into **D**, making `Bind(id, pk) = 1`.

### 3.2 Online Authentication

1. **Challenge:** `V` samples a fresh random challenge `c` (bitstring) and sends it to `P`.
2. **Response:** `P` computes `σ := Sign(sk, c)` and sends `σ` to `V`.
3. **Verification:** `V` accepts `P` as identity **id** if and only if:

> `Auth(id, c, σ) = 1`
>
> where
>
> `Auth(id, c, σ) := [ ∃ pk : Bind(id, pk) = 1  ∧  Verify(pk, c, σ) = 1 ]`.

There is no other state, key, or authority in this definition.

---

## 4. Security Statement

Let **A** be any PPT adversary that does *not* know **sk** corresponding to a given `(id, pk)` with `Bind(id, pk) = 1`.

### Theorem (Authentication Soundness)

Under the EUF-CMA assumption on Σ, for any such **A**, the probability that **A** can convince a verifier to accept as identity **id** in the above protocol is at most **ε_sig**.

Formally, let **Game** be:

1. `(sk, pk) ← KeyGen()`.
2. Publish `(id, pk)` by inserting it into **D** (so `Bind(id, pk) = 1`).
3. Give **A** the description of Σ, the directory **D**, and **pk**.
4. Repeat: when **A** requests a challenge, sample fresh `c`, give `c` and oracle access to `Sign(sk, ·)`.
5. **A** outputs `(id*, c*, σ*)`.
6. **A** wins if `id* = id` and `Auth(id, c*, σ*) = 1` and **A** never queried `c*` to the signing oracle.

Then:

> `Pr[Game(A) = win] ≤ ε_sig`.

Thus, *any* successful impersonation of **id** requires either:
- Breaking the signature scheme (probability ≤ ε_sig), or
- Compromising the prover's secret key **sk**.

No institutional or third-party secret appears in the definition of `Auth`.

This is the irreducible cryptographic core for authentication and identification of a labeled entity.
