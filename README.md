# Chimera Kozojeb 2.9.1

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
| Morrid | `/kozojeb rola zaslony` oraz `/kozojeb lider auto` | Wsparcie i osłanianie prowadzącego |
| Yergo i Gror | `/kozojeb rola wsparcie` oraz `/kozojeb lider auto` | Druga linia: wsparcie i DPS, bez automatycznych zasłon |

Wspierający dołączają do walki przez `wesprzyj`; dalsze ataki wykonuje gra. Nie patrolują, nie ścigają przeciwników i nie wykonują własnego odwrotu, leczenia, `/idz` ani opuszczania drużyny. Nie przesyłają raportów między profilami. Ruch za prowadzącym zapewnia drużyna w grze.

Zmiana roli zatrzymuje bota. Po skonfigurowaniu uruchom go przez `/kozojeb start` na każdym profilu. Wspierających można uruchomić przed prowadzącym. Bez widocznego, faktycznego prowadzącego czekają.

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

Limit stworów dotyczy rozpoczynania nowego ataku. Agresywny NPC może rozpocząć walkę niezależnie od tego limitu. `/kozojeb baza` zmienia bazę na bieżący pokój, ale kolejne `/kozojeb start` ponownie ustawia ją w miejscu uruchomienia.

## Zasłony i HP

Własne HP jest liczone z kompletnej pary `hp/maxhp` z jednego źródła GMCP. Niepełny odczyt nie łączy wartości z `Char.Vitals` i `Room.Entities`; jeśli oba źródła są niepełne, bot zachowuje ostatni poprawny wynik. Pełne, nowsze `Char.Vitals` nadal ma pierwszeństwo przed starszym odczytem encji.

Na profilu osłaniającym prowadzącego:

```text
/kozojeb proglidera 85
/kozojeb minhpzaslony 50
```

Te progi dopuszczają rozważenie zasłony: HP prowadzącego musi być **poniżej 85%**, własne HP **co najmniej 50%**, żywy NPC musi faktycznie atakować prowadzącego, a szyk musi być gotowy. Sama różnica procentów nie wystarcza do wykonania osłony. Przy równych 85% zasłona nie następuje. `/kozojeb proglidera 0` wyłącza tę zasłonę.

`/kozojeb progzaslony 70` ustawia zasłony wykonywane przez prowadzącego na rannych członkach drużyny. Ten próg musi być wyższy od progów odwrotu. Własne minimum `/kozojeb minhpzaslony` działa niezależnie w obu rolach wykonujących zasłony. Na wspierającym `/kozojeb prog 50` jest skrótem ustawienia własnego minimum zasłon; na prowadzącym pozostaje progiem odwrotu.

Od wersji 2.9.0 decyzja uwzględnia punkty HP obu postaci, liczbę unikalnych napastników NPC oraz ostatnie spadki HP. Dla przykładu 60% z 1200 HP oznacza więcej życia niż 78% z 600 HP. Pełne pary `hp/maxhp` drużyny wybierane są według nowszego zdarzenia `Room.Entities` albo `Group.State`; starszy odczyt nie przesłania nowszego. Punkty do porównania obu graczy pochodzą ze wspólnego kanału. `Char.Vitals` nie dostarcza punktów do bezpośredniego porównywania różnych postaci.

Bot ocenia obciążenie przed i po przejęciu jednego NPC. Kolejny napastnik ma większy koszt niż pierwszy. Zasłona musi poprawiać oceniany zapas obrony obu postaci co najmniej o 15%; duży niedawny spadek HP zmniejsza ten zapas. Jest to ostrożna heurystyka, nie dokładny model pancerza, umiejętności ani obrażeń przyszłego przeciwnika. Przy komendzie wskazującej osobę sprawdzany jest najmniej korzystny wariant wyboru jej napastnika. Gdy nie można uzyskać porównywalnych HP, automatyczna zasłona czeka na pełne dane.

```text
/kozojeb limitzaslony 2
/kozojeb stabilizacja 8
```

Domyślnie zasłona nie może podnieść liczby napastników osłaniającego powyżej **2** (ustawienie 1–5). Nie jest to limit samoczynnej agresji NPC ani polecenie rozdzielania przeciwników na profile drugiej linii. Po potwierdzonej w GMCP zmianie obrońcy konkretnego NPC bot przez **8 sekund** ogranicza oddawanie go poprzedniemu obrońcy. Wyjątkiem jest stan bliski progowi odwrotu albo znaczna, co najmniej 40-procentowa poprawa oceny bezpieczeństwa. Identyczne opisy NPC są rozróżniane po ID. Po zmianie pokoju i sesji historia jest czyszczona. Dawna reguła przewagi 5 punktów procentowych została zastąpiona tą oceną.

Każda próba rezerwuje zmianę szyku od razu. Bot czeka na `Jestes gotowy do zmiany w szyku.`; limit awaryjny przy braku komunikatu wynosi 10 sekund. Nieudana próba umiejętności również zużywa gotowość szyku.

Odmiany imion są zapisane dla Yarrima, Morrida, Yerga i Grora. Dla kolejnej postaci ustaw biernik, np.:

