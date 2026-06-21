# ISTRUZIONI PER TESTARE IL GIOCO
## Progetto: Indie 2D – Palline, Terreno, Plinko
### Motore: Godot 4.3 (GL Compatibility)

---

## PREREQUISITI

1. **Scarica Godot 4.3** da https://godotengine.org/download
   - Scegli la versione **Standard** (non Mono/.NET)
   - Non richiede installazione: è un eseguibile singolo

2. **Estrai questo zip** in una cartella a tua scelta
   - La struttura deve rimanere intatta: `TravelCalculator/project.godot`, `scripts/`, `data/`, ecc.

---

## AVVIO DEL PROGETTO

### Metodo 1 — Doppio clic su project.godot
1. Apri Godot 4.3
2. Nella schermata "Project Manager" clicca **Import**
3. Naviga fino alla cartella estratta e seleziona `project.godot`
4. Clicca **Import & Edit**
5. Premi **F5** oppure il pulsante ▶ in alto a destra per avviare il gioco

### Metodo 2 — Da riga di comando
```
godot --path /percorso/TravelCalculator
```

---

## STRUTTURA DELLO SCHERMO

Lo schermo è diviso in **tre sezioni verticali** (1280×720):

```
┌────────────────────────────────────┐  y = 0
│  SEZIONE PALLINE  (y 0–240)        │
│  Palline colorate che rimbalzano   │
├────────────────────────────────────┤  y = 240
│  TERRENO DISTRUTTIBILE (y 240–480) │
│  Griglia 140×30 celle + cannoni    │
├────────────────────────────────────┤  y = 480
│  ZONA PLINKO / RACCOLTA (y 480–720)│
│  Pioli + slot con moltiplicatori   │
└────────────────────────────────────┘  y = 720
```

---

## CONTROLLI

### Selezione arma
| Tasto | Arma            | Comportamento                              |
|-------|-----------------|--------------------------------------------|
| `1`   | Proiettile      | Distrugge 1 cella precisa                  |
| `2`   | Bomba           | Esplosione media (raggio ~42 px)           |
| `3`   | Missile         | Esplosione grande (raggio ~85 px)          |
| `4`   | Lanciafiamme    | Tieni premuto il mouse per un flusso rapido|
| `5`   | Acido           | Si espande nelle celle vicine nel tempo    |
| `6`   | Verme           | Atterra e mangia il terreno a caso         |

### Sparo
- **Click sinistro** sulla zona terreno (grigia, tra i due cannoni laterali)
- Il proiettile parte dal cannone più vicino al lato opposto e segue una **traiettoria parabolica**
- Il Lanciafiamme (`4`) si attiva tenendo premuto e si ferma rilasciando

### Negozio potenziamenti
- **TAB** — apre/chiude il negozio
- Clicca il pulsante con il costo (`$ N`) per acquistare un potenziamento
- I pulsanti grigi = fondi insufficienti; quelli con bordo blu = acquistabili

---

## TEST PASSO PER PASSO

### PASSO 1 — Verifica avvio
- [ ] Il gioco si apre senza errori nella console di Godot
- [ ] Sono visibili palline colorate nella sezione superiore che rimbalzano
- [ ] Il terreno colorato (sfumato con rumore simplex) è visibile nella sezione centrale
- [ ] La zona Plinko con pioli e slot è visibile in basso

### PASSO 2 — Sezione palline
- [ ] Le palline rimbalzano sulle pareti laterali e sul soffitto
- [ ] Le palline NON attraversano il terreno (il terreno funge da pavimento)
- [ ] Le palline cadono attraverso i buchi creati nel terreno

### PASSO 3 — Armi (testa ognuna)
- [ ] Premi `1`, clicca sul terreno → una singola cella sparisce
- [ ] Premi `2`, clicca → cratere medio con effetto visivo esplosione
- [ ] Premi `3`, clicca → cratere grande con effetto visivo più ampio
- [ ] Premi `4`, tieni premuto → flusso continuo di piccole fiamme
- [ ] Premi `5`, clicca → macchia verde che si espande lentamente nel tempo
- [ ] Premi `6`, clicca → pallina marrone che appare e mangia il terreno in direzioni casuali
- [ ] Cambia arma con i tasti 1–6 e verifica che il nome dell'arma attiva cambi in basso a sinistra

### PASSO 4 — Caduta palline → slot
- [ ] Distruggi abbastanza terreno da creare un buco largo
- [ ] Aspetta che una pallina cada attraverso il buco
- [ ] La pallina rimbalza sui pioli nella zona Plinko
- [ ] Entra in uno slot e appare il testo "+N" con l'importo guadagnato
- [ ] Il contatore `$ N` in basso a sinistra della sezione Plinko aumenta

