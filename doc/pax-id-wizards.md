# PAX / Privateness Identity Wizards

This note specifies how PAX / Privateness identities are created using:

- **PrivatenessTools** (`./keygen`, `./key`, `./user`),
- **`pax_skyproof_tui.sh`** for canonical self-spend proofs, and
- The browser wizards:
  - `scripts/NESS-Node-lite-wizard.html` (lite node + master user),
  - `scripts/PAX-ETH-wizard.html` (EIP-4361 / SIWE binding).

The goal is to keep Identity Bedrock intact: Emercoin NVS + WORM JSON are the only cryptographic directory. Ethereum, Privateness, and Skycoin/Skywire sit above that.

## 1. PAX Ed25519 identity via PrivatenessTools

### 1.1 Commands

Authoritative implementation: `privatenesstools/keygen.py`, `privatenesstools/framework/Container.py`, and `privatenesstools/README.md`.

- **Generate user keypair and keyfiles**

  ```bash
  ./keygen user <username> <entropy>
  ```

  In `KeyManager.__generate_seed(entropy, len)`, `<entropy>` is an **integer loop count**. For each `i` in `range(entropy)` the code does:

  - `rand = b64encode(os.urandom(1024)).decode('utf-8')`, then
  - `generator.add_entropy(rand, str(uuid.getnode()))` on a `prng.UhePrng()` instance, optionally printing `+`.

  Runtime cost scales roughly linearly with `<entropy>`. PAX helper tooling currently defaults to `100`.

  This uses `Container.KeyManager()` to create:

  - `~/.privateness-keys/users.key.json` – multi-user index,
  - `~/.privateness-keys/user.key.json` – current user Ed25519 key (private/public/verify).

- **Derive Emer NVS bindings**

  ```bash
  ./key nvs  ~/.privateness-keys/users.key.json   # NVS key
  ./key worm ~/.privateness-keys/users.key.json   # WORM value
  ```

  These outputs are the exact `(name, value)` pair to commit into Emer NVS as the Bedrock binding `(id, pk)` for the user.

### 1.2 TUI wrapper: `pax_skyproof_tui.sh`

The script `scripts/pax_skyproof_tui.sh` provides an interactive front-end.

Relevant function:

- `create_pax_identity()`:

  - Locates `PrivatenessTools/keygen.py`.
  - Prompts for:
    - `username` – PAX / Privateness username,
    - `entropy` – integer ≥ 1.
  - Executes:

    ```bash
    python keygen.py user "$username" "$entropy"
    ```

The TUI does not change semantics; it simply drives PrivatenessTools with user-provided parameters.

## 2. Lite node + master user wizard (`NESS-Node-lite-wizard.html`)

`scripts/NESS-Node-lite-wizard.html` is a browser wizard that generates a Bash script for setting up a lite node and master user keys.

### 2.1 Inputs

The wizard collects:

- `masterUser` – master user name,
- `masterEntropy` – entropy level for master user key,
- `nodeUrl` – node URL (e.g. `http://batman1.private.ness`),
- `nodeTariff` – tariff in NCH/hour,
- `nodeServices` – comma-separated service list (e.g. `prng,files`),
- `nodeNetwork` – network flags (e.g. `inet,skywire`),
- `nodeEntropy` – entropy level for node key.

### 2.2 Generated script (current behavior)

The embedded JavaScript generates a Bash script that:

1. Ensures a Go/NESS workspace exists and changes into it.
2. Sets up a Python 3 virtualenv and installs dependencies.
3. Clones `https://github.com/NESS-Network/PrivatenessTools` and installs `requirements.txt`.
4. Runs:

   ```bash
   ./keygen user ${masterUser} ${masterEntropy}
   ```

5. Defines:

   ```bash
   homeKeysDir="$HOME/.privateness-keys"
   usersKey="${homeKeysDir}/users.key.json"
   nodeKey="${homeKeysDir}/node.key.json"

   USER_NVS=$(./key nvs  "$usersKey")
   USER_WORM=$(./key worm "$usersKey")
   NODE_NVS=$(./key nvs  "$nodeKey")
   NODE_WORM=$(./key worm "$nodeKey")
   ```

6. Prints a wrapped message instructing the operator to register the `USER_*` and `NODE_*` values via Emer NVS and to configure EmerDNS for `nodeUrl`.

### 2.3 Suggested extension: explicit node key generation

`privatenesstools/keygen.py` exposes a `node` mode:

```bash
./keygen node <url> <tariff> <masterUser> "services" "network" <entropy>
```

To make the lite wizard produce a fully specified node identity, the generated script can be extended to run:

