PAX: Privateness Auth eXchange
Escaping ETH Digital ID via EmerNVS, WORM, Sky/Privateness and Handshake
Abstract
This document proposes PAX (Privateness Auth eXchange), a cross‑chain authentication protocol that:

Anchors identity in Privateness keys and EmerNVS/WORM on the Emercoin chain, with Ed25519 as the canonical signing primitive.
Uses Sky/Privateness UTXO signatures as optional on‑chain proofs of control, respecting the existing transaction format (no arbitrary data fields).
Presents to Ethereum and other account‑based systems a familiar “one subject per key” abstraction via EIP‑4361, so that from the dApp’s point of view it is interacting with a single coherent person‑like subject.
Integrates with Ethereum solely via EIP‑4361 (Sign‑In With Ethereum) in a way that explicitly avoids ETH becoming the global “digital identity” root.
Exposes the system globally using Handshake DNS (.privateness) and standard DNS (privateness.link) so that resolution and identity claims are made available to the clearnet on our own terms, while EmerNVS/WORM remains the only root of identity.
ETH dApps remain unchanged: they still see only a standard ETH account and a SIWE message. The complexity of cross‑chain identity, proofs, and policy lives entirely inside the Privateness stack.

Why PAX matters now

In simple terms, PAX matters because it separates **who you are** from **which chain or provider you happen to use today**:

- Your real identity is the Ed25519 keypair anchored in EmerNVS/WORM. Chains (Emercoin, Sky/Privateness, Ethereum) and DNS layers (EmerDNS, Handshake, ICANN DNS) are just transport and publication layers for assertions about that key.
- Ethereum and other L1s become **consumers of identity assertions**, not global identity registries. You can rotate or abandon ETH addresses without losing your underlying identity.
- Emercoin and Sky/Privateness keep their consensus rules exactly as they are; PAX builds entirely on existing primitives (NVS/WORM, standard Sky transactions) instead of demanding protocol changes.
- For ETH dApps, nothing special is required: they see a normal SIWE flow, but behind that flow there is a cryptographic identity anchored outside ETH.

This lets Small Tech systems re‑use the big chains where useful, without ever ceding control of identity to them.

1. Motivation
Today’s mainstream identity trends push towards:

Address‑centric identity (e.g. “you are 0xABC… on Ethereum”),
On‑chain digital IDs (soulbound tokens, ERC‑725, registries),
Often KYC/AML anchoring in ETH or other “big” L1s.
For Privateness.Network, this is unacceptable:

The user’s true identity must be controlled at the Privateness layer (Ed25519 keys, EmerNVS/WORM), not by external chains.
ETH (and other chains) should be consumers of identity assertions — not sources of truth.
Identity must be portable and rotatable across chains without losing sovereignty or leaking a global handle.
At the protocol level, the identity layer should be able to present itself to account‑based systems (such as ETH) as a single coherent subject – “as if it were a real person” – while keeping the actual authority and revocation power in EmerNVS/WORM.
The goal of PAX is to provide:

A clean, standards‑aligned bridge from Privateness identities to ETH (and back), compatible with SIWE / OAuth2 / OIDC.
Strong anchors in EmerNVS/WORM and optionally Sky/Privateness UTXOs.
A global naming and resolution layer via Handshake .privateness, with clearnet accessibility through privateness.link and resolver infrastructure.
Importantly, PAX itself requires no mandatory centralized backend: all hard identity and proof primitives live on‑chain (EmerNVS/WORM plus canonical Sky/Privateness self‑spend transactions), and any "PAX Bridge" is an optional, replaceable adapter that communities or users can run locally or per‑service, with trust anchored only in those on‑chain records.

2. Components
2.1 Privateness user keys (privatenesstools)
Privateness users already have key material defined by privatenesstools:

Stored in ~/.privateness-keys/user.key.json
Structure (simplified):
json
{
  "filedata": { "vendor": "Privateness", "type": "key", "for": "user" },
  "username": "alice",
  "private": "<base64 Ed25519 signing key>",
  "public": "<base64 Curve25519 public key>",
  "verify": "<base64 Ed25519 verify key>",
  "nonce": "...",
  "signatures": { ... },
  "worm": "<worm XML>"
}
Key material:

private → Ed25519 signing key.
verify → Ed25519 verify (public) key.
public → Curve25519 public key for box/encryption.
This verify key is the Privateness identity key for Ed25519.

2.2 WORM + EmerNVS (Emercoin naming system)
Privateness already uses WORM (XML) embedded in EmerNVS:

NVS name for a user:
text
worm:user:ness:<username>
Value: XML:
xml
<worm>
  <user type="ness"
        public="..."
        verify="..."
        nonce="...">
    <signatures>...</signatures>
    <!-- extension point: <identity>...</identity> -->
  </user>
</worm>
This is an on‑chain, append‑only friendly identity anchor:

It ties a username and Ed25519 verify to an Emercoin NVS record.
It can be extended (e.g. with <identity> tags for cross‑chain bindings) without breaking existing tooling.

Importantly, this use of EmerNVS does not require any change to Emercoin consensus rules. PAX treats NVS as a generic key–value registry with well‑defined lifetime and fee semantics and interprets the WORM payload off‑chain.

2.3 Sky/Privateness chain
The Privateness coin is a Skycoin fork. From upstream Transaction:

go
type Transaction struct {
    Length    uint32
    Type      uint8
    InnerHash cipher.SHA256

    Sigs []cipher.Sig
    In   []cipher.SHA256
    Out  []TransactionOutput
}

type TransactionOutput struct {
    Address cipher.Address
    Coins   uint64
    Hours   uint64
}
Important facts:

There is no OP_RETURN or arbitrary data field in the transaction format.
The only native primitive for “proof of control” is signing a transaction over specific inputs (In) and outputs (Out).
So, PAX cannot piggyback arbitrary 80 bytes inside a Sky tx. Instead, it uses canonical transaction patterns as proofs.

Again, no change to the Sky/Privateness transaction format or consensus logic is required. PAX only constrains how wallets construct and present transactions as proofs, leaving the base protocol untouched.

2.4 Ethereum & SIWE
For ETH, PAX assumes standard EIP‑4361 Sign‑In With Ethereum:

DApp chooses a domain, uri, nonce, etc.
User signs the SIWE message with an ETH private key.
DApp verifies EIP‑4361 using existing libraries.
PAX will treat SIWE as an optional binding between a Privateness identity and one or more ETH addresses, without ETH ever becoming the root.

2.5 Handshake & .privateness + privateness.link
To expose this system to the world “on our own terms”, without introducing a new root of trust:

Handshake: acquire and operate .privateness as a Handshake TLD. In this design, Handshake is chosen primarily for pragmatic reasons (registrars such as Porkbun already provide Handshake-aware DNS and gateway UX); any equivalent naming or bridge mechanism could be substituted without changing the PAX trust model or identity root.
Each identity could use a label such as alice.privateness.
DNS records (A/AAAA/TXT/SRV) can embed:
PAX issuer metadata,
EmerNVS identifiers (e.g. nvs=worm:user:ness:alice),
ETH mappings (eth=0x...).
Clearnet bridge:
privateness.link (normal DNS) and id.privateness.link host:
The HTTP PAX API.
Web dApps.
Resolvers that map .privateness Handshake names to EmerNVS/WORM records and PAX endpoints.
With Porkbun supporting Handshake, resolution of .privateness can be made accessible to normal browsers via their nameservers or gateway UX.

3. Identity Model
3.1 Canonical identity ID
We define the canonical identity as a URN:

text
id = "urn:privateness:user:" + <username>
Example:

text
urn:privateness:user:alice
This yields:

Local representation: user.key.json for alice.
NVS representation: worm:user:ness:alice → WORM <user> with verify.
The URN is never on-chain; it’s an internal canonical identifier that all components use.

3.2 Optional aliases
Handshake: alice.privateness → TXT containing:
text
nvs=worm:user:ness:alice
pax_issuer=<https://id.privateness.link:54443>
Clearnet: alice.privateness.link → optionally CNAME or TXT mirroring the same nvs=/pax_issuer data.

4. PAX Protocol
4.1 Actors
Privateness Wallet
Manages user.key.json.
Talks to EmerNVS (via Emercoin).
Talks to Sky/Privateness node (via privateness-cli or RPC).
Optionally manages / talks to an ETH signer.
Talks to PAX bridge HTTP API (local or remote).
PAX Bridge / Verifier (id.privateness.link:54443)
Issues challenges.
Verifies Ed25519 signatures.
Optionally verifies Sky tx proofs.
Verifies SIWE where requested.
Issues PAX tokens (JWT/CWT) for internal consumption.
ETH dApps
Only use standard SIWE / EIP‑4361.
Do not need to know about PAX or EmerNVS.

4.2 PAX Challenge
Bridge issues a JSON challenge:

json
{
  "id": "urn:privateness:user:alice",
  "session_id": "3e5f1a0b2c9043ef9bba5030d43a7d12",
  "nonce": "b94626b8ee4c4a88a295948ab2c9fa10",
  "issued_at": "2025-11-17T23:05:00Z",
  "expires_at": "2025-11-17T23:10:00Z",
  "purpose": "login"
}
This challenge:

Is canonicalized with JCS before signing (challenge_bytes = JCS(challenge_json)).
Is stored server‑side with a random challenge_id.

4.3 PAX‑SIGN: Ed25519 response
Privateness Wallet:

Loads user.key.json for alice.
Decodes private (Ed25519 secret key).
Signs:
text
sig = Ed25519_Sign(private, challenge_bytes)
Sends this object to the bridge:

json
{
  "challenge_id": "chg_01HRFQ9H3T0ZQDJEXAMPLE",
  "username": "alice",
  "pax_sign": {
    "challenge": {
      "id": "urn:privateness:user:alice",
      "session_id": "...",
      "nonce": "...",
      "issued_at": "2025-11-17T23:05:00Z",
      "expires_at": "2025-11-17T23:10:00Z",
      "purpose": "login"
    },
    "signature": "base64url(ed25519_sig_bytes)"
  }
}
No Sky/Privateness chain interaction is needed for this step; it uses only user.key.json and EmerNVS for verification.

4.4 Optional PAX‑TX: Sky self‑spend proof
If we also want a Sky UTXO control proof, the wallet:

Chooses a wallet address A with coins.
Runs:
bash
./privateness-cli createRawTransactionV2 mywallet.wlt <A> 1 \
    --from-address <A> \
    --unsign \
    --json
Extracts unsigned tx hex from JSON.
Signs it:
bash
./privateness-cli signTransaction mywallet.wlt <raw_unsigned_hex> --json
The signed tx hex tx_hex is sent as:

json
"sky_proof": {
  "tx_hex": "<signed_tx_hex>",
  "network": "privateness-mainnet"
}
The bridge can then decode and verify this tx using Skycoin consensus rules.

4.5 Optional SIWE: ETH binding
For sessions that also require ETH:

Wallet exposes ETH account 0xABC... (internal or external).
DApp sends EIP‑4361 SIWE message:
text
dapp.example wants you to sign in with your Ethereum account:
0xABC...

I assert identity: urn:privateness:user:alice

URI: <https://dapp.example/login>
Version: 1
Chain ID: 1
Nonce: <random>
Issued At: <ISO8601>
Wallet signs it; result is included in PAX completion:
json
"siwe": {
  "message": "raw SIWE message",
  "signature": "0x...eth_signature"
}

5. PAX Verification Logic
On /v1/pax/complete:

5.1 Verify challenge binding
Retrieve stored challenge by challenge_id.
Confirm pax_sign.challenge equals the stored challenge.
Check expires_at not passed; session_id matches; optional client nonce, etc.

5.2 Verify identity via WORM + Ed25519
From username and pax_sign.challenge.id:
Require pax_sign.challenge.id == "urn:privateness:user:" + username.
Query EmerNVS:
name_show "worm:user:ness:" + username → WORM <user verify="...">.
Decode verify (base64) → auth_pub (Ed25519 pubkey).
Canonicalize pax_sign.challenge via JCS → challenge_bytes.
Verify:
text
Ed25519_Verify(auth_pub, challenge_bytes, sig)
If valid, identity is authenticated as urn:privateness:user:alice.

5.3 Optionally verify Sky proof
If sky_proof.tx_hex is provided:

Decode tx using Skycoin tx parser (or decodeRawTransaction).
Verify signatures with standard Sky rules.
Check tx is a canonical self-spend under some fixed policy:
At least one output to an address controlled by this wallet (if known via WORM <identity>).
No third-party addresses, or only per policy.
If valid, you know the same user (or system) controls those UTXOs.

5.4 Optionally verify SIWE
If siwe is present (and required):

Parse SIWE message.
Recover ETH address from signature.
Check:
address matches recovered address.
domain matches expected dApp domain.
nonce matches a value you issued.
Optionally bind that ETH address to this Privateness identity in WORM <identity> for persistence.

6. PAX Tokens
On success, the bridge may issue a PAX token (JWT/CWT):

6.1 Example JWT payload
json
{
  "iss": "<https://id.privateness.link:54443>",
  "sub": "urn:privateness:user:alice",
  "aud": "dapp.example",
  "iat": 1731884700,
  "exp": 1731888300,

  "nvs": {
    "user": "worm:user:ness:alice"
  },

  "eth": {
    "addr": "0xABCDEF1234567890...",
    "chainId": 1
  },

  "sky": {
    "addresses": ["<sky_addr>"],
    "proof_txid": "optional-txid"
  }
}
Signed with Ed25519 (JWS alg: "EdDSA"), with public keys published at:

text
<https://id.privateness.link:54443/v1/pax/jwks>
ETH dApps don’t need this JWT if they only depend on SIWE. The JWT is useful for:

Privateness services,
Cross‑chain apps,
Or external verifiers that want to consume Privateness identities directly.

7. Handshake .privateness Integration
7.1 TLD design
Acquire .privateness TLD in Handshake.
Authoritative DNS for .privateness is under your control.
For each user alice:

Define alice.privateness in Handshake DNS with TXT records:
text
nvs=worm:user:ness:alice
pax_issuer=<https://id.privateness.link:54443>
eth_addr=0xABCDEF1234567890...
This lets:

Handshake‑aware resolvers discover the EmerNVS identity anchor (worm:user:ness:alice) and the PAX issuer endpoint.
Optionally, ETH addresses or other chain bindings.

7.2 Clearnet bridge via privateness.link
To expose .privateness to “normal” DNS clients:

Use privateness.link as a bridge domain.
For each identity, define e.g.:
alice.privateness.link → TXT with the same metadata:
text
nvs=worm:user:ness:alice
pax_issuer=<https://id.privateness.link:54443>
eth_addr=0xABCDEF1234567890...
Optionally expose a web profile at <https://alice.privateness.link> that:
Shows identity info resolved from EmerNVS.
Links to PAX / OIDC endpoints.
Porkbun (as a registrar that supports Handshake) can be used to:

Host the .privateness zone or bridge it into regular DNS.
Offer endpoints that resolve .privateness TLDs for users without Handshake‑aware resolvers.

7.3 Governance advantages
By using .privateness on Handshake plus privateness.link on legacy DNS:

Resolution is anchored in your infrastructure and EmerNVS, not in ICANN or ETH.
You can define how names resolve and what identity data is exposed.
You can change or drop ETH bindings without breaking the underlying Privateness identity.

8. Security & Privacy Properties
Root of identity: Ed25519 verify key + WORM/EmerNVS (worm:user:ness:username).
Chain proofs:
Sky/Privateness: canonical self-spend tx (optional).
EmerNVS: WORM record ensures append‑only semantics and an on‑chain audit trail.
ETH is not the root:
ETH accounts are bindings to Privateness identities via SIWE.
PAX can rotate/droop ETH addresses without losing identity.
No Sky OP_RETURN:
Design respects the actual Sky tx format (no arbitrary data field).
Uses existing transaction signature primitives as proof-of-control.
Minimal on-chain writes:
EmerNVS: WORM entries change rarely (identity updates).
Sky: optional registration or proof tx, not per‑login.
Daily logins: off‑chain Ed25519 + SIWE only.
Compatibility:
ETH dApps see only SIWE; no protocol changes required.
PAX tokens/JWKS can be consumed by standard OAuth2/OIDC infrastructure.
Handshake .privateness and privateness.link expose identity and PAX endpoints via pure DNS.

9. Future Work
Formal WORM <identity> schema:
Define a standard XML sub‑tree under <user> for chain bindings.
Sky proof standardization:
Tight canonicalization rules for self-spend tx (e.g. deterministic UTXO selection, coins/hours policy).
Multiple roots:
Support identity roots not only by username but also by chain‑specific URNs:
urn:privateness:sky:<sky_addr>
urn:privateness:emc:<emc_addr>
Multi‑resolver strategy:
Multiple PAX issuer endpoints and JWKS sets, anchored via EmerNVS and Handshake.
Privacy extensions:
Use of zk‑proofs or selective disclosure over PAX tokens for stateful apps.
This proposal shows how Privateness.Network can project its identities into ETH and the broader Internet while maintaining EmerNVS/WORM as the sovereign root of identity, with Handshake .privateness and privateness.link acting only as naming and discovery layers. Ethereum and similar systems see a familiar person‑like subject through SIWE and related flows, but the actual authority remains in Ed25519 keys anchored in EmerNVS, avoiding ETH‑centric digital ID regimes and preserving user freedom.

Feedback submitted
