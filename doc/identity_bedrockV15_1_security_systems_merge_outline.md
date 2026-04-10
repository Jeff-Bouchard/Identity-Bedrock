# Identity Bedrock V15.1: Academic Merge Outline for a Security Systems Venue

## 0. Editorial objective

This outline specifies a fresh V15.1 manuscript plan for a **security systems** venue. It intentionally prioritizes the systems contribution, uses conventional academic prose, and presents implications in the measured style expected by reviewers.

### Project-wide rules

- **Tone.** Use classical academic wording throughout. Claims should be stated with restraint, and implications should be framed explicitly and cautiously.
- **Venue posture.** The manuscript is a systems paper first. Policy-oriented material appears only where it is necessary for interpretation, limitations, or broader implications.
- **Bibliography.** The reference list must be complete and externally grounded. Do not cite the `privateness` litepaper, and do not cite the author's own manuscript as a source.
- **Evidence standard.** Every substantial claim should be supported by a theorem, a reproducible measurement, a public standard, or established prior literature.

---

## 1. Intended paper shape

### 1.1 Working title

Identity Bedrock: A Chain-Agnostic Authentication Substrate with Quantified Directory Finality

### 1.2 Abstract direction

The abstract should do four things in the standard order expected in systems venues:

1. State the problem.
2. State the technical approach.
3. State the principal result.
4. State the implication.

### 1.3 Abstract content to retain

- The authentication substrate is based on signature verification and an append-only directory.
- The directory layer is separable from the cryptographic layer.
- The system has a concrete deployment history.
- The architecture can be evaluated with measurable security and operational criteria.

### 1.4 Abstract content to avoid

- Manifesto language.
- Overstated claims of universal censorship resistance.
- Self-referential assertions about novelty without evidence.
- Citations to internal or private author material.

---

## 2. Main manuscript structure

## 2.1 Introduction

### Introduction — Keep

- A concise problem statement about identity systems that introduce institutional dependencies.
- A neutral statement of why a minimal authentication substrate is academically interesting.
- A short summary of contributions in conventional list form.

### Introduction — Move in

- A brief OSI-layer framing sentence to explain why network structure matters for authentication.
- A short statement that cryptographic correctness does not by itself determine infrastructure resilience.

### Introduction — Cut

- Rhetorical or polemical language.
- Language that implies policy conclusions before the technical case is established.

### Introduction — Reviewer-facing emphasis

The introduction should read like a conventional systems paper introduction: problem, gap, method, contribution, implication.

## 2.2 Background and related work

### Background and related work — Keep

- The OWF and EUF-CMA foundation.
- The distinction between identity verification and directory binding.
- Comparative discussion of PKI, DID, FIDO2/WebAuthn, EIP-4361, ENS, Handshake, and verifiable credentials.

### Background and related work — Move in

- A compact OSI model summary as a framing device, not as a tutorial.
- A short table that distinguishes application-layer authentication from lower-layer network constraints.

### Background and related work — Cut

- Long pedagogical OSI exposition.
- Any text that reads as a general primer rather than related work.

### Background and related work — Implication to state

The literature review should make clear that the paper is not claiming to replace all identity systems; rather, it isolates a minimal substrate and evaluates what can be derived from it.

## 2.3 Threat model and assumptions

### Threat model and assumptions — Keep

- The adversary model.
- The non-assumptions.
- The design requirements.

### Threat model and assumptions — Move in

- Explicit acknowledgment that the underlying network is controlled by real infrastructure operators.
- A short, factual statement that overlay systems inherit dependencies from lower layers.

### Threat model and assumptions — Cut

- Absolute claims about infrastructure being impossible to shut down.
- Any statement that cannot be defended under the declared threat model.

### Threat model and assumptions — Implication to state

The threat model should support a sober conclusion: cryptographic soundness is necessary, but it does not erase infrastructure dependence.

## 2.4 Formal model

### Formal model — Keep

- The signature scheme definition.
- EUF-CMA security.
- The public directory definition.
- The append-only and finality notions.
- The authentication predicate.

### Formal model — Move in

- A brief note on stateless versus stateful verification only if it is needed for implementation clarity.

### Formal model — Cut

- Redundant definitions already present in standard cryptography texts.

### Formal model — Implication to state

The formal section should establish that the system claims are derived from standard cryptographic assumptions and clearly defined directory properties.

## 2.5 Architecture

### Architecture — Keep

- The two-layer decomposition: identity cryptography and append-only directory.
- The concrete resolution flow.
- The instantiation details relevant to reproduction.

### Architecture — Move in

- A concise paragraph distinguishing transport security from application-layer signature verification.

### Architecture — Cut

- Repetition of challenge-response basics.
- Extended narrative that does not support the architecture.

### Architecture — Implication to state

