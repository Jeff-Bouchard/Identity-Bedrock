Identity Bedrock over Emercoin NVS and Skycoin‑Type Chains
Draft for review

Abstract
We isolate the minimal cryptographic structure needed to authenticate a labeled entity, and instantiate it using:

one‑way functions as the hardness floor (via Rompel),
Ed25519 signatures,
Emercoin’s blockchain and Name–Value Storage (NVS), and
WORM (World Object Mapper) JSON objects as identity records.
In the classical PPT model, public‑key signatures (and hence publicly verifiable authentication) exist if one‑way functions exist (Rompel, STOC 1990). We treat this as an unnegotiable floor: no strictly weaker primitive inside the usual model can undercut it.

Acronym summary (for quick reference):

- **PPT** – Probabilistic Polynomial-Time (adversary model).
- **OWF** – One-Way Function.
- **EUF-CMA** – Existential Unforgeability under Chosen-Message Attack (signature security).
- **NVS** – Name–Value Storage (Emercoin’s on-chain key/value table).
- **WORM** – World Object Mapper (JSON schema used for identity objects).
- **PoS** – Proof-of-Stake consensus blocks on Emercoin.
- **AuxPoW** – Auxiliary Proof-of-Work blocks referring to Bitcoin work.
- **PKI** – Public Key Infrastructure.
- **IdP** – Identity Provider (centralized auth authority we purposely avoid).

Operational note: production keys are minted locally through KeyGen using a deployment-configured entropy source mixed into a UHEPRNG state before key material is produced. This document does not assume Emercoin RC4OK in the local keygen path.

Above this floor we add only:

a directory D binding identifiers id to public keys pk
(implemented as WORM JSON in Emer NVS), and
a challenge–response predicate Auth(id, c, σ) built from any EUF‑CMA secure signature scheme (instantiated here with Ed25519).
There is no Identity Provider, no CA root, no institutional key somewhere “under” the user; the only cryptographic root of trust is the individual sk plus Emer’s consensus assumptions. Any future Digital ID regime can only live strictly above this bedrock.

1. Motivation: resistance to Digital ID capture
The concrete adversary here is not “some hacker” but:

a global Digital ID stack (IdPs, SAML/OIDC providers, mobile OSes, X.509 CAs, cloud, KYC infrastructure),
with essentially unlimited conventional resources and political backing, and
full willingness to outlaw or deplatform alternatives.
What they do not control are:

the existence of one‑way functions, and
the consensus dynamics of chains they do not dominate economically.
The goal here is therefore not “integration” or “compliance”, but to deny such a regime any cryptographic foothold under the individual:

No institutional secret key appears in the definition of authentication.
No registry key, CA root, or IdP is assumed at the bedrock level.
Any attempt to recenter trust must move upwards (governance, distribution, coercion), because inside the usual PPT model there is nothing strictly below this construction to capture.
2. Hardness floor: one‑way functions and signatures
We work in the standard model of probabilistic polynomial‑time (PPT) adversaries.

2.1 One‑way functions (OWF)
A (family of) one‑way function(s) is an efficiently computable map
f : {0,1}* → {0,1}* such that any PPT adversary A given f(x) has only negligible probability of finding any preimage x' with f(x') = f(x).

