Ceci est le cahier des charges technique final et consolidé pour le projet de système de Mini-Apps KodiScript sur Flutter.

Il intègre toutes les décisions architecturales prises : exécution monothread, gestion d'état par persistance de contexte, réactivité fine type `Obx`, et mapping UI déclaratif.

---

# Cahier des Charges Technique : Système Mini-Apps KS/Flutter

## 1. Vue d'ensemble
Le système permet d'exécuter des micro-applications dynamiques (scripts) au sein d'une application hôte Flutter. L'objectif est d'allier la flexibilité du web (mise à jour instantanée, code distant) à la performance native (rendu Flutter, pas de WebView).

### 1.1 Choix Architecturaux
*   **Moteur :** Exécution sur le **Main Thread** (Monothread). Pas d'Isolates par défaut.
*   **Persistance :** L'état est maintenu par la réutilisation du `context` (Map) entre les appels.
*   **Rendu :** Déclaratif via JSON (Arbre UI Virtuel) converti en Widgets Flutter.
*   **Réactivité :** Fine-grained (Grain fin) via Binding d'objets Dart (`Rx`/`Obx`) pour éviter les re-renders globaux.
*   **Distribution :** Hybride (SSR possible pour l'affichage initial, CSR pour la logique).

---

## 2. Le Moteur (KSEngine Wrapper)
Une classe Dart encapsulant la librairie `kodi-script-dart`.

### 2.1 Responsabilités
*   Gérer la mémoire vive de la mini-app (`context`).
*   Charger les scripts (Core + User).
*   Exécuter des fonctions spécifiques sans réinitialiser les variables globales.

### 2.2 Spécifications API
```dart
class KSEngine {
  // La mémoire persistante de la mini-app
  final Map<String, dynamic> context = {};

  KSEngine() {
    _injectNativeBindings(); // Injecte Obs, print, delay, etc.
  }

  // Phase 1 : Chargement (Exécuté 1 seule fois)
  // Charge core.ks + script utilisateur pour définir variables et fonctions.
  Future<void> load(String scriptSource);

  // Phase 2 : Appel (Exécuté à chaque event)
  // Exécute "funcName()" en réutilisant le context existant.
  Future<dynamic> invoke(String funcName);
}
```

---

## 3. Gestion de l'État et Réactivité (Rx System)
Implémentation d'une réactivité implicite inspirée de GetX, rendue possible par l'interface `KodiBindable`.

### 3.1 Composant `Rx<T>` (Dart)
Classe implémentant `KodiBindable` pour être manipulable directement par le script.
*   **Interface Script :**
    *   `getProperty('value')` : Retourne la valeur et **capture la dépendance** si un `Obx` est actif.
    *   `callMethod('set', [val])` : Met à jour la valeur et **notifie les widgets abonnés**.
*   **Constructeur :** Injecté dans le contexte via la fonction globale `Obs(val)`.

### 3.2 Widget `ObxWidget` (Flutter)
Widget Stateful qui écoute les changements.
*   **Entrée :** Nom de la fonction builder KS (String).
*   **Cycle de vie (`build`) :**
    1.  Active un flag global `RxNotifier.currentCapturer`.
    2.  Appelle `engine.invoke(builderName)`.
    3.  Le script s'exécute, lit `myVar.value` -> Le `Rx` s'ajoute au capturer.
    4.  Désactive le flag.
    5.  S'abonne aux `Rx` capturés pour déclencher un `setState` local au futur changement.

---

## 4. Rendu de l'Interface (UI Mapping)

### 4.1 Structure JSON Standard
Le script doit produire des Maps Dart standard (convertibles en JSON).
```json
{
  "type": "WidgetName",
  "props": { "color": "#FF0000", "onTap": "myFunc" },
  "children": []
}
```

### 4.2 Librairie Standard (`core.ks`)
Helpers injectés automatiquement pour masquer la complexité du JSON.
```javascript
// Exemples de helpers
function Text(content, style) { return { "type": "Text", "props": {...} }; }
function Obx(builderFunc) { return { "type": "Obx", "builder": builderFunc }; }
```

### 4.3 Registre de Widgets (Dart)
Catalogue associant `String` -> `WidgetBuilder`.
*   **Support Minimum (MVP) :**
    *   Layout : `Column`, `Row`, `Stack`, `SizedBox`, `Padding`, `Container`.
    *   Basic : `Text`, `Image`, `Icon`.
    *   Interactif : `Button`, `Input` (liés à des Rx).
    *   Logique : `Obx` (pour la réactivité).

### 4.4 Mapper (Dart)
Fonction récursive transformant la Map KS en Widget.
*   Gère l'attachement des callbacks : Si `props['onTap']` est présent, crée une closure qui appelle `engine.invoke('nomFonction')`.

---

## 5. Flux d'Exécution & User Experience

### 5.1 Exemple de Script Cible
C'est ce que le développeur écrira.
```javascript
// Variable réactive (Objet Dart bindé)
var counter = Obs(0);

function increment() {
  // Modification d'état -> Notifie Flutter automatiquement
  counter.set(counter.value + 1);
}

function build() {
  return Column([
    Text("Compteur"),
    // Zone réactive ciblée
    Obx("buildCountText"), 
    Button("Ajouter", { "onTap": "increment" })
  ]);
}

function buildCountText() {
  // Lecture -> Capture la dépendance
  return Text(counter.value);
}
```

### 5.2 Séquence d'Interaction
1.  **Clic :** User tape sur "Ajouter".
2.  **Flutter :** Détecte `onTap`, appelle `engine.invoke('increment')`.
3.  **Script :** Exécute `increment`, appelle `counter.set(...)`.
4.  **Rx (Dart) :** Met à jour la valeur, notifie les listeners.
5.  **ObxWidget (Flutter) :** Reçoit la notif, appelle `engine.invoke('buildCountText')`.
6.  **Script :** Retourne le nouveau JSON du texte.
7.  **Flutter :** Met à jour uniquement le widget Text.

---

## 6. Recommandations d'Amélioration Moteur (KodiScript)
Pour assurer la robustesse à long terme, ces évolutions du package `kodi-script-dart` seraient bénéfiques (via PR ou Fork) :

1.  **Invocation Native :** Ajouter une méthode `call(String funcName, List args)` pour éviter le hack de l'injection de string `"$funcName()"`.
2.  **Parsing Séparé :** Séparer la méthode `parse` (création AST) de `run` (exécution) pour ne pas re-analyser le code à chaque clic (Performance ++).

## 7. Livrables
1.  **Package `ks_flutter_engine` :** Contient `KSEngine`, `Rx`, `RxNotifier`.
2.  **Package `ks_flutter_ui` :** Contient `WidgetRegistry`, `WidgetMapper`, `ObxWidget`.
3.  **Assets :** Fichier `core.ks`.
4.  **Demo App :** Application hôte montrant un exemple complet.