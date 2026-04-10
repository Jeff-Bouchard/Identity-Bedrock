## Identity Bedrock: Operationalizing Rompel's Minimal Cryptographic Substrate for Sovereign Identity

**Authors:** \[Jean-François Bouchard\]

Affiliations: privateness.network: co-founder, CTO.
			  emercoin.com/team: Community activist (volunteer)

**Structure:**

**Theoretical Foundation:** Rompel (1990) proved one-way functions are necessary and sufficient for digital signatures. We operationalize this as the irreducible floor for public authentication.

**Design:** Identity Bedrock separates identity cryptography (Ed25519) from directory consensus (chain-agnostic). Any append-only ledger with quantifiable finality can host identity bindings.

**Implementation:** Deployed on Emercoin NVS (hybrid PoS + Bitcoin AuxPoW), with NESS Fiber infrastructure. Attack cost inherits from directory choice; for Bitcoin anchoring we estimate an attack cost on the order of $5-20B \[5\].

**Key Property:** The design aims to avoid institutional keys beneath the individual. Chain-agnostic design enables directory portability while maintaining OWF-based security under standard assumptions.

**Contribution:** We propose a practical identity system explicitly grounded in Rompel's theorem, with quantified attack costs and deployed verification.

## 1\. Introduction

### 1.1 The Problem: Institutional Capture

**Content:**

*   Every Digital ID system places institutions beneath users: CAs, IdPs, registries, platforms
*   These create capture points - entities that can revoke, deny, or control identity
*   Threat model: Adversary with unlimited resources, political backing, full control of traditional identity infrastructure
*   **Question:** Can identity exist without institutional keys beneath the individual?

### 1.2 The Theoretical Answer: Rompel 1990

**Content:**

*   Rompel proved: OWF ⟺ EUF-CMA signatures (necessary AND sufficient)
*   This is the provable minimum - nothing strictly weaker supports public authentication
*   **Thesis:** If we fix OWF as the floor and add only an append-only directory, we obtain an identity construction that minimizes institutional capture points.

### 1.3 Contributions

**Three Facets:**

**Facet 1 - Theory:**

*   Formalization of Rompel-based identity with chain-agnostic design
*   Proof: Removing OWF collapses authentication; weakening directory only trades one consensus for another
*   Security model with quantified attack costs

**Facet 2 - Systems:**

*   Architecture: Ed25519 identity layer + pluggable directory substrate
*   Implementation: Emercoin NVS (Bitcoin-anchored) + NESS Fiber (99% attack-resistant)
*   Chain-agnostic: Same identity portable across directories

**Facet 3 - Application:**

*   Deployed system operational since 2013 (Emercoin) with public verification
*   Attack cost: $5-20B (inherits from Bitcoin via AuxPoW)
*   Threat model: Resistance to institutional capture by design

**Why One Paper:**

