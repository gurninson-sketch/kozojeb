# Zmiany

## 2.9.5

- Ochrona drużyny działa również podczas leczenia: świeży atak NPC w miejscu odpoczynku uruchamia wspólne awaryjne wyjście prowadzącego. Brak wyjścia lub faktyczna odmowa ruchu nie wyłącza bezpiecznych zasłon.
- Ewakuacja korzysta ze zwykłych wyjść mapy, sprawdza sytuację po każdym potwierdzonym kroku i ma najwyżej trzy próby ruchu. Pomija odrzucone miejsca i wyjścia; obsługuje brak potwierdzenia oraz zmęczenie bez pętli komend. Nie nadaje sąsiednim pokojom gwarancji bezpieczeństwa.
- Potwierdzone awaryjne miejsce leczenia pozostaje celem kolejnych odwrotów w tym zadaniu. Oryginalny start patrolu, wymagane pełne HP i oczekiwanie na drużynę pozostają zachowane. Rozłączenie w trakcie kroku wznawia ewakuację albo rozpoznaje osiągnięte miejsce; stop, śmierć i zmiana roli ją anulują.
- Rozpoznawanie odpowiedzi o zepchnięciu sprzed osłanianej osoby. Dziesięciosekundowy odstęp dotyczy tylko tej osoby i jest niezależny od gotowości szyku. Prowadzący uwzględnia tę blokadę przy ocenie dostępności zasłony; zatrzymany bot nie wznawia się po wygaśnięciu ograniczenia.
- Własne ciosy odświeżają watchdog podczas opóźnienia listy encji, bez znoszenia wymogu świeżych danych dla komend. Zachowane wykrywanie rzeczywistego zastoju i ignorowanie tekstu po rozłączeniu.
- 34 nowe symulacje odtwarzają atak w bazie, krytyczne HP kolejnych członków i wymagane pełne leczenie, zablokowane wyjścia, limit kroków zachowany także po chwilowej ciszy, zmęczenie, powrót po leczeniu, rozłączenia, blokady pozycji, serię 2000 zdarzeń oraz watchdog.

## 2.9.4

- Prowadzący nie wycofuje drużyny tylko dlatego, że własna zasłona czeka jeszcze na odpowiedź lub świeże relacje walki. Oczekiwanie ograniczone do 2 s od komendy i do 0,5 s po sukcesie; krytyczne HP, dalsza utrata zdrowia i zagrożenie innego członka zachowują pierwszeństwo.
- Rozpoznane ręczne i zewnętrzne komendy `zaslon` rezerwują szyk również dla automatu. Spóźniona gotowość nie uwalnia trwającej próby. Stop/start zachowuje rezerwację bez samoczynnego uruchamiania bota. Obserwacja korzysta z `sysDataSendRequest`, bez podmiany `send`, blokowania ręcznych poleceń lub zapisu innych komend.
- Profile osłaniające rozkładają decyzje w czasie według przewidywanego obciążenia i punktów HP, z opóźnieniem najwyżej 0,36 s. Tekst zasłony kolegi pozwala krótko poczekać na relacje walki; zmiana napastników wymusza nową ocenę. Przy niskim HP prowadzącego dodatkowa zwłoka jest pomijana. Role, progi i limity pozostają zachowane; brak komunikacji między profilami.
- Notatka przy zasłonie pokazuje punkty HP oraz liczbę napastników osłaniającego i celu. Pamięć i timery są ograniczone; brak nowej stałej pętli lub rejestratora pakietów.
- Aktualizator pokazuje przyczynę błędu pobierania i ponawia błędy sieciowe lub przekroczenie czasu po 1, 5 i 15 minutach, najwyżej trzy razy. Każde ponowienie zaczyna od manifestu i zachowuje kontrolę rozmiaru oraz SHA-256. Okresowe sprawdzanie nie przerywa tej kolejki. Błędy integralności lub instalacji nie są ponawiane; ręczne sprawdzenie, wyłączenie aktualizacji i zmiana repozytorium obsługują anulowanie oczekiwania.
- 40 nowych symulacji regresji: opóźnione potwierdzenia zasłon, pilny odwrót, ręczne komendy, kilka profili, różne pule HP, seria 2000 pakietów, ograniczone ponowienia pobierania i czyszczenie timerów.

