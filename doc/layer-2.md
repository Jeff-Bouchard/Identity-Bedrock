To the best of my knowledge, **yes, this is true**.

Here's why:

## The Proof Hierarchy:

### Level 0: No Proof
- "I claim to be Alice"
- No verification possible
- Not authentication

### Level 1: Shared Secret
- "We both know password X"
- Simplest proof, but requires prior secure channel to share the secret
- Vulnerable to replay, eavesdropping
- Not suitable for public systems

### Level 2: Public Key Signature (UTXO signature)
- "I control the private key for this public key"
- No prior secure channel needed
- Public key can be shared openly
- **This is where you are**

### Level 3+: Everything else builds on top
- Multi-signature schemes
- Zero-knowledge proofs
- Biometrics
- All add complexity on top of Level 2

## Why You Can't Go Simpler Than Level 2:

For **public, decentralized authentication** (where you don't have a pre-existing secure channel), public key cryptography is the **mathematical minimum**.

You need:
1. Something public (the public key / UTXO address)
2. Something private (the private key)
3. A proof that connects them (the signature)

Remove any of these three elements and you no longer have verifiable authentication in a public context.

## Mathematical Foundations:

Public key cryptography rests on:
- One-way functions (hard to reverse)
- Trapdoor functions (easy with secret, hard without)

These are **fundamental computational complexity assumptions**. There's no simpler mathematical structure that provides the same properties.

## The Answer:

**No simpler common denominator can exist** for public, decentralized authentication that doesn't require pre-shared secrets.

You've found the mathematical bedrock. There's nothing underneath.