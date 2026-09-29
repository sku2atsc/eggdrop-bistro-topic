# =====================================================================
#  bistro-topic.tcl  v1.0
#  Geburtstage & Todestage im Topic von #irc-bistro
#  fuer Eggdrop 1.8.x (Tcl 8.5 / 8.6)
#  Lizenz: MIT - siehe LICENSE
#
#  - Liest die Datei Bistro-Geburtstage.txt (wird bei Aenderung
#    automatisch neu eingelesen, kein .rehash noetig)
#  - Haengt am Geburtstag/Todestag " | <Text>" an die Topic an
#  - Stellt am Folgetag die vorherige Topic wieder her
#  - Meldet das Setzen im Channel #bistro-talk
#  - Merkt sich den Zustand in einer .state-Datei (ueberlebt Neustarts)
#
#  Format der Datei (Leerzeichen/Tabs beliebig, # = Kommentar):
#     Name            TT.MM.[JJJJ]     [+ TT.MM.JJJJ]
#     DancingFo       03.01.
#     sacon (Juergen) 07.01.           + 08.10.2021
#  Zeilen ohne Datum (Ueberschriften, Striche) werden ignoriert.
#  Geburtstage am 29.02. werden in Nicht-Schaltjahren am 28.02. gefeiert.
#
#  Partyline-Befehle (Flag +m):
#     .bistro               Status + was heute ansteht
#     .bistro test TT.MM.   zeigt den Text fuer ein Datum
#     .bistro list          alle geladenen Eintraege
#     .bistro check         Pruefung sofort ausfuehren
#     .bistro reload        Datei neu einlesen
#     .bistro reset         gespeicherten Zustand verwerfen
#
#  Installation: Datei nach scripts/ kopieren und in eggdrop.conf
#     source scripts/bistro-topic.tcl
#  eintragen, dann .rehash
# =====================================================================

namespace eval ::bistro {

    # ------------------------- KONFIGURATION -------------------------
    # Channel, dessen Topic erweitert wird
    variable chan       "#irc-bistro"
    # Channel fuer die Info-Meldung ("" = keine Meldung)
    variable talkchan   "#bistro-talk"
    # Datenliste (relativ zum Eggdrop-Verzeichnis oder absoluter Pfad)
    variable datafile   "scripts/Bistro-Geburtstage.txt"
    # Hier merkt sich das Script die alte Topic
    variable statefile  "scripts/bistro-topic.state"
    # Zeichensatz der .txt: "auto", "utf-8" oder "iso8859-1"
    variable fileenc    "auto"
    # Zeichensatz fuer die IRC-Ausgabe.
    # Umlaute erscheinen als "Ã¼" o.ae.? -> hier "" eintragen.
    variable ircenc     "utf-8"
    # Trenner zwischen alter Topic und Zusatz
    variable sep        " | "
    # max. Topic-Laenge (TOPICLEN des Netzwerks, meist 300-390)
    variable maxlen     300
    # Am Geburtstag Verstorbener einen Gedenktext setzen? 1 = ja, 0 = nein
    variable deadbday   1

    # Texte (Umlaute als \u-Escapes, damit die Datei encoding-sicher ist)
    #   %names%  = Namen der Geburtstagskinder ("A, B und C")
    #   %name%   = Name, %date% = Todesdatum, %years% = Jahre seit Tod
    #   %chan%   = Channel, %msg% = gesetzter Topic-Zusatz
    variable txt_bday      "Das Bistro-Team w\u00fcnscht %names% alles Gute zum Geburtstag!"
    variable txt_death     "R.I.P. %name% - Todestag: %date%"
    variable txt_deadbday  "Heute h\u00e4tte %name% Geburtstag gehabt - unvergessen."
    variable txt_talk      "Die Topic in %chan% wurde gesetzt: %msg%"
    # Meldung in talkchan beim Zuruecksetzen ("" = keine)
    variable txt_restore   ""
    variable and_word      "und"
    # ------------------------------------------------------------------

    variable entries {}
    variable mtime   -1
    variable warned  ""
    variable joined
    variable state
}

