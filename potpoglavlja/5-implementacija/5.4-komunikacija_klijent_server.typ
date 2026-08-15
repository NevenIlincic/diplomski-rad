#import "@preview/codegds:0.1.0": gdscript-syntax
#set raw(syntaxes: gdscript-syntax)
== Комуникација клијента и сервера
=== Протоколи
Комуникација између клијента и сервера је подељена на три различита протокола:
- *UDP протокол*: Користи се искључиво док траје игра стартованог _lobby_-ја. Како играчи константо шаљу своје акције ка серверу и није дозвољено чекање потврде сервера да ли је пакет успешно примљен, што би изазвало латенцију, користи се UDP протокол. Такође, након што израчуна ново стање игре, сервер шаље путем истог протокола пакете ка свим повезаним клијентима у партији. Ако неки пакет не стигне, серверским усклађивањем следећег добијеног пакета ће играч бити позициониран на неопходну позицију. 
- *WebSocket*: Конекција се успоставља оног тренутка, када играч приступи жељеном _lobby_-ју. Користи се за акције које се често извршавају, а неопходно је да клијент и сервер добију одговор. У акције спадају: 
    - мењање мапe, 
    - мењање неопходног броја елиминације за победу (ако је FFA режим) или HP куле, 
    - мењање изгледа играча, 
    - четовање и 
    - обавештавање када је играч елиминасан. 
    Када играч изађе из партије или _lobby_-ја, конекција се прекида. 
- *HTTP протокол (REST API)*: Користи се за акције ван саме партије које се извршавају повремено, а за које је потребно потврда извршења, као што су: 
    - пријава,
    - одјава,
    - регистрација,
    - креирање, улазак и излазак из _lobby_-ја и 
    - добијање информација о приступљеном _lobby_-ју.

На листингу @lst:enumi_komunikacija_klijent_server се могу видети сви енуми који се користе за размену података између клијента и сервера. *_ServerMessage_* представља одговор сервера ка клијенту, док је *_ClientMessage_* структура коју клијент шаље серверу.

#figure(
  ```rust
  
#[derive(Serialize, Deserialize)]
pub enum ServerMessage {
    Init(u32),                       //0
    Snapshot(GameState),             //1
    Pong(u64),                       //2
    GameEnd(GameEnd),                //3
    LobbiesList(LobbiesInfo),        //4
    CreatedLobbyResponse(u32, u32),  //5
    GameStarted(bool),               //6
    LobbyInfo(LobbyRoomInfo),        //7
    PlayerDisconnected(u32, u32),    //8 player_id lobby_host_id
    PlayerChangedSkin(u32, u8),      //9 player_id, player_skin_index(0-GREEN,1-BLUE,2...)
    PlayerChangedReadyState(u32),    //10 player_id
    TowerMaxHPChanged(u32),          //11 tower_max_hp
    PlayerMessage(u32, String),      //12 player_id, message
    PlayerConnected(u32, String),    //13 player_id, player_nickname
    PlayerKilled(u32, u32, GunEnum), //14 killer_id, victim_id, gun_index (0-pistol, 1-m4a1)
    KillsToWinChanged(u8),                      //15 kill_amount
    AuthenticationResponse(u32, String, String), //16 player_id, nickname, token
    MapChanged(u8),                              //17 map_index
    StartedLobbyJoinResponse(u8),                //18 map_index
    TowerCreated(TowerSnapshot) //19
}

#[derive(Deserialize, Debug)]
pub enum ClientMessage {
    Input(ClientInput),               // 0
    PingCheck(PingInput),             // 1
    LobbyCreate(CreateLobbyRequest),  //2
    LobbyJoin(JoinRequest),           //3,
    LobbyStart(u32),                  //4 lobby_id
    PlayerReady(u32),                 //5   lobby_id
    GetLobbyInfo(u32),                //6 lobby_id
    ChangeTowerMaxHP(u32, u32),       //7 lobby_id, tower_max_hp
    ChangePlayerBodySkin(u32, u8),    //8 lobby_id, skin_index (0-GREEN,1-BLUE,2-RED)
    LobbyLeave(u32),                  //9 lobby_id
    PlayerMessage(u32, String),       //10 lobby_id, message
    ChangeKillsToWin(u32, u8),       //11 lobby_id, kill_amount
    JoinStartedLobby(u32),            //12 lobby_id
    RegistrationData(String, String), //13 nickname, password
    LoginData(String, String, u8),        //14 nickname, password, //project version
    ChangeMap(u8),                    //15, map_index
}
  ```,
  caption: [Приказ енума који се користе за размену података између клијента и сервера.],
) <lst:enumi_komunikacija_klijent_server>
\

