## Identity Bedrock : opérationnaliser le substrat cryptographique minimal de Rompel pour l’identité souveraine

**Auteurs :** [Jeff Bouchard], Équipe Emercoin, Équipe Privateness Network

**Structure :**

**Fondement théorique :** Rompel (1990) a démontré que les fonctions à sens unique (OWF) sont nécessaires et suffisantes pour construire des schémas de signature numériques. Nous opérationnalisons ce résultat comme plancher irréductible pour l’authentification publique.

**Conception :** Identity Bedrock sépare la cryptographie d’identité (Ed25519) du consensus de l’annuaire (agnostique vis‑à‑vis de la chaîne). Tout registre append‑only avec une finalité quantifiable peut héberger les liaisons d’identité.

**Implémentation :** Déployé sur Emercoin NVS (preuve d’enjeu hybride + AuxPoW Bitcoin), avec une infrastructure NESS Fiber. Le coût d’attaque hérite du choix d’annuaire ; pour un ancrage Bitcoin nous estimons un coût d’attaque de l’ordre de 5–20 milliards de dollars [5].

**Propriété clé :** La conception vise à éviter les clés institutionnelles situées sous l’individu. La conception agnostique vis‑à‑vis de la chaîne permet la portabilité de l’annuaire tout en maintenant une sécurité fondée sur les OWF sous des hypothèses standards.

**Contribution :** Nous proposons un système d’identité pratique explicitement fondé sur le théorème de Rompel, avec des coûts d’attaque quantifiés et une vérification déployée.

## 1. Introduction

### 1.1 Le problème : la capture institutionnelle

**Contenu :**

*   Chaque système d’identité numérique place des institutions sous les utilisateurs : AC, IdP, registres, plates‑formes
*   Ces acteurs créent des points de capture – entités pouvant révoquer, refuser ou contrôler l’identité
*   Modèle d’attaquant : adversaire disposant de ressources illimitées, d’un soutien politique et d’un contrôle complet sur l’infrastructure d’identité traditionnelle
*   **Question :** une identité peut‑elle exister sans clés institutionnelles sous l’individu ?

### 1.2 La réponse théorique : Rompel 1990

**Contenu :**

*   Rompel a prouvé : OWF ⟺ signatures EUF‑CMA (nécessaire ET suffisant)
*   C’est le minimum démontré – rien de strictement plus faible ne permet l’authentification publique
*   **Thèse :** si l’on fixe l’OWF comme plancher et que l’on ajoute uniquement un annuaire append‑only, on obtient une construction d’identité qui minimise les points de capture institutionnels.

### 1.3 Contributions

**Trois facettes :**

**Facette 1 – Théorie :**

*   Formalisation d’une identité basée sur Rompel avec une conception agnostique vis‑à‑vis de la chaîne
*   Esquisse de preuve : retirer l’OWF fait s’effondrer l’authentification ; affaiblir l’annuaire revient seulement à échanger un consensus contre un autre
*   Modèle de sécurité avec des coûts d’attaque quantifiés

**Facette 2 – Systèmes :**

*   Architecture : couche d’identité Ed25519 + substrat d’annuaire enfichable
*   Implémentation : Emercoin NVS (ancré à Bitcoin) + NESS Fiber (conçu pour résister à 99 % de nœuds hostiles dans notre modèle)
*   Agnostique vis‑à‑vis de la chaîne : la même identité est portable entre annuaires

**Facette 3 – Application :**

*   Système déployé, opérationnel depuis 2013 (Emercoin), avec vérification publique
*   Coût d’attaque : 5–20 Mds $ (hérité de Bitcoin via AuxPoW)
*   Modèle de menace : résistance à la capture institutionnelle par conception

**Pourquoi un seul article :**

*   La théorie justifie la conception (plancher de Rompel)
*   Les systèmes implémentent la théorie (architecture agnostique)
*   L’application démontre le fonctionnement (déploiement, coûts quantifiés)
*   Les trois facettes sont inséparables : chacune a besoin des autres

## 2. Contexte et travaux connexes

### 2.1 Le théorème de Rompel (1990)

**Contenu :**

