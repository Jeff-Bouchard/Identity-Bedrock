#!/usr/bin/env python3
"""
Nano-Mina: A succinct blockchain implementation for EmerNVS
Single unified file containing node, client, and core functionality
"""

import http.server
import socketserver
import socket
import json
import time
import os
import argparse
import hashlib
import binascii
import sys
import sqlite3
from typing import Dict, List, Optional, Tuple
from nacl.signing import SigningKey, VerifyKey
from nacl.encoding import HexEncoder, Base64Encoder
from nacl.exceptions import BadSignatureError

# ============================================================================
# BOLTDB-LIKE STORAGE
# ============================================================================

class BoltDB:
    """BoltDB-like key-value store using SQLite"""
    
    def __init__(self, path: str):
        self.path = path
        self.conn = sqlite3.connect(path, timeout=30.0)
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.execute("PRAGMA synchronous=NORMAL")
        self.conn.execute("PRAGMA cache_size=10000")
        self._init_schema()
    
    def _init_schema(self):
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS kv (
                key TEXT PRIMARY KEY,
                value BLOB NOT NULL
            )
        """)
        self.conn.commit()
    
    def get(self, key: str) -> Optional[bytes]:
        cursor = self.conn.execute("SELECT value FROM kv WHERE key = ?", (key,))
        row = cursor.fetchone()
        return row[0] if row else None
    
    def put(self, key: str, value: bytes):
        self.conn.execute("INSERT OR REPLACE INTO kv (key, value) VALUES (?, ?)", (key, value))
        self.conn.commit()
    
    def delete(self, key: str):
        self.conn.execute("DELETE FROM kv WHERE key = ?", (key,))
        self.conn.commit()
    
    def keys(self, prefix: str = "") -> List[str]:
        if prefix:
            cursor = self.conn.execute("SELECT key FROM kv WHERE key LIKE ?", (prefix + "%",))
        else:
            cursor = self.conn.execute("SELECT key FROM kv")
        return [row[0] for row in cursor]
    
    def close(self):
        self.conn.close()

# ============================================================================
# CORE CRYPTOGRAPHIC PRIMITIVES
# ============================================================================

def hash_sha256(data: bytes) -> bytes:
    return hashlib.sha256(data).digest()

def hash_hex(data: bytes) -> str:
    return hash_sha256(data).hex()

def derive_key_from_mnemonic(mnemonic: str, passphrase: str = "") -> SigningKey:
    """Derive Ed25519 key from BIP-39 style mnemonic"""
    mnemonic = " ".join(mnemonic.strip().split())
    salt = ("mnemonic" + passphrase).encode("utf-8")
    dk = hashlib.pbkdf2_hmac("sha512", mnemonic.encode("utf-8"), salt, 2048)
    seed = dk[:32]
    return SigningKey(seed)

class MerkleTree:
    """Merkle tree for state commitment"""
    
    @staticmethod
    def compute_root(data: dict) -> str:
        if not data:
            return "0" * 64

        leaves = []
        for key in sorted(data.keys()):
            val_str = json.dumps(data[key], sort_keys=True, separators=(',', ':'))
            leaf_content = f"{key}{val_str}".encode('utf-8')
            leaves.append(hash_sha256(leaf_content))

        level = leaves
        while len(level) > 1:
            next_level = []
            for i in range(0, len(level), 2):
                left = level[i]
                right = level[i+1] if i+1 < len(level) else left
                next_level.append(hash_sha256(left + right))
            level = next_level
        
        return level[0].hex()

    @staticmethod
    def get_proof(data: dict, target_key: str) -> List[Tuple[str, str]]:
        """Generate Merkle proof for a key"""
        if target_key not in data:
            return []

        leaves = []
        target_index = -1
        sorted_keys = sorted(data.keys())
        
        for idx, key in enumerate(sorted_keys):
            val_str = json.dumps(data[key], sort_keys=True, separators=(',', ':'))
            leaf_content = f"{key}{val_str}".encode('utf-8')
            h = hash_sha256(leaf_content)
            leaves.append(h)
            if key == target_key:
                target_index = idx
        
        if target_index == -1:
            return []

        proof = []
        level = leaves
        curr_idx = target_index

        while len(level) > 1:
            next_level = []
            for i in range(0, len(level), 2):
                left = level[i]
                right = level[i+1] if i+1 < len(level) else left
                
                if i == curr_idx or i + 1 == curr_idx:
                    if i == curr_idx:
                        proof.append(('R', right.hex()))
                    else:
                        proof.append(('L', left.hex()))
                    next_level.append(hash_sha256(left + right))
                    curr_idx = len(next_level) - 1
                else:
                    next_level.append(hash_sha256(left + right))
            level = next_level
            
        return proof

    @staticmethod
    def verify_proof(root_hex: str, target_key: str, target_val: dict, proof: List[Tuple[str, str]]) -> bool:
        """Verify Merkle proof"""
        val_str = json.dumps(target_val, sort_keys=True, separators=(',', ':'))
        leaf_content = f"{target_key}{val_str}".encode('utf-8')
        curr_hash = hash_sha256(leaf_content)

        for direction, sibling_hex in proof:
            sibling = bytes.fromhex(sibling_hex)
            if direction == 'R':
                combined = curr_hash + sibling
            else:
                combined = sibling + curr_hash
            curr_hash = hash_sha256(combined)
            
        return curr_hash.hex() == root_hex

class Transaction:
    """Transaction structure and validation"""
    
    @staticmethod
    def create(sender_sk_hex: str, to: str, amount: int, nonce: int) -> dict:
        sk = SigningKey(sender_sk_hex, encoder=HexEncoder)
        vk = sk.verify_key
        sender = vk.encode(encoder=HexEncoder).decode('utf-8')

        tx_payload = {
            "from": sender,
            "to": to,
            "amount": amount,
            "nonce": nonce
        }
        
        msg = json.dumps(tx_payload, sort_keys=True, separators=(',', ':')).encode('utf-8')
        sig = sk.sign(msg).signature
        
        tx = tx_payload.copy()
        tx["sig"] = sig.hex()
        return tx

    @staticmethod
    def verify(tx: dict) -> bool:
        try:
            sender_vk_hex = tx["from"]
            sig_hex = tx["sig"]
            
            payload = {k: v for k, v in tx.items() if k != "sig"}
            msg = json.dumps(payload, sort_keys=True, separators=(',', ':')).encode('utf-8')
            
            vk = VerifyKey(sender_vk_hex, encoder=HexEncoder)
            vk.verify(msg, bytes.fromhex(sig_hex))
            return True
        except (BadSignatureError, KeyError, ValueError):
            return False

# ============================================================================
# CHAIN STATE MANAGEMENT
# ============================================================================

class NanoMinaChain:
    """Core chain state management with BoltDB storage"""
    
    def __init__(self, data_dir: str = "chain_data"):
        self.data_dir = data_dir
        if not os.path.exists(data_dir):
            os.makedirs(data_dir)
            
        self.db_path = os.path.join(data_dir, "chain.db")
        self.nvs_file = os.path.join(data_dir, "nvs_record.json")
        
        # BoltDB-like storage
        self.db = BoltDB(self.db_path)
        
        # Chain state
        self.chain_height = 0
        self.prev_hash = "0" * 64
        self.publisher_key = None
        self.signing_key = None
        
        # Mempool
        self.mempool = []
        
        self.load_state()

    def load_state(self):
        """Load or initialize chain state from BoltDB"""
        # Load chain metadata
        height_bytes = self.db.get("chain:height")
        if height_bytes:
            self.chain_height = int.from_bytes(height_bytes, 'big')
        
        prev_hash_bytes = self.db.get("chain:prev_hash")
        if prev_hash_bytes:
            self.prev_hash = prev_hash_bytes.hex()
        
        publisher_bytes = self.db.get("chain:publisher")
        if publisher_bytes:
            self.publisher_key = publisher_bytes.hex()
        
        # Load NVS record if exists
        if os.path.exists(self.nvs_file):
            with open(self.nvs_file, 'r') as f:
                nvs = json.load(f)
                self.chain_height = nvs.get("height", 0)
                self.prev_hash = nvs.get("signature", "0"*64)
                self.publisher_key = nvs.get("publisher", None)

    def save_state(self):
        """Save state to BoltDB (auto-committed on put)"""
        self.db.put("chain:height", self.chain_height.to_bytes(8, 'big'))
        self.db.put("chain:prev_hash", bytes.fromhex(self.prev_hash))
        if self.publisher_key:
            self.db.put("chain:publisher", bytes.fromhex(self.publisher_key))

    def init_chain(self, mnemonic: str, genesis_supply: int = 1000000):
        """Initialize chain with publisher and configurable genesis supply"""
        self.signing_key = derive_key_from_mnemonic(mnemonic)
        self.publisher_key = self.signing_key.verify_key.encode(encoder=HexEncoder).decode('utf-8')
        
        # Genesis state: configurable initial supply
        genesis_account = {"balance": genesis_supply, "nonce": 0}
        self.db.put(f"account:{self.publisher_key}", json.dumps(genesis_account).encode())
        
        self.chain_height = 0
        self.prev_hash = "0" * 64
        
        self.save_state()
        record = self.create_nvs_record()
        
        print(f"Chain initialized with {genesis_supply:,} tokens")
        print(f"Publisher: {self.publisher_key}")
        print(f"All tokens initially held by publisher")
        return record

    def get_account(self, address: str) -> dict:
        """Get account state from BoltDB"""
        account_bytes = self.db.get(f"account:{address}")
        if account_bytes:
            return json.loads(account_bytes.decode())
        return {"balance": 0, "nonce": 0}

    def set_account(self, address: str, account: dict):
        """Set account state in BoltDB"""
        self.db.put(f"account:{address}", json.dumps(account).encode())

    def get_all_accounts(self) -> dict:
        """Get all accounts for Merkle tree computation"""
        accounts = {}
        for key in self.db.keys("account:"):
            address = key[8:]  # Remove "account:" prefix
            accounts[address] = self.get_account(address)
        return accounts

    def add_transaction(self, tx: dict) -> bool:
        """Add transaction to mempool"""
        if not Transaction.verify(tx):
            return False
        
        sender = tx["from"]
        acc = self.get_account(sender)
        
        if tx["nonce"] <= acc["nonce"]:
            return False
            
        if acc["balance"] < tx["amount"]:
            return False

        self.mempool.append(tx)
        return True

    def produce_block(self) -> Optional[dict]:
        """Produce block from mempool (Fiber-style: on-demand)"""
        if not self.mempool:
            return None

        # Process transactions
        valid_txs = []
        for tx in self.mempool:
            sender = tx["from"]
            receiver = tx["to"]
            amount = tx["amount"]
            
            sender_acc = self.get_account(sender)
            if sender_acc["balance"] >= amount:
                # Update state
                new_sender_acc = sender_acc.copy()
                new_sender_acc["balance"] -= amount
                new_sender_acc["nonce"] = tx["nonce"]
                self.set_account(sender, new_sender_acc)
                
                receiver_acc = self.get_account(receiver)
                new_receiver_acc = receiver_acc.copy()
                new_receiver_acc["balance"] += amount
                self.set_account(receiver, new_receiver_acc)
                
                valid_txs.append(tx)

        self.mempool = []
        self.save_state()

        # Update chain
        self.chain_height += 1
        accounts = self.get_all_accounts()
        root = MerkleTree.compute_root(accounts)
        
        return self.create_nvs_record()

    def create_nvs_record(self) -> dict:
        """Create NVS record for current state"""
        accounts = self.get_all_accounts()
        root = MerkleTree.compute_root(accounts)
        
        record = {
            "protocol": "ness-mina-v1",
            "publisher": self.publisher_key,
            "height": self.chain_height,
            "timestamp": int(time.time()),
            "state_root": root,
            "prev_hash": self.prev_hash
        }
        
        if self.signing_key:
            canonical = json.dumps(record, sort_keys=True, separators=(',', ':')).encode('utf-8')
            sig = self.signing_key.sign(canonical).signature
            record["signature"] = binascii.hexlify(sig).decode('utf-8')
            self.prev_hash = record["signature"]
        
        with open(self.nvs_file, 'w') as f:
            json.dump(record, f, indent=2)
        
        return record

    def get_account_with_proof(self, address: str) -> Tuple[dict, List[Tuple[str, str]]]:
        """Get account state with Merkle proof"""
        account = self.get_account(address)
        accounts = self.get_all_accounts()
        proof = MerkleTree.get_proof(accounts, address)
        return account, proof

# ============================================================================
# HTTP API SERVER
# ============================================================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


class NanoMinaRequestHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for Nano-Mina node"""
    
    chain = None

    def do_OPTIONS(self):
        """Handle preflight requests for CORS"""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        try:
            # Serve static HTML files
            if self.path == '/' or self.path == '/unified.html':
                self.serve_file('unified.html')
                return
            elif self.path == '/interface.html':
                self.serve_file('interface.html')
                return
            elif self.path == '/dashboard.html':
                self.serve_file('dashboard.html')
                return
            elif self.path == "/state":
                self.send_json(self.chain.create_nvs_record())
            elif self.path.startswith("/account/"):
                addr = self.path.split("/")[-1]
                account, proof = self.chain.get_account_with_proof(addr)
                self.send_json({"account": account, "proof": proof})
            elif self.path == "/mempool":
                self.send_json({"transactions": self.chain.mempool})
            elif self.path == "/produce":
                rec = self.chain.produce_block()
                if rec:
                    self.send_json(rec)
                else:
                    self.send_json({"status": "no_block"})
            else:
                self.send_error(404)
        except ConnectionAbortedError:
            # Client disconnected, ignore
            pass
        except Exception as e:
            print(f"Error in GET request: {e}")
            self.send_error(500, "Internal server error")

    def serve_file(self, filename):
        """Serve static HTML file"""
        try:
            candidates = [
                os.path.join(BASE_DIR, filename.lstrip("/")),
                os.path.join(os.getcwd(), filename.lstrip("/"))
            ]
            file_path = None
            for cand in candidates:
                if os.path.isfile(cand):
                    file_path = cand
                    break
            print(f"[static] request={filename} resolved={file_path}")
            if not file_path:
                print(f"[static] not found in {candidates}")
                self.send_error(404, f"File not found: {filename}")
                return
            with open(file_path, 'rb') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_cors_headers()
            if filename.endswith('.html'):
                self.send_header("Content-type", "text/html")
            elif filename.endswith('.css'):
                self.send_header("Content-type", "text/css")
            elif filename.endswith('.js'):
                self.send_header("Content-type", "application/javascript")
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            self.send_error(404, "File not found")
        except Exception as e:
            print(f"Error serving file {filename}: {e}")
            self.send_error(500, "Internal server error")

    def do_POST(self):
        if self.path == "/tx":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            tx = json.loads(post_data.decode('utf-8'))
            
            success = self.chain.add_transaction(tx)
            self.send_json({"success": success})

    def send_cors_headers(self):
        """Send CORS headers for all responses"""
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def send_json(self, data):
        try:
            self.send_response(200)
            self.send_cors_headers()
            self.send_header("Content-type", "application/json")
            self.end_headers()
            
            # Ensure data is JSON serializable
            json_str = json.dumps(data, default=str, separators=(',', ':'))
            self.wfile.write(json_str.encode('utf-8'))
        except Exception as e:
            print(f"Error sending JSON response: {e}")
            self.send_error(500, "Internal server error")

    def log_message(self, format, *args):
        # Only suppress GET/POST success messages, show errors
        msg = format % args
        if 'GET /' in msg and '200' in msg:
            return  # Suppress successful GET requests
        if 'POST /' in msg and '200' in msg:
            return  # Suppress successful POST requests
        print(msg)  # Show everything else including errors