=== JWT
JWT представља додатан слој заштите и аутентификације како би сервер могао безбедно да идентификује корисника без потребе да чува податке о сесији у својој меморији или да за сваки захтев проверава базу података.\
Приликом пријаве, сервер генерише токен приказаном у листингу @lst:implementacija_jwt_handler_metode_server и смешта га као параметар *_AuthenticationReponse_* варијанте *_ServerMessage_* енума, а клијент потом чува токен. Клијент складишти токен у променљивој, шаље га у _Authorization_ заглављу у сваком наредном захтеву ка серверу и брише га када се одјави.

#figure(
  ```rust
    static JWT_SECRET: Lazy<Vec<u8>> = Lazy::new(|| {
        std::env::var("JWT_SECRET")
            .expect("JWT_SECRET nije postavljen!")
            .into_bytes()
    });

    pub struct JWTHandler;

    impl JWTHandler {
        pub fn create_jwt(player_id: u32, player_nickname: String) -> String {
            let now = Utc::now();
            let expire = now + Duration::hours(24);
    
            let claims = Claims {
                id: player_id,
                nickname: player_nickname,
                iat: now.timestamp() as usize,
                exp: expire.timestamp() as usize,
            };

            encode(
                &Header::default(),
                &claims,
                &EncodingKey::from_secret(&JWT_SECRET),
            )
            .unwrap()
        }

        pub fn validate_jwt(token: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
            decode::<Claims>(
                token,
                &DecodingKey::from_secret(&JWT_SECRET),
                &Validation::new(Algorithm::HS256),
            )
            .map(|data| data.claims)
        }
    }

  ```,
  caption: [Имплементација _create_jwt()_ и _validate_jwt()_ метода],
) <lst:implementacija_jwt_handler_metode_server>
\
\
\
\
\
\
\
\
\
\
\
\
\

=== _Network_ и _MyHttpHandler_ синглтони (клијент)
// *_Network_* синглтон је задужен за успостављање конекције са сервером, док је *_MyHttpHandler_* задужен за слање захтева ка серверу путем _web-socket_-а или _REST API_-ја.

Синглтон _Network_ (приказан на листингу @lst:deo_Network_singltona) је искључиво задужен за успостављање, одржавање и управљање мрежним конекцијама које захтевају брз проток података, првенствено путем UDP протокола и _WebSocket_-а.

UDP комуникација (_PacketPeerUDP_): Како је приказано у методи connect_to_socket(), клијент врши резолуцију хоста преко _IP.resolve_hostname()_ како би динамички претворио доменско име или локалну адресу у валидну IP адресу. Коришћењем класе *_PacketPeerUDP_* омогућено је слање сирових бајтова (_PackedByteArray_) уз минимално кашњење, што је критично за игре са брзом синхронизацијом позиција играча и стања физичке симулације. Метода _send_data()_ врши безбедну проверу активне конекције пре саме серијализације и слања пакета ка серверу на дефинисаном порту (у овом случају 9000).

_WebSocket_ комуникација: Поред UDP-а, синглтон интегрише и *_WebSocketPeer_* механизам (дефинисан кроз променљиве попут: _websocket_, _is_connected_to_websocket_ и праћење губитка везе _is_conenction_with_websocket_lost_). Ово омогућава поуздан, двосмерни комуникацијски канал преко TCP-а за догађаје који захтевају гарантовану испоруку порука, а који нису временски критични као сама физичка симулација.

Са друге стране, *_MyHttpHandler_* синглтон (приказан на листингу @lst:deo_MyHttpHandler_singltona) се ослања на  REST API комуникацију. Архитектура овог синглтона се заснива на асинхроном моделу захтев-одговор (_Request-Response_), где свака акциона метода има свој пратећи повратни позив (_callback_ методу) која се окида по завршетку HTTP захтева (_register()_ - _on_register_completed_(), _login()_ - _on_login_completed()_). Такође, иако је *_Network_* задужен за успостављање конекције, *_MyHttpHandler_* синглтон је задужен и за слање података ка серверу путем _WebSocket_-а.

