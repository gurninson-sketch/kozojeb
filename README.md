# Chimera Kozojeb 2.9.25

[Pobierz najnowszą paczkę](https://github.com/gurninson-sketch/kozojeb/releases/latest/download/Chimera_Kozojeb.mpackage) · [Wydania](https://github.com/gurninson-sketch/kozojeb/releases)

**Kozojeb** jest rozwinięciem oryginalnego **KozoBota**, którego autorem jest **Pipek**. Zachowujemy autorstwo oryginału; nazwa Kozojeb oznacza rozwijaną tutaj wersję.

Bot do Mudleta: patrol, walka i role drużynowe w Chimerze. Prowadzącym może być dowolny profil. Pozostałe profile wspierają walkę zgodnie ze swoją rolą; decyzję o odwrocie podejmuje prowadzący, korzystając z danych drużyny w GMCP.

## Poprawki po analizie logów z 3–5 listopada — 2.9.22

- Watchdog rozróżnia zastój mimo bieżących pakietów od braku danych z gry. Przy przerwie w danych zachowuje zadanie i pancerze oraz wstrzymuje komendy. Po świeżych `Room.Info`, `Room.Entities` i `Combat.State` automatycznie ocenia obecną walkę. Odświeżenie subskrypcji GMCP następuje najwyżej raz na 15 sekund, bez pętli ruchu i ponownego logowania. Oczekujący STOP anuluje wznowienie.
- Kolejne zmiany celu w GMCP nie odsuwają w nieskończoność awaryjnej zasłony oczekującej na inny profil. Sama rola profilu pozostaje lokalna. Dla osoby ustawionej na DPS zapisz na pozostałych profilach ogólną regułę `/kozojeb druzyna rola <imie> wsparcie`, aby od początku nie przydzielać jej zasłon. Aktualizacja nie zmienia zapisanych ról i nie wprowadza przypisań według imienia.
- Powtórne `wesprzyj` może zostać pominięte, jeśli aktualne, jednoznaczne relacje GMCP potwierdzają ten sam żywy cel prowadzącego i wspierającego. Inny, nieznany albo niejednoznaczny cel nadal dopuszcza wsparcie. Dotyczy również komend wysyłanych przez osobne triggery; liczbę pominięć pokazuje `/kozojeb wydajnosc`.
- `zakoncz` wysłane już w grze zatrzymuje zadanie Kozojeba i anuluje jego wznowienie. Ponowne zestawianie połączenia przez Mudleta lub osobny Reconnect ma własne ustawienia.

### Puste serie łupu na golemach

Przy aktywnym automatycznym prowadzącym, włączonych golemach i pokoju z samymi golemami filtr pomija serię `wez kamienie z ciala`, `ocen kamienie`, otwarcie plecaka, wkładanie kamieni i zamknięcie plecaka. Kolejne cztery polecenia muszą nadejść w tej kolejności w ciągu 0,25 s; pojedyncza ręczna komenda ekwipunku pozostaje dostępna. Pancerze zbierane są jak dotąd, a odpoczynek nadal wymaga 100% HP całej drużyny. Filtr nie działa podczas ręcznego prowadzenia w roli `zaslony`, u wspierających, w mieszanych pokojach, przy przeszukiwaniu w bazie ani na wyłączonym bocie.

Od 2.9.23 filtr obsługuje też wariant zaczynający się od `wez zlote monety z ciala`, w którym przed kamieniami makro wkłada do plecaka monety. Cała rozpoznana seria musi zmieścić się w tym samym oknie 0,25 s.

```text
/kozojeb golemy filtr status
/kozojeb golemy filtr off
/kozojeb golemy filtr on
```

Zbędne komendy pobierania innych przedmiotów można dodać samodzielnie, np. `/kozojeb golemy filtr dodaj wez misterny topor`; cofnięcie: `filtr usun wez misterny topor`. Nie można w ten sposób filtrować pancerzy. Lista jest konfigurowalna, domyślnie pusta. Docelowo usuń niepotrzebny automat łupu u źródła; filtr ogranicza jego komendy, ale nie odinstalowuje obcych triggerów.

### Zapisane pułapki i niebezpieczne przejścia

```text
/kozojeb pulapki status
/kozojeb pulapki blokuj <numer_pokoju>
/kozojeb pulapki blokuj <numer_pokoju> <kierunek>
/kozojeb pulapki usun <numer_pokoju> [kierunek]
/kozojeb pulapki on
/kozojeb pulapki off
```

Powyższe numery i kierunki zastąp wartościami z mapy. Zapis dotyczy bieżącego profilu. Automatyczny patrol omija zablokowane pokoje i wyjścia przy wyborze trasy. Powrót lub odwrót sprawdza również całą drogę mapy przed wywołaniem `/idz`; brak potwierdzonej bezpiecznej drogi zatrzymuje bota zamiast wysyłać go przez pułapkę. Obce, ręcznie uruchomione `/idz` i inne boty nie są zmieniane.

Wykrywanie zapisuje pokój po rozpoznanym komunikacie pułapki z ostrzem i niedawnym, jednoznacznym kierunku ruchu. Dotyczy również uniknięcia pułapki. Seria kierunków bez potwierdzenia pozycji daje ostrzeżenie zamiast zapisania przypadkowej lokacji. `off` wyłącza nowe automatyczne rozpoznawanie; zapisane blokady usuwa `usun`. Przy ręcznym prowadzeniu bot ostrzega, a ruch pozostaje pod kontrolą gracza. Mechanizm nie zapewnia ochrony przed pierwszą nieznaną pułapką i nie zawiera wpisanych na stałe numerów pokoi z logów.

## Instalacja

1. Na każdym profilu zatrzymaj poprzedniego bota: `/kozo stop` w KozoBocie lub `/kozojeb stop` w Kozojebie. Poczekaj na zakończenie walki oraz ruchu.
2. W Menedżerze pakietów Mudleta usuń starszą paczkę **Chimera_Kozojeb** lub poprzedniego **Chimera_Kozobot**. Zachowaj główne skrypty Chimery.
3. Zainstaluj `Chimera_Kozojeb.mpackage` pobrany z **Releases** tego repozytorium. Pozostaw jedną wersję Kozojeba na profilu.
4. Wpisz `/kozojeb status` i sprawdź numer wersji.
5. Pozostaw wyłączone dodatkowe automatyczne wsparcie w głównych skryptach Chimery.

Do automatycznych aktualizacji wymagany jest Mudlet **4.20.0 lub nowszy**. Kod głównego bota jest zgodny z Lua 5.1 i 5.4; testy nie zastępują sprawdzenia w grze.

## Drużyna i role

Najpierw utwórz drużynę w grze. Rola bota nie przekazuje faktycznego prowadzenia drużyny.

| Funkcja profilu | Komendy konfiguracji | Zachowanie |
| --- | --- | --- |
| Dowolny faktyczny prowadzący | `/kozojeb rola prowadzacy` | Patrol, wybór celów, pościg, zasłony drużyny i wspólny odwrót |
| Faktyczny prowadzący — ruch ręczny | `/kozojeb rola zaslony` i `/kozojeb start` | Ręczna nawigacja i walka; automatyczne zasłony całej drużyny |
| Profil osłaniający | `/kozojeb rola zaslony` oraz `/kozojeb lider auto` | Wsparcie i osłanianie zagrożonych członków całej drużyny |
| Profil drugiej linii | `/kozojeb rola wsparcie` oraz `/kozojeb lider auto` | Wsparcie i DPS, bez automatycznych zasłon |

Wspierający dołączają do walki przez `wesprzyj`; dalsze ataki wykonuje gra. Nie patrolują, nie ścigają przeciwników i nie wykonują własnego odwrotu, leczenia, `/idz` ani opuszczania drużyny. Nie przesyłają raportów między profilami. Ruch za prowadzącym zapewnia drużyna w grze.

Model ról pozostałych osób jest domyślnie pusty. Imię postaci nie narzuca roli. Każdy profil zachowuje własne ustawienie `rola`, a opcjonalny model określa, kogo uwzględniać w planie obrońców. Osoby wpisane jako `wsparcie` nadal są osłaniane i uwzględniane przy kontroli HP, odwrocie, zbieraniu drużyny oraz regeneracji.

Podgląd: `/kozojeb druzyna role`. Regułę ustaw na każdym profilu przez `/kozojeb druzyna rola <imie> wsparcie|zaslony|auto`; `auto` usuwa przypisanie. Wyczyszczenie całego modelu: `/kozojeb druzyna role reset`. Model nie zmienia zdalnie roli innego profilu. Aktualizacja 2.9.20 usuwa jednorazowo niezmieniony stary zestaw trzech domyślnych przypisań; inne własne modele zachowuje. Własne role profili pozostają zapisane, więc profil ustawiony na `wsparcie` nadal nie wykonuje zasłon. Faktycznego prowadzącego wskazuje GMCP.

Zmiana roli zatrzymuje bota. Po skonfigurowaniu uruchom go przez `/kozojeb start` na każdym profilu. Wspierających można uruchomić przed prowadzącym. Bez widocznego prowadzącego czekają z nowym wsparciem jego walki. Od 2.9.20 nadal aktualizują własne HP, a rola `zaslony` chroni rozpoznanych, widocznych członków rzeczywistej drużyny, także po zniknięciu lidera. Nie rozpoczyna samodzielnego odwrotu.

### Światło i zgon członka drużyny — od 2.9.20

Zniknięcie jedynego nosiciela światła może pozostawić pozostałych w ciemności. Opcjonalna obsługa pozwala postaci zapalić własną lampę z paliwem dopiero przy wykrytej utracie widoczności. W jasnych pokojach naturalne światło lub lampa kolegi wystarczają. Obsługę można włączyć na każdym profilu:

```text
/kozojeb swiatlo on
/kozojeb swiatlo status
```

Domyślna komenda to `zapal lampe`; można zapisać inną pojedynczą komendę przez `/kozojeb swiatlo komenda zapal pochodnie`. Od **2.9.21** sam start, reconnect i włączenie opcji w jasnym pokoju nie zapalają lampy ani nie wymagają jej potwierdzenia. Próba następuje dopiero, gdy aktualne encje GMCP są anonimowe i nie ma rozpoznanej postaci ani NPC. Brak danych i sam anonimowy napastnik w widocznym pokoju nie wystarczają do uruchomienia lampy. Bot czeka 3 s na potwierdzenie próby. Brak lampy, paliwa lub odpowiedzi daje jeden komunikat; nie tworzy pętli ponowień. Kolejne zdarzenie braku widoczności dopuszcza próbę najwyżej raz na 30 s. Obsługa nie kupuje lamp ani paliwa. Wyłączenie: `/kozojeb swiatlo off`.

Potwierdzona utrata widoczności w danym pokoju wstrzymuje nowy patrol i usuwa jeszcze niewysłany zwykły krok prowadzącego. Zasłony wymagają rozpoznanej postaci oraz NPC, a pilny wspólny odwrót nadal działa według dotychczasowych progów. Samo wysłanie komendy światła nie oznacza odzyskania widoczności: potrzebny jest świeży odczyt rozpoznanych encji. Może go zapewnić światło dzienne lub lampa kolegi; własna lampa nie jest wymagana. Jasny pusty pokój z rozpoznaną własną postacią również zwalnia oczekiwanie. Zmiana pokoju usuwa poprzednią blokadę i oczekiwanie na lampę; nowy pokój jest oceniany osobno. Wspierający nie wychodzą samodzielnie.

Potwierdzony zgon członka, rozpoznany duch, stan `dead`/`ghost` lub poprawna para HP z zerową wartością uruchamia na profilu `prowadzacy` wspólny odwrót i blokuje wznowienie patrolu z uszczuploną drużyną. Blokada przeżywa przeładowanie paczki i rozłączenie. Powrót żywej postaci potwierdzają świeże kanały drużyny i pokoju; przed patrolem wymaga ona 100% HP. Jeśli świadomie zmniejszasz skład, usuń zmarłą postać z drużyny w grze i poza walką wpisz na faktycznym prowadzącym `/kozojeb druzyna gotowa`. Komenda wymaga kompletnego, widocznego i żywego składu. Ręczny prowadzący w roli `zaslony` nadal sam decyduje o odwrocie.

Od **2.9.16** rola `zaslony` działa również na faktycznym prowadzącym drużynę, gdy chodzisz ręcznie. Na aktualnym prowadzącym, np. Yarrimie, ustaw:

```text
/kozojeb rola zaslony
/kozojeb start
```

Bot rozpoznaje własne prowadzenie przez GMCP i automatycznie osłania pozostałych członków drużyny. Nie wymaga innego lidera ani zapisanej trasy. Panel pokazuje `Prowadzenie: Reczne; automatyczne zaslony calej druzyny`. Sam wybierasz ataki, kierunki, odwrót i odpoczynek. Ten tryb nie wysyła `wesprzyj` do własnej postaci, nie rozpoczyna patrolu, pościgu ani cyklu pancerzy. Wspólny plan zasłon działa również podczas ręcznego prowadzenia. Po przekazaniu prowadzenia profil sam wraca do wspierania nowego widocznego lidera; po odzyskaniu prowadzenia znów osłania podczas ręcznego chodzenia. Rozłączenie wznawia ochronę automatycznie po świeżych danych.

Dla ochrony kolegów przy ręcznym prowadzeniu znaczenie mają `progzaslony`, `minhpzaslony`, limit napastników i stabilizacja. `proglidera` określa ochronę **innego** prowadzącego, kiedy ten profil jest wspierającym. Próg `progdruzyny` nie uruchamia w tej roli automatycznego odwrotu; w planie golemów nadal wpływa na rozpoznanie pilnej zasłony. Ustawienia pozostają zapisane i nie są automatycznie wyrównywane między profilami. Do pełnego patrolu, wspólnego odwrotu i cyklu pancerzy wybierz `rola prowadzacy`.

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

Po komunikacie `Kogo chcesz zaslonic?` bot od 2.9.15 wstrzymuje tę komendę najwyżej na 30 s. Zmiana napastników lub pokoju, zniknięcie postaci, korekta odmiany i potwierdzony sukces zwalniają blokadę wcześniej. Sama odmowa nie dowodzi złej odmiany: postać mogła wyjść lub przeciwnik zginąć przed odpowiedzią.

## Wybór kolejnego przeciwnika

Od 2.9.15 prowadzący domyślnie wybiera do nowego ataku dozwolonego NPC z najniższymi znanymi HP. Dzięki temu po zabiciu dotychczasowego celu może dobić przeciwnika wcześniej zranionego ciosem obszarowym. Przykład: pozostałe golemy mają 70, 20 i 90 HP — wybierany jest golem z 20 HP, jeżeli jego opis pozwala go jednoznacznie wskazać komendą. W logu pojawia się opis i odczyt `wybor HP: hp/maxhp`.

```text
/kozojeb celowanie hp
/kozojeb celowanie kolejnosc
```

Pierwsza komenda włącza wybór według HP, druga przywraca dotychczasową kolejność gatunków i encji. Ustawienie jest zapisywane na profilu. Porównywane są pozostałe wartości `hp` z poprawnych par `hp/maxhp` kanału `Room.Entities`; przy równych HP niższy udział HP, a następnie dotychczasowa kolejność rozstrzygają remis. Skala zależy od serwera: z samych procentów skrypt nie odtwarza nieudostępnionych rzeczywistych punktów życia. Brak danych nie oznacza zerowych HP.

Cel musi mieć obsługiwaną odmianę i jednoznaczny pełny opis. Jednakowe opisy, przestawione przymiotniki oraz krótszy opis pasujący też do dłuższego nie pozwalają udawać wyboru konkretnego ID przez ogólne `zabij golema`. Niejednoznaczni i nierozpoznani kandydaci nie są używani do optymalizacji; jeśli żaden kandydat się nie nadaje, pozostaje dotychczasowy wybór. Filtry gatunków i ignorowanych nazw, pierwszeństwo byka przed krową i kozła przed kozą oraz limit pokoju nadal obowiązują.

Ocena następuje przy rozpoczynaniu nowego ataku oraz po pełnej ustawionej pauzie po zabiciu. Potwierdzony bieżący cel, pościg i walka już trwająca podczas startu lub wznowienia pozostają kontynuowane. Kolejne obrażenia innych NPC nie przełączają celu. Wspierający nadal korzystają z `wesprzyj` i rzeczywistego stanu walki prowadzącego; nie wybierają samodzielnie NPC ani nie wykonują nowej pętli ataków. Nie dodano stałego odpytywania HP ani analizy każdej linii obrażeń.

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

Własne minimum `/kozojeb minhpzaslony` działa niezależnie w obu rolach wykonujących zasłony. Na wspierającym `/kozojeb prog 50` jest skrótem ustawienia własnego minimum zasłon; na prowadzącym pozostaje progiem odwrotu. W roli `zaslony` zagrożony kolega może być osłaniany także wtedy, gdy prowadzący sam nie walczy lub przestał być widoczny.

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

Od 2.9.25 wszystkie walki z NPC korzystają ze wspólnego planu zasłon. Gdy pierwszy spójny stan GMCP pokazuje jednego napastnika, dostępny obrońca może od razu osłonić osobę, która zebrała aggro, także przy 100% jej HP. Potrzebuje gotowego szyku, wolnego miejsca na napastnika i porównywalnej rezerwy HP. Przejęcie kończy zasłonę otwarcia w tej walce.

Przy kilku napastnikach plan przydziela różne cele kolejnym obrońcom. Dąży do wyrównania liczby NPC, z pierwszeństwem wolnych obrońców. Używa świeżych relacji NPC–gracz i wspólnej kolejności nazw, bez wiadomości między profilami. Gdy jeden obrońca jest niedostępny, pozostali oceniają zastępstwo po ograniczonym czasie. Widoczna nieudana zasłona wyklucza obrońcę z planu na 10 s i skraca to oczekiwanie. Zmiana pokoju lub sesji czyści te informacje.

Zasłona celowana używa pełnego opisu, np. `zaslon yarrima przed bladym zwinnym ozywiencem`. Plan rozpoznaje opisy golemów, orków, goblinów, snotlingów, trolli, ożywieńców i zombi. Numer przy identycznych opisach jest dopuszczalny, gdy wszystkie pasujące egzemplarze atakują tę samą osobę. Przy jednym potwierdzonym napastniku dostępna jest też zwykła komenda. Dla ogólnej zasłony przed kilkoma NPC bot ocenia możliwe przejęcie ich wszystkich. `/kozojeb celowanezaslony on|off` steruje celowanymi komendami w całej walce.

Po podziale plan ocenia rotację według różnicy HP. `/kozojeb roznicahp 10` ustawia próg w punktach procentowych od 5 do 30, z domyślną wartością 10. Obrońca potrzebuje także porównywalnej rezerwy HP w punktach większej o 5% przy pierwszym i 15% przy drugim napastniku. Zapisany próg golemów przechodzi do wspólnego ustawienia. Zasłony otwarcia i wyrównywanie liczby NPC działają powyżej zwykłych progów HP. Wartość 0 dla progu osłony danej osoby wyłącza jej przydział na tym profilu.

Odpowiedź gry rezerwuje NPC opisanego w potwierdzeniu. Gdy opis pasuje do kilku egzemplarzy, plan czeka do 0,5 s na rozstrzygnięcie w GMCP. Rozbieżny selektor dostaje 15 s przerwy. Świeży stan, gotowość szyku, minimalne własne HP i limit napastników są sprawdzane ponownie przed wysłaniem komendy.

Od 2.9.9 prowadzący i profile `zaslony` używają wspólnej kolejności: obrońca z najkorzystniejszym przewidywanym ryzykiem po osłonie ma pierwszeństwo, pozostali czekają po 0,45 s na kolejne miejsce, najwyżej 1,35 s. Nie zakładają, że inne profile mają włączone zasłony — po tym czasie mogą osłonić samodzielnie. Oczekiwanie na osłonę najważniejszego celu nie uruchamia zastępczo zasłony mniej zagrożonej osoby. Widoczna zasłona dowolnego członka daje do 0,5 s na aktualizację relacji walki; komunikat `zrecznie zaslania` jest również rozpoznawany. Równoczesne osłony różnych kolegów mają osobny krótki kontekst. Zmiana napastników wymaga ponownej oceny. Od 2.9.10 zwykły spadek HP nie zwalnia jednocześnie wszystkich oczekujących obrońców. Dodatkowe oczekiwanie jest pomijane przy krytycznym HP albo braku zapasu na kolejny ostatnio obserwowany cios. Próg odwrotu i kontrola presji nadal obowiązują. Nie wymaga to komunikacji między profilami ani nowych pętli. Notatka przy wykonanej komendzie pokazuje punkty HP, liczby napastników obu postaci i maksymalne obciążenie po pełnym przejęciu, aby ułatwić analizę logów.

Prowadzący również uwzględnia widoczną udaną zasłonę kolegi: przez najwyżej 0,5 s czeka na nowe relacje, zamiast uznawać własny brak gotowości za konieczność dodatkowego odwrotu. Dalsza utrata HP zagrażająca kolejnym takim ciosem, krytyczny stan własny, celu lub innej osoby oraz zmiana napastników kończą to oczekiwanie. Powtórzony komunikat nie przedłuża pierwszego okna. Wszystkie krótkie potwierdzenia współdzielą jeden timer, który znika po ich wygaśnięciu i jest anulowany przy zatrzymaniu lub zmianie pokoju.

Odmiany imion są zapisane dla Yarrima, Morrida, Yerga i Grora. Dla kolejnej postaci ustaw biernik, np.:

```text
/kozojeb imie Pandjed pandjeda
/kozojeb imie lista
```

Niepoprawna forma odrzucona przez grę jest blokowana do poprawienia.

## Opcjonalny tryb golemów — od 2.9.11

Na **prowadzącym** włącz `/kozojeb golemy on`. Tryb obsługuje łup z golemów oraz odpoczynek i powrót do patrolu po cyklu. Domyślnie jest wyłączony. Dodaje cel `golem` z odmianą `golema`, zachowując pozostałe cele, obszar, progi, tempo i pauzę po zabiciu. Wyłączenie: `/kozojeb golemy off`. Zmiana trybu podczas pracy zatrzymuje profil; po konfiguracji uruchom `/kozojeb start`.

Przykład konfiguracji drużyny:

| Profil | Komendy przed uruchomieniem |
| --- | --- |
| Faktyczny prowadzący | `/kozojeb rola prowadzacy`, `/kozojeb golemy on` |
| Profile osłaniające | `/kozojeb rola zaslony`, `/kozojeb lider auto` |
| Profile drugiej linii | `/kozojeb rola wsparcie`, `/kozojeb lider auto` |

1. **Wyłącz stary dodatkowy trigger zbierania pancerzy**, aby uniknąć nakładania komend. Nowa obsługa zbiera je do ekwipunku. Od 2.9.12 rozpoznaje również potwierdzone wkładanie pancerzy do plecaka podczas bieżącego cyklu i wyjmuje je w bazie przed przeszukiwaniem. Głównego modułu łupienia Chimery nie trzeba zastępować. Pancerze pozostawione sprzed aktualizacji obsłuż przed pierwszym cyklem; instalacja zatrzymuje bota i nie przenosi trwającego zadania między wersjami.
2. Na prowadzącym, stojąc w bezpiecznej kozobazie, wpisz `/kozojeb baza`. Zaznacz na mapie **bazę i pokoje golemów**, następnie `/kozojeb obszar`. W analizowanym logu baza golemów to 8765; sprawdź ją na swojej mapie. Poprzedni obszar 19 pokoi i baza 1097 dotyczyły wcześniejszego patrolu.
3. Zacznij w tej bezpiecznej bazie: `/kozojeb start` najpierw na osłaniających, potem na prowadzącym. Każdy ręczny start prowadzącego ustala bazę w bieżącym pokoju; nie uruchamiaj go po raz pierwszy w pokoju z golemami.

Czysty pokój z najwyżej czterema golemami, których nie jest więcej niż członków drużyny, korzysta z wyjątku od zwykłego limitu celów. Zasłony dobiera wspólny plan walki opisany powyżej.

Od 2.9.13 **prowadzący podnosi pancerz od razu po każdym potwierdzonym zabiciu golema**, także podczas dalszej walki. Używa `wez pancerz`, z potwierdzeniem podniesienia i pojedynczą kolejką dla równoczesnych zgonów. Powtórzenie komunikatu zabicia i późniejsza linia XP nie wysyłają kolejnego pobrania. Przejściowy brak przedmiotu dopuszcza jedną krótką powtórkę; brak odpowiedzi pozostaje zapisany jako niepewne podniesienie. Pilny odwrót ma pierwszeństwo. Po oczyszczeniu całego pokoju prowadzący wraca z drużyną przez dotychczasowe `/idz` do kozobazy. Tylko w bazie wykonuje kolejno `przeszukaj pancerz` → potwierdzenie `Przestajesz przeszukiwac ...` → `odloz pancerz` → potwierdzenie odłożenia.

Od 2.9.14 pierwsze pobranie ma krótkie, jednorazowe odroczenie 0,05 s do zakończenia triggerów tej samej linii. Jeśli inny trigger już wysłał `wez pancerz`, moduł oczekuje na potwierdzenie tej komendy zamiast wysyłać własną. Obsługuje to również kilka zgonów i odpowiedzi w jednym pakiecie. Stary trigger nadal zaleca się wyłączyć: moduł nie blokuje ręcznych poleceń ani poleceń innych skryptów wysłanych później. Podczas krótkiego odroczenia nowy pilny stan HP, stop lub rozłączenie blokuje wysłanie. Po zalogowaniu niewysłana operacja jest ponawiana jako niewysłana, bez dopisywania niepewnego przedmiotu do ładunku.

Żywy golem może zabrać pancerz z ziemi i wrzucić go do pieca. Rozpoznanie tego komunikatu oznacza utratę łupu, nie utratę przedmiotu już zebranego do ekwipunku. Bot pomija powtórkę pobrania przechwyconego pancerza. Szybka reakcja nie gwarantuje uratowania przedmiotu przejętego w tej samej turze serwera. Zwykły rozpad pancerza na ziemi nadal nie pomija odłożenia przedmiotu z ekwipunku. Niepowodzenie znalezienia kamienia nie kończy samo przeszukiwania.

Widoczna udana zasłona kolegi daje najpierw do 0,5 s na potwierdzenie zmiany celu w GMCP. Tego krótkiego uzgodnienia nie pomija również pilny HP; po potwierdzeniu nadal można ratować nową ofiarę przed upływem zwykłej stabilizacji, domyślnie 8 s. Przy jednakowych opisach długa blokada dotyczy wyłącznie faktycznie przejętego egzemplarza. Brak potwierdzenia nie przedłuża krótkiego oczekiwania, a powtórzone komunikaty nie przesuwają jego terminu. Nieudana para NPC–osłaniana osoba dostaje do 15 s przerwy przed kolejną zwykłą próbą. Bot rozpoznaje także szyk zdania `Yergo probuje cie zaslonic`, widoczny u chronionej postaci. W kolejce zastępstwa pierwszeństwo mają obrońcy bez napastnika, następnie wspólna kolejność nazw; przy pilnym HP oczekiwanie jest krótsze. Profile nadal nie wymieniają raportów.

Hotfix 2.9.12 uwzględnia ostatni pancerz także wtedy, gdy potwierdzenie podniesienia nadejdzie w pauzie po zakończeniu walki lub podczas powrotu. Licznik ładunku nie jest obcinany do początkowej liczby golemów. Odpowiedź „bierzesz trzy pancerze” oznacza trzy sztuki; przeniesienie znanych sztuk z plecaka nie liczy ich drugi raz. Potwierdzone schowanie uruchamia w bazie `otworz swoj plecak` i `wez pancerze z plecaka`, z oczekiwaniem na wyjęcie. Brak pancerza przy dodatnim liczniku lub `Odloz co?` wstrzymuje cykl, zamiast uznawać ładunek za obsłużony. Panel pokazuje pozostałą liczbę sztuk oraz pancerze w plecaku. Powtórne `golemy on` zachowuje aktywny cykl.

Wznowienie patrolu wymaga obsłużenia pancerzy, obecności całej zapamiętanej drużyny i **rzeczywistych 100% HP wszystkich postaci**; zaokrąglone 100% nie wystarcza. Kontrola ruchu i ekwipunku nadal obowiązuje. Dzieje się to automatycznie. Rozłączenie zachowuje etap cyklu; po niepewnym odłożeniu bot najpierw ponownie przeszukuje kolejny pancerz, zanim go odłoży. Brak potwierdzenia przeszukiwania przez 45 s lub odłożenia przez 4 s wyświetla przyczynę i pozostawia cykl w oczekiwaniu, bez kolejnych komend. Spóźniona odpowiedź jest nadal przyjmowana. Zadanie pozostaje aktywne, także gdy Mudlet dopiero później wykryje rozłączenie; po zalogowaniu wznowienie jest automatyczne. Jeżeli połączenie działa, a odpowiedź nie przychodzi, sprawdź ekwipunek i komunikaty gry. Ręczny stop, śmierć, zmiana roli lub wyłączenie trybu anuluje cykl.

Od 2.9.23 po wydobyciu kamienia i zakończeniu przeszukiwania w bazie prowadzący podaje jedną sztukę następnemu żywemu członkowi drużyny obecnemu w pokoju. Po potwierdzeniu gry odkłada pancerz i przechodzi do kolejnej sztuki. Kolejka przechodzi między cyklami oraz przez reconnect. Przy stałym składzie i potwierdzeniu wszystkich przekazań różnica wynosi najwyżej jeden kamień. Wydobycie kamienia uruchamia przekazanie jednej sztuki z ekwipunku. Od 2.9.24 prowadzący używa polecenia `daj kamien <odbiorca>`. Pełna nazwa w odpowiedzi gry potwierdza przekazanie.

`/kozojeb golemy kamienie status` pokazuje potwierdzone przekazania. Podział w trybie golemów jest domyślnie włączony. Opcje `kamienie off` i `kamienie on` sterują nim na prowadzącym. Niestandardową odmianę imienia można zapisać poleceniem `/kozojeb golemy kamienie odmiana <imie> <celownik>`. Przy braku odbiorcy kamień zostaje u prowadzącego. Brak potwierdzenia po 3 s zwalnia obsługę pancerza i wyłącza danego odbiorcę z kolejki na 30 s. Rozłączenie podczas przekazywania zachowuje już zebrane pancerze bez powtarzania niepewnego polecenia.

Potwierdzona przez grę odmowa podniesienia zbyt ciężkiego pancerza kończy próby zbierania w bieżącym pokoju. Bot kończy walkę, wraca z zebranymi pancerzami i kontynuuje odpoczynek drużyny w bazie.

`/kozojeb golemy status` i panel pokazują etap. Plan zasłon jest buforowany według istotnego stanu HP i walki; zdarzenia korzystają z istniejącej kolejki decyzji. Timery działają tylko dla oczekującej operacji, podniesienia lub krótkiego zastępstwa obrońcy. Duplikaty odmowy pobrania współdzielą jeden timer powtórki. Tekstowe `kondycja` czeka podczas przeszukiwania i podawania kamienia, a kontrola GMCP pozostaje aktywna. `/kozojeb wydajnosc` pokazuje również liczbę przeliczeń planu; notatka wykonanej zasłony zawiera opis i lokalne ID NPC. Nie ma nowego stałego odpytywania ani analizy każdej linii obrażeń.

## Odwrót, sprzęt i ponowne logowanie

- Prowadzący decyduje o odwrocie według własnego HP, HP drużyny i własnego zmęczenia.
- Przy nieudanej lub niedostępnej bezpiecznej osłonie prowadzący może wycofać drużynę wcześniej: poniżej mniejszej wartości z `prog zasłony - 1` i `próg odwrotu drużyny + 15`. Przykładowo progi 50%/80% dają dodatkową granicę 65%. Wyłączenie kontroli HP drużyny przez `progdruzyny 0` wyłącza też ten dodatkowy odwrót. Wspierający nie wykonują osobnego odwrotu ani raportowania.
- Od 2.9.4 własna trwająca próba zasłony nie wywołuje sprzecznego odwrotu tylko z powodu zajętego szyku. Oczekiwanie na odpowiedź trwa najwyżej 2 s od komendy, a po sukcesie najwyżej 0,5 s na uzgodnienie relacji walki, w granicach pierwotnych 2 s. Dotyczy wyłącznie osłanianej osoby przy niezmienionych napastnikach i HP. Krytyczne HP, dalsza utrata zdrowia, zmiana napastników, odmowa zasłony lub zagrożenie innego członka nie korzystają z tej zwłoki. Nie zmienia to progów odwrotu.
- Od 2.9.1 prowadzący przez 8 s pamięta największy ostatni spadek HP w bieżącym pokoju. Przy stracie co najmniej 15% maksymalnego HP i nadal atakującym NPC zachowuje rezerwę na kolejny taki cios ponad skonfigurowany próg odwrotu. Przykład: próg 50%, ostatni spadek 25 punktów procentowych, teraz 74% — możliwy wcześniejszy odwrót. Przy zagrożonym koledze bezpieczna dostępna zasłona jest rozważana przed tym dodatkowym odwrotem. `progdruzyny 0` wyłącza rezerwę drużynową. Jest to reakcja na zaobserwowane HP, a nie przewidywanie pierwszego silnego ciosu, pancerza czy umiejętności przeciwnika.
- Śmierć własnej postaci zatrzymuje bota i anuluje oczekujące wznowienie.
- Od 2.9.7 po odwrocie każdy członek drużyny, także prowadzący, musi osiągnąć domyślnie **95% HP**. Ustawienie na prowadzącym: `/kozojeb powrothp 95`; `/kozojeb powrothp 100` wymaga pełnej regeneracji wszystkich. Próg jest zapisywany na profilu i musi być wyższy od obu progów odwrotu. Zmiana późniejszego progu odwrotu nie pozwala wznowić zadania poniżej niego. Ustawienia wspierających nie sterują wspólnym powrotem.
- Jeśli od rozpoczęcia odwrotu postać spadnie poniżej swojego właściwego progu odwrotu (prowadzący: `prog`, pozostali: `progdruzyny` prowadzącego), wymaga rzeczywistych **100% HP** do końca tego leczenia i drogi powrotnej. Dotyczy również kolejnych rannych oraz zwykłej drogi do bazy, bez konieczności wystąpienia awaryjnego wyjścia. Pamięć obejmuje wszystkich takich członków i przeżywa rozłączenie. Obniżenie `powrothp` nie usuwa tego wymogu.
- Warunek regeneracji używa pełnych par `hp/maxhp`, bez zaokrąglania w górę. Widoczne po zaokrągleniu 95% przy faktycznych 94,6% nie wystarcza; tak samo 99,6% nie oznacza pełnych HP po stanie krytycznym. Każda postać jest oceniana względem własnego maksimum. Osoba wskazana przy odwrocie nie ma pierwszeństwa przed innymi rannymi.
- Od 2.9.15 świeży, kompletny skład `Group.State` pozwala przestać czekać na osobę, która rzeczywiście opuściła drużynę. Niewidoczny członek nadal figurujący w składzie pozostaje wymagany. Niepełne lub stare dane oraz nierozpoznane ID nie usuwają nikogo z oczekiwania.
- Przed powrotem bot nadal wymaga zebrania wcześniej obecnych i nowo dołączających członków, znanych HP, odpowiedniego ruchu, sprawnego sprzętu oraz zakończenia walki. Brak postaci lub odczytu nie oznacza wyzdrowienia. Panel pokazuje osobno wszystkich blokujących powrót, z bieżącym i wymaganym HP, zmęczeniem lub brakiem w pokoju. `progdruzyny 0` nie wyłącza regeneracji całej drużyny.
- Po drodze powrotnej prowadzący sprawdza te same warunki ponownie, ze świeżych danych przybycia. Obrażenia lub brakujący gracz zatrzymują wznowienie patrolu i przedłużają odpoczynek; atak nadal uruchamia dotychczasową ochronę i ewakuację. Sprawdzenie korzysta z istniejącego timera leczenia co 3 s i jednorazowego krótkiego uzgodnienia pakietów przybycia. Nie dodaje stałego odpytywania ani komunikacji między profilami.
- Od 2.9.5 leczenie nie wyłącza ochrony drużyny. Świeże dane o ataku NPC na odpoczywającą drużynę uruchamiają awaryjne wyjście prowadzącego, także zanim HP stanie się krytyczne. Bot wybiera zwykłe wyjście zapisane na mapie, preferując pokój poza obszarem patrolu i kierunek inny niż ostatnia droga przybycia. Pomija miejsca odrzucone w tej ewakuacji oraz znane miejsce rozpoczęcia odwrotu. Nie korzysta z wymyślonych kierunków ani wyjść specjalnych.
- Po każdym kroku czeka na potwierdzenie pokoju i świeże dane walki. Jeśli atak trwa, może wykonać kolejny krok; cała ewakuacja ma najwyżej trzy próby ruchu, bez powrotu do odrzuconych miejsc. Odmowa wyjścia pozwala wybrać inne, brak potwierdzenia ma limit czasu, a odmowa z powodu zmęczenia wymaga świeżego odczytu sił i nie zużywa próby trasy. Przy braku wyjścia bot nadal może wykonywać bezpieczne zasłony i wyświetla przyczynę blokady; odczyt mapy jest ponawiany najwyżej trzy razy.
- Nowe miejsce leczenia jest sprawdzane po przybyciu — mapa nie gwarantuje, że sąsiedni pokój będzie bezpieczny. Potwierdzone miejsce pozostaje awaryjnym celem następnych odwrotów do zatrzymania zadania. Ustawiony start patrolu nie jest zmieniany; po pełnej regeneracji i zebraniu drużyny bot wraca do niego. Panel pokazuje awaryjne miejsce leczenia. Rozłączenie zachowuje ten kontekst, ręczny stop, śmierć i zmiana roli go anulują. Wspierający nie wykonują własnej ewakuacji ani raportowania.
- Ręczne `/kozojeb baza`, `startpokoj <ID>` lub `bezczynnosc <sekundy> <ID>` zastępuje wcześniejsze awaryjne miejsce odwrotu. Bot nie kieruje kolejnego odwrotu do starego schronienia po wskazaniu nowej bazy.
- Pęknięcie własnego lub widocznego drużynowego ekwipunku uruchamia wspólny odwrót i blokuje automatyczne wznowienie. Uzupełnij sprzęt i wpisz na prowadzącym `/kozojeb ekwipunek gotowy`.
- Rozłączenie wstrzymuje komendy i zapamiętuje aktywne zadanie. Po ponownym zalogowaniu Kozojeb **automatycznie je wznawia, bez `/kozojeb start`**. Wymaga świeżego pokoju i listy encji z własną postacią oraz kompletnym HP. Po krótkiej pauzie 0,5 s ocenia aktualny stan. Przy zwykłym zerwaniu połączenia brak ponownego wysłania niezmienionych `Group.State`, `Combat.State` lub `Char.Vitals` nie blokuje wznowienia. Po ciszy wykrytej przez watchdog wymagany jest dodatkowo świeży `Combat.State`; ograniczone odświeżanie GMCP działa również po późniejszym rozłączeniu. Starsze dane walki i składu drużyny pozostają odfiltrowane; drużyna może być rozpoznana po rolach na świeżej liście encji. Ruch jest monitorowany według ostatniego znanego odczytu, aż przyjdzie jego aktualizacja.
- Przed wznowieniem patrolu prowadzący czeka na wcześniej widocznych członków drużyny. Ich nieobecność nie blokuje pilnego odwrotu ani kontynuacji leczenia; zebranie drużyny jest wtedy sprawdzane w bazie. Wspierający wracają do swoich ról bez własnego ruchu. Panel pokazuje konkretny brakujący odczyt albo gracza, gdy wznowienie nadal oczekuje.
- Automatyczne wznowienie zachowuje bazę, obszar i postęp patrolu. Trwający odwrót, leczenie lub powrót jest kontynuowany. Cel walki i kolejny krok są wybierane ponownie z aktualnych danych. Logowanie i ponowne połączenie obsługuje Mudlet oraz dotychczasowa konfiguracja profilu.
- `/kozojeb stop` anuluje również oczekujące wznowienie. Bot zatrzymany przed rozłączeniem pozostaje zatrzymany. Zmiana roli anuluje poprzednie zadanie; logowanie inną postacią również go nie wznawia. Po aktualizacji paczki bot pozostaje zatrzymany.
- Po wysłaniu ruchu bot czeka na potwierdzenie pokoju i nową listę encji, zanim wybierze cel do ataku.

`/kozojeb stop` zatrzymuje Kozojeba na danym profilu. Zatrzymanie wszystkich profili wymaga tej komendy na każdym z nich. Trwającą walkę i zewnętrzny chodzik obsługuje gra oraz główne skrypty Chimery.

## Aktualizacje z GitHuba

Jeśli masz już Kozojeba 2.8.1–2.9.24, wykonaj na **każdym profilu**:

```text
/kozojeb stop
/kozojeb repo gurninson-sketch/kozojeb
/kozojeb autoaktualizacja on
/kozojeb aktualizuj
```

Poczekaj na zakończenie walki i ruchu oraz komunikat `Zainstalowano 2.9.25`. Sprawdź `/kozojeb status`; powinien pokazać wersję **2.9.25**. Wyłącz stary dodatkowy trigger pancerzy — podniesienia po każdym zabiciu są już wbudowane. Skontroluj `/kozojeb druzyna role` na każdym profilu; domyślnie nie ma przypisań zależnych od imion. Własne role profili i inne własne modele pozostają zapisane. Opcjonalnie włącz `/kozojeb swiatlo on` na postaciach z lampą i paliwem; opcja działa tylko przy wykrytej utracie widoczności. Następnie uruchom `/kozojeb start` — najpierw na wspierających, potem na prowadzącym stojącym w bazie. To jednorazowy start po aktualizacji; późniejsze rozłączenia nie wymagają ręcznego wznowienia. Nie trzeba usuwać ani ręcznie instalować paczki; można przejść bezpośrednio z 2.9.2 do 2.9.25. Zwykły próg regeneracji wynosi domyślnie 95%; można go zmienić przez `/kozojeb powrothp 95`. Tryb golemów wymaga osobnego włączenia i w swoim cyklu czeka na 100% całej drużyny.

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

## Zapis HP, walki i zasłon — od 2.9.18

Zapis jest domyślnie **włączony** na każdym profilu i działa przy uruchomionym bocie podczas walki, odwrotu i leczenia, także w roli `wsparcie` oraz przy ręcznym prowadzeniu z automatycznymi zasłonami. Ustawienie jest zapisywane osobno na profilu. Nie wymaga aliasu `lua` ani dodatkowego odpytywania serwera.

```text
/kozojeb zapis status
/kozojeb zapis teraz
/kozojeb zapis off
/kozojeb zapis on
```

`status` pokazuje stan rejestratora i pełne ścieżki plików. `teraz` zapisuje pojedynczy stan na żądanie, również przy zatrzymanym bocie lub wyłączonym zapisie automatycznym. `off` opróżnia bufor i wyłącza dalsze automatyczne zapisy. Pliki znajdują się w katalogu bieżącego profilu Mudleta:

- `kozojeb-walka.jsonl` — bieżące dane;
- `kozojeb-walka.jsonl.1` — poprzednia część, jeśli nastąpiła rotacja.

Limit wynosi **8 MiB na plik**, zachowywana jest jedna poprzednia część. Kolejna rotacja zastępuje starszą kopię. Do analizy dołącz oba istniejące pliki z każdego badanego profilu oraz zwykły log tekstowy. Pliki nie są automatycznie wysyłane ani umieszczane w repozytorium.

Od **2.9.19** komendy `/kozojeb wydajnosc` i `/kozojeb zapis status` pokazują czas przygotowania próbki oraz osobno zapisania partii do pliku. Dla obu operacji podają liczbę pomiarów, średnią, p95 i maksimum w milisekundach — osobno CPU (`os.clock`) oraz czas rzeczywisty obejmujący oczekiwanie. Średnia i maksimum obejmują okres od załadowania skryptu, p95 ostatnie 128 operacji. Zapis wywołany podczas przygotowania próbki jest odjęty od jej pomiaru, więc nie liczy się podwójnie. Są to pomiary tych dwóch operacji na tym profilu, nie całego Mudleta ani opóźnienia sieci. Zapytanie o statystyki nie uruchamia testu obciążenia i nie opróżnia bufora. JSONL zawiera zbiorcze metryki poprzednich zakończonych operacji w `recorder_performance`, bez dodatkowego strumienia próbek. Pole źródła `fresh` nadal oznacza odebranie danych w bieżącej sesji; nowe `recent` informuje osobno, czy pakiet odebrano w ostatnich 15 s. Stary niezmieniony pakiet nie jest sam w sobie dowodem zerwania połączenia i nie wywołuje automatycznego reconnect.

Od **2.9.20** rejestrator zachowuje także niewidocznych członków z surowego `Group.State` oraz ich dostępne pary HP. Nieznane ID napastników trafiają do `unresolved_incoming`, oddzielnie od rozpoznanych NPC. Nierozpoznana walka, rany i utrata widoczności mogą uruchomić próbkę bez znanej encji przeciwnika. Pole `safety` pokazuje brak lidera, powód oczekiwania, utratę widoczności, blokadę po zgonie i stan własnego światła. Znana nazwa profilu pozostaje zachowana, nawet gdy serwer zastąpi nazwę własnej postaci słowem `Ktos`. Procentowe `Char.Vitals` jest zapisywane osobno i nie zastępuje punktów HP bez własnego maksimum. Pozostają dotychczasowy limit próbek, buforowanie, rotacja i pomiary kosztu; brak nowego stałego odpytywania.

Jeśli podczas automatycznego odwrotu pojawi się `(Chimera) Chodzik zatrzymany: atak.`, Kozojeb czeka na potwierdzenie wykonanego kroku i dane nowego pokoju, po czym wznawia `/idz` do dotychczasowej bazy. Postęp nie zużywa limitu nieudanych prób trasy. Bez potwierdzenia ruchu nadal działa zwykły watchdog i ograniczenie ponowień. Mechanizm dotyczy roli `prowadzacy` w trybie odwrotu; nie uruchamia ruchu wspierających ani ręcznego lidera w roli `zaslony` i nie zmienia globalnych ustawień chodzika. Stop, rozłączenie i dojście do bazy anulują oczekujące wznowienie.

Opóźniona aktualizacja numeru pokoju na mapie po `Room.Info` jest uzgadniana z istniejącymi pakietami, bez nowej pętli odpytywania. Lista encji odebrana już dla nowego hasha zachowuje prawdziwą rewizję; zgodny stan walki może zostać wykorzystany bez czekania na ponowne wysłanie identycznego pakietu. Sam opis poprzedniej lokacji nie potwierdza ruchu. Przy przekroczeniu limitu celów bot nadal opuszcza pokój, lecz potwierdzone wyjście nie wywołuje dodatkowego odwrotu do bazy. Metryki pokazują liczbę takich uzgodnień, a JSONL także kierunek, początek oczekującego kroku i stan pomijania zatłoczonego pokoju. Nowa komenda `/kozojeb start` nadal ustala bazę w aktualnym pokoju; po ręcznym stopie uruchom prowadzącego w wybranej bazie.

Po udanej częściowej zasłonie, np. przejęciu jednego z dwóch NPC, niezmieniony ranny członek drużyny zachowuje dotychczasowe okno do 0,5 s na przejęcie pozostałego napastnika przez kolegę. Spadek poniżej progu drużyny, nowy napastnik lub następny groźny cios kończy oczekiwanie. Brak dokończenia ochrony nie wydłuża tego terminu.

Każdy wiersz JSONL jest osobnym rekordem ze znacznikiem czasu odbiorcy, wersją i sesją. Zmieniony stan jest zapisywany najwyżej **raz na sekundę**; identyczne stany są pomijane. To próbkowanie, więc nie zachowuje każdej pośredniej zmiany HP między próbkami. Osobne zdarzenia wysłania zasłony, odpowiedzi gry, odmowy, widocznego zastępstwa i faktycznego odwrotu mają własne czasy niezależnie od tego limitu. Dane trafiają na dysk partiami, najpóźniej po 5 s; zwykły stop, wyjście, przeładowanie i rozłączenie opróżniają bufor. Awaryjne zamknięcie procesu może utracić ostatnią buforowaną partię.

Zapis obejmuje HP i maksymalne HP wszystkich rozpoznanych członków, procent bez zaokrąglenia, oddzielne wartości `Group.State` i `Room.Entities`, stany postaci, napastników NPC i ich HP, wybrany cel, surowe relacje `covers`, tryb, rolę, progi oraz lokalną gotowość szyku. Własne procentowe `Char.Vitals.hp` bez `maxhp` jest oznaczane osobno jako `hp_percent`; nie zostaje potraktowane jak punkty HP ani nie zmienia działania parsera bojowego. Czasy odbioru, wiek i gotowość kanałów pomagają odróżnić bieżący odczyt od starego. `covers` nie zastępuje relacji ataków NPC.

Kontrole faktycznie wykonane przez ten profil mają kody przyczyn: m.in. `hp_gap`, `hp_reserve`, `ambiguous_selector`, `unsafe_projection`, `cover_hold`, `transfer_hold`, `formation_busy`, `reply_pending`, `defender_turn`, `hp_above_threshold` i `no_npc`. To ślad rozważanych kandydatów, nie symulacja dodatkowych decyzji. Zasłona innego celu może pozostawić wpisy wcześniejszych odrzuconych kandydatów. Zapis przechowuje najwyżej 24 członków, 32 NPC i 64 kontrole na próbkę; pole `truncated` oznacza ograniczenie rozmiaru. Nie zmienia komend, ról, prowadzenia, progów odwrotu ani wymagań regeneracji. Błąd pliku wyłącza rejestrator do ponownego `zapis on`, zgłasza jedną informację i pozostawia bota w pracy.

`/kozojeb diagnostyka` pokazuje te liczniki oraz bieżący tryb, rolę, pokój, ID celu, gotowość danych i oczekujący ruch. Podaje czas od ostatniego odebranego GMCP, własnego ciosu, postępu bota i decyzji. Watchdog zapisuje ten sam krótki stan przed decyzją o powrocie lub oczekiwaniu na świeże dane. Identyczny pakiet GMCP aktualizuje czas odbioru, lecz nie udaje postępu. Diagnostyka działa na żądanie lub przy faktycznym zastoju; sama nie dodaje timera, odpytywania ani rejestratora pakietów. Oczekiwanie na utracone dane korzysta z osobnego odświeżenia najwyżej raz na 15 sekund. Sam zapis nie rozstrzyga przyczyny zerwania TCP.

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

Od 2.9.14 komunikat o nowym połączeniu do tej samej postaci lub pytanie o przejęcie kontroli wyświetla jedną diagnostykę konfliktu sesji i zapis w panelu. Powtórzone pytania nie zasypują konsoli. Po rzeczywistym zalogowaniu i automatycznym wznowieniu zapis znika. Pozostaw jedną aktywną sesję danej postaci; dwie instancje automatycznego logowania mogą odbierać sobie kontrolę. Bot nie wysyła automatycznej odpowiedzi `t` i nie traktuje samego zestawienia połączenia TCP jako wejścia do gry.

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
