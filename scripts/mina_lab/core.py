import hashlib
import json
import base64
from nacl.signing import SigningKey, VerifyKey
from nacl.encoding import HexEncoder, Base64Encoder
from nacl.exceptions import BadSignatureError

def hash_sha256(data: bytes) -> bytes:
    return hashlib.sha256(data).digest()

def hash_hex(data: bytes) -> str:
    return hash_sha256(data).hex()

class MerkleTree:
    """
    A simple Merkle Tree implementation for a Key-Value store.
    It sorts keys to ensure deterministic roots.
    """
    @staticmethod
    def compute_root(data: dict) -> str:
        if not data:
            return "0" * 64

        # 1. Leaf Hashes: H(key + value_json)
        leaves = []
        for key in sorted(data.keys()):
            val_str = json.dumps(data[key], sort_keys=True, separators=(',', ':'))
            leaf_content = f"{key}{val_str}".encode('utf-8')
            leaves.append(hash_sha256(leaf_content))

        # 2. Build Tree
        level = leaves
        while len(level) > 1:
            next_level = []
            for i in range(0, len(level), 2):
                left = level[i]
                if i + 1 < len(level):
                    right = level[i+1]
                else:
                    right = left # Duplicate last if odd
                
                combined = left + right
                next_level.append(hash_sha256(combined))
            level = next_level
        
        return level[0].hex()

    @staticmethod
    def get_proof(data: dict, target_key: str) -> list:
        # Simplified proof generation (Proof of inclusion)
        # For a sorted list merkle tree, a proof is the sibling hashes up the path.
        # NOTE: This is a naive O(N) reconstruction for brevity. 
        # Production systems use optimized sparse trees.
        
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
        
        if target_index == -1: return []

        proof = []
        level = leaves
        curr_idx = target_index

        while len(level) > 1:
            next_level = []
            for i in range(0, len(level), 2):
                left = level[i]
                if i + 1 < len(level):
                    right = level[i+1]
                else:
                    right = left
                
                # If current node is in this pair, add sibling to proof
                if i == curr_idx or i + 1 == curr_idx:
                    if i == curr_idx: # We are left
                        proof.append(('R', right.hex()))
                    else: # We are right
                        proof.append(('L', left.hex()))
                    
                    next_level.append(hash_sha256(left + right))
                    # Update index for next level
                    curr_idx = len(next_level) - 1
                else:
                    next_level.append(hash_sha256(left + right))
            level = next_level
            
        return proof

    @staticmethod
    def verify_proof(root_hex: str, target_key: str, target_val: dict, proof: list) -> bool:
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
        # Canonical JSON for signing
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
            
            # Reconstruct payload
            payload = {k: v for k, v in tx.items() if k != "sig"}
            msg = json.dumps(payload, sort_keys=True, separators=(',', ':')).encode('utf-8')
            
            vk = VerifyKey(sender_vk_hex, encoder=HexEncoder)
            vk.verify(msg, bytes.fromhex(sig_hex))
            return True
        except (BadSignatureError, KeyError, ValueError):
            return False
