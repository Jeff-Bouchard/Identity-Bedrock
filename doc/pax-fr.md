PAX : Privateness Auth eXchange
Échapper à l'identité numérique ETH via EmerNVS, WORM, Sky/Privateness et Handshake
Résumé
Ce document propose PAX (Privateness Auth eXchange), un protocole d'authentification cross‑chain qui :

Ancre l'identité dans les clés Privateness et EmerNVS/WORM sur la chaîne Emercoin, avec Ed25519 comme primitive de signature canonique.
Utilise les signatures UTXO de Sky/Privateness comme preuves optionnelles de contrôle on‑chain, en respectant le format de transaction existant (aucun champ de données arbitraire).
Présente à Ethereum et aux autres systèmes basés sur des comptes une abstraction familière « un sujet par clé » via EIP‑4361, de sorte que, du point de vue du dApp, il interagit avec un unique sujet cohérent ressemblant à une personne.
S'intègre à Ethereum uniquement via EIP‑4361 (Sign‑In With Ethereum) de manière à éviter explicitement qu'ETH ne devienne la racine mondiale de « l'identité numérique ».
Expose le système globalement via Handshake DNS (.privateness) et le DNS standard (privateness.link) afin que la résolution et les revendications d'identité soient disponibles sur le clearnet à nos propres conditions, tout en gardant EmerNVS/WORM comme unique racine d'identité.
Les dApps ETH restent inchangés : ils ne voient qu'un compte ETH standard et un message SIWE. Toute la complexité de l'identité cross‑chain, des preuves et de la politique réside entièrement dans la pile Privateness.

Pourquoi PAX est important aujourd'hui

En termes simples, PAX est important parce qu'il sépare **qui vous êtes** de **la chaîne ou du fournisseur que vous utilisez aujourd'hui** :

- Votre véritable identité est la paire de clés Ed25519 ancrée dans EmerNVS/WORM. Les chaînes (Emercoin, Sky/Privateness, Ethereum) et les couches DNS (EmerDNS, Handshake, DNS ICANN) ne sont que des couches de transport et de publication pour des assertions sur cette clé.
- Ethereum et les autres L1 deviennent des **consommateurs d'assertions d'identité**, pas des registres d'identité globaux. Vous pouvez faire pivoter ou abandonner des adresses ETH sans perdre votre identité sous‑jacente.
- Emercoin et Sky/Privateness conservent leurs règles de consensus telles quelles ; PAX s'appuie uniquement sur les primitives existantes (NVS/WORM, transactions Sky standard) au lieu d'exiger des modifications de protocole.
- Pour les dApps ETH, rien de spécial n'est requis : elles voient un flux SIWE normal, mais derrière ce flux se trouve une identité cryptographique ancrée en dehors d'ETH.

Cela permet aux systèmes Small Tech de réutiliser les grandes chaînes lorsqu'elles sont utiles, sans jamais leur céder le contrôle de l'identité.

1. Motivation
Les tendances actuelles en matière d'identité vont vers :

Une identité centrée sur l'adresse (par exemple « vous êtes 0xABC… sur Ethereum »),
Des identités numériques on‑chain (soulbound tokens, ERC‑725, registres),
Souvent un ancrage KYC/AML dans ETH ou d'autres L1 « majeures ».
Pour Privateness.Network, cela est inacceptable :

La véritable identité de l'utilisateur doit être contrôlée au niveau Privateness (clés Ed25519, EmerNVS/WORM), et non par des chaînes externes.
ETH (et les autres chaînes) doivent être des consommateurs d'assertions d'identité — pas des sources de vérité.
L'identité doit être portable et rotatable entre les chaînes sans perdre la souveraineté ni divulguer un identifiant global.
Au niveau protocolaire, la couche d'identité doit pouvoir se présenter aux systèmes basés sur des comptes (tels qu'ETH) comme un sujet unique cohérent – « comme s'il s'agissait d'une vraie personne » – tout en conservant le pouvoir réel d'autorité et de révocation dans EmerNVS/WORM.
L'objectif de PAX est de fournir :

Un pont propre et aligné sur les standards entre les identités Privateness et ETH (et retour), compatible avec SIWE / OAuth2 / OIDC.
Des ancres fortes dans EmerNVS/WORM et éventuellement des UTXO Sky/Privateness.
Une couche globale de nommage et de résolution via Handshake .privateness, avec une accessibilité clearnet via privateness.link et une infrastructure de résolveurs.