Аутентификација и регистрација: Методе _register()_ и _login()_ омогућавају слање креденцијала корисника ка серверу, док одговарајуће функције _on_register_completed()_ и _on_login_completed()_ прихватају повратне параметре (_result_, _response_code_, _headers_, _body_, _http_node_) и обрађују статус код сервера (нпр. издавање и чување JWT токена).

Управљање _lobby_-јима: Методе попут _get_all_lobies()_ и _create_lobby_binary()_ омогућавају преглед доступних соба и креирање нових партија са специфичним параметрима (максималан број играча, шифра _lobby_-ја, број режима игре).
#figure(
  ```gdscript
        extends Node2D
        var is_local: bool = false
        const VERSION: int = 1
        ###CONNECTION
        var socket := PacketPeerUDP.new()
        var server_address = null
        var server_port := 9000
        var is_connected_to_udp_socket: bool = false
        var websocket := WebSocketPeer.new()
        var websocket_address = null
        var is_connected_to_websocket: bool = false
        var is_conenction_with_websocket_lost: bool = false
        ...остатак променљивих

        #Метода за отварање UDP сокета
        func connect_to_socket(): 
            var ip = IP.resolve_hostname(server_address)
            if ip == "" or not ip.is_valid_ip_address():
                return

            var err = socket.set_dest_address(ip, server_port)
            if err != OK:
                return
                
            is_connected_to_udp_socket = true
        #Метода за слање података серверу
        func send_data(data: PackedByteArray):
            if is_connected_to_udp_socket:
                socket.put_packet(data)

        ...остале методе
  ```,
  caption: [Део *_Network_* синглтона],
) <lst:deo_Network_singltona>
\

#figure(
  ```gdscript
        extends Node
        func register(nickname: String, password: String)
        func _on_register_completed(result, response_code, headers, body, http_node)
        func login(nickname: String, password: String) 
        func _on_login_completed(result, response_code, headers, body, http_node)
        func get_all_lobies()
        func _on_get_all_lobbies_completed(result, response_code, headers, body, http_node)
        func create_lobby_binary(max_players: int, password: String, game_mode_number:int = 0) 
        func _on_create_completed(result, response_code, headers, body, http_node)
        ...остале методе
  ```,
  caption: [Део *_MyHttpHandler_* синглтона],
) <lst:deo_MyHttpHandler_singltona>
\
\
\
\
\
\
\
\
=== Оптимизација величине пакета
У циљу смањења мрежног оптерећења (_network overhead_) и кашњења, комуникација између клијента и сервера у овој апликацији је реализована коришћењем бинарне серијализације података уместо текстуалних формата као што је JSON. Иако је JSON читљив и једноставан за имплементацију, он је за потребе мрежмне синхронизације у реалном времену неефикасан из следећих разлога:
- У JSON-у, сваки податак је идентификован кључем. На пример, запис {"position_x": 140.0} троши бајтове и на назив кључа који се понавља у сваком пакету. Бинарни запис преноси само вредности, што драстично смањује величину пакета.
- Додатно, одређено време се троши на десеријализацију самог формата, што код бинарне серијализације није случај.

Листинг @lst:convert_input_data_to_byte_array_metoda приказује методу _convert_input_data_to_byte_array()_ *_Network_* синглтона, која је задужена за припрему података за слање ка серверу. *_INPUT_DATA_* представља речник у којем се налазе неопходни подаци које клијент шаље ка серверу како би сервер могао успешно да изврши симулацију.

Поређења ради, употребом JSON формата, сваког фрејма клијент шаље пакете величине око 180 бајтова, док се употребом бинарне серијализације величина пакета смањује на 37 бајтова:
- _message_type_ (u32): 4 бајта,
- _my_id_ (u32): 4 бајта,
- _input_id_ (u32): 4 бајта,
- boolean поља (u8 по пољу): 4 бајта,
- _mouse_angle_ (float / 32-bit): 4 бајта,
- _cmd_id_ (u32): 4 бајта,
- _gun_id_ (u32): 4 бајта,
- провера за позицију метка (u8 за 0 или 1): 1 бајт,
- _bullet_spawn_position_ (2 пута по 4 бајта за float): 8 бајтова