# ============================================================================
# CLIENT INTERFACE
# ============================================================================

class NanoMinaClient:
    """Client interface for interacting with Nano-Mina chain"""
    
    def __init__(self, node_url: str = "http://localhost:61234"):
        self.node_url = node_url.rstrip("/")

    def get_state(self) -> dict:
        """Get current chain state"""
        r = requests.get(f"{self.node_url}/state")
        return r.json()

    def get_balance(self, address: str) -> Tuple[int, int, bool]:
        """Get balance with proof verification"""
        # Get state
        state = self.get_state()
        
        # Get account and proof
        r = requests.get(f"{self.node_url}/account/{address}")
        data = r.json()
        
        account = data["account"]
        proof = data["proof"]
        
        # Verify proof
        if proof:
            is_valid = MerkleTree.verify_proof(
                state["state_root"], 
                address, 
                account, 
                proof
            )
            return account["balance"], account["nonce"], is_valid
        else:
            return account["balance"], account["nonce"], account["balance"] == 0

    def send_transaction(self, mnemonic: str, to: str, amount: int) -> bool:
        """Send signed transaction"""
        key = derive_key_from_mnemonic(mnemonic)
        sk_hex = key.encode(encoder=HexEncoder).decode('utf-8')
        
        # Get current nonce
        addr = key.verify_key.encode(encoder=HexEncoder).decode('utf-8')
        _, nonce, _ = self.get_balance(addr)
        
        # Create and send transaction
        tx = Transaction.create(sk_hex, to, amount, nonce + 1)
        
        r = requests.post(f"{self.node_url}/tx", json=tx)
        return r.json()["success"]

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

