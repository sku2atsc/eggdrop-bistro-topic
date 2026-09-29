#!/usr/bin/env tclsh
# =====================================================================
#  Tests fuer bistro-topic.tcl
#  Laeuft ohne Eggdrop: die Eggdrop-Befehle werden simuliert.
#  Aufruf:  tclsh tests/run.tcl
# =====================================================================

set root [file dirname [file dirname [file normalize [info script]]]]
set tmpbase [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}]
set tmp [file join $tmpbase bistro-test-[pid]]
file delete -force $tmp
file mkdir [file join $tmp scripts]
file copy -force [file join $root Bistro-Geburtstage.example.txt] \
                 [file join $tmp scripts Bistro-Geburtstage.txt]
cd $tmp

# ------------------------- Eggdrop-Stubs -------------------------
set ::TOPIC ""
set ::SENT  {}
set ::OP    1
proc putlog  {s}     {}
proc putdcc  {idx s} {}
proc bind    {args}  {}
proc utimer  {args}  {}
proc putserv {s} {
    lappend ::SENT $s
    if {[regexp {^TOPIC \S+ :(.*)$} $s -> t]} { set ::TOPIC $t }
}
proc validchan   {c} { return 1 }
proc botonchan   {c} { return 1 }
proc botisop     {c} { return $::OP }
proc botishalfop {c} { return 0 }
proc getchanmode {c} { return "+nt" }
proc isbotnick   {n} { return 0 }
proc topic       {c} { return $::TOPIC }

# Uhr steuerbar machen
rename clock _clock
set ::NOW [_clock seconds]
proc clock {sub args} {
    if {$sub eq "seconds"} { return $::NOW }
    return [_clock $sub {*}$args]
}
proc at {day} { set ::NOW [_clock scan "$day 00:01" -format "%Y-%m-%d %H:%M"] }

# ------------------------- Test-Helfer ---------------------------
set ::fails 0
set ::count 0
proc expect {name got want} {
    incr ::count
    if {$got ne $want} {
        incr ::fails
        puts "FAIL: $name"
        puts "      erwartet: $want"
        puts "      erhalten: $got"
    } else {
        puts "ok    $name"
    }
}
proc filelines {} {
    set fd [open scripts/Bistro-Geburtstage.txt r]
    set d [read $fd]
    close $fd
    return [split [string trimright $d "\n"] "\n"]
}

source [file join $root bistro-topic.tcl]

set W "Das Bistro-Team w\u00fcnscht"
set G "alles Gute zum Geburtstag!"

# ------------------------- Einlesen ------------------------------
expect "Beispieldatei: 7 Eintraege" [llength $::bistro::entries] 7

# ------------------------- Texte ---------------------------------
expect "zwei Namen am selben Tag" [::bistro::buildmsg 25 1 2026] "$W Carol und Dave $G"
expect "Geburtsjahr wird akzeptiert" [::bistro::buildmsg 15 3 2026] "$W Grace $G"
expect "29.02. im Nicht-Schaltjahr am 28.02." [::bistro::buildmsg 28 2 2027] "$W Frank $G"
expect "28.02. im Schaltjahr leer" [::bistro::buildmsg 28 2 2028] ""
expect "29.02. im Schaltjahr" [::bistro::buildmsg 29 2 2028] "$W Frank $G"
expect "Todestag" [::bistro::buildmsg 8 10 2026] "R.I.P. Bob (Robert) - Todestag: 08.10.2021"
expect "kein Todestag im Todesjahr" [::bistro::buildmsg 8 10 2021] ""
expect "Geburtstag Verstorbener" [::bistro::buildmsg 7 1 2026] \
       "Heute h\u00e4tte Bob (Robert) Geburtstag gehabt - unvergessen."
expect "normaler Tag leer" [::bistro::buildmsg 24 1 2026] ""

# ------------------------- Topic-Ablauf --------------------------
set ::TOPIC "Willkommen im Bistro "
at 2026-01-24; ::bistro::check
expect "normaler Tag: Topic unveraendert" $::TOPIC "Willkommen im Bistro "

at 2026-01-25; ::bistro::check
expect "Geburtstag gesetzt, kein doppeltes Leerzeichen" $::TOPIC \
       "Willkommen im Bistro | $W Carol und Dave $G"
expect "Meldung in #bistro-talk" [lindex $::SENT end] \
       "PRIVMSG #bistro-talk :Die Topic in #irc-bistro wurde gesetzt: $W Carol und Dave $G"

