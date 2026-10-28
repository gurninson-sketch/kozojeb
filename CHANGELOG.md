# Zmiany

## 2.9.1

- Restart po powrocie do bazy zachowuje aktywne zadanie i czeka na spóźnione encje oraz kompletne HP. Ręczny stop nadal anuluje oczekiwanie.
- Watchdog rozpoznaje postęp HP ze wszystkich obsługiwanych kanałów i rzeczywiste własne ciosy; znacznik czasu nie wymaga odtwarzania timera.
- Własny atak na wybrany NPC ma pierwszeństwo przed sprzecznym `primary`. Niepotwierdzone ataki mają najwyżej trzy próby dla niezmienionych relacji, z odstępami 1 i 2 s.
- Wsparcie zachowuje potwierdzenie przy uzgodnieniu tekstu z ID NPC, nie ponawia odmów po identycznych relacjach i pomija potwierdzone zgony widoczne jeszcze w starych pakietach.
- Pamięć podręczna indeksu encji jest unieważniana przez zmianę danych pokoju zamiast przez każdy pakiet walki lub parametrów postaci.
- Prowadzący uwzględnia rezerwę na kolejny ostatnio obserwowany silny spadek HP; bezpieczna dostępna zasłona ma pierwszeństwo przed dodatkowym odwrotem drużyny.
- Poprawiona odmiana imienia w komunikacie o niedostępnej zasłonie. Rozszerzone liczniki wydajności bez dodatkowej pętli ani zapisu pakietów.
- Symulacje odtwarzają problemy z logów, spóźnione dane po restarcie, ograniczenie prób i unieważnianie pamięci podręcznej.

## 2.9.0

- Zasłony oceniają HP w punktach, liczbę napastników po przejęciu i ostatnie spadki HP; progi procentowe pozostają dodatkowymi warunkami.
- Nowszy pełny odczyt HP drużyny zastępuje starszy, z zachowaniem jednej skali przy porównywaniu postaci.
- Domyślny limit 2 napastników po zasłonie i stabilizacja przejęć po ID NPC zamiast reguły 5 punktów procentowych.
- Wcześniejszy wspólny odwrót prowadzącego przy nieskutecznej lub niebezpiecznej osłonie. Śmierć anuluje zadanie i wznowienie.
- Jedna kolejka decyzji dla serii GMCP, zachowana pilna kontrola HP, ponowne użycie odczytów i jeden watchdog bez odtwarzania timera po każdym pakiecie.
- Potwierdzanie własnej walki ogranicza powtarzanie wsparcia; odmowa wymaga nowych danych przed kolejną próbą.
- Stopniowe zwalnianie pustego patrolu do 3 s/krok oraz komenda `/kozojeb wydajnosc`.
- Testy różnych pul HP, przeciążenia, stabilizacji osłon, odmów wsparcia i serii 2000 pakietów.

## 2.8.4

- Naprawa blokady `reconnect_wait`, gdy po ponownym zalogowaniu nie przychodzą zdarzenia dla niezmienionych kanałów GMCP.
- Do wznowienia wystarcza świeży pokój i lista encji z własną postacią oraz kompletnym HP. Krótka pauza 0,5 s pozwala przetworzyć pozostałe pakiety logowania.
- Starsze dane walki i składu drużyny nadal są ignorowane do ich odświeżenia; brak opcjonalnego zdarzenia nie zatrzymuje aktywnego zadania na czas nieokreślony.
- Panel podaje konkretny brakujący odczyt lub członka drużyny. Ręczny stop anuluje również timer wznowienia.
- Testy regresji dla braku dodatkowych kanałów, niepełnego HP i 90-minutowego okresu bez kolejnych aktualizacji.

## 2.8.3