```text
/kozojeb imie Pandjed pandjeda
/kozojeb imie lista
```

Niepoprawna forma odrzucona przez grę jest blokowana do poprawienia.

## Odwrót, sprzęt i ponowne logowanie

- Prowadzący decyduje o odwrocie według własnego HP, HP drużyny i własnego zmęczenia.
- Przy nieudanej lub niedostępnej bezpiecznej osłonie prowadzący może wycofać drużynę wcześniej: poniżej mniejszej wartości z `prog zasłony - 1` i `próg odwrotu drużyny + 15`. Przykładowo progi 50%/80% dają dodatkową granicę 65%. Wyłączenie kontroli HP drużyny przez `progdruzyny 0` wyłącza też ten dodatkowy odwrót. Wspierający nie wykonują osobnego odwrotu ani raportowania.
- Od 2.9.1 prowadzący przez 8 s pamięta największy ostatni spadek HP w bieżącym pokoju. Przy stracie co najmniej 15% maksymalnego HP i nadal atakującym NPC zachowuje rezerwę na kolejny taki cios ponad skonfigurowany próg odwrotu. Przykład: próg 50%, ostatni spadek 25 punktów procentowych, teraz 74% — możliwy wcześniejszy odwrót. Przy zagrożonym koledze bezpieczna dostępna zasłona jest rozważana przed tym dodatkowym odwrotem. `progdruzyny 0` wyłącza rezerwę drużynową. Jest to reakcja na zaobserwowane HP, a nie przewidywanie pierwszego silnego ciosu, pancerza czy umiejętności przeciwnika.
- Śmierć własnej postaci zatrzymuje bota i anuluje oczekujące wznowienie.
- Po odwrocie czeka na swoje pełne HP, wymagany poziom ruchu oraz obecność i znane HP wcześniej widocznych członków drużyny. Osoba, której rany wywołały odwrót, musi odzyskać 100% HP.
- Pęknięcie własnego lub widocznego drużynowego ekwipunku uruchamia wspólny odwrót i blokuje automatyczne wznowienie. Uzupełnij sprzęt i wpisz na prowadzącym `/kozojeb ekwipunek gotowy`.
- Rozłączenie wstrzymuje komendy i zapamiętuje aktywne zadanie. Po ponownym zalogowaniu Kozojeb **automatycznie je wznawia, bez `/kozojeb start`**. Wymaga świeżego pokoju i listy encji z własną postacią oraz kompletnym HP. Po krótkiej pauzie 0,5 s ocenia aktualny stan. Brak ponownego wysłania niezmienionych `Group.State`, `Combat.State` lub `Char.Vitals` nie blokuje wznowienia. Starsze dane walki i składu drużyny pozostają odfiltrowane; drużyna może być rozpoznana po rolach na świeżej liście encji. Ruch jest monitorowany według ostatniego znanego odczytu, aż przyjdzie jego aktualizacja.
- Przed wznowieniem patrolu prowadzący czeka na wcześniej widocznych członków drużyny. Ich nieobecność nie blokuje pilnego odwrotu ani kontynuacji leczenia; zebranie drużyny jest wtedy sprawdzane w bazie. Wspierający wracają do swoich ról bez własnego ruchu. Panel pokazuje konkretny brakujący odczyt albo gracza, gdy wznowienie nadal oczekuje.
- Automatyczne wznowienie zachowuje bazę, obszar i postęp patrolu. Trwający odwrót, leczenie lub powrót jest kontynuowany. Cel walki i kolejny krok są wybierane ponownie z aktualnych danych. Logowanie i ponowne połączenie obsługuje Mudlet oraz dotychczasowa konfiguracja profilu.
- `/kozojeb stop` anuluje również oczekujące wznowienie. Bot zatrzymany przed rozłączeniem pozostaje zatrzymany. Zmiana roli anuluje poprzednie zadanie; logowanie inną postacią również go nie wznawia. Po aktualizacji paczki bot pozostaje zatrzymany.
- Po wysłaniu ruchu bot czeka na potwierdzenie pokoju i nową listę encji, zanim wybierze cel do ataku.

`/kozojeb stop` zatrzymuje Kozojeba na danym profilu. Zatrzymanie wszystkich profili wymaga tej komendy na każdym z nich. Trwającą walkę i zewnętrzny chodzik obsługuje gra oraz główne skrypty Chimery.

## Aktualizacje z GitHuba

Jeśli masz już Kozojeba 2.8.1–2.9.0, wykonaj na **każdym profilu**:

```text
/kozojeb stop
/kozojeb repo gurninson-sketch/kozojeb
/kozojeb autoaktualizacja on
/kozojeb aktualizuj
```

Poczekaj na zakończenie walki i ruchu oraz komunikat `Zainstalowano 2.9.1`. Sprawdź `/kozojeb status`; powinien pokazać wersję **2.9.1**. Następnie uruchom `/kozojeb start` — najpierw na wspierających, potem na prowadzącym. To jednorazowy start po aktualizacji; późniejsze rozłączenia nie wymagają ręcznego wznowienia. Nie trzeba usuwać ani ręcznie instalować paczki; ustawienia profili pozostają zachowane.