def is_port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def run_node(port: int, seed_words: str, genesis_supply: int, data_dir: str = "chain_data"):
    """Run Nano-Mina node"""
    
    # Convert to absolute paths
    data_dir = os.path.abspath(data_dir)
    
    print("=" * 80)
    print("NANO-MINA BLOCKCHAIN NODE STARTING")
    print("=" * 80)
    print(f"Port: {port}")
    print(f"Full API URL: http://localhost:{port}")
    print(f"Seed words: '{seed_words}'")
    print(f"Genesis supply: {genesis_supply:,} tokens")
    print("-" * 80)
    
    # Check port availability
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    if sock.connect_ex(('localhost', port)) == 0:
        print(f"ERROR: Port {port} is already in use!")
        print(f"Please choose a different port or stop the existing service.")
        return
    sock.close()
    
    print("Initializing blockchain...")
    chain = NanoMinaChain(data_dir)
    record = chain.init_chain(seed_words, genesis_supply)
    
    print(f"Publisher address: {chain.publisher_key}")
    print(f"All {genesis_supply:,} tokens initially held by publisher")
    record = chain.create_nvs_record()
    print(f"Chain state root: {record['state_root']}")
    accounts = chain.get_all_accounts()
    print(f"Total accounts in genesis: {len(accounts)}")
    print("-" * 80)
    
    # Set chain for request handler
    NanoMinaRequestHandler.chain = chain
    
    server_address = ('', port)
    httpd = http.server.HTTPServer(server_address, NanoMinaRequestHandler)
    
    print("SERVER STARTED SUCCESSFULLY")
    print("=" * 80)
    print(f"Node API endpoints:")
    print(f"  • Chain state: http://localhost:{port}/state")
    print(f"  • Account info: http://localhost:{port}/account/<address>")
    print(f"  • Mempool: http://localhost:{port}/mempool")
    print(f"  • Send TX: POST http://localhost:{port}/tx")
    print(f"  • Produce block: http://localhost:{port}/produce")
    print("-" * 80)
    print("WEB INTERFACES:")
    print(f"  • Unified Interface: http://localhost:{port}/unified.html")
    print(f"  • Simple Interface: http://localhost:{port}/interface.html")
    print(f"  • Dashboard: http://localhost:{port}/dashboard.html")
    print("-" * 80)
    print("CLIENT COMMANDS:")
    print(f"  • Check balance: python nanomina.py client --node http://localhost:{port} balance <address>")
    print(f"  • Send tokens: python nanomina.py client --node http://localhost:{port} send <seed> <to> <amount>")
    print(f"  • Get address: python nanomina.py client --node http://localhost:{port} address --words '<seed>'")
    print("=" * 80)
    print("Node is ready. Press Ctrl+C to stop.")
    print()
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n" + "=" * 80)
        print("SHUTTING DOWN NODE...")
        print(f"Saved chain data to: {data_dir}")
        print(f"Final height: {chain.chain_height}")
        print("Node stopped gracefully.")
        print("=" * 80)
        httpd.server_close()

