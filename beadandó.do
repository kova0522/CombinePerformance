cls
clear all
global mappa "C:\Users\win10\OneDrive\Dokumentumok\Egyetemi anyagok\adatelemzés\beadandó"
cd "$mappa"
pwd

*csv fájlok átalakítása dta formátumba
forvalues year = 14/22 {
	forvalues i = 1/2{
		     clear
             import delimited combine_`year'_`i'.csv, varname(1)
             save combine_`year'_`i'.dta, replace
	}
 } 
 
* behozom az adatokat
clear all
forvalues year = 14/22 {
	forvalues i = 1/2{
		     append using combine_`year'_`i'.dta
	}
 }
 
* a felesleges oszlopokat kitörlöm
drop ïrk v8

* duplikált és üres sorokat törlöm
duplicates drop
drop if player == "Player"

*formátumokat beállítom
foreach name in av year age wt yd vertical benchreps broadjump cone shuttle{
	gen `name'_n = real(`name')
	drop `name'
	rename `name'_n `name'
}

*magasságot cm-re átváltom
split height, p("-")
gen height_n = 2.54*(12*real(height1)+real(height2))
drop height height1 height2
rename height_n height
*súlyt kg-ra átváltom
gen weight = wt *0.45359237
drop wt
order weight, before(height)

*draftolás oszlopot felosztom
rename draftedtmrndyr drafted
split drafted, p(" / ")
drop drafted
rename drafted1 drafted_team
rename drafted2 drafted_rnd
rename drafted3 drafted_pick
drop drafted4
split drafted_rnd, ignore("th" "nd" "st" "rd") destring
split drafted_pick, ignore("th" "nd" "st" "rd") destring
drop drafted_rnd drafted_pick drafted_pick2
rename drafted_rnd1 drafted_rnd
rename drafted_pick1 drafted_pick 

*üres adatok kezelése
*megnézem, hogy az adott játékos, hány mérésben nem vett részt
gen ures = 0
foreach col in vertical yd benchreps broadjump cone shuttle{
	replace ures = ures+1 if `col' == .
}

*pozíciók egységesítése
replace pos = "OL" if pos == "OG" | pos == "OT"

*pozíciók számszerűsítése

encode pos, gen(pos_n)
order pos_n, before(pos)
drop pos
rename pos_n pos

*iskolák számszerűsítése
encode school, gen(school_n)
order school_n, before(school)
drop school
rename school_n school

* csapatok névváltozásának megoldása
replace drafted_team = "Washington Commanders" if drafted_team == "Washington Football Team" | drafted_team == "Washington Redskins"

replace drafted_team = "Los Angeles Rams" if drafted_team == "St. Louis Rams"

replace drafted_team = "Las Vegas Raiders" if drafted_team == "Oakland Raiders"

replace drafted_team = "Los Angeles Chargers" if drafted_team == "San Diego Chargers"
*nfl csapatok számszerűsítése
encode drafted_team, gen(drafted_team_n)
order drafted_team_n, before(drafted_team)
drop drafted_team
rename drafted_team_n drafted_team

*BMI változó létrehozása
gen BMI = weight/(height/100)^2

*av oszlop üres oszlopait 0-ra állítom
replace av = 0 if av == .

*---------------------------------------------------*
*elemzés
*bizonyos NFL csapatok eredményesebbé teszik a játékosokat? vagy a draft pozíciójuk jobb?
*nfl csapatok átlagos draft pozíciója --> van eltérés, vannak jobb helyen draftoló csapatok -> ezek a csapatok jellemzően gyengébbek, azért kapnak jobb draft helyeket
by drafted_team(), sort: egen mean_drafted_pick = mean(drafted_pick)
egen tag2 = tag(mean_drafted_pick) 

asdoc list drafted_team mean_drafted_pick if tag2==1
asdoc summarize mean_drafted_pick if tag2==1

*nfl csapatok draftolt játékosainak sikeressége
by drafted_team (), sort: egen mean_av_team = mean(av)
egen tag3 = tag(mean_av_team) 


*későbbi eredményességet évente külön kell kezelni?
graph bar av, over(year) ytitle("átlagos teljesítmény") title("Átlagos teljesítmény évenkénti bontásban")


*későbbi eredményesség és a draft pozíció összefüggése 2014-ben -> 0.506, van összefüggés, de nem olyan erős. NFL scoutok nem tökéletesek, hátsóbb körös játékos is lehet sikeres
asdoc correlate av drafted_pick if year == 2014
graph twoway (lfit av drafted_pick) (scatter av drafted_pick) if year == 2014, legend(order(1 "illesztett érték" 2 "játékosok")) ytitle("játékosok eredményessége") xtitle("játékosok draft pozíciója")
asdoc reg av drafted_pick if year == 2014
* rosszabb helyen draftolt csapatok és a játékos sikeressége --> általánosságban nem a csapat teszi jobbá a játékost, hanem a jobb helyen draftolt játékosok lesznek sikeresebbek
asdoc correlate mean_av_team mean_drafted_pick
graph twoway (lfit mean_av_team mean_drafted_pick) (scatter mean_av_team mean_drafted_pick, mlabel(drafted_team) mlabsize(tiny)),legend(order(1 "illesztett érték" 2 "csapatok")) ytitle("draftolt játékosok átlagos eredményessége") xtitle("átlagos draft pozíció")

*-----combine elemzése-----------
*pozíciók különbsége
*BMI yd

graph twoway (lfit yd BMI) (scatter yd BMI), legend(order(1 "illesztett érték" 2 "játékosok")) ytitle("40 yard-os sprint")

*futók és centerek között
twoway (scatter BMI yd if pos == 17) (scatter BMI yd if pos == 1), legend(order(1 "futók" 2 "centerek")) xtitle("40 yard (s)")

*atlétikai mutatók és hatásuk egymásra -> korrelálnak egymással, azonban a jövőbeli eredményesség már csak alig korrelál az atlétikai képességgel
asdoc correlate BMI yd vertical benchreps broadjump cone shuttle
asdoc correlate av BMI yd vertical benchreps broadjump cone shuttle if year== 2014



*-----------atlétikai mutatók, csak a teljesen kitöltött sorok maradnak------------------------------------

*mivel elég sok változóm van, ezért csak azokat a sorokat hagyom meg, ahol minden adat rendelkezésre áll
keep if ures < 1

* normalitás vizsgálat
asdoc sktest yd BMI age vertical benchreps broadjump cone shuttle

*befolyásolja a kor, hogy ki mennyire ér el jó eredményt?
graph bar BMI, over(age) ytitle("átlagos BMI") title("Átlagos BMI érték korcsoportonként")

graph bar drafted_pick, over(age) ytitle("átlagos draft pozíció") title("Átlagos draft pozíció korcsoportonként")


*BMI, mint atlétkussági mutató
foreach ismerv in yd vertical benchreps broadjump cone shuttle{
	asdoc regress `ismerv' BMI
	display "R2 = " e(r2)
}