The architecture section should make the system design legible to reviewers: what is being bound, where binding occurs, and which properties are inherited from which layer.

## 2.6 Security analysis

### Security analysis — Keep

- The soundness theorem.
- The security reduction.
- The corollary separating forgery risk from directory corruption risk.

### Security analysis — Move in

- A compact attack-surface table derived from the OSI-oriented threat framing.

### Security analysis — Cut

- Policy language.
- Non-technical claims about legitimacy, governance, or social control.

### Security analysis — Implication to state

The security analysis should support a clear reviewer conclusion: authentication failure requires either a break in the signature scheme or compromise of the directory layer under the stated assumptions.

## 2.7 Implementation and deployment evidence

### Implementation and deployment evidence — Keep

- The concrete instantiation.
- The deployment description.
- The attack-cost analysis, provided the methodology is explicit and reproducible.

### Implementation and deployment evidence — Move in

- A neutral timing statement anchored to the first self-spend proof at Fiber genesis on Emercoin block #445669.
- A clearly defined operational measurement start point.

### Implementation and deployment evidence — Cut

- Claims that cannot be independently checked.
- Internal provenance claims that do not add to the technical argument.

### Implementation and deployment evidence — Implication to state

The deployment evidence should show that the architecture is not merely theoretical; it has operational relevance and can be audited against public artifacts.

## 2.8 Evaluation

### Evaluation — Keep

- Authentication correctness.
- Finality behavior by depth.
- Operational cost on commodity hardware.
- Adversarial cost model inputs.

### Evaluation — Move in

- External dependency constraints from layers 1 through 4 as evaluation limitations.

### Evaluation — Cut

- Policy recommendations in the main evaluation narrative.

### Evaluation — Implication to state

The evaluation should support a measured claim about performance and resilience, not a broad sociopolitical conclusion.

## 2.9 Discussion and limitations

### Discussion and limitations — Keep

- Endpoint compromise.
- Phishing and social engineering.
- Legal coercion.
- Post-quantum migration considerations.

### Discussion and limitations — Move in

- A short factual discussion of decentralization limits and censorship-resistance limits.

### Discussion and limitations — Cut

- Manifesto-style passages.
- Any claim that exceeds the available evidence.

### Discussion and limitations — Implication to state

The discussion should acknowledge the system's boundaries explicitly so that the paper remains credible to a traditional reviewer.

## 2.10 Conclusion

### Conclusion — Keep

- The minimal-substrate sufficiency claim.
- The deployment feasibility claim.
- A concise statement of the architectural implications.

### Conclusion — Move in

- One restrained sentence on the relationship between cryptographic soundness and infrastructure dependence.

### Conclusion — Cut

- Unqualified universal claims.
- Language that sounds promotional rather than scholarly.

### Conclusion — Implication to state

The conclusion should close with a conventional academic synthesis: what was shown, why it matters, and what the boundaries are.

---

## 3. Tone and style rules for the V15.1 manuscript

1. Prefer conventional academic verbs such as `shows`, `indicates`, `suggests`, `supports`, and `implies`.
2. Use affirmations in measured form: `the results support`, `the analysis indicates`, `the evidence is consistent with`.
3. Use implications explicitly and conservatively: `this suggests`, `this has the implication that`, `this constrains`.
4. Avoid rhetorical escalation.
5. Avoid first-person claims unless they are necessary for reproducibility or authorship disclosure.
6. Keep terminology stable and standard.
7. If a claim is not externally supportable, recast it as a limitation or omit it.

---

## 4. Bibliography policy

### Required properties

- The bibliography must be complete enough for a reviewer to reconstruct the argument.
- It should include primary standards, foundational cryptography references, and relevant systems literature.
- It should not include the author's `privateness` litepaper.
- It should not cite the manuscript as its own authority.

### Citation sources to prioritize

- Cryptography foundations and signature security.
- OSI/TCP-IP and networking standards.
- Signature and encoding standards.
- Peer-to-peer and overlay networking literature.
- Distributed naming and directory systems literature.
- Public deployment or protocol references relevant to the implementation.

### Citation discipline

- Prefer primary sources over commentary.
- Prefer standards and peer-reviewed literature over informal documentation.
- If a claim is operational rather than theoretical, cite the public artifact or the public protocol reference, not private explanatory prose.

---

## 5. Submission-readiness checklist

- [ ] The manuscript reads like a conventional systems paper.
- [ ] The opening pages feel familiar to a traditional reviewer.
- [ ] The formal model is central.
- [ ] The deployment evidence is externally checkable.
- [ ] The bibliography is complete and does not include private self-citation.
- [ ] The tone remains neutral, academic, and restrained throughout.

---

## 6. Version marker

V15.1 fresh outline draft; previous outline versions are disregarded for this file.