*   Énoncé formel : les OWF existent ⟺ il existe des schémas de signature EUF‑CMA
*   Esquisse de preuve (citer l’article original)
*   Implication : l’OWF est le minimum irréductible pour l’authentification publique
*   **Lacune dans la littérature :** à notre connaissance, peu de travaux utilisent explicitement ce résultat comme fondement de systèmes d’identité.

D’un point de vue théorie de la complexité, les fonctions à sens unique (OWF), les fonctions de hachage à sens unique universelles (UOWHF) et les schémas de signature existentiellement infalsifiables sous attaque par messages choisis de manière adaptative (EUF‑CMA) sont équivalents en puissance. Naor et Yung montrent comment construire des signatures EUF‑CMA à partir de UOWHF. Rompel [1] puis Haitner et al. [7] montrent comment construire des UOWHF à partir de n’importe quelle OWF, en utilisant la notion d’entropie inaccessible. Une exposition moderne, auto‑contenue et accompagnée d’une preuve complète de la construction de Rompel (à partir d’OWF arbitraires vers des UOWHF puis des signatures) est fournie par l’ePrint « Rompel Revisited » [9], que nous utilisons comme référence technique canonique pour cette équivalence. Il est également standard (voir par exemple Goldreich, _Foundations of Cryptography_) que tout schéma de signature EUF‑CMA implique l’existence d’une fonction à sens unique. En combinant ces implications, on obtient l’équivalence :  
\[  
\mathrm{OWF} \Leftrightarrow \mathrm{SIG}\_{\mathrm{EUF\mbox{-}CMA}}  
\]  
au sens des définitions usuelles, et nous nous appuyons sur [1,7,9] pour les constructions et preuves sous‑jacentes.

### 2.2 Systèmes d’identité basés sur la blockchain

**Contenu :**

**Namecoin / EmerDNS :**

*   Stockage nom‑valeur sur blockchain
*   **Lacune :** les clés d’identité sont liées aux clés de portefeuille de la blockchain (non agnostique)
*   Les mineurs agissent comme une autorité de certification implicite

**W3C DIDs / basés sur Ethereum :**

*   Méthodes DID, contrats intelligents, ENS
*   **Lacune :** clés de gouvernance DAO, administrateurs de registre, dépendances à des fournisseurs (Infura)
*   Ajoute souvent des clés institutionnelles au‑dessus ou en dessous de l’utilisateur

**Sovrin / Hyperledger Indy :**

*   Validateurs permissionnés, schémas de crédentiels
*   **Lacune :** les clés des « stewards » contrôlent le réseau, pas un plancher pur d’OWF

**Différence d’Identity Bedrock :**

*   Plancher pur d’OWF (Rompel)
*   Agnostique vis‑à‑vis de la chaîne (identité ≠ annuaire)
*   Vise à éviter des clés institutionnelles sous l’utilisateur

### 2.3 AuxPoW Bitcoin et minage fusionné

**Contenu :**

*   Mécanisme d’Auxiliary Proof‑of‑Work
*   Emercoin comme exemple : 85 % PoS + 15 % AuxPoW Bitcoin
*   Héritage de sécurité : attaquer l’annuaire nécessite d’attaquer Bitcoin
*   **Usage nouveau (à notre connaissance) :** application non monétaire (identité) héritant du coût d’attaque estimé de Bitcoin (5–20 Mds $) [5]

### 2.4 Consensus Skycoin Fiber

**Contenu :**

*   Clés d’éditeur de blocs annoncées (et non consensus économique)
*   99 % de nœuds hostiles sans effet (impossibilité de forger sans les clés)
*   Stockage append‑only (BoltDB)
*   **Propriété :** infrastructure présentant une forte résistance aux attaques par majorité de nœuds, sous le modèle considéré

## 3. Modèle de menace et exigences

### 3.1 Capacités de l’adversaire

**Hypothèses :**

*   Ressources conventionnelles pratiquement illimitées
*   Soutien politique pour la législation et la coercition
*   Contrôle complet de l’infrastructure d’identité traditionnelle (AC, IdP, KYC)
*   Peut interdire des logiciels, saisir des biens, compromettre des individus

**Non supposé :**

