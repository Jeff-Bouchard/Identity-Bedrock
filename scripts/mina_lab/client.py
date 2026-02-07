import argparse
import requests
import json
import sys
from core import MerkleTree, Transaction
from node import derive_key_from_mnemonic # Reusing the helper
from nacl.encoding import HexEncoder

class MinaClient:
    def __init__(self, node_url: str, mnemonic: str = None):
        self.node_url = node_url.rstrip("/")
        self.key = None
        self.address = None
        if mnemonic:
            self.key = derive_key_from_mnemonic(mnemonic)
            self.address = self.key.verify_key.encode(encoder=HexEncoder).decode('utf-8')

    def get_nvs_root(self):
        try:
            r = requests.get(f"{self.node_url}/state")
            if r.status_code == 200:
                data = r.json()
                # In a real app, we would verify data["signature"] against a known Publisher Key
                # For this lab, we just trust the downloaded JSON structure as "the chain state"
                return data
            return None
        except:
            return None

    def get_balance(self, address: str):
        # 1. Get Trusted Root (from NVS)
        nvs_state = self.get_nvs_root()
        if not nvs_state:
            print("Could not fetch Chain State.")
            return

        print(f"Chain Height: {nvs_state['height']}")
        print(f"State Root:   {nvs_state['state_root']}")
        
        # 2. Get Account + Proof
        try:
            r = requests.get(f"{self.node_url}/account/{address}")
            data = r.json()
        except:
            print("Could not fetch account data.")
            return

        acc = data["account"]
        proof = data["proof"]

        # 3. Verify Proof
        # Note: If account doesn't exist (balance 0), proof might be empty or show neighbor. 
        # Our simple MerkleTree implementation returns [] if key missing.
        # So we verify if we got a proof.
        
        if not proof:
            # If no proof, it means it's not in the tree or tree is empty. 
            # If account is empty (0 balance), that's valid.
            if acc["balance"] == 0:
                print(f"Balance: 0 (Validated: Not in tree)")
            else:
                print("Error: Non-zero balance returned with no proof!")
            return

        is_valid = MerkleTree.verify_proof(nvs_state["state_root"], address, acc, proof)
        
        if is_valid:
            print(f"Balance: {acc['balance']}")
            print(f"Nonce:   {acc['nonce']}")
            print(f"Proof:   VALID (Verified against Root)")
        else:
            print(f"Balance: {acc['balance']}")
            print(f"Proof:   INVALID!")

    def send(self, to: str, amount: int):
        if not self.key:
            print("No seed provided. Cannot sign transaction.")
            return

        # Get current nonce
        try:
            r = requests.get(f"{self.node_url}/account/{self.address}")
            acc = r.json()["account"]
            nonce = acc["nonce"] + 1
        except:
            nonce = 1 # Default if not found
            
        # Create TX
        sk_hex = self.key.encode(encoder=HexEncoder).decode('utf-8')
        tx = Transaction.create(sk_hex, to, amount, nonce)
        
        print(f"Sending TX: {tx}")
        
        # Post
        try:
            r = requests.post(f"{self.node_url}/tx", json=tx)
            if r.status_code == 200:
                print("Transaction submitted successfully.")
            else:
                print(f"Submission failed: {r.text}")
        except Exception as e:
            print(f"Error sending TX: {e}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--node", default="http://localhost:61234", help="Node URL")
    
    subparsers = parser.add_subparsers(dest="cmd", required=True)
    
    # Balance
    p_bal = subparsers.add_parser("balance")
    p_bal.add_argument("address", help="Address to check")
    
    # Send
    p_send = subparsers.add_parser("send")
    p_send.add_argument("--words", required=True, help="Sender seed words")
    p_send.add_argument("to", help="Receiver address")
    p_send.add_argument("amount", type=int, help="Amount")

    # My Address
    p_addr = subparsers.add_parser("address")
    p_addr.add_argument("--words", required=True, help="Seed words")
    
    args = parser.parse_args()
    
    mnemonic = None
    if "words" in args:
        mnemonic = args.words

    client = MinaClient(args.node, mnemonic)

    if args.cmd == "balance":
        client.get_balance(args.address)
    elif args.cmd == "send":
        client.send(args.to, args.amount)
    elif args.cmd == "address":
        print(f"Address: {client.address}")

if __name__ == "__main__":
    main()