2. Composants
2.1 Clés utilisateur Privateness (privatenesstools)
Les utilisateurs Privateness possèdent déjà du matériel de clé défini par privatenesstools :

Stocké dans ~/.privateness-keys/user.key.json
Structure (simplifiée) :
json
{
  "filedata": { "vendor": "Privateness", "type": "key", "for": "user" },
  "username": "alice",
  "private": "<base64 Ed25519 signing key>",
  "public": "<base64 Curve25519 public key>",
  "verify": "<base64 Ed25519 verify key>",
  "nonce": "...",
  "signatures": { ... },
  "worm": "<worm XML>"
}
Matériel de clé :

private → clé de signature Ed25519.
verify → clé de vérification (publique) Ed25519.
public → clé publique Curve25519 pour le chiffrement (box).
Cette clé verify est la clé d'identité Privateness pour Ed25519.

2.2 WORM + EmerNVS (système de nommage Emercoin)
Privateness utilise déjà WORM (XML) embarqué dans EmerNVS :

Nom NVS pour un utilisateur :
text
worm:user:ness:<username>
Valeur : XML :
xml
<worm>
  <user type="ness"
        public="..."
        verify="..."
        nonce="...">
    <signatures>...</signatures>
    <!-- point d'extension : <identity>...</identity> -->
  </user>
</worm>
Il s'agit d'une ancre d'identité on‑chain, adaptée à l'append‑only :

Elle lie un nom d'utilisateur et une clé de vérification Ed25519 à un enregistrement NVS Emercoin.
Elle peut être étendue (par exemple avec des balises <identity> pour les liaisons cross‑chain) sans casser les outils existants.

Point important : ce recours à EmerNVS ne requiert aucun changement des règles de consensus Emercoin. PAX traite NVS comme un registre générique clé–valeur avec des sémantiques de durée de vie et de frais bien définies, et interprète la charge utile WORM hors‑chaîne.

2.3 Chaîne Sky/Privateness
La pièce Privateness est un fork de Skycoin. D'après l'upstream Transaction :

go
type Transaction struct {
    Length    uint32
    Type      uint8
    InnerHash cipher.SHA256

    Sigs []cipher.Sig
    In   []cipher.SHA256
    Out  []TransactionOutput
}

type TransactionOutput struct {
    Address cipher.Address
    Coins   uint64
    Hours   uint64
}
Points importants :

Il n'existe aucun champ OP_RETURN ou de données arbitraires dans le format de transaction.
La seule primitive native de « preuve de contrôle » est la signature d'une transaction portant sur des entrées (In) et des sorties (Out) spécifiques.
Ainsi, PAX ne peut pas embarquer 80 octets arbitraires dans une transaction Sky. Il utilise à la place des schémas de transaction canoniques comme preuves.

Là encore, aucun changement au format de transaction ou à la logique de consensus Sky/Privateness n'est requis. PAX ne fait que contraindre la manière dont les portefeuilles construisent et présentent les transactions comme preuves, en laissant le protocole de base intact.

2.4 Ethereum & SIWE
Pour ETH, PAX suppose l'usage standard de EIP‑4361 Sign‑In With Ethereum :

Le dApp choisit un domaine, un uri, un nonce, etc.
L'utilisateur signe le message SIWE avec une clé privée ETH.
Le dApp vérifie EIP‑4361 en utilisant les bibliothèques existantes.
PAX traite SIWE comme une liaison optionnelle entre une identité Privateness et une ou plusieurs adresses ETH, sans qu'ETH ne devienne jamais la racine.

2.5 Handshake & .privateness + privateness.link
Pour exposer ce système au monde « selon nos propres conditions », sans introduire une nouvelle racine de confiance :

Handshake : acquérir et exploiter le TLD .privateness dans Handshake. Dans cette conception, Handshake est choisi principalement pour des raisons pragmatiques (des registrars comme Porkbun fournissent déjà un DNS et une UX passerelle compatibles Handshake) ; tout mécanisme de nommage ou de pont équivalent pourrait être substitué sans changer le modèle de confiance PAX ni la racine d'identité.
Chaque identité peut utiliser un label du type alice.privateness.
Les enregistrements DNS (A/AAAA/TXT/SRV) peuvent embarquer :
Métadonnées d'émetteur PAX,
Identifiants EmerNVS (par ex. nvs=worm:user:ness:alice),
Correspondances ETH (eth=0x...).
Passerelle clearnet :
privateness.link (DNS normal) et id.privateness.link hébergent :
L'API HTTP PAX.
Des dApps Web.
Des résolveurs qui font correspondre les noms Handshake .privateness aux enregistrements EmerNVS/WORM et aux endpoints PAX.
Avec le support de Handshake par Porkbun, la résolution de .privateness peut être rendue accessible aux navigateurs classiques via leurs serveurs de noms ou une UX de passerelle.