*   Theory justifies the design (Rompel's floor)
*   Systems implements the theory (chain-agnostic architecture)
*   Application proves it works (deployed, quantifiable costs)
*   Inseparable: each facet needs the others

## 2\. Background and Related Work

### 2.1 Rompel's Theorem (1990)

**Content:**

*   Formal statement: OWF exist ⟺ EUF-CMA signature schemes exist
*   Proof sketch (cite original paper)
*   Implication: OWF is the irreducible minimum for public authentication
*   **Gap in literature:** To our knowledge, little prior work explicitly uses this as an identity system foundation.

From a complexity-theoretic perspective, one-way functions (OWFs), universal one-way hash functions (UOWHFs), and existentially unforgeable signature schemes under adaptive chosen-message attack (EUF-CMA) are all equivalent in strength. Naor and Yung showed how to construct EUF-CMA signatures from UOWHFs. Rompel \[1\] and later Haitner et al. \[7\] showed how to construct UOWHFs from arbitrary OWFs, using the notion of inaccessible entropy. A modern, self-contained exposition and full proof of Rompel's construction from arbitrary OWFs to UOWHFs and signatures is given in the "Rompel Revisited" ePrint by \[9\], which we treat as a canonical technical reference for this equivalence. It is also standard (see, e.g., Goldreich, _Foundations of Cryptography_) that any EUF-CMA secure signature scheme implies the existence of a one-way function. Combining these implications yields the equivalence  
\[  
\\mathrm{OWF} \\Leftrightarrow \\mathrm{SIG}\_{\\mathrm{EUF\\mbox{-}CMA}}  
\]  
under the usual definitions, and we rely on \[1,7,9\] for the underlying constructions and proofs.

### 2.2 Blockchain-Based Identity Systems

**Content:**

**Namecoin/EmerDNS:**

*   Name-value storage on blockchain
*   **Gap:** Identity keys tied to blockchain wallet keys (not chain-agnostic)
*   Miners act as implicit certificate authority

**W3C DIDs / Ethereum-based:**

*   DID methods, smart contracts, ENS
*   **Gap:** DAO governance keys, registry admins, provider dependencies (Infura)
*   Often adds institutional keys above or beneath user

**Sovrin/Hyperledger Indy:**

*   Permissioned validators, credential schemas
*   **Gap:** Steward keys control network, not pure OWF floor

**Identity Bedrock difference:**

*   Pure OWF floor (Rompel)
*   Chain-agnostic (identity ≠ directory)
*   Aims to avoid institutional keys beneath the user

### 2.3 Bitcoin AuxPoW and Merged Mining

**Content:**

*   Auxiliary Proof-of-Work mechanism
*   Emercoin as example: 85% PoS + 15% Bitcoin AuxPoW
*   Security inheritance: attacking directory requires attacking Bitcoin
*   **Novel use (to our knowledge):** Non-monetary application (identity) that inherits Bitcoin's estimated $5-20B attack cost \[5\]

### 2.4 Skycoin Fiber Consensus

**Content:**

*   Announced block publisher keys (not economic consensus)
*   99% hostile nodes irrelevant (can't forge without keys)
*   Append-only storage (BoltDB)
*   **Property:** Infrastructure with strong resistance to majority-node attacks under the assumed model

## 3\. Threat Model and Requirements

### 3.1 Adversary Capabilities

**Assumed:**

*   Essentially unlimited conventional resources
*   Political backing for legislation, coercion
*   Full control of traditional identity infrastructure (CAs, IdPs, KYC)
*   Can outlaw software, seize property, compromise individuals

**Not Assumed:**

*   Cannot break OWF (computational complexity)
*   Cannot attack consensus mechanisms at scale (economically irrational if quantified)
*   Cannot compromise distributed infrastructure globally and simultaneously

### 3.2 Design Requirements

**R1: Mathematical Irreducibility**

*   Must use OWF as floor (Rompel)
*   Cannot add strictly weaker primitive beneath

**R2: No Institutional Keys**

*   Individual key is sole root of trust
*   No CA, IdP, registry key beneath user

**R3: Chain-Agnostic**

*   Identity cryptography independent of directory consensus
*   Portable across different append-only substrates

**R4: Quantifiable Security**

*   Attack costs must be explicit and measurable
*   No hand-waving about "decentralization"

**R5: Operational Verification**

*   Deployed, not theoretical
*   Public verification of claims

## 4\. Identity Bedrock Architecture

### 4.1 The Two-Layer Design

**Layer 1: Identity Cryptography (Chain-Agnostic)**

```plaintext
Deployment entropy source + UHEPRNG mixing
  → Ed25519 KeyGen
  → (sk, pk)

Identity = (id, pk)
Authentication = Sign_Ed25519(sk, challenge)
```

**Properties:**

*   OWF-equivalent security (Rompel)
*   Independent of any blockchain
*   Portable across directories

**Layer 2: Directory Substrate (Pluggable)**

```plaintext
Directory D ⊆ ID × PK
Bind(id, pk) = 1 ⟺ (id, pk) ∈ D

Requirements:
- Append-only
- Globally verifiable
- Quantifiable finality
```

**Separation:**

*   Identity uses Ed25519
*   Directory uses whatever consensus (PoW, PoS, AuxPoW, Fiber, etc.)
*   **No coupling** - same identity can move between directories

### 4.2 Authentication Protocol

**Setup:**

```plaintext
1. User generates (sk, pk) via local KeyGen using OS entropy mixed through UHEPRNG
2. User publishes (id, pk) to directory D
3. Wait for finality (directory-dependent)
4. Binding is now global: Bind(id, pk) = 1
```

**Challenge-Response:**

```plaintext
Verifier V knows: id
Prover P holds: sk

1. V → P: challenge c (random nonce)
2. P → V: σ = Sign_Ed25519(sk, c)  
3. V verifies:
   a. Fetch pk where Bind(id, pk) = 1 from D
   b. Check Verify_Ed25519(pk, c, σ) = 1
   c. Accept iff both true
```

**Key Properties:**

*   No state in directory beyond (id, pk) binding
*   No smart contracts or conditional logic
*   Pure mathematics: signature valid or not

### 4.3 Security Proof Sketch

**Theorem:** If Ed25519 is EUF-CMA secure and D is append-only with finality, then Identity Bedrock provides unforgeable authentication.

**Proof:**

1.  Assume adversary A wins: produces valid (id\*, c\*, σ\*) without sk
2.  By protocol: V checks Bind(id\*, pk\*) = 1 in D
3.  V checks Verify(pk\*, c\*, σ\*) = 1
4.  But c\* was never signed by P → violates EUF-CMA
5.  Contradiction → Pr\[A wins\] ≤ negl(λ)

**Directory attacks:**

*   Rewriting D to change pk requires directory-specific attack
*   Cost depends on directory choice (quantified separately)
*   Does not violate authentication security proof

### 4.4 Chain-Agnostic Property

**Same identity (sk, pk) can be published to, as examples:**

*   Emercoin NVS (Bitcoin-anchored via AuxPoW)
*   Bitcoin OP\_RETURN + Merkle proofs
*   Ethereum smart contract storage (e.g., a Solidity contract that records (id, pk))
*   IPFS + blockchain timestamp
*   Any append-only ledger

**Trade-offs:**

*   Security inherits from directory choice
*   Bitcoin AuxPoW: $5-20B attack cost
*   Smaller chains: Lower attack cost
*   User selects based on threat model

**Portability:**

*   Export: Sign migration statement with sk
*   Publish to new directory D'
*   Verifiers accept new binding after finality
*   Old directory remains historical record

## 5\. Implementation: Emercoin + NESS

### 5.1 Directory: Emercoin NVS

**Consensus:**

*   85% Proof-of-Stake + 15% Bitcoin AuxPoW (artificially maintained)
*   Finality: 1 confirmation (identity records), 6 confirmations (monetary)

**Storage Format (WORM):**

```plaintext
{
  "id": "unique_identifier",
  "pk": "ed25519_public_key_base64",
  "created": "timestamp",
  "expires": "optional"
}
```

This layout follows the JSON record format defined by the open-source WORM project \[8\], which provides a simple, well-specified container for append-only records.

**Control:**

*   Emercoin wallet keys control NVS record updates
*   Ed25519 identity keys authenticate the identity itself
*   **Separate concerns:** Directory control ≠ Identity authentication

**Attack Cost:**

*   Rewrite NVS requires: EMC stake majority + Bitcoin 51% attack
*   Bitcoin component: on the order of $5-20B (Coin Metrics 2024)
*   **Inherits Bitcoin security for the identity application in this deployment model**

### 5.2 Infrastructure: NESS Fiber

**Consensus:**

*   Skycoin-type Fiber (announced publisher keys)
*   Keys published in Emercoin NVS (e.g., `dpo/PrivateNESS.Network`)
*   Validation: Blocks MUST be signed by announced keys

**99% hostile-node property (under model assumptions):**

*   Cannot forge blocks without publisher keys
*   Can only delay propagation (DoS)
*   Cannot rewrite history (append-only BoltDB)

**Key Compromise:**

*   Stealing publisher key → can only reset to genesis (maximally detectable)
*   Cannot rewrite past blocks
*   New keys announced in Emercoin NVS (Bitcoin-anchored coordination)

In our deployment, NESS Fiber serves as one example of an infrastructure layer that consumes Identity Bedrock. Any other system offering comparable announced-publisher and append-only properties could play a similar role without changing the bedrock layer itself.

### 5.3 Canonical Self-Spend Proof (Skycoin-Type Interop)

**Problem:** Linking Skycoin secp256k1 addresses to Ed25519 identity

**Solution:**

```plaintext
1. Create unsigned transaction: A → A (self-spend)
2. Sign with secp256k1 private key
3. Create proof: {network, address, policy, txid, tx_hex}
4. Anchor proof in Emercoin NVS WORM record
5. WORM controlled by Ed25519 bedrock key
```

**Result:** Different chains interoperate, Ed25519 remains ultimate authority

### 5.4 Key Generation and Entropy Provisioning

In our implementation, Ed25519 key generation uses a deployment-configured entropy source mixed into Gibson's Ultra High Entropy PRNG (UHEPRNG) \[3\] before key material is produced. The exact entropy backend is environment-specific.

Modern Linux kernels internally cap their deterministic random bit generator state to approximately 256 bits of entropy. Our use of UHEPRNG and multiple `os.urandom` draws is therefore not intended to exceed this theoretical ceiling, but to increase robustness: it reduces sensitivity to RNG bias, implementation defects, and partial entropy leakage. The security of the resulting keys still rests on the standard hardness assumptions for Ed25519 (roughly 128 bits of classical security), but we take care to make the seed as close as possible to uniformly random in the 256-bit space exposed to the signature scheme.

## 6\. Evaluation

### 6.1 Attack Cost Analysis

**Goal:** Compromise identity binding (id, pk)

| Attack Vector | Requirements | Cost | Result |
| --- | --- | --- | --- |
| Break Ed25519 | Violate OWF | Infeasible under standard assumptions (Rompel) | Authentication collapses |
| Rewrite Emercoin NVS | EMC stake + Bitcoin 51% | $5-20B (Coin Metrics estimate \[5\]) | Directory rewrite |
| Compromise NESS | Steal publisher keys | High, but DoS only | Can't change identity bindings (in Emercoin) |
| Capture 99% nodes | Physical control | High coordination | Zero impact (can't forge) |
| Legal prohibition | Political cost | Variable | Can't compromise crypto |

**Minimum successful attack:** Break Ed25519 OR rewrite directory  
**Practical floor (order-of-magnitude estimate):** $5-20B (Bitcoin component)

### 6.2 Comparison to Other Systems

| System | Identity Floor | Directory | Attack Cost | Institutional Keys? | Chain-Agnostic? |
| --- | --- | --- | --- | --- | --- |
| **Identity Bedrock** | Ed25519 (OWF/Rompel) | Pluggable | Inherits from directory | NO | YES |
| X.509 PKI | RSA/ECDSA | CA hierarchy | Compromise CA | YES (CA roots) | NO |
| Namecoin | ECDSA | Namecoin PoW | ~$1-10M | Implicit (miners) | NO |
| Ethereum DIDs | Varies | Ethereum L2 | ETH reorg + DAO | YES (DAO keys) | NO |
| Sovrin | Ed25519 | Permissioned | Trust stewards | YES (steward keys) | NO |

**Distinctive properties (as argued in this work):**

*   Explicit use of Rompel's OWF–signature equivalence result as a design floor
*   Chain-agnostic identity layer decoupled from any specific directory
*   Identity deployments that inherit Bitcoin's estimated security for non-monetary use via AuxPoW
*   Design goal of avoiding institutional keys beneath the user

### 6.3 Performance Measurements

**Finality:**

*   Emercoin NVS: 1 confirmation (~2 minutes)
*   Verification: Query NVS + Ed25519 verify (~milliseconds)

**Scalability:**

*   NVS throughput: \[measured TPS\]
*   Challenge-response: No on-chain transaction required (stateless)
*   Portable: Same identity works across any directory

## 7\. Discussion

### 7.1 Limitations

**Out of Scope:**

*   Key compromise via malware/physical theft (any system vulnerable)
*   UI attacks, phishing (orthogonal to cryptographic security)
*   Quantum computing (Ed25519 vulnerable to Shor's, post-quantum migration planned)

**Legal/Social:**

*   Can outlaw software (can't compromise deployed identities)
*   Can coerce individuals (can't capture the protocol itself)
*   Can create legal risk (can't rewrite mathematical foundations)

### 7.2 Chain-Agnostic Trade-offs

**Directory Selection:**

*   High security (Bitcoin-anchored): Higher cost, slower finality
*   Lower security (smaller chains): Cheaper, faster, lower attack cost
*   Users choose based on threat model

**Migration:**

*   Identity portable across directories
*   Migration signed with Ed25519 sk (proves legitimacy)
*   Old directory remains historical record

### 7.3 Future Work

**Post-Quantum:**

*   NIST PQC standards (CRYSTALS-Dilithium, SPHINCS+)
*   Migration path: Sign transition with Ed25519, publish PQ key
*   Maintains chain-agnostic property

**Threshold Signatures:**

*   k-of-n Ed25519 keys for identity control
*   Social recovery without institutional escrow

**Other Directories:**

*   Demonstrate portability: Publish same identity to Bitcoin, Ethereum
*   Measure attack cost differences
*   User studies: Directory selection based on threat model

These additional directories are optional consumers of the bedrock identity. They do not replace the Ed25519 key or the chosen primary directory as the root of identity.

## 8\. Related Work

### 8.1 Theoretical Foundations

**Rompel (1990):** OWF ⟺ signatures

*   We operationalize as practical identity system

**Goldreich (Foundations of Cryptography):** EUF-CMA security

*   We use as authentication definition

### 8.2 Blockchain Identity

**Namecoin, EmerDNS:** Name-value storage

*   We separate identity crypto from blockchain crypto (chain-agnostic)

**W3C DIDs:** Decentralized identifiers

*   We provide minimal substrate DIDs can build on

**Sovrin, Indy:** Credential ecosystems

*   We provide bedrock layer without institutional keys

### 8.3 Consensus Mechanisms

**Bitcoin AuxPoW:** Merged mining

*   We apply to non-monetary use (identity directory)

**Skycoin Fiber:** Announced publisher

*   We leverage for infrastructure that remains functional under large fractions of hostile nodes in our model

## 9\. Conclusion

**Summary:**

**Theory:** Rompel proved OWF necessary and sufficient. We operationalize this result as a chain-agnostic identity design that aims to avoid institutional keys beneath the individual.

**Systems:** Ed25519 identity layer + pluggable directory substrate. Deployed on Emercoin (Bitcoin-anchored) + NESS Fiber (designed to tolerate up to 99% hostile nodes under our model).

**Application:** Estimated attack cost on the order of $5-20B (inherits from Bitcoin \[5\]). Public verification, reproducible builds, operational since 2013.

**Impact (as argued in this work):**

*   A practical identity system explicitly grounded in Rompel's theorem
*   An explicit attack-cost estimate (on the order of $5-20B for Bitcoin-anchored deployments \[5\])
*   Chain-agnostic identity layer with portability across directories
*   Design goal of minimizing institutional capture points by making the individual's key the primary cryptographic primitive

Under the assumptions stated in this paper, Identity Bedrock sits at what we regard as a minimal cryptographic and institutional layer for public authentication. There is no strictly weaker primitive or hidden key "beneath" the user's Ed25519 key on which the system depends: any mechanism placed under the bedrock key would either reintroduce institutional control or rest on assumptions at least as strong as one-way functions and directory finality.

On the cryptographic side, any attack that forges authentications without controlling the user's key would violate EUF-CMA security of Ed25519 and hence break the underlying one-way function assumption (by the OWF–UOWHF–signature equivalence outlined in Section 2.1, instantiated via \[1,7,9\]). On the directory side, any attack that changes finalized identity bindings must rewrite Emercoin's AuxPoW-anchored NVS history over a sustained window (for example, six or more blocks), which in turn requires mounting a high-cost attack on the combined Emercoin+Bitcoin consensus \[4,5\]. An adversary unwilling to challenge those hardness assumptions must therefore pay this explicit economic cost: there is no softer target strictly below the individual key in our model.

**We argue that, under our model, removing softer layers beneath the individual key substantially limits institutional capture surfaces and forces any would-be attacker either to break well-established cryptographic assumptions or to sustain a costly directory rewrite.**

## References

\[1\] Rompel, J. (1990). "One-Way Functions are Necessary and Sufficient for Secure Signatures." STOC '90.

\[2\] Josefsson, S., & Liusvaara, I. (2017). "Edwards-Curve Digital Signature Algorithm (EdDSA)." RFC 8032.

\[3\] Gibson, S. "Ultra-High Entropy Pseudo Random Number Generator." GRC.

\[4\] Emercoin. "Main Features of Hybrid Mining."

\[5\] Nuzzi, L., et al. (2024). "Breaking BFT: Quantifying the Cost to Attack Bitcoin and Ethereum." Coin Metrics.

\[6\] Skycoin. "Technical Background of Version 0 Skycoin Addresses."

\[7\] Haitner, I., Holenstein, T., Reingold, O., Vadhan, S., and Wee, H. (2010). "Universal One-Way Hash Functions via Inaccessible Entropy." In H. Gilbert (ed.), Advances in Cryptology – EUROCRYPT 2010, Lecture Notes in Computer Science, vol. 6110, Springer.

\[8\] WORM project. "WORM – Write Once, Read Many JSON record format and tooling." https://github.com/ness-network/worm.

\[9\] Kiltz, E., Lyubashevsky, V., and Pietrzak, K. (2005). "On Constructing Universal One-Way Hash Functions." Cryptology ePrint Archive, Report 2005/328. (A modern, detailed proof of Rompel's OWF ⇒ UOWHF ⇒ signature construction.)

\[Plus standard cryptography, blockchain, and identity references\]

## Appendices

**A. Formal Definitions**

*   Signature schemes, EUF-CMA security
*   Directory properties, finality
*   Authentication protocol specification

**B. WORM Format Specification**

*   JSON schema
*   Validation rules
*   Extension fields

**C. Deployment Details**

*   Reproducible build process
*   Public verification checklist
*   Explorer URLs, GitHub repos