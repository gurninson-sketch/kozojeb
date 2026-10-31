# Chimera Kozojeb 2.9.12

[Pobierz najnowszą paczkę](https://github.com/gurninson-sketch/kozojeb/releases/latest/download/Chimera_Kozojeb.mpackage) · [Wydania](https://github.com/gurninson-sketch/kozojeb/releases)

**Kozojeb** jest rozwinięciem oryginalnego **KozoBota**, którego autorem jest **Pipek**. Zachowujemy autorstwo oryginału; nazwa Kozojeb oznacza rozwijaną tutaj wersję.

Bot do Mudleta: patrol, walka i role drużynowe w Chimerze. Prowadzącym może być dowolny profil. Pozostałe profile wspierają walkę zgodnie ze swoją rolą; decyzję o odwrocie podejmuje prowadzący, korzystając z danych drużyny w GMCP.

## Instalacja

1. Na każdym profilu zatrzymaj poprzedniego bota: `/kozo stop` w KozoBocie lub `/kozojeb stop` w Kozojebie. Poczekaj na zakończenie walki oraz ruchu.
2. W Menedżerze pakietów Mudleta usuń starszą paczkę **Chimera_Kozojeb** lub poprzedniego **Chimera_Kozobot**. Zachowaj główne skrypty Chimery.
3. Zainstaluj `Chimera_Kozojeb.mpackage` pobrany z **Releases** tego repozytorium. Pozostaw jedną wersję Kozojeba na profilu.
4. Wpisz `/kozojeb status` i sprawdź numer wersji.
5. Pozostaw wyłączone dodatkowe automatyczne wsparcie w głównych skryptach Chimery.

Do automatycznych aktualizacji wymagany jest Mudlet **4.20.0 lub nowszy**. Kod głównego bota jest zgodny z Lua 5.1 i 5.4; testy nie zastępują sprawdzenia w grze.

## Drużyna i role

Najpierw utwórz drużynę w grze. Rola bota nie przekazuje faktycznego prowadzenia drużyny.

| Profil — przykład | Komendy konfiguracji | Zachowanie |
| --- | --- | --- |
| Yarrim | `/kozojeb rola prowadzacy` | Patrol, wybór celów, pościg, zasłony drużyny i wspólny odwrót |
| Morrid, Yergo i Gror | `/kozojeb rola zaslony` oraz `/kozojeb lider auto` | Wsparcie i osłanianie zagrożonych członków całej drużyny |
| Opcjonalny profil drugiej linii | `/kozojeb rola wsparcie` oraz `/kozojeb lider auto` | Wsparcie i DPS, bez automatycznych zasłon |

Wspierający dołączają do walki przez `wesprzyj`; dalsze ataki wykonuje gra. Nie patrolują, nie ścigają przeciwników i nie wykonują własnego odwrotu, leczenia, `/idz` ani opuszczania drużyny. Nie przesyłają raportów między profilami. Ruch za prowadzącym zapewnia drużyna w grze.

Zmiana roli zatrzymuje bota. Po skonfigurowaniu uruchom go przez `/kozojeb start` na każdym profilu. Wspierających można uruchomić przed prowadzącym. Bez widocznego, faktycznego prowadzącego czekają.

Od 2.9.9 start prowadzącego w spokojnym pokoju sprawdza HP całej widocznej drużyny według `powrothp` (domyślnie 95%). Brak odczytu lub ranny kolega wstrzymuje rozpoczęcie patrolu, także po aktualizacji. Stan poniżej progu odwrotu wymaga 100% tej postaci. Po regeneracji bot rusza automatycznie; atak podczas oczekiwania uruchamia dotychczasową ewakuację. Start podczas trwającej walki zachowuje decyzje bojowe i progi odwrotu. Ponowny `start` podczas leczenia lub powrotu nie kasuje wymagań regeneracji; wznowienie jest automatyczne.

Możesz wskazać konkretnego prowadzącego zamiast automatycznego wykrywania:

```text
/kozojeb lider Yarrim yarrima
```

## Obszar i cele prowadzącego

1. Zaznacz pokoje na mapie i wpisz `/kozojeb obszar`.
2. Wybierz cele, np. `/kozojeb cele snotling`. Komenda zastępuje całą listę celów.
3. Zbierz drużynę w bezpiecznym pokoju znajdującym się w obszarze.
4. Wpisz `/kozojeb start`. Bieżący pokój prowadzącego staje się bazą i początkiem patrolu.

Przykładowe ustawienia:

```text
/kozojeb maxstworow 3
/kozojeb predkosc 0.7
/kozojeb pauza 5
/kozojeb prog 50
/kozojeb progdruzyny 50
/kozojeb progzaslony 70
/kozojeb odpoczynek 25 55
```

Limit stworów dotyczy nowych spotkań podczas patrolu. Od **2.9.8** przekroczenie limitu zachowuje decyzję o szybkim wyjściu również wtedy, gdy NPC sam zaatakuje prowadzącego lub kolegę, zanim drużyna zdąży odejść. Przykład: przy `/kozojeb maxstworow 3` pokój z 7 liczonymi NPC jest pomijany mimo ich agresji. Sam limit nie zapobiega atakom gry ani obrażeniom podczas wychodzenia. Zero wyłącza limit; dokładnie 3 cele przy limicie 3 dopuszczają normalną walkę.

Do limitu wliczani są żywi NPC zgodnie z listą celów i ustawieniem `ignoruj pozostale`. Gracze, martwi NPC i nazwy z listy ignorowanych nie zawyżają licznika. Decyzja o opuszczeniu pokoju obowiązuje do potwierdzenia przejścia, nawet jeśli część NPC ucieknie lub zginie. W tym czasie bot nie rozpoczyna nowego ataku, pościgu ani pauzy po przypadkowej śmierci przeciwnika. Zasłony, pilny odwrót z powodu HP, kontrola ruchu oraz zbieranie drużyny pozostają aktywne. Wspierający nadal poruszają się wyłącznie za prowadzącym.

Wyjście korzysta z istniejącej trasy patrolu i krótkiego odstępu, domyślnie najwyżej 0,2 s. Jeden krok czeka na potwierdzenie zmiany pokoju; kolejny atak lub powtórzony opis tego samego pokoju nie zwalnia tego oczekiwania. Po rzeczywistym przejściu nowa walka wymaga świeżej listy encji. Odrzucony kierunek jest pomijany, odmowa z powodu zmęczenia wymaga odpoczynku i nie oznacza błędu wyjścia. Przy trwającym ataku brak drogi lub wyczerpanie trzech domyślnych prób przekazuje sterowanie wspólnemu odwrotowi; brak potwierdzenia kroku przez domyślne 12 s również uruchamia procedurę odwrotu. Czasy i budżet korzystają z dotychczasowych ustawień. Nie są wysyłane serie kierunków bez oczekiwania na wynik.

Limit nie przerywa wcześniej wybranej walki, trwającego pościgu ani pełnej skonfigurowanej pauzy po zabiciu. Ręczna zmiana limitu przed wysłaniem ruchu powoduje ponowną ocenę; nie anuluje już wysłanego kierunku. `/kozojeb baza` zmienia bazę na bieżący pokój, ale kolejne `/kozojeb start` ponownie ustawia ją w miejscu uruchomienia.

## Zasłony i HP

Własne HP jest liczone z kompletnej pary `hp/maxhp` z jednego źródła GMCP. Niepełny odczyt nie łączy wartości z `Char.Vitals` i `Room.Entities`; jeśli oba źródła są niepełne, bot zachowuje ostatni poprawny wynik. Pełne, nowsze `Char.Vitals` nadal ma pierwszeństwo przed starszym odczytem encji.

Na profilu z rolą `zaslony`:

```text
/kozojeb proglidera 85
/kozojeb progzaslony 70
/kozojeb minhpzaslony 50
```

Te progi dopuszczają rozważenie zasłony: HP prowadzącego musi być **poniżej 85%**, własne HP **co najmniej 50%**, żywy NPC musi faktycznie atakować prowadzącego, a szyk musi być gotowy. Sama różnica procentów nie wystarcza do wykonania osłony. Przy równych 85% zasłona nie następuje. `/kozojeb proglidera 0` wyłącza tę zasłonę.

Od 2.9.6 `/kozojeb progzaslony 70` określa także próg osłony **pozostałych członków drużyny** na profilach z rolą `zaslony`. Prowadzący używa go dla całej drużyny. Ten próg musi być wyższy od progów odwrotu. `proglidera` pozostaje osobnym progiem dla prowadzącego na profilu osłaniającym: jego wyłączenie nie wyłącza ochrony kolegów, a `progzaslony 0` nie wyłącza ochrony lidera. Rola `wsparcie` nadal nie wykonuje zasłon. Aktualizacja zachowuje istniejące role i wartości progów.

Własne minimum `/kozojeb minhpzaslony` działa niezależnie w obu rolach wykonujących zasłony. Na wspierającym `/kozojeb prog 50` jest skrótem ustawienia własnego minimum zasłon; na prowadzącym pozostaje progiem odwrotu. W roli `zaslony` zagrożony kolega może być osłaniany także wtedy, gdy prowadzący sam nie walczy, ale pozostaje widocznym członkiem drużyny.

Od wersji 2.9.0 decyzja uwzględnia punkty HP obu postaci, liczbę unikalnych napastników NPC oraz ostatnie spadki HP. Dla przykładu 60% z 1200 HP oznacza więcej życia niż 78% z 600 HP. Pełne pary `hp/maxhp` drużyny wybierane są według nowszego zdarzenia `Room.Entities` albo `Group.State`; starszy odczyt nie przesłania nowszego. Punkty do porównania obu graczy pochodzą ze wspólnego kanału. `Char.Vitals` nie dostarcza punktów do bezpośredniego porównywania różnych postaci.

Od 2.9.10 bot ocenia każdy możliwy zakres przejęcia: od jednego NPC do wszystkich widocznych napastników celu. Uwzględnia wynik „przed ciosami wrogow”; wolny obrońca nie jest automatycznie bezpiecznym wyborem. Sprawdza największą możliwą liczbę unikalnych napastników po zasłonie oraz najmniej korzystny zapas HP obu osób. Wspólny NPC atakujący obie postacie jest liczony raz. Obliczenie korzysta z dwóch skrajnych obciążeń, bez wyliczania wszystkich podzbiorów. Kolejny napastnik ma większy koszt niż pierwszy. Zasłona musi poprawiać oceniany zapas obrony obu postaci co najmniej o 15%; niedawne obrażenia zmniejszają ten zapas. Jest to ostrożna heurystyka, nie dokładny model pancerza, umiejętności ani przyszłych obrażeń. Przy braku porównywalnych HP automat czeka na pełne dane.

```text
/kozojeb limitzaslony 2
/kozojeb stabilizacja 8
```

Domyślnie automat odrzuca próbę, jeśli pełne przejęcie widocznych napastników mogłoby zwiększyć obciążenie osłaniającego powyżej **2** (ustawienie 1–5). Przykładowo wolny obrońca nie osłoni automatycznie przed trzema NPC przy limicie dwóch. Przy dwóch napastnikach nadal potrzebny jest wystarczający zapas HP. Samoczynna agresja lub przybycie nowych NPC po wysłaniu komendy może przekroczyć tę ocenę. Nie jest to limit samoczynnej agresji NPC ani polecenie rozdzielania przeciwników na profile drugiej linii. Po potwierdzonej w GMCP zmianie obrońcy konkretnego NPC bot przez **8 sekund** ogranicza oddawanie go poprzedniemu obrońcy. Wyjątkiem jest stan bliski progowi odwrotu albo znaczna, co najmniej 40-procentowa poprawa oceny bezpieczeństwa. Identyczne opisy NPC są rozróżniane po ID. Po zmianie pokoju i sesji historia jest czyszczona. Dawna reguła przewagi 5 punktów procentowych została zastąpiona tą oceną.

Każda próba rezerwuje zmianę szyku od razu. Od 2.9.4 dotyczy to również rozpoznanych poleceń `zaslon <imię>` wysłanych ręcznie lub przez inne skrypty: automat czeka na ich wynik. Nie blokuje przy tym ręcznych poleceń. Spóźniony komunikat gotowości sprzed odpowiedzi na próbę nie zwalnia rezerwacji. Rezerwacja trwa także podczas zatrzymania bota; nie uruchamia go ponownie. Bot czeka na `Jestes gotowy do zmiany w szyku.`; limit awaryjny przy braku komunikatu wynosi 10 sekund. Nieudana próba umiejętności również zużywa gotowość szyku.

Od 2.9.5 odpowiedź `Dopiero co zepchnieto cie sprzed <osoby>; ...` kończy oczekiwanie na wynik i wprowadza 10 s odstępu przed kolejną automatyczną próbą osłony tej osoby. Jest to zachowawczy odstęp skryptu, nie odczyt czasu blokady z serwera. Gotowość szyku nie usuwa tej blokady. Inne osoby można osłaniać zgodnie z pozostałymi warunkami; prowadzący uwzględnia niedostępną pozycję przy decyzji o odwrocie. Stop/start zachowuje niewygasłą blokadę, a upływ czasu nie uruchamia zatrzymanego bota.

Profile z rolą `zaslony` wybierają zagrożonego członka według liczby napastników oraz zapasu HP w punktach z uwzględnieniem ostatnich obrażeń. Kolega obciążony kilkoma NPC może mieć pierwszeństwo przed prowadzącym z niższym procentem HP. Brak porównywalnych danych, niekorzystna osłona lub blokada pozycji pozwala rozważyć kolejną osobę. Nie są osłaniani gracze spoza drużyny ani osoby bez napastnika NPC.

Od 2.9.9 prowadzący i profile `zaslony` używają wspólnej kolejności: obrońca z najkorzystniejszym przewidywanym ryzykiem po osłonie ma pierwszeństwo, pozostali czekają po 0,45 s na kolejne miejsce, najwyżej 1,35 s. Nie zakładają, że inne profile mają włączone zasłony — po tym czasie mogą osłonić samodzielnie. Oczekiwanie na osłonę najważniejszego celu nie uruchamia zastępczo zasłony mniej zagrożonej osoby. Widoczna zasłona dowolnego członka daje do 0,5 s na aktualizację relacji walki; komunikat `zrecznie zaslania` jest również rozpoznawany. Równoczesne osłony różnych kolegów mają osobny krótki kontekst. Zmiana napastników wymaga ponownej oceny. Od 2.9.10 zwykły spadek HP nie zwalnia jednocześnie wszystkich oczekujących obrońców. Dodatkowe oczekiwanie jest pomijane przy krytycznym HP albo braku zapasu na kolejny ostatnio obserwowany cios. Próg odwrotu i kontrola presji nadal obowiązują. Nie wymaga to komunikacji między profilami ani nowych pętli. Notatka przy wykonanej komendzie pokazuje punkty HP, liczby napastników obu postaci i maksymalne obciążenie po pełnym przejęciu, aby ułatwić analizę logów.

Prowadzący również uwzględnia widoczną udaną zasłonę kolegi: przez najwyżej 0,5 s czeka na nowe relacje, zamiast uznawać własny brak gotowości za konieczność dodatkowego odwrotu. Dalsza utrata HP zagrażająca kolejnym takim ciosem, krytyczny stan własny, celu lub innej osoby oraz zmiana napastników kończą to oczekiwanie. Powtórzony komunikat nie przedłuża pierwszego okna. Wszystkie krótkie potwierdzenia współdzielą jeden timer, który znika po ich wygaśnięciu i jest anulowany przy zatrzymaniu lub zmianie pokoju.

Odmiany imion są zapisane dla Yarrima, Morrida, Yerga i Grora. Dla kolejnej postaci ustaw biernik, np.:

```text
/kozojeb imie Pandjed pandjeda
/kozojeb imie lista
```

Niepoprawna forma odrzucona przez grę jest blokowana do poprawienia.

## Opcjonalny tryb golemów — od 2.9.11

Na **każdym profilu** włącz `/kozojeb golemy on`. Domyślnie tryb jest wyłączony. Dodaje cel `golem` z odmianą `golema`, zachowując pozostałe cele, obszar, progi, tempo i pauzę po zabiciu. Wyłączenie: `/kozojeb golemy off`. Zmiana trybu podczas pracy zatrzymuje profil; po konfiguracji uruchom `/kozojeb start`.

Przykład konfiguracji drużyny:

| Profil | Komendy przed uruchomieniem |
| --- | --- |
| Yarrim, faktyczny prowadzący | `/kozojeb rola prowadzacy`, `/kozojeb golemy on` |
| Gror, Morrid i Yergo | `/kozojeb rola zaslony`, `/kozojeb lider auto`, `/kozojeb golemy on` |

1. **Wyłącz stary dodatkowy trigger zbierania pancerzy**, aby uniknąć nakładania komend. Nowa obsługa zbiera je do ekwipunku. Od 2.9.12 rozpoznaje również potwierdzone wkładanie pancerzy do plecaka podczas bieżącego cyklu i wyjmuje je w bazie przed przeszukiwaniem. Głównego modułu łupienia Chimery nie trzeba zastępować. Pancerze pozostawione sprzed aktualizacji obsłuż przed pierwszym cyklem; instalacja zatrzymuje bota i nie przenosi trwającego zadania między wersjami.
2. Na prowadzącym, stojąc w bezpiecznej kozobazie, wpisz `/kozojeb baza`. Zaznacz na mapie **bazę i pokoje golemów**, następnie `/kozojeb obszar`. W analizowanym logu baza golemów to 8765; sprawdź ją na swojej mapie. Poprzedni obszar 19 pokoi i baza 1097 dotyczyły wcześniejszego patrolu.
3. Zacznij w tej bezpiecznej bazie: `/kozojeb start` najpierw na osłaniających, potem na prowadzącym. Każdy ręczny start prowadzącego ustala bazę w bieżącym pokoju; nie uruchamiaj go po raz pierwszy w pokoju z golemami.

Przy czterech golemach atakujących jednego gracza profile planują różne, **celowane zasłony**, np. `zaslon yarrima przed pierwszym golemem`, `drugim`, `trzecim` lub `czwartym`. Plan używa ID NPC i bieżącej lokalnej kolejności żywych golemów. Dąży do jednego przeciwnika na osobę już przy wysokim HP, bez czekania na zwykły próg zasłony. Czysty pokój z najwyżej czterema golemami, których nie jest więcej niż członków drużyny, może zostać przyjęty mimo zwykłego limitu celów 3. Mieszany pokój lub większa grupa przeciwników nie otrzymuje tego wyjątku.

Po rozdzieleniu napastników bot może przenosić pojedynczego golema z osoby o niższym procencie HP na zdrowszego obrońcę. Domyślna różnica wynosi **10 punktów procentowych**; ustawienie `/kozojeb golemy roznicahp 10` przyjmuje wartości 5–30. Sama różnica procentów nie wystarcza: porównywalna rezerwa rzeczywistych punktów HP obrońcy musi być co najmniej o 15% większa. Zachowane są minimum własnego HP, limit napastników, gotowość szyku i stabilizacja niedawnych przejęć. Bezpieczna rotacja celowana może zastąpić zwykły wymóg poprawy presji o 15%, ponieważ jej celem jest wyrównanie HP w dalszej części walki. Brak gotowego obrońcy, opóźniony GMCP lub niejednoznaczny cel mogą opóźnić podział. To heurystyka, nie gwarancja równego HP w każdej rundzie. Rola `wsparcie` nadal nie wykonuje zasłon.

Po oczyszczeniu pokoju **prowadzący** zbiera pancerze przez `wez pancerz`, czekając na potwierdzenie każdego podniesienia. Nie używa `wez pancerz z ciala`. Następnie prowadzi całą drużynę przez dotychczasowe `/idz` do kozobazy. Tylko w bazie wykonuje kolejno `przeszukaj pancerz` → potwierdzenie `Przestajesz przeszukiwac ...` → `odloz pancerz` → potwierdzenie odłożenia. Niepowodzenie znalezienia kamienia nie kończy samo przeszukiwania. Rozpad pancerza leżącego na ziemi nie zmienia tego cyklu i nie pomija odłożenia pancerza z ekwipunku.

Hotfix 2.9.12 uwzględnia ostatni pancerz także wtedy, gdy potwierdzenie podniesienia nadejdzie w pauzie po zakończeniu walki lub podczas powrotu. Licznik ładunku nie jest obcinany do początkowej liczby golemów. Odpowiedź „bierzesz trzy pancerze” oznacza trzy sztuki; przeniesienie znanych sztuk z plecaka nie liczy ich drugi raz. Potwierdzone schowanie uruchamia w bazie `otworz swoj plecak` i `wez pancerze z plecaka`, z oczekiwaniem na wyjęcie. Brak pancerza przy dodatnim liczniku lub `Odloz co?` wstrzymuje cykl, zamiast uznawać ładunek za obsłużony. Panel pokazuje pozostałą liczbę sztuk oraz pancerze w plecaku. Powtórne `golemy on` zachowuje aktywny cykl.

Wznowienie patrolu wymaga obsłużenia pancerzy, obecności całej zapamiętanej drużyny i **rzeczywistych 100% HP wszystkich postaci**; zaokrąglone 100% nie wystarcza. Kontrola ruchu i ekwipunku nadal obowiązuje. Dzieje się to automatycznie. Rozłączenie zachowuje etap cyklu; po niepewnym odłożeniu bot najpierw ponownie przeszukuje kolejny pancerz, zanim go odłoży. Brak potwierdzenia przeszukiwania przez 45 s lub odłożenia przez 4 s wyświetla przyczynę i pozostawia cykl w oczekiwaniu, bez kolejnych komend. Spóźniona odpowiedź jest nadal przyjmowana. Zadanie pozostaje aktywne, także gdy Mudlet dopiero później wykryje rozłączenie; po zalogowaniu wznowienie jest automatyczne. Jeżeli połączenie działa, a odpowiedź nie przychodzi, sprawdź ekwipunek i komunikaty gry. Ręczny stop, śmierć, zmiana roli lub wyłączenie trybu anuluje cykl.

`/kozojeb golemy status` i panel pokazują etap. Plan zasłon jest buforowany, zdarzenia korzystają z istniejącej kolejki decyzji. Timery działają tylko dla oczekującej operacji lub krótkiego zastępstwa obrońcy. Nie ma komunikacji między profilami, nowego stałego odpytywania ani analizy każdej linii obrażeń.

## Odwrót, sprzęt i ponowne logowanie

- Prowadzący decyduje o odwrocie według własnego HP, HP drużyny i własnego zmęczenia.
- Przy nieudanej lub niedostępnej bezpiecznej osłonie prowadzący może wycofać drużynę wcześniej: poniżej mniejszej wartości z `prog zasłony - 1` i `próg odwrotu drużyny + 15`. Przykładowo progi 50%/80% dają dodatkową granicę 65%. Wyłączenie kontroli HP drużyny przez `progdruzyny 0` wyłącza też ten dodatkowy odwrót. Wspierający nie wykonują osobnego odwrotu ani raportowania.
- Od 2.9.4 własna trwająca próba zasłony nie wywołuje sprzecznego odwrotu tylko z powodu zajętego szyku. Oczekiwanie na odpowiedź trwa najwyżej 2 s od komendy, a po sukcesie najwyżej 0,5 s na uzgodnienie relacji walki, w granicach pierwotnych 2 s. Dotyczy wyłącznie osłanianej osoby przy niezmienionych napastnikach i HP. Krytyczne HP, dalsza utrata zdrowia, zmiana napastników, odmowa zasłony lub zagrożenie innego członka nie korzystają z tej zwłoki. Nie zmienia to progów odwrotu.
- Od 2.9.1 prowadzący przez 8 s pamięta największy ostatni spadek HP w bieżącym pokoju. Przy stracie co najmniej 15% maksymalnego HP i nadal atakującym NPC zachowuje rezerwę na kolejny taki cios ponad skonfigurowany próg odwrotu. Przykład: próg 50%, ostatni spadek 25 punktów procentowych, teraz 74% — możliwy wcześniejszy odwrót. Przy zagrożonym koledze bezpieczna dostępna zasłona jest rozważana przed tym dodatkowym odwrotem. `progdruzyny 0` wyłącza rezerwę drużynową. Jest to reakcja na zaobserwowane HP, a nie przewidywanie pierwszego silnego ciosu, pancerza czy umiejętności przeciwnika.
- Śmierć własnej postaci zatrzymuje bota i anuluje oczekujące wznowienie.
- Od 2.9.7 po odwrocie każdy członek drużyny, także prowadzący, musi osiągnąć domyślnie **95% HP**. Ustawienie na prowadzącym: `/kozojeb powrothp 95`; `/kozojeb powrothp 100` wymaga pełnej regeneracji wszystkich. Próg jest zapisywany na profilu i musi być wyższy od obu progów odwrotu. Zmiana późniejszego progu odwrotu nie pozwala wznowić zadania poniżej niego. Ustawienia wspierających nie sterują wspólnym powrotem.
- Jeśli od rozpoczęcia odwrotu postać spadnie poniżej swojego właściwego progu odwrotu (prowadzący: `prog`, pozostali: `progdruzyny` prowadzącego), wymaga rzeczywistych **100% HP** do końca tego leczenia i drogi powrotnej. Dotyczy również kolejnych rannych oraz zwykłej drogi do bazy, bez konieczności wystąpienia awaryjnego wyjścia. Pamięć obejmuje wszystkich takich członków i przeżywa rozłączenie. Obniżenie `powrothp` nie usuwa tego wymogu.
- Warunek regeneracji używa pełnych par `hp/maxhp`, bez zaokrąglania w górę. Widoczne po zaokrągleniu 95% przy faktycznych 94,6% nie wystarcza; tak samo 99,6% nie oznacza pełnych HP po stanie krytycznym. Każda postać jest oceniana względem własnego maksimum. Osoba wskazana przy odwrocie nie ma pierwszeństwa przed innymi rannymi.
- Przed powrotem bot nadal wymaga zebrania wcześniej obecnych i nowo dołączających członków, znanych HP, odpowiedniego ruchu, sprawnego sprzętu oraz zakończenia walki. Brak postaci lub odczytu nie oznacza wyzdrowienia. Panel pokazuje osobno wszystkich blokujących powrót, z bieżącym i wymaganym HP, zmęczeniem lub brakiem w pokoju. `progdruzyny 0` nie wyłącza regeneracji całej drużyny.
- Po drodze powrotnej prowadzący sprawdza te same warunki ponownie, ze świeżych danych przybycia. Obrażenia lub brakujący gracz zatrzymują wznowienie patrolu i przedłużają odpoczynek; atak nadal uruchamia dotychczasową ochronę i ewakuację. Sprawdzenie korzysta z istniejącego timera leczenia co 3 s i jednorazowego krótkiego uzgodnienia pakietów przybycia. Nie dodaje stałego odpytywania ani komunikacji między profilami.
- Od 2.9.5 leczenie nie wyłącza ochrony drużyny. Świeże dane o ataku NPC na odpoczywającą drużynę uruchamiają awaryjne wyjście prowadzącego, także zanim HP stanie się krytyczne. Bot wybiera zwykłe wyjście zapisane na mapie, preferując pokój poza obszarem patrolu i kierunek inny niż ostatnia droga przybycia. Pomija miejsca odrzucone w tej ewakuacji oraz znane miejsce rozpoczęcia odwrotu. Nie korzysta z wymyślonych kierunków ani wyjść specjalnych.
- Po każdym kroku czeka na potwierdzenie pokoju i świeże dane walki. Jeśli atak trwa, może wykonać kolejny krok; cała ewakuacja ma najwyżej trzy próby ruchu, bez powrotu do odrzuconych miejsc. Odmowa wyjścia pozwala wybrać inne, brak potwierdzenia ma limit czasu, a odmowa z powodu zmęczenia wymaga świeżego odczytu sił i nie zużywa próby trasy. Przy braku wyjścia bot nadal może wykonywać bezpieczne zasłony i wyświetla przyczynę blokady; odczyt mapy jest ponawiany najwyżej trzy razy.
- Nowe miejsce leczenia jest sprawdzane po przybyciu — mapa nie gwarantuje, że sąsiedni pokój będzie bezpieczny. Potwierdzone miejsce pozostaje awaryjnym celem następnych odwrotów do zatrzymania zadania. Ustawiony start patrolu nie jest zmieniany; po pełnej regeneracji i zebraniu drużyny bot wraca do niego. Panel pokazuje awaryjne miejsce leczenia. Rozłączenie zachowuje ten kontekst, ręczny stop, śmierć i zmiana roli go anulują. Wspierający nie wykonują własnej ewakuacji ani raportowania.
- Ręczne `/kozojeb baza`, `startpokoj <ID>` lub `bezczynnosc <sekundy> <ID>` zastępuje wcześniejsze awaryjne miejsce odwrotu. Bot nie kieruje kolejnego odwrotu do starego schronienia po wskazaniu nowej bazy.
- Pęknięcie własnego lub widocznego drużynowego ekwipunku uruchamia wspólny odwrót i blokuje automatyczne wznowienie. Uzupełnij sprzęt i wpisz na prowadzącym `/kozojeb ekwipunek gotowy`.
- Rozłączenie wstrzymuje komendy i zapamiętuje aktywne zadanie. Po ponownym zalogowaniu Kozojeb **automatycznie je wznawia, bez `/kozojeb start`**. Wymaga świeżego pokoju i listy encji z własną postacią oraz kompletnym HP. Po krótkiej pauzie 0,5 s ocenia aktualny stan. Brak ponownego wysłania niezmienionych `Group.State`, `Combat.State` lub `Char.Vitals` nie blokuje wznowienia. Starsze dane walki i składu drużyny pozostają odfiltrowane; drużyna może być rozpoznana po rolach na świeżej liście encji. Ruch jest monitorowany według ostatniego znanego odczytu, aż przyjdzie jego aktualizacja.
- Przed wznowieniem patrolu prowadzący czeka na wcześniej widocznych członków drużyny. Ich nieobecność nie blokuje pilnego odwrotu ani kontynuacji leczenia; zebranie drużyny jest wtedy sprawdzane w bazie. Wspierający wracają do swoich ról bez własnego ruchu. Panel pokazuje konkretny brakujący odczyt albo gracza, gdy wznowienie nadal oczekuje.
- Automatyczne wznowienie zachowuje bazę, obszar i postęp patrolu. Trwający odwrót, leczenie lub powrót jest kontynuowany. Cel walki i kolejny krok są wybierane ponownie z aktualnych danych. Logowanie i ponowne połączenie obsługuje Mudlet oraz dotychczasowa konfiguracja profilu.
- `/kozojeb stop` anuluje również oczekujące wznowienie. Bot zatrzymany przed rozłączeniem pozostaje zatrzymany. Zmiana roli anuluje poprzednie zadanie; logowanie inną postacią również go nie wznawia. Po aktualizacji paczki bot pozostaje zatrzymany.
- Po wysłaniu ruchu bot czeka na potwierdzenie pokoju i nową listę encji, zanim wybierze cel do ataku.

`/kozojeb stop` zatrzymuje Kozojeba na danym profilu. Zatrzymanie wszystkich profili wymaga tej komendy na każdym z nich. Trwającą walkę i zewnętrzny chodzik obsługuje gra oraz główne skrypty Chimery.

## Aktualizacje z GitHuba

Jeśli masz już Kozojeba 2.8.1–2.9.11, wykonaj na **każdym profilu**:

```text
/kozojeb stop
/kozojeb repo gurninson-sketch/kozojeb
/kozojeb autoaktualizacja on
/kozojeb aktualizuj
```

Poczekaj na zakończenie walki i ruchu oraz komunikat `Zainstalowano 2.9.12`. Sprawdź `/kozojeb status`; powinien pokazać wersję **2.9.12**. Następnie uruchom `/kozojeb start` — najpierw na wspierających, potem na prowadzącym. To jednorazowy start po aktualizacji; późniejsze rozłączenia nie wymagają ręcznego wznowienia. Nie trzeba usuwać ani ręcznie instalować paczki; dotychczasowe ustawienia profili pozostają zachowane. Można przejść bezpośrednio z 2.9.2 do 2.9.12. Profile już ustawione na `zaslony` korzystają z ochrony całej drużyny; rola `wsparcie` pozostaje drugą linią. Zwykły próg regeneracji wynosi domyślnie 95%; można go zmienić na prowadzącym przez `/kozojeb powrothp 95`. Tryb golemów wymaga osobnego włączenia i w swoim cyklu czeka na 100% całej drużyny.

Przy paczce zbudowanej w tym repozytorium adres wydań jest wbudowany. W paczce przygotowanej bez adresu skonfiguruj na każdym profilu:

```text
/kozojeb repo gurninson-sketch/kozojeb
/kozojeb autoaktualizacja on
/kozojeb aktualizuj
```

Adres repozytorium ma postać `OWNER/REPO`, bez `https://`. Repozytorium z wydaniami musi być publicznie dostępne. Ta wersja aktualizatora nie przechowuje tokenów GitHuba i nie pobiera prywatnych wydań.

Aktualizator sprawdza wydanie 30 sekund po załadowaniu profilu, a następnie co 6 godzin. Ręczne `/kozojeb aktualizuj` działa również przy wyłączonym sprawdzaniu automatycznym. Pobiera tylko opublikowane stabilne wydania z **Releases**. Zmiany na `main` i wydania robocze nie aktualizują profili.

Od 2.9.4 po błędzie połączenia lub przekroczeniu czasu pobierania aktualizator podejmuje najwyżej trzy ponowienia: po 1, 5 i 15 minutach. Ponownie zaczyna od weryfikacji manifestu, zachowując dotychczasową wersję do poprawnej instalacji. Pokazuje przyczynę błędu bez pełnych adresów pobierania. Błędy sumy kontrolnej, formatu lub instalacji nie powodują ponowień. Nowe ręczne sprawdzenie zastępuje oczekujące ponowienie, a wyłączenie automatycznych aktualizacji lub zmiana repozytorium je anuluje. Starszy aktualizator nie ma tej funkcji: jeśli pierwsze pobranie 2.9.4 nie powiedzie się, ponów `/kozojeb aktualizuj` albo zainstaluj paczkę z Releases przez Menedżer pakietów.

Instalacja czeka na zatrzymanie bota, zakończenie własnej walki i aktualne dane pokoju. Nie zatrzymuje samodzielnie prowadzącego ani wspierających. Bot po aktualizacji pozostaje zatrzymany; uruchom go przez `/kozojeb start`.

Przed podmianą sprawdzane są rozmiar, format i SHA-256 paczki. Bieżące skrypty są zachowywane w kopii `kozojeb_rollback/Chimera_Kozojeb.xml` w katalogu profilu. Gdy nowa wersja nie zainstaluje się poprawnie, aktualizator próbuje przywrócić tę kopię. Można ją też zainstalować ręcznie przez Menedżer pakietów.

Konfiguracja — w tym obszar, cele, prędkości, progi, role i odmiany — pozostaje w katalogu danego profilu, poza katalogiem paczki. Aktualizacja nie przenosi ustawień pomiędzy postaciami. Pierwsze przejście z KozoBota importuje dostępne wcześniejsze ustawienia profilu i obszar; po zmianach zapisz profil Mudleta.

## Wydajność i powtarzane komendy

Od 2.9.10 zmiana pokoju odcina stare relacje walki, również gdy ten sam NPC nadal jest widoczny. Wsparcie wymaga aktualnej relacji ataku prowadzącego albo jego bieżącego komunikatu rozpoczęcia walki. Sam atak NPC na prowadzącego nie uruchamia wsparcia. Role osłaniające nadal mogą chronić drużynę: przed nowym GMCP jednoznaczny komunikat „NPC ATAKUJE osobę” potwierdza tę konkretną relację w bieżącym pokoju. Identyczne opisy kilku NPC nie pozwalają zgadywać ID. Dane tekstowe są zastępowane przez następny stan walki GMCP i usuwane po zmianie pokoju, rozłączeniu, śmierci lub zniknięciu NPC. Wspierający zachowują brak własnego ruchu i raportowania.

Panel pokazuje „Stan walki”: aktualne dane pokoju, potwierdzony atak tekstowy lub oczekiwanie. Diagnostyka odróżnia źródło GMCP od tekstu pokoju. Te zmiany nie dodają pętli, odpytywania serwera ani timera na pakiet. Indeks nazw NPC jest współdzielony z istniejącym indeksem encji; obserwacje ataków zajmują pamięć tylko dla bieżącego pokoju.

Kolejne zdarzenia GMCP współdzielą jeden oczekujący timer decyzji (zwykle 0,12 s). Krytyczny odczyt HP prowadzącego lub drużyny jest sprawdzany od razu, bez oczekiwania na tę kolejkę. Dane HP, indeks encji oraz relacje walki są obliczane raz dla aktualnego stanu i wykorzystywane ponownie. Aktualizacje walki i własnych parametrów nie przebudowują indeksu niezmienionej listy encji.

Od 2.9.8 licznik NPC jest współdzielony między kontrolą limitu i wyborem celu. Aktualizacje walki bez zmiany encji nie przeliczają go ponownie. Pomijanie pokoju używa istniejącego timera ruchu do kroku i ograniczonego oczekiwania na jego wynik, bez nowej stałej pętli lub odpytywania gry. Przy spokojnym pokoju bez drogi ponowne sprawdzenie nie następuje częściej niż co sekundę.

Kolejka zasłony ma jeden dodatkowy timer tylko podczas krótkiego oczekiwania, a ponowienia aktualizacji jeden tylko po błędzie pobierania. Nie dodają stałego odpytywania gry. Obserwacja wysyłania poleceń odrzuca inne komendy bez zapisywania ich treści; rozszerzona notatka pojawia się tylko przy rzeczywistym poleceniu zasłony.

Watchdog uwzględnia zmiany pełnych HP z `Char.Vitals`, `Group.State` i `Room.Entities`, również mniejsze od zaokrąglonego procenta, oraz rzeczywiste własne ciosy. Każde źródło porównuje z jego poprzednim odczytem: przełączanie między niezmienionymi skalami, np. `1000/1000` i `10/10`, nie udaje aktywności. Przesuwa znacznik czasu bez tworzenia nowego timera przy każdym pakiecie lub ciosie. Po powrocie do bazy restart czeka na świeży pokój i kompletne HP, zachowując aktywne zadanie. Nie wymaga ręcznego startu po spóźnionej liście encji; ręczny stop anuluje oczekiwanie.

Od 2.9.5 własne ciosy podczas trwającej walki lub pościgu odświeżają aktywność także przy opóźnionej liście encji. Nie odblokowują przy tym ataków ani ruchu na podstawie starych danych. Tekst po rozłączeniu jest ignorowany, a rzeczywisty zastój nadal uruchamia watchdog. Ewakuacja wykorzystuje dotychczasowy timer odwrotu; blokady pozycji współdzielą jeden dodatkowy timer działający tylko do ich wygaśnięcia.

Potwierdzenie własnej walki, w tym odpowiedź `Juz walczysz`, powstrzymuje kolejne `wesprzyj` dla tego samego starcia. Od 2.9.9 późniejsza sprzeczna odmowa nie usuwa tego potwierdzenia. Zniknięcie wcześniej widocznej własnej walki w nowym stanie GMCP pozwala ponownie dołączyć; zmiana celu prowadzącego również pozostaje obsługiwana. Krótkie przejście od tekstowej informacji o walce do konkretnego ID przeciwnika zachowuje potwierdzenie. Sygnał tekstowy jest powiązany z pokojem i widocznymi żywymi NPC. Po śmierci przeciwnika stary komunikat nie uruchamia kolejnego wsparcia; dalsza walka prowadzącego musi mieć potwierdzenie w świeżych danych. Po odmowie wsparcia wymagane są nowe relacje dotyczące prowadzącego lub jego przeciwnika albo nowy poprawny komunikat walki. Walka innych NPC, identyczne pakiety, kolejność i duplikaty relacji nie odnawiają próby.

Własna relacja ataku ma pierwszeństwo przed `primary`. Jeżeli ogólne `zabij fimira` wybrało innego dozwolonego fimira, bot przyjmuje jego potwierdzone ID i nie ponawia komendy, próbując wymusić pierwszy wpis z listy. Inny gatunek, ignorowany NPC i sam napastnik nie zastępują wybranego celu. Przy braku potwierdzenia bot wysyła najwyżej trzy próby na konkretny cel w danym pokoju, z odstępami 1 i 2 s. Nowy cel, nowy pokój lub rzeczywiste odzyskanie i późniejsza utrata własnej walki pozwalają rozpocząć nowy cykl; zmiany pobocznych relacji nie wystarczają. To ogranicza komendy Kozojeba; inne skrypty i ręczne aliasy mogą nadal wysyłać własne polecenia.

Potwierdzone `0 HP` śledzonego NPC uruchamia pełną ustawioną pauzę po zabiciu. Po zniknięciu celu bot przez 3 sekundy pamięta jego ID, nazwę i pokój, aby rozpoznać spóźnione potwierdzenie śmierci. Kontekst wygasa po ruchu, wyborze nowego celu, zatrzymaniu lub zmianie sesji. Powtórzona linia śmierci nie wydłuża pauzy; opóźniony zgon z poprzedniego pokoju nie przerywa nowej walki. Przy identycznych opisach bot wymaga potwierdzenia dotyczącego konkretnego ID, zamiast oznaczać oba NPC jako martwe.

Po pustych pełnych okrążeniach patrol stopniowo zwalnia. Domyślny maksymalny odstęp wynosi 3 sekundy na krok. Nowy cel jest sprawdzany po GMCP bez czekania na wolniejszy krok, a walka przywraca zwykłe tempo. Ustawienie jest lokalne dla profilu:

```text
/kozojeb pustypatrol 3
/kozojeb pustypatrol 0
/kozojeb wydajnosc
```

`0` wyłącza zwalnianie. `wydajnosc` wypisuje liczniki zdarzeń, decyzji, przeliczeń, ataków i ich ponowień, powrotów watchdogu oraz oczekiwań na restart od załadowania skryptu; nie jest pomiarem całkowitego CPU Mudleta. Nie uruchamia nagrywania pakietów, pętli odpytywania, testów sieciowych ani zapisu logu na dysk. Dane obserwacji są ograniczone do widocznych członków drużyny i NPC bieżącego pokoju.

`/kozojeb diagnostyka` pokazuje te liczniki oraz bieżący tryb, rolę, pokój, ID celu, gotowość danych i oczekujący ruch. Podaje czas od ostatniego odebranego GMCP, własnego ciosu, postępu bota i decyzji. Watchdog zapisuje ten sam krótki stan przed rozpoczęciem powrotu. Identyczny pakiet GMCP aktualizuje czas odbioru, lecz nie udaje postępu. Diagnostyka działa na żądanie lub przy faktycznym zastoju; nie dodaje timera, odpytywania ani rejestratora pakietów. Sam taki zapis nie rozstrzyga przyczyny zerwania TCP.

## Zmęczenie i odmowa ruchu

Od 2.9.2 bot odczytuje `fatigue` Chimery: **0% oznacza wypoczęcie, 100% wyczerpanie**. W panelu ruch nadal oznacza pozostałe siły, czyli `100 - fatigue`. Gdy tego pola nie ma, bot korzysta z kompletnej pary `moves/maxmoves` z jednego źródła.

```text
/kozojeb odpoczynek 25 55
```

To wspólne progi prowadzącego: odwrót przy co najwyżej 25% pozostałych sił (co najmniej 75% zmęczenia), wznowienie po osiągnięciu co najmniej 55% sił (zmęczenie co najwyżej 45%). Dostępne pełne odczyty drużynowe są oceniane według tych samych progów. Osoba, której zmęczenie wywołało odwrót, musi mieć potwierdzone odzyskanie sił przed powrotem do patrolu. Wspierający nadal pozostają w drużynie i nie wysyłają raportów ani własnych komend ruchu.

Po komunikacie `Jestes tak zmeczony, ze nie mozesz isc w tym kierunku.` prowadzący wstrzymuje własny ruch w miejscu. Nie czeka na watchdog, nie blokuje poprawnego wyjścia na mapie i nie ponawia kroków na podstawie starego odczytu 100%. Automatyczne wznowienie wymaga nowego kompletnego odczytu sił. Podczas tego oczekiwania bot wysyła `stan` najwyżej raz na 10 sekund; poza oczekiwaniem ten timer nie działa.

Gdy serwer nie udostępnia zmęczenia wspierającego, prowadzący korzysta z obecności drużyny po własnym kroku patrolu lub pościgu. Daje postaciom **1 sekundę** na przybycie. Jeśli ktoś pozostał z tyłu, wstrzymuje nowy atak i dalszy patrol, wraca **o jeden pokój**, jeśli mapa potwierdza takie wyjście, i odpoczywa z zebraną drużyną. Kolejne nieudane przejścia wydłużają przerwę do **10, 20 i 30 sekund**. Przy dostępnych danych czeka również na wymagane siły; bez tych danych po przerwie wykonuje kontrolowaną próbę dalszego wspólnego przejścia. Brak drogi powrotnej oznacza oczekiwanie na zebranie drużyny, bez zgadywania kierunku.

Niski HP i pilny odwrót nadal mają pierwszeństwo. Odpoczynek nie zmienia decyzji gry o podążaniu w drużynie ani działania ręcznie uruchomionego chodzika; nie zapewnia bezpieczeństwa lokacji. Po odzyskaniu połączenia oczekiwanie jest kontynuowane automatycznie. Ręczny stop, zmiana roli i śmierć je anulują. Panel pokazuje powód wstrzymania ruchu, a `/kozojeb wydajnosc` także liczbę odpoczynków i powrotów po drużynę.

Kozojeb wznawia zadanie po odzyskaniu sesji, ale nie zmienia automatycznego logowania Mudleta, obsługi pytania o przejęcie postaci ani odstępów ponownego łączenia w innych skryptach. Te ustawienia wymagają osobnego sprawdzenia przy odrzucanych połączeniach.

## Dla autora zmian

Wymagane: Python 3.10+ oraz biblioteka Lua 5.4 albo Lua 5.1. Na Ubuntu: `sudo apt-get install liblua5.4-0`.

```sh
python3 tools/test.py
python3 tools/build.py --repository gurninson-sketch/kozojeb
```

Paczka i `update.json` powstaną w `dist/`. Budowanie jest powtarzalne dla tego samego kodu i adresu repozytorium. Testy używają atrap API Mudleta, timerów, GMCP i pobierania plików.

Wydanie:

1. Zmień `VERSION`, `K.version`, nagłówek pomocy i opis zmian.
2. Uruchom testy i zatwierdź kod.
3. Utwórz tag, np. `git tag v2.8.0`, i wypchnij go do GitHuba.
4. Workflow **Release** uruchomi testy, zbuduje paczkę i utworzy wydanie robocze.
5. Sprawdź wydanie robocze i opublikuj je. Od tej chwili profile wykryją nową wersję.

Przy wypchnięciu pierwszego tagu razem z nowymi workflowami można też uruchomić **Release → Run workflow** z istniejącym tagiem. GitHub wymaga włączonych Actions w repozytorium.

Do repozytorium trafiają wyłącznie źródła, testy i dokumentacja. Logi postaci, mapy i ustawienia profili nie są częścią projektu.