*   Ne peut pas casser les OWF (barrière de complexité calculatoire)
*   Ne peut pas attaquer les mécanismes de consensus à grande échelle (économiquement irrationnel si le coût est quantifié)
*   Ne peut pas compromettre l’infrastructure distribuée globalement et simultanément

### 3.2 Exigences de conception

**R1 : irréductibilité mathématique**

*   Doit utiliser un OWF comme plancher (Rompel)
*   Ne peut pas ajouter de primitive strictement plus faible en dessous

**R2 : absence de clés institutionnelles**

*   La clé de l’individu est l’unique racine de confiance
*   Aucune clé d’AC, d’IdP ou de registre sous l’utilisateur

**R3 : agnosticisme vis‑à‑vis de la chaîne**

*   Cryptographie d’identité indépendante du consensus d’annuaire
*   Portabilité entre différents substrats append‑only

**R4 : sécurité quantifiable**

*   Les coûts d’attaque doivent être explicites et mesurables
*   Pas de discours vague sur la « décentralisation »

**R5 : vérification opérationnelle**

*   Système déployé, pas purement théorique
*   Vérification publique des revendications

## 4. Architecture d’Identity Bedrock

### 4.1 Conception à deux couches

**Couche 1 : cryptographie d’identité (agnostique vis‑à‑vis de la chaîne)**

```plaintext
Seed (1536 bits UHEPRNG)
  → Ed25519 KeyGen
  → (sk, pk)

Identity = (id, pk)
Authentication = Sign_Ed25519(sk, challenge)
```

**Propriétés :**

*   Sécurité équivalente aux OWF (Rompel)
*   Indépendante de toute blockchain
*   Portable entre annuaires

**Couche 2 : substrat d’annuaire (enfichable)**

```plaintext
Directory D ⊆ ID × PK
Bind(id, pk) = 1 ⟺ (id, pk) ∈ D

Requirements:
- Append-only
- Globally verifiable
- Quantifiable finality
```

**Séparation :**

*   L’identité utilise Ed25519
*   L’annuaire utilise n’importe quel consensus (PoW, PoS, AuxPoW, Fiber, etc.)
*   **Pas de couplage :** la même identité peut migrer d’un annuaire à l’autre

### 4.2 Protocole d’authentification

**Mise en place :**

```plaintext
1. L’utilisateur génère (sk, pk) à partir d’une graine UHEPRNG
2. L’utilisateur publie (id, pk) dans l’annuaire D
3. Attente de la finalité (dépendant de l’annuaire)
4. La liaison est maintenant globale : Bind(id, pk) = 1
```

**Challenge‑réponse :**

```plaintext
Verifier V knows: id
Prover P holds: sk

1. V → P : challenge c (nonce aléatoire)
2. P → V : σ = Sign_Ed25519(sk, c)
3. V vérifie :
   a. Récupérer pk tel que Bind(id, pk) = 1 dans D
   b. Vérifier Verify_Ed25519(pk, c, σ) = 1
   c. Accepter si et seulement si les deux conditions sont vraies
```

**Propriétés clés :**

*   Aucun état dans l’annuaire au‑delà de la liaison (id, pk)
*   Aucun contrat intelligent ni logique conditionnelle
*   Purement mathématique : la signature est valide ou non

### 4.3 Esquisse de preuve de sécurité

**Théorème :** si Ed25519 est EUF‑CMA sûr et si D est append‑only avec finalité, alors Identity Bedrock fournit une authentification infalsifiable.

**Preuve (esquisse) :**

1.  Supposons qu’un adversaire A réussisse : il produit un triplet valide (id\*, c\*, σ\*) sans posséder sk.
2.  Par le protocole, V vérifie que Bind(id\*, pk\*) = 1 dans D.
3.  V vérifie que Verify(pk\*, c\*, σ\*) = 1.
4.  Or c\* n’a jamais été signé par le porteur légitime de sk → cela viole l’hypothèse EUF‑CMA.
5.  Contradiction → Pr\[A réussit\] ≤ negl(λ).

**Attaques sur l’annuaire :**

*   Réécrire D pour changer pk nécessite une attaque spécifique à l’annuaire
*   Le coût dépend du choix d’annuaire (quantifié séparément)
*   Cela n’affecte pas la preuve d’authentification elle‑même

