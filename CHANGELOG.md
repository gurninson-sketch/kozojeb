# Zmiany

## 2.9.13

- Pierwszy podział golemów używa wspólnej kolejności nazw członków i opisów NPC. Lokalne ID oraz niewielkie różnice HP nie przestawiają pozostałych miejsc. Komenda nadal wskazuje lokalny indeks żywego golema. Dla identycznych opisów używana jest kolejność lokalna; sam tekst nie identyfikuje egzemplarza.
- Widoczna udana zasłona rezerwuje konkretnego NPC, również przed aktualizacją GMCP. Stabilizacja obejmuje kolejne przejęcia przez trzecią osobę, nie tylko bezpośredni powrót. Niejednoznaczny opis rezerwuje pasujące egzemplarze zamiast zgadywać ID. Ratowanie zagrożonej osoby zachowuje pierwszeństwo przy dotychczasowych ograniczeniach HP, gotowości szyku i liczby napastników.
- Nieudana para NPC–osoba ma do 15 s przerwy przed zwykłym ponowieniem. Zastępstwa są rozdzielone według nazw profili i wybierają najpierw większe obciążenie. Pilny stan skraca oczekiwanie. Bufor planów opiera się na istotnym stanie, a nie samym nadejściu kolejnego identycznego pakietu. Rozłączenie i zmiana pokoju czyszczą stare rezerwacje.
- Prowadzący podnosi pancerz natychmiast po potwierdzonym zabiciu golema. Równoczesne zgony korzystają z jednej kolejki i jednego aktywnego timera podniesienia. Duplikat zgonu i późniejsza linia XP nie powielają komendy. Przejściowy brak dopuszcza jedną opóźnioną powtórkę; duplikaty odmowy nie tworzą nowych timerów. Pilny odwrót ma pierwszeństwo. Role wspierające nie zbierają łupu.
- Rozpoznawane jest zabranie pancerza z ziemi i spalenie go przez żywego golema. Przechwycony przedmiot nie powiększa ładunku i nie powoduje kolejnych pustych prób. Rozpad przedmiotów na ziemi pozostaje osobnym zdarzeniem. Powrót do bazy, przeszukiwanie, odkładanie i regeneracja całej drużyny do rzeczywistych 100% zachowują dotychczasowe potwierdzenia. Należy wyłączyć stary dodatkowy trigger pancerzy.
- Tekstowe odpytywanie kondycji czeka podczas przeszukiwania; monitorowanie HP przez GMCP nadal działa. Notatka zasłony zawiera opis i lokalne ID NPC, a panel wydajności liczbę przeliczeń planu. Bez komunikacji między profilami, nadpisania `send`, stałej nowej pętli i skanowania każdej linii obrażeń.
- Ułamkowy procent HP jest zaokrąglany wyłącznie do wyświetlenia w notatce. Ocena zasłony nadal używa rzeczywistych wartości HP; zapis notatki jest zgodny również z Lua 5.4.
- 35 nowych symulacji: różne ID i drobne różnice HP między profilami, częściowy podział napastników, widoczne rezerwacje, przejęcie przez trzecią osobę, ratunkowe HP, porażki i zastępstwa, natychmiastowy łup, cztery kompletne pancerze, trzy po spaleniu czwartego, równoczesne zgony, brak odpowiedzi i rozłączenie, odwrót, ograniczenia ról, ułamkowy procent HP oraz serie 2000 zdarzeń. Razem 502 symulacje bota i 30 aktualizatora; dodatkowo rzeczywiste wzorce komunikatów, SHA-256, zgodność źródeł i powtarzalność paczki.

## 2.9.12

