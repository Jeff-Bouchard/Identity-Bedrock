# Nano-Mina Lab

This is a complete, minimal implementation of a "Mina-style" succinct blockchain compatible with Emercoin NVS limits (<20KB).

## Architecture

1. **Block Production (`node.py`):**
   - Single Publisher (Fiber model).
   - Maintains a full State (Accounts -> Balances) locally.
   - Accepts Transactions via HTTP.
   - Produces "Blocks" by updating the State and calculating a new **Merkle Root**.
   - Publishes the Root + Chain Height + Signature to a JSON file (simulating EmerNVS).
   - **Data Availability:** In this validium mode, the Node stores the data. The NVS only stores the cryptographic commitment (Root).

2. **Client (`client.py`):**
   - Light Client.
   - Trusts the EmerNVS Record (Root + Signature).
   - Queries the Node for Balances.
   - **Crucially:** Verifies the Node's answer against the Trusted Root using a **Merkle Proof**.
   - Sends signed transactions.

## Setup

Install dependencies:

```bash
pip install -r ../../privatenesstools/requirements.txt
```

## How to Run

### 1. Start the Node (Publisher)

You need a 12-word seed for the publisher.

```bash
cd scripts/mina_lab
# Start node on port 61234 (Default)
python node.py --words "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
```

The node will initialize a genesis state (giving the publisher 1,000,000 tokens) and start an HTTP server.

### 2. Use the Client

Open a new terminal.

#### Check Publisher Balance

```bash
# Get address for the seed
python client.py address --words "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

# Check balance (replace ADDRESS with the one above)
python client.py balance <ADDRESS>
```

*Observe that the client verifies the Merkle Proof against the Root.*

#### Send a Transaction

Create a second wallet (seed "test test ...") and send tokens to it.

```bash
# Get destination address
python client.py address --words "test test test test test test test test test test test test"
# -> Output: <DEST_ADDRESS>

# Send 50 tokens from Publisher to Dest
python client.py send --words "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about" <DEST_ADDRESS> 50
```

#### Produce a Block

The node holds the TX in mempool. Trigger a block production:

```bash
curl http://localhost:61234/produce
```

(Or waiting if you implemented a timer. The lab node uses manual production for clarity).

#### Check New Balance

```bash
python client.py balance <DEST_ADDRESS>
```

*You will see the balance update and a valid Proof.*

## Usage Scenarios

### 1. Alone (Standalone Personal Blockchain)

In this mode, you use the tools exactly as above.

- You are the sole authority.
- Clients connect directly to your `node.py` IP/Port to fetch proofs.
- **Use Case:** Immutable personal logs, private token systems among friends, or a localized "Layer 2" for data timestamping.

### 2. With Privateness (Global Directory)

This integrates your chain into the global `privateness.network` ecosystem.

1. **The Anchor:** The `nvs_record.json` file produced by `node.py` is your **Identity Bedrock** binding.
2. **Upload:** Use `privatenesstools` to upload this record to Emercoin NVS.
   ```bash
   # Example (Conceptual)
   python privatenesstools/upload.py --name "mina:my-chain" --file "node_data/nvs_record.json"
   ```
3. **The Client:**
   - Instead of trusting `http://localhost:61234/state`, the client fetches the JSON from Emercoin NVS (`mina:my-chain`).
   - This gives the Client a **globally finalized, censorship-resistant Root**.
   - The Client then asks your Node (service) only for the *Proof path*, verifying it against the NVS Root.

This architecture allows your tiny chain to inherit the **$5-20B attack cost** of the Bitcoin/Emercoin network for its finality, while keeping the actual data storage on your own cheap service node.
