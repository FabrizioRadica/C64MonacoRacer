# Monaco Racer C64 - Test Assembly 6502

Questo progetto è un piccolo esperimento realizzato in Assembly 6502 per Commodore 64, ispirato alle meccaniche arcade di **Monaco GP** di Sega del 1979.

Il sorgente è stato creato come test con **Claude Fable5**, verificando poi manualmente il codice, il comportamento nell'emulatore e la corretta gestione del charset personalizzato.

## Descrizione del progetto

Il gioco è un semplice racing game con visuale dall'alto, dove l'auto del giocatore rimane nella parte bassa dello schermo mentre la strada scorre verticalmente.

Il progetto include:

* codice Assembly 6502 in sintassi ACME;
* compatibilità con C64Studio;
* sprite per auto, traffico, esplosione e fari;
* charset personalizzato;
* strada a larghezza variabile;
* tratti differenti come asfalto, ghiaccio, ghiaia, galleria e ponte;
* punteggio, vite e classifica dei migliori tempi;
* gestione joystick su porta 2.

## Fix al charset

Durante il test nell'emulatore è stato individuato un problema nella visualizzazione del testo, in particolare nella scritta:

```text
FABRIZIO RADICA 2026
```

Il problema era causato dal fatto che alcuni caratteri custom venivano copiati nelle posizioni `1`, `2` e `3` del charset, che nel Commodore 64 corrispondono alle lettere:

```text
1 = A
2 = B
3 = C
```

Di conseguenza, le lettere A, B e C venivano sovrascritte dai tile grafici del gioco.

La correzione è stata quella di spostare i caratteri personalizzati in una zona libera del charset, usando i caratteri `27`, `28` e `29`:

```asm
CH_LINE     = 27
CH_GRASS2   = 92
CH_GRAVEL   = 29
```

e copiando i dati custom a partire da:

```asm
CHARSET+(27*8)
```

In questo modo il testo standard rimane leggibile e i tile grafici continuano a funzionare correttamente.

## Compilazione

Il progetto è pensato per essere compilato con **ACME** oppure tramite **C64Studio**.

Esempio da terminale:

```bash
acme -f cbm -o monaco.prg monaco_fix_charset.asm
```

Oppure aprire il sorgente in C64Studio e usare **Build & Run**.

## Autore

Progetto e test a cura di:

**Fabrizio Radica**
RadicaDesign

Sito web:
www.radicadesign.com

Email:
fabrizio@radicadesign.com