- Hotfix „podniesione cztery, przeszukane trzy”: potwierdzenie podniesienia jest liczone również w krótkiej fazie po ostatnim zabiciu i podczas powrotu. Licznik zebranego ładunku nie jest już obcinany do początkowej liczby NPC. Późniejszy odbiór pancerza w bazie rozszerza trwający cykl.
- Rozpoznawanie liczby sztuk w odpowiedziach podniesienia, wyjęcia z plecaka i odłożenia. Przenoszenie znanych pancerzy między plecakiem i ekwipunkiem nie podwaja ładunku. Nieznana liczba nie jest zgadywana jako jedna sztuka.
- Potwierdzone wkładanie pancerzy do plecaka jest zapamiętywane. Prowadzący w bazie otwiera plecak i wyjmuje pancerze przed kolejnym przeszukaniem. Brak potwierdzenia blokuje patrol z podaną przyczyną, bez powtarzania komend. Rozłączenie zachowuje ten etap. Dodatkowy stary trigger nadal zaleca się wyłączyć.
- Ujemna odpowiedź przeszukiwania przy niepustym liczniku oraz `Odloz co?` nie zmniejszają ładunku ani nie oznaczają jego zakończenia. Powrót po ewakuacji zachowuje nieobsłużone pancerze. Panel pokazuje liczbę pozostałą i schowaną w plecaku; ponowne `golemy on` nie kasuje aktywnego cyklu.
- 14 nowych symulacji obejmuje czwarty pancerz w fazie kończenia walki, opóźnione podniesienie, podniesienie wielu sztuk, trzy pancerze w plecaku, większy ładunek, brakujące potwierdzenia, rozłączenie podczas wyjmowania, powtórne włączenie trybu i zachowanie ładunku po leczeniu. Łącznie 467 symulacji bota i 30 aktualizatora, wzorce rzeczywistych odpowiedzi, SHA-256 oraz integralność i powtarzalność paczki.

## 2.9.11

- Opcjonalny tryb `/kozojeb golemy on|off|status`, domyślnie wyłączony. Celowane zasłony `zaslon <osobe> przed pierwszym|drugim|trzecim|czwartym golemem` rozdzielają różne NPC między obrońców już na początku walki. Plan opiera się na bieżących ID i lokalnej kolejności żywych golemów, bez komunikacji między profilami. Czysty pokój z najwyżej czterema golemami i wystarczającą drużyną otrzymuje lokalny wyjątek od zwykłego limitu celów; globalny limit pozostaje zapisany bez zmian.
- Dalsze rotacje pojedynczego golema dążą do wyrównania procentów HP. Domyślny próg to 10 punktów procentowych, konfigurowany przez `golemy roznicahp 5–30`. Wyższy procent nie wystarcza: porównywalna rezerwa rzeczywistych HP musi być co najmniej o 15% większa. Nadal obowiązują minimum własnego HP, limit napastników, gotowość szyku i stabilizacja przejęć. Zwykłe zasłony poza trybem zachowują ostrożną ocenę pełnego przejęcia z 2.9.10.
- Prowadzący po oczyszczeniu pokoju zbiera pancerze pojedynczym `wez pancerz`, wraca z drużyną do kozobazy i serialnie przeszukuje oraz odkłada potwierdzony ładunek. Kolejny pancerz czeka na zakończenie przeszukiwania i potwierdzenie odłożenia poprzedniego. Rozpad pancerza leżącego na ziemi nie pomija odłożenia pancerza z ekwipunku. Należy wyłączyć stary dodatkowy trigger pancerzy; główny moduł łupienia Chimery nie jest zastępowany.
- Patrol w trybie golemów wznawia się automatycznie po obsłużeniu pancerzy i osiągnięciu rzeczywistych 100% HP całej obecnej drużyny. Zaokrąglony odczyt 100% nie wystarcza. Decyzje o ruchu i odwrocie nadal należą wyłącznie do prowadzącego; rola `wsparcie` nie wykonuje zasłon ani obsługi pancerzy.
- Etap pancerzy pozostaje zapamiętany po rozłączeniu. Niepewne odłożenie nie jest powtarzane w ciemno: po zalogowaniu najpierw następuje przeszukanie. Brak odpowiedzi ma ograniczony timer, po którym cykl czeka i nadal przyjmuje spóźnione potwierdzenie. Zadanie pozostaje aktywne do późniejszego wykrycia rozłączenia; ręczny stop, śmierć, zmiana roli i wyłączenie trybu anulują cykl. Świeży atak w bazie ma pierwszeństwo przed pancerzami.
- Plan zasłon korzysta z bufora i dotychczasowej kolejki decyzji. Moduł dołączany jest do głównego skryptu podczas budowania; paczka nadal zawiera trzy skrypty i zachowuje zgodność aktualizatora oraz kopii przywracania. Bez nowego stałego odpytywania, pętli po liniach obrażeń i nadpisywania `send`.
- 34 nowe symulacje obejmują różne perspektywy profili, rozdział czterech golemów przy pełnym HP, kolejność celów, różne pule HP, rotację, ograniczenia ról, obsługę czterech pancerzy, komunikat rozpadu z ziemi, 99,9% HP, nieobecnego członka, rozłączenia podczas zbierania/przeszukiwania/odkładania, spóźnione odpowiedzi, przerwanie zadania, atak w bazie i serie 2000 pakietów. Razem 453 symulacje bota i 30 aktualizatora; dodatkowo rzeczywiste wzorce tekstu, wektory SHA-256, wykonanie połączonego skryptu i powtarzalność paczki.

