# Inférence souveraine en tant que service :
## Découverte décentralisée, authentification et exécution de l'inférence par intelligence artificielle

**Jean-François Bouchard**
*Avril 2026*

---

## Résumé

Les services d'inférence contemporains reposent sur une infrastructure centralisée, comprenant des passerelles d'API, des identifiants révocables et des points d'accès réseau susceptibles de faire l'objet de filtrage ou de saisie. Nous présentons une architecture d'inférence souveraine en tant que service qui élimine toute dépendance envers des points de contrôle centralisés.

La découverte des services est effectuée via des enregistrements SRV stockés dans la chaîne de blocs Emercoin Name-Value Storage (NVS). La confiance est établie au moyen d'identités ancrées sur chaîne (privatenessID), remplaçant les dépendances envers les autorités de certification par des liaisons cryptographiques de clés ancrées dans un registre public.

Le transport est assuré par des réseaux mailleux et superposés, réduisant la dépendance envers la visibilité du routage IP conventionnel. Le paiement est effectué par des transactions natives sur la chaîne de blocs, sans processeur intermédiaire.

Bien que l'interférence au niveau réseau demeure possible, le système garantit que les enregistrements de découverte de services et d'identité restent globalement répliqués et résistants à la falsification.

Nous introduisons également l'usage d'une source d'entropie contrôlée par l'utilisateur pour l'échantillonnage lors de l'inférence, réduisant le risque de biais induit par l'opérateur dans la génération probabiliste.

L'architecture est validée sur du matériel grand public, établissant une borne inférieure reproductible pour le déploiement d'inférence décentralisée.

---

## 1. Introduction

La fourniture d'inférence par intelligence artificielle est essentiellement centralisée, s'appuyant sur une infrastructure en nuage et des mécanismes d'accès révocables. Cela introduit des dépendances structurelles envers des fournisseurs d'infrastructure, des systèmes de paiement et des environnements réglementaires.

Le présent article propose une alternative décentralisée dans laquelle :

- la découverte est fondée sur la chaîne de blocs ;
- l'identité est ancrée cryptographiquement ;
- le transport est multi-réseau ;
- le paiement est natif et décentralisé.

---

## 2. Modèle de système

Nous définissons le système comme :

```
S = (N, I, D, T, E)
```

Où :

- **N** : ensemble des nœuds ;
- **I** : correspondance d'identité (ancrée sur chaîne) ;
- **D** : mécanisme de découverte ;
- **T** : couche de transport ;
- **E** : source d'entropie.

---

## 3. Consensus et stockage

Tous les enregistrements persistants sont stockés dans l'Emercoin NVS. Les enregistrements sont :

- globalement répliqués ;
- engagés cryptographiquement ;
- modifiables uniquement par le détenteur de la clé.

La preuve de travail auxiliaire (AuxPoW) renforce la résistance aux réorganisations profondes de la chaîne en couplant la sécurité à la participation externe au minage.

---

## 4. Propriétés de sécurité

### 4.1 Immuabilité des enregistrements

Toute modification non autorisée requiert :

```
P(attaque) ≈ P(compromission de clé) + P(échec de consensus)
```

### 4.2 Intégrité de la découverte

Un client n'accepte un point d'accès que si :

```
Clé du point d'accès ∈ I(identité)
```

### 4.3 Absence de point de contrôle unique

```
∀c ∈ S, S \ c ≠ ∅
```

### 4.4 Borne inférieure du coût d'attaque

```
C_attaque ≥ min(C_réorg, C_clé) + C_réseau
```

---

## 5. L'entropie comme primitive de sécurité

### 5.1 Modèle d'échantillonnage

La probabilité d'échantillonnage d'un token est définie par la distribution softmax :

```
P(t_i) = exp(l_i / T) / Σ_j exp(l_j / T)
```

### 5.2 Biais adversarial

Un opérateur malveillant peut introduire un biais ε_i tel que :

```
P'(t_i) = P(t_i) + ε_i
```

avec la contrainte de conservation :

```
Σ_i ε_i = 0
```

### 5.3 Difficulté de détection

La divergence de Kullback-Leibler entre la distribution biaisée et la distribution réelle est d'ordre :

```
D_KL(P' ‖ P) ≈ O(ε²)
```

Les biais de faible amplitude sont difficiles à détecter sans jeux de données de grande taille.

### 5.4 Atténuation

L'introduction d'une source d'entropie externe :

```
R = H(graine, compteur)
```

modifie l'échantillonnage comme suit :

```
t_i = f(P, R)
```

réduisant ainsi le contrôle de l'opérateur sur la sortie stochastique.

---

## 6. Évaluation expérimentale

### 6.1 Configuration

- Modèle : paramètres quantifiés de 7B / 8B ;
- Environnement d'exécution : llama.cpp ;
- Matériel : Raspberry Pi 4, RK35xx ;
- Transports : hôte local, réseau local, mailleux, internet.

### 6.2 Débit

| Matériel | Tokens / seconde |
|----------|-----------------|
| Pi 4     | 4 – 8           |
| RK35xx   | 8 – 18          |

### 6.3 Latence

| Transport    | Latence         |
|--------------|----------------|
| Hôte local   | 50 – 150 ms    |
| Réseau local | 100 – 300 ms   |
| Mailleux     | 500 – 1 500 ms |
| Internet     | 200 – 800 ms   |

### 6.4 Temps de découverte

| Opération        | Durée          |
|------------------|----------------|
| Consultation NVS | 1 – 3 s        |
| Résolution SRV   | 50 – 200 ms    |

---

## 7. Considérations économiques

Les coûts opérationnels sont faibles en raison :

- de l'utilisation de matériel grand public ;
- des frais de stockage minimaux.

Les récompenses de jalonnement peuvent compenser les coûts dans des conditions favorables, mais cela dépend de la dynamique des marchés et ne constitue pas un invariant du système.

---

## 8. Limitations

- Le filtrage au niveau réseau demeure possible.
- La latence est plus élevée sur les transports mailleux.
- Les systèmes de réputation ne sont pas encore implémentés.
- L'équilibrage de charge en temps réel est limité.

---

## 9. Conclusion

Nous présentons une architecture d'inférence décentralisée qui :

- supprime toute dépendance envers des ancres de confiance centralisées ;
- distribue la découverte de services et la gestion des identités ;
- introduit l'entropie comme contrôle de sécurité.

Le système démontre que l'inférence par intelligence artificielle peut être fournie via une infrastructure décentralisée avec une confiance vérifiable et un coût minimal.
