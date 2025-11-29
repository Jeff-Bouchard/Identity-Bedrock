PAX: Privateness Auth eXchange
Cross‑chain cryptographic identity anchored in EmerNVS, WORM and Sky/Privateness, exposed to Ethereum via SIWE

Abstract
PAX (Privateness Auth eXchange) is a cross‑chain authentication protocol that takes cryptographic identity—Ed25519 keys controlled by users—and projects it into account‑based systems such as Ethereum without letting those systems become the identity root.

The protocol:

Anchors identity in Privateness keys and EmerNVS/WORM on the Emercoin blockchain, with Ed25519 as the canonical signing primitive.
Uses Sky/Privateness UTXO signatures as an optional on‑chain proof of UTXO control, strictly within the existing Sky transaction format (no arbitrary data fields, no consensus changes).
Presents to Ethereum a standard EIP‑4361 (Sign‑In With Ethereum) flow in which the SIWE statement asserts a Privateness identity urn:privateness:user:<username>. From the dApp’s point of view, it is interacting with a single coherent, “person‑like” subject behind an ETH key.
Exposes identities and PAX endpoints using EmerNVS/EmerDNS, Handshake .privateness, and clearnet DNS (privateness.link), relying on resolvers (such as ns74.com) that can resolve dns: records, while keeping EmerNVS/WORM + Ed25519 as the only root of identity.
PAX is intentionally conservative: it uses existing Emercoin and Sky/Privateness consensus rules unchanged, and treats all external stacks—including ETH digital ID experiments—as optional consumers of its cryptographic identity layer.

1. Motivation
1.1 Cryptographic identity vs “blockchain identity”
In many current systems, “identity” is implicitly defined by:

A blockchain account identifier (e.g. an Ethereum address).
Or a centralized account with KYC and OAuth2/OIDC on top.
In contrast, PAX starts from the observation:

If you have a public key (e.g. a Sky/Privateness or Privateness Ed25519 verify key), and you know that the same key will sign future challenges, then cryptographically you can tell “it’s you” in the future, without any particular chain being the source of truth.
Blockchains are then used to anchor, timestamp, and replicate assertions about that key (e.g. WORM records in EmerNVS), not to define the identity itself.
PAX formalizes this:

Identity = Ed25519 keypair + WORM/EmerNVS anchor.
Chains (Emercoin, Sky/Privateness, Ethereum) and DNS layers (EmerDNS, Handshake, ICANN DNS) are transport and publication layers for assertions about that key.
1.2 Threats from ETH‑centric digital ID
Current ETH‑centric trends include:

“Address‑centric identity” (you are 0xABC…).
On‑chain digital IDs (soulbound tokens, registries).
KYC/AML anchored in a few large L1s.
These designs risk turning a single public blockchain into a global identity registry.

PAX’s stance:

Ethereum is an application‑level consumer, not an identity root.
ETH addresses are bindings to a pre‑existing Privateness identity; they must be rotatable without loss of identity.
Any ETH “digital ID” contract is at best a derived view of the EmerNVS/WORM identity, not vice versa.
1.3 Design goals
PAX aims to:

Root identity in Ed25519 keys and EmerNVS/WORM, under user control.
Use Sky/Privateness UTXO signatures as canonical proof‑of‑control, without modifying Sky consensus.
Provide a standards‑aligned bridge to ETH via EIP‑4361, so existing dApps work unmodified.
Use EmerNVS/EmerDNS, Handshake .privateness, and DNS as naming and discovery layers—never as primary trust roots.
Be deployable with existing infrastructure:
Emercoin JSON‑RPC (e.g. 192.243.100.192:6662).
Resolvers like ns74.com that understand dns:–style EmerDNS records.
Avoid any mandatory centralized backend infrastructure: all hard identity and proof primitives live in on‑chain WORM/EmerNVS entries and canonical Sky/Privateness self‑spend transactions; any “PAX Bridge” is an optional, replaceable adapter built on top of these primitives.
2. Components
2.1 Privateness user keys
Privateness users have key material in:

~/.privateness-keys/user.key.json
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
Key semantics:

private: Ed25519 secret key (signing).
verify: Ed25519 public key (verification).
public: Curve25519 public key (box/encryption).
In PAX, the Ed25519 verify key is the canonical identity key; blockchains only anchor assertions about this key.

2.2 WORM + EmerNVS (Emercoin naming system)
Each user identity is anchored in EmerNVS:

NVS name:
text
worm:user:ness:<username>
Value: WORM XML, e.g.:
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
Properties:

On‑chain append‑only friendly anchor.
Binds username and Ed25519 verify to a well‑defined NVS record.
Can be extended with <identity> sub‑trees (e.g. chain bindings, metadata) without breaking existing tooling.
Consensus impact:

