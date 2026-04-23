import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:audio_session/audio_session.dart';

import 'tts_service.dart';

/// Maps card image key (kirilic) to latin wav filename
const _audioMap = {
  // Розмовлялки
  'ай': 'ai', 'ан': 'an', 'ас': 'as', 'ах': 'ah',
  'ба': 'ba', 'бі': 'bi', 'ва': 'va', 'га': 'ga',
  'да': 'da', 'за': 'za', 'ла': 'la', 'ле': 'le',
  'му': 'mu', 'но': 'no', 'ой': 'oi', 'ок': 'ok',
  'ом': 'om', 'оп': 'op', 'ор': 'or', 'ос': 'os',
  'от': 'ot', 'ту': 'tu', 'ук': 'uk', 'уп': 'up',
  'ух': 'uh',
  // Тваринки
  'киця': 'kotik', 'песик': 'sobachka', 'корівка': 'korova',
  'коник': 'konik', 'свинка': 'svinka', 'курочка': 'kurochka',
  'півник': 'pivnik', 'качечка': 'kachechka', 'жабка': 'jabka',
  'рибка': 'ribka', 'пташка': 'ptashka', 'метелик': 'metelik',
  'бджола': 'bjilka', 'равлик': 'ravlik', 'зайчик': 'zaichik',
  'ведмідь': 'vednid', 'вовк': 'vovchik', 'олень': 'olen',
  'їжачок': 'ijachok', 'сова': 'sova', 'лисиця': 'lisicia',
  'лев': 'lev', 'слон': 'slon', 'дельфін': 'delfin',
  'крокодил': 'krokodil', 'пінгвін': 'pingvin', 'мавпочка': 'mavpochka',
  'білочка': 'bilochka', 'черепаха': 'cherepaha',
  // Вдома
  'мама': 'mama', 'тато': 'tato', 'бабуся': 'babusia',
  'дідусь': 'didus', 'ляля': 'lialia', 'родина': 'rodina',
  'обійми': 'obiimi', 'ранок': 'ranok', 'вечір': 'vechir',
  'радість': 'radist', 'сумно': 'sumno', 'сердитий': 'serditii',
  'страшно_д': 'strah', 'подив': 'podiv',
  'мʼяч': 'miach', 'лялька': 'lialka', 'машинка': 'mashinka',
  'книжка': 'knijka', 'кубики': 'kubiki', 'каша': 'kasha',
  'яблуко': 'yabluko', 'водичка': 'vodichka', 'гуляти': 'guliati',
  'ванна': 'vanna', 'мити_ручки': 'ruchki', 'чистити_зубки': 'zubki',
  'ліжко': 'lijko', 'дякую': 'diakuiu', 'будь ласка': 'budlaska',
  'любов': 'lubluiu',
  // Емоції
  'радість_е': 'radist_e', 'сумно_е': 'sumno_e', 'злість': 'zlist',
  'страх': 'strah', 'подив_е': 'podiv_e', 'любов_е': 'lubov_e',
  'сором': 'sorom', 'втома': 'vtoma', 'гордість': 'gordist',
  'цікавість': 'cikavist', 'спокій': 'spokii', 'ніжність': 'nijnist',
  'щастя': 'schastia', 'турбота': 'turbota', 'сміх': 'smih',
  'вдячність': 'vdiachnist', 'здвування': 'zdivuvanna',
  'нудьга': 'nudga', 'образа': 'obraza', 'довіра': 'dovira',
  'натхнення': 'nathnennia', 'хвилювання': 'hviluvania',
  'доброта': 'dobrota', 'сміливість': 'smilivist',
  'мир': 'mir', 'подяка': 'podiaka', 'увага': 'uvaga',
  'тепло': 'teplo', 'задоволення': 'zadovolennia',
  'співчуття': 'spivchutta',
  // Транспорт
  'автомобіль': 'avtomobil', 'автобус': 'avtobus', 'потяг': 'potiag',
  'літак': 'litak', 'корабель': 'korabel', 'велосипед': 'velosiped',
  'мотоцикл': 'motocikl', 'гелікоптер': 'gelikopter', 'трамвай': 'tramvai',
  'метро': 'metro', 'таксі': 'taksi', 'пожежна': 'pojejna',
  'швидка': 'shvidka', 'поліція': 'policia', 'вантажівка': 'vantajivka',
  'трактор': 'traktor', 'самокат': 'samokat', 'ракета': 'raketa',
  'човник': 'chovnik', 'яхта': 'yahta', 'повітряна_куля': 'povitryana_kulia',
  'санки': 'sanki', 'конячка': 'konyachka', 'карета': 'kareta',
  'скейтборд': 'skateboard', 'канатна_дорога': 'kanatna_doroga',
  'електричка': 'electrichka', 'екскаватор': 'ekskavator',
  'підводний_човен': 'pidvodnii_choven', 'параплан': 'paraplan',
  // Кольори та форми
  'червоний': 'red', 'синій': 'blue', 'жовтий': 'yellow',
  'зелений': 'green', 'білий': 'white', 'чорний': 'black',
  'помаранчевий': 'orange', 'рожевий': 'pink', 'фіолетовий': 'purple',
  'коричневий': 'brown', 'сірий': 'gray', 'блакитний': 'sky-blue',
  'золотий': 'gold', 'коло': 'circle', 'квадрат': 'square',
  'трикутник': 'triangle', 'зірка': 'star', 'серце_к': 'hart_k',
  'овал': 'oval', 'ромб': 'diamond', 'великий': 'big',
  'маленький': 'little', 'довгий': 'long', 'круглий': 'round',
  'пухнастий': 'fluffy', 'яскравий': 'bright', 'смугастий': 'striped',
  'плямистий': 'spotted', 'прозорий': 'transparent', 'різнобарвний': 'variegated',
  // Частини тіла
  'ніс': 'nose', 'голова': 'head', 'очі': 'eyes', 'вуха': 'ears',
  'рот': 'mouse', 'зуби': 'teeth', 'язик': 'tonge',
  'волосся': 'hair', 'шия': 'neck', 'плечі': 'sholdes',
  'руки': 'hands', 'пальчики': 'fingers', 'живіт': 'stomack',
  'спина': 'back', 'ноги': 'legs', 'коліна': 'knees',
  'ступні': 'foots', 'серце_т': 'hart_t', 'легені': 'lungs',
  'лікоть': 'elbow', 'долоні': 'palms', 'брови': 'eyebrows',
  'щоки': 'cheeks', 'чоло': 'forehead', 'підборіддя': 'chin',
  'нігті': 'neils', 'шкіра': 'skin', 'пупок': 'jellybutton',
  'усмішка': 'smile', 'тіло': 'body',
  // Їжа
  'яблуко_ї': 'yabluko_f', 'банан': 'banan', 'виноград': 'vinograd',
  'апельсин': 'apelsin', 'полуниця': 'polunicia', 'кавун': 'kavun',
  'груша': 'grusha', 'вишня': 'vishnia', 'персик': 'persik',
  'лимон': 'limon', 'хліб': 'hlib', 'молоко': 'moloko',
  'сир': 'sir', 'каша_ї': 'kasha_f', 'суп': 'sup',
  'пиріжок': 'pirijok', 'печиво': 'pechivo', 'торт': 'tort',
  'морозиво': 'morozivo', 'вареник': 'varenik', 'морква': 'morkva',
  'огірок': 'ogirok', 'помідор': 'pomidor', 'картопля': 'kartoplia',
  'кукурудза': 'kukurudza', 'гарбуз': 'garbuz', 'мед': 'med',
  'яєчко': 'yayechko', 'цукерка': 'cukerka', 'водичка_ї': 'vodichka_f',
  // EN — Animals (identity mapping: JSON audio key = filename stem)
  'en_cat': 'en_cat', 'en_dog': 'en_dog', 'en_cow': 'en_cow',
  'en_horse': 'en_horse', 'en_pig': 'en_pig', 'en_chicken': 'en_chicken',
  'en_rooster': 'en_rooster', 'en_duck': 'en_duck', 'en_frog': 'en_frog',
  'en_fish': 'en_fish', 'en_bird': 'en_bird', 'en_butterfly': 'en_butterfly',
  'en_bee': 'en_bee', 'en_snail': 'en_snail', 'en_bunny': 'en_bunny',
  'en_bear': 'en_bear', 'en_fox': 'en_fox', 'en_wolf': 'en_wolf',
  'en_deer': 'en_deer', 'en_hedgehog': 'en_hedgehog', 'en_owl': 'en_owl',
  'en_penguin': 'en_penguin', 'en_elephant': 'en_elephant', 'en_lion': 'en_lion',
  'en_monkey': 'en_monkey', 'en_crocodile': 'en_crocodile',
  'en_turtle': 'en_turtle', 'en_dolphin': 'en_dolphin', 'en_squirrel': 'en_squirrel',
  // EN — Home & Family
  'en_mommy': 'en_mommy', 'en_dad': 'en_dad', 'en_grandma': 'en_grandma',
  'en_grandpa': 'en_grandpa', 'en_baby': 'en_baby', 'en_family': 'en_family',
  'en_hug': 'en_hug', 'en_morning': 'en_morning', 'en_evening': 'en_evening',
  'en_smile': 'en_smile', 'en_kiss': 'en_kiss', 'en_song': 'en_song',
  'en_ball': 'en_ball', 'en_doll': 'en_doll', 'en_toy_car': 'en_toy_car',
  'en_book': 'en_book', 'en_blocks': 'en_blocks', 'en_porridge': 'en_porridge',
  'en_apple': 'en_apple', 'en_water': 'en_water', 'en_walk': 'en_walk',
  'en_bath': 'en_bath', 'en_hands': 'en_hands', 'en_teeth': 'en_teeth',
  'en_bed': 'en_bed', 'en_thank_you': 'en_thank_you', 'en_please': 'en_please',
  'en_love': 'en_love', 'en_home': 'en_home', 'en_play': 'en_play',
  // EN — Feelings
  'en_happy': 'en_happy', 'en_sad': 'en_sad', 'en_angry': 'en_angry',
  'en_scared': 'en_scared', 'en_tired': 'en_tired', 'en_surprised': 'en_surprised',
  'en_excited': 'en_excited', 'en_calm': 'en_calm', 'en_shy': 'en_shy',
  'en_silly': 'en_silly', 'en_proud': 'en_proud', 'en_loved': 'en_loved',
  // EN — Transport
  'en_car': 'en_car', 'en_bus': 'en_bus', 'en_train': 'en_train',
  'en_airplane': 'en_airplane', 'en_ship': 'en_ship', 'en_bicycle': 'en_bicycle',
  'en_motorcycle': 'en_motorcycle', 'en_helicopter': 'en_helicopter',
  'en_tram': 'en_tram', 'en_subway': 'en_subway', 'en_taxi': 'en_taxi',
  'en_fire_truck': 'en_fire_truck', 'en_ambulance': 'en_ambulance',
  'en_police_car': 'en_police_car', 'en_truck': 'en_truck',
  'en_tractor': 'en_tractor', 'en_scooter': 'en_scooter',
  'en_rocket': 'en_rocket', 'en_boat': 'en_boat', 'en_yacht': 'en_yacht',
  'en_hot_air_balloon': 'en_hot_air_balloon', 'en_sled': 'en_sled',
  'en_skateboard': 'en_skateboard', 'en_excavator': 'en_excavator',
  'en_submarine': 'en_submarine',
  // EN — Food & Fruits (APPLE/PORRIDGE differ from Home: _f suffix)
  'en_apple_f': 'en_apple_f', 'en_banana': 'en_banana', 'en_grapes': 'en_grapes',
  'en_orange': 'en_orange', 'en_strawberry': 'en_strawberry',
  'en_watermelon': 'en_watermelon', 'en_pear': 'en_pear', 'en_cherry': 'en_cherry',
  'en_peach': 'en_peach', 'en_lemon': 'en_lemon', 'en_bread': 'en_bread',
  'en_milk': 'en_milk', 'en_cheese': 'en_cheese', 'en_porridge_f': 'en_porridge_f',
  'en_soup': 'en_soup', 'en_pie': 'en_pie', 'en_cookie': 'en_cookie',
  'en_cake': 'en_cake', 'en_ice_cream': 'en_ice_cream', 'en_pancake': 'en_pancake',
  'en_carrot': 'en_carrot', 'en_cucumber': 'en_cucumber', 'en_tomato': 'en_tomato',
  'en_potato': 'en_potato', 'en_corn': 'en_corn', 'en_pumpkin': 'en_pumpkin',
  'en_honey': 'en_honey', 'en_egg': 'en_egg', 'en_candy': 'en_candy',
  'en_juice': 'en_juice',
  // EN — Colors & Shapes (ORANGE also appears in Food: _c suffix for color)
  'en_red': 'en_red', 'en_blue': 'en_blue', 'en_yellow': 'en_yellow',
  'en_green': 'en_green', 'en_white': 'en_white', 'en_black': 'en_black',
  'en_orange_c': 'en_orange_c', 'en_pink': 'en_pink', 'en_purple': 'en_purple',
  'en_brown': 'en_brown', 'en_gray': 'en_gray', 'en_sky_blue': 'en_sky_blue',
  'en_gold': 'en_gold', 'en_circle': 'en_circle', 'en_square': 'en_square',
  'en_triangle': 'en_triangle', 'en_star': 'en_star', 'en_heart': 'en_heart',
  'en_oval': 'en_oval', 'en_diamond': 'en_diamond', 'en_rectangle': 'en_rectangle',
  'en_cross': 'en_cross', 'en_arrow': 'en_arrow', 'en_moon': 'en_moon',
  'en_flower': 'en_flower', 'en_spiral': 'en_spiral', 'en_cloud': 'en_cloud',
  'en_lightning': 'en_lightning', 'en_rainbow': 'en_rainbow', 'en_sun': 'en_sun',
  // EN — Body Parts (HEART/HANDS/TEETH/SMILE overlap other packs: _b suffix)
  'en_head': 'en_head', 'en_eyes': 'en_eyes', 'en_ears': 'en_ears',
  'en_nose': 'en_nose', 'en_mouth': 'en_mouth', 'en_teeth_b': 'en_teeth_b',
  'en_tongue': 'en_tongue', 'en_hair': 'en_hair', 'en_neck': 'en_neck',
  'en_shoulders': 'en_shoulders', 'en_hands_b': 'en_hands_b',
  'en_fingers': 'en_fingers', 'en_tummy': 'en_tummy', 'en_back': 'en_back',
  'en_legs': 'en_legs', 'en_knees': 'en_knees', 'en_feet': 'en_feet',
  'en_heart_b': 'en_heart_b', 'en_lungs': 'en_lungs', 'en_elbow': 'en_elbow',
  'en_palms': 'en_palms', 'en_eyebrows': 'en_eyebrows', 'en_cheeks': 'en_cheeks',
  'en_forehead': 'en_forehead', 'en_chin': 'en_chin', 'en_nails': 'en_nails',
  'en_skin': 'en_skin', 'en_belly_button': 'en_belly_button',
  'en_smile_b': 'en_smile_b', 'en_toes': 'en_toes',
  // EN — Actions (PLAY/WALK/HUG overlap Home: _a suffix for the action version)
  'en_run': 'en_run', 'en_jump': 'en_jump', 'en_eat': 'en_eat',
  'en_drink': 'en_drink', 'en_sleep': 'en_sleep', 'en_play_a': 'en_play_a',
  'en_draw': 'en_draw', 'en_dance': 'en_dance', 'en_swim': 'en_swim',
  'en_laugh': 'en_laugh', 'en_cry': 'en_cry', 'en_wash': 'en_wash',
  'en_walk_a': 'en_walk_a', 'en_sit': 'en_sit', 'en_look': 'en_look',
  'en_listen': 'en_listen', 'en_hug_a': 'en_hug_a', 'en_sing': 'en_sing',
  'en_throw': 'en_throw', 'en_catch': 'en_catch', 'en_read': 'en_read',
  'en_build': 'en_build', 'en_cook': 'en_cook', 'en_clean': 'en_clean',
  'en_help': 'en_help',
  // EN — Opposites (HAPPY/SAD/CLEAN overlap other packs: _o suffix)
  'en_big': 'en_big', 'en_small': 'en_small', 'en_hot': 'en_hot',
  'en_cold': 'en_cold', 'en_happy_o': 'en_happy_o', 'en_sad_o': 'en_sad_o',
  'en_fast': 'en_fast', 'en_slow': 'en_slow', 'en_day': 'en_day',
  'en_night': 'en_night', 'en_loud': 'en_loud', 'en_quiet': 'en_quiet',
  'en_clean_o': 'en_clean_o', 'en_dirty': 'en_dirty', 'en_long': 'en_long',
  'en_short': 'en_short', 'en_heavy': 'en_heavy', 'en_light': 'en_light',
  'en_open': 'en_open', 'en_closed': 'en_closed', 'en_up': 'en_up',
  'en_down': 'en_down', 'en_hard': 'en_hard', 'en_soft': 'en_soft',
  'en_full': 'en_full', 'en_empty': 'en_empty', 'en_young': 'en_young',
  'en_old': 'en_old', 'en_wet': 'en_wet', 'en_dry': 'en_dry',
  // EN — Phrases (THANK YOU/PLEASE overlap Home: _p suffix for phrases version)
  'en_im_thirsty': 'en_im_thirsty', 'en_im_hungry': 'en_im_hungry',
  'en_im_sleepy': 'en_im_sleepy', 'en_im_cold': 'en_im_cold',
  'en_im_hot': 'en_im_hot', 'en_wheres_mommy': 'en_wheres_mommy',
  'en_wheres_daddy': 'en_wheres_daddy', 'en_come_here': 'en_come_here',
  'en_i_love_you': 'en_i_love_you', 'en_hug_me': 'en_hug_me',
  'en_thank_you_p': 'en_thank_you_p', 'en_please_p': 'en_please_p',
  'en_sorry': 'en_sorry', 'en_hello': 'en_hello', 'en_bye_bye': 'en_bye_bye',
  'en_give_me': 'en_give_me', 'en_help_me': 'en_help_me', 'en_again': 'en_again',
  'en_no': 'en_no', 'en_wait': 'en_wait', 'en_it_hurts': 'en_it_hurts',
  'en_im_sad': 'en_im_sad', 'en_im_happy': 'en_im_happy',
  'en_im_scared': 'en_im_scared', 'en_i_dont_know': 'en_i_dont_know',
  // EN — Adjectives
  'en_fluffy': 'en_fluffy', 'en_prickly': 'en_prickly', 'en_smooth': 'en_smooth',
  'en_slimy': 'en_slimy', 'en_bumpy': 'en_bumpy', 'en_sticky': 'en_sticky',
  'en_sweet': 'en_sweet', 'en_sour': 'en_sour', 'en_bitter': 'en_bitter',
  'en_salty': 'en_salty', 'en_spicy': 'en_spicy', 'en_juicy': 'en_juicy',
  'en_crunchy': 'en_crunchy',
  // EN — Sound R (RED/CARROT/STAR/ROCKET/RAINBOW overlap: _r suffix)
  'en_rabbit': 'en_rabbit', 'en_rocket_r': 'en_rocket_r',
  'en_rainbow_r': 'en_rainbow_r', 'en_river': 'en_river', 'en_robot': 'en_robot',
  'en_ring': 'en_ring', 'en_rose': 'en_rose', 'en_rain': 'en_rain',
  'en_road': 'en_road', 'en_red_r': 'en_red_r', 'en_carrot_r': 'en_carrot_r',
  'en_tiger': 'en_tiger', 'en_zebra': 'en_zebra', 'en_giraffe': 'en_giraffe',
  'en_drum': 'en_drum', 'en_star_r': 'en_star_r',
  // EN — Sound L (many overlaps: _l suffix for the L-practice version)
  'en_lion_l': 'en_lion_l', 'en_lemon_l': 'en_lemon_l', 'en_leaf': 'en_leaf',
  'en_lamp': 'en_lamp', 'en_ladder': 'en_ladder', 'en_light_l': 'en_light_l',
  'en_lake': 'en_lake', 'en_lunch': 'en_lunch', 'en_leg': 'en_leg',
  'en_lock': 'en_lock', 'en_elephant_l': 'en_elephant_l',
  'en_hello_l': 'en_hello_l', 'en_yellow_l': 'en_yellow_l',
  'en_ball_l': 'en_ball_l', 'en_apple_l': 'en_apple_l', 'en_owl_l': 'en_owl_l',
  // EN — Sound S (SUN/STAR/SOUP/SONG overlap: _s suffix)
  'en_sun_s': 'en_sun_s', 'en_snake': 'en_snake', 'en_star_s': 'en_star_s',
  'en_soup_s': 'en_soup_s', 'en_sock': 'en_sock', 'en_spoon': 'en_spoon',
  'en_seal': 'en_seal', 'en_sand': 'en_sand', 'en_seven': 'en_seven',
  'en_salt': 'en_salt', 'en_song_s': 'en_song_s', 'en_six': 'en_six',
  'en_sea': 'en_sea', 'en_pencil': 'en_pencil', 'en_grass': 'en_grass',
  'en_mouse': 'en_mouse',
  // EN — Sound Z (ZEBRA/CHEESE/NOSE/ROSE/EYES overlap: _z suffix)
  'en_zebra_z': 'en_zebra_z', 'en_zoo': 'en_zoo', 'en_zipper': 'en_zipper',
  'en_zero': 'en_zero', 'en_breeze': 'en_breeze', 'en_cheese_z': 'en_cheese_z',
  'en_nose_z': 'en_nose_z', 'en_rose_z': 'en_rose_z', 'en_eyes_z': 'en_eyes_z',
  'en_bees': 'en_bees', 'en_lazy': 'en_lazy', 'en_freeze': 'en_freeze',
  'en_music': 'en_music',
  // EN — Sound SH (SHIP/SHY/FISH/WASH overlap: _sh suffix)
  'en_ship_sh': 'en_ship_sh', 'en_shoe': 'en_shoe', 'en_shark': 'en_shark',
  'en_sheep': 'en_sheep', 'en_shirt': 'en_shirt', 'en_shower': 'en_shower',
  'en_shell': 'en_shell', 'en_shop': 'en_shop', 'en_shy_sh': 'en_shy_sh',
  'en_fish_sh': 'en_fish_sh', 'en_dish': 'en_dish', 'en_brush': 'en_brush',
  'en_wash_sh': 'en_wash_sh', 'en_push': 'en_push', 'en_bushy': 'en_bushy',
  // EN — Sound ZH
  'en_vision': 'en_vision', 'en_treasure': 'en_treasure', 'en_garage': 'en_garage',
  'en_beige': 'en_beige', 'en_measure': 'en_measure', 'en_pleasure': 'en_pleasure',
  // EN — Sound CH (CHEESE/CHICKEN/CHERRY/CHIN/LUNCH/PEACH overlap: _ch suffix)
  'en_chair': 'en_chair', 'en_cheese_ch': 'en_cheese_ch',
  'en_chicken_ch': 'en_chicken_ch', 'en_cherry_ch': 'en_cherry_ch',
  'en_church': 'en_church', 'en_chocolate': 'en_chocolate', 'en_chips': 'en_chips',
  'en_chin_ch': 'en_chin_ch', 'en_beach': 'en_beach', 'en_teach': 'en_teach',
  'en_watch': 'en_watch', 'en_match': 'en_match', 'en_lunch_ch': 'en_lunch_ch',
  'en_peach_ch': 'en_peach_ch', 'en_bench': 'en_bench',
  // EN — Sound TH (BATH overlaps Home: _th suffix)
  'en_three': 'en_three', 'en_thumb': 'en_thumb', 'en_thank': 'en_thank',
  'en_think': 'en_think', 'en_thorn': 'en_thorn', 'en_thick': 'en_thick',
  'en_thin': 'en_thin', 'en_tooth': 'en_tooth', 'en_bath_th': 'en_bath_th',
  'en_math': 'en_math', 'en_this': 'en_this', 'en_that': 'en_that',
  'en_they': 'en_they', 'en_mother': 'en_mother', 'en_father': 'en_father',
  'en_brother': 'en_brother',
  // EN — Sound W (WATER/WATCH/WALK/WOLF/WHITE overlap: _w suffix)
  'en_water_w': 'en_water_w', 'en_window': 'en_window', 'en_whale': 'en_whale',
  'en_wave': 'en_wave', 'en_wheel': 'en_wheel', 'en_watch_w': 'en_watch_w',
  'en_walk_w': 'en_walk_w', 'en_wind': 'en_wind', 'en_wall': 'en_wall',
  'en_winter': 'en_winter', 'en_web': 'en_web', 'en_wolf_w': 'en_wolf_w',
  'en_worm': 'en_worm', 'en_white_w': 'en_white_w',
  // EN — Consonant Blends (many overlap: _bl suffix)
  'en_spoon_bl': 'en_spoon_bl', 'en_star_bl': 'en_star_bl', 'en_snow': 'en_snow',
  'en_smile_bl': 'en_smile_bl', 'en_skate': 'en_skate', 'en_sleep_bl': 'en_sleep_bl',
  'en_swing': 'en_swing', 'en_train_bl': 'en_train_bl', 'en_tree': 'en_tree',
  'en_truck_bl': 'en_truck_bl', 'en_drum_bl': 'en_drum_bl', 'en_dragon': 'en_dragon',
  'en_bridge': 'en_bridge', 'en_bread_bl': 'en_bread_bl', 'en_clock': 'en_clock',
  'en_cloud_bl': 'en_cloud_bl', 'en_flower_bl': 'en_flower_bl',
  'en_frog_bl': 'en_frog_bl',
};

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final _soloud = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};

  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  final ValueNotifier<bool> autoSpeak = ValueNotifier(false);
  int _speakGeneration = 0;

  Future<void> precache() async {
    // 1. Configure iOS audio session — playback ignores silent switch
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
    await session.setActive(true);

    // 2. Initialize SoLoud engine (FFI — no method channels, lowest latency)
    await _soloud.init();

    // 3. Load all sounds into RAM
    for (final entry in _audioMap.entries) {
      try {
        final source = await _soloud.loadAsset('assets/audio_mp3/${entry.value}.mp3');
        _sources[entry.key] = source;
      } catch (e) {
        if (kDebugMode) debugPrint('AudioService: failed to load ${entry.key}: $e');
      }
    }

    if (kDebugMode) debugPrint('AudioService: ${_sources.length} sounds loaded into RAM');
  }

  Future<void> speakCard(String? audioKey, String sound, String fullText) async {
    if (audioKey == null) return;
    final source = _sources[audioKey];
    if (source == null) {
      if (kDebugMode) debugPrint('AudioService: no source for "$audioKey"');
      return;
    }

    final gen = ++_speakGeneration;
    try {
      // Stop previous sound before playing new one
      stop();
      isSpeaking.value = true;
      _currentHandle = await _soloud.play(source);
      final handle = _currentHandle;
      if (handle == null) {
        if (_speakGeneration == gen) isSpeaking.value = false;
        return;
      }
      while (_currentHandle == handle &&
          _soloud.getIsValidVoiceHandle(handle)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // Only the latest speakCard call may clear isSpeaking
      if (_speakGeneration == gen) isSpeaking.value = false;
    } catch (e) {
      if (_speakGeneration == gen) isSpeaking.value = false;
      if (kDebugMode) debugPrint('AudioService: error playing "$audioKey": $e');
    }
  }

  /// Play just the sound for a given audio key (no speaking state tracking).
  /// Used by quiz mode.
  Future<void> playSound(String? audioKey) async {
    if (audioKey == null) return;
    final source = _sources[audioKey];
    if (source == null) {
      if (kDebugMode) debugPrint('AudioService: no source for "$audioKey"');
      return;
    }
    try {
      stop();
      _currentHandle = await _soloud.play(source);
    } catch (e) {
      if (kDebugMode) debugPrint('AudioService: error in playSound "$audioKey": $e');
    }
  }

  /// Play the pre-trimmed first-word recording for [audioKey].
  ///
  /// Audio assets in assets/audio_mp3 have been batch-processed to contain
  /// only the first word (~1–2s each, see tools/trim_audio_to_first_word.sh),
  /// so we just play the file to its natural end. The generation counter
  /// guards the isSpeaking flag against overlap when the user switches
  /// cards before playback finishes.
  ///
  /// Falls back to TTS if no audio file exists for this key.
  Future<void> playWordOnly(
    String? audioKey,
    String fallbackWord, {
    String locale = 'uk-UA',
  }) async {
    if (audioKey == null || !_sources.containsKey(audioKey)) {
      await TtsService.instance.speak(fallbackWord, locale: locale);
      return;
    }

    final source = _sources[audioKey]!;
    final gen = ++_speakGeneration;
    try {
      stop();
      isSpeaking.value = true;
      _currentHandle = await _soloud.play(source);
      final handle = _currentHandle;
      if (handle == null) {
        if (_speakGeneration == gen) isSpeaking.value = false;
        return;
      }
      while (_currentHandle == handle &&
          _soloud.getIsValidVoiceHandle(handle)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_speakGeneration == gen) isSpeaking.value = false;
    } catch (e) {
      if (_speakGeneration == gen) isSpeaking.value = false;
      if (kDebugMode) debugPrint('AudioService: playWordOnly error "$audioKey": $e');
    }
  }

  /// Whether a sound source exists for the given key.
  bool hasSound(String? key) => key != null && _sources.containsKey(key);

  SoundHandle? _currentHandle;

  void stop() {
    if (_currentHandle != null) {
      _soloud.stop(_currentHandle!);
      _currentHandle = null;
    }
    isSpeaking.value = false;
  }
}