3. Modèle d'identité
3.1 Identifiant canonique d'identité
Nous définissons l'identité canonique comme un URN :

text
id = "urn:privateness:user:" + <username>
Exemple :

text
urn:privateness:user:alice
Ce qui donne :

Représentation locale : user.key.json pour alice.
Représentation NVS : worm:user:ness:alice → <user> WORM avec verify.
L'URN n'est jamais on‑chain ; c'est un identifiant canonique interne utilisé par tous les composants.

3.2 Alias optionnels
Handshake : alice.privateness → TXT contenant :
text
nvs=worm:user:ness:alice
pax_issuer=https://id.privateness.link:54443
Clearnet : alice.privateness.link → éventuellement CNAME ou TXT reflétant les mêmes données nvs=/pax_issuer.

4. Protocole PAX
4.1 Acteurs
Portefeuille Privateness
Gère user.key.json.
Communique avec EmerNVS (via Emercoin).
Communique avec un nœud Sky/Privateness (via privateness-cli ou RPC).
Gère/communique éventuellement avec un signataire ETH.
Communique avec l'API HTTP du pont PAX (locale ou distante).
Pont / Vérificateur PAX (id.privateness.link:54443)
Émet des challenges.
Vérifie les signatures Ed25519.
Vérifie éventuellement les preuves de transaction Sky.
Vérifie SIWE lorsque demandé.
Émet des jetons PAX (JWT/CWT) pour la consommation interne.
dApps ETH
Utilisent uniquement SIWE / EIP‑4361 standard.
N'ont pas besoin de connaître PAX ou EmerNVS.

4.2 Challenge PAX
Le pont émet un challenge JSON :

json
{
  "id": "urn:privateness:user:alice",
  "session_id": "3e5f1a0b2c9043ef9bba5030d43a7d12",
  "nonce": "b94626b8ee4c4a88a295948ab2c9fa10",
  "issued_at": "2025-11-17T23:05:00Z",
  "expires_at": "2025-11-17T23:10:00Z",
  "purpose": "login"
}
Ce challenge :

Est canonisé avec JCS avant signature (challenge_bytes = JCS(challenge_json)).
Est stocké côté serveur avec un challenge_id aléatoire.

4.3 PAX‑SIGN : réponse Ed25519
Le Portefeuille Privateness :

Charge user.key.json pour alice.
Décodage de private (clé secrète Ed25519).
Signe :
text
sig = Ed25519_Sign(private, challenge_bytes)
Envoie cet objet au pont :

json
{
  "challenge_id": "chg_01HRFQ9H3T0ZQDJEXAMPLE",
  "username": "alice",
  "pax_sign": {
    "challenge": {
      "id": "urn:privateness:user:alice",
      "session_id": "...",
      "nonce": "...",
      "issued_at": "2025-11-17T23:05:00Z",
      "expires_at": "2025-11-17T23:10:00Z",
      "purpose": "login"
    },
    "signature": "base64url(ed25519_sig_bytes)"
  }
}
Aucune interaction avec la chaîne Sky/Privateness n'est nécessaire pour cette étape ; elle n'utilise que user.key.json et EmerNVS pour la vérification.

4.4 PAX‑TX optionnel : preuve de self‑spend Sky
Si l'on souhaite également une preuve de contrôle UTXO Sky, le portefeuille :

Choisit une adresse de portefeuille A possédant des coins.
Exécute :
bash
./privateness-cli createRawTransactionV2 mywallet.wlt <A> 1 \
    --from-address <A> \
    --unsign \
    --json
Extrait l'hex de transaction non signée du JSON.
La signe :
bash
./privateness-cli signTransaction mywallet.wlt <raw_unsigned_hex> --json
L'hex de transaction signée tx_hex est envoyé comme :

