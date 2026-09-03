#let format_strane = "a4"         // могуће вредности: iso-b5, a4
#let naslov = "Имплементација игре Commander's Defense применом клијент-сервер архитектуре"
#let autor = "Невен Илинчић"

// На енглеском
#let naslov_eng = "Implementation of the game Commander's Defense using client-server architecture"
#let autor_eng = "Neven Ilinčić"

#let indeks = "SV47/2022"

// Име и презиме ментора
#let mentor = "Игор Дејановић"
// Звање: редовни професор, ванредни професор, доцент
#let mentor_zvanje = "редовни професор"

// Скинути коментаре са одговарајућих линија
#let studijski_program = "Софтверско инжењерство и информационе технологије"
//#let studijski_program = "Рачунарство и аутоматика"
// #let stepen = "Мастер академске студије"
#let stepen = "Основне академске студије"

#let godina = [#datetime.today().year()]

#let kljucne_reci = "Шаблон, завршни рад, упутство"
#let apstrakt = [
     Овај документ представља упутство за писање завршних радова на Факултету
     техничких наука Универзитета у Новом Саду. У исто време је и шаблон за Typst.
]

// На енглеском
#let kljucne_reci_eng = "Template, thesis, tutorial"
#let apstrakt_eng = [
     This document provides guidelines for writing final theses at the Faculty
     of Technical Sciences, University of Novi Sad. At the same time, it serves
     as a Typst template.
]

// TODO: Текст задатка добијате од ментора. Заменити доле #lorem(100) са текстом задатка.
#let zadatak = [

Циљ овог завршног рада је пројектовање и имплементација 2D _online multiplayer_
игре _Commander's Defense_ засноване на клијент-сервер архитектури са
ауторитативним сервером. Клијентску страну потребно је развити коришћењем погона
_Godot Game Engine_, док серверску логику високих перформанси треба реализовати
у програмском језику _Rust_, уз коришћење _PostgreSQL_ базе података.

Неопходно је имплементирати кључне механизме мрежне синхронизације у реалном
времену, укључујући клијентску предикцију, серверско усклађивање (_server
reconciliation_) и _tick-rate_ регулацију. Посебну пажњу посветити оптимизацији
мрежног саобраћаја путем бинарне серијализације података, као и употреби
комбинације UDP, WebSocket и HTTP протокола за различите типове комуникације.
Функционалност система потребно је верификовати кроз реализацију различитих
режима игре (_FFA_ и кула режим) и примену пројектантских шаблона _Command_ и
_State_.

При изради користити препоручену праксу из области софтверског инжењерства.
Детаљно документовати решење.

]

// TODO: Датум одбране и чланове комисије добијате од ментора
#let datum_odbrane = "10.09.2026"
#let komisija_predsednik = "Гордана Милосављевић"
#let komisija_predsednik_zvanje = "редовни професор"
#let komisija_clan = "Никола Лубурић"
#let komisija_clan_zvanje = "ванредни професор"

// На енглеском уписати чланове на латиници
#let komisija_predsednik_eng = "Gordana Milosavljević"
#let komisija_clan_eng = "Nikola Luburić"
#let mentor_eng = "Igor Dejanović"


// Ово даље углавном не треба мењати.

#let zvanje_eng = (
     "редовни професор": "full professor",
     "ванредни професор": "assoc. professor",
     "доцент": "asist. professor",
)
#let komisija_predsednik_zvanje_eng = zvanje_eng.at(komisija_predsednik_zvanje)
#let komisija_clan_zvanje_eng = zvanje_eng.at(komisija_clan_zvanje)
#let mentor_zvanje_eng = zvanje_eng.at(mentor_zvanje)


#let vrsta_rada = if stepen == "Мастер академске студије" {
    "Дипломски - мастер рад"
} else {
    "Дипломски - бечелор рад"
}

#let oblast = "Електротехничко и рачунарско инжењерство"
#let oblast_eng = "Electrical and Computer Engineering"
#let disciplina = "Примењене рачунарске науке и информатика"
#let disciplina_eng = "Applied computer science and informatics"

#import "funkcije.typ": *
// Поглавља/страна/цитата/табела/слика/графика/прилога
#let fizicki_opis = physical()
