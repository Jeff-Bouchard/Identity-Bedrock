# NESS Identity Bedrock: Technical Architecture
## The Minimal Cryptographic Substrate for Sovereign Identity

**Document Status:** Technical specification based on deployed architecture  
**Authority:** Emercoin team (emercoin.com/team), Privateness team (privateness.network/team)  
**Date:** November 2025

---

## 1. The Mathematical Foundation: Rompel's Theorem

### 1.1 The Irreducible Floor

**Rompel, J. (1990). "One-Way Functions are Necessary and Sufficient for Secure Signatures."**  
*Proceedings of the 22nd Annual ACM Symposium on Theory of Computing (STOC '90)*, pp. 387-394.  
DOI: https://doi.org/10.1145/100216.100269

**Theorem:**
- **Necessary:** If EUF-CMA secure digital signatures exist → One-way functions exist
- **Sufficient:** If one-way functions exist → EUF-CMA secure digital signatures can be constructed
- **Equivalence:** OWF ⟺ Digital Signatures (in standard PPT model)

**Implication for Identity Bedrock:**  
There exists no strictly weaker cryptographic primitive that can support publicly verifiable authentication. This is the provable minimum. Identity Bedrock fixes this as the floor and builds nothing beneath it.

### 1.2 Implementation: Ed25519

**Standard:** RFC 8032 - Edwards-Curve Digital Signature Algorithm (EdDSA)  
https://datatracker.ietf.org/doc/html/rfc8032

**Properties:**
- 256-bit keys
- Deterministic signatures
- Fast verification
- No timing side-channels in reference implementation
- OWF-equivalent security assumptions

**Identity Bedrock uses Ed25519 as the signature scheme Σ = (KeyGen, Sign, Verify):**
```
KeyGen(1^λ) → (sk, pk)
Sign(sk, message) → σ
Verify(pk, message, σ) ∈ {0,1}
```

---

## 2. Ultra-High Entropy Key Generation

### 2.1 Steve Gibson's UHEPRNG

**Source:** "Ultra-High Entropy Pseudo Random Number Generator"  
Gibson Research Corporation  
https://www.grc.com/otg/uheprng.htm

**Verified Properties:**
- **Internal state:** 1536 bits
- **Period:** Germain prime 1,768,863 × 2^1535 - 1 ≈ 2.132 × 10^468
- **Entropy capacity:** 1536 bits (sufficient to initialize all possible states)
- **Tested:** Passes Fourmilab, diehard, and dieharder randomness test suites

**Key Derivation Process:**
```
1. Generate 1536-bit seed from UHEPRNG
2. Derive Ed25519 keypair deterministically per RFC 8032:
   seed → SHA-512(seed) → Ed25519 (sk, pk)
3. Store seed securely (hardware wallet, Shamir backup)
```

**Why 1536 bits?**
- Exceeds all current cryptanalytic capabilities
- Enables deterministic key trees for multiple identities
- Single seed backup recovers entire key hierarchy
- Compatible with hardware security modules

---

## 3. Three-Layer Consensus Architecture

Identity Bedrock anchors across three independent consensus mechanisms with different security models.

### 3.1 Layer 1: Emercoin Hybrid Consensus

**Source:** "Main Features of Hybrid Mining"  
https://emercoin.com/en/news/main-features-of-hybrid-mining/

**Consensus Mechanism:**
- **85% Proof-of-Stake blocks** (EMC stakers produce blocks)
- **15% Bitcoin Auxiliary Proof-of-Work blocks** (Bitcoin miners include Emercoin data)
- **Ratio:** Artificially maintained by protocol (per Emercoin team)

**Finality Parameters:**  
*(Source: Direct communication with Emercoin team, emercoin.com/team)*
- **Non-monetary transactions (NVS identity records):** 1 confirmation
- **Monetary transactions:** 6 confirmations

**Attack Cost Model:**

To rewrite an identity binding in Emercoin NVS, an attacker must:

1. **Control EMC stake** to produce alternative PoS blocks (85% of chain)
2. **Attack Bitcoin** to orphan AuxPoW blocks (15% of chain)

The Bitcoin component creates the cost floor:

**Bitcoin 51% Attack Cost (2024):**  
*Nuzzi, L., Waters, K., & Andrade, M. (2024). "Breaking BFT: Quantifying the Cost to Attack Bitcoin and Ethereum." Coin Metrics Special Report.*  
https://ssrn.com/abstract=4727999

**Findings:**
- Hardware cost: **$5-20 billion** in ASIC miners
- Ongoing cost: Hundreds of thousands per hour in electricity
- Detection: Globally visible on Bitcoin network
- Economic irrationality: Attacker likely holds BTC, undermining own position

**Identity Bedrock Security:**  
To change the binding `(id, pk)` in Emercoin NVS after 1 confirmation requires rewriting the Emercoin chain deeply enough to reach that block. Due to the 15% AuxPoW blocks anchored to Bitcoin, this requires orphaning Bitcoin blocks - Bitcoin 51% attack cost applies.

### 3.2 Layer 2: NESS Fiber Consensus

**Architecture:** Skycoin-type blockchain with Fiber consensus model

**Source:** "Technical Background of Version 0 Skycoin Addresses"  
https://github.com/skycoin/skycoin/wiki/

**Consensus Model:**
- **Block publisher:** Keys announced in Emercoin NVS (example: `dpo/PrivateNESS.Network`)
- **Validation:** Blocks MUST be signed by announced keys
- **Storage:** BoltDB append-only database

**Key Properties:**

1. **Not Economic Consensus:**  
   Unlike Bitcoin/Ethereum, validity is determined by cryptographic signatures from announced keys, not economic majority (mining/staking).

2. **99% Hostile Node Immunity:**  
   Hostile nodes cannot forge valid blocks without publisher keys. They can only delay propagation (DoS), not compromise validity.

3. **Append-Only Storage:**  
   BoltDB implementation is append-only. Even with compromised publisher keys, attacker can only:
   - Reset to genesis (block 0) - immediately detectable by all nodes
   - Continue publishing from current height
   
   **Cannot:** Rewrite past blocks or fork from arbitrary historical points.

**Attack Scenarios:**

| Attack Vector | Effect | Detection | Compromise Past Identity Bindings? |
|---------------|--------|-----------|-----------------------------------|
| Steal publisher key + reset to genesis | Complete chain reset | Immediate, universal | No - old chain remains verifiable |
| Steal publisher key + continue publishing | Can censor future transactions | Depends on behavior | No - append-only prevents rewrite |
| Control 99% of nodes | Can delay block propagation | Stale blocks noticed | No - can't forge without keys |
| Rewrite past blocks | **Impossible** | N/A | No - storage layer prevents it |

**Recovery Path:**
1. Detect compromise (reset or malicious blocks)
2. Community coordination
3. Announce new publisher keys in Emercoin NVS
4. Bootstrap from last valid state
5. New keys take over (old chain remains historical record)

### 3.3 Layer 3: Bitcoin (via AuxPoW)

**Role:** Immutable timestamping and cost floor for Emercoin

Bitcoin is not directly used by NESS Identity, but provides the economic security through Emercoin's AuxPoW:

- 15% of Emercoin blocks embed Bitcoin block hashes
- These AuxPoW blocks create "walls" in Emercoin history
- Rewriting past these walls requires orphaning the referenced Bitcoin blocks
- This inherits Bitcoin's $5-20B attack cost

**Verification:**
- Explorer: https://explorer.emercoin.com
- Bitcoin AuxPoW blocks are marked in explorers
- Users can verify depth of AuxPoW anchoring independently

---

## 4. Identity Bindings and WORM Format

### 4.1 Directory Structure

**Directory:** Emercoin Name-Value Storage (NVS)  
**Format:** WORM (World Object Mapper) JSON objects

**Chain-Agnostic Design:**  
Identity Bedrock is independent of Emercoin's wallet signature scheme. Emercoin serves purely as an append-only directory (bulletin board). The identity keys (Ed25519) are separate from Emercoin's transaction signing keys.

**Basic Identity Binding:**
```json
{
  "id": "unique_identifier",
  "pk": "ed25519_public_key_base64",
  "created": "timestamp",
  "expires": "timestamp_or_null"
}
```

**Storage:**
- Written to Emercoin NVS as name:value pair
- Name: Hierarchical identifier (e.g., `identity:alice`)
- Value: WORM JSON object containing Ed25519 `pk` and metadata
- **Control:** Emercoin NVS record is controlled by whoever holds the Emercoin private key that wrote it
- **Identity Authentication:** Separate - uses the Ed25519 key published in the record

**Separation of Concerns:**
- **Emercoin wallet keys:** Control NVS record updates (whatever signature scheme Emercoin uses)
- **Identity Bedrock Ed25519 keys:** Authenticate the identity itself (challenge-response)
- The directory (Emercoin NVS) stores the Ed25519 public key but doesn't use Ed25519 for blockchain operations

**Finality:** 1 confirmation for identity records (per Emercoin team)

### 4.2 Authentication Protocol

**Setup:**
1. User generates (sk, pk) via UHEPRNG → Ed25519
2. User publishes WORM object `(id, pk)` to Emercoin NVS
3. Wait 1 confirmation (~2 minutes)
4. Identity binding is now final and globally verifiable

**Challenge-Response Authentication:**

```
Prover P holds: sk
Verifier V knows: id

1. V → P: challenge c (random nonce)
2. P → V: σ = Sign(sk, c)
3. V verifies:
   a. Lookup pk from Emercoin NVS where Bind(id, pk) = 1
   b. Check Verify(pk, c, σ) = 1
   c. Accept if both true
```

**Security:** If Ed25519 is EUF-CMA secure (equivalent to OWF existence per Rompel), then forging σ for fresh challenge c is negligible probability for any PPT adversary without sk.

---

## 5. Skycoin-Type Chain Interoperability

### 5.1 The Canonical Self-Spend Proof

**Problem:** Skycoin, NESS, and similar chains use secp256k1 ECDSA for addresses. How to link these to Ed25519 Identity Bedrock?

**Solution:** Canonical self-spend transaction

**Source:** Identity Bedrock draft specification, Section 7  
"Relation to Skycoin-type chains (optional anchoring)"

**Procedure:**
```
1. User controls Skycoin address A (derived from secp256k1 keypair)

2. Create unsigned transaction:
   Input: UTXO from address A
   Output: Same UTXO back to address A
   (Canonical form: A → A, "self-spend")

3. Sign transaction with secp256k1 private key

4. Create proof object:
{
  "network": "skycoin",
  "address": "A",
  "policy": "canonical_self_spend",
  "txid": "transaction_id",
  "unsigned_tx_hex": "...",
  "signed_tx_hex": "..."
}

5. Include proof in WORM object stored in Emercoin NVS

6. WORM object controlled by Ed25519 bedrock key
```

**Result:**
- Skycoin address A is cryptographically linked to Identity Bedrock
- Verifiers can check: holder of bedrock Ed25519 key also controls Skycoin address A
- **But:** Ed25519 key remains ultimate authority (controls the Emercoin NVS record)

**Why "Canonical"?**
- Standardized: A→A is unambiguous
- Verifiable: Anyone can check signed transaction proves key control
- Minimal: No additional assumptions beyond ECDSA signature validity

### 5.2 Control Hierarchy

```
[UHEPRNG 1536-bit seed]
        ↓
[Ed25519 Bedrock Key] ← SOLE ROOT OF TRUST
        ↓ (controls)
[Emercoin NVS Record]
        ↓ (contains)
[WORM Identity Object]
        ↓ (optionally includes)
[Canonical Self-Spend Proof]
        ↓ (proves control of)
[Skycoin-type Address]
```

The Ed25519 key is the root. Everything else is optional layering.

---

## 6. Complete Attack Surface Analysis

### 6.1 Cryptographic Attacks

**Goal:** Forge signature without private key

**Attack Path:** Break Ed25519 → Violate OWF assumptions → Contradict Rompel 1990

**Cost:** Impossible in standard PPT model (computational complexity theory)

**Mitigation:** None needed - this is the mathematical floor

---

### 6.2 Consensus Attacks on Emercoin

**Goal:** Rewrite identity binding in NVS

**Attack Requirements:**
1. Control >51% of staked EMC (for PoS component)
2. **AND** Attack Bitcoin to orphan AuxPoW blocks (for 15% PoW component)

**Cost Analysis:**
- EMC stake: Variable, likely $1-10M depending on market
- Bitcoin 51%: **$5-20 billion** (Coin Metrics 2024)
- **Total cost floor: $5-20 billion** (Bitcoin component dominates)

**Practical Barriers:**
- Geopolitically visible (Bitcoin reorg makes global news)
- Economically irrational (attacker likely holds BTC/EMC)
- Technically detectable (network monitoring, explorer alerts)

---

### 6.3 Infrastructure Attacks on NESS

**Goal:** Control NESS network

**Attack Scenario 1: Compromise 99% of nodes**
- **Effect:** Can delay block propagation (DoS)
- **Cannot:** Forge blocks without publisher keys
- **Cannot:** Rewrite past blocks (append-only storage)
- **Compromise identity bindings:** No (those are in Emercoin NVS)

**Attack Scenario 2: Steal publisher keys**
- **Effect:** Can reset to genesis OR continue publishing
- **Detection:** Reset is immediately visible to all nodes
- **Compromise identity bindings:** No (append-only prevents history rewrite, new keys announced in Emercoin)

**Mitigation:**
- Identity bindings remain in Emercoin (Bitcoin-anchored)
- Append-only storage prevents history rewrite
- Publisher key rotation via Emercoin NVS announcement
- Users need only one honest node to verify

---

### 6.4 Social and Legal Attacks

**Goal:** Coerce users, outlaw system

**Attack Vectors:**
- Legislative prohibition
- Law enforcement targeting operators
- ISP-level blocking

**Effects:**
- Can reduce adoption (political cost)
- Can create legal risk for public operators
- **Cannot:** Compromise existing identity bindings (cryptography remains valid)
- **Cannot:** Rewrite blockchain history (mathematically immutable)
- **Cannot:** Insert institutional keys retroactively (Turing-incomplete chains)

**Mitigation:**
- Mesh network resilience (NESS infrastructure)
- Open source (cannot "uninvent" mathematics)
- Reproducible builds (verify integrity)
- Geographic distribution (no single jurisdiction)
- Tor/I2P integration possible (censorship resistance)

---

## 7. Operational Security

### 7.1 Key Management Best Practices

**Hardware Security:**
- Ledger Nano S Plus / X
- Trezor Model T / One
- Custom HSMs with Ed25519 support
- Air-gapped signing devices

**Backup Strategy (Recommended):**
```
1536-bit UHEPRNG seed → Shamir Secret Sharing

Example: 2-of-3 scheme
- Shard 1: Personal safe (home jurisdiction)
- Shard 2: Bank safety deposit box (different jurisdiction)
- Shard 3: Trusted person (different jurisdiction)

Recovery: Any 2 shards reconstruct seed → deterministic Ed25519 derivation
```

**Key Rotation:**
1. Generate new (sk', pk') from fresh UHEPRNG seed
2. Publish updated WORM object `(id, pk')` to Emercoin NVS
3. Sign transition statement with old sk: "Rotating to pk' at block N"
4. Wait 1 confirmation
5. Old key deprecated, new key active

### 7.2 Verification Procedures

**Before Trusting an Identity Binding:**

1. **Query Emercoin NVS:**
   - Use multiple independent nodes
   - Verify same `(id, pk)` returned

2. **Check Finality:**
   - Verify ≥1 confirmation for identity records
   - Check block depth in explorer

3. **Verify AuxPoW Anchoring:**
   - Confirm nearby AuxPoW blocks exist
   - Check Bitcoin anchoring via explorer.emercoin.com

4. **Cross-Client Verification:**
   - Query using different implementations (Go CLI, WASM client, etc.)
   - Compare pk hashes before trusting

### 7.3 NESS Publisher Key Verification

**Announced Keys Location:** Emercoin NVS  
**Example:** `dpo/PrivateNESS.Network`

**Verification Process:**
1. Query Emercoin NVS for current publisher keys
2. Verify keys are anchored with ≥1 confirmation
3. Check NESS blocks are signed by announced keys
4. Reject blocks signed by non-announced keys

**If Publisher Key Compromised:**
- Reset to genesis: Immediately visible, reject compromised chain
- New keys announced: Wait for Emercoin confirmation, bootstrap from snapshot
- Continue with malicious blocks: Detect anomalies, coordinate new keys

---

## 8. Comparison to Other Identity Systems

| System | Cryptographic Primitive | Directory/Consensus | Attack Cost Floor | Institutional Keys Below User? | Turing-Complete? |
|--------|------------------------|-------------------|------------------|-------------------------------|------------------|
| **NESS Identity Bedrock** | Ed25519 (Rompel OWF floor) | Emercoin 85% PoS + 15% BTC AuxPoW | $5-20B (Bitcoin) | **NO** | No (both chains Turing-incomplete) |
| X.509 PKI | RSA/ECDSA | Certificate Authority hierarchy | Compromise CA root | Yes - CA roots | N/A (not blockchain) |
| Namecoin | ECDSA/secp256k1 | Namecoin PoW | Namecoin 51% (~$1-10M) | Implicit - miners | No (UTXO only) |
| W3C DID (Ethereum) | Varies by method | Ethereum L1/L2 smart contracts | Ethereum reorg + DAO votes | Yes - DAO/multisig keys | Yes (EVM) |
| Sovrin/Hyperledger Indy | Ed25519/BLS | Permissioned validator pool | Trust in stewards | Yes - steward keys | Limited (permissioned VM) |

**Key Differentiator:**  
NESS Identity Bedrock is the only system where:
1. Individual Ed25519 key is the sole cryptographic root
2. No institutional key exists beneath the user
3. Directory is anchored to Bitcoin's security budget
4. Both chains are Turing-incomplete (no governance to capture)

---

## 9. Deployment and Verification

### 9.1 Current Status (November 2025)

**Operational Components:**
- ✅ Emercoin blockchain (operational since 2013)
- ✅ Emercoin NVS (operational)
- ✅ NESS/Privateness blockchain (operational)
- ✅ WORM identity format (specified and deployed)
- ✅ Publisher keys announced in Emercoin NVS

**Public Verification:**
- Emercoin team: https://emercoin.com/team
- Privateness team: https://privateness.network/team
- Source repositories: https://github.com/NESS-Network

### 9.2 Reproducible Builds

**Requirement:** All WORM and wallet binaries MUST be reproducible

**Process:**
1. Source code in public Git repositories
2. Build scripts with pinned dependencies
3. SHA256 manifest of build outputs
4. Multiple independent builders cross-verify
5. Users verify local build matches published hash

**Why This Matters:**  
Prevents backdoored binaries from compromising key generation or NVS queries

---

## 10. Limitations and Threat Model Boundaries

### 10.1 What Identity Bedrock Does NOT Protect Against

**Out of Scope:**
1. **Key compromise via side channels:** Malware, physical theft, coercion
2. **User interface attacks:** Fake websites, phishing, social engineering
3. **Implementation bugs:** Software vulnerabilities in wallets/clients
4. **Quantum computing:** Ed25519 vulnerable to Shor's algorithm (post-quantum migration planned)

### 10.2 What Identity Bedrock DOES Protect Against

**In Scope:**
1. **Institutional capture:** No keys beneath the user to compromise
2. **Governance capture:** Turing-incomplete chains prevent post-deployment rule changes
3. **Consensus attacks:** Bitcoin anchor makes history rewrite $5-20B
4. **Network attacks:** 99% hostile nodes cannot forge blocks or rewrite history
5. **Centralization:** Mesh infrastructure, distributed nodes, open source

### 10.3 The Adversary Model

**Adversary Capabilities:**
- Essentially unlimited conventional resources
- Political backing for legislation/prohibition
- Full control of traditional identity infrastructure (CAs, IdPs, KYC)
- Ability to coerce individuals and seize property

**Adversary CANNOT (Within System Assumptions):**
- Break Rompel's OWF floor (computational complexity)
- Rewrite Bitcoin blockchain (economically irrational: $5-20B)
- Capture Fiber consensus (not economic, cryptographic validity)
- Rewrite append-only storage (storage layer prevents it)
- Add governance post-deployment (Turing-incomplete)

**Result:** Adversary can outlaw and harass, but cannot compromise the mathematical/cryptographic foundation

---

## 11. Future Directions

### 11.1 Planned Enhancements
- Hardware wallet integration (official Ledger/Trezor apps)
- Threshold signatures (k