## 2.9.10

- Ocena zasłony obejmuje przejęcie od jednego do wszystkich widocznych napastników celu. Limit dotyczy sumy unikalnych NPC osłaniającego i celu. Odrzucana jest także zasłona mieszcząca się w limicie, jeśli pełne przejęcie nie poprawia oceny bezpieczeństwa o wymagane 15%. Wystarczają skrajne obciążenia, bez enumeracji podzbiorów i bez dodatkowej pętli. Notatka pokazuje maksymalną liczbę napastników po zasłonie.
- Zwykły spadek HP nie omija kolejki wszystkich obrońców ani krótkiego oczekiwania po potwierdzonej zasłonie kolegi. Krytyczny stan i brak zapasu na kolejny obserwowany cios nadal pomijają dodatkowe oczekiwanie. Rezerwacje pozostają ograniczone czasowo; minimum własnego HP, limit napastników, stabilizacja przejęć oraz decyzja prowadzącego o wspólnym odwrocie są zachowane.
- Room.Info odcina relacje walki poprzedniej lokacji, także przy ponownym pojawieniu się tego samego ID NPC. Wsparcie wymaga bieżącego ataku prowadzącego lub jego aktualnego komunikatu walki. Sam napastnik NPC nie oznacza rozpoczęcia walki przez prowadzącego.
- Przy opóźnionym GMCP jednoznaczny tekst ataku NPC potwierdza tylko konkretną parę NPC–członek drużyny w obecnym pokoju. Pozwala osłaniać oraz reagować na atak podczas leczenia. Tekst pomocy nie jest atakiem; niejednoznaczne opisy NPC i osoby spoza drużyny nie tworzą relacji. Nowy Combat.State zastępuje obserwacje, również gdy jest pusty. Zmiana pokoju, rozłączenie oraz śmierć lub zniknięcie NPC usuwają stary kontekst. Brak nowych zapytań, stałych timerów i komunikacji między profilami.
- Indeks nazw NPC współdzieli bufor encji. Duplikaty tekstu współdzielą jeden wpis i jedną kolejkę decyzji. Panel pokazuje stan danych walki, diagnostyka ich źródło; stary powód blokady zasłony nie przechodzi do nowej lokacji.
- 30 nowych symulacji obejmuje 9 napastników przy limicie 2, pełne przejęcie, wspólne ID, stabilizację wielu NPC, zmiany HP podczas oczekiwania, obie kolejności pakietów pokoju, bieżący atak przed GMCP, niejednoznaczne nazwy, pusty stan walki, odwrót, role, rozłączenie i serie 2000 zdarzeń. Razem 419 symulacji bota i 30 aktualizatora; dodatkowo rzeczywiste wzorce tekstu, wektory SHA-256 i integralność paczki.
- Zapisane role, progi, obszar, tempo i pauza po zabiciu pozostają zachowane. Komendy ręczne pozostają dostępne. Moduł łupienia głównej Chimery jest poza repozytorium; nie został podmieniony.

## 2.9.9

