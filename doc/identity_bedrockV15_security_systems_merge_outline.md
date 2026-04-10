# Identity Bedrock V15 (Security Systems Venue) - Merged Outline and Editorial Merge Plan

## 0) Scope and venue lock

**Target venue type:** Security Systems (system paper takes precedence).

**Primary source corpus:**

- `doc/identity_bedrockV14.tex` (formal model + system instantiation)
- `doc/osi_layers_distributed_authentication.md` (network-layer threat framing + infrastructure constraints)

**Editorial constraints (locked):**

1. Neutral scientific tone across all sections.
2. Operational timeline anchor: first self-spend proof corresponds to the Fiber genesis anchored on-chain at Emercoin block **#445669** (start time reference).
3. Keep this as a systems paper (policy material minimized and de-emphasized).
4. No secret-bearing artifacts in manuscript or artifacts package.

---

## 1) New paper title and abstract direction

### 1.1 Proposed title

Identity Bedrock: A Chain-Agnostic Authentication Substrate with Quantified Directory Finality

### 1.2 Abstract recipe (what to keep/cut)

- KEEP (V14): formal substrate claim (EUF-CMA + append-only directory), chain-agnostic decomposition, deployed-system claim. Source: `identity_bedrockV14.tex` @ lines 44-70.
- MOVE IN (OSI): one sentence on separation between application-layer cryptographic correctness and lower-layer infrastructure constraints. Source: `osi_layers_distributed_authentication.md` @ lines 5-6, 199-204.
- CUT/REWRITE: rhetorical phrasing such as "was not built from theory" and "standing on bedrock". Source: `identity_bedrockV14.tex` @ lines 45-53.

---

## 2) Section-by-section merged outline with exact KEEP / MOVE / CUT instructions

## 2.1 Introduction

### Introduction KEEP

- Problem statement: institutional dependencies in existing identity stacks (rewrite neutrally). `identity_bedrockV14.tex` @ 81-103.
- Contribution bullets C1-C4 structure (retain, shorten to measurable claims). `identity_bedrockV14.tex` @ 114-135.

### Introduction MOVE

- OSI model as analysis lens (2-3 sentences only; not full tutorial). `osi_layers_distributed_authentication.md` @ 13-20.
- Decentralization taxonomy reference as terminology definition only. `osi_layers_distributed_authentication.md` @ 163-168.

### Introduction CUT

- Any normative/advocacy framing that is not testable.

## 2.2 Background and related systems

### Background and related systems KEEP

- OWF <-> EUF-CMA background and minimum-assumption framing. `identity_bedrockV14.tex` @ 151-173.
- Comparisons against PKI, DID, FIDO2, EIP-4361, ENS/Handshake, VC. `identity_bedrockV14.tex` @ 551-586.

### Background and related systems MOVE

- Compact OSI-layer threat table concept as one synthesis figure/table in this section. `osi_layers_distributed_authentication.md` @ 147-159.

### Background and related systems CUT

- Long per-layer educational exposition from OSI paper. Cut most of `osi_layers_distributed_authentication.md` @ 52-140 and keep only compressed risk model.

## 2.3 Threat model and assumptions

### Threat model and assumptions KEEP

- Adversary and non-assumptions. `identity_bedrockV14.tex` @ 203-217.
- Design requirements R1-R5. `identity_bedrockV14.tex` @ 219-231.

### Threat model and assumptions MOVE

- Explicit infrastructure-control realism into assumptions (network ownership, routing control potential). `osi_layers_distributed_authentication.md` @ 104-118, 128-140, 170-176.

### Threat model and assumptions CUT

- Absolute statements about impossible shutdown/censorship if not formally scoped.

## 2.4 Formal model

### Formal model KEEP

- Definitions for signature scheme, EUF-CMA, public directory, epsilon-finality, auth predicate. `identity_bedrockV14.tex` @ 243-304.

### Formal model MOVE

- Stateless vs stateful authentication operational note as implementation consideration. `osi_layers_distributed_authentication.md` @ 92-94.

### Formal model CUT

- None from V14 formal core; this section is already publication-aligned.

## 2.5 Architecture

### Architecture KEEP

- Two-layer decomposition (identity crypto + append-only directory). `identity_bedrockV14.tex` @ 311-337.
- Resolution flow skeleton. `identity_bedrockV14.tex` @ 531-538.

### Architecture MOVE

- Transport-layer distinction between TLS cert auth and application signature auth as clarifying paragraph. `osi_layers_distributed_authentication.md` @ 99-103.

### Architecture CUT

- Duplicate explanations of challenge-response already formalized elsewhere.

## 2.6 Security analysis

### Security analysis KEEP

- Authentication soundness theorem and proof. `identity_bedrockV14.tex` @ 343-387.
- Corollary expressing attack bifurcation (signature break vs directory corruption). `identity_bedrockV14.tex` @ 389-395.

### Security analysis MOVE

- Layer-correlated threat table as "attack surface stratification" immediately after theorem. Source concept: `osi_layers_distributed_authentication.md` @ 149-157.

### Security analysis CUT

- Any policy rhetoric in security section.

## 2.7 Implementation and deployment evidence

### Implementation and deployment evidence KEEP