```bash
./keygen node "${nodeUrl}" "${nodeTariff}" "${masterUser}" "${nodeServices}" "${nodeNetwork}" "${nodeEntropy}"
```

After this call, `node.key.json` becomes a concrete node identity file, and `./key nvs` / `./key worm` on `node.key.json` yield the Emer NVS binding for the node.

### 2.4 Human and agent usage

- Human operator:
  - Open `NESS-Node-lite-wizard.html` in a browser.
  - Fill real values for all fields,
  - Click "Generate Script" and save as `nessnode-setup.sh`.
  - Run the script on the server, then register the printed NVS records via Emer wallet or `https://nvs.ness.cx`.

- Agent or backend:
  - Does not need the HTML; it can directly run:

    ```bash
    ./keygen user <username> <entropy>
    ./keygen node <url> <tariff> <masterUser> "services" "network" <entropy>
    ./key nvs  ~/.privateness-keys/users.key.json
    ./key worm ~/.privateness-keys/users.key.json
    ./key nvs  ~/.privateness-keys/node.key.json
    ./key worm ~/.privateness-keys/node.key.json
    ```

  - The resulting `(name, value)` pairs are then committed into Emer NVS through wallet UI, `emercoin-cli`, or an Emer MCP server.

## 3. EIP-4361 / SIWE wizard (`PAX-ETH-wizard.html`)

`scripts/PAX-ETH-wizard.html` provides an ETH-side demo for binding a Privateness username to an Ethereum address using EIP-4361 Sign-In With Ethereum (SIWE).

### 3.1 Behavior

The wizard:

- Accepts:
  - `username` – Privateness username,
  - An Ethereum address (manual or via `window.ethereum`),
  - dApp `domain` and `uri`,
  - `chainId`, `nonce`, and `issuedAt`.

- Builds a SIWE statement:

  ```text
  I assert identity: urn:privateness:user:<username>
  ```

- Constructs the EIP-4361 message:

  ```text
  <domain> wants you to sign in with your Ethereum account:
  <address>

  I assert identity: urn:privateness:user:<username>

  URI: <uri>
  Version: 1
  Chain ID: <chainId>
  Nonce: <nonce>
  Issued At: <issuedAt>
  ```

- Uses an injected EIP-1193 provider (`window.ethereum`) to:
  - Request an address,
  - Call `personal_sign` for the SIWE message,
  - Verify the signature with `ethers.utils.verifyMessage`.

### 3.2 Composition with PrivatenessTools identities

To make this part of a PAX / Identity Bedrock stack:

1. Generate the Ed25519-based PAX identity with `./keygen user` as in §1.
2. Treat `<username>` in the SIWE statement as the same `username` used for `./keygen user`.
3. Use the ETH-side wizard to obtain a signed, verified EIP-4361 message binding `urn:privateness:user:<username>` to a specific Ethereum address.
4. Store the chosen Ethereum address (and optionally a hash of the SIWE payload) as additional fields in the WORM JSON for that user before committing it to Emer NVS.

Ethereum remains an external attestation layer; Emer NVS + WORM continue to define the canonical `(id, pk)` pair.

## 4. Self-spend proofs and PAX / SKY-PROOF TUI

`pax_skyproof_tui.sh` also provides a workflow for Skycoin-type self-spend proofs using `privateness-cli`:

- `select_wallet_and_address()` collects:
  - A Privateness wallet (via `privateness-cli listWallets`),
  - A self-spend address and amount.
- `create_unsigned_tx()` calls:

  ```bash
  privateness-cli createRawTransactionV2 <wallet> <address> <coins> \
      --from-address <address> --unsign --json
  ```

  and extracts the unsigned transaction hex.

- `sign_transaction_from_json()` signs the transaction via:

  ```bash
  privateness-cli signTransaction <wallet> <unsigned_hex> --json
  ```

The resulting JSON files (`unsigned-*.json`, `signed-*.json`) can be packaged into a `sky_proof` object and referenced from WORM JSON to prove control over a Skycoin-type address that shares the same Ed25519 key material.

## 5. Summary

- **PrivatenessTools** (`./keygen`, `./key`) generate the canonical Ed25519 identities and corresponding Emer NVS bindings.
- **`NESS-Node-lite-wizard.html`** is a UX layer that generates a setup script calling those tools with concrete parameters, for both master users and nodes.
- **`PAX-ETH-wizard.html`** generates and verifies an EIP-4361 SIWE message binding an Ethereum address to `urn:privateness:user:<username>`.
- **`pax_skyproof_tui.sh`** orchestrates Privateness wallets and transactions to create canonical self-spend proofs.

All of these sit above the Identity Bedrock: Emercoin NVS + WORM JSON remain the only cryptographic directory; everything else is a layered attestation.