### PASSO 5 — Negozio (TAB)
- [ ] Premi TAB → il negozio si apre sopra tutto
- [ ] Sono visibili 8 nodi nell'albero dei potenziamenti collegati da linee
- [ ] In alto a sinistra: importo attuale `$ N` e livello corrente
- [ ] La barra di progresso mostra l'avanzamento verso il prossimo livello
- [ ] Premi TAB di nuovo → il negozio si chiude

### PASSO 6 — Acquisto potenziamento
> Per guadagnare denaro velocemente: usa il Verme (`6`) per aprire grandi buchi
> e lascia cadere molte palline.

- [ ] Accumula almeno **$ 80** (costo minimo: Cadenza di Fuoco lv1)
- [ ] Apri il negozio (TAB)
- [ ] Il pulsante del potenziamento accessibile ha il **bordo blu**
- [ ] Clicca il pulsante → il costo viene scalato dai fondi
- [ ] Il testo dell'effetto nella card si aggiorna (es. "+20% velocità")
- [ ] Il livello della card aumenta di 1

### PASSO 7 — Effetti potenziamenti
- [ ] **Potenza Armi** (lv 1+): Bomba/Missile creano crateri più grandi
- [ ] **Cadenza di Fuoco** (lv 1+): il Lanciafiamme spara più velocemente
- [ ] **Colpi Critici** (lv 1+): occasionalmente le esplosioni causano triplo danno
- [ ] **Basi di Lancio** (lv 1+): vengono usate più posizioni di partenza dei proiettili
- [ ] **Perforazione** (lv 1+): le celle del terreno hanno meno HP (si distruggono prima)
- [ ] **Slot Aggiuntivi** (lv 1+): la zona Plinko mostra più slot (13, 16, 19)
- [ ] **Moltiplicatori** (lv 1+): i valori guadagnati per pallina sono moltiplicati
- [ ] **Potenza Verme** (lv 1+): il verme mangia per più passi e in un'area maggiore

### PASSO 8 — Livello superiore
- [ ] Guadagna abbastanza monete per salire di livello (soglia: `$ 1.000` per il livello 2)
- [ ] Appare il banner **"LIVELLO N!"** in basso (visibile sia nel negozio che nel gioco)
- [ ] Il terreno viene rigenerato con HP più alti (i livelli alti rendono le celle più resistenti)
- [ ] La barra di progresso nel negozio si azzera per il prossimo livello

---

## PERSONALIZZAZIONE (FILE DI TESTO)

### Bilanciamento livelli — `data/levels.cfg`
Apri il file con qualsiasi editor di testo. Ogni riga è la soglia di monete totali
guadagnate per salire a quel livello:
```ini
l2   = 1000     ; modifica per rendere il primo livello più facile/difficile
l3   = 3000
...
l100 = 4950000
```

### Albero potenziamenti — `data/upgrades.cfg`
Ogni sezione `[id]` è un nodo dell'albero:
```ini
[weapon_power]
name      = "Potenza Armi"
desc      = "Danno di tutte le armi +25% per livello"
max_level = 10
costs     = [50, 120, 250, 500, 1000, 2000, 4000, 8000, 16000, 32000]
connect   = ["fire_rate", "critical"]   ; vicini nell'albero visuale (max 4)
grid_x    = 0                           ; colonna nella griglia
grid_y    = 0                           ; riga nella griglia
```
- Puoi modificare costi, livello massimo e descrizioni senza riaprire Godot
- Aggiungi un nuovo nodo aggiungendo una nuova sezione e riavviando il gioco

---

## PROBLEMI COMUNI

| Problema | Soluzione |
|----------|-----------|
| Errore "Cannot open file res://data/upgrades.cfg" | Assicurati di avere la cartella `data/` nella stessa directory di `project.godot` |
| Le palline non cadono | Il terreno è ancora intatto: distruggi celle nel mezzo |
| Il negozio non si apre | Premi TAB sulla finestra di gioco (non sull'editor Godot) |
| I pulsanti del negozio sono tutti grigi | Fondi insufficienti: guadagna più denaro prima |
| Nessun testo "+N" quando la pallina cade | La pallina è uscita dai bordi laterali: usa i cannoni per aprire buchi più centrali |

---

## FILE INCLUSI

```
TravelCalculator/
├── project.godot          ← apri questo con Godot
├── data/
│   ├── levels.cfg         ← soglie livelli (modificabile)
│   └── upgrades.cfg       ← albero potenziamenti (modificabile)
├── scenes/
│   └── Main.tscn
├── scripts/
│   ├── Ball.gd
│   ├── BucketSection.gd
│   ├── DestructibleArea.gd
│   ├── GameState.gd       ← singleton autoload
│   ├── Main.gd
│   └── UpgradeShop.gd
└── icon.svg
```
