PAX agit comme un hyperviseur d’identité souveraine extérieur à Ethereum mais exposé via SIWE standard. La racine reste l’entrée EmerNVS/WORM (worm:user:ness:<username>) signée Ed25519 : c’est elle qui définit le sujet, pas un compte ETH. Concrètement :

Chaîne d’attestation : le wallet Privateness signe le challenge PAX pour prouver l’identité, puis génère un SIWE classique dont la déclaration contient « I assert identity: urn:privateness:user: ». Le dApp vérifie la signature EIP‑4361 comme d’habitude et obtient une liaison dure entre l’adresse Ethereum et la racine EmerNVS—sans aucune modification côté ETH.
Résilience censure / upgrades : si un compte EOA/AA est censuré ou si Ethereum change ses règles, on rebinde simplement une nouvelle adresse via SIWE. L’identité PAX reste valide car l’autorité est l’entrée EmerNVS + la clé Ed25519, indépendante d’Ethereum.
Preuves additionnelles optionnelles : on peut inclure des preuves Sky/Privateness (self-spend canonique) et autres métadonnées dans le même payload/JWT. Les dApps Ethereum reçoivent ainsi un sujet « personne » dont l’historique est ancré dans un namespace append-only qu’elles ne contrôlent pas, sans devoir héberger un registre d’identité.
Bref, PAX « importe » dans Ethereum des identités résistantes à la censure tout en laissant la souveraineté hors de l’écosystème. Les dApps bénéficient de sujets fiables et rotatifs, sans toucher au protocole ETH ni dépendre d’un ID centralisé.

## 1. Racine cryptographique PAX

La racine ne vit pas sur Ethereum mais dans Emercoin NVS + WORM, telle que formalisée dans *Identity Bedrock over Emercoin NVS and Skycoin‑Type Chains* :

- l’objet identité est `(id, pk)` avec `id = worm:user:ness:<username>` et `pk` une clé Ed25519 ;
- l’enregistrement EmerNVS contient le WORM JSON produit par `PrivatenessTools` (`./key worm ~/.privateness-keys/users.key.json`).

Génération des clés côté client :

- `./keygen user <username> <entropy>` appelle `KeyManager.__keypair(entropy)`;
- `__keypair(entropy)` appelle `__generate_seed(entropy)` puis `__keypair_seed(seed)`;
- `__generate_seed(entropy)` instancie `prng.UhePrng()` (port du UHEPRNG de Gibson) et pour chaque itération `i ∈ [0, entropy)` :
  - lit `os.urandom(1024)`,
  - appelle `generator.add_entropy(rand, str(uuid.getnode()))` ;
- la graine 32 octets issue de `UhePrng.string(32)` sert de seed Ed25519 ;
- `__keypair_seed` construit ensuite la paire `(sk, pk)` via `nacl.signing.SigningKey` et en dérive les formes sérialisées (privée, publique, vérification) stockées dans `users.key.json`.

Avec l’interface TUI `pax_skyproof_tui.sh`, le paramètre `entropy` est demandé explicitement et par défaut à `100`, c’est‑à‑dire 100 itérations de `os.urandom(1024)` injectées dans l’UHEPRNG avant de dériver la clé.

## 2. Chaîne d’attestation PAX ↔ Privateness ↔ Ethereum

On distingue trois couches :

1. **Bedrock EmerNVS/WORM**
   - `(id, pk)` est fixé par `users.key.json` + WORM ;
   - la publication dans EmerNVS impose la finalité PoS+AuxPoW décrite dans le texte *Identity Bedrock*.
2. **PAX / Privateness**
   - le wallet Privateness utilise la même paire Ed25519 pour opérer sur la chaîne Privateness / Skycoin‑type et pour signer les challenges PAX ;
   - `pax_skyproof_tui.sh` fournit les primitives interactives :
     - création de l’identité PAX (`create_pax_identity()` → `keygen.py user username entropy`),
     - génération de self‑spend canoniques via `createRawTransactionV2 --unsign --json` et `signTransaction --json`.
3. **ETH / SIWE**
   - `scripts/PAX-ETH-wizard.html` construit un message SIWE EIP‑4361 dont la *statement* contient:
     `I assert identity: urn:privateness:user:<username>` ;
   - la signature est obtenue côté navigateur via `personal_sign`, puis vérifiée localement avec `ethers.utils.verifyMessage`.

Du point de vue d’une dApp ETH :

- elle voit un SIWE standard (domaine, URI, chainId, nonce, issuedAt, adresse ETH, signature ECDSA) ;
- la seule extension est sémantique : la statement introduit une liaison dure entre l’adresse et `urn:privateness:user:<username>`, donc indirectement `(id, pk)` sur Emer.

## 3. Hyperviseur et rebinding contrôlé

Parce que l’autorité se trouve dans EmerNVS (entrée WORM + clé Ed25519) et **non** dans l’adresse ETH :

- une compromission d’EOA/AA ne détruit pas l’identité PAX ;
- on peut :
  1. révoquer ou ignorer l’adresse compromise dans la couche applicative PAX ;
  2. générer une nouvelle adresse Ethereum ;
  3. rejouer un SIWE avec la même statement `urn:privateness:user:<username>` ;
  4. propager le nouvel appariement dans WORM/WORM+JWT.

La dApp n’a jamais besoin de voir Emer directement :

- elle consomme seulement des SIWE / JWT qui lui présentent :
  - une identité humaine stable (PAX),
  - une adresse ETH rebondable,
  - des métadonnées optionnelles (voir §4).

## 4. Preuves Sky/Privateness et sky_proof

`pax_skyproof_tui.sh` implémente également un flux canonique de self‑spend sur chaîne Privateness :

- sélection du wallet et de l’adresse via `privateness-cli listWallets` et saisie utilisateur ;
- création d’une transaction auto‑dépensante :
  - `createRawTransactionV2 <wallet> <address> <coins> --from-address <address> --unsign --json` ;
  - extraction du hex non signé via `json_extract_hex unsigned` ;
- signature avec `signTransaction <wallet> <unsigned_hex> --json` et archivage de `signed-*.json`.

Ces artefacts peuvent être encapsulés dans une structure `sky_proof` (txid, hex, réseau, politique de self‑spend) référencée dans le WORM de l’utilisateur ou dans un JWT PAX. Ils fournissent une preuve supplémentaire que le même `(id, pk)` contrôle aussi une adresse Sky/Privateness.

## 5. Invariants de sécurité

Sous les hypothèses d’Identity Bedrock :

- la rupture de la chaîne d’attestation PAX impliquerait soit :
  - une attaque sur Ed25519 / UHEPRNG / OS RNG (clé PAX compromise),
  - une réécriture profonde d’EmerNVS (capture de consensus PoS+AuxPoW),
  - ou un détournement applicatif (dApp qui ignore la statement SIWE) ;
- aucune des couches Ethereum (EOA, AA, smart‑wallets, upgrades de protocole) ne peut, à elle seule, invalider l’identité PAX tant que `(id, pk)` et EmerNVS restent intègres ;
- les adresses ETH / Sky / Privateness sont des *bindings rebondables* au‑dessus de cette racine, gérés par PAX comme un hyperviseur d’identité.

En pratique, cela permet d’exposer des identités PAX dans Ethereum via SIWE sans céder la souveraineté au stack ETH : la racine reste EmerNVS + Ed25519, instrumentée par `PrivatenessTools`.
