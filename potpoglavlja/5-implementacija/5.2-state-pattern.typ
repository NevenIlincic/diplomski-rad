#import "@preview/codegds:0.1.0": gdscript-syntax
#set raw(syntaxes: gdscript-syntax)

== Синхронизација стања
=== Извршавање и чување акција
Приказани код у Листингу @lst:player_physics_process_funkcija демонстрира интеграцију клијентске предикције. Кључни део ове имплементације је ажурирање локалне позиције играча (*_apply_movement_step_* функција) и чување у структуру *state_history*. Тиме се обезбеђује референца за будући _rollback_ процес.\
У Листингу @lst:send_data_funckija приказана је *_send_data_* функција која се бави серијализацијом података о уносу. Бафер *_inputs_list_* памти историју акција које су извршене, а које још увек нису потврђене од стране сервера.

#figure(
  ```gdscript
    func _physics_process(delta: float) -> void:
      var move_command: PlayerMoveCommand = handle_move_inputs(Network.INPUT_DATA["input_id"], delta) #Енкапсулација корисничког уноса
      apply_movement_step(move_command, PHYSICS_DELTA) #Извршавање акције

      if not self.message_input.visible and not self.pause_menu.visible:
        Network.INPUT_DATA["input_id"] += 1
        self.player_state.handle_inputs(self)
        #Чување позиције играча у тренутку слања команде
        state_history.append(
          {
            "id": Network.INPUT_DATA["input_id"],
            "global_position": global_position
          }
        )
          send_data(move_command) #Слање команде ка серверу
  ```,
  caption: [Имплементација позива],
) <lst:player_physics_process_funkcija>
\
#figure(
  ```gdscript
     func send_data(move_command: PlayerMoveCommand):
   	    if !Network.is_disconnecting:
          var packed_byte_array: PackedByteArray = Network.convert_input_data_to_byte_array()
          Network.send_data(packed_byte_array)
          inputs_list.append(move_command)
          if inputs_list.size() > 30:
            inputs_list = inputs_list.slice(-30)
  ```,
  caption: [Слање података ка серверу и чување команди у бафер.],
) <lst:send_data_funckija>

=== Детекција десинхронизације и усклађивање
Процес усклађивања започиње обрадом примљеног пакета и изменом података о тренутном оружју играча као што су муниција, репетирање оружја (Листинг @lst:handle_server_response_funckija_1), након чега се бришу застареле команде из бафера (Листинг @lst:handle_server_response_funckija_2). Коначно, на основу разлике између предвиђене и ауторитативне позиције се примењује механизам корекције који је приказан на Листингу @lst:handle_server_response_funckija_3. Ако је разлика у позицији велика, клијент додатно понавља све акције које су извршене у периоду између два пакета (овај поступак омогућава да клијент не изгуби уносе док је чекао одговор сервера).

#figure(
  ```gdscript
  func handle_server_response(player_snapshot: Dictionary):
    target_position = Vector2(player_snapshot["position"][0] * METER_TO_PIXEL, player_snapshot["position"][1] * METER_TO_PIXEL) #Позиција играча одређена сервером.
    var last_processed_id = player_snapshot["last_processed_input_id"] #Последњи унос који је сервер обрадио.

    if not throwable_map.has(player_snapshot["gun"]):
      weapons[weapon_index].update_from_server(player_snapshot)
      if weapons_names_list[weapon_index] != player_snapshot["gun"]:
        weapons[weapon_index].reload_sound.stop()
    else:
      throwables[throwable_map[player_snapshot["gun"]]].set_snapshot(player_snapshot)
  ```,
  caption: [Очитавање позиције са сервера и ажурирање оружја.],
) <lst:handle_server_response_funckija_1>

\
#figure(
  ```gdscript
  while len(inputs_list) > 0 and inputs_list[0].input_id <= last_processed_id:
  	inputs_list.remove_at(0)
  ```,
  caption: [Брисање застарелих команди из бафера.],
) <lst:handle_server_response_funckija_2>

#figure(
  ```gdscript
  var checking_state = null
  var match_index: int = -1
  for i in range(len(state_history)):
    if state_history[i]["id"] == last_processed_id:
      checking_state = state_history[i]
      match_index = i
      break
	
	if checking_state != null:
		var error_vec = target_position - checking_state["global_position"]
	
		var distance = error_vec.length()
		#TESKA KOREKCIJA
		if distance > 100.0:
			global_position = target_position
			for input_item in inputs_list:
				apply_movement_correction(input_item, PHYSICS_DELTA)
		
		#LAGANA KOREKCIJA
		else:
			var old_pos = global_position
			global_position = target_position			
			var new_predicted_pos = global_position
			var offset = old_pos - new_predicted_pos
			visuals.global_position += offset 
  ```,
  caption: [Кориговање позиције клијента.],
) <lst:handle_server_response_funckija_3>
