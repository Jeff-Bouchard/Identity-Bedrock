% Identity Bedrock — V12 (Full, reviewer-safe, PBAT removed)
% Compile: pdflatex -> pdflatex

\documentclass[11pt,a4paper]{article}

\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
\usepackage{microtype}
\usepackage{amsmath,amssymb,amsthm}
\usepackage{mathtools}
\usepackage{booktabs}
\usepackage{array}
\usepackage[colorlinks=true,linkcolor=black,citecolor=black,urlcolor=blue]{hyperref}
\usepackage{geometry}

\geometry{a4paper,margin=25mm}

\newtheorem{theorem}{Theorem}[section]
\newtheorem{definition}[theorem]{Definition}
\newtheorem{remark}[theorem]{Remark}

\begin{document}

\title{\textbf{Identity Bedrock: A Minimal Cryptographic Substrate for Sovereign Identity}}
\author{Jean-Fran\c{c}ois Bouchard}
\date{March 2026}
\maketitle

\begin{abstract}
We present Identity Bedrock, a deployed identity system constructed from a minimal cryptographic substrate. Starting from the requirement that no institutional key exists beneath the individual, we derive an architecture grounded in one-way functions (OWFs), which are necessary and sufficient for existentially unforgeable signature schemes under adaptive chosen-message attack.

The system separates identity cryptography from directory consensus via a chain-agnostic, append-only binding layer, enabling portability across heterogeneous substrates while preserving verifiability. We instantiate this construction using Emercoin NVS anchored to Bitcoin via AuxPoW, with publicly verifiable deployment since 2020.

The contribution is not a new primitive but a binding of existing ones into a system that minimizes trust assumptions while preserving verifiable authentication.
\end{abstract}

\section{Introduction}

Digital identity systems commonly rely on institutional trust anchors such as certificate authorities or identity providers. These introduce external control points over identity.

This work explores whether identity can be constructed by minimizing such dependencies, using only necessary cryptographic assumptions.

\subsection{Contributions}

\textbf{Minimal construction.} Identity grounded in OWF-based signatures.

\textbf{Chain-agnostic architecture.} Decoupled identity and directory layers.

\textbf{Deployed system.} Publicly verifiable implementation since 2020.

\textbf{Binding insight.} Emergent properties arise from combining these components.

\section{Background}

One-way functions (OWFs) are necessary and sufficient for existentially unforgeable signature schemes. This equivalence provides a natural minimal foundation for authentication.

\section{Architecture}

\subsection{Layer 1: Identity Cryptography}

A user generates a keypair $(sk, pk)$ from a high-entropy seed. Authentication consists of signing a challenge.

\subsection{Layer 2: Directory Substrate}

An append-only directory binds identifiers to public keys. The directory provides global verifiability and finality.

\section{Security}

\begin{theorem}
If the signature scheme is existentially unforgeable under adaptive chosen-message attack and the directory is append-only with finality, then authentication is unforgeable under standard assumptions.
\end{theorem}

\begin{proof}
A successful forgery implies a break of the underlying signature scheme or directory integrity.
\end{proof}

\section{Implementation}

The system is implemented using Emercoin NVS and anchored to Bitcoin via AuxPoW. Identity bindings are publicly verifiable.

\section{Evaluation}

Authentication requires only signature verification and directory lookup, yielding low latency and minimal computational overhead.

\section{Conclusion}

Identity Bedrock demonstrates that a minimal cryptographic substrate combined with an append-only directory enables authentication without institutional trust anchors.

\end{document}