- Prowadzący dołącza do kolejności obrońców używanej przez profile `zaslony`. Odstęp kolejnych miejsc wynosi 0,45 s, najwyżej 1,35 s, zamiast 0,12 s / 0,36 s. Pozostaje ograniczone oczekiwanie na rzeczywisty wynik i świeże relacje GMCP, bez założenia, że pozostałe profile mają włączone zasłony. Dalsza utrata rzeczywistego HP i stan pilny pomijają dodatkowe oczekiwanie. Zachowane porównywalne pule HP, ocena presji, limit napastników i stabilizacja przejęć.
- Sprzeczna późniejsza odmowa `wesprzyj` nie kasuje wcześniejszego potwierdzenia własnej walki dla tej samej próby. Nowy, rzeczywisty zanik wcześniej widocznej własnej walki pozwala ponownie dołączyć; nowy cel prowadzącego oraz śmierć przeciwnika nadal zmieniają kontekst. Bez zgadywania składni celowanego wsparcia i bez komunikacji między profilami.
- Start prowadzącego w spokojnym pokoju sprawdza gotowość całej widocznej drużyny według `powrothp`, domyślnie 95%. Niepełny odczyt HP blokuje patrol. Krytyczny stan wymaga 100%, odpoczynek wznawia się po rozłączeniu, atak uruchamia istniejącą ewakuację. Ponowny start w trakcie leczenia lub powrotu nie usuwa krytycznych wymagań. Wspierający zachowują swoje role i brak własnego ruchu; start w trwającej walce zachowuje dotychczasowe decyzje bojowe.
- `/kozojeb diagnostyka` pokazuje liczniki, stan bota i czas od GMCP, własnego ciosu, postępu oraz decyzji. Watchdog wypisuje taki stan przed skasowaniem celu i rozpoczęciem powrotu. Stała liczba znaczników czasu, bez nowych timerów, rejestratora pakietów czy zapytań do gry. Nie jest to rozpoznanie przyczyny rozłączenia TCP.
- 27 nowych symulacji: wspólna kolejność prowadzącego i obrońców, odczyty HP z logu, opóźnione potwierdzenia, dalsze obrażenia, serie 2000 pakietów, sprzeczne odpowiedzi wsparcia, rzeczywisty powrót do walki, gotowość przy starcie, atak podczas odpoczynku, rozłączenie i diagnostyka przed resetem. Łącznie 389 symulacji bota i 30 aktualizatora, dodatkowo wektory SHA-256 i kontrola paczki.
- Zapisane role, tempo patrolu, pauza po zabiciu i progi pozostają zachowane. Moduł zbierania łupów głównych skryptów Chimery jest poza tym repozytorium; nie został zmieniony.

## 2.9.8

- Nowe spotkanie podczas patrolu ponad limitem celów jest pomijane także po automatycznej agresji NPC. Przyjęcie walki nie anuluje kroku wyjścia; dotyczy również ataku wyłącznie na kolegę i automatycznej odpowiedzi prowadzącego.
- Decyzja o pominięciu pozostaje do potwierdzenia zmiany pokoju. Ucieczka lub przypadkowa śmierć NPC nie uruchamia pościgu ani pauzy zatrzymującej wyjście. Zmniejszenie liczby przeciwników nie rozpoczyna nowego ataku w trakcie odchodzenia. Wcześniej wybrana walka, pościg i pełna pauza po zabiciu pozostają zachowane.
- Jeden oczekujący krok, ponowione opisy tego samego pokoju nie odblokowują następnego. Obsługa odrzuconych wyjść, odmowy z powodu zmęczenia i ograniczonego oczekiwania na potwierdzenie. Brak trasy podczas ataku, wyczerpanie budżetu prób lub przekroczenie czasu przekazuje sterowanie dotychczasowej procedurze odwrotu. Zachowane pilne HP, zasłony, zbieranie drużyny, brak własnego ruchu wspierających i automatyczne wznowienie po rozłączeniu.
- Licznik NPC jest buforowany dla niezmienionej listy encji i ustawień. Wyjście i jego potwierdzenie współdzielą istniejący timer ruchu; brak nowej stałej pętli, dodatkowych zapytań lub komunikacji między profilami. Panel i pomoc opisują pomijanie pokoju mimo agresji.
- 35 nowych symulacji odtwarza 7 NPC przy limicie 3, atak przed oceną i przed ruchem, panikę NPC, spóźnione pakiety, odrzucone wyjścia, brak mapy i potwierdzenia, zmęczenie, krytyczne HP, zasłony, zachowanie pościgu i pauzy, filtry licznika, rozłączenie oraz serie 2000 zdarzeń.

## 2.9.7

- Wspólny próg regeneracji całej drużyny, domyślnie 95% HP: `/kozojeb powrothp 95` na prowadzącym. Pełne HP pierwotnie wskazanego rannego nie pozwalają już wrócić z innym członkiem na 67%; niekrytyczne 99% jednej osoby nie blokuje gotowej drużyny. Ustawienie jest zapisywane; dotychczasowe role, zasłony, tempo i progi odwrotu pozostają zachowane.
- Spadek poniżej właściwego progu odwrotu od rozpoczęcia ewakuacji wymaga rzeczywistych 100% HP tej postaci, także przy zwykłym odwrocie i po rozłączeniu. Kolejne osoby nie zastępują wcześniejszych. Warunek używa pełnych par HP bez zaokrąglania 94,6% do wymaganych 95% ani 99,6% do pełnych 100%.
- Panel pokazuje wszystkich blokujących powrót wraz z wymaganym i bieżącym HP, brakującymi odczytami, obecnością oraz zmęczeniem. Obejmuje także nowych członków. Nadal obowiązują kontrola sprzętu, ruchu i zagrożenia w miejscu leczenia; wspierający nie podejmują własnego odwrotu ani nie wysyłają raportów.
- Ponowna ocena gotowości po drodze powrotnej przed wznowieniem patrolu. Jeden krótki timer uzgadnia pakiety przybycia; obrażenia lub brak gracza przedłużają odpoczynek, a świeży atak uruchamia dotychczasową ewakuację. Brak nowej stałej pętli i dodatkowego odpytywania gry.
- 34 nowe symulacje obejmują wspólne leczenie, różne pule HP, progi bez zaokrągleń, wielu krytycznie rannych, zapis ustawień, brakujące dane i członków, zmęczenie, rozłączenie, obrażenia i atak po powrocie oraz scalanie serii pakietów.

## 2.9.6

- Rola `zaslony` chroni zagrożonych członków całej drużyny. `proglidera` zachowuje osobny próg prowadzącego, a `progzaslony` steruje pozostałymi członkami. Rola `wsparcie` pozostaje drugą linią; decyzja o wspólnym odwrocie nadal należy do prowadzącego.
- Wybór osoby do osłony według presji NPC i zapasu HP w punktach z uwzględnieniem ostatnich obrażeń. Kolejka obrońców porównuje przewidywane ryzyko po osłonie na wspólnej skali HP; własny procent nie obniża odczytu HP innego obrońcy. Zachowane minimum własnego HP, poprawa oceny bezpieczeństwa, limit napastników i stabilizacja przejęć.
- Krótkie oczekiwanie na lepiej przygotowanego obrońcę nie uruchamia osłony mniej zagrożonego celu. Potwierdzenia zasłon kolegów obejmują całą drużynę i nie nadpisują kontekstu innej osoby. Stara historia przejęcia nie zastępuje potwierdzenia nowej próby.
- Prowadzący uwzględnia widoczną udaną osłonę kolegi przez najwyżej 0,5 s na świeże relacje. Powtórki nie przedłużają oczekiwania; dalsze obrażenia, krytyczne HP lub inne zagrożenie zachowują pierwszeństwo. Potwierdzenia współdzielą jeden krótko działający timer.
- Rozpoznawanie tekstu `zrecznie zaslania` z poprawnym imieniem wykonawcy. Ręczne ustawienie nowej bazy usuwa stary awaryjny cel odwrotu. Pomoc i panel opisują aktualne zachowanie i wersję.
- 31 nowych symulacji ochrony członków drużyny, różnych pul HP, priorytetów, blokad, stabilizacji, rozdzielonych potwierdzeń i serii 2000 zdarzeń. Dodatkowe sprawdzenie zarejestrowanych wzorców na komunikatach z logów. Brak nowych stałych timerów i raportowania między profilami.

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