Rompel, “One‑Way Functions are Necessary and Sufficient for Secure Signatures”, STOC 1990
(full text: <https://www.cs.princeton.edu/courses/archive/spr08/cos598D/Rompel.pdf>)

proves:

OWF ⇒ there exists a EUF‑CMA signature scheme.
EUF‑CMA signature scheme ⇒ OWF exist.
So OWF are the minimal hardness assumption for signatures in the classical PPT model. There is no strictly weaker primitive under them that still supports public‑key authentication.

2.2 Digital signatures
We use an abstract signature scheme
Σ = (KeyGen, Sign, Verify) with the standard API:

KeyGen(1^λ) → (sk, pk)
Sign(sk, m) → σ
Verify(pk, m, σ) ∈ {0,1}
and EUF‑CMA security in the usual sense (see, e.g., Goldreich, Foundations of Cryptography, or Slamanig’s lecture: <https://danielslamanig.info/lectures/MC19_Lecture13.pdf>).

In practice we instantiate Σ as Ed25519 (RFC 8032): <https://datatracker.ietf.org/doc/html/rfc8032>.

3. Identity objects and directory
3.1 Identity
An identity is simply:

text
I := (id, pk)
id: arbitrary unique label (string, URN, hash of metadata, …).
pk: public verification key output by KeyGen.
3.2 Directory D and binding predicate
We assume a public directory:

text
D ⊆ ID × PK
with predicate:

text
Bind(id, pk) = 1  ⇔  (id, pk) ∈ D.
The bedrock layer is agnostic to how D is realized, as long as all honest verifiers agree on Bind. There is no assumption of X.509, CAs, or IdPs at this level.

4. Instantiation: WORM + Emercoin NVS
4.1 Emercoin NVS
Emercoin’s blockchain embeds Name–Value Storage (NVS): <https://emercoin.com/en/emercoin-blockchain>.

We treat:

the Emer ledger as an append‑only log, secured by Emer’s hybrid Proof‑of‑Stake + Bitcoin AuxPoW consensus (see e.g. <https://emercoin.com/en/news/main-features-of-hybrid-mining/>), and
NVS as a key–value table on that log.
Explorers show blocks flagged PoS and PoW; the PoW blocks are AuxPoW blocks referencing real Bitcoin work. Deep reorgs across those PoW “walls” are therefore BTC‑scale expensive, on top of Emer’s PoS stake requirements.

4.2 World Object Mapper (WORM)
The World Object Mapper (WORM) in the Ness / Privateness stack encodes structured “world objects” (users, nodes, services) as JSON values suitable for NVS.

Relevant repos:

Ness Service Node: <https://github.com/NESS-Network/NessNode>
Privateness Tools: <https://github.com/NESS-Network/PrivatenessTools>
Commands like:

text
./key worm master01.key.json
./key worm http%3A%2F%2Fmy-node.net.key.json
take local JSON and output NVS values. Among other fields, such objects can contain:

an identifier id, and
a public key pk (Ed25519) intended as the verification key for that identity.
Instantiation of D.

D = set of all WORM objects committed in Emer NVS.
Bind(id, pk) = 1 iff the finalized WORM object for id in the Emer chain contains pk in the agreed field.
This is the only place Emer appears in the bedrock.

5. Authentication protocol
5.1 Roles
Prover P:
Holds sk with corresponding pk.
There exists id with Bind(id, pk) = 1.
Verifier V:
Knows id.
Has read access to D (Emer NVS + WORM).
Can recover pk via Bind.
5.2 Setup
(sk, pk) ← KeyGen(1^λ).
A WORM object for (id, pk) is published into Emer NVS and allowed to reach finality (PoS + BTC‑AuxPoW depth).
From this point on, all honest verifiers regard Bind(id, pk) = 1.
5.3 Online challenge–response
Challenge.
V samples fresh random c and sends it to P.
Response.
P computes σ := Sign(sk, c) and returns σ.
Verification.
V accepts that it is talking to id iff:
text
Auth(id, c, σ) = 1
where
text
Auth(id, c, σ) :=
  \[ ∃ pk : Bind(id, pk) = 1  ∧  Verify(pk, c, σ) = 1 \].
No extra state, authority, or infrastructure appears in this definition.

6. Security statement
Fix an identity (id, pk) with Bind(id, pk) = 1. Let A be a PPT adversary that does not know sk.

Game:

(sk, pk) ← KeyGen(1^λ).
Publish (id, pk) as a WORM record in Emer NVS.
Give A:
description of Σ,
read access to D,
public key pk,
oracle access to Sign(sk, ·) on arbitrary messages.
Eventually A outputs (id*, c*, σ*).
A wins if:
id* = id,
Auth(id, c*, σ*) = 1, and
c* was never signed via the oracle.*
Authentication soundness.

If Σ is EUF‑CMA secure, then for all PPT adversaries A:

text
Pr\[ A wins \] ≤ negl(λ).
Sketch: a winning A immediately yields a EUF‑CMA forger by forwarding its signature queries and outputting (c*, σ*) when A wins. Since Verify(pk, c*, σ*) = 1 and c* was not queried, this contradicts EUF‑CMA except with negligible probability.*

By Rompel, existence of such Σ is equivalent to existence of OWF. There is no strictly weaker hardness assumption inside the usual model that can still support this protocol.

7. Relation to Skycoin‑type chains
Skycoin‑type chains (Skycoin, Privateness descendants, similar UTXO chains) use:

Ed25519 keypairs, and
a UTXO model without a general script VM.
In the Ness / Privateness ecosystem the same Ed25519 keypair (sk, pk) is used:

for Emer NVS identity bindings ((id, pk) in WORM), and
for addresses on Skycoin‑type chains.
This allows an optional canonical self‑spend transaction:

Spend from a Skycoin‑type address, pay back to the same address, sign with sk.
Export transaction hex and/or txid.
Wrap as a sky_proof JSON containing:
network,
address,
policy (canonical self‑spend),
txid,
unsigned_tx_hex,
signed_tx_hex.
Verifiers can then check that:

the chain’s Ed25519 address really is controlled by pk, and
pk is the same key as in Bind(id, pk) on Emer.
This is an optional strengthening; the bedrock authentication only needs (id, pk) + signatures.

8. Threat model
8.1 Assumptions
Hardness: One‑way functions exist (⇔ EUF‑CMA signatures exist).
Key generation: KeyGen has access to high-entropy local sources (OS RNG and UHEPRNG-based mixing) so `sk` is unpredictable.
Directory consistency: Emer’s PoS + Bitcoin‑AuxPoW consensus maintains an append‑only NVS view. Once a WORM record (id, pk) is deeply buried (including behind BTC‑AuxPoW “PoW” walls), rewriting it requires large‑scale consensus capture.
8.2 Adversary capabilities
We do not claim to prevent:

key compromise (side channels, malware, physical),
censorship or outlawing of software,
client hijack via distribution channels.
Given the assumptions, remaining impersonation strategies are:

Signature forgery
Forge (c*, σ*) with Verify(pk, c*, σ*) = 1 without access to Sign(sk, c*).
Violates EUF‑CMA ⇒ violates OWF existence.
Directory rewrite (Emer consensus capture)
Produce an alternative Emer chain whose finalized NVS state binds id to pk' ≠ pk.
Requires economic control over:
enough EMC stake to dominate PoS, and / or
enough Bitcoin hashpower pointed at Emer’s AuxPoW interface to out‑produce honest AuxPoW blocks.
Client / governance redirection
Modify clients or governance so that verifiers use a different directory D' (different NVS keys, different WORM schema).
This does not violate the mathematical definition of Auth, but can mislead users into trusting the wrong directory.*
There is no other cryptographic “hole” below the individual key; any attack that does not steal sk must either attack OWF/signatures or Emer consensus.

9. Emercoin as hardened substrate (“weaponization”)
We do not alter Emercoin’s consensus or NVS. Instead we use them in the most adversarial way we can specify:

Emer’s role is reduced to one function:
maintain an append‑only directory of WORM objects binding id to pk under PoS + BTC‑AuxPoW.
All higher‑level trust is stripped away:
there is no PKI, no X.509 root, no IdP key hidden underneath the user’s key. The only cryptographic root of trust is the individual’s sk plus the OWF floor.
The attack surface is forced upward:
without key compromise, any attempt to recenter identity must:
break EUF‑CMA (and hence OWF), or
capture Emer consensus deeply enough to rewrite NVS history, or
redirect clients to some D'.
In that sense we “weaponize” Emercoin: we use its PoS + BTC‑AuxPoW ledger and NVS not as a general config store, but as a minimal, formally specified substrate for identity bindings that remains secure even against a global Digital ID adversary living above the protocol.

10. Conclusion
Inside the classical PPT model, one‑way functions are the weakest assumption under which EUF‑CMA signatures (and hence public authentication) are possible. This construction:

fixes that as the hardness floor,
adds only a binding directory (id, pk) realized as WORM JSON in Emer NVS, and
defines authentication as the minimal challenge–response predicate Auth(id, c, σ).


There is nothing else “below” it to capture. Any regime that wants to control identity must do so above this bedrock, on the same terms as everyone else, or pay the price of breaking OWF‑level assumptions or Emercoin’s consensus.

That is the point.
