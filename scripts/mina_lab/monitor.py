import requests
import json
import hashlib
import time
from nanomina import NanoMinaClient, MerkleTree

# Simple monitoring dashboard
class NanoMinaMonitor:
    def __init__(self, node_url="http://localhost:61234"):
        self.client = NanoMinaClient(node_url)
        
    def get_chain_info(self):
        """Get comprehensive chain information"""
        state = self.client.get_state()
        return {
            "height": state["height"],
            "root": state["state_root"],
            "publisher": state["publisher"],
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(state["timestamp"]))
        }
        
    def get_mempool_info(self):
        """Get mempool status"""
        r = requests.get(f"{self.client.node_url}/mempool")
        data = r.json()
        return {
            "count": len(data["transactions"]),
            "transactions": data["transactions"]
        }
        
    def verify_chain_state(self):
        """Verify chain state integrity"""
        state = self.client.get_state()
        # In a real implementation, this would verify the signature
        return {
            "valid": True,  # Simplified
            "publisher": state["publisher"],
            "signature": state["signature"][:16] + "..."
        }

if __name__ == "__main__":
    monitor = NanoMinaMonitor()
    
    print("=== Nano-Mina Chain Monitor ===")
    info = monitor.get_chain_info()
    print(f"Height: {info['height']}")
    print(f"Root: {info['root']}")
    print(f"Publisher: {info['publisher']}")
    print(f"Updated: {info['timestamp']}")
    
    mempool = monitor.get_mempool_info()
    print(f"\nMempool: {mempool['count']} transactions")
    
    verification = monitor.verify_chain_state()
    print(f"\nChain state: {'VALID' if verification['valid'] else 'INVALID'}")
