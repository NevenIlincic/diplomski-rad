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

Аутентификација и регистрација: Методе _register()_ и _login()_ омогућавају слање креденцијала корисника ка серверу, док одговарајуће функције _on_register_completed и _on_login_completed прихватају повратне параметре (_result_, _response_code_, _headers_, _body_, _http_node_) и обрађују статус код сервера (нпр. издавање и чување JWT токена).

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

=== Оптимизација величине пакета
