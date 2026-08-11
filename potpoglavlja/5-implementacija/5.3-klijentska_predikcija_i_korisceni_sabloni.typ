#import "@preview/codegds:0.1.0": gdscript-syntax
#set raw(syntaxes: gdscript-syntax)
== Имплементација кретања играча - _Command_ и _State_ шаблон <implementacija_kretanja>

Како би серверско усклађивање имало смисла и клијентска предикција била могућа, неопходно је да клијент и сервер рачунају кретање на исти начин. _Godot Game Engine_ има уграђену методу *move_and_slide()* која рачуна кретање помоћу његове интерне физике, а _Rapier_ библиотека у _Rust_-у помоћу своје. Стога, било је потребно ручно написати логику кретања играча, како на клијенту, тако и на серверу. Олакшана околност је што и _Godot Game Engine_ и _Rapier_ библиотека пружају могућност аутоматског рачунања колизија објеката на основу прослеђених података, чиме није било потребе за додатном имплементацијом рачунања.

=== Имплементација на клијентској страни
==== Command шаблон
За потребе игрице, *_Command_* шаблон је искоришћен за енкапсулацију акције кретања (да ли је играч у посматраном фрејму притиснуо тастер за кретање лево, десно или скок), приказано у листингу @lst:implementacija_PlayerMoveCommand_klase.
#figure(
  ```gdscript
    extends Node
    class_name PlayerMoveCommand

    var player: MyPlayer
    var move_left: bool
    var move_right: bool
    var jump: bool
    var input_id: int

    func _init(player: MyPlayer, input_id: int) -> void:
      self.player = player
      self.move_left = false
      self.move_right = false
      self.jump = false
      self.input_id = input_id

    func execute(delta: float):
      self.player.player_state.update(delta, self.player, self)
      

  ```,
  caption: [Имплементација _Command_ класе.],
) <lst:implementacija_PlayerMoveCommand_klase>
\

Једина метода коју *PlayerMoveCommand* класа садржи је _execute()_ која се позива у раније наведеној _apply_movement_step_ методи, у секцији @izvrsavanje_i_cuvanje_akcija.