Како би се додатно уштедело на величини пакета, у неким ситуацијама је искоришћено и битовско померање. Уместо да се подаци о томе да ли је играч на земљи, да ли репетира оружје или гледа надесно прослеђују као три засебна бајта, шаље се 1 бајт. Коришћењем битовског "и" са одређеном маском и поређењем добијене вредности са нула, добијају се _boolean_ вредности. Листинг @lst:create_player_snapshot_metoda_klijent приказује читање бинарног формата пакета добијеног од сервера.

Важно је напоменути да је редослед којим се подаци читају и пакују битан. Нарушавање редоследа само једног поља може довести до десинхронизације и погрешног тумачења података.
#figure(
  ```gdscript
    INPUT_DATA = {
		"player_id": my_id,
		"input_id": 0,
		"move_left": false,
		"move_right": false,
		"jump": false,
		"shoot": false,
		"mouse_angle": 0.0,
		"command": "JOIN",
		"gun": "pistol",
		"bullet_spawn_position": null
	}


     func convert_input_data_to_byte_array():
	var buffer = StreamPeerBuffer.new()
	
	buffer.put_u32(0) # ClientMessage::Input
	buffer.put_u32(my_id)
	buffer.put_u32(INPUT_DATA["input_id"])
	
	buffer.put_u8(1 if INPUT_DATA["move_left"] else 0)
	buffer.put_u8(1 if INPUT_DATA["move_right"] else 0)
	buffer.put_u8(1 if INPUT_DATA["jump"] else 0)
	buffer.put_u8(1 if INPUT_DATA["shoot"] else 0)
	
	buffer.put_float(INPUT_DATA["mouse_angle"])
	
	var cmd_id = Command.get(INPUT_DATA["command"], 0)
	buffer.put_u32(cmd_id) 

	var gun_id = Gun.get(INPUT_DATA["gun"].to_upper(), 0)
	buffer.put_u32(gun_id)

	if INPUT_DATA["bullet_spawn_position"] == null:
		buffer.put_u8(0)
	else:
		buffer.put_u8(1)
		buffer.put_float(INPUT_DATA["bullet_spawn_position"][0])
		buffer.put_float(INPUT_DATA["bullet_spawn_position"][1])
			
	return buffer.data_array
  ```,
  caption: [Припрема података за слање корисничких акција ка серверу.],
) <lst:convert_input_data_to_byte_array_metoda>

#figure(
  ```gdscript
    func create_players_snapshot(buffer: StreamPeerBuffer):
        var snapshot: Dictionary = {}
        
        snapshot["id"] = buffer.get_u32()
        
        var name_length = buffer.get_u64() 
        snapshot["nickname"] = buffer.get_utf8_string(name_length)
        
        var pos_x = buffer.get_float()
        var pos_y = buffer.get_float()
        snapshot["position"] = Vector2(pos_x, pos_y)
        
        snapshot["hp"] = buffer.get_32()
        
        #const FLAG_FACING_RIGHT = 1 (00000001)
        #const FLAG_IS_ON_GROUND = 2 (00000010)
        #const FLAG_IS_RELOADING = 4 (00000100)
        var flags_byte: int = buffer.get_u8()
        var facing_right = (flags_byte & FLAG_FACING_RIGHT) != 0
        var is_on_ground = (flags_byte & FLAG_IS_ON_GROUND) != 0
        var is_reloading = (flags_byte & FLAG_IS_RELOADING) != 0
        
        snapshot["facing_right"] = facing_right
        snapshot["is_on_ground"] = is_on_ground
        snapshot["is_reloading"] = is_reloading
        
        snapshot["respawn_timer"] = buffer.get_float()
        snapshot["last_processed_input_id"] = buffer.get_u32()
        snapshot["mouse_angle"] = buffer.get_float()
        
        var gun_id = buffer.get_u32() 
        if gun_id == 0:
            snapshot["gun"] = "pistol"
        elif gun_id == 1:
            snapshot["gun"] = "m4a1_rifle"
        elif gun_id == 2:
            snapshot["gun"] = "grenade"
        
        snapshot["current_ammo"] = buffer.get_16()
        snapshot["player_skin"] = buffer.get_u8()
        snapshot["player_score"] = buffer.get_u8()
        snapshot["velocity_x"] = buffer.get_u32()
        snapshot["velocity_y"] = buffer.get_u32()
        
        return snapshot
  ```,
  caption: [Читање бинарног формата пакета добијеног од сервера.],
) <lst:create_player_snapshot_metoda_klijent>