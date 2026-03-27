<<<<<<< HEAD
# Identity Bedrock & EIP-4361

This repository collects the research notes, specifications, tools, and reference code around **Identity Bedrock** – an identity layer that takes Rompel’s 1990 theorem on one-way functions and signatures as its *minimal cryptographic foundation* – together with practical infrastructure used by the **Privateness Network**.

At a high level, Identity Bedrock treats a modern existentially unforgeable signature scheme (Ed25519) as the unique cryptographic root of identity, and uses a pluggable, append-only directory (e.g., Emercoin NVS anchored via Bitcoin AuxPoW) to bind identifiers to public keys. Under standard assumptions (one-way functions, EUF-CMA signatures, and directory finality), there is no strictly weaker cryptographic or institutional layer "beneath" the user’s key on which the system depends.

This repo sits alongside the Sign-In With Ethereum / **EIP-4361** pattern, but generalizes the idea: rather than coupling identity to any single chain, it defines a *chain-agnostic* bedrock that can be consumed by multiple directories and application stacks.

---

## Motivation

Most digital identity systems place **institutions beneath users**: certificate authorities, identity providers, registries, DAOs, or platform keys that can silently revoke, redirect, or seize control. Even in Web3 settings, governance multisigs and admin keys often sit below the individual in the trust stack.

Identity Bedrock asks a simple question:

- *Can we build an identity layer where the only cryptographic root is the individual’s key, and where any deeper attack must either break standard hardness assumptions or pay a clearly quantified economic cost?*

This leads to three design goals:

- **No keys beneath the user:** the Ed25519 key is the sole cryptographic root of identity; there are no CA/DAO/admin keys under it.
- **Chain-agnostic directory:** bindings between identifiers and keys live in an append-only directory (e.g., Emercoin NVS anchored via Bitcoin AuxPoW) with explicit, measurable finality and attack cost.
- **Reusable foundation:** the result is a minimal, formally grounded substrate that other schemes (DIDs, wallets, credential systems) can build on without inheriting extra institutional capture points.

The documents and code in this repository show how to realize this idea in practice, starting from Rompel’s 1990 theorem and working up through concrete deployments.

---

## The forgotten foundation: Rompel 1990

In 1990, **J. Rompel** proved that the existence of **one-way functions (OWFs)** is *necessary and sufficient* for the existence of digital signatures secure against adaptive chosen-message attacks (EUF-CMA). Together with later work (Naor–Yung, Haitner et al. on universal one-way hash functions and inaccessible entropy), this yields the classical equivalence:

\[
  \mathrm{OWF} \Leftrightarrow \mathrm{SIG}_{\mathrm{EUF\mbox{-}CMA}}
\]

Under standard definitions, this means:

- there is no signature scheme strictly below OWFs; and
- assuming OWFs exist already commits you to the possibility of signatures.

Identity Bedrock **operationalizes** this as an identity design principle:

- the only cryptographic floor is an OWF-equivalent signature scheme (here, Ed25519);
- everything else – directories, UIs, wallets, consensus – is layered above that floor;
- there are no additional root keys, CAs, DAOs, or institutional secrets "under" the individual’s key.

The various documents in `doc/` work through this idea at different levels of formality and detail.

---

## Repository layout (top-level)

- `doc/`
  - Research papers and design notes.
  - In particular, **`identity_bedrock_paper2.md`** is the current English write-up that:
    - explains the Rompel/Naor–Yung/Haitner background;
    - defines the Identity Bedrock architecture (Ed25519 key + pluggable directory);
    - describes the Emercoin NVS + NESS deployment and its attack-cost analysis.
  - `identity_bedrock_paper2-FR.md` is a French version of the same paper.

- `worm/`
  - The **WORM (Write Once, Read Many)** JSON record format and tooling.
  - Defines the simple, well-specified JSON schema used for append-only records in the Emercoin NVS directory.
  - Has its own `worm/README.md` and `worm/doc/` tree that mirror many of the Identity Bedrock notes from this root.

- `privatenesstools/`
  - Command-line tools for interacting with **Privateness** service nodes.
  - Handles key generation, encrypted file storage, node and user management, and WORM/NVS registration.
  - See `privatenesstools/README.md` for detailed usage (commands such as `keygen`, `node`, `user`, `upload`, `backup`, etc.).

- `pyuheprng/`
  - Python adaptation of Steve Gibson’s **UHEPRNG** (Ultra High Entropy PRNG).
  - Used to seed Ed25519 key generation with high-quality entropy on top of OS randomness.
  - See `pyuheprng/readme.md` for how to run the RNG services and utilities.

- `scripts/` and HTML tools
  - Wizard-style web UIs and helpers that sit on top of the bedrock layer, for example:
    - `privateness-transaction-signer.html` – a browser-based signer for Skycoin/Privateness transactions;
    - `scripts/NESS-Bedrock-wizard.html`, `scripts/PAX-ETH-wizard.html`, etc. – setup and integration helpers for specific stacks.
  - These do **not** define new cryptographic roots; they consume the Identity Bedrock keys and directory as clients.

---

## How the pieces fit together

From bottom to top:

1. **Cryptographic floor (Identity Bedrock)**
   - Ed25519 keypairs derived from high-entropy seeds (OS RNG + UHEPRNG).
   - Security reduces to standard one-way function / EUF-CMA assumptions.

2. **Directory substrate (e.g., Emercoin NVS + AuxPoW)**
   - Append-only key–value store where identity bindings `(id, pk)` are written as WORM JSON records.
   - Security quantified in terms of the cost to sustain a directory rewrite (Emercoin stake + Bitcoin AuxPoW attack).

3. **WORM JSON format**
   - A small, language-agnostic JSON schema for write-once records.
   - Used for identity bindings and for coordination data (such as NESS Fiber publisher keys).

4. **Infrastructure and services (PrivatenessTools, NESS Fiber, nodes)**
   - Tools for generating, storing, and backing up keys.
   - Service nodes that expose storage and randomness behind Ed25519-authenticated control.

5. **Applications and UX (PAX, wizards, transaction signers)**
   - Higher-level protocols and user interfaces that build on the bedrock identity and directory.
   - These layers may impose their own privacy and usability trade-offs but do not alter the cryptographic floor.

---

## Getting started

Depending on your background, there are a few natural entry points:

- **Cryptography / security theory**
  - Start with `doc/identity_bedrock_paper2.md` (or the `-FR` version) for the Rompel-based model and the security proof sketch.
  - Cross-check references `[1]` (Rompel), `[7]` (Haitner et al.), and standard texts such as Goldreich.

- **Systems / directory implementers**
  - Read the architecture and implementation sections in `identity_bedrock_paper2.md`.
  - Inspect `worm/` for the WORM JSON format and example usage.
  - Use `privatenesstools/` to experiment with actual Emercoin NVS registrations and service nodes.

- **Application / UX developers**
  - Look at the HTML wizards and transaction signers under the root and `scripts/`.
  - Treat the Ed25519 bedrock key and the WORM-based directory as given, and focus on how to build privacy-preserving flows on top.

---

## Status and scope

- This repository intentionally focuses on the *foundation* of identity – the Rompel-style OWF/signature floor and the minimal directory needed to make it useful.
- It does **not** attempt to solve all problems related to:
  - endpoint compromise and malware,
  - social engineering and phishing,
  - legal or regulatory coercion.
- Those require additional operational and social layers, which are out of scope here.

Identity Bedrock aims to make at least one thing very clear and formally grounded: **if you accept standard one-way function and signature assumptions, and you accept an append-only directory with quantified finality, then there is no softer cryptographic or institutional layer beneath the individual key on which the system secretly relies.**
=======
# EIP4361 (killer)

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
>>>>>>> 10611e2c0bf4c921fcd742ec30411886d76a7678