json
"sky_proof": {
  "tx_hex": "<signed_tx_hex>",
  "network": "privateness-mainnet"
}
Le pont peut alors décoder et vérifier cette transaction en utilisant les règles de consensus Skycoin.

4.5 SIWE optionnel : liaison ETH
Pour les sessions qui nécessitent également ETH :

Le portefeuille expose le compte ETH 0xABC... (interne ou externe).
Le dApp envoie un message SIWE EIP‑4361 :
text
dapp.example wants you to sign in with your Ethereum account:
0xABC...

I assert identity: urn:privateness:user:alice

URI: https://dapp.example/login
Version: 1
Chain ID: 1
Nonce: <random>
Issued At: <ISO8601>
Le portefeuille le signe ; le résultat est inclus dans la complétion PAX :
json
"siwe": {
  "message": "raw SIWE message",
  "signature": "0x...eth_signature"
}

5. Logique de vérification PAX
Sur /v1/pax/complete :

5.1 Vérifier le binding du challenge
Récupérer le challenge stocké par challenge_id.
Confirmer que pax_sign.challenge est égal au challenge stocké.
Vérifier que expires_at n'est pas dépassé ; que session_id correspond ; et éventuellement un nonce client, etc.

5.2 Vérifier l'identité via WORM + Ed25519
À partir de username et pax_sign.challenge.id :
Exiger pax_sign.challenge.id == "urn:privateness:user:" + username.
Interroger EmerNVS :
name_show "worm:user:ness:" + username → <user verify="..."> WORM.
Décoder verify (base64) → auth_pub (clé publique Ed25519).
Canoniser pax_sign.challenge via JCS → challenge_bytes.
Vérifier :
text
Ed25519_Verify(auth_pub, challenge_bytes, sig)
Si la vérification est valide, l'identité est authentifiée comme urn:privateness:user:alice.

5.3 Vérifier éventuellement la preuve Sky
Si sky_proof.tx_hex est fourni :

Décoder la transaction en utilisant le parseur de transactions Skycoin (ou decodeRawTransaction).
Vérifier les signatures avec les règles Sky standard.
Vérifier que la transaction est un self‑spend canonique sous une politique fixée :
Au moins une sortie vers une adresse contrôlée par ce portefeuille (si connue via <identity> WORM).
Pas d'adresses tierces, ou seulement selon la politique.
Si valide, on sait que le même utilisateur (ou système) contrôle ces UTXO.

5.4 Vérifier éventuellement SIWE
Si siwe est présent (et requis) :

Analyser le message SIWE.
Récupérer l'adresse ETH à partir de la signature.
Vérifier :
address correspond à l'adresse récupérée.
domain correspond au domaine attendu du dApp.
nonce correspond à une valeur que vous avez émise.
Lier éventuellement cette adresse ETH à l'identité Privateness dans <identity> WORM pour la persistance.

6. Jetons PAX
En cas de succès, le pont peut émettre un jeton PAX (JWT/CWT) :

6.1 Exemple de payload JWT
json
{
  "iss": "https://id.privateness.link:54443",
  "sub": "urn:privateness:user:alice",
  "aud": "dapp.example",
  "iat": 1731884700,
  "exp": 1731888300,

  "nvs": {
    "user": "worm:user:ness:alice"
  },

  "eth": {
    "addr": "0xABCDEF1234567890...",
    "chainId": 1
  },

  "sky": {
    "addresses": ["<sky_addr>"],
    "proof_txid": "optional-txid"
  }
}
Signé avec Ed25519 (JWS alg : "EdDSA"), avec les clés publiques publiées à :

text
https://id.privateness.link:54443/v1/pax/jwks
Les dApps ETH n'ont pas besoin de ce JWT si elles dépendent uniquement de SIWE. Le JWT est utile pour :

Les services Privateness,
Les applications cross‑chain,
Ou des vérificateurs externes qui souhaitent consommer directement des identités Privateness.

7. Intégration Handshake .privateness
7.1 Conception du TLD
Acquérir le TLD .privateness dans Handshake.
L'autorité DNS pour .privateness est sous votre contrôle.
Pour chaque utilisateur alice :

Définir alice.privateness dans le DNS Handshake avec des enregistrements TXT :
text
nvs=worm:user:ness:alice
pax_issuer=https://id.privateness.link:54443
eth_addr=0xABCDEF1234567890...
Cela permet :