# ---------------------------------------------------------------------
#  Datei einlesen (nur wenn sie sich geaendert hat)
# ---------------------------------------------------------------------
proc ::bistro::load {} {
    variable datafile
    variable fileenc
    variable entries
    variable mtime

    if {![file readable $datafile]} {
        if {$mtime != -2} {
            putlog "bistro: Datei $datafile nicht gefunden/lesbar!"
            set mtime -2
        }
        set entries {}
        return 0
    }
    set mt [file mtime $datafile]
    if {$mt == $mtime} { return 1 }

    set fd [open $datafile r]
    fconfigure $fd -translation binary
    set raw [read $fd]
    close $fd

    set enc $fileenc
    if {$enc eq "auto"} {
        # gueltiges UTF-8? sonst Latin-1 annehmen
        if {[encoding convertto utf-8 [encoding convertfrom utf-8 $raw]] eq $raw} {
            set enc utf-8
        } else {
            set enc iso8859-1
        }
    }
    set data [encoding convertfrom $enc $raw]

    set new {}
    set lineno 0
    foreach line [split $data "\n"] {
        incr lineno
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} { continue }
        # erstes Datum suchen -> alles davor ist der Name
        if {![regexp -indices {\s\d{1,2}\.\d{1,2}\.} $line pos]} { continue }
        set p    [lindex $pos 0]
        set name [string trim [string range $line 0 $p]]
        set rest [string trim [string range $line $p end]]
        if {$name eq ""} { continue }
        if {![regexp {^(\d{1,2})\.(\d{1,2})\.(\d{4})?\s*(?:\+\s*(\d{1,2})\.(\d{1,2})\.(\d{4}))?$} \
                  $rest -> bd bm by dd dm dy]} {
            putlog "bistro: Zeile $lineno nicht verstanden: $line"
            continue
        }
        # scan statt expr -> "08"/"09" werden nicht als Oktalzahl gelesen
        scan $bd %d bd
        scan $bm %d bm
        if {$bd < 1 || $bd > 31 || $bm < 1 || $bm > 12} {
            putlog "bistro: Zeile $lineno ungueltiges Datum: $line"
            continue
        }
        if {$dd ne ""} {
            scan $dd %d dd
            scan $dm %d dm
            scan $dy %d dy
            if {$dd < 1 || $dd > 31 || $dm < 1 || $dm > 12} {
                putlog "bistro: Zeile $lineno ungueltiges Todesdatum: $line"
                set dd ""; set dm ""; set dy ""
            }
        }
        lappend new [list $name $bd $bm $dd $dm $dy]
    }
    set entries $new
    set mtime $mt
    putlog "bistro: [llength $entries] Eintraege aus $datafile geladen ($enc)"
    return 1
}

# ---------------------------------------------------------------------
#  Hilfsfunktionen
# ---------------------------------------------------------------------
proc ::bistro::isleap {y} {
    expr {($y % 4 == 0 && $y % 100 != 0) || $y % 400 == 0}
}

# passt Tag/Monat (d m) auf das Datum (day month year)?
proc ::bistro::match {d m day month year} {
    if {$d == $day && $m == $month} { return 1 }
    if {$d == 29 && $m == 2 && $day == 28 && $month == 2 && ![isleap $year]} { return 1 }
    return 0
}

proc ::bistro::joinnames {names} {
    variable and_word
    if {[llength $names] == 1} { return [lindex $names 0] }
    return "[join [lrange $names 0 end-1] ", "] $and_word [lindex $names end]"
}

# Text fuer ein Datum bauen ("" = nichts los)
proc ::bistro::buildmsg {day month year} {
    variable entries
    variable deadbday
    variable txt_bday
    variable txt_death
    variable txt_deadbday
    variable sep

    set alive {}
    set parts {}
    foreach e $entries {
        foreach {name bd bm dd dm dy} $e break
        if {[match $bd $bm $day $month $year]} {
            if {$dd eq ""} {
                lappend alive $name
            } elseif {$deadbday} {
                lappend parts [string map [list %name% $name] $txt_deadbday]
            }
        }
        if {$dd ne "" && $year > $dy && [match $dd $dm $day $month $year]} {
            set date [format "%02d.%02d.%04d" $dd $dm $dy]
            lappend parts [string map [list %name% $name %date% $date \
                                            %years% [expr {$year - $dy}]] $txt_death]
        }
    }
    if {[llength $alive]} {
        set parts [linsert $parts 0 [string map [list %names% [joinnames $alive]] $txt_bday]]
    }
    return [join $parts $sep]
}

# Umwandlung fuer die IRC-Ausgabe
proc ::bistro::out {s} {
    variable ircenc
    if {$ircenc eq ""} { return $s }
    return [encoding convertto $ircenc $s]
}

# darf der Bot die Topic setzen?
proc ::bistro::cantopic {c} {
    if {[botisop $c]} { return 1 }
    if {![catch {botishalfop $c} r] && $r} { return 1 }
    set modes [lindex [split [getchanmode $c]] 0]
    return [expr {[string first "t" $modes] < 0}]
}

