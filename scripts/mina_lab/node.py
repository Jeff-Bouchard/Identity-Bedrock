import http.server
import socketserver
import socket
import json
import time
import os
import argparse
import hashlib
import binascii
from nacl.signing import SigningKey
from nacl.encoding import HexEncoder
from core import MerkleTree, Transaction

# Reusing the PBKDF2 logic for seed derivation
def derive_key_from_mnemonic(mnemonic: str, passphrase: str = "") -> SigningKey:
    mnemonic = " ".join(mnemonic.strip().split())
    salt = ("mnemonic" + passphrase).encode("utf-8")
    dk = hashlib.pbkdf2_hmac("sha512", mnemonic.encode("utf-8"), salt, 2048)
    seed = dk[:32]
    return SigningKey(seed)

class MinaNode:
    def __init__(self, mnemonic: str, data_dir: str = "node_data"):
        self.key = derive_key_from_mnemonic(mnemonic)
        self.pub_key = self.key.verify_key.encode(encoder=HexEncoder).decode('utf-8')
        self.data_dir = data_dir
        if not os.path.exists(data_dir):
            os.makedirs(data_dir)
            
        self.state_file = os.path.join(data_dir, "state.json")
        self.nvs_file = os.path.join(data_dir, "nvs_record.json")
        
        # Load or Init State
        # State structure: {address: {balance: int, nonce: int}}
        self.state_data = {}
        self.load_state()

        self.mempool = []
        self.chain_height = 0
        self.prev_hash = "0" * 64
        
        # Try to load existing NVS info to get height/prev_hash
        if os.path.exists(self.nvs_file):
            with open(self.nvs_file, 'r') as f:
                nvs = json.load(f)
                self.chain_height = nvs.get("height", 0)
                self.prev_hash = nvs.get("signature", "0"*64) # Using sig as prev_hash for simplicity in this chain

        print(f"Node initialized.")
        print(f"Publisher: {self.pub_key}")
        print(f"Height: {self.chain_height}")

    def load_state(self):
        if os.path.exists(self.state_file):
            with open(self.state_file, 'r') as f:
                self.state_data = json.load(f)
        else:
            # Genesis state: Give publisher some tokens
            self.state_data = {
                self.pub_key: {"balance": 1000000, "nonce": 0}
            }
            self.save_state()

    def save_state(self):
        with open(self.state_file, 'w') as f:
            json.dump(self.state_data, f, indent=2)

    def get_account(self, address: str):
        return self.state_data.get(address, {"balance": 0, "nonce": 0})

    def add_tx(self, tx: dict) -> bool:
        if not Transaction.verify(tx):
            print("Invalid signature")
            return False
        
        # Basic checks
        sender = tx["from"]
        acc = self.get_account(sender)
        
        # Check nonce (simplified: strictly sequential)
        # Note: In a real mempool we might handle gaps/ordering.
        # Here we just check against current state.
        if tx["nonce"] <= acc["nonce"]:
            print(f"Nonce too low: {tx['nonce']} <= {acc['nonce']}")
            return False
            
        if acc["balance"] < tx["amount"]:
            print("Insufficient funds")
            return False

        self.mempool.append(tx)
        print(f"Added TX to mempool: {tx}")
        return True

    def produce_block(self):
        if not self.mempool:
            print("Mempool empty, skipping block")
            return None

        # Process TXs
        valid_txs = []
        for tx in self.mempool:
            sender = tx["from"]
            receiver = tx["to"]
            amount = tx["amount"]
            
            # Re-check in case multiple txs from same sender invalidated state
            sender_acc = self.get_account(sender)
            if sender_acc["balance"] >= amount:
                # Debit
                self.state_data.setdefault(sender, {"balance": 0, "nonce": 0})
                self.state_data[sender]["balance"] -= amount
                self.state_data[sender]["nonce"] = tx["nonce"] # Update nonce
                
                # Credit
                self.state_data.setdefault(receiver, {"balance": 0, "nonce": 0})
                self.state_data[receiver]["balance"] += amount
                
                valid_txs.append(tx)
            else:
                print(f"Skipping TX {tx} due to funds")

        self.mempool = [] # Clear mempool
        self.save_state()

        # Update Chain
        self.chain_height += 1
        root = MerkleTree.compute_root(self.state_data)
        
        # Create NVS Record
        record = {
            "protocol": "ness-mina-v1",
            "publisher": self.pub_key,
            "height": self.chain_height,
            "timestamp": int(time.time()),
            "state_root": root,
            "prev_hash": self.prev_hash
        }
        
        # Sign Record
        canonical = json.dumps(record, sort_keys=True, separators=(',', ':')).encode('utf-8')
        sig = self.key.sign(canonical).signature
        record["signature"] = binascii.hexlify(sig).decode('utf-8')
        
        self.prev_hash = record["signature"] # Chain hash

        with open(self.nvs_file, 'w') as f:
            json.dump(record, f, indent=2)

        print(f"Produced Block {self.chain_height}. Root: {root}")
        return record

# HTTP Handler
node_instance = None

class RequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/state":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            with open(node_instance.nvs_file, 'r') as f:
                self.wfile.write(f.read().encode())
        elif self.path.startswith("/account/"):
            addr = self.path.split("/")[-1]
            acc = node_instance.get_account(addr)
            proof = MerkleTree.get_proof(node_instance.state_data, addr)
            resp = {
                "account": acc,
                "proof": proof
            }
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode())
        elif self.path == "/produce":
            # Manually trigger block production
            rec = node_instance.produce_block()
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(rec if rec else {"status": "no_block"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/tx":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            tx = json.loads(post_data.decode('utf-8'))
            
            success = node_instance.add_tx(tx)
            
            self.send_response(200 if success else 400)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": success}).encode())

def is_port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def run(port=61234, mnemonic=""):
    global node_instance
    
    if is_port_in_use(port):
        print(f"Error: Port {port} is already in use. Please choose another port.")
        return

    node_instance = MinaNode(mnemonic)
    
    server_address = ('', port)
    httpd = http.server.HTTPServer(server_address, RequestHandler)
    print(f"Starting Mina Node on port {port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=61234)
    parser.add_argument("--words", type=str, required=True, help="12/24 words seed")
    args = parser.parse_args()
    
    run(args.port, args.words)