Aux résolveurs compatibles Handshake de découvrir l'ancre d'identité EmerNVS (worm:user:ness:alice) et l'endpoint de l'émetteur PAX.
Optionnellement, les adresses ETH ou d'autres liaisons de chaînes.

7.2 Passerelle clearnet via privateness.link
Pour exposer .privateness aux clients DNS « normaux » :

Utiliser privateness.link comme domaine de pont.
Pour chaque identité, définir par exemple :
alice.privateness.link → TXT avec les mêmes métadonnées :
text
nvs=worm:user:ness:alice
pax_issuer=https://id.privateness.link:54443
eth_addr=0xABCDEF1234567890...
Exposer éventuellement un profil web sur https://alice.privateness.link qui :
Affiche les informations d'identité résolues depuis EmerNVS.
Pointe vers les endpoints PAX / OIDC.
Porkbun (en tant que registrar supportant Handshake) peut être utilisé pour :

Héberger la zone .privateness ou la relayer dans le DNS classique.
Offrir des endpoints qui résolvent les TLD .privateness pour les utilisateurs sans résolveur compatible Handshake.

7.3 Avantages de gouvernance
En utilisant .privateness sur Handshake plus privateness.link sur le DNS « legacy » :

La résolution est ancrée dans votre infrastructure et EmerNVS, et non dans l'ICANN ou ETH.
Vous pouvez définir comment les noms se résolvent et quelles données d'identité sont exposées.
Vous pouvez modifier ou supprimer les liaisons ETH sans casser l'identité Privateness sous‑jacente.

8. Propriétés de sécurité et de confidentialité
Racine d'identité : clé de vérification Ed25519 + WORM/EmerNVS (worm:user:ness:username).
Preuves de chaîne :
Sky/Privateness : transaction self‑spend canonique (optionnelle).
EmerNVS : l'enregistrement WORM garantit une sémantique d'append‑only et une piste d'audit on‑chain.
ETH n'est pas la racine :
Les comptes ETH sont des liaisons vers les identités Privateness via SIWE.
PAX peut faire pivoter ou abandonner des adresses ETH sans perdre l'identité.
Aucun OP_RETURN Sky :
La conception respecte le format de transaction Sky réel (aucun champ de données arbitraires).
Utilise les primitives de signature de transaction existantes comme preuve de contrôle.
Écritures on‑chain minimales :
EmerNVS : les entrées WORM changent rarement (mises à jour d'identité).
Sky : transactions de preuve ou d'enregistrement optionnelles, pas à chaque login.
Logins quotidiens : Ed25519 hors‑chaîne + SIWE uniquement.
Compatibilité :
Les dApps ETH ne voient que SIWE ; aucun changement de protocole requis.
Les jetons PAX/JWKS peuvent être consommés par une infrastructure OAuth2/OIDC standard.
Handshake .privateness et privateness.link exposent les identités et les endpoints PAX via un DNS pur.

9. Travaux futurs
Schéma formel <identity> WORM :
Définir un sous‑arbre XML standard sous <user> pour les liaisons de chaînes.
Standardisation des preuves Sky :
Règles de canonisation strictes pour la transaction self‑spend (par ex. sélection déterministe des UTXO, politique sur coins/hours).
Racines multiples :
Supporter des racines d'identité non seulement par nom d'utilisateur mais aussi par des URN spécifiques à une chaîne :
urn:privateness:sky:<sky_addr>
urn:privateness:emc:<emc_addr>
Stratégie multi‑résolveur :
Plusieurs endpoints d'émetteurs PAX et ensembles JWKS, ancrés via EmerNVS et Handshake.
Extensions de confidentialité :
Utilisation de preuves à divulgation nulle de connaissance ou de divulgation sélective au‑dessus des jetons PAX pour les applications stateful.
Cette proposition montre comment Privateness.Network peut projeter ses identités dans ETH et sur l'Internet au sens large tout en maintenant EmerNVS/WORM comme racine souveraine de l'identité, Handshake .privateness et privateness.link n'agissant que comme couches de nommage et de découverte. Ethereum et des systèmes similaires voient un sujet familier ressemblant à une personne via SIWE et les flux associés, mais l'autorité réelle reste dans les clés Ed25519 ancrées dans EmerNVS, ce qui évite les régimes d'identité numérique centrés sur ETH et préserve la liberté de l'utilisateur.

Retour d'expérience