# neue Topic zusammensetzen, ggf. alte Topic kuerzen
proc ::bistro::compose {base suffix} {
    variable sep
    variable maxlen
    if {$base eq ""} { set t $suffix } else { set t "$base$sep$suffix" }
    if {[string length $t] <= $maxlen} { return $t }
    set keep [expr {$maxlen - [string length $sep] - [string length $suffix] - 3}]
    if {$keep < 10} { return [string range $suffix 0 [expr {$maxlen - 1}]] }
    set b [string range $base 0 [expr {$keep - 1}]]
    # keine halben Mehrbyte-Zeichen am Ende stehen lassen
    regsub {[\u0080-\u00ff]+$} $b "" b
    return "[string trimright $b]...$sep$suffix"
}

# Topic ermitteln, die am Folgetag wieder gesetzt werden soll
proc ::bistro::restorebase {cur} {
    variable state
    variable sep
    # niemand hat etwas geaendert -> exakt die alte Topic
    if {$cur eq $state(set)} { return $state(saved) }
    if {$state(suffix) ne ""} {
        if {$cur eq $state(suffix)} { return "" }
        # jemand hat den vorderen Teil geaendert -> nur unseren Zusatz entfernen
        set tail "$sep$state(suffix)"
        set i [string first $tail $cur]
        if {$i >= 0} {
            return [string replace $cur $i [expr {$i + [string length $tail] - 1}]]
        }
    }
    # Zusatz wurde schon von Hand entfernt -> Topic so lassen
    return $cur
}

proc ::bistro::talk {text} {
    variable talkchan
    if {$talkchan eq "" || ![validchan $talkchan] || ![botonchan $talkchan]} { return }
    putserv "PRIVMSG $talkchan :[out $text]"
}

# ---------------------------------------------------------------------
#  Zustand speichern / laden
# ---------------------------------------------------------------------
proc ::bistro::savestate {} {
    variable statefile
    variable state
    if {[catch {
        set fd [open $statefile w]
        fconfigure $fd -encoding utf-8
        puts $fd [array get state]
        close $fd
    } err]} {
        putlog "bistro: kann $statefile nicht schreiben: $err"
    }
}

proc ::bistro::loadstate {} {
    variable statefile
    variable state
    array set state {date "" saved "" set "" suffix "" done ""}
    if {![file readable $statefile]} { return }
    if {[catch {
        set fd [open $statefile r]
        fconfigure $fd -encoding utf-8
        set d [read -nonewline $fd]
        close $fd
        array set state $d
    } err]} {
        putlog "bistro: kann $statefile nicht lesen: $err"
    }
}

# ---------------------------------------------------------------------
#  Hauptpruefung (laeuft jede Minute)
# ---------------------------------------------------------------------
proc ::bistro::check {} {
    variable chan
    variable state
    variable joined
    variable sep
    variable warned
    variable txt_talk
    variable txt_restore

    if {![validchan $chan] || ![botonchan $chan]} { return }
    # kurz nach dem Join warten, bis die Topic sicher bekannt ist
    set lc [string tolower $chan]
    if {[info exists joined($lc)] && ([clock seconds] - $joined($lc)) < 30} { return }

    load
    set now   [clock seconds]
    set today [clock format $now -format %Y-%m-%d]
    set cur   [topic $chan]
    set base  $cur
    set restored 0
    set changed  0

    # 1) Zusatz vom Vortag entfernen
    if {$state(date) ne "" && $state(date) ne $today} {
        if {![cantopic $chan]} {
            if {$warned ne $today} {
                putlog "bistro: kann Topic in $chan nicht zuruecksetzen (kein Op?) - versuche es weiter."
                set warned $today
            }
            return
        }
        set base [restorebase $cur]
        array set state {date "" saved "" set "" suffix ""}
        set restored 1
        set changed 1
    }

    # 2) heutige Geburtstage/Todestage
    set msg ""
    set target $base
    if {$state(done) ne $today} {
        scan [clock format $now -format "%d %m %Y"] "%d %d %d" d m y
        set msg [buildmsg $d $m $y]
        if {$msg ne ""} {
            if {![cantopic $chan]} {
                if {$warned ne $today} {
                    putlog "bistro: kann Topic in $chan nicht setzen (kein Op?) - versuche es weiter."
                    set warned $today
                }
                return
            }
            set suffix [out $msg]
            # Zusatz evtl. schon vorhanden (z.B. Zustand verloren) -> nicht doppelt
            set i [string first "$sep$suffix" $base]
            if {$i >= 0} {
                set base [string replace $base $i [expr {$i + [string length "$sep$suffix"] - 1}]]
            } elseif {$base eq $suffix} {
                set base ""
            }
            set target [compose $base $suffix]
            array set state [list date $today saved $base set $target suffix $suffix]
        }
        set state(done) $today
        set changed 1
    }

    if {!$changed} { return }

    if {$target ne $cur} {
        putserv "TOPIC $chan :$target"
        if {$msg ne ""} {
            putlog "bistro: Topic gesetzt: $msg"
            talk [string map [list %chan% $chan %msg% $msg] $txt_talk]
        } elseif {$restored} {
            putlog "bistro: vorherige Topic in $chan wiederhergestellt"
            if {$txt_restore ne ""} {
                talk [string map [list %chan% $chan] $txt_restore]
            }
        }
    }
    savestate
}