### 4.4 Propriété d’agnosticisme vis‑à‑vis de la chaîne

**La même identité (sk, pk) peut être publiée, à titre d’exemples, dans :**

*   Emercoin NVS (ancré à Bitcoin via AuxPoW)
*   Bitcoin OP_RETURN + preuves de Merkle
*   Stockage de contrats intelligents Ethereum (par ex. un contrat Solidity qui enregistre (id, pk))
*   IPFS + estampillage blockchain
*   Tout registre append‑only

**Compromis :**

*   La sécurité hérite du choix d’annuaire
*   AuxPoW Bitcoin : coût d’attaque de 5–20 Mds $
*   Chaînes plus petites : coût d’attaque plus faible
*   L’utilisateur choisit en fonction de son modèle de menace

**Portabilité :**

*   Export : signer une déclaration de migration avec sk
*   Publier dans un nouvel annuaire D'
*   Les vérificateurs acceptent la nouvelle liaison après finalité
*   L’ancien annuaire reste un enregistrement historique

## 5. Implémentation : Emercoin + NESS

### 5.1 Annuaire : Emercoin NVS

**Consensus :**

*   85 % preuve d’enjeu + 15 % AuxPoW Bitcoin (maintenu artificiellement)
*   Finalité : 1 confirmation (enregistrements d’identité), 6 confirmations (monétaire)

**Format de stockage (WORM) :**

```plaintext
{
  "id": "unique_identifier",
  "pk": "ed25519_public_key_base64",
  "created": "timestamp",
  "expires": "optional"
}
```

Ce format suit le schéma JSON défini par le projet open source WORM [8], qui fournit un conteneur simple et bien spécifié pour des enregistrements append‑only.

**Contrôle :**

*   Les clés de portefeuille Emercoin contrôlent les mises à jour des enregistrements NVS
*   Les clés d’identité Ed25519 authentifient l’identité elle‑même
*   **Séparation des préoccupations :** contrôle de l’annuaire ≠ authentification de l’identité

**Coût d’attaque :**

*   Réécrire le NVS nécessite : majorité de mise sous enjeu EMC + attaque 51 % sur Bitcoin
*   Composante Bitcoin : de l’ordre de 5–20 Mds $ (Coin Metrics 2024)
*   **Hérite de la sécurité de Bitcoin pour l’application identité dans ce modèle de déploiement**

### 5.2 Infrastructure : NESS Fiber

**Consensus :**

*   Fiber de type Skycoin (clés d’éditeur annoncées)
*   Clés publiées dans Emercoin NVS (par ex. `dpo/PrivateNESS.Network`)
*   Validation : les blocs DOIVENT être signés par les clés annoncées

**Propriété « 99 % de nœuds hostiles » (dans notre modèle) :**

*   Impossible de forger des blocs sans les clés d’éditeur
*   Les attaquants peuvent seulement retarder la propagation (DoS)
*   Impossible de réécrire l’historique (BoltDB append‑only)

**Compromission de clé :**

*   Voler une clé d’éditeur permet seulement de revenir au bloc genesis (attaque maximálně détectable)
*   Impossible de réécrire les blocs passés
*   Nouvelles clés annoncées dans Emercoin NVS (coordination ancrée à Bitcoin)

Dans notre déploiement, NESS Fiber constitue un exemple de couche d’infrastructure consommant Identity Bedrock. Tout autre système offrant des propriétés comparables (clés d’éditeur annoncées, append‑only) pourrait jouer un rôle similaire sans modifier la couche bedrock elle‑même.

### 5.3 Preuve canonique de self‑spend (interop type Skycoin)

**Problème :** lier des adresses secp256k1 Skycoin à une identité Ed25519

**Solution :**

```plaintext
1. Créer une transaction non signée : A → A (self-spend)
2. Signer avec la clé privée secp256k1
3. Créer une preuve : {network, address, policy, txid, tx_hex}
4. Ancrer la preuve dans un enregistrement WORM Emercoin NVS
5. L’enregistrement WORM est contrôlé par la clé bedrock Ed25519
```