Przy paczce zbudowanej w tym repozytorium adres wydań jest wbudowany. W paczce przygotowanej bez adresu skonfiguruj na każdym profilu:

```text
/kozojeb repo gurninson-sketch/kozojeb
/kozojeb autoaktualizacja on
/kozojeb aktualizuj
```

Adres repozytorium ma postać `OWNER/REPO`, bez `https://`. Repozytorium z wydaniami musi być publicznie dostępne. Ta wersja aktualizatora nie przechowuje tokenów GitHuba i nie pobiera prywatnych wydań.

Aktualizator sprawdza wydanie 30 sekund po załadowaniu profilu, a następnie co 6 godzin. Ręczne `/kozojeb aktualizuj` działa również przy wyłączonym sprawdzaniu automatycznym. Pobiera tylko opublikowane stabilne wydania z **Releases**. Zmiany na `main` i wydania robocze nie aktualizują profili.

Instalacja czeka na zatrzymanie bota, zakończenie własnej walki i aktualne dane pokoju. Nie zatrzymuje samodzielnie prowadzącego ani wspierających. Bot po aktualizacji pozostaje zatrzymany; uruchom go przez `/kozojeb start`.

Przed podmianą sprawdzane są rozmiar, format i SHA-256 paczki. Bieżące skrypty są zachowywane w kopii `kozojeb_rollback/Chimera_Kozojeb.xml` w katalogu profilu. Gdy nowa wersja nie zainstaluje się poprawnie, aktualizator próbuje przywrócić tę kopię. Można ją też zainstalować ręcznie przez Menedżer pakietów.

Konfiguracja — w tym obszar, cele, prędkości, progi, role i odmiany — pozostaje w katalogu danego profilu, poza katalogiem paczki. Aktualizacja nie przenosi ustawień pomiędzy postaciami. Pierwsze przejście z KozoBota importuje dostępne wcześniejsze ustawienia profilu i obszar; po zmianach zapisz profil Mudleta.

## Wydajność i powtarzane komendy

Kolejne zdarzenia GMCP współdzielą jeden oczekujący timer decyzji (zwykle 0,12 s). Krytyczny odczyt HP prowadzącego lub drużyny jest sprawdzany od razu, bez oczekiwania na tę kolejkę. Dane HP, indeks encji oraz relacje walki są obliczane raz dla aktualnego stanu i wykorzystywane ponownie. Aktualizacje walki i własnych parametrów nie przebudowują indeksu niezmienionej listy encji.

Watchdog uwzględnia zmiany pełnych HP z `Char.Vitals`, `Group.State` i `Room.Entities`, również mniejsze od zaokrąglonego procenta, oraz rzeczywiste własne ciosy. Przesuwa znacznik czasu bez tworzenia nowego timera przy każdym pakiecie lub ciosie. Identyczne pakiety nie udają postępu. Po powrocie do bazy restart czeka na świeży pokój i kompletne HP, zachowując aktywne zadanie. Nie wymaga ręcznego startu po spóźnionej liście encji; ręczny stop anuluje oczekiwanie.

Potwierdzenie własnej walki, w tym odpowiedź `Juz walczysz`, powstrzymuje kolejne `wesprzyj` dla tego samego starcia. Krótkie przejście od tekstowej informacji o walce do konkretnego ID przeciwnika zachowuje potwierdzenie. Po odmowie wsparcia bot czeka na zmianę relacji walki lub nowy komunikat walki; identyczne pakiety, kolejność i duplikaty relacji nie wystarczają. Potwierdzona śmierć jednoznacznie rozpoznanego NPC blokuje reakcje na jego stare dane.

Własna relacja ataku na wybrany cel potwierdza walkę także wtedy, gdy `primary` wskazuje innego agresora. Przy braku potwierdzenia bot wysyła najwyżej trzy próby ataku dla niezmienionego stanu, z odstępami 1 i 2 s; kolejne wymagają zmiany walki. To ogranicza komendy Kozojeba; inne skrypty i ręczne aliasy mogą nadal wysyłać własne polecenia.

Po pustych pełnych okrążeniach patrol stopniowo zwalnia. Domyślny maksymalny odstęp wynosi 3 sekundy na krok. Nowy cel jest sprawdzany po GMCP bez czekania na wolniejszy krok, a walka przywraca zwykłe tempo. Ustawienie jest lokalne dla profilu:

```text
/kozojeb pustypatrol 3
/kozojeb pustypatrol 0
/kozojeb wydajnosc
```

`0` wyłącza zwalnianie. `wydajnosc` wypisuje liczniki zdarzeń, decyzji, przeliczeń, ataków i ich ponowień, powrotów watchdogu oraz oczekiwań na restart od załadowania skryptu; nie jest pomiarem całkowitego CPU Mudleta. Nie uruchamia nagrywania pakietów, pętli odpytywania, testów sieciowych ani zapisu logu na dysk. Dane obserwacji są ograniczone do widocznych członków drużyny i NPC bieżącego pokoju.

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