proc ::bistro::safecheck {} {
    if {[catch {::bistro::check} err]} {
        putlog "bistro: Fehler: $err"
    }
}

proc ::bistro::tick {min hour day month year} {
    safecheck
}

proc ::bistro::onjoin {nick uhost hand chan} {
    variable joined
    if {![isbotnick $nick]} { return }
    set joined([string tolower $chan]) [clock seconds]
    utimer 40 ::bistro::safecheck
}

# ---------------------------------------------------------------------
#  Partyline
# ---------------------------------------------------------------------
proc ::bistro::dcc {hand idx text} {
    variable entries
    variable state
    variable mtime
    variable datafile

    set args [split [string trim $text]]
    set cmd  [string tolower [lindex $args 0]]
    set arg  [lindex $args 1]

    switch -- $cmd {
        "" - status {
            load
            scan [clock format [clock seconds] -format "%d %m %Y"] "%d %d %d" d m y
            set msg [buildmsg $d $m $y]
            putdcc $idx "bistro: [llength $entries] Eintraege aus $datafile"
            putdcc $idx "Heute: [expr {$msg eq "" ? "(nichts)" : $msg}]"
            if {$state(date) ne ""} {
                putdcc $idx "Aktiver Zusatz seit $state(date), gemerkte Topic: $state(saved)"
            } else {
                putdcc $idx "Kein aktiver Topic-Zusatz."
            }
            putdcc $idx "Zuletzt geprueft fuer: [expr {$state(done) eq "" ? "-" : $state(done)}]"
        }
        test {
            if {![regexp {^(\d{1,2})\.(\d{1,2})\.?(\d{4})?$} $arg -> d m y]} {
                putdcc $idx "Benutzung: .bistro test TT.MM.\[JJJJ\]"
                return 0
            }
            scan $d %d d
            scan $m %d m
            if {$y eq ""} { set y [clock format [clock seconds] -format %Y] }
            scan $y %d y
            load
            set msg [buildmsg $d $m $y]
            putdcc $idx "[format %02d.%02d.%04d $d $m $y]: [expr {$msg eq "" ? "(nichts)" : $msg}]"
        }
        list {
            load
            foreach e $entries {
                foreach {name bd bm dd dm dy} $e break
                set line [format "%-20s %02d.%02d." $name $bd $bm]
                if {$dd ne ""} { append line [format "   + %02d.%02d.%04d" $dd $dm $dy] }
                putdcc $idx $line
            }
            putdcc $idx "[llength $entries] Eintraege."
        }
        check {
            safecheck
            putdcc $idx "bistro: Pruefung ausgefuehrt."
        }
        reload {
            set mtime -1
            load
            putdcc $idx "bistro: [llength $entries] Eintraege geladen."
        }
        reset {
            array set state {date "" saved "" set "" suffix "" done ""}
            savestate
            putdcc $idx "bistro: Zustand zurueckgesetzt (Topic wurde nicht veraendert)."
        }
        default {
            putdcc $idx "Benutzung: .bistro \[status|test TT.MM.|list|check|reload|reset\]"
        }
    }
    return 1
}

# ---------------------------------------------------------------------
#  Start
# ---------------------------------------------------------------------
if {![info exists ::bistro::state(done)]} { ::bistro::loadstate }
if {![array exists ::bistro::joined]} { array set ::bistro::joined {} }

bind time - "* * * * *"           ::bistro::tick
bind join - "$::bistro::chan *"   ::bistro::onjoin
bind dcc  m bistro                ::bistro::dcc

::bistro::load
putlog "bistro-topic.tcl v1.0 geladen ([llength $::bistro::entries] Eintraege)"