**Résultat :** différentes chaînes interopèrent, Ed25519 reste l’autorité ultime

### 5.4 Génération de clés et approvisionnement en entropie

Dans notre implémentation, les clés Ed25519 sont dérivées d’une graine produite par le générateur pseudo‑aléatoire à entropie ultra‑élevée (UHEPRNG) de Gibson [3], lui‑même alimenté par l’aléa du système d’exploitation. Concrètement, le code de génération lit plusieurs blocs de 1024 octets depuis `os.urandom` et les mélange dans une instance d’UHEPRNG avant d’extraire une graine de 32 octets (256 bits) pour Ed25519. La quantité totale d’aléa en entrée est de l’ordre de 1536 bits ou plus, mais la graine résultante est par construction de 256 bits.

Les noyaux Linux modernes plafonnent en interne l’entropie de leur générateur déterministe à environ 256 bits. Notre usage d’UHEPRNG et de multiples lectures `os.urandom` n’a donc pas pour vocation de dépasser ce plafond théorique, mais d’augmenter la robustesse : il réduit la sensibilité aux biais du RNG, aux défauts d’implémentation et aux fuites partielles d’entropie. La sécurité des clés résultantes reste fondée sur les hypothèses standards pour Ed25519 (environ 128 bits de sécurité classique), mais nous veillons à rendre la graine aussi proche que possible d’une distribution uniforme dans l’espace des 256 bits exposé au schéma de signature.

## 6. Évaluation

### 6.1 Analyse des coûts d’attaque

**Objectif :** compromettre la liaison d’identité (id, pk)

| Vecteur d’attaque | Prérequis | Coût | Résultat |
| --- | --- | --- | --- |
| Casser Ed25519 | Violer une OWF | Infeasible sous les hypothèses standards (Rompel) | L’authentification s’effondre |
| Réécrire Emercoin NVS | Mise sous enjeu EMC + 51 % Bitcoin | 5–20 Mds $ (estimation Coin Metrics [5]) | Réécriture de l’annuaire |
| Compromettre NESS | Voler les clés d’éditeur | Élevé, mais DoS seulement | Impossible de modifier les liaisons d’identité (dans Emercoin) |
| Capturer 99 % des nœuds | Contrôle physique | Forte coordination | Impact nul (impossibilité de forger) |
| Interdiction légale | Coût politique | Variable | Impossible de compromettre la crypto |

**Attaque minimale réussie :** casser Ed25519 OU réécrire l’annuaire  
**Plancher pratique (ordre de grandeur) :** 5–20 Mds $ (composante Bitcoin)

### 6.2 Comparaison avec d’autres systèmes

| Système | Plancher d’identité | Annuaire | Coût d’attaque | Clés institutionnelles ? | Agnostique vis‑à‑vis de la chaîne ? |
| --- | --- | --- | --- | --- | --- |
| **Identity Bedrock** | Ed25519 (OWF/Rompel) | Enfichable | Hérite de l’annuaire | NON | OUI |
| X.509 PKI | RSA/ECDSA | Hiérarchie d’AC | Compromettre une AC | OUI (racines AC) | NON |
| Namecoin | ECDSA | PoW Namecoin | ≈ 1–10 M$ | Implicite (mineurs) | NON |
| DID Ethereum | Variable | Ethereum L2 | Réorg ETH + DAO | OUI (clés DAO) | NON |
| Sovrin | Ed25519 | Permissionné | Faire confiance aux stewards | OUI (clés des stewards) | NON |

**Propriétés distinctives (telles qu’argumentées ici) :**

*   Usage explicite du résultat d’équivalence OWF–signature de Rompel comme plancher de conception
*   Couche d’identité agnostique vis‑à‑vis de la chaîne, découplée de tout annuaire spécifique
*   Déploiements d’identité héritant de la sécurité estimée de Bitcoin pour un usage non monétaire via AuxPoW
*   Objectif de conception : éviter des clés institutionnelles sous l’utilisateur

### 6.3 Mesures de performance

**Finalité :**

*   Emercoin NVS : 1 confirmation (~2 minutes)
*   Vérification : requête NVS + vérification Ed25519 (~millisecondes)

**Scalabilité :**

*   Débit NVS : [TPS mesuré]
*   Challenge‑réponse : aucune transaction on‑chain requise (sans état)
*   Portable : la même identité fonctionne sur n’importe quel annuaire

## 7. Discussion

### 7.1 Limitations

**Hors du champ :**

*   Compromission de clé par malware ou vol physique (vulnérable dans tout système)
*   Attaques d’interface (UI), phishing (orthogonal à la sécurité cryptographique)
*   Calcul quantique (Ed25519 vulnérable à Shor, migration post‑quantique prévue)

**Légal / social :**

*   Peut interdire des logiciels (mais ne peut pas compromettre les identités déployées)
*   Peut contraindre des individus (mais ne peut pas capturer le protocole lui‑même)
*   Peut créer du risque juridique (mais ne peut pas réécrire les fondations mathématiques)

### 7.2 Compromis liés à l’agnosticisme vis‑à‑vis de la chaîne

**Choix d’annuaire :**

*   Haute sécurité (ancré à Bitcoin) : coût plus élevé, finalité plus lente
*   Sécurité plus faible (chaînes plus petites) : moins cher, plus rapide, coût d’attaque plus bas
*   Les utilisateurs choisissent en fonction de leur modèle de menace

**Migration :**

*   Identité portable entre annuaires
*   Migration signée avec la clé Ed25519 (prouve la légitimité)
*   L’ancien annuaire reste un enregistrement historique

### 7.3 Travaux futurs

**Post‑quantique :**

*   Standards PQC du NIST (CRYSTALS‑Dilithium, SPHINCS+)
*   Chemin de migration : signer la transition avec Ed25519, publier une clé PQ
*   Maintient la propriété d’agnosticisme vis‑à‑vis de la chaîne

**Signatures seuil :**

*   k‑sur‑n clés Ed25519 pour le contrôle d’identité
*   Récupération sociale sans séquestre institutionnel

**Autres annuaires :**

*   Démontrer la portabilité : publier la même identité sur Bitcoin, Ethereum
*   Mesurer les différences de coûts d’attaque
*   Études utilisateurs : choix d’annuaire en fonction du modèle de menace

Ces annuaires supplémentaires sont des consommateurs optionnels de l’identité bedrock. Ils ne remplacent ni la clé Ed25519 ni l’annuaire primaire choisi comme racine de l’identité.

## 8. Travaux connexes

### 8.1 Fondements théoriques

**Rompel (1990) :** OWF ⟺ signatures

*   Nous l’opérationnalisons comme système d’identité pratique

**Goldreich (Foundations of Cryptography) :** sécurité EUF‑CMA

*   Nous l’utilisons comme définition de l’authentification

### 8.2 Identité sur blockchain

**Namecoin, EmerDNS :** stockage nom‑valeur

*   Nous séparons la crypto d’identité de la crypto de la blockchain (agnostique)

**W3C DIDs :** identifiants décentralisés

*   Nous fournissons un substrat minimal sur lequel les DID peuvent se construire

**Sovrin, Indy :** écosystèmes de crédentiels

*   Nous fournissons une couche de bedrock sans clés institutionnelles

### 8.3 Mécanismes de consensus

**Bitcoin AuxPoW :** minage fusionné

*   Nous l’appliquons à un usage non monétaire (annuaire d’identité)

**Skycoin Fiber :** éditeur annoncé

*   Nous l’exploitons comme infrastructure restant fonctionnelle sous de fortes proportions de nœuds hostiles dans notre modèle

## 9. Conclusion

**Résumé :**

**Théorie :** Rompel a prouvé que les OWF sont nécessaires et suffisantes. Nous opérationnalisons ce résultat sous la forme d’une conception d’identité agnostique vis‑à‑vis de la chaîne qui vise à éviter des clés institutionnelles sous l’individu.

**Systèmes :** couche d’identité Ed25519 + substrat d’annuaire enfichable. Déployé sur Emercoin (ancré à Bitcoin) + NESS Fiber (conçu pour tolérer jusqu’à 99 % de nœuds hostiles dans notre modèle).

**Application :** coût d’attaque estimé de l’ordre de 5–20 Mds $ (hérité de Bitcoin [5]). Vérification publique, builds reproductibles, opérationnel depuis 2013.

**Impact (tel qu’argumenté dans ce travail) :**

*   Un système d’identité pratique explicitement fondé sur le théorème de Rompel
*   Une estimation explicite du coût d’attaque (de l’ordre de 5–20 Mds $ pour les déploiements ancrés à Bitcoin \[5\])
*   Une couche d’identité agnostique vis‑à‑vis de la chaîne, portable entre annuaires
*   Un objectif de conception visant à minimiser les points de capture institutionnelle en faisant de la clé de l’individu la primitive cryptographique première

Sous les hypothèses énoncées dans cet article, Identity Bedrock se situe, de notre point de vue, à un niveau cryptographique et institutionnel minimal pour l’authentification publique. Il n’existe pas de primitive strictement plus faible ni de clé cachée « sous » la clé Ed25519 de l’utilisateur dont le système dépendrait : tout mécanisme placé en dessous de la clé bedrock réintroduirait soit un contrôle institutionnel, soit des hypothèses au moins aussi fortes que les fonctions à sens unique et la finalité de l’annuaire.

Sur le plan cryptographique, toute attaque forgeant une authentification sans contrôler la clé de l’utilisateur violerait la sécurité EUF‑CMA d’Ed25519 et casserait donc l’hypothèse sous‑jacente de fonction à sens unique (via l’équivalence OWF–UOWHF–signature décrite en section 2.1 et instanciée au moyen de [1,7,9]). Sur le plan de l’annuaire, toute attaque modifiant des liaisons d’identité finalisées doit réécrire l’historique NVS ancré par AuxPoW dans Emercoin sur une fenêtre prolongée (par exemple six blocs ou plus), ce qui exige une attaque coûteuse sur le consensus Emercoin+Bitcoin combiné \[4,5\]. Un adversaire qui refuse de remettre en cause ces hypothèses de dureté doit donc payer ce coût économique explicite : dans notre modèle, il n’existe pas de cible plus « molle » strictement sous la clé individuelle.

**Nous soutenons que, dans notre modèle, l’élimination de couches plus molles situées sous la clé individuelle réduit substantiellement les surfaces de capture institutionnelle et force tout attaquant potentiel soit à casser des hypothèses cryptographiques bien établies, soit à soutenir une réécriture coûteuse de l’annuaire.**

## Références

[1] Rompel, J. (1990). "One-Way Functions are Necessary and Sufficient for Secure Signatures." STOC ’90.

[3] Gibson, S. "Ultra-High Entropy Pseudo Random Number Generator." GRC.

[4] Emercoin. "Main Features of Hybrid Mining."

[5] Nuzzi, L., et al. (2024). "Breaking BFT: Quantifying the Cost to Attack Bitcoin and Ethereum." Coin Metrics.

[6] Skycoin. "Technical Background of Version 0 Skycoin Addresses."

[7] Haitner, I., Holenstein, T., Reingold, O., Vadhan, S., and Wee, H. (2010). "Universal One-Way Hash Functions via Inaccessible Entropy." In H. Gilbert (ed.), Advances in Cryptology – EUROCRYPT 2010, Lecture Notes in Computer Science, vol. 6110, Springer.

[8] WORM project. "WORM – Write Once, Read Many JSON record format and tooling." https://github.com/ness-network/worm.

[9] Kiltz, E., Lyubashevsky, V., et Pietrzak, K. (2005). "On Constructing Universal One-Way Hash Functions." Cryptology ePrint Archive, Report 2005/328. (Preuve moderne et détaillée de la construction de Rompel OWF ⇒ UOWHF ⇒ schéma de signature.)

[Références standard supplémentaires en cryptographie, blockchain et identité]

## Annexes

**A. Définitions formelles**

*   Schémas de signature, sécurité EUF‑CMA
*   Propriétés des annuaires, finalité
*   Spécification du protocole d’authentification

**B. Spécification du format WORM**

*   Schéma JSON
*   Règles de validation
*   Champs d’extension

**C. Détails de déploiement**

*   Processus de builds reproductibles
*   Liste de vérification pour la vérification publique
*   URLs d’explorateurs et dépôts GitHub