- Concrete instantiation (Ed25519, Emercoin NVS + AuxPoW). `identity_bedrockV14.tex` @ 458-478.
- Attack-cost table + quantified rewrite economics (retain with explicit methodology). `identity_bedrockV14.tex` @ 482-505.
- Operational deployment claim and independent audit path. `identity_bedrockV14.tex` @ 516-529.

### Implementation and deployment evidence MOVE / REWRITE (MANDATORY)

- Rewrite timeline sentence so start time is anchored to your declared first self-spend proof at Fiber genesis anchored at Emercoin block **#445669**.
- Use wording template: "Operational measurement start is defined by the first self-spend proof at Fiber genesis, anchored in Emercoin block #445669 (timestamp: 2020-11-01 22:16:45 UTC)."

### Implementation and deployment evidence CUT

- Any claim that does not have a reproducible verification command/procedure.

## 2.8 Evaluation

### Evaluation KEEP

- Quantitative dimensions:
  1) authentication correctness/failure rate,
  2) directory consistency/finality behavior by depth,
  3) operational cost envelope on commodity hardware,
  4) adversarial cost model inputs.

### Evaluation MOVE

- From OSI: constraints from layers 1-4 as external dependency model in evaluation limitations. `osi_layers_distributed_authentication.md` @ 199-204, 220-226.

### Evaluation CUT

- Policy recommendation lists from OSI Section 7 in main body. `osi_layers_distributed_authentication.md` @ 301-312.

## 2.9 Discussion and limitations

### Discussion and limitations KEEP

- Out-of-scope list (endpoint compromise, phishing, legal coercion). `identity_bedrockV14.tex` @ 597-608.
- PQ migration path details (ML-DSA) with implementation constraints. `identity_bedrockV14.tex` @ 617-633.

### Discussion and limitations MOVE

- Narrow form of decentralization caveat and censorship-resistance realism as limitations language only. `osi_layers_distributed_authentication.md` @ 169-176.

### Discussion and limitations CUT

- Asymmetric-enforcement manifesto paragraph block. `osi_layers_distributed_authentication.md` @ 313-336.

## 2.10 Conclusion

### Conclusion KEEP

- Minimal-substrate sufficiency claim + deployment feasibility statement. `identity_bedrockV14.tex` @ 643-657.

### Conclusion MOVE

- One sentence: cryptographic soundness does not eliminate infrastructure dependencies.

### Conclusion CUT

- Non-falsifiable assertions.

---

## 3) Tone normalization rules (global replace policy)

Apply throughout merged manuscript:

1. Replace certainty rhetoric with bounded claims.
   - "proves that policy cannot" -> "indicates under stated assumptions"
2. Replace adversarial normative language with empirical framing.
   - "surveillance apparatus" -> "identity-to-access linkage risk"
3. Every strong claim must be paired with one of:
   - formal theorem, or
   - reproducible measurement, or
   - citable prior literature.
4. Keep first-person singular only in reproducibility or artifact statements; otherwise use neutral third person.

---

## 4) Secret-handling and artifact hygiene (submission-critical)

## 4.1 Immediate exclusions

- Exclude any files containing private keys or secret seeds from manuscript artifacts.
- Known secret-bearing file: `worm/scripts/identities/pax-proof0.ee77705188dda98a848c8a7ba3674f1a12e57f2fd768801e15fd75f1b56f737a.key.json`.

## 4.2 Derived public object replacement template

When replacing a secret-bearing identity object, publish only:

- `username`
- `public_key` (base64 or canonical encoding)
- `public_key_fingerprint` (SHA-256 over canonical public key bytes)
- optional `proof_reference` (txid / block height / explorer URL)

Do **not** publish raw private key material in any appendix, figure, or replication bundle.

## 4.3 Confirmation gate (required)

Before replacing or deleting any secret-bearing file in-repo, obtain explicit user confirmation on:

1. whether to redact in-place,
2. whether to create a sanitized sibling file,
3. whether to rotate the affected keypair.

---

## 5) Policy-tech content disposition for systems venue

- Keep policy/age-verification material as an optional appendix or companion manuscript.
- Main systems paper should include at most a short "Broader Impacts" paragraph and avoid prescriptive policy language.

Suggested disposition of OSI Section 7:

- **Main paper:** keep only architecture comparison table concept in minimized form.
- **Appendix/companion:** full policy implications and regulatory recommendations.

---

## 6) Editing execution order (for V15 manuscript build)

1. Merge formal + architecture backbone from V14.
2. Inject compact OSI-derived threat/infrastructure framing.
3. Remove rhetorical/policy-forward passages from main body.
4. Normalize tone globally.
5. Align operational timeline sentence to the block #445669 anchor definition.
6. Run secret scan and replace with derived public objects only after explicit user confirmation.
7. Freeze bibliography and ensure every retained claim is evidence-backed.

---

## 7) Acceptance checklist (security systems target)

- [ ] Claims are falsifiable and scoped by assumptions.
- [ ] Formal model and theorem are central, not peripheral.
- [ ] Deployment evidence includes reproducibility path.
- [ ] No private key material in text/artifacts.
- [ ] Policy discussion is subordinate to systems contribution.
- [ ] Tone is neutral scientific throughout.

---

**Version marker:** V15 merge-outline draft (created April 2026).