- Automatyczne wznowienie aktywnego zadania po utracie połączenia i ponownym zalogowaniu — bez ręcznej komendy `/kozojeb start`.
- Zachowanie bazy, obszaru i postępu patrolu; kontynuacja odwrotu, leczenia i powrotu. Nowy cel i krok są ustalane ze świeżych danych.
- Komendy pozostają wstrzymane podczas logowania. Wznowienie czeka na aktualne dane pokoju, postaci, HP/ruchu, walki i drużyny; prowadzący czeka na wcześniej widocznych członków drużyny.
- Wspierający automatycznie wracają do swoich ról i nadal nie wykonują własnego ruchu ani odwrotu.
- Ręczny stop i zmiana roli anulują oczekujące wznowienie. Wcześniej zatrzymany bot, nowo zainstalowana paczka oraz logowanie inną postacią nie uruchamiają zadania.
- Testy ponownych rozłączeń, kolejności danych, zachowania bazy, ról wspierających i leczenia.

## 2.8.2

- Naprawa mieszania odczytów własnego HP z `Char.Vitals` i `Room.Entities`: procent jest liczony wyłącznie z kompletnej pary `hp/maxhp` z jednego źródła.
- Przy niepełnych danych z obu źródeł, także podczas przechodzenia między pokojami, zachowywany jest ostatni poprawny wynik. Niepełny pakiet nie wywołuje fałszywego odwrotu ani wznowienia po leczeniu.
- Zachowane pierwszeństwo pełnych, nowych danych `Char.Vitals` oraz odwrót przy rzeczywistym spadku HP.
- Dodane testy regresji pętli odwrotu i instrukcja aktualizacji z wersji 2.8.1.

## 2.8.1

- Korekta informacji o autorze oryginalnego KozoBota: **Pipek**. Poprawiono opis projektu, informację o pochodzeniu i metadane paczki.

## 2.8.0

- Projekt rozwijany pod nazwą Kozojeb, z zachowaniem informacji o oryginalnym KozoBocie i jego autorze. Nowa komenda główna: `/kozojeb`.

- Zatrzymanie po rozłączeniu; blokada komend podczas logowania i oczekiwanie na świeże dane przed ręcznym wznowieniem.
- Wstrzymanie zasłon wspierającego po otrzymaniu osłony od prowadzącego, z marginesem 5 punktów procentowych HP przed ponownym przejęciem zagrożenia.
- Wspólny odwrót po pęknięciu własnego lub drużynowego ekwipunku. Wznowienie wymaga `/kozojeb ekwipunek gotowy`.
- Sprawdzanie wcześniej obecnych członków drużyny przed wznowieniem po leczeniu.
- Blokada ataku na dane poprzedniego pokoju po wysłaniu ruchu oraz pomijanie odrzuconego wyjścia.
- Relacje walki obcych NPC nie są uznawane za własną walkę prowadzącego.
- Świeży pakiet `Char.Vitals` ma pierwszeństwo przed starszym HP własnej postaci w encjach pokoju.
- Pełny zapis ustawień profilu i obszaru; migracja starszego pliku ustawień ról.
- Ograniczenie tekstowych zapytań o kondycję podczas leczenia i usunięcie nieobsługiwanego wywołania `/mm follow`.
- Aktualizator publicznych wydań GitHub: kontrola SHA-256, oczekiwanie na stop i koniec walki, kopia oraz próba przywrócenia poprzedniej wersji.
- Automatyczne testy i budowanie paczek przez GitHub Actions.

## 2.7.2

- Rezerwowanie szyku przy wysłaniu próby zasłony.
- Wybór chronionej osoby według kierunku relacji NPC → gracz.
- Niezależne minimum HP zasłaniającego.

## 2.7.1

- Usunięcie wszystkich dróg samodzielnego odwrotu wspierających.

## 2.7.0

- Role prowadzącego, drugiej linii oraz wsparcia z zasłonami.
- Automatyczne wykrywanie faktycznego prowadzącego przez GMCP.
- Odmiany imion i ustawienia ról osobno na każdym profilu.
