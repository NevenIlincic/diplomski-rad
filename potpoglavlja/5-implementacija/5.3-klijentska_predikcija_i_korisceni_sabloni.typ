#import "@preview/codegds:0.1.0": gdscript-syntax
#set raw(syntaxes: gdscript-syntax)
== Имплементација кретања играча - _Command_ и _State_ шаблон <implementacija_kretanja>

Како би серверско усклађивање имало смисла и клијентска предикција била могућа, неопходно је да клијент и сервер рачунају кретање на исти начин. _Godot Game Engine_ има уграђену методу *move_and_slide()* која рачуна кретање помоћу његове интерне физике, а _Rapier_ библиотека у _Rust_-у помоћу своје. Стога, било је потребно ручно написати логику кретања играча, како на клијенту, тако и на серверу. Олакшана околност је што и _Godot Game Engine_ и _Rapier_ библиотека пружају могућност аутоматског рачунања колизија објеката на основу прослеђених података, чиме није било потребе за додатном имплементацијом рачунања.

=== Имплементација на клијентској страни
==== _Command_ шаблон
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

Једина метода коју *_PlayerMoveCommand_* класа садржи је _execute()_ која се позива у раније наведеној _apply_movement_step_ методи, у секцији @izvrsavanje_i_cuvanje_akcija. Једина улога ове методе је да позове _update()_ методу која се налази у *_PlayerState_* класи преко референце на играча. 

==== _State_ шаблон
У зависности од извршених акција и стања игре, играч у посматраном тренутку може да пуца, трчи, скаче или чека да оживи након што је био елиминисан.
Како би се избегле сталне *_if_* провере у _physics_process_() методи која се окида сваког фрејма, што, ако их има пуно, може да доведе до пада у перформансама, имплементиран је *_State_* шаблон представљен *_PlayerState_* апстрактном класом (листинг @lst:implementacija_PlayerState_klase). _Enter()_ и _update()_ методе морају бити редефинисане у конкретним имплементацијама класа, док су _apply_common_physics()_ и _handle_inputs()_ заједничке методе за сва стања. Постојеће класе стања су: *_IdleState_*, *_RunningState_*, *_JumpingState_* и *_DeadState_*, а њихове имплементације _enter()_ методе су приказане у листинзима @lst:IdleState_enter_metoda, @lst:RunningState_enter_metoda, @lst:JumpingState_enter_metoda и @lst:DeadState_enter_metoda. Играч садржи референцу на стање, а када је потребно да играч пређе у ново стање, потребно је позвати методу _change_player_state()_ (листинг @lst:change_state_metoda).
\
Употреба *_State_* шаблона омогућава организованији код, боље перформансе и лакше дебагобање, јер је потребно фокусирати се само на оно стање које је изазвало проблем. Листинг @lst:change_state_metoda_pseudokod приказује псеудокод _execute()_ методе из листинга @lst:implementacija_PlayerMoveCommand_klase без имплементације шаблона.

#figure(
  ```gdscript
    @abstract class_name PlayerState
    extends Node

    @abstract
    func enter(player: MyPlayer);

    @abstract
    func update(delta: float, player: MyPlayer, command: PlayerMoveCommand);

    func apply_common_physics(delta: float, player: MyPlayer, command: PlayerMoveCommand):
      	var direction = 0
        if not player.is_dead:
          if command.move_left:  direction -= 1
          if command.move_right: direction += 1

          if direction > 0 and not player.can_move_right:  direction = 0
          elif direction < 0 and not player.can_move_left: direction = 0
        else:
          direction = 0
        var motion_x = direction * player.SERVER_SPEED * player.METER_TO_PIXEL
        player.move_and_collide(Vector2(motion_x * delta, 0))
        
        var predicted_v_velocity = player.vertical_velocity + player.GRAVITY * delta
        if predicted_v_velocity > 12.0:
          predicted_v_velocity = 12.0

        var motion_y = predicted_v_velocity * delta * player.METER_TO_PIXEL
        var collision = player.move_and_collide(Vector2(0, motion_y))
        
        player.is_on_ground = false

        if collision:
          var normal = collision.get_normal()
          if normal.y < -0.5:
            player.is_on_ground = true
            player.vertical_velocity = 0.0
          elif normal.y > 0.5:
            player.vertical_velocity = 0.0
        else:
          player.vertical_velocity = predicted_v_velocity

        return direction
      
    func handle_inputs(player: MyPlayer):
      if Network.INPUT_DATA["gun"] == "m4a1_rifle":
        Network.INPUT_DATA["shoot"] = Input.is_action_pressed("shoot")
      else:
        Network.INPUT_DATA["shoot"] = Input.is_action_just_pressed("shoot")
      #ОСТАТАК МЕТОДЕ
  ```,
  caption: [Базна *_PlayerState_* класа],
) <lst:implementacija_PlayerState_klase>
\

#figure(
  ```gdscript
    class_name IdleState extends PlayerState

    func enter(player: MyPlayer):
      player.vertical_velocity = 0
      player.is_on_ground = true
      player.walking_sprite.visible = false
      player.idle_sprite.visible = true
      player.dying_sprite.visible = false
      player.animation_player.play("idle_animation")

  ```,
  caption: [Имплементација _enter()_ методе *_IdleState_* класе],
) <lst:IdleState_enter_metoda>
\

#figure(
  ```gdscript
    class_name RunningState extends PlayerState

    func enter(player: MyPlayer):
      player.walking_sprite.visible = true
      player.idle_sprite.visible = false
      player.dying_sprite.visible = false
      player.animation_player.play("walking_animation")

  ```,
  caption: [Имплементација _enter()_ методе *_RunningState_* класе],
) <lst:RunningState_enter_metoda>
\

#figure(
  ```gdscript
    class_name JumpingState extends PlayerState

    func enter(player: MyPlayer):
      player.is_on_ground = false	
      player.walking_sprite.visible = true
      player.idle_sprite.visible = false
      player.dying_sprite.visible = false
      player.animation_player.play("walking_animation")
  ```,
  caption: [Имплементација _enter()_ методе *_JumpingState_* класе],
) <lst:JumpingState_enter_metoda>
\

#figure(
  ```gdscript
   class_name DeadState extends PlayerState

    func enter(player: MyPlayer):
      player.is_on_ground = true
      player.walking_sprite.visible = false
      player.idle_sprite.visible = false
      player.dying_sprite.visible = true
      player.health_amount.visible = false
      
      player.is_dead = true
      player.can_move_left = false
      player.can_move_right = false
      player.animation_player.play("dying_animation")
  ```,
  caption: [Имплементација _enter()_ методе *_DeadState_* класе],
) <lst:DeadState_enter_metoda>
\


#figure(
  ```gdscript
    func change_state(state: PlayerState):
      if self.player_state:
        self.player_state.queue_free()
      self.player_state = state
      self.player_state.enter(self)
  ```,
  caption: [Имплементација _change_state()_ методе *_MyPlayer_* класе],
) <lst:change_state_metoda>
\

#figure(
  ```gdscript
    #Пуно if провера сваки фрејм 
    func execute(delta: float):
    if играч_HP <= 0.0:
      return
    if играч_није_на_земљи:
      код за логику скакања...
    else:
      if играч_се_креће:
        код за логику кретања...
      else:
        код за логику стајања...

  ```,
  caption: [Имплементација _execute()_ методе *_PlayerMoveCommand_* класе без имплементације *_State_* шаблона.],
) <lst:change_state_metoda_pseudokod>
\