None. PAX treats EmerNVS as a generic key–value store with fee/expiration semantics.
WORM contents are parsed and interpreted off‑chain.
Emercoin JSON‑RPC (e.g. at 192.243.100.192:6662) can be used by PAX Bridges to call name_show and similar methods.
Resolvers:

EmerDNS and resolvers such as ns74.com can already resolve dns: records and other EmerDNS constructs.
These resolvers can expose EmerDNS/EmerNVS data to legacy DNS clients, but do not become trust roots: they are just access paths to the same on‑chain NVS data.
2.3 Sky/Privateness chain
The Privateness coin is a fork of Skycoin. From upstream:

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
Important constraints:

No OP_RETURN, no arbitrary data field.
The only native “proof of control” primitive is signing a transaction over explicit inputs (In) and outputs (Out).
PAX therefore:

Does not attempt to insert arbitrary 80‑byte payloads into Sky/Privateness transactions.
Uses canonical self‑spend transactions as optional proofs:
Wallet creates an unsigned tx spending from address A back to A (or to a small policy‑constrained set).
Signs using normal Sky rules.
The signed hex is submitted as a sky_proof object to the PAX Bridge.
Consensus impact:

None. No new opcodes, no new fields.
PAX adds wallet‑level conventions for proof transactions; the chain remains unchanged.
2.4 Ethereum & SIWE
On the ETH side, PAX assumes standard EIP‑4361 Sign‑In With Ethereum:

dApp chooses (domain, uri, nonce, chainId, issuedAt, etc.).
User signs the SIWE string with their ETH key.
dApp verifies with existing libraries.
PAX adds only one semantic requirement:

The SIWE statement includes:
text
I assert identity: urn:privateness:user:<username>
This binds the ETH address to a pre‑existing Privateness identity URN; ETH remains a consumer of that assertion, not the root.

2.5 Naming & resolution: EmerDNS, Handshake, DNS
PAX uses naming layers for discovery, not trust:

EmerDNS/EmerNVS:
dns: records describe DNS state stored in NVS.
Resolvers like ns74.com can already interpret these and expose classic A/AAAA/TXT/etc. to clients.
Handshake .privateness:
Acquired and operated purely for pragmatic reasons (registrars such as Porkbun already expose Handshake-aware DNS and gateways).
For a user alice, alice.privateness TXT may contain:
text
nvs=worm:user:ness:alice
pax_issuer=<https://id.privateness.link:54443>
Clearnet privateness.link:
Bridge domain: alice.privateness.link TXT mirrors the same
nvs
/pax_issuer.
Web profile at <https://alice.privateness.link> can display identity info resolved from EmerNVS and expose OIDC/PAX endpoints.
Crucially:

None of these naming layers become identity roots.
They can be changed or replaced (other TLDs, other resolvers) without impacting the underlying EmerNVS/WORM identity.
3. Identity Model
3.1 Canonical identity URN
PAX defines a canonical identity URN:

text
urn:privateness:user:<username>
which maps to:

Local representation: user.key.json with Ed25519 verify key.
On‑chain representation: worm:user:ness:<username> in EmerNVS, containing WORM <user verify="...">.
This URN never appears on‑chain; it is a stable handle used in protocols and tokens.

3.2 Optional aliases
Handshake: alice.privateness → TXT with nvs=..., pax_issuer=....
Clearnet: alice.privateness.link → TXT mirroring the same mapping.
EmerDNS: dns: records under EmerNVS for DNS‑level exposure (via resolvers such as ns74.com).
These aliases make the same EmerNVS‑rooted identity visible across DNS worlds without changing the trust model.
Within the same WORM record, an <identity> sub‑tree can list acceptable PAX Bridges and/or EmerFV validator names (e.g. val:privatenessnetwork) that are allowed to act as issuers for this identity. Bridges whose Ed25519 keys or JWKS hashes are attested via EmerFV under those validator keys are acceptable; this mirrors EmerFV’s validator model and avoids any single global issuer.