*BMI mutatót mennyire irják le az atlétikai mutatók -> 84%-ban, aki kisebb az atlétikusabb

asdoc regress BMI vertical yd benchreps broadjump cone shuttle

asdoc regress BMI yd benchreps broadjump cone shuttle

*ez már jó
asdoc regress BMI  yd benchreps broadjump cone 


*mennyire különbözőek az egyes pozíciókban a játékosok (pozíciók belső szórása), mennyire térnek el egymástól a pozíciók (külső szórás)
*átlagok kiszámolása
foreach col in BMI vertical yd benchreps broadjump cone shuttle{
	by pos (), sort: egen mean_`col' = mean(`col')
	replace `col' = mean_`col'  if `col' == .
}

asdoc summarize mean_BMI mean_vertical mean_yd mean_benchreps mean_broadjump mean_cone mean_shuttle
scatter mean_BMI mean_vertical mean_yd mean_benchreps mean_broadjump mean_cone mean_shuttle pos
*látszik, hogy a pozíciók egymástól eltérnek, pozícionként más mutatók a fontosak, ezért külön-külön érdemes őket nézni a draft során.


*combine atlétikai teljesítmény mennyire indikálja a későbbi jó teljesítményt
*melyik atlétikai mutatók számítanak a draft helyekben
asdoc regress drafted_pick age weight height vertical yd benchreps broadjump cone shuttle

regress drafted_pick age weight vertical yd benchreps broadjump cone shuttle

asdoc regress drafted_pick age weight vertical yd benchreps cone shuttle

regress drafted_pick age weight vertical yd cone shuttle

regress drafted_pick age weight yd cone shuttle

regress drafted_pick age weight yd cone

*elkapók esetén
asdoc correlate drafted_pick age weight height vertical yd benchreps broadjump cone shuttle if pos == 20

*draft
asdoc regress drafted_pick age weight height vertical yd benchreps broadjump cone shuttle if pos == 20

regress drafted_pick age weight height vertical yd broadjump cone shuttle if pos == 20

regress drafted_pick age weight height vertical yd cone shuttle if pos == 20

regress drafted_pick age weight height yd cone shuttle if pos == 20

regress drafted_pick age weight height yd cone if pos == 20
*ez már jó
asdoc regress drafted_pick age weight height yd if pos == 20

regress drafted_pick age weight yd if pos == 20

regress drafted_pick age yd if pos == 20

*ol esetén
asdoc correlate drafted_pick age weight height vertical yd benchreps broadjump cone shuttle if pos == 13

*draft
asdoc regress drafted_pick age weight height vertical yd benchreps broadjump cone shuttle if pos == 13

regress drafted_pick age weight vertical yd benchreps broadjump cone shuttle if pos == 13

regress drafted_pick age weight vertical yd broadjump cone shuttle if pos == 13

regress drafted_pick age weight vertical yd broadjump shuttle if pos == 13
*ez már jó
asdoc regress drafted_pick age weight vertical yd shuttle if pos == 13

regress drafted_pick age weight yd shuttle if pos == 13