def client_cmd(args):
    """Client command interface"""
    client = NanoMinaClient(args.node)
    
    if args.cmd == "balance":
        balance, nonce, valid = client.get_balance(args.address)
        print(f"Address: {args.address}")
        print(f"Balance: {balance}")
        print(f"Nonce: {nonce}")
        print(f"Proof: {'VALID' if valid else 'INVALID'}")
        
    elif args.cmd == "send":
        success = client.send_transaction(args.words, args.to, args.amount)
        if success:
            print("Transaction sent successfully")
        else:
            print("Transaction failed")
            
    elif args.cmd == "address":
        key = derive_key_from_mnemonic(args.words)
        addr = key.verify_key.encode(encoder=HexEncoder).decode('utf-8')
        print(f"Address: {addr}")

def main():
    parser = argparse.ArgumentParser(description="Nano-Mina: Succinct blockchain for EmerNVS")
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # Node command
    node_parser = subparsers.add_parser("node", help="Run Nano-Mina node")
    node_parser.add_argument("--port", type=int, default=61234, help="Port to listen on")
    node_parser.add_argument("--words", required=True, help="Publisher seed words")
    node_parser.add_argument("--supply", type=int, default=1000000, help="Genesis token supply")
    node_parser.add_argument("--data", default="chain_data", help="Data directory")
    
    # Client commands
    client_parser = subparsers.add_parser("client", help="Client interface")
    client_parser.add_argument("--node", default="http://localhost:61234", help="Node URL")
    
    client_subparsers = client_parser.add_subparsers(dest="cmd", required=True)
    
    # Balance
    bal_parser = client_subparsers.add_parser("balance", help="Check balance")
    bal_parser.add_argument("address", help="Address to check")
    
    # Send
    send_parser = client_subparsers.add_parser("send", help="Send transaction")
    send_parser.add_argument("--words", required=True, help="Sender seed words")
    send_parser.add_argument("to", help="Recipient address")
    send_parser.add_argument("amount", type=int, help="Amount to send")
    
    # Address
    addr_parser = client_subparsers.add_parser("address", help="Get address from seed")
    addr_parser.add_argument("--words", required=True, help="Seed words")
    
    args = parser.parse_args()
    
    if args.command == "node":
        run_node(args.port, args.words, args.supply, args.data)
    elif args.command == "client":
        client_cmd(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