4. PAX Protocol
4.1 Actors
Privateness Wallet
Manages user.key.json.
Talks to EmerNVS via Emercoin JSON‑RPC (e.g. 192.243.100.192:6662).
Talks to Sky/Privateness nodes via privateness-cli or RPC.
Talks to ETH signer (locally, or via in‑browser provider).
Talks to the PAX Bridge HTTP API (/v1/pax/*).
PAX Bridge / Verifier
Issues challenges and stores them server‑side.
Queries EmerNVS to retrieve WORM identity anchors.
Verifies Ed25519 PAX‑SIGN responses.
Optionally verifies Sky self‑spend proofs and SIWE messages.
Issues PAX tokens (JWT/CWT) for consumption by services.
In the reference architecture, “PAX Bridge / Verifier” is a logical role, not a mandatory central service. It can be implemented as a local library, a CLI tool, or a lightweight per‑community HTTP daemon; multiple Bridges may exist, and Privateness.Network is not expected to operate any canonical backend. All hard trust rests in on‑chain WORM/EmerNVS anchors and canonical Sky self‑spend proofs, not in any particular Bridge instance.
dApps / relying parties
ETH dApps: use SIWE unchanged; optionally consume PAX tokens.
Other services: may consume PAX JWTs directly, or rely on the PAX Bridge introspection.*
4.2 Challenge issuance (PAX‑CHALLENGE)
The Bridge issues a signed challenge (e.g. JSON canonicalized via JCS):

json
{
  "id": "urn:privateness:user:alice",
  "session_id": "...",
  "nonce": "...",
  "issued_at": "2025-11-17T23:05:00Z",
  "expires_at": "2025-11-17T23:10:00Z",
  "purpose": "login"
}
The Bridge stores this server‑side keyed by challenge_id.

4.3 PAX‑SIGN: Ed25519 proof
The Wallet:

Loads user.key.json for alice.
Uses private (Ed25519 secret key).
Canonicalizes the challenge; signs: sig = Ed25519_Sign(private, challenge_bytes).
Returns:
json
{
  "challenge_id": "chg_...",
  "username": "alice",
  "pax_sign": {
    "challenge": { ...same JSON... },
    "signature": "base64url(ed25519_sig_bytes)"
  }
}
No Sky/Privateness tx is required here; only EmerNVS/WORM is used by the Bridge for verification.

4.4 Optional PAX‑TX: Sky self‑spend proof
To add a UTXO‑control proof:

Wallet chooses address A with spendable coins.
Calls something like:
bash
privateness-cli createRawTransactionV2 mywallet.wlt A 1 \
    --from-address A \
    --unsign \
    --json
Signs the returned raw tx hex with signTransaction.
Sends:
json
"sky_proof": {
  "tx_hex": "<signed_tx_hex>",
  "network": "privateness-mainnet"
}
The Bridge decodes the tx using standard Sky rules and checks a canonical self‑spend policy (e.g. all outputs back to addresses under the same wallet or as described in <identity> WORM).

4.5 Optional SIWE: ETH binding
If the session also requires ETH:

dApp presents a SIWE message that includes:
text
I assert identity: urn:privateness:user:alice
Wallet signs it with the ETH key (e.g. via personal_sign).
PAX completion includes:
json
"siwe": {
  "message": "raw SIWE message",
  "signature": "0x...eth_signature"
}
The Bridge verifies SIWE with existing libraries and, if desired, records the binding ETH address ↔ URN in WORM <identity>.

5. Verification Logic
On /v1/pax/complete, the Bridge:

Challenge binding
Retrieves stored challenge by challenge_id.
Ensures pax_sign.challenge matches stored challenge (id, nonce, session_id, expiry).
Identity via WORM + Ed25519
Ensures pax_sign.challenge.id == "urn:privateness:user:" + username.
Queries EmerNVS:
text
name_show "worm:user:ness:" + username
Extracts Ed25519 verify from WORM.
Canonicalizes the challenge; verifies Ed25519_Verify(verify, challenge_bytes, sig).
Optional Sky proof
If sky_proof is present:
Decodes the tx using Skycoin rules.
Verifies signatures, ensures a canonical self‑spend pattern.
Associates those UTXOs with the same identity.
Optional SIWE
If siwe is present:
Verifies SIWE signature and domain/nonce.
Optionally records the ETH address binding in WORM <identity>.
Token issuance (PAX token)
Issues a JWT/CWT with:
sub = "urn:privateness:user:alice".
Fields for NVS name, ETH address, Sky addresses/proof txid.
Publishes Bridge public keys as Ed25519 JWKS whose hashes are anchored in EmerNVS/EmerFV under validator keys (e.g. val:privatenessnetwork). Any HTTPS or IPFS URL may serve a copy of this JWKS; for example:
text
<https://id.privateness.link:54443/v1/pax/jwks>
Verifiers MUST treat the EmerNVS/EmerFV anchor (plus the user’s WORM <identity> accepted‑issuer list) as the trust root and MUST only accept JWKS documents whose content matches the on‑chain hash. The URL is a distribution channel, not an authority.
6. Security & Privacy Analysis
6.1 Trust root
Root of identity: Ed25519 verify key anchored in WORM/EmerNVS.
Chains are transport: Emercoin provides anchoring; Sky/Privateness provides optional UTXO proofs; Ethereum provides SIWE binding.
Naming layers (EmerDNS, Handshake .privateness, privateness.link) and resolvers (ns74.com or others) are federated discovery mechanisms, not authorities.
6.2 No consensus changes
Emercoin:
PAX uses existing NVS semantics via JSON‑RPC; no protocol forks.
Sky/Privateness:
PAX uses standard transaction structs and signature rules; no new data fields.
Ethereum:
PAX uses EIP‑4361 without modification.
This is important for both Emercoin and Skycoin design philosophies: PAX enables new identity behavior entirely at the application and wallet layers, not by mutating their consensus logic.

6.3 Threats and mitigations
Compromised Emercoin node / resolver:
A malicious Emercoin RPC endpoint (or resolver) could lie about WORM contents.
Mitigation: clients/Bridges can query multiple independent Emercoin nodes and EmerDNS resolvers and compare results; WORM contents are signed at the application layer; chains provide ordering and availability.
Compromised PAX Bridge:
A malicious Bridge could mis‑issue tokens.
Mitigation: Bridges are identified by their own Ed25519 keys and EmerNVS records; clients can choose which Bridges to trust, or operate their own.
ETH‑side attacks:
Replay or misuse of SIWE messages is mitigated by standard SIWE nonce, domain, and expiry checks.
ETH digital ID contracts remain external; PAX does not depend on any such contract as a source of truth.
Fingerprinting / privacy:
The URN and WORM records are stable identifiers; naive use can lead to linkability.
Future work includes zero‑knowledge and selective disclosure on top of PAX tokens, and patterns for ephemeral URNs derived from the same root key.
7. Implementation & Demonstration
PAX is designed to be demonstrable with minimal tooling:

EmerNVS lookup: scripts or services call Emercoin JSON‑RPC (e.g. 192.243.100.192:6662) and/or use resolvers like ns74.com to retrieve WORM records for worm:user:ness:<username>.
Sky self‑spend: privateness-cli createRawTransactionV2 + signTransaction produce standard Sky transactions that can be decoded and verified.
Ed25519 PAX‑SIGN: small utilities use the private field from user.key.json to sign the challenge and emit pax_sign JSON.
ETH‑side wizard: a static HTML wizard uses window.ethereum and eth_chainId/personal_sign to:
Generate PAX‑compatible SIWE messages asserting urn:privateness:user:<username>.
Sign them with any wallet.
Verify the signatures locally.
These demonstrations show that PAX can be implemented today, without protocol changes, using real chain data and real keys.

8. Research Questions and Future Work
PAX opens several lines of research:

Formal WORM <identity> schema
Define a minimal XML vocabulary under <user> for chain bindings (ETH addresses, Sky addresses, PAX Bridges, service endpoints).
Study update and revocation patterns over EmerNVS’s fee/expiration model.
Canonical Sky proof patterns
Rigorously define canonical self‑spend transaction policies (output layout, coin/hour constraints).
Explore analysis tools for proofs that combine UTXO flow with WORM identity assertions.
Multi‑resolver trust model
How to formally combine signals from Emercoin RPC nodes, EmerDNS resolvers (including ns74.com), Handshake gateways, and legacy DNS.
Quantify failure modes described in DNS research (including work such as the Ariadne’s thread paper) in the context of PAX’s anchored WORM records.
Selective disclosure & ZK
Layer zero‑knowledge proofs and selective disclosure mechanisms over PAX tokens so that applications can verify “this key belongs to a valid PAX identity” without learning full URNs or NVS names.
Federated Bridges and governance
Multiple PAX Bridges, each with its own JWKS and EmerNVS anchor, can coexist.
Study governance patterns where communities or services choose different subsets of Bridges and resolvers without fragmenting the identity layer.
9. Conclusion
PAX is a deliberately minimal, technically conservative protocol that:

Treats cryptographic keys as the essence of identity.
Uses EmerNVS/WORM as a robust, append‑only anchor for those keys, with no change to Emercoin consensus.
Uses Sky/Privateness only through canonical self‑spend transactions, again without protocol changes.
Projects this identity into Ethereum and other account‑based systems via standard EIP‑4361 SIWE, making those systems consumers of identity, not its source.
Uses EmerDNS, Handshake .privateness, and clearnet DNS as replaceable naming and discovery layers, supported by resolvers like ns74.com, without ever turning them into roots of trust.
In this architecture, sending a Sky/Privateness or Privateness public key genuinely allows future recognition “without any doubt” in a cryptographic sense; blockchains and DNS only help track, distribute, and time‑stamp the associated assertions.

PAX is thus less a new blockchain system and more an auth exchange layer that enables existing projects—Emercoin, Sky/Privateness, and Ethereum—to interoperate around user‑controlled cryptographic identity, while resisting capture by any single “digital ID” stack.
