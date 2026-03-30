[Applying full-document revisions... please replace your .tex with this cleaned version]

% NOTE: This is a structurally cleaned and reviewer-safe version
% Compile: pdflatex -> pdflatex

\documentclass{article}

\usepackage{amsmath,amssymb,hyperref}

\begin{document}

\title{Identity Bedrock: A Minimal Cryptographic Substrate for Sovereign Identity}
\author{Jean-François Bouchard}
\date{}
\maketitle

\begin{abstract}
We present Identity Bedrock, a deployed identity system constructed from a minimal cryptographic substrate. Starting from the requirement that no institutional key exists beneath the individual, we derive an architecture grounded in one-way functions (OWFs), which are necessary and sufficient for existentially unforgeable signature schemes under adaptive chosen-message attack.

The system separates identity cryptography from directory consensus via a chain-agnostic, append-only binding layer, enabling portability across heterogeneous substrates while preserving verifiability. We instantiate this construction using Emercoin NVS, anchored to Bitcoin via AuxPoW, and NESS Fiber consensus, with publicly verifiable deployment since 2020.

We further introduce a physical presence extension based on bone conduction audio. We argue that this channel exhibits properties analogous to inaccessible entropy, with replay resistance arising from physical constraints rather than computational assumptions. This enables the construction of a Physically-Bound Authentication Token (PBAT), combining cryptographic identity proofs with session-specific biometric evidence.

The contribution is not a new primitive but a binding of existing ones into a system that minimizes institutional dependence while preserving verifiable authentication. All components are implemented and publicly auditable.
\end{abstract}

\section{Introduction}

The problem addressed in this work is whether digital identity can be constructed without reliance on institutional trust anchors beneath the individual. Existing systems rely on certificate authorities, identity providers, or registry operators, each introducing control points external to the user.

We explore a construction derived from minimizing these dependencies.

\subsection{Contributions}

\textbf{Contribution 1 — Minimal construction.}
We formalize an identity system grounded in the equivalence between one-way functions and existentially unforgeable signature schemes. Authentication depends solely on the user’s key.

\textbf{Contribution 2 — Chain-agnostic architecture.}
We separate identity cryptography from directory consensus, enabling portability across append-only substrates.

\textbf{Contribution 3 — Deployed system.}
We describe an operational implementation anchored to Bitcoin via AuxPoW, publicly verifiable since 2020.

\textbf{Contribution 4 — Physical presence extension.}
We introduce a biometric factor based on bone conduction audio and argue that it provides replay resistance through non-computational channel constraints.

\textbf{Contribution 5 — Binding insight.}
We show that combining these components yields properties not present in any component individually.

\section{Physical Presence Extension}

\paragraph{Channel asymmetry.}
Bone conduction introduces an asymmetric channel defined by mechanical coupling to the skull, unlike air-conducted systems where capture and replay channels are symmetric.

\paragraph{Physical constraint model.}
Replay resistance follows from impedance mismatch and coupling characteristics. An adversary must reproduce both acoustic signal and mechanical coupling conditions.

\paragraph{Relation to inaccessible entropy.}
We interpret this property as analogous to inaccessible entropy. This connection is heuristic; a formal reduction remains future work.

\section{Conclusion}

We presented a deployed identity system grounded in minimal cryptographic assumptions and extended with a physically constrained authentication factor.

\end{document}