set n [llength $::SENT]
::bistro::check
expect "zweite Pruefung aendert nichts" [llength $::SENT] $n

at 2026-01-26; ::bistro::check
expect "Folgetag mit neuem Geburtstag" $::TOPIC \
       "Willkommen im Bistro | $W Erin $G"

at 2026-01-27; ::bistro::check
expect "alte Topic exakt wiederhergestellt" $::TOPIC "Willkommen im Bistro "

# Zusatz von Hand entfernt -> wird nicht erneut angehaengt
at 2026-01-03; ::bistro::check
set ::TOPIC "Von Hand geaendert"
::bistro::check
expect "von Hand entfernter Zusatz bleibt weg" $::TOPIC "Von Hand geaendert"
at 2026-01-04; ::bistro::check
expect "fremde Topic bleibt am Folgetag" $::TOPIC "Von Hand geaendert"

# vorderer Teil geaendert -> nur Zusatz entfernen
set ::TOPIC "Alt"
at 2026-01-25; ::bistro::check
set ::TOPIC "Neu | $W Carol und Dave $G"
at 2026-01-27; ::bistro::check
expect "nur der Zusatz wird entfernt" $::TOPIC "Neu"

# ohne Op keine Aenderung, danach nachholen
set ::OP 0
set ::TOPIC "X"
at 2026-03-15; ::bistro::check
expect "ohne Op keine Aenderung" $::TOPIC "X"
set ::OP 1
::bistro::check
expect "mit Op nachgeholt" $::TOPIC "X | $W Grace $G"

# Zustand uebersteht einen Neustart
array unset ::bistro::state
::bistro::loadstate
at 2026-03-16; ::bistro::check
expect "Wiederherstellung nach Neustart" $::TOPIC "X"

# ------------------------- Partyline -----------------------------
::bistro::dcc hand 1 "add Zed 30.01."
expect "add: Eintrag geladen" [llength $::bistro::entries] 8
set lines [filelines]
set iz [lsearch -glob $lines "Zed*"]
set ie [lsearch -glob $lines "Erin*"]
set ifr [lsearch -glob $lines "Frank*"]
expect "add: nach Datum einsortiert" [expr {$iz == $ie + 1 && $ifr == $iz + 1}] 1
expect "add: Tab-Layout" [lindex $lines $iz] "Zed\t\t\t30.01."

::bistro::dcc hand 1 "add zed 01.01."
expect "add: Duplikat abgelehnt" [llength $::bistro::entries] 8

::bistro::dcc hand 1 "rip Zed 01.02.2026"
expect "rip: Todesdatum gesetzt" [lindex [filelines] $iz] "Zed\t\t\t30.01.\t\t+ 01.02.2026"
::bistro::dcc hand 1 "rip Zed -"
expect "rip: Todesdatum entfernt" [lindex [filelines] $iz] "Zed\t\t\t30.01."

::bistro::dcc hand 1 "del Bob"
expect "del: Kurzname findet 'Bob (Robert)'" [lsearch -glob [filelines] "Bob*"] -1
::bistro::dcc hand 1 "del Zed"
expect "del: Eintraege" [llength $::bistro::entries] 6
expect "Sicherung angelegt" [file exists scripts/Bistro-Geburtstage.txt.bak] 1
expect "Kommentare bleiben erhalten" [expr {[lsearch -glob [filelines] "# Format*"] >= 0}] 1

# ------------------------- Latin-1 -------------------------------
set fd [open scripts/Bistro-Geburtstage.txt w]
fconfigure $fd -encoding iso8859-1
puts $fd "J\u00fcrgen\t\t\t01.05."
close $fd
set ::bistro::mtime -1
::bistro::load
expect "Latin-1 erkannt" [lindex $::bistro::entries 0 0] "J\u00fcrgen"
::bistro::dcc hand 1 "add Bj\u00f6rn 02.05."
set fd [open scripts/Bistro-Geburtstage.txt r]
fconfigure $fd -translation binary
set raw [read $fd]
close $fd
expect "Latin-1 bleibt beim Speichern erhalten" [expr {[string first "Bj\xf6rn" $raw] >= 0}] 1

# ------------------------- Ergebnis ------------------------------
cd $root
file delete -force $tmp
puts ""
puts "[expr {$::count - $::fails}] von $::count Tests bestanden."
exit [expr {$::fails > 0}]