## 2.9.3

- Prowadzący przyjmuje potwierdzony własny cel tego samego dozwolonego gatunku, gdy ogólne `zabij fimira` wybrało innego NPC niż pierwszy wpis w GMCP. Własny atak ma pierwszeństwo przed `primary`; lista ignorowanych i ograniczenia gatunku nadal obowiązują.
- Najwyżej trzy niepotwierdzone próby ataku na dany cel w pokoju. Zmiany walki innych NPC i celów sojuszników nie odnawiają budżetu. Nowy pokój lub faktyczne odzyskanie i późniejsza utrata własnej walki pozwalają rozpocząć kolejny ograniczony cykl.
- Sygnał wsparcia jest związany z pokojem i żywymi NPC. Po zgonie stary tekst i stare relacje nie wystarczają do ponowienia wsparcia; nowa walka wznawia je automatycznie. Po odmowie analizowane są relacje prowadzącego i jego przeciwnika, zamiast całej walki w pokoju.
- Jawne `0 HP` śledzonego NPC rozpoczyna pauzę po zabiciu. Krótki kontekst zaginionego celu obsługuje opóźniony zgon bez skracania pauzy i bez przerywania nowej walki lub ruchu. Zachowany powrót po pościgu i ostrożna obsługa jednakowych opisów NPC.
- Watchdog porównuje HP osobno dla każdego kanału GMCP. Różne, niezmienione skale nie udają postępu; rzeczywiste zmiany mniejsze od zaokrąglonego procenta nadal odświeżają aktywność. Brak dodatkowego odpytywania gry i stałych timerów.
- 30 nowych symulacji regresji, w tym opóźnione dane, identyczne opisy, przełączanie skal HP, zachowanie pełnej pauzy, powrót po pościgu oraz ograniczenie ponowień. Dotychczasowe role, zasłony i obsługa zmęczenia pozostają objęte testami.

## 2.9.2

- Obsługa rzeczywistego pola `fatigue` Chimery: 0% oznacza wypoczęcie, 100% wyczerpanie. Progi `odpoczynek` nadal określają pozostałe siły do ruchu; pełna para `moves/maxmoves` jest obsługiwana zastępczo.
- Odmowa `Jestes tak zmeczony, ze nie mozesz isc [w tym kierunku].` zwalnia oczekiwanie na nieudany krok i wstrzymuje ruch bez oznaczania wyjścia jako błędnego. Wznowienie wymaga świeżego odczytu sił; stare HP i ruch sprzed odmowy nie wystarczają.
- Prowadzący uwzględnia dostępne odczyty zmęczenia drużyny i czeka na odpoczynek zmęczonego członka przed wznowieniem po odwrocie. Brak danych nie jest uznawany za potwierdzone wypoczęcie.
- Po własnym kroku patrolu lub pościgu prowadzący daje drużynie 1 s na przybycie. Przy pozostawionym członku blokuje nowy atak i dalszy patrol, wraca jednym potwierdzonym wyjściem mapy i odpoczywa. Kolejne nieudane przejścia wydłużają przerwę do 10, 20 i 30 s. Bez drogi powrotnej czeka na zebranie drużyny.
- Pilny odwrót ma pierwszeństwo przed zbieraniem drużyny; brakujący członkowie pozostają wymagani przed wznowieniem patrolu w bazie. Wspierający nadal nie wykonują własnego ruchu, odwrotu ani raportowania.
- Znane zmęczenie podczas powrotu przez `/idz` nie zużywa kolejnych prób dotarcia do bazy. Odpoczynek i zbieranie drużyny są kontynuowane po ponownym połączeniu; stop, zmiana roli i śmierć anulują oczekiwanie.
- Jeden timer tylko podczas wstrzymania ruchu; `stan` najwyżej co 10 s po własnej odmowie ruchu. Dodatkowe liczniki odpoczynków i powrotów po drużynę w `/kozojeb wydajnosc`.
- Testy odmów z logów, progów i kolejności źródeł zmęczenia, spóźnionego przybycia, powrotów po członka, stopniowego odpoczynku, priorytetu HP, ponownego łączenia i serii 2000 pakietów.

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
