;==============================================================
;  MONACO RACER v3 - clone di MONACO GP (Sega 1979)
;  Commodore 64 - assembly 6502, sintassi ACME / C64Studio
;  FABRIZIO RADICA 2026 - Claude Fable5 Test
;
;  NOVITA' DELLA v3:
;   - MENU iniziale: titolo, classifica e invito lampeggiante
;     "PREMI FUOCO PER INIZIARE"
;   - CLASSIFICA dei 10 MIGLIORI TEMPI di sopravvivenza
;     (in secondi), conservata in RAM tra una partita e l'altra
;   - 5 VITE al massimo: ogni incidente ne toglie una, le soglie
;     di punteggio (2000/4000/6000/8000) ne regalano una (mai
;     oltre 5); a vite finite si torna al menu e si riparte
;
;  MECCANICHE RIPRESE DALL'ORIGINALE:
;   - strada DRITTA che si restringe e si allarga di continuo
;   - 5 tratti in ordine fisso: normale, GHIACCIO (si slitta),
;     GALLERIA (buio, si vede solo nei fari), GHIAIA (niente
;     marcia alta), PONTE (strettissimo, sull'acqua)
;   - punti in base alla marcia: ~8/sec in prima, 25/sec in
;     seconda; punteggio bloccato a 9999
;   - traffico che ondeggia con moto sinusoidale e accelera
;     dopo i 6000 e gli 8000 punti
;
;  COMANDI (joystick in PORTA 2):
;    sinistra / destra : sterza (sul ghiaccio l'auto slitta!)
;    su                : seconda marcia (veloce, piu' punti)
;    fuoco             : avvia la partita dal menu
;
;  COMPILAZIONE: aprire in C64Studio e premere F5, oppure
;     acme -f cbm -o monaco3.prg monaco3.asm
;==============================================================

;--------------------------------------------------------------
; COSTANTI
;--------------------------------------------------------------
SCREEN      = $0400             ; matrice video
CHARSET     = $3800             ; set di caratteri in RAM

; tile (modalita' ECM: i 2 bit alti del codice scelgono lo sfondo)
CH_ROAD     = 32                ; asfalto (sfondo 0, grigio)
CH_LINE     = 27                ; linea di mezzeria (char custom 27)
CH_GRASS2   = 92                ; ciuffi d'erba (char custom 28 + 64)
CH_GRAVEL   = 29                ; ghiaia (char custom 29)
CH_GRASS    = 96                ; erba (sfondo 1, verde)
CH_RAIL     = 160               ; guard rail (sfondo 2, bianco)
CH_BLUE     = 224               ; ghiaccio / acqua (sfondo 3, blu)

CENTER      = 19                ; colonna centrale (strada dritta)
PROW        = 22                ; riga video sotto il giocatore
PY          = 218               ; Y fissa dello sprite giocatore
NSECT       = 8                 ; tratti nel circuito
MAXLIVES    = 5                 ; vite massime

; tipi di tratto
T_NORM      = 0
T_ICE       = 1
T_TUNNEL    = 2
T_GRAVEL    = 3
T_BRIDGE    = 4

; puntatori di pagina zero per scorrimento e classifica
SRCL        = $fb
SRCH        = $fc
DSTL        = $fd
DSTH        = $fe

;--------------------------------------------------------------
; AVVIO BASIC:  10 SYS2061
;--------------------------------------------------------------
* = $0801
        !byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

;--------------------------------------------------------------
; INIZIALIZZAZIONE HARDWARE (una sola volta)
;--------------------------------------------------------------
start
        sei

        ; copia i primi 64 caratteri della ROM in RAM
        lda #$33
        sta $01
        ldx #0
in_cc   lda $d000,x
        sta CHARSET,x
        lda $d100,x
        sta CHARSET+$100,x
        inx
        bne in_cc
        lda #$37
        sta $01

        ; tile personalizzate: 27=mezzeria, 28=ciuffi, 29=ghiaia
        ; NON usare i caratteri 1,2,3: sono A,B,C nello screen code C64
        ldx #23
in_cu   lda customchr,x
        sta CHARSET+(27*8),x
        dex
        bpl in_cu

        ; VIC-II
        lda #$1e                ; schermo $0400, charset $3800
        sta $d018
        lda #$5b                ; modalita' Extended Color (ECM)
        sta $d011
        lda #$c8
        sta $d016
        lda #0
        sta $d020               ; bordo nero

        ; color RAM tutta bianca (testi, mezzeria, ghiaia)
        ldx #0
in_cr   lda #1
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $db00,x
        inx
        bne in_cr

        ; sprite: 0 giocatore, 1-3 traffico, 4-7 fari (galleria)
        lda #128                ; $2000/64 -> auto giocatore
        sta SCREEN+$3f8
        lda #129                ; $2040/64 -> auto avversarie
        sta SCREEN+$3f9
        sta SCREEN+$3fa
        sta SCREEN+$3fb
        lda #132                ; $2100/64 -> cono di luce
        sta SCREEN+$3fc
        sta SCREEN+$3fd
        sta SCREEN+$3fe
        sta SCREEN+$3ff
        lda #0
        sta $d015               ; sprite spenti (si parte dal menu)
        sta $d017
        sta $d01d
        sta $d01b
        sta $d01c
        sta $d010
        lda #2
        sta $d027               ; giocatore rosso
        lda #14
        sta $d028               ; traffico: azzurro...
        lda #7
        sta $d029               ; ...giallo...
        lda #13
        sta $d02a               ; ...verde chiaro
        lda #7
        sta $d02b               ; fari gialli
        sta $d02c
        sta $d02d
        sta $d02e
        lda #PY
        sta $d001

        ; SID
        lda #$8f                ; volume max, voce 3 muta
        sta $d418
        lda #$ff                ; voce 3: rumore -> numeri casuali
        sta $d40e
        sta $d40f
        lda #$80
        sta $d412
        lda #$00                ; voce 1: motore
        sta $d405
        lda #$f0
        sta $d406
        jmp menu

;--------------------------------------------------------------
; MENU INIZIALE: titolo, classifica dei 10 migliori tempi e
; invito lampeggiante; fuoco per iniziare
;--------------------------------------------------------------
menu
        ldx #$ff
        txs
        lda #0
        sta $d015               ; niente sprite nel menu
        lda #$20                ; motore spento
        sta $d404
        jsr litepal

        ; schermo grigio uniforme
        ldx #0
mn_f    lda #CH_ROAD
        sta SCREEN,x
        sta SCREEN+250,x
        sta SCREEN+500,x
        sta SCREEN+750,x
        inx
        cpx #250
        bne mn_f

        ; titolo
        ldx #11
mn_t1   lda txttitle,x
        sta SCREEN+3*40+14,x
        dex
        bpl mn_t1
        ; nome dell'autore e anno
        ldx #19                 ; lunghezza - 1 (20 caratteri)
mn_t9   lda txtnome,x
        sta SCREEN+5*40+10,x
        dex
        bpl mn_t9
        ; intestazione classifica
        ldx #13
mn_t2   lda txtbest,x
        sta SCREEN+6*40+13,x
        dex
        bpl mn_t2
        jsr drawtable

        ; attende che il pulsante sia rilasciato
mn_w0   lda $dc00
        and #%00010000
        beq mn_w0

        ; ciclo del menu: invito lampeggiante + attesa del fuoco
mn_lp   jsr waitfr
        inc frame
        lda frame
        and #$20
        beq mn_sh
        ldx #23                 ; fase spenta
        lda #CH_ROAD
mn_hd   sta SCREEN+21*40+8,x
        dex
        bpl mn_hd
        jmp mn_ck
mn_sh   ldx #23                 ; fase accesa
mn_s2   lda txtstart,x
        sta SCREEN+21*40+8,x
        dex
        bpl mn_s2
mn_ck   lda $dc00
        and #%00010000
        bne mn_lp
        jmp newgame

;--------------------------------------------------------------
; disegna la classifica: " 1.  0042" ... "10.  0003"
;--------------------------------------------------------------
drawtable
        lda #<(SCREEN+8*40+15)
        sta DSTL
        lda #>(SCREEN+8*40+15)
        sta DSTH
        ldx #0                  ; offset nella tabella (0,2..18)
dt_row  txa
        lsr
        clc
        adc #1                  ; posizione 1..10
        cmp #10
        bcc dt_r1
        ldy #0                  ; "10"
        lda #49
        sta (DSTL),y
        iny
        lda #48
        sta (DSTL),y
        jmp dt_dot
dt_r1   pha                     ; " n"
        ldy #0
        lda #32
        sta (DSTL),y
        iny
        pla
        clc
        adc #48
        sta (DSTL),y
dt_dot  ldy #2
        lda #46                 ; '.'
        sta (DSTL),y

        ; quattro cifre del tempo (BCD)
        lda hitab,x             ; byte alto
        pha
        lsr
        lsr
        lsr
        lsr
        clc
        adc #48
        ldy #4
        sta (DSTL),y
        pla
        and #15
        clc
        adc #48
        iny
        sta (DSTL),y
        lda hitab+1,x           ; byte basso
        pha
        lsr
        lsr
        lsr
        lsr
        clc
        adc #48
        iny
        sta (DSTL),y
        pla
        and #15
        clc
        adc #48
        iny
        sta (DSTL),y

        lda DSTL                ; riga successiva
        clc
        adc #40
        sta DSTL
        bcc dt_n
        inc DSTH
dt_n    inx
        inx
        cpx #20
        bcc dt_row
        rts

;--------------------------------------------------------------
; inserisce il tempo di sopravvivenza nella classifica
; (10 voci da 2 byte BCD: alto, basso - ordinata decrescente)
;--------------------------------------------------------------
savetime
        ldx #0
st_lp   lda etime+1
        cmp hitab,x
        beq st_eq
        bcs st_ins              ; nuovo tempo maggiore: inserisci
        bcc st_nx
st_eq   lda etime
        cmp hitab+1,x
        beq st_nx               ; a parita' resta dietro
        bcs st_ins
st_nx   inx
        inx
        cpx #20
        bcc st_lp
        rts                     ; fuori classifica

st_ins  ldy #17                 ; fa scorrere in giu' le voci
st_sh   sty tmpc
        cpx tmpc
        beq st_cp
        bcs st_put
st_cp   lda hitab,y
        sta hitab+2,y
        dey
        bpl st_sh
st_put  lda etime+1
        sta hitab,x
        lda etime
        sta hitab+1,x
        rts

;--------------------------------------------------------------
; NUOVA PARTITA
;--------------------------------------------------------------
newgame
        ldx #$ff
        txs
        lda #0
        sta score
        sta score+1
        sta capflag
        sta etime
        sta etime+1
        sta spdcnt
        sta frame
        sta stripecnt
        sta enebonus
        sta vx
        sta pxh
        sta sectidx
        sta curtype
        lda #MAXLIVES
        sta lives
        lda #50
        sta tick
        lda #6
        sta ptscnt
        lda #$20                ; prima soglia bonus: 2000 punti
        sta nextbonus
        lda #1
        sta speed
        lda #100
        sta crashtimer
        lda #70
        sta sectcnt
        lda #24
        sta widthtimer
        lda #7
        sta curhalf
        sta targethalf
        ldx #24
ng_t    sta halftab,x           ; strada larga ovunque
        lda #T_NORM
        sta typetab,x
        lda #7
        dex
        bpl ng_t

        ; traffico scaglionato
        lda #80
        sta eney
        lda #150
        sta eney+1
        lda #210
        sta eney+2
        lda #0
        sta eneoff
        lda #$fd                ; -3
        sta eneoff+1
        lda #3
        sta eneoff+2

        ; giocatore al centro
        lda #CENTER
        jsr coltopix
        lda tmpl
        sta pxl
        lda tmph
        sta pxh

        jsr fillfield
        lda #24                 ; riempie lo schermo di strada
        sta tmpcnt
ng_pr   jsr scrollroad
        dec tmpcnt
        bne ng_pr

        jsr prtime
        jsr printlives
        lda #$21                ; motore acceso
        sta $d404
        jmp mainloop

;--------------------------------------------------------------
; CICLO PRINCIPALE
;--------------------------------------------------------------
mainloop
        jsr waitfr
        inc frame
        jsr readjoy
        jsr engine
        jsr setpal              ; buio in galleria, fari accesi

        ; scorrimento: ogni 2 frame in prima, ogni frame in seconda
        lda spdcnt
        clc
        adc speed
        cmp #2
        bcc ml_ns
        sbc #2
        sta spdcnt
        jsr scrollroad
        jmp ml_g
ml_ns   sta spdcnt
ml_g    jsr updene
        jsr updplay

        ; punti legati alla marcia: ~8/sec in prima, 25/sec in seconda
        dec ptscnt
        bne ml_p
        jsr addpoint
        jsr chkbonus
        lda speed
        cmp #2
        beq ml_ph
        lda #6
        bne ml_ps
ml_ph   lda #2
ml_ps   sta ptscnt
ml_p
        jsr printscore
        jsr checkcol

        ; cronometro di sopravvivenza (sale, e' il dato in classifica)
        dec tick
        bne ml_t
        lda #50
        sta tick
        sed
        clc
        lda etime
        adc #1
        sta etime
        lda etime+1
        adc #0
        sta etime+1
        cld
        bcc ml_pt
        lda #$99                ; tetto 9999 secondi
        sta etime
        sta etime+1
ml_pt   jsr prtime
ml_t    jmp mainloop

;--------------------------------------------------------------
; sincronizzazione: un passaggio del raster per frame
;--------------------------------------------------------------
waitfr
wf_1    lda $d012
        cmp #$fa
        bne wf_1
wf_2    lda $d012
        cmp #$fa
        beq wf_2
        rts

;--------------------------------------------------------------
; JOYSTICK: sterzo diretto sull'asfalto, INERZIA sul ghiaccio,
; niente seconda marcia sulla ghiaia
;--------------------------------------------------------------
readjoy
        lda $dc00
        sta joyval
        lda typetab+PROW        ; superficie sotto il giocatore
        cmp #T_ICE
        beq rj_ice

        ; --- sterzo normale ---
        lda #0
        sta vx
        lda joyval
        and #%00000100
        bne rj_nl
        lda #$fe                ; -2
        sta vx
rj_nl   lda joyval
        and #%00001000
        bne rj_mv
        lda #2
        sta vx
        jmp rj_mv

        ; --- ghiaccio: la velocita' laterale resta (si slitta) ---
rj_ice  lda joyval
        and #%00000100
        bne rj_ir
        dec vx
        lda vx
        cmp #$fc                ; minimo -3
        bne rj_ir
        lda #$fd
        sta vx
rj_ir   lda joyval
        and #%00001000
        bne rj_mv
        inc vx
        lda vx
        cmp #4                  ; massimo +3
        bne rj_mv
        lda #3
        sta vx

        ; --- applica la velocita' (16 bit, con segno) ---
rj_mv   lda vx
        clc
        adc pxl
        sta pxl
        lda vx
        bmi rj_neg
        lda pxh
        adc #0
        sta pxh
        jmp rj_cl
rj_neg  lda pxh
        adc #$ff
        sta pxh

        ; --- limiti 18..318 ---
rj_cl   lda pxh
        bmi rj_min
        bne rj_max
        lda pxl
        cmp #18
        bcs rj_gear
rj_min  lda #18
        sta pxl
        lda #0
        sta pxh
        sta vx
        beq rj_gear
rj_max  lda pxl
        cmp #$3f
        bcc rj_gear
        lda #$3e
        sta pxl
        lda #0
        sta vx

        ; --- marcia: su = seconda (ma non sulla ghiaia) ---
rj_gear lda joyval
        and #%00000001
        bne rj_lo
        lda #2
        bne rj_sp
rj_lo   lda #1
rj_sp   sta speed
        lda typetab+PROW
        cmp #T_GRAVEL
        bne rj_x
        lda #1                  ; la ghiaia rallenta
        sta speed
rj_x    rts

;--------------------------------------------------------------
; motore: il tono sale con la marcia
;--------------------------------------------------------------
engine
        lda frame
        asl
        sta $d400
        lda frame
        and #3
        clc
        adc speed
        adc speed
        adc #2
        sta $d401
        rts

;--------------------------------------------------------------
; tavolozza chiara (usata in gioco e nel menu)
;--------------------------------------------------------------
litepal
        lda #11
        sta $d021               ; asfalto grigio
        lda #5
        sta $d022               ; erba verde
        lda #1
        sta $d023               ; guard rail bianco
        lda #6
        sta $d024               ; ghiaccio/acqua blu
        rts

; buio totale in galleria + fari accesi
setpal
        lda typetab+PROW
        cmp #T_TUNNEL
        beq sp_dark
        jsr litepal
        lda #%00001111          ; fari spenti
        sta $d015
        rts
sp_dark lda #0
        sta $d021               ; tutto nero...
        sta $d022
        lda #11
        sta $d023               ; ...rail appena visibili
        sta $d024
        lda #%11111111          ; fari accesi
        sta $d015
        rts

;--------------------------------------------------------------
; SCORRIMENTO: tabelle + righe video, poi nuova riga in alto
;--------------------------------------------------------------
scrollroad
        ldx #23
sr_tab  lda halftab,x
        sta halftab+1,x
        lda typetab,x
        sta typetab+1,x
        dex
        bne sr_tab
        jsr genroad
        lda curhalf
        sta halftab+1
        lda curtype
        sta typetab+1

        lda #<(SCREEN+23*40)
        sta SRCL
        lda #>(SCREEN+23*40)
        sta SRCH
        lda #<(SCREEN+24*40)
        sta DSTL
        lda #>(SCREEN+24*40)
        sta DSTH
        ldx #23
sr_row  ldy #39
sr_col  lda (SRCL),y
        sta (DSTL),y
        dey
        bpl sr_col
        sec
        lda SRCL
        sbc #40
        sta SRCL
        bcs sr_s1
        dec SRCH
sr_s1   sec
        lda DSTL
        sbc #40
        sta DSTL
        bcs sr_s2
        dec DSTH
sr_s2   dex
        bne sr_row
        jmp drawrow1

;--------------------------------------------------------------
; avanzamento del circuito: tratti in ordine fisso, strada
; dritta che si restringe/allarga (l'imbuto graduale fa da
; preavviso, come nel coin-op)
;--------------------------------------------------------------
genroad
        dec sectcnt
        bne gn_w
        ldx sectidx             ; tratto successivo
        inx
        cpx #NSECT
        bcc gn_si
        ldx #0
gn_si   stx sectidx
        lda sectlens,x
        sta sectcnt
        lda secttypes,x
        sta curtype
        tax
        lda secthalfs,x
        sta targethalf
        lda #24
        sta widthtimer
gn_w    lda curtype             ; nei tratti normali la larghezza
        bne gn_h                ; cambia di continuo
        dec widthtimer
        bne gn_h
        lda #24
        sta widthtimer
        jsr getrnd
        and #3
        clc
        adc #5                  ; nuova semilarghezza 5..8
        sta targethalf
gn_h    lda curhalf             ; transizione graduale (imbuto)
        cmp targethalf
        beq gn_x
        bcc gn_up
        dec curhalf
        rts
gn_up   inc curhalf
gn_x    rts

;--------------------------------------------------------------
; disegna la nuova riga 1 secondo il tipo di tratto
;--------------------------------------------------------------
drawrow1
        inc stripecnt
        ; lati: erba, oppure acqua sul ponte
        lda #CH_GRASS
        ldx curtype
        cpx #T_BRIDGE
        bne dw_s
        lda #CH_BLUE
dw_s    sta sidechar
        ; fondo stradale: asfalto, ghiaccio blu o ghiaia
        lda #CH_ROAD
        cpx #T_ICE
        bne dw_r1
        lda #CH_BLUE
dw_r1   cpx #T_GRAVEL
        bne dw_r2
        lda #CH_GRAVEL
dw_r2   sta roadchr

        lda sidechar            ; riempie i lati
        ldx #39
dr_g    sta SCREEN+40,x
        dex
        bpl dr_g

        lda curtype             ; ciuffi solo sull'erba normale
        bne dr_nd
        jsr getrnd
        and #31
        clc
        adc #4
        tax
        lda #CH_GRASS2
        sta SCREEN+40,x
        jsr getrnd
        and #31
        clc
        adc #4
        tax
        lda #CH_GRASS2
        sta SCREEN+40,x
dr_nd
        lda #CENTER             ; guard rail sinistro
        sec
        sbc curhalf
        tax
        dex
        jsr railchar
        sta SCREEN+40,x
        inx
        lda curhalf             ; fondo stradale
        asl
        clc
        adc #1
        tay
        lda roadchr
dr_rd   sta SCREEN+40,x
        inx
        dey
        bne dr_rd
        jsr railchar            ; guard rail destro
        sta SCREEN+40,x

        lda stripecnt           ; mezzeria solo sull'asfalto
        and #3
        cmp #2
        bcs dr_x
        lda roadchr
        cmp #CH_ROAD
        bne dr_x
        ldx #CENTER
        lda #CH_LINE
        sta SCREEN+40,x
dr_x    rts

; guard rail a paletti: una riga su quattro resta vuota
railchar
        lda stripecnt
        and #3
        beq rl_g
        lda #CH_RAIL
        rts
rl_g    lda sidechar
        rts

;--------------------------------------------------------------
; TRAFFICO: scende, ondeggia con moto sinusoidale e resta
; sempre dentro la carreggiata della propria riga
;--------------------------------------------------------------
updene
        ldx #2
ue_lp   lda speed               ; si avvicina in base alla marcia
        clc
        adc enebonus            ; +veloce dopo 6000 e 8000 punti
        adc eney,x
        sta eney,x
        cmp #250
        bcc ue_mv
        lda #10                 ; rientra dall'alto
        sta eney,x
        jsr getrnd
        and #7
        sec
        sbc #3
        sta eneoff,x
ue_mv
        ; onda sinusoidale (fase diversa per ogni auto)
        lda frame
        lsr
        lsr
        lsr
        sta tmpw
        txa
        asl
        clc
        adc tmpw
        and #7
        tay
        lda wavetab,y
        sta tmpw

        lda eney,x              ; riga video sotto l'auto
        sec
        sbc #50
        bcs ue_r1
        lda #8
ue_r1   lsr
        lsr
        lsr
        cmp #25
        bcc ue_r2
        lda #24
ue_r2   tay
        bne ue_r3
        ldy #1
ue_r3
        lda #CENTER             ; colonna = centro + corsia + onda
        clc
        adc eneoff,x
        clc
        adc tmpw
        sta tmpc
        lda halftab,y           ; dentro la strada di quella riga
        sec
        sbc #2
        sta tmpw
        lda #CENTER
        sec
        sbc tmpw
        cmp tmpc
        bcc ue_cm
        sta tmpc
ue_cm   lda #CENTER
        clc
        adc tmpw
        cmp tmpc
        bcs ue_co
        sta tmpc
ue_co   lda tmpc
        jsr coltopix
        lda tmpl
        sta enexl,x             ; memorizza per le collisioni
        lda tmph
        sta enexh,x

        ; registri sprite: auto = x+1, faro = x+5
        lda eney,x
        pha
        txa
        asl
        tay
        lda tmpl
        sta $d002,y             ; X auto
        sta $d00a,y             ; X faro
        pla
        sta $d003,y             ; Y auto
        cmp #60
        bcs ue_by
        lda #19                 ; faro nascosto vicino al bordo alto
ue_by   sec
        sbc #19
        sta $d00b,y             ; Y faro (cono davanti all'auto)
        lda tmph
        beq ue_m0
        lda $d010
        ora enemask,x
        ora beammask,x
        sta $d010
        jmp ue_nx
ue_m0   lda enemask,x
        ora beammask,x
        eor #$ff
        and $d010
        sta $d010
ue_nx   dex
        bmi ue_end
        jmp ue_lp
ue_end  rts

;--------------------------------------------------------------
; sprite del giocatore (e relativo faro)
;--------------------------------------------------------------
updplay
        lda pxl
        sta $d000
        sta $d008               ; faro
        lda #PY-22
        sta $d009
        lda pxh
        beq up_m0
        lda $d010
        ora #$11
        sta $d010
        rts
up_m0   lda $d010
        and #$ee
        sta $d010
        rts

;--------------------------------------------------------------
; colonna (A) -> pixel: tmpl/tmph = colonna*8+16
;--------------------------------------------------------------
coltopix
        sta tmpl
        lda #0
        sta tmph
        asl tmpl
        rol tmph
        asl tmpl
        rol tmph
        asl tmpl
        rol tmph
        lda tmpl
        clc
        adc #16
        sta tmpl
        bcc cp_ok
        inc tmph
cp_ok   rts

;--------------------------------------------------------------
; PUNTEGGIO: 4 cifre BCD, bloccato a 9999 come nell'originale
;--------------------------------------------------------------
addpoint
        lda capflag
        bne ap_x
        sed
        clc
        lda score
        adc #1
        sta score
        lda score+1
        adc #0
        sta score+1
        cld
        bcc ap_x
        lda #$99                ; tetto raggiunto
        sta score
        sta score+1
        inc capflag
ap_x    rts

; soglie 2000/4000/6000/8000: una vita extra (mai oltre 5);
; il traffico accelera alle ultime due
chkbonus
        lda nextbonus
        cmp #$ff
        beq cb_x
        lda score+1
        cmp nextbonus
        bcc cb_x
        lda lives
        cmp #MAXLIVES
        bcs cb_pl               ; gia' al massimo
        inc lives
cb_pl   jsr printlives
        lda nextbonus
        cmp #$60
        bcc cb_inc
        inc enebonus
cb_inc  lda nextbonus
        cmp #$80
        bne cb_add
        lda #$ff
        sta nextbonus
        rts
cb_add  sed
        clc
        adc #$20
        sta nextbonus
        cld
cb_x    rts

printscore
        ldx #0
        lda score+1
        jsr prbyte
        lda score
prbyte  pha
        lsr
        lsr
        lsr
        lsr
        jsr prdig
        pla
        and #15
prdig   clc
        adc #48
        sta SCREEN+7,x
        inx
        rts

; cronometro di sopravvivenza: 4 cifre
prtime
        ldx #0
        lda etime+1
        jsr ptbyte
        lda etime
ptbyte  pha
        lsr
        lsr
        lsr
        lsr
        jsr ptdig
        pla
        and #15
ptdig   clc
        adc #48
        sta SCREEN+19,x
        inx
        rts

printlives
        lda lives
        clc
        adc #48
        sta SCREEN+31
        rts

;--------------------------------------------------------------
; COLLISIONI via software (riquadri), cosi' i coni di luce
; dei fari non contano come urti
;--------------------------------------------------------------
checkcol
        lda crashtimer          ; invulnerabile dopo un incidente
        beq cc_a
        dec crashtimer
        rts
cc_a    ldx #2
cc_el   lda eney,x              ; distanza verticale
        sec
        sbc #PY
        bcs cc_p
        eor #$ff
        adc #1
cc_p    cmp #18
        bcs cc_nx
        lda enexl,x             ; distanza orizzontale (16 bit)
        sec
        sbc pxl
        sta tmpl
        lda enexh,x
        sbc pxh
        bpl cc_q
        eor #$ff                ; valore assoluto
        sta tmph
        lda tmpl
        eor #$ff
        clc
        adc #1
        sta tmpl
        lda tmph
        adc #0
        sta tmph
        jmp cc_r
cc_q    sta tmph
cc_r    lda tmph
        bne cc_nx
        lda tmpl
        cmp #16
        bcc cc_hit
cc_nx   dex
        bpl cc_el

        ; --- fuoristrada: oltre il guard rail della riga ---
        lda pxl
        sec
        sbc #12
        sta tmpl
        lda pxh
        sbc #0
        sta tmph
        lsr tmph
        ror tmpl
        lsr tmph
        ror tmpl
        lsr tmph
        ror tmpl
        lda tmpl
        sec
        sbc #CENTER
        bpl cc_ab
        eor #$ff
        clc
        adc #1
cc_ab   cmp halftab+PROW
        bcc cc_ok
        jmp docrash
cc_hit  jmp docrash
cc_ok   rts

;--------------------------------------------------------------
; INCIDENTE: esplosione animata, una vita in meno;
; a zero vite -> game over e ritorno al menu
;--------------------------------------------------------------
docrash
        jsr explode
        dec lives
        bne dc_lv
        jmp gameover
dc_lv   jsr printlives
        lda #CENTER             ; auto nuova al centro strada
        jsr coltopix
        lda tmpl
        sta pxl
        lda tmph
        sta pxh
        lda #0
        sta vx
        jsr updplay
        lda #80
        sta crashtimer
        rts

;--------------------------------------------------------------
; esplosione: due fotogrammi alternati, colori e rumore
;--------------------------------------------------------------
explode
        lda #$06
        sta $d408
        lda #$0c
        sta $d409
        lda #$00
        sta $d40a
        lda #$81                ; rumore, gate on
        sta $d40b
        ldx #48
ex_fr   txa
        and #4
        bne ex_f2
        lda #130
        bne ex_sp
ex_f2   lda #131
ex_sp   sta SCREEN+$3f8         ; cambia fotogramma
        txa
        and #15
        sta $d027               ; colori impazziti
ex_w1   lda $d012
        cmp #$fb
        bne ex_w1
ex_w2   lda $d012
        cmp #$fb
        beq ex_w2
        dex
        bne ex_fr
        lda #$80                ; gate off
        sta $d40b
        lda #128                ; ripristina l'auto
        sta SCREEN+$3f8
        lda #2
        sta $d027
        rts

;--------------------------------------------------------------
; GAME OVER: messaggio, registrazione del tempo in classifica
; e ritorno al menu
;--------------------------------------------------------------
gameover
        lda #$20                ; spegne il motore
        sta $d404
        jsr printlives
        ldx #8
go_t1   lda txtgameover,x
        sta SCREEN+11*40+15,x
        dex
        bpl go_t1
        lda #150                ; pausa di ~3 secondi
        sta tmpcnt
go_d    jsr waitfr
        dec tmpcnt
        bne go_d
        jsr savetime            ; registra il tempo (se in top 10)
        jmp menu

;--------------------------------------------------------------
; numero casuale dall'oscillatore a rumore della voce 3
;--------------------------------------------------------------
getrnd
        lda $d41b
        rts

;--------------------------------------------------------------
; schermo di gioco: erba + riga di stato in alto
;--------------------------------------------------------------
fillfield
        ldx #0
ff_l    lda #CH_GRASS
        sta SCREEN,x
        sta SCREEN+250,x
        sta SCREEN+500,x
        sta SCREEN+750,x
        inx
        cpx #250
        bne ff_l
        ldx #39
        lda #CH_ROAD
ff_r0   sta SCREEN,x
        dex
        bpl ff_r0
        ldx #4
ff_t1   lda txtpunti,x
        sta SCREEN+1,x
        dex
        bpl ff_t1
        ldx #4
ff_t2   lda txttempo,x
        sta SCREEN+13,x
        dex
        bpl ff_t2
        ldx #3
ff_t3   lda txtvite,x
        sta SCREEN+26,x
        dex
        bpl ff_t3
        rts

;--------------------------------------------------------------
; DATI
;--------------------------------------------------------------
; circuito: i tratti si ripetono sempre nello stesso ordine
secttypes   !byte T_NORM,T_ICE,T_NORM,T_TUNNEL,T_NORM,T_GRAVEL,T_NORM,T_BRIDGE
sectlens    !byte 70,45,50,55,50,45,50,40
; semilarghezza per tipo: normale, ghiaccio, galleria, ghiaia, ponte
secthalfs   !byte 7,6,6,7,3

; onda sinusoidale del traffico (-1, 0, +1)
wavetab     !byte 0,1,1,0,0,$ff,$ff,0

txtpunti    !byte 16,21,14,20,9                 ; "PUNTI"
txttempo    !byte 20,5,13,16,15                 ; "TEMPO"
txtvite     !byte 22,9,20,5                     ; "VITE"
txtgameover !byte 7,1,13,5,32,15,22,5,18        ; "GAME OVER"
txttitle    !byte 13,15,14,1,3,15,32,18,1,3,5,18        ; "MONACO RACER"
; "FABRIZIO RADICA 2026" (20 caratteri)
txtnome     !scr "FABRIZIO RADICA 2026"
txtbest     !byte 13,9,7,12,9,15,18,9,32,20,5,13,16,9   ; "MIGLIORI TEMPI"
; "PREMI FUOCO PER INIZIARE"
txtstart    !byte 16,18,5,13,9,32,6,21,15,3,15,32
            !byte 16,5,18,32,9,14,9,26,9,1,18,5

enemask     !byte %00000010,%00000100,%00001000
beammask    !byte %00100000,%01000000,%10000000

; tile ridefinite: 1=mezzeria, 2=ciuffi d'erba, 3=ghiaia
customchr
        !byte %00011000,%00011000,%00011000,%00011000
        !byte %00011000,%00011000,%00011000,%00011000
        !byte %00000000,%00100100,%00000000,%00000000
        !byte %00000000,%01000010,%00000000,%00000000
        !byte %10001000,%00000000,%00100010,%00000000
        !byte %10001000,%00000000,%00100010,%00000000

;--------------------------------------------------------------
; VARIABILI
;--------------------------------------------------------------
score       !byte 0,0           ; punteggio BCD (4 cifre)
capflag     !byte 0             ; punteggio bloccato a 9999
etime       !byte 0,0           ; secondi di sopravvivenza (BCD)
tick        !byte 0
lives       !byte 0
nextbonus   !byte 0             ; prossima soglia (BCD, centinaia)
enebonus    !byte 0             ; traffico extra-veloce
speed       !byte 0             ; marcia: 1 o 2
spdcnt      !byte 0
ptscnt      !byte 0
frame       !byte 0
stripecnt   !byte 0
crashtimer  !byte 0
joyval      !byte 0
vx          !byte 0             ; velocita' laterale (con segno)
pxl         !byte 0
pxh         !byte 0
tmpl        !byte 0
tmph        !byte 0
tmpc        !byte 0
tmpw        !byte 0
tmpcnt      !byte 0
sidechar    !byte 0
roadchr     !byte 0
sectidx     !byte 0
sectcnt     !byte 0
curtype     !byte 0
curhalf     !byte 0
targethalf  !byte 0
widthtimer  !byte 0
eney        !byte 0,0,0
eneoff      !byte 0,0,0
enexl       !byte 0,0,0
enexh       !byte 0,0,0
halftab     !fill 25,7
typetab     !fill 25,0
; classifica: 10 voci da 2 byte BCD (alto, basso), decrescente;
; vive in RAM e resta valida tra una partita e l'altra
hitab       !fill 20,0

;==============================================================
; SPRITE (24x21)
;==============================================================
* = $2000

; --- 128: monoposto del giocatore ---
sprplayer
        !byte $00,$ff,$00
        !byte $00,$ff,$00
        !byte $30,$ff,$0c
        !byte $3c,$ff,$3c
        !byte $3c,$ff,$3c
        !byte $30,$ff,$0c
        !byte $00,$ff,$00
        !byte $00,$7e,$00
        !byte $00,$7e,$00
        !byte $00,$7e,$00
        !byte $00,$ff,$00
        !byte $00,$ff,$00
        !byte $01,$ff,$80
        !byte $33,$ff,$cc
        !byte $3f,$ff,$fc
        !byte $3f,$ff,$fc
        !byte $33,$ff,$cc
        !byte $03,$ff,$c0
        !byte $00,$ff,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00

; --- 129: auto del traffico ---
sprenemy
        !byte $01,$ff,$80
        !byte $01,$ff,$80
        !byte $31,$ff,$8c
        !byte $3d,$ff,$bc
        !byte $3d,$ff,$bc
        !byte $31,$ff,$8c
        !byte $01,$ff,$80
        !byte $01,$ff,$80
        !byte $00,$ff,$00
        !byte $00,$ff,$00
        !byte $01,$ff,$80
        !byte $01,$ff,$80
        !byte $31,$ff,$8c
        !byte $3d,$ff,$bc
        !byte $3d,$ff,$bc
        !byte $31,$ff,$8c
        !byte $01,$ff,$80
        !byte $01,$ff,$80
        !byte $00,$7e,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00

; --- 130: esplosione, fotogramma 1 ---
sprexpl1
        !byte $00,$10,$00
        !byte $04,$10,$20
        !byte $02,$38,$40
        !byte $00,$7c,$00
        !byte $31,$fe,$8c
        !byte $03,$ff,$c0
        !byte $0f,$ff,$f0
        !byte $03,$ff,$c0
        !byte $31,$fe,$8c
        !byte $00,$7c,$00
        !byte $02,$38,$40
        !byte $04,$10,$20
        !byte $00,$10,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00

; --- 131: esplosione, fotogramma 2 (piu' grande) ---
sprexpl2
        !byte $10,$10,$08
        !byte $08,$38,$10
        !byte $04,$7c,$20
        !byte $32,$fe,$4c
        !byte $01,$ff,$80
        !byte $4f,$ff,$f2
        !byte $1f,$ff,$f8
        !byte $4f,$ff,$f2
        !byte $01,$ff,$80
        !byte $32,$fe,$4c
        !byte $04,$7c,$20
        !byte $08,$38,$10
        !byte $10,$10,$08
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00

; --- 132: cono di luce dei fari (per la galleria) ---
sprbeam
        !byte $7f,$ff,$fe
        !byte $7f,$ff,$fe
        !byte $3f,$ff,$fc
        !byte $3f,$ff,$fc
        !byte $1f,$ff,$f8
        !byte $1f,$ff,$f8
        !byte $0f,$ff,$f0
        !byte $0f,$ff,$f0
        !byte $07,$ff,$e0
        !byte $07,$ff,$e0
        !byte $03,$ff,$c0
        !byte $03,$ff,$c0
        !byte $01,$ff,$80
        !byte $01,$ff,$80
        !byte $00,$ff,$00
        !byte $00,$ff,$00
        !byte $00,$7e,$00
        !byte $00,$7e,$00
        !byte $00,$3c,$00
        !byte $00,$00,$00
        !byte $00,$00,$00
        !byte $00
