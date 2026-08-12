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

На листингу @lst:enumi_komunikacija_klijent_server се могу видети сви енуми који се користе за размену података између клијента и сервера. *_ServerMessage_* представља одговор сервера ка клијенту, док *_ClientMessage_* је структура коју клијент шаље серверу.

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
  caption: [Приказ енума који се користе за размену података између клијента и сервера.],
) <lst:implementacija_jwt_handler_metode_server>
\