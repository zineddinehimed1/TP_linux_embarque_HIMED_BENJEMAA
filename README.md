# TP_linux_embarque_HIMED_BENJEMAA

# TP – Écran magique

## Introduction

Dans ce TP, l’objectif est de concevoir une version numérique de l’**écran magique** (ou télécran) à l’aide d’un FPGA.  
Le déplacement du stylet est assuré par des **encodeurs incrémentaux**, tandis que l’affichage sera réalisé via la sortie HDMI de la carte **DE10-Nano**.

Le projet est découpé en plusieurs parties, chacune suivant la démarche classique de conception en logique numérique :
- conception du schéma,
- implémentation en VHDL,
- simulation sous **ModelSim**,
- test sur la carte FPGA à l’aide de **Quartus Prime Lite**.

---

## 1. Gestion des encodeurs

Cette première partie se concentre sur la **gestion des encodeurs incrémentaux**.  
L’affichage est volontairement mis de côté afin de se focaliser sur l’acquisition des signaux, la détection des fronts et la détermination du sens de rotation.

### Détection d’un front montant / descendant avec deux bascules D

Le montage utilisant **deux bascules D en série** permet de mémoriser :
- l’état **courant** du signal,
- l’état **précédent** du signal,

tous deux échantillonnés sur le signal d’horloge `clk`.

#### Principe

On note :
- `q0` : sortie de la **première bascule D** → état courant du signal
- `q1` : sortie de la **seconde bascule D** → état précédent du signal

En comparant ces deux valeurs, on peut détecter les fronts :

- **Front montant (0 → 1)**
- **Front descendant (1 → 0)**


Ces signaux (`rise` et `fall`) sont des **impulsions d’un seul cycle d’horloge**.

Dans le schéma fourni, le bloc `???` correspond à cette **logique combinatoire**, chargée de comparer `q0` et `q1` afin de générer le signal d’événement `E`.

---

### Prise en compte du sens de rotation (encodeur en quadrature A/B)

Un encodeur incrémental fournit deux signaux `A` et `B` en **quadrature**.  
Le sens de rotation est déterminé en observant l’état de l’autre signal au moment du front.

#### Règles de décision

**Incrémenter le registre :**
- `riseA` lorsque `B = 0`
- `fallA` lorsque `B = 1`

**Décrémenter le registre :**
- `riseB` lorsque `A = 0`
- `fallB` lorsque `A = 1